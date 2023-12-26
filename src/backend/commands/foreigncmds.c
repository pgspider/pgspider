/*-------------------------------------------------------------------------
 *
 * foreigncmds.c
 *	  foreign-data wrapper/server creation/manipulation commands
 *
 * Portions Copyright (c) 1996-2023, PostgreSQL Global Development Group
 *
 *
 * IDENTIFICATION
 *	  src/backend/commands/foreigncmds.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "access/htup_details.h"
#include "access/reloptions.h"
#include "access/table.h"
#include "access/xact.h"
#include "catalog/catalog.h"
#include "catalog/dependency.h"
#include "catalog/indexing.h"
#include "catalog/objectaccess.h"
#include "catalog/pg_foreign_data_wrapper.h"
#include "catalog/pg_foreign_server.h"
#include "catalog/pg_foreign_table.h"
#include "catalog/pg_proc.h"
#include "catalog/pg_type.h"
#include "catalog/pg_user_mapping.h"
#include "commands/defrem.h"
#include "foreign/fdwapi.h"
#include "foreign/foreign.h"
#include "miscadmin.h"
#include "parser/parse_func.h"
#include "tcop/utility.h"
#include "utils/acl.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/rel.h"
#include "utils/syscache.h"

#ifdef PGSPIDER
#ifdef HAVE_DLOPEN
#include <dlfcn.h>
#endif							/* HAVE_DLOPEN */
#include "catalog/namespace.h"
#include "executor/spi.h"
#include "utils/regproc.h"
#include "utils/builtins.h"
#endif
typedef struct
{
	char	   *tablename;
	char	   *cmd;
} import_error_callback_arg;

/* Internal functions */
static void import_error_callback(void *arg);

#ifdef PGSPIDER
typedef int (*ExecForeignDDL) (Oid, Relation, int, bool);

/*
 * ForeignDDLType -
 *	  enums for type of operation represented by a CREATE/DROP DATASOURCE TABLE Query
 */
typedef enum ForeignDDLType
{
	SPD_CMD_CREATE,					/* Create datasource stmt */
	SPD_CMD_DROP					/* Drop datasource stmt */
} ForeignDDLType;

/*
 * Child server information, currently only num of child table is saved.
 */
typedef struct child_server_info
{
	char	   *server_name;		/* foreign server name */
	int			child_table_cnt;	/* num of child table */
	struct child_server_info *next;	/* next foreign server */
} child_server_info;

/* MIGRATE COMMAND parsing context */
typedef struct migrate_cmd_context
{
	List	   *commands;						/* command list for migrate data */
	List	   *cleanup_commands;				/* command list for clean-up when an error occurs */

	char	   *use_multitenant_server;		/* multitenant server name */
	int 		socket_port;				/* port number of socket server */
	int 		function_timeout;			/* specifies the seconds that PGSpider waits for finished notification from Function */

	/* source table information */
	char	   *src_table_fullname;			/* name include schema/catalog and quote indentifier  */
	char	   *src_table_name;				/* src table name */
	bool		src_table_is_multitenant;		/* true if src table is multitenant table */

	/* destination table information */
	char	   *dest_table_fullname;			/* name include schema/catalog and quote indentifier */
	char	   *dest_table_name;				/* dest table name */
	bool		dest_table_is_multitenant;		/* true if dest table is multitenant table */

	/* destination child table information */
	List	   *dest_child_table_full_names;	/* name list include schema/catalog and quote indentifier  */
	List	   *dest_child_table_names;		/* dest child table name list */

	/* temporary table prefix temp_<time create> */
	char	   *temp_prefix;

	/* temporary host info*/
	char       *public_host;
	int         public_port;
	char       *ifconfig_service;
} migrate_cmd_context;

#define DCT_DEFAULT_BATCH_SIZE 1000			/* Default batch size for Data Compression Transfer Feature */
#define DCT_DEFAULT_PORT 4814				/* Default port for Data Compression Transfer Feature */
#define DCT_DEFAULT_FUNCTION_TIMEOUT 900	/* Default function timeout for Data Compression Transfer Feature. 900s equal 15 minutes */
#endif

/*
 * Convert a DefElem list to the text array format that is used in
 * pg_foreign_data_wrapper, pg_foreign_server, pg_user_mapping, and
 * pg_foreign_table.
 *
 * Returns the array in the form of a Datum, or PointerGetDatum(NULL)
 * if the list is empty.
 *
 * Note: The array is usually stored to database without further
 * processing, hence any validation should be done before this
 * conversion.
 */
static Datum
optionListToArray(List *options)
{
	ArrayBuildState *astate = NULL;
	ListCell   *cell;

	foreach(cell, options)
	{
		DefElem    *def = lfirst(cell);
		const char *value;
		Size		len;
		text	   *t;

		value = defGetString(def);
		len = VARHDRSZ + strlen(def->defname) + 1 + strlen(value);
		t = palloc(len + 1);
		SET_VARSIZE(t, len);
		sprintf(VARDATA(t), "%s=%s", def->defname, value);

		astate = accumArrayResult(astate, PointerGetDatum(t),
								  false, TEXTOID,
								  CurrentMemoryContext);
	}

	if (astate)
		return makeArrayResult(astate, CurrentMemoryContext);

	return PointerGetDatum(NULL);
}


/*
 * Transform a list of DefElem into text array format.  This is substantially
 * the same thing as optionListToArray(), except we recognize SET/ADD/DROP
 * actions for modifying an existing list of options, which is passed in
 * Datum form as oldOptions.  Also, if fdwvalidator isn't InvalidOid
 * it specifies a validator function to call on the result.
 *
 * Returns the array in the form of a Datum, or PointerGetDatum(NULL)
 * if the list is empty.
 *
 * This is used by CREATE/ALTER of FOREIGN DATA WRAPPER/SERVER/USER MAPPING/
 * FOREIGN TABLE.
 */
Datum
transformGenericOptions(Oid catalogId,
						Datum oldOptions,
						List *options,
						Oid fdwvalidator)
{
	List	   *resultOptions = untransformRelOptions(oldOptions);
	ListCell   *optcell;
	Datum		result;

	foreach(optcell, options)
	{
		DefElem    *od = lfirst(optcell);
		ListCell   *cell;

		/*
		 * Find the element in resultOptions.  We need this for validation in
		 * all cases.
		 */
		foreach(cell, resultOptions)
		{
			DefElem    *def = lfirst(cell);

			if (strcmp(def->defname, od->defname) == 0)
				break;
		}

		/*
		 * It is possible to perform multiple SET/DROP actions on the same
		 * option.  The standard permits this, as long as the options to be
		 * added are unique.  Note that an unspecified action is taken to be
		 * ADD.
		 */
		switch (od->defaction)
		{
			case DEFELEM_DROP:
				if (!cell)
					ereport(ERROR,
							(errcode(ERRCODE_UNDEFINED_OBJECT),
							 errmsg("option \"%s\" not found",
									od->defname)));
				resultOptions = list_delete_cell(resultOptions, cell);
				break;

			case DEFELEM_SET:
				if (!cell)
					ereport(ERROR,
							(errcode(ERRCODE_UNDEFINED_OBJECT),
							 errmsg("option \"%s\" not found",
									od->defname)));
				lfirst(cell) = od;
				break;

			case DEFELEM_ADD:
			case DEFELEM_UNSPEC:
				if (cell)
					ereport(ERROR,
							(errcode(ERRCODE_DUPLICATE_OBJECT),
							 errmsg("option \"%s\" provided more than once",
									od->defname)));
				resultOptions = lappend(resultOptions, od);
				break;

			default:
				elog(ERROR, "unrecognized action %d on option \"%s\"",
					 (int) od->defaction, od->defname);
				break;
		}
	}

	result = optionListToArray(resultOptions);

	if (OidIsValid(fdwvalidator))
	{
		Datum		valarg = result;

		/*
		 * Pass a null options list as an empty array, so that validators
		 * don't have to be declared non-strict to handle the case.
		 */
		if (DatumGetPointer(valarg) == NULL)
			valarg = PointerGetDatum(construct_empty_array(TEXTOID));
		OidFunctionCall2(fdwvalidator, valarg, ObjectIdGetDatum(catalogId));
	}

	return result;
}


/*
 * Internal workhorse for changing a data wrapper's owner.
 *
 * Allow this only for superusers; also the new owner must be a
 * superuser.
 */
static void
AlterForeignDataWrapperOwner_internal(Relation rel, HeapTuple tup, Oid newOwnerId)
{
	Form_pg_foreign_data_wrapper form;
	Datum		repl_val[Natts_pg_foreign_data_wrapper];
	bool		repl_null[Natts_pg_foreign_data_wrapper];
	bool		repl_repl[Natts_pg_foreign_data_wrapper];
	Acl		   *newAcl;
	Datum		aclDatum;
	bool		isNull;

	form = (Form_pg_foreign_data_wrapper) GETSTRUCT(tup);

	/* Must be a superuser to change a FDW owner */
	if (!superuser())
		ereport(ERROR,
				(errcode(ERRCODE_INSUFFICIENT_PRIVILEGE),
				 errmsg("permission denied to change owner of foreign-data wrapper \"%s\"",
						NameStr(form->fdwname)),
				 errhint("Must be superuser to change owner of a foreign-data wrapper.")));

	/* New owner must also be a superuser */
	if (!superuser_arg(newOwnerId))
		ereport(ERROR,
				(errcode(ERRCODE_INSUFFICIENT_PRIVILEGE),
				 errmsg("permission denied to change owner of foreign-data wrapper \"%s\"",
						NameStr(form->fdwname)),
				 errhint("The owner of a foreign-data wrapper must be a superuser.")));

	if (form->fdwowner != newOwnerId)
	{
		memset(repl_null, false, sizeof(repl_null));
		memset(repl_repl, false, sizeof(repl_repl));

		repl_repl[Anum_pg_foreign_data_wrapper_fdwowner - 1] = true;
		repl_val[Anum_pg_foreign_data_wrapper_fdwowner - 1] = ObjectIdGetDatum(newOwnerId);

		aclDatum = heap_getattr(tup,
								Anum_pg_foreign_data_wrapper_fdwacl,
								RelationGetDescr(rel),
								&isNull);
		/* Null ACLs do not require changes */
		if (!isNull)
		{
			newAcl = aclnewowner(DatumGetAclP(aclDatum),
								 form->fdwowner, newOwnerId);
			repl_repl[Anum_pg_foreign_data_wrapper_fdwacl - 1] = true;
			repl_val[Anum_pg_foreign_data_wrapper_fdwacl - 1] = PointerGetDatum(newAcl);
		}

		tup = heap_modify_tuple(tup, RelationGetDescr(rel), repl_val, repl_null,
								repl_repl);

		CatalogTupleUpdate(rel, &tup->t_self, tup);

		/* Update owner dependency reference */
		changeDependencyOnOwner(ForeignDataWrapperRelationId,
								form->oid,
								newOwnerId);
	}

	InvokeObjectPostAlterHook(ForeignDataWrapperRelationId,
							  form->oid, 0);
}

/*
 * Change foreign-data wrapper owner -- by name
 *
 * Note restrictions in the "_internal" function, above.
 */
ObjectAddress
AlterForeignDataWrapperOwner(const char *name, Oid newOwnerId)
{
	Oid			fdwId;
	HeapTuple	tup;
	Relation	rel;
	ObjectAddress address;
	Form_pg_foreign_data_wrapper form;


	rel = table_open(ForeignDataWrapperRelationId, RowExclusiveLock);

	tup = SearchSysCacheCopy1(FOREIGNDATAWRAPPERNAME, CStringGetDatum(name));

	if (!HeapTupleIsValid(tup))
		ereport(ERROR,
				(errcode(ERRCODE_UNDEFINED_OBJECT),
				 errmsg("foreign-data wrapper \"%s\" does not exist", name)));

	form = (Form_pg_foreign_data_wrapper) GETSTRUCT(tup);
	fdwId = form->oid;

	AlterForeignDataWrapperOwner_internal(rel, tup, newOwnerId);

	ObjectAddressSet(address, ForeignDataWrapperRelationId, fdwId);

	heap_freetuple(tup);

	table_close(rel, RowExclusiveLock);

	return address;
}

/*
 * Change foreign-data wrapper owner -- by OID
 *
 * Note restrictions in the "_internal" function, above.
 */
void
AlterForeignDataWrapperOwner_oid(Oid fwdId, Oid newOwnerId)
{
	HeapTuple	tup;
	Relation	rel;

	rel = table_open(ForeignDataWrapperRelationId, RowExclusiveLock);

	tup = SearchSysCacheCopy1(FOREIGNDATAWRAPPEROID, ObjectIdGetDatum(fwdId));

	if (!HeapTupleIsValid(tup))
		ereport(ERROR,
				(errcode(ERRCODE_UNDEFINED_OBJECT),
				 errmsg("foreign-data wrapper with OID %u does not exist", fwdId)));

	AlterForeignDataWrapperOwner_internal(rel, tup, newOwnerId);

	heap_freetuple(tup);

	table_close(rel, RowExclusiveLock);
}

/*
 * Internal workhorse for changing a foreign server's owner
 */
static void
AlterForeignServerOwner_internal(Relation rel, HeapTuple tup, Oid newOwnerId)
{
	Form_pg_foreign_server form;
	Datum		repl_val[Natts_pg_foreign_server];
	bool		repl_null[Natts_pg_foreign_server];
	bool		repl_repl[Natts_pg_foreign_server];
	Acl		   *newAcl;
	Datum		aclDatum;
	bool		isNull;

	form = (Form_pg_foreign_server) GETSTRUCT(tup);

	if (form->srvowner != newOwnerId)
	{
		/* Superusers can always do it */
		if (!superuser())
		{
			Oid			srvId;
			AclResult	aclresult;

			srvId = form->oid;

			/* Must be owner */
			if (!object_ownercheck(ForeignServerRelationId, srvId, GetUserId()))
				aclcheck_error(ACLCHECK_NOT_OWNER, OBJECT_FOREIGN_SERVER,
							   NameStr(form->srvname));

			/* Must be able to become new owner */
			check_can_set_role(GetUserId(), newOwnerId);

			/* New owner must have USAGE privilege on foreign-data wrapper */
			aclresult = object_aclcheck(ForeignDataWrapperRelationId, form->srvfdw, newOwnerId, ACL_USAGE);
			if (aclresult != ACLCHECK_OK)
			{
				ForeignDataWrapper *fdw = GetForeignDataWrapper(form->srvfdw);

				aclcheck_error(aclresult, OBJECT_FDW, fdw->fdwname);
			}
		}

		memset(repl_null, false, sizeof(repl_null));
		memset(repl_repl, false, sizeof(repl_repl));

		repl_repl[Anum_pg_foreign_server_srvowner - 1] = true;
		repl_val[Anum_pg_foreign_server_srvowner - 1] = ObjectIdGetDatum(newOwnerId);

		aclDatum = heap_getattr(tup,
								Anum_pg_foreign_server_srvacl,
								RelationGetDescr(rel),
								&isNull);
		/* Null ACLs do not require changes */
		if (!isNull)
		{
			newAcl = aclnewowner(DatumGetAclP(aclDatum),
								 form->srvowner, newOwnerId);
			repl_repl[Anum_pg_foreign_server_srvacl - 1] = true;
			repl_val[Anum_pg_foreign_server_srvacl - 1] = PointerGetDatum(newAcl);
		}

		tup = heap_modify_tuple(tup, RelationGetDescr(rel), repl_val, repl_null,
								repl_repl);

		CatalogTupleUpdate(rel, &tup->t_self, tup);

		/* Update owner dependency reference */
		changeDependencyOnOwner(ForeignServerRelationId, form->oid,
								newOwnerId);
	}

	InvokeObjectPostAlterHook(ForeignServerRelationId,
							  form->oid, 0);
}

/*
 * Change foreign server owner -- by name
 */
ObjectAddress
AlterForeignServerOwner(const char *name, Oid newOwnerId)
{
	Oid			servOid;
	HeapTuple	tup;
	Relation	rel;
	ObjectAddress address;
	Form_pg_foreign_server form;

	rel = table_open(ForeignServerRelationId, RowExclusiveLock);

	tup = SearchSysCacheCopy1(FOREIGNSERVERNAME, CStringGetDatum(name));

	if (!HeapTupleIsValid(tup))
		ereport(ERROR,
				(errcode(ERRCODE_UNDEFINED_OBJECT),
				 errmsg("server \"%s\" does not exist", name)));

	form = (Form_pg_foreign_server) GETSTRUCT(tup);
	servOid = form->oid;

	AlterForeignServerOwner_internal(rel, tup, newOwnerId);

	ObjectAddressSet(address, ForeignServerRelationId, servOid);

	heap_freetuple(tup);

	table_close(rel, RowExclusiveLock);

	return address;
}

/*
 * Change foreign server owner -- by OID
 */
void
AlterForeignServerOwner_oid(Oid srvId, Oid newOwnerId)
{
	HeapTuple	tup;
	Relation	rel;

	rel = table_open(ForeignServerRelationId, RowExclusiveLock);

	tup = SearchSysCacheCopy1(FOREIGNSERVEROID, ObjectIdGetDatum(srvId));

	if (!HeapTupleIsValid(tup))
		ereport(ERROR,
				(errcode(ERRCODE_UNDEFINED_OBJECT),
				 errmsg("foreign server with OID %u does not exist", srvId)));

	AlterForeignServerOwner_internal(rel, tup, newOwnerId);

	heap_freetuple(tup);

	table_close(rel, RowExclusiveLock);
}

/*
 * Convert a handler function name passed from the parser to an Oid.
 */
static Oid
lookup_fdw_handler_func(DefElem *handler)
{
	Oid			handlerOid;

	if (handler == NULL || handler->arg == NULL)
		return InvalidOid;

	/* handlers have no arguments */
	handlerOid = LookupFuncName((List *) handler->arg, 0, NULL, false);

	/* check that handler has correct return type */
	if (get_func_rettype(handlerOid) != FDW_HANDLEROID)
		ereport(ERROR,
				(errcode(ERRCODE_WRONG_OBJECT_TYPE),
				 errmsg("function %s must return type %s",
						NameListToString((List *) handler->arg), "fdw_handler")));

	return handlerOid;
}

/*
 * Convert a validator function name passed from the parser to an Oid.
 */
static Oid
lookup_fdw_validator_func(DefElem *validator)
{
	Oid			funcargtypes[2];

	if (validator == NULL || validator->arg == NULL)
		return InvalidOid;

	/* validators take text[], oid */
	funcargtypes[0] = TEXTARRAYOID;
	funcargtypes[1] = OIDOID;

	return LookupFuncName((List *) validator->arg, 2, funcargtypes, false);
	/* validator's return value is ignored, so we don't check the type */
}

/*
 * Process function options of CREATE/ALTER FDW
 */
static void
parse_func_options(ParseState *pstate, List *func_options,
				   bool *handler_given, Oid *fdwhandler,
				   bool *validator_given, Oid *fdwvalidator)
{
	ListCell   *cell;

	*handler_given = false;
	*validator_given = false;
	/* return InvalidOid if not given */
	*fdwhandler = InvalidOid;
	*fdwvalidator = InvalidOid;

	foreach(cell, func_options)
	{
		DefElem    *def = (DefElem *) lfirst(cell);

		if (strcmp(def->defname, "handler") == 0)
		{
			if (*handler_given)
				errorConflictingDefElem(def, pstate);
			*handler_given = true;
			*fdwhandler = lookup_fdw_handler_func(def);
		}
		else if (strcmp(def->defname, "validator") == 0)
		{
			if (*validator_given)
				errorConflictingDefElem(def, pstate);
			*validator_given = true;
			*fdwvalidator = lookup_fdw_validator_func(def);
		}
		else
			elog(ERROR, "option \"%s\" not recognized",
				 def->defname);
	}
}

/*
 * Create a foreign-data wrapper
 */
ObjectAddress
CreateForeignDataWrapper(ParseState *pstate, CreateFdwStmt *stmt)
{
	Relation	rel;
	Datum		values[Natts_pg_foreign_data_wrapper];
	bool		nulls[Natts_pg_foreign_data_wrapper];
	HeapTuple	tuple;
	Oid			fdwId;
	bool		handler_given;
	bool		validator_given;
	Oid			fdwhandler;
	Oid			fdwvalidator;
	Datum		fdwoptions;
	Oid			ownerId;
	ObjectAddress myself;
	ObjectAddress referenced;

	rel = table_open(ForeignDataWrapperRelationId, RowExclusiveLock);

	/* Must be superuser */
	if (!superuser())
		ereport(ERROR,
				(errcode(ERRCODE_INSUFFICIENT_PRIVILEGE),
				 errmsg("permission denied to create foreign-data wrapper \"%s\"",
						stmt->fdwname),
				 errhint("Must be superuser to create a foreign-data wrapper.")));

	/* For now the owner cannot be specified on create. Use effective user ID. */
	ownerId = GetUserId();

	/*
	 * Check that there is no other foreign-data wrapper by this name.
	 */
	if (GetForeignDataWrapperByName(stmt->fdwname, true) != NULL)
		ereport(ERROR,
				(errcode(ERRCODE_DUPLICATE_OBJECT),
				 errmsg("foreign-data wrapper \"%s\" already exists",
						stmt->fdwname)));

	/*
	 * Insert tuple into pg_foreign_data_wrapper.
	 */
	memset(values, 0, sizeof(values));
	memset(nulls, false, sizeof(nulls));

	fdwId = GetNewOidWithIndex(rel, ForeignDataWrapperOidIndexId,
							   Anum_pg_foreign_data_wrapper_oid);
	values[Anum_pg_foreign_data_wrapper_oid - 1] = ObjectIdGetDatum(fdwId);
	values[Anum_pg_foreign_data_wrapper_fdwname - 1] =
		DirectFunctionCall1(namein, CStringGetDatum(stmt->fdwname));
	values[Anum_pg_foreign_data_wrapper_fdwowner - 1] = ObjectIdGetDatum(ownerId);

	/* Lookup handler and validator functions, if given */
	parse_func_options(pstate, stmt->func_options,
					   &handler_given, &fdwhandler,
					   &validator_given, &fdwvalidator);

	values[Anum_pg_foreign_data_wrapper_fdwhandler - 1] = ObjectIdGetDatum(fdwhandler);
	values[Anum_pg_foreign_data_wrapper_fdwvalidator - 1] = ObjectIdGetDatum(fdwvalidator);

	nulls[Anum_pg_foreign_data_wrapper_fdwacl - 1] = true;

	fdwoptions = transformGenericOptions(ForeignDataWrapperRelationId,
										 PointerGetDatum(NULL),
										 stmt->options,
										 fdwvalidator);

	if (PointerIsValid(DatumGetPointer(fdwoptions)))
		values[Anum_pg_foreign_data_wrapper_fdwoptions - 1] = fdwoptions;
	else
		nulls[Anum_pg_foreign_data_wrapper_fdwoptions - 1] = true;

	tuple = heap_form_tuple(rel->rd_att, values, nulls);

	CatalogTupleInsert(rel, tuple);

	heap_freetuple(tuple);

	/* record dependencies */
	myself.classId = ForeignDataWrapperRelationId;
	myself.objectId = fdwId;
	myself.objectSubId = 0;

	if (OidIsValid(fdwhandler))
	{
		referenced.classId = ProcedureRelationId;
		referenced.objectId = fdwhandler;
		referenced.objectSubId = 0;
		recordDependencyOn(&myself, &referenced, DEPENDENCY_NORMAL);
	}

	if (OidIsValid(fdwvalidator))
	{
		referenced.classId = ProcedureRelationId;
		referenced.objectId = fdwvalidator;
		referenced.objectSubId = 0;
		recordDependencyOn(&myself, &referenced, DEPENDENCY_NORMAL);
	}

	recordDependencyOnOwner(ForeignDataWrapperRelationId, fdwId, ownerId);

	/* dependency on extension */
	recordDependencyOnCurrentExtension(&myself, false);

	/* Post creation hook for new foreign data wrapper */
	InvokeObjectPostCreateHook(ForeignDataWrapperRelationId, fdwId, 0);

	table_close(rel, RowExclusiveLock);

	return myself;
}


/*
 * Alter foreign-data wrapper
 */
ObjectAddress
AlterForeignDataWrapper(ParseState *pstate, AlterFdwStmt *stmt)
{
	Relation	rel;
	HeapTuple	tp;
	Form_pg_foreign_data_wrapper fdwForm;
	Datum		repl_val[Natts_pg_foreign_data_wrapper];
	bool		repl_null[Natts_pg_foreign_data_wrapper];
	bool		repl_repl[Natts_pg_foreign_data_wrapper];
	Oid			fdwId;
	bool		isnull;
	Datum		datum;
	bool		handler_given;
	bool		validator_given;
	Oid			fdwhandler;
	Oid			fdwvalidator;
	ObjectAddress myself;

	rel = table_open(ForeignDataWrapperRelationId, RowExclusiveLock);

	/* Must be superuser */
	if (!superuser())
		ereport(ERROR,
				(errcode(ERRCODE_INSUFFICIENT_PRIVILEGE),
				 errmsg("permission denied to alter foreign-data wrapper \"%s\"",
						stmt->fdwname),
				 errhint("Must be superuser to alter a foreign-data wrapper.")));

	tp = SearchSysCacheCopy1(FOREIGNDATAWRAPPERNAME,
							 CStringGetDatum(stmt->fdwname));

	if (!HeapTupleIsValid(tp))
		ereport(ERROR,
				(errcode(ERRCODE_UNDEFINED_OBJECT),
				 errmsg("foreign-data wrapper \"%s\" does not exist", stmt->fdwname)));

	fdwForm = (Form_pg_foreign_data_wrapper) GETSTRUCT(tp);
	fdwId = fdwForm->oid;

	memset(repl_val, 0, sizeof(repl_val));
	memset(repl_null, false, sizeof(repl_null));
	memset(repl_repl, false, sizeof(repl_repl));

	parse_func_options(pstate, stmt->func_options,
					   &handler_given, &fdwhandler,
					   &validator_given, &fdwvalidator);

	if (handler_given)
	{
		repl_val[Anum_pg_foreign_data_wrapper_fdwhandler - 1] = ObjectIdGetDatum(fdwhandler);
		repl_repl[Anum_pg_foreign_data_wrapper_fdwhandler - 1] = true;

		/*
		 * It could be that the behavior of accessing foreign table changes
		 * with the new handler.  Warn about this.
		 */
		ereport(WARNING,
				(errmsg("changing the foreign-data wrapper handler can change behavior of existing foreign tables")));
	}

	if (validator_given)
	{
		repl_val[Anum_pg_foreign_data_wrapper_fdwvalidator - 1] = ObjectIdGetDatum(fdwvalidator);
		repl_repl[Anum_pg_foreign_data_wrapper_fdwvalidator - 1] = true;

		/*
		 * It could be that existing options for the FDW or dependent SERVER,
		 * USER MAPPING or FOREIGN TABLE objects are no longer valid according
		 * to the new validator.  Warn about this.
		 */
		if (OidIsValid(fdwvalidator))
			ereport(WARNING,
					(errmsg("changing the foreign-data wrapper validator can cause "
							"the options for dependent objects to become invalid")));
	}
	else
	{
		/*
		 * Validator is not changed, but we need it for validating options.
		 */
		fdwvalidator = fdwForm->fdwvalidator;
	}

	/*
	 * If options specified, validate and update.
	 */
	if (stmt->options)
	{
		/* Extract the current options */
		datum = SysCacheGetAttr(FOREIGNDATAWRAPPEROID,
								tp,
								Anum_pg_foreign_data_wrapper_fdwoptions,
								&isnull);
		if (isnull)
			datum = PointerGetDatum(NULL);

		/* Transform the options */
		datum = transformGenericOptions(ForeignDataWrapperRelationId,
										datum,
										stmt->options,
										fdwvalidator);

		if (PointerIsValid(DatumGetPointer(datum)))
			repl_val[Anum_pg_foreign_data_wrapper_fdwoptions - 1] = datum;
		else
			repl_null[Anum_pg_foreign_data_wrapper_fdwoptions - 1] = true;

		repl_repl[Anum_pg_foreign_data_wrapper_fdwoptions - 1] = true;
	}

	/* Everything looks good - update the tuple */
	tp = heap_modify_tuple(tp, RelationGetDescr(rel),
						   repl_val, repl_null, repl_repl);

	CatalogTupleUpdate(rel, &tp->t_self, tp);

	heap_freetuple(tp);

	ObjectAddressSet(myself, ForeignDataWrapperRelationId, fdwId);

	/* Update function dependencies if we changed them */
	if (handler_given || validator_given)
	{
		ObjectAddress referenced;

		/*
		 * Flush all existing dependency records of this FDW on functions; we
		 * assume there can be none other than the ones we are fixing.
		 */
		deleteDependencyRecordsForClass(ForeignDataWrapperRelationId,
										fdwId,
										ProcedureRelationId,
										DEPENDENCY_NORMAL);

		/* And build new ones. */

		if (OidIsValid(fdwhandler))
		{
			referenced.classId = ProcedureRelationId;
			referenced.objectId = fdwhandler;
			referenced.objectSubId = 0;
			recordDependencyOn(&myself, &referenced, DEPENDENCY_NORMAL);
		}

		if (OidIsValid(fdwvalidator))
		{
			referenced.classId = ProcedureRelationId;
			referenced.objectId = fdwvalidator;
			referenced.objectSubId = 0;
			recordDependencyOn(&myself, &referenced, DEPENDENCY_NORMAL);
		}
	}

	InvokeObjectPostAlterHook(ForeignDataWrapperRelationId, fdwId, 0);

	table_close(rel, RowExclusiveLock);

	return myself;
}


/*
 * Create a foreign server
 */
ObjectAddress
CreateForeignServer(CreateForeignServerStmt *stmt)
{
	Relation	rel;
	Datum		srvoptions;
	Datum		values[Natts_pg_foreign_server];
	bool		nulls[Natts_pg_foreign_server];
	HeapTuple	tuple;
	Oid			srvId;
	Oid			ownerId;
	AclResult	aclresult;
	ObjectAddress myself;
	ObjectAddress referenced;
	ForeignDataWrapper *fdw;

	rel = table_open(ForeignServerRelationId, RowExclusiveLock);

	/* For now the owner cannot be specified on create. Use effective user ID. */
	ownerId = GetUserId();

	/*
	 * Check that there is no other foreign server by this name.  If there is
	 * one, do nothing if IF NOT EXISTS was specified.
	 */
	srvId = get_foreign_server_oid(stmt->servername, true);
	if (OidIsValid(srvId))
	{
		if (stmt->if_not_exists)
		{
			/*
			 * If we are in an extension script, insist that the pre-existing
			 * object be a member of the extension, to avoid security risks.
			 */
			ObjectAddressSet(myself, ForeignServerRelationId, srvId);
			checkMembershipInCurrentExtension(&myself);

			/* OK to skip */
			ereport(NOTICE,
					(errcode(ERRCODE_DUPLICATE_OBJECT),
					 errmsg("server \"%s\" already exists, skipping",
							stmt->servername)));
			table_close(rel, RowExclusiveLock);
			return InvalidObjectAddress;
		}
		else
			ereport(ERROR,
					(errcode(ERRCODE_DUPLICATE_OBJECT),
					 errmsg("server \"%s\" already exists",
							stmt->servername)));
	}

	/*
	 * Check that the FDW exists and that we have USAGE on it. Also get the
	 * actual FDW for option validation etc.
	 */
	fdw = GetForeignDataWrapperByName(stmt->fdwname, false);

	aclresult = object_aclcheck(ForeignDataWrapperRelationId, fdw->fdwid, ownerId, ACL_USAGE);
	if (aclresult != ACLCHECK_OK)
		aclcheck_error(aclresult, OBJECT_FDW, fdw->fdwname);

	/*
	 * Insert tuple into pg_foreign_server.
	 */
	memset(values, 0, sizeof(values));
	memset(nulls, false, sizeof(nulls));

	srvId = GetNewOidWithIndex(rel, ForeignServerOidIndexId,
							   Anum_pg_foreign_server_oid);
	values[Anum_pg_foreign_server_oid - 1] = ObjectIdGetDatum(srvId);
	values[Anum_pg_foreign_server_srvname - 1] =
		DirectFunctionCall1(namein, CStringGetDatum(stmt->servername));
	values[Anum_pg_foreign_server_srvowner - 1] = ObjectIdGetDatum(ownerId);
	values[Anum_pg_foreign_server_srvfdw - 1] = ObjectIdGetDatum(fdw->fdwid);

	/* Add server type if supplied */
	if (stmt->servertype)
		values[Anum_pg_foreign_server_srvtype - 1] =
			CStringGetTextDatum(stmt->servertype);
	else
		nulls[Anum_pg_foreign_server_srvtype - 1] = true;

	/* Add server version if supplied */
	if (stmt->version)
		values[Anum_pg_foreign_server_srvversion - 1] =
			CStringGetTextDatum(stmt->version);
	else
		nulls[Anum_pg_foreign_server_srvversion - 1] = true;

	/* Start with a blank acl */
	nulls[Anum_pg_foreign_server_srvacl - 1] = true;

	/* Add server options */
	srvoptions = transformGenericOptions(ForeignServerRelationId,
										 PointerGetDatum(NULL),
										 stmt->options,
										 fdw->fdwvalidator);

	if (PointerIsValid(DatumGetPointer(srvoptions)))
		values[Anum_pg_foreign_server_srvoptions - 1] = srvoptions;
	else
		nulls[Anum_pg_foreign_server_srvoptions - 1] = true;

	tuple = heap_form_tuple(rel->rd_att, values, nulls);

	CatalogTupleInsert(rel, tuple);

	heap_freetuple(tuple);

	/* record dependencies */
	myself.classId = ForeignServerRelationId;
	myself.objectId = srvId;
	myself.objectSubId = 0;

	referenced.classId = ForeignDataWrapperRelationId;
	referenced.objectId = fdw->fdwid;
	referenced.objectSubId = 0;
	recordDependencyOn(&myself, &referenced, DEPENDENCY_NORMAL);

	recordDependencyOnOwner(ForeignServerRelationId, srvId, ownerId);

	/* dependency on extension */
	recordDependencyOnCurrentExtension(&myself, false);

	/* Post creation hook for new foreign server */
	InvokeObjectPostCreateHook(ForeignServerRelationId, srvId, 0);

	table_close(rel, RowExclusiveLock);

	return myself;
}


/*
 * Alter foreign server
 */
ObjectAddress
AlterForeignServer(AlterForeignServerStmt *stmt)
{
	Relation	rel;
	HeapTuple	tp;
	Datum		repl_val[Natts_pg_foreign_server];
	bool		repl_null[Natts_pg_foreign_server];
	bool		repl_repl[Natts_pg_foreign_server];
	Oid			srvId;
	Form_pg_foreign_server srvForm;
	ObjectAddress address;

	rel = table_open(ForeignServerRelationId, RowExclusiveLock);

	tp = SearchSysCacheCopy1(FOREIGNSERVERNAME,
							 CStringGetDatum(stmt->servername));

	if (!HeapTupleIsValid(tp))
		ereport(ERROR,
				(errcode(ERRCODE_UNDEFINED_OBJECT),
				 errmsg("server \"%s\" does not exist", stmt->servername)));

	srvForm = (Form_pg_foreign_server) GETSTRUCT(tp);
	srvId = srvForm->oid;

	/*
	 * Only owner or a superuser can ALTER a SERVER.
	 */
	if (!object_ownercheck(ForeignServerRelationId, srvId, GetUserId()))
		aclcheck_error(ACLCHECK_NOT_OWNER, OBJECT_FOREIGN_SERVER,
					   stmt->servername);

	memset(repl_val, 0, sizeof(repl_val));
	memset(repl_null, false, sizeof(repl_null));
	memset(repl_repl, false, sizeof(repl_repl));

	if (stmt->has_version)
	{
		/*
		 * Change the server VERSION string.
		 */
		if (stmt->version)
			repl_val[Anum_pg_foreign_server_srvversion - 1] =
				CStringGetTextDatum(stmt->version);
		else
			repl_null[Anum_pg_foreign_server_srvversion - 1] = true;

		repl_repl[Anum_pg_foreign_server_srvversion - 1] = true;
	}

	if (stmt->options)
	{
		ForeignDataWrapper *fdw = GetForeignDataWrapper(srvForm->srvfdw);
		Datum		datum;
		bool		isnull;

		/* Extract the current srvoptions */
		datum = SysCacheGetAttr(FOREIGNSERVEROID,
								tp,
								Anum_pg_foreign_server_srvoptions,
								&isnull);
		if (isnull)
			datum = PointerGetDatum(NULL);

		/* Prepare the options array */
		datum = transformGenericOptions(ForeignServerRelationId,
										datum,
										stmt->options,
										fdw->fdwvalidator);

		if (PointerIsValid(DatumGetPointer(datum)))
			repl_val[Anum_pg_foreign_server_srvoptions - 1] = datum;
		else
			repl_null[Anum_pg_foreign_server_srvoptions - 1] = true;

		repl_repl[Anum_pg_foreign_server_srvoptions - 1] = true;
	}

	/* Everything looks good - update the tuple */
	tp = heap_modify_tuple(tp, RelationGetDescr(rel),
						   repl_val, repl_null, repl_repl);

	CatalogTupleUpdate(rel, &tp->t_self, tp);

	InvokeObjectPostAlterHook(ForeignServerRelationId, srvId, 0);

	ObjectAddressSet(address, ForeignServerRelationId, srvId);

	heap_freetuple(tp);

	table_close(rel, RowExclusiveLock);

	return address;
}


/*
 * Common routine to check permission for user-mapping-related DDL
 * commands.  We allow server owners to operate on any mapping, and
 * users to operate on their own mapping.
 */
static void
user_mapping_ddl_aclcheck(Oid umuserid, Oid serverid, const char *servername)
{
	Oid			curuserid = GetUserId();

	if (!object_ownercheck(ForeignServerRelationId, serverid, curuserid))
	{
		if (umuserid == curuserid)
		{
			AclResult	aclresult;

			aclresult = object_aclcheck(ForeignServerRelationId, serverid, curuserid, ACL_USAGE);
			if (aclresult != ACLCHECK_OK)
				aclcheck_error(aclresult, OBJECT_FOREIGN_SERVER, servername);
		}
		else
			aclcheck_error(ACLCHECK_NOT_OWNER, OBJECT_FOREIGN_SERVER,
						   servername);
	}
}


/*
 * Create user mapping
 */
ObjectAddress
CreateUserMapping(CreateUserMappingStmt *stmt)
{
	Relation	rel;
	Datum		useoptions;
	Datum		values[Natts_pg_user_mapping];
	bool		nulls[Natts_pg_user_mapping];
	HeapTuple	tuple;
	Oid			useId;
	Oid			umId;
	ObjectAddress myself;
	ObjectAddress referenced;
	ForeignServer *srv;
	ForeignDataWrapper *fdw;
	RoleSpec   *role = (RoleSpec *) stmt->user;

	rel = table_open(UserMappingRelationId, RowExclusiveLock);

	if (role->roletype == ROLESPEC_PUBLIC)
		useId = ACL_ID_PUBLIC;
	else
		useId = get_rolespec_oid(stmt->user, false);

	/* Check that the server exists. */
	srv = GetForeignServerByName(stmt->servername, false);

	user_mapping_ddl_aclcheck(useId, srv->serverid, stmt->servername);

	/*
	 * Check that the user mapping is unique within server.
	 */
	umId = GetSysCacheOid2(USERMAPPINGUSERSERVER, Anum_pg_user_mapping_oid,
						   ObjectIdGetDatum(useId),
						   ObjectIdGetDatum(srv->serverid));

	if (OidIsValid(umId))
	{
		if (stmt->if_not_exists)
		{
			/*
			 * Since user mappings aren't members of extensions (see comments
			 * below), no need for checkMembershipInCurrentExtension here.
			 */
			ereport(NOTICE,
					(errcode(ERRCODE_DUPLICATE_OBJECT),
					 errmsg("user mapping for \"%s\" already exists for server \"%s\", skipping",
							MappingUserName(useId),
							stmt->servername)));

			table_close(rel, RowExclusiveLock);
			return InvalidObjectAddress;
		}
		else
			ereport(ERROR,
					(errcode(ERRCODE_DUPLICATE_OBJECT),
					 errmsg("user mapping for \"%s\" already exists for server \"%s\"",
							MappingUserName(useId),
							stmt->servername)));
	}

	fdw = GetForeignDataWrapper(srv->fdwid);

	/*
	 * Insert tuple into pg_user_mapping.
	 */
	memset(values, 0, sizeof(values));
	memset(nulls, false, sizeof(nulls));

	umId = GetNewOidWithIndex(rel, UserMappingOidIndexId,
							  Anum_pg_user_mapping_oid);
	values[Anum_pg_user_mapping_oid - 1] = ObjectIdGetDatum(umId);
	values[Anum_pg_user_mapping_umuser - 1] = ObjectIdGetDatum(useId);
	values[Anum_pg_user_mapping_umserver - 1] = ObjectIdGetDatum(srv->serverid);

	/* Add user options */
	useoptions = transformGenericOptions(UserMappingRelationId,
										 PointerGetDatum(NULL),
										 stmt->options,
										 fdw->fdwvalidator);

	if (PointerIsValid(DatumGetPointer(useoptions)))
		values[Anum_pg_user_mapping_umoptions - 1] = useoptions;
	else
		nulls[Anum_pg_user_mapping_umoptions - 1] = true;

	tuple = heap_form_tuple(rel->rd_att, values, nulls);

	CatalogTupleInsert(rel, tuple);

	heap_freetuple(tuple);

	/* Add dependency on the server */
	myself.classId = UserMappingRelationId;
	myself.objectId = umId;
	myself.objectSubId = 0;

	referenced.classId = ForeignServerRelationId;
	referenced.objectId = srv->serverid;
	referenced.objectSubId = 0;
	recordDependencyOn(&myself, &referenced, DEPENDENCY_NORMAL);

	if (OidIsValid(useId))
	{
		/* Record the mapped user dependency */
		recordDependencyOnOwner(UserMappingRelationId, umId, useId);
	}

	/*
	 * Perhaps someday there should be a recordDependencyOnCurrentExtension
	 * call here; but since roles aren't members of extensions, it seems like
	 * user mappings shouldn't be either.  Note that the grammar and pg_dump
	 * would need to be extended too if we change this.
	 */

	/* Post creation hook for new user mapping */
	InvokeObjectPostCreateHook(UserMappingRelationId, umId, 0);

	table_close(rel, RowExclusiveLock);

	return myself;
}


/*
 * Alter user mapping
 */
ObjectAddress
AlterUserMapping(AlterUserMappingStmt *stmt)
{
	Relation	rel;
	HeapTuple	tp;
	Datum		repl_val[Natts_pg_user_mapping];
	bool		repl_null[Natts_pg_user_mapping];
	bool		repl_repl[Natts_pg_user_mapping];
	Oid			useId;
	Oid			umId;
	ForeignServer *srv;
	ObjectAddress address;
	RoleSpec   *role = (RoleSpec *) stmt->user;

	rel = table_open(UserMappingRelationId, RowExclusiveLock);

	if (role->roletype == ROLESPEC_PUBLIC)
		useId = ACL_ID_PUBLIC;
	else
		useId = get_rolespec_oid(stmt->user, false);

	srv = GetForeignServerByName(stmt->servername, false);

	umId = GetSysCacheOid2(USERMAPPINGUSERSERVER, Anum_pg_user_mapping_oid,
						   ObjectIdGetDatum(useId),
						   ObjectIdGetDatum(srv->serverid));
	if (!OidIsValid(umId))
		ereport(ERROR,
				(errcode(ERRCODE_UNDEFINED_OBJECT),
				 errmsg("user mapping for \"%s\" does not exist for server \"%s\"",
						MappingUserName(useId), stmt->servername)));

	user_mapping_ddl_aclcheck(useId, srv->serverid, stmt->servername);

	tp = SearchSysCacheCopy1(USERMAPPINGOID, ObjectIdGetDatum(umId));

	if (!HeapTupleIsValid(tp))
		elog(ERROR, "cache lookup failed for user mapping %u", umId);

	memset(repl_val, 0, sizeof(repl_val));
	memset(repl_null, false, sizeof(repl_null));
	memset(repl_repl, false, sizeof(repl_repl));

	if (stmt->options)
	{
		ForeignDataWrapper *fdw;
		Datum		datum;
		bool		isnull;

		/*
		 * Process the options.
		 */

		fdw = GetForeignDataWrapper(srv->fdwid);

		datum = SysCacheGetAttr(USERMAPPINGUSERSERVER,
								tp,
								Anum_pg_user_mapping_umoptions,
								&isnull);
		if (isnull)
			datum = PointerGetDatum(NULL);

		/* Prepare the options array */
		datum = transformGenericOptions(UserMappingRelationId,
										datum,
										stmt->options,
										fdw->fdwvalidator);

		if (PointerIsValid(DatumGetPointer(datum)))
			repl_val[Anum_pg_user_mapping_umoptions - 1] = datum;
		else
			repl_null[Anum_pg_user_mapping_umoptions - 1] = true;

		repl_repl[Anum_pg_user_mapping_umoptions - 1] = true;
	}

	/* Everything looks good - update the tuple */
	tp = heap_modify_tuple(tp, RelationGetDescr(rel),
						   repl_val, repl_null, repl_repl);

	CatalogTupleUpdate(rel, &tp->t_self, tp);

	InvokeObjectPostAlterHook(UserMappingRelationId,
							  umId, 0);

	ObjectAddressSet(address, UserMappingRelationId, umId);

	heap_freetuple(tp);

	table_close(rel, RowExclusiveLock);

	return address;
}


/*
 * Drop user mapping
 */
Oid
RemoveUserMapping(DropUserMappingStmt *stmt)
{
	ObjectAddress object;
	Oid			useId;
	Oid			umId;
	ForeignServer *srv;
	RoleSpec   *role = (RoleSpec *) stmt->user;

	if (role->roletype == ROLESPEC_PUBLIC)
		useId = ACL_ID_PUBLIC;
	else
	{
		useId = get_rolespec_oid(stmt->user, stmt->missing_ok);
		if (!OidIsValid(useId))
		{
			/*
			 * IF EXISTS specified, role not found and not public. Notice this
			 * and leave.
			 */
			elog(NOTICE, "role \"%s\" does not exist, skipping",
				 role->rolename);
			return InvalidOid;
		}
	}

	srv = GetForeignServerByName(stmt->servername, true);

	if (!srv)
	{
		if (!stmt->missing_ok)
			ereport(ERROR,
					(errcode(ERRCODE_UNDEFINED_OBJECT),
					 errmsg("server \"%s\" does not exist",
							stmt->servername)));
		/* IF EXISTS, just note it */
		ereport(NOTICE,
				(errmsg("server \"%s\" does not exist, skipping",
						stmt->servername)));
		return InvalidOid;
	}

	umId = GetSysCacheOid2(USERMAPPINGUSERSERVER, Anum_pg_user_mapping_oid,
						   ObjectIdGetDatum(useId),
						   ObjectIdGetDatum(srv->serverid));

	if (!OidIsValid(umId))
	{
		if (!stmt->missing_ok)
			ereport(ERROR,
					(errcode(ERRCODE_UNDEFINED_OBJECT),
					 errmsg("user mapping for \"%s\" does not exist for server \"%s\"",
							MappingUserName(useId), stmt->servername)));

		/* IF EXISTS specified, just note it */
		ereport(NOTICE,
				(errmsg("user mapping for \"%s\" does not exist for server \"%s\", skipping",
						MappingUserName(useId), stmt->servername)));
		return InvalidOid;
	}

	user_mapping_ddl_aclcheck(useId, srv->serverid, srv->servername);

	/*
	 * Do the deletion
	 */
	object.classId = UserMappingRelationId;
	object.objectId = umId;
	object.objectSubId = 0;

	performDeletion(&object, DROP_CASCADE, 0);

	return umId;
}


/*
 * Create a foreign table
 * call after DefineRelation().
 */
void
CreateForeignTable(CreateForeignTableStmt *stmt, Oid relid)
{
	Relation	ftrel;
	Datum		ftoptions;
	Datum		values[Natts_pg_foreign_table];
	bool		nulls[Natts_pg_foreign_table];
	HeapTuple	tuple;
	AclResult	aclresult;
	ObjectAddress myself;
	ObjectAddress referenced;
	Oid			ownerId;
	ForeignDataWrapper *fdw;
	ForeignServer *server;

	/*
	 * Advance command counter to ensure the pg_attribute tuple is visible;
	 * the tuple might be updated to add constraints in previous step.
	 */
	CommandCounterIncrement();

	ftrel = table_open(ForeignTableRelationId, RowExclusiveLock);

	/*
	 * For now the owner cannot be specified on create. Use effective user ID.
	 */
	ownerId = GetUserId();

	/*
	 * Check that the foreign server exists and that we have USAGE on it. Also
	 * get the actual FDW for option validation etc.
	 */
	server = GetForeignServerByName(stmt->servername, false);
	aclresult = object_aclcheck(ForeignServerRelationId, server->serverid, ownerId, ACL_USAGE);
	if (aclresult != ACLCHECK_OK)
		aclcheck_error(aclresult, OBJECT_FOREIGN_SERVER, server->servername);

	fdw = GetForeignDataWrapper(server->fdwid);

	/*
	 * Insert tuple into pg_foreign_table.
	 */
	memset(values, 0, sizeof(values));
	memset(nulls, false, sizeof(nulls));

	values[Anum_pg_foreign_table_ftrelid - 1] = ObjectIdGetDatum(relid);
	values[Anum_pg_foreign_table_ftserver - 1] = ObjectIdGetDatum(server->serverid);
	/* Add table generic options */
	ftoptions = transformGenericOptions(ForeignTableRelationId,
										PointerGetDatum(NULL),
										stmt->options,
										fdw->fdwvalidator);

	if (PointerIsValid(DatumGetPointer(ftoptions)))
		values[Anum_pg_foreign_table_ftoptions - 1] = ftoptions;
	else
		nulls[Anum_pg_foreign_table_ftoptions - 1] = true;

	tuple = heap_form_tuple(ftrel->rd_att, values, nulls);

	CatalogTupleInsert(ftrel, tuple);

	heap_freetuple(tuple);

	/* Add pg_class dependency on the server */
	myself.classId = RelationRelationId;
	myself.objectId = relid;
	myself.objectSubId = 0;

	referenced.classId = ForeignServerRelationId;
	referenced.objectId = server->serverid;
	referenced.objectSubId = 0;
	recordDependencyOn(&myself, &referenced, DEPENDENCY_NORMAL);

	table_close(ftrel, RowExclusiveLock);
}

#ifdef PGSPIDER
/**
 * spd_FdwExecForeignDDL
 *
 * Call the public function ExecForeignDLL which is defined in FDW
 */
static void
spd_FdwExecForeignDDL(RangeVar *relvar, ForeignDDLType operation, bool exists_flag)
{
	AclResult	aclresult;
	Oid			ownerId;
	ForeignDataWrapper *fdw;
	ForeignServer *server;
	char	   *fdwlib_name = NULL;
	ExecForeignDDL infofunc;
	Relation	rel;
	Oid			relid;

	/*
	 * For now the owner cannot be specified on create. Use effective user ID.
	 */
	ownerId = GetUserId();

	/* Get relation OID */
	rel = table_openrv(relvar, AccessShareLock);

	if (rel->rd_rel->relkind != RELKIND_FOREIGN_TABLE)
		elog(ERROR, "%s DATASOURCE TABLE command support only for FOREIGN TABLE", (operation == SPD_CMD_CREATE) ? "CREATE" : "DROP");

	relid = RelationGetRelid(rel);
	aclresult = pg_class_aclcheck(relid, ownerId, ACL_SELECT);
	if (aclresult != ACLCHECK_OK)
		aclcheck_error(aclresult, get_relkind_objtype(rel->rd_rel->relkind),
						RelationGetRelationName(rel));

	/*
	 * Get foreign server from relid
	 */
	server = GetForeignServer(GetForeignServerIdByRelId(relid));

	aclresult = object_aclcheck(ForeignServerRelationId, server->serverid, ownerId, ACL_USAGE);
	if (aclresult != ACLCHECK_OK)
		aclcheck_error(aclresult, OBJECT_FOREIGN_SERVER, server->servername);

	/* Get foreign fdw */
	fdw = GetForeignDataWrapper(server->fdwid);

	/* Support foreign tables only */
	if (strcmp(fdw->fdwname, "pgspider_core_fdw") == 0)
	{
		elog(ERROR, "Does not support %s DATASOURCE TABLE command for multitenant foreign table.", (operation == SPD_CMD_CREATE) ? "CREATE" : "DROP");
	}

	/* Create fdw lib name simply by fdw name */
	fdwlib_name = psprintf("$libdir/%s", fdw->fdwname);

	/* Try to look up the info function */
	infofunc = (ExecForeignDDL) load_external_function(fdwlib_name, "ExecForeignDDL", false, NULL);
	if (infofunc == NULL)
		elog(ERROR, "%s does not support DDL commands", fdw->fdwname);

	if (infofunc == NULL)
		elog(ERROR, "%s does not support DDL commands", fdw->fdwname);

	/* Call ExecForeignDDL() */
	(int)(*infofunc) (server->serverid, rel, (int)operation, exists_flag);

	table_close(rel, AccessShareLock);
}

/**
 * @brief Convert type OID + typmod info into a type name we can ship to the remote server
 *
 * @param[in] type_oid
 * @param[in] typemod
 * @return char*
 */
static char *
spd_deparse_type_name(Oid type_oid, int32 typemod)
{
	bits16		flags = FORMAT_TYPE_TYPEMOD_GIVEN;

	if (!(type_oid < FirstGenbkiObjectId))
		flags |= FORMAT_TYPE_FORCE_QUALIFY;

	return format_type_extended(type_oid, typemod, flags);
}

/**
 * @brief Generate a string of column with the format "c1, c2, c3, ...".
 *        It will be helpful for INSERT/SELECT data, CREATE table.
 *
 * @param[in] rel relation
 * @param[in] add_col_info add more information to column
 * @param[in] ncol number of column
 * @param[in] need_spdurl need to create column __spd_url or not
 * @return char*
 */
static char *
spd_deparse_column_list(Relation rel, bool add_col_info, int *ncol, bool need_spdurl)
{
	StringInfoData cols;
	TupleDesc	tupdesc = RelationGetDescr(rel);
	int			i;
	bool		first = true;
	char	   *colname;
	int			cnt = 0;

	initStringInfo(&cols);

	/* deparse column */
	for (i = 0; i < tupdesc->natts; i++)
	{
		Form_pg_attribute att = TupleDescAttr(tupdesc, i);

		/* Ignore dropped columns. */
		if (att->attisdropped)
			continue;

		/*
		 * Currently, we don't have any information about column option for each FDW,
		 * So let's ignore it for consistency.
		 */
		colname = NameStr(att->attname);

		/* Ignore __spd_url column, if request */
		if (!need_spdurl && strcmp(colname, "__spd_url") == 0)
			continue;

		if (!first)
			appendStringInfoString(&cols, ", ");
		first = false;

		appendStringInfo(&cols, "%s", quote_identifier(colname));

		/* append more column information: type, not null, default value... */
		if (add_col_info)
		{
			appendStringInfo(&cols, " %s", spd_deparse_type_name(att->atttypid, att->atttypmod));

			/* att is NOT NULL */
			if (att->attnotnull)
				appendStringInfo(&cols, " NOT NULL");

			if (OidIsValid(att->attcollation))
			{
				char	   *collname = get_collation_name(att->attcollation);

				if (collname == NULL)
					elog(ERROR, "cache lookup failed for collation %u", att->attcollation);
				appendStringInfo(&cols, " COLLATE %s", quote_identifier(collname));
			}
			/* TODO:
			 *     At the moment we support NOT NULL option of a column when creating a datasource table.
			 *     In the future, we may support more column option.
			 */
		}
		cnt++;
	}

	if (ncol)
		*ncol = cnt;

	return cols.data;
}

/**
 * @brief Get the table mapping option name object for given servername
 *
 * @param[in] fdw_name foreign data wrapper name
 * @return char*
 */
static char *
spd_get_table_mapping_option_name(ForeignServer *server)
{
	char *fdwname = GetForeignDataWrapper(server->fdwid)->fdwname;

	/*
	 * TODO:
	 *     In the future we may support more fdws,
	 *     so we add code prototype for other FDWs here to help developer maintain code more easily.
	 */
	if (strcmp(fdwname, "mongo_fdw") == 0)
		return "collection";
	else if (strcmp(fdwname, "parquet_s3_fdw") == 0)
		return "dirname";
	else if (strcmp(fdwname, "influxdb_fdw") == 0 || strcmp(fdwname, "oracle_fdw") == 0)
		return "table";
	else
		return "table_name";
}

/**
 * @brief Get the datasource table name object
 *
 * @param[in] rel relation
 * @return char*
 */
static char *
spd_get_datasource_table_name(Relation rel)
{
	ForeignTable   *table;
	ForeignServer  *server;
	ListCell	   *lc;
	char		   *table_mapping_opt;

	/* Return source table name if it not a FOREIGN TABLE */
	if (rel->rd_rel->relkind == RELKIND_FOREIGN_TABLE)
	{
		table = GetForeignTable(RelationGetRelid(rel));
		server =  GetForeignServer(table->serverid);

		table_mapping_opt = spd_get_table_mapping_option_name(server);

		foreach (lc, table->options)
		{
			DefElem	*od = lfirst(lc);

			if (strcmp(table_mapping_opt, od->defname) == 0)
				return defGetString(od);
		}
	}

	/* There is no table mapping option, this mean datasource table and foreign table has same name */
	return RelationGetRelationName(rel);
}

/**
 * @brief get full name of relation including schema name and table name
 *
 * @param[in] rel relation
 * @return char*
 */
static char *
spd_relation_get_full_name(Relation rel)
{
	char	   *nspname;
	char	   *relname;

	/*
	 * Note: we could skip printing the schema name if it's pg_catalog, but
	 * that doesn't seem worth the trouble.
	 */
	nspname = get_namespace_name(RelationGetNamespace(rel));
	relname = RelationGetRelationName(rel);

	return psprintf("%s.%s", quote_identifier(nspname), quote_identifier(relname));
}

/**
 * @brief Check if the option should be skipped for specific fdw
 *
 * @param[in] fdw_name foreign data wrapper name
 * @param[in] option option name
 * @return bool
 */
static bool
spd_skip_fdw_option(char *fdw_name, char *option)
{
	/*
	 * The following option cannot be passed into specific fdw.
	 * For example, influxdb_fdw does not support "org" option.
	 * It is added only for support data compression transfer feature.
	 * Therefore, it should be skipped for influxdb_fdw.
	 */
	if (strcmp(fdw_name, "influxdb_fdw") == 0 && strcmp(option, "org") == 0)
		return true;
	else
		return false;
}

/**
 * @brief create CREATE FOREIGN TABLE command
 *
 * @param buf returned sql
 * @param srcrel relation
 * @param table_name foreign table name
 * @param server foreign table server info
 * @param need_spdurl flag to specify __spd_url column is needed or not
 * @param relay relay server name for data migrate transfer feature
 */
static char *
spd_deparse_create_foreign_table_sql(Relation srcrel, char *table_name, MigrateServerItem * server, bool need_spdurl, char *relay)
{
	ListCell   *optcell;
	bool		first = true;
	bool		has_table_mapping_opt = false;
	int			batch_size = 0;
	char	   *table_mapping_opt;
	StringInfoData buf;
	char	   *server_name;
	Oid			serverID = InvalidOid;
	Oid			userID = InvalidOid;
	ForeignDataWrapper *fdw;

	if (relay == NULL)
	{
		ForeignServer *fs_target;

		server_name = server->dest_server_name;
		fs_target = GetForeignServerByName(server->dest_server_name, false);
		/* Get target fdw */
		fdw = GetForeignDataWrapper(fs_target->fdwid);
	}
	else
	{
		ForeignServer *fs_target;
		ForeignServer *fs_relay;

		server_name = relay;

		/* Get userID and serverID of target server */
		fs_target = GetForeignServerByName(server->dest_server_name, false);
		serverID = fs_target->serverid;
		userID = fs_target->owner;

		fs_relay = GetForeignServerByName(relay, false);

		/* Get relay fdw */
		fdw = GetForeignDataWrapper(fs_relay->fdwid);

		/* check batch_size exists in relay server */
		foreach(optcell, fs_relay->options)
		{
			DefElem    *def = (DefElem *) lfirst(optcell);

			if (strcmp(def->defname, "batch_size") == 0)
			{
				(void) parse_int(defGetString(def), &batch_size, 0, NULL);
				break;
			}
		}

		if (batch_size == 1)
			elog(ERROR, "batch_size for Data Compression Transfer Feature must be larger than 1");
	}

	initStringInfo(&buf);

	/* create new foreign table inherit from source table */
	/* do not support MIGRATE data to existed table: do not use IF NOT EXISTS */
	appendStringInfo(&buf, "CREATE FOREIGN TABLE %s (", table_name);

	/* deparse column */
	appendStringInfo(&buf, "%s", spd_deparse_column_list(srcrel, true, NULL, need_spdurl));

	/* append server name */
	appendStringInfo(&buf, ") SERVER %s", quote_identifier(server_name));

	/* get table mapping option of dest server */
	table_mapping_opt = spd_get_table_mapping_option_name(GetForeignServerByName(server_name, false));

	appendStringInfoString(&buf, " OPTIONS (");

	/* Add server options */
	foreach(optcell, server->dest_server_options)
	{
		DefElem    *od = lfirst(optcell);

		if (strcmp(od->defname, "relay") == 0)
			continue;

		/* If options cannot be passed into fdw, skip it */
		if (spd_skip_fdw_option(fdw->fdwname, od->defname))
			continue;

		if (!first)
			appendStringInfoString(&buf, ",");

		if (strcmp(table_mapping_opt, od->defname) == 0)
			has_table_mapping_opt = true;

		first = false;

		/* Treat all server options as string values */
		appendStringInfo(&buf, "%s '%s'", od->defname, defGetString(od));
	}

	/* append table mapping option if needed */
	if (!has_table_mapping_opt)
	{
		if (!first)
			appendStringInfoString(&buf, ", ");

		appendStringInfo(&buf, "%s '%s'", table_mapping_opt, spd_get_datasource_table_name(srcrel));

		first = false;
	}

	/* append serverID and userID of target server */
	if (relay != NULL)
	{
		if (!first)
			appendStringInfoString(&buf, ", ");

		appendStringInfo(&buf, "serverid '%d', userid '%d'", serverID, userID);
		appendStringInfoString(&buf, ", ");

		/* batch_size not set in relay server */
		if (batch_size == 0)
			appendStringInfo(&buf, "batch_size '%d'", DCT_DEFAULT_BATCH_SIZE);
		else
			appendStringInfo(&buf, "batch_size '%d'", batch_size);
	}

	appendStringInfoString(&buf, ");");

	return buf.data;
}

/*
 * Get child index for creating child foreign table.
 * In case of multi-tenant table, we need to create many child foreign tables.
 * The syntax for table name is [table__servername__idx]. For example, t1__post_svr__0, t1__post_svr__1,...
 */
static int
spd_server_get_child_idx(child_server_info **svr_list, char *svr_name)
{
	if (svr_list == NULL)
		return -1;
	/* Create new server info node */
	if (*svr_list == NULL)
	{
		child_server_info *new_svr = (child_server_info *) palloc0(sizeof(child_server_info));
		new_svr->server_name = pstrdup(svr_name);
		new_svr->child_table_cnt = 1;
		(*svr_list) = new_svr;

		return 0;
	}

	if (strcmp((*svr_list)->server_name, svr_name) == 0)
	{
		return (*svr_list)->child_table_cnt++;
	}
	else
	{
		return spd_server_get_child_idx(&(*svr_list)->next, svr_name);
	}
}

/**
 * @brief add a query and its corresponding clean-up when an error occurs to migrate list command;
 *
 * @param context
 * @param query
 * @param clean_query
 */
static void
spd_add_query(migrate_cmd_context *context,
			  char *query,
			  char *clean_query)
{
	Assert(query != NULL && clean_query != NULL);

	context->commands = lappend(context->commands, query);
	context->cleanup_commands = lappend(context->cleanup_commands, clean_query);
}

/**
 * @brief Check whether that server_name is pgspider_core_fdw server or not
 * 		  and create new server if not existed
 *
 * @param context
 */
static void
spd_multitenant_server_validation(migrate_cmd_context *context)
{
	char		   *server_name = context->use_multitenant_server;
	ForeignServer  *server = GetForeignServerByName(server_name, true);

	if (server == NULL)
	{
		/*
		 * Create a new server if not exists.
		 * New server will be dropped if an error occurs.
		 */
		spd_add_query(context,
					  psprintf("CREATE SERVER %s FOREIGN DATA WRAPPER pgspider_core_fdw;", quote_identifier(server_name)),
					  psprintf("DROP SERVER %s CASCADE;", quote_identifier(server_name)));
	}
	else
	{
		/* Get foreign fdw */
		ForeignDataWrapper *fdw = GetForeignDataWrapper(server->fdwid);

		if (strcmp(fdw->fdwname, "pgspider_core_fdw") != 0)
			elog(ERROR, "PGSpider: %s is not a multitenant server.", server_name);
	}
}

/**
 * @brief Create a query which can drop all child table of a multitenant table
 *
 * @param foreigntableid multitenant table oid
 * @return char* query
 */
static char *
spd_build_drop_child_table_query(Oid foreigntableid)
{
	char		query[1024];

	sprintf(query, "DO "
				   "$$ "
				   "DECLARE "
				   "    table_rec record; "
				   "BEGIN "
				   "    FOR table_rec IN ("
				   "        WITH srv AS "
				   "            (SELECT srvname FROM pg_foreign_table ft "
				   "                JOIN pg_foreign_server fs ON ft.ftserver = fs.oid GROUP BY srvname ORDER BY srvname),"
				   "        regex_pattern AS "
				   "            (SELECT '^' || relname || '\\_\\_' || srv.srvname  || '\\_\\_[0-9]+$' regex FROM pg_class "
				   "                CROSS JOIN srv WHERE oid = %u)"
				   "        SELECT relname AS tname FROM pg_class "
				   "            WHERE (relname ~ ANY(SELECT regex FROM regex_pattern)) "
				   "              AND (relname NOT LIKE '%%\\_%%\\_seq') "
				   "            ORDER BY relname"
				   "    )"
				   "    LOOP "
				   "        EXECUTE 'DROP FOREIGN TABLE '||table_rec.tname||' CASCADE';"
				   "    END LOOP; "
				   "END; "
				   "$$;", foreigntableid);
	return pstrdup(query);
}

/**
 * @brief check wether relation is a multitenant table or not
 *
 * @param rel
 */
static bool
spd_is_multitenant_table(Relation rel)
{
	AclResult		aclresult;
	ForeignServer  *src_server = NULL;
	ForeignDataWrapper *fdw = NULL;
	Oid				ownerId = GetUserId();

	if (rel->rd_rel->relkind == RELKIND_FOREIGN_TABLE)
	{
		/*
		 * Get foreign server from relid
		 */
		src_server = GetForeignServer(GetForeignServerIdByRelId(RelationGetRelid(rel)));

		aclresult = object_aclcheck(ForeignServerRelationId, src_server->serverid, ownerId, ACL_USAGE);
		if (aclresult != ACLCHECK_OK)
			aclcheck_error(aclresult, OBJECT_FOREIGN_SERVER, src_server->servername);

		/* Get foreign fdw */
		fdw = GetForeignDataWrapper(src_server->fdwid);

		if (strcmp(fdw->fdwname, "pgspider_core_fdw") == 0)
		{
			return true;
		}
	}

	return false;
}

/**
 * @brief create list command to create destination table of migrate command
 *
 * @param stmt
 * @param src_rel
 * @param context
 */
static void
spd_create_migrate_dest_table(MigrateTableStmt *stmt,
							  Relation src_rel,
							  migrate_cmd_context *context, List **relay_command_list)
{
	char	   *dest_ftable_namespace;
	child_server_info *child_svr_list = NULL;
	child_server_info *child_relay_svr_list = NULL;
	ListCell   *lc;
	char	   *collist = NULL;
	char	   *multitenant_table;
	bool		data_compression_transfer_enabled = false;

	/* create destination foreign table name */
	if (stmt->dest_relation)
	{
		/* check dest relation exist */
		if (RangeVarGetRelid(stmt->dest_relation, NoLock, true) != InvalidOid)
			elog(ERROR, "Destination table already existed!");

		/* destination foreign table create from MIGRATE command information */
		context->dest_table_name = stmt->dest_relation->relname;
		dest_ftable_namespace = stmt->dest_relation->schemaname ? stmt->dest_relation->schemaname : "public";
		context->dest_table_fullname = psprintf("%s.%s", quote_identifier(dest_ftable_namespace),
												 quote_identifier(context->dest_table_name));
	}
	else
	{
		/*
		 * Because we can not create a new foreign table which has the same name with source table,
		 * so using default table name with the syntax [temp_prefix]_[source_table_name] and rename/remove it after migration.
		 * Rename in case migrate type is MIGRATE_REPLACE, remove in case migrate type is MIGRATE_NONE
		 */
		context->dest_table_name = psprintf("%s%s", context->temp_prefix, RelationGetRelationName(src_rel));
		dest_ftable_namespace = get_namespace_name(RelationGetNamespace(src_rel));
		context->dest_table_fullname = psprintf("%s.%s", quote_identifier(dest_ftable_namespace),
												 quote_identifier(context->dest_table_name));
	}

	/* Get column information of source table */
	collist = spd_deparse_column_list(src_rel, true, NULL, false);

	/*
	 * If there is any destination server that provide relay option
	 * data compression transfer feature is activated.
	 */
	foreach (lc, stmt->dest_server_list)
	{
		MigrateServerItem *dest_server_item = (MigrateServerItem *) lfirst(lc);

		foreach(lc, dest_server_item->dest_server_options)
		{
			DefElem    *def = (DefElem *) lfirst(lc);
			if (strcmp(def->defname, "relay") == 0)
			{
				data_compression_transfer_enabled = true;
				break;
			}
		}

		if (data_compression_transfer_enabled)
			break;
	}

	/*
	 * We use multitenant table to migrate data from src table to destination datasource.
	 * Destination table type will be change (if needed) when migrate done.
	 * This foreign table must be dropped if any next queries fail.
	 */
	if (data_compression_transfer_enabled)
	{
		StringInfoData options;
		initStringInfo(&options);
		
		/*
		 * pgspider_fdw notify public_host to function in compression transfer
		 */
		if (context->public_host)
		{
			appendStringInfo(&options, ", public_host '%s'", context->public_host);
		}

		/* Default public_port is socket_port
		 * psgpider_fdw notify public_port to function in compression transfer
		 * pgspider_core_fdw listen socket_port
		 */
		if (context->public_port != context->socket_port)
		{
			appendStringInfo(&options, ", public_port '%d'", context->public_port);
		}

		/*
		 * pgspider_fdw get ip from ifconfig_service then notify to function in compression transfer
		 */
		if (context->ifconfig_service)
		{
			appendStringInfo(&options, ", ifconfig_service '%s'", context->ifconfig_service);
		}
		
		multitenant_table = psprintf("CREATE FOREIGN TABLE %s(%s, __spd_url text) SERVER %s OPTIONS (socket_port '%d', function_timeout '%d' %s);",
										context->dest_table_fullname, collist,
										quote_identifier(context->use_multitenant_server),
										context->socket_port, 
										context->function_timeout,
										options.data);
	}
	else
	{
		multitenant_table =  psprintf("CREATE FOREIGN TABLE %s(%s, __spd_url text) SERVER %s;",
								context->dest_table_fullname, collist,
								quote_identifier(context->use_multitenant_server));
	}

	spd_add_query(context,
				multitenant_table,
				psprintf("DROP FOREIGN TABLE %s;", context->dest_table_fullname));

	/* Create child foreign tables */
	foreach (lc, stmt->dest_server_list)
	{
		MigrateServerItem *dest_server_item;
		char	   *child_table_name;
		int			child_idx;
		int			child_idx_relay_server;
		char	   *relay = NULL;
		char	   *sql_drop_table_child_foreign_table;
		char	   *sql_create_table_child_foreign_table;

		dest_server_item = (MigrateServerItem *) lfirst(lc);
		child_idx = spd_server_get_child_idx(&child_svr_list, dest_server_item->dest_server_name);

		child_table_name = psprintf("%s__%s__%d", context->dest_table_name, dest_server_item->dest_server_name, child_idx);
		context->dest_child_table_names = lappend(context->dest_child_table_names, child_table_name);

		child_table_name = psprintf("%s.%s", quote_identifier(dest_ftable_namespace), quote_identifier(child_table_name));
		/* save the new child table full name to list */
		context->dest_child_table_full_names = lappend(context->dest_child_table_full_names, child_table_name);

		/*
		 * create child foreign table of destination server.
		 * 
		 * For all fdws, remove `relay` option from the list of server options
		 * For influxdb fdw, remove `org` option from the list of server options
		 */
		sql_create_table_child_foreign_table = spd_deparse_create_foreign_table_sql(src_rel, child_table_name, dest_server_item, false, NULL);
		sql_drop_table_child_foreign_table = psprintf("DROP FOREIGN TABLE %s;", child_table_name);

		/* get relay and org option for each child destination server */
		foreach(lc, dest_server_item->dest_server_options)
		{
			DefElem    *def = (DefElem *) lfirst(lc);

			if (strcmp(def->defname, "relay") == 0)
			{
				relay = defGetString(def);
				break;
			}
		}

		if (relay != NULL)
		{
			child_idx_relay_server = spd_server_get_child_idx(&child_relay_svr_list, relay);

			child_table_name = psprintf("%s__%s__%d", context->dest_table_name, relay, child_idx_relay_server);
			child_table_name = psprintf("%s.%s", quote_identifier(dest_ftable_namespace), quote_identifier(child_table_name));

			/* Create foreign table for relay server */
			spd_add_query(context,
						  spd_deparse_create_foreign_table_sql(src_rel, child_table_name, dest_server_item, false, relay),
						  psprintf("DROP FOREIGN TABLE %s;", child_table_name));

			*relay_command_list = lappend(*relay_command_list, psprintf("DROP FOREIGN TABLE %s;", child_table_name));
			*relay_command_list = lappend(*relay_command_list, ";");

			*relay_command_list = lappend(*relay_command_list, sql_create_table_child_foreign_table);
			*relay_command_list = lappend(*relay_command_list, sql_drop_table_child_foreign_table);
		}
		else
		{
			/*
			 * Create child foreign table for multitenant table created above.
			 * This foreign table must be dropped if any next queries fail.
			 */
			spd_add_query(context, sql_create_table_child_foreign_table, sql_drop_table_child_foreign_table);
		}

		/*
		 * Create datasource table, do not support MIGRATE data to existed
		 * table (do not use IF NOT EXISTS) because that table may has data or
		 * different data schema. Datasource table is not existed before, so
		 * we must be drop it if an error occurs. Some fdw does not create a
		 * datasource table at "CREATE DATASOURCE" command, so using "IF
		 * EXISTS" to avoid error.
		 */
		spd_add_query(context,
					  psprintf("CREATE DATASOURCE TABLE %s;", child_table_name),
					  psprintf("DROP DATASOURCE TABLE IF EXISTS %s;", child_table_name));
	}
}

/**
 * @brief In MIGRATE_NONE, all destination foreign table must be remove.
 * 		  This function create command to drop all of them.
 *
 * @param context
 */
static void
spd_drop_temp_table(migrate_cmd_context *context)
{
	ListCell	   *lc;

	/* Create DROP command for all child tables */
	foreach(lc, context->dest_child_table_full_names)
	{
		char *child = lfirst(lc);

		/*
		 * DROP destination child table.
		 * If an error occurs, a ROLLBACK will be execute, so we do not need do anything when an error occurs.
		 */
		spd_add_query(context,
					  psprintf("DROP FOREIGN TABLE %s;", child),
					  ";");
	}

	/*
	 * DROP destination table.
	 * If an error occurs, a ROLLBACK will be execute, so we do not need do anything when an error occurs.
	 */
	spd_add_query(context,
				  psprintf("DROP FOREIGN TABLE %s;", context->dest_table_fullname),
				  ";");
}

/**
 * @brief In MIGRATE_REPLACE, source table will be dropped and
 * 		  replaced by temp destination table.
 *
 * @param src_rel
 * @param context
 */
static void
spd_replace_src_table(Relation src_rel, migrate_cmd_context *context)
{
	char		   *src_table_fullname = context->src_table_fullname;
	StringInfoData	cmd;

	initStringInfo(&cmd);

	/*
	 * If source table is a multitenant table, its child tables must be dropped also.
	 * If an error occurs, a ROLLBACK will be execute, so we do not need do anything when an error occurs.
	 */
	if (context->src_table_is_multitenant)
	{
		spd_add_query(context,
					  spd_build_drop_child_table_query(RelationGetRelid(src_rel)),
					  ";");
	}

	/*
	 * Drop src table.
	 * If an error occurs, a ROLLBACK will be execute, so we do not need do anything when an error occurs.
	 */
	if (src_rel->rd_rel->relkind == RELKIND_FOREIGN_TABLE)
		spd_add_query(context,
					  psprintf("DROP FOREIGN TABLE %s;", src_table_fullname),
					  ";");
	else
		spd_add_query(context,
					  psprintf("DROP TABLE %s;", src_table_fullname),
					  ";");

	/* Rename temp parent table to src table name */
	if (context->dest_table_is_multitenant)
	{
		int 		i;

		/*
		 * Remove "temp_prefix" prefix of destination table.
		 * If an error occurs, a ROLLBACK will be execute, so we do not need do anything when an error occurs.
		 */
		spd_add_query(context,
					  psprintf("ALTER FOREIGN TABLE %s RENAME TO %s;", context->dest_table_fullname, quote_identifier(context->dest_table_name + strlen(context->temp_prefix))),
					  ";");

		/* Rename dest child table */
		for (i = 0; i < list_length(context->dest_child_table_full_names); i++)
		{
			char *rel_name = list_nth(context->dest_child_table_names, i);
			char *rel_fullname = list_nth(context->dest_child_table_full_names, i);

			/*
			 * Remove "temp_prefix" prefix of child table.
			 * If an error occurs, a ROLLBACK will be execute, so we do not need do anything when an error occurs.
			 */
			spd_add_query(context,
						  psprintf("ALTER FOREIGN TABLE %s RENAME TO %s;", rel_fullname, quote_identifier(rel_name + strlen(context->temp_prefix))),
						  ";");
		}
	}
	else
	{
		char	   *child_fullname = lfirst(list_head(context->dest_child_table_full_names));

		Assert(list_length(context->dest_child_table_full_names) == 1);

		/* Change destination table from multitenant table (1 child node) to normal foreign table */

		/*
		 * Drop parent table.
		 * If an error occurs, a ROLLBACK will be execute, so we do not need do anything when an error occurs.
		 */
		spd_add_query(context,
					  psprintf("DROP FOREIGN TABLE %s;", context->dest_table_name),
					  ";");

		/*
		 * Using child table as a foreign table and remove "temp_prefix" prefix.
		 * If an error occurs, a ROLLBACK will be execute, so we do not need do anything when an error occurs.
		 */
		spd_add_query(context,
					  psprintf("ALTER FOREIGN TABLE %s RENAME TO %s;", child_fullname, quote_identifier(context->dest_table_name + strlen(context->temp_prefix))),
					  ";");

	}
}

/**
 * @brief Convert a multitenant table with one child node to a foreign table.
 *
 * @param context
 */
static void
spd_multitenant_table_to_foreign_table(migrate_cmd_context *context)
{
	char	   *child_name;

	Assert(list_length(context->dest_child_table_full_names) == 1);
	child_name = lfirst(list_head(context->dest_child_table_full_names));

	/*
	 * DROP parent table.
	 * If an error occurs, a ROLLBACK will be execute, so we do not need do anything when an error occurs.
	 */
	spd_add_query(context,
				  psprintf("DROP FOREIGN TABLE %s;", context->dest_table_fullname),
				  ";");

	/*
	 * Using child table as a foreign table.
	 * If an error occurs, a ROLLBACK will be execute, so we do not need do anything when an error occurs.
	 */
	spd_add_query(context,
				  psprintf("ALTER FOREIGN TABLE %s RENAME TO %s;", child_name, quote_identifier(context->dest_table_name)),
				  ";");
}

/**
 * @brief Create prefix for temporary table with the syntax: temp_[timestamp]_
 *
 */
static char *
spd_create_temp_table_prefix(void)
{
	return psprintf("temp_%ld_", GetCurrentTimestamp());
}

/**
 * @brief Initialize migrate cmd context.
 *
 * @param context
 */
static void
spd_migrate_context_init(migrate_cmd_context *context)
{
	context->cleanup_commands = NIL;
	context->commands = NIL;
	context->dest_child_table_full_names = NULL;
	context->dest_child_table_names = NULL;
	context->dest_table_fullname = NULL;
	context->dest_table_is_multitenant = false;
	context->dest_table_name = NULL;
	context->src_table_name = NULL;
	context->src_table_fullname = NULL;
	context->src_table_is_multitenant = false;
	context->use_multitenant_server = NULL;
	context->socket_port = DCT_DEFAULT_PORT;
	context->function_timeout = DCT_DEFAULT_FUNCTION_TIMEOUT;
	context->temp_prefix = spd_create_temp_table_prefix();
}

/**
 * @brief  return list equivalent commands and corresponding clean-up command of a MIGTATE cmd.
 *
 * @param stmt Migrate statement
 * @param cmds PostgreSQL original command list required for MIGRATE statement.
 * 			   MIGRATE command using these commands to migrate data from source table to destination server.
 * @param c_cmds PostgreSQL original command list required for clean-up resouce created by MIGRATE command
 * 			     include temporary foreign table, datasource table, ...
 */
void
CreateMigrateCommands(MigrateTableStmt * stmt, List **cmds, List **c_cmds)
{
	AclResult	aclresult;
	Oid			ownerId;
	Relation	src_rel = NULL;
	Oid			src_relid;
	ListCell   *lc;
	char	   *collist = NULL;
	migrate_cmd_context context;
	List	   *relay_command_list = NIL;
	bool        is_public_port_set = false;
	/* context init */
	spd_migrate_context_init(&context);

	/*
	 * For now the owner cannot be specified on create. Use effective user ID.
	 */
	ownerId = GetUserId();

	/* get table OID */
	src_rel = table_openrv(stmt->source_relation, AccessShareLock);

	PG_TRY();
	{
		src_relid = RelationGetRelid(src_rel);
		aclresult = pg_class_aclcheck(src_relid, ownerId, ACL_SELECT);
		if (aclresult != ACLCHECK_OK)
			aclcheck_error(aclresult, get_relkind_objtype(src_rel->rd_rel->relkind),
							RelationGetRelationName(src_rel));

		context.src_table_name = pstrdup(RelationGetRelationName(src_rel));
		context.src_table_fullname = spd_relation_get_full_name(src_rel);
		context.src_table_is_multitenant = spd_is_multitenant_table(src_rel);
		context.public_host = NULL;
		context.public_port = 0;
		context.ifconfig_service = NULL;
		/* Get option USE_MULTITENANT_SERVER */
		foreach(lc, stmt->dest_table_options)
		{
			DefElem    *def = lfirst(lc);

			if (strcmp(def->defname, "use_multitenant_server") == 0)
			{
				context.use_multitenant_server = defGetString(def);
				spd_multitenant_server_validation(&context);
			}
			else if (strcmp(def->defname, "socket_port") == 0)
			{
				(void) parse_int(defGetString(def), &context.socket_port, 0, NULL);
			}
			else if (strcmp(def->defname, "function_timeout") == 0)
			{
				(void) parse_int(defGetString(def), &context.function_timeout, 0, NULL);
			} 
			else if (strcmp(def->defname, "public_host") == 0)
			{
				context.public_host = defGetString(def);
			}
			else if (strcmp(def->defname, "public_port") == 0)
			{
				(void) parse_int(defGetString(def), &context.public_port, 0, NULL);
				is_public_port_set = true;
			}
			else if (strcmp(def->defname, "ifconfig_service") == 0)
			{
				context.ifconfig_service = defGetString(def);
			}
			else
			{
				elog(ERROR, "PGSpider: unexpected option: %s", def->defname);
			}
		}

		if (!is_public_port_set)
		{
			context.public_port = context.socket_port;
		}
		
		if (context.public_host != NULL && context.ifconfig_service != NULL)
		{
			elog(ERROR, "PGSpider: unexpected both options, either public_host or ifconfig_service are specified");
		}


		/* dest table is multitenant table */
		if (list_length(stmt->dest_server_list) > 1 || context.use_multitenant_server)
			context.dest_table_is_multitenant = true;

		/* get multitenant server name */
		if (context.use_multitenant_server == NULL)
		{
			if (context.src_table_is_multitenant)
			{
				/* using src table foreign server name */
				ForeignServer *src_server = GetForeignServer(GetForeignServerIdByRelId(RelationGetRelid(src_rel)));

				context.use_multitenant_server = src_server->servername;
			}
			else
			{
				/* using default name for multitenant server */
				context.use_multitenant_server = "pgspider_core_svr";
				spd_multitenant_server_validation(&context);
			}
		}

		/* Create destination table query */
		spd_create_migrate_dest_table(stmt, src_rel, &context, &relay_command_list);

		/* get column information of source table */
		collist = spd_deparse_column_list(src_rel, false, NULL, false);

		/* Migrate data from src table to dest table */
		spd_add_query(&context,
					  psprintf("INSERT INTO %s (%s) SELECT %s FROM %s;", context.dest_table_fullname, collist, collist, context.src_table_fullname),
					  ";");

		/*
		 * All DDL queries after will run on a transaction, clean-up query
		 * always ROLLBACK
		 */
		spd_add_query(&context,
					  "BEGIN;",
					  "ROLLBACK;");

		/* Add relay queries that are executed after INSERT */
		if (relay_command_list != NIL)
		{
			int			i = 0;

			for (; i < list_length(relay_command_list); i += 2)
			{
				char	   *cmd = (char *) lfirst(list_nth_cell(relay_command_list, i));
				char	   *cmd_clean = (char *) lfirst(list_nth_cell(relay_command_list, i + 1));

				spd_add_query(&context, cmd, cmd_clean);
			}
		}

		/* DROP/RENAME table according to migrate type */
		switch (stmt->migrate_type)
		{
			case MIGRATE_NONE:
			{
				/* In case MIGRATE NONE, all destination foreign table will be dropped. */
				spd_drop_temp_table(&context);
				break;
			}
			case MIGRATE_REPLACE:
			{
				/* In case MIGRATE REPLACE, source table will be dropped and replaced by destination table. */
				spd_replace_src_table(src_rel, &context);
				break;
			}
			case MIGRATE_TO:
			{
				if (!context.dest_table_is_multitenant)
				{
					/*
					 * We are using multitenan table to migrate data,
					 * so we need changing destination from multitenant table to foreing table
					 */
					spd_multitenant_table_to_foreign_table(&context);
				}
				break;
			}
			default:
			{
				elog(ERROR, "Invalid migrate type");
			}
		}

		/* COMMIT all changed */
		spd_add_query(&context,
					"COMMIT;",
					";");

		/* Close src relation */
		table_close(src_rel, AccessShareLock);
	}
	PG_CATCH();
	{
		/* Close src relation */
		table_close(src_rel, AccessShareLock);
		PG_RE_THROW();
	}
	PG_END_TRY();

	*cmds = context.commands;
	*c_cmds = context.cleanup_commands;
}

/* DROP DATASOURCE TABLE command */
void
DropDatasourceTable(DropDatasourceTableStmt *stmt)
{
	spd_FdwExecForeignDDL(stmt->relation, SPD_CMD_DROP, stmt->missing_ok);
}

/* CREATE DATASOURCE TABLE command */
void
CreateDatasourceTable(CreateDatasourceTableStmt *stmt)
{
	spd_FdwExecForeignDDL(stmt->relation, SPD_CMD_CREATE, stmt->if_not_exists);
}
#endif /* PGSPIDER */

/*
 * Import a foreign schema
 */
void
ImportForeignSchema(ImportForeignSchemaStmt *stmt)
{
	ForeignServer *server;
	ForeignDataWrapper *fdw;
	FdwRoutine *fdw_routine;
	AclResult	aclresult;
	List	   *cmd_list;
	ListCell   *lc;

	/* Check that the foreign server exists and that we have USAGE on it */
	server = GetForeignServerByName(stmt->server_name, false);
	aclresult = object_aclcheck(ForeignServerRelationId, server->serverid, GetUserId(), ACL_USAGE);
	if (aclresult != ACLCHECK_OK)
		aclcheck_error(aclresult, OBJECT_FOREIGN_SERVER, server->servername);

	/* Check that the schema exists and we have CREATE permissions on it */
	(void) LookupCreationNamespace(stmt->local_schema);

	/* Get the FDW and check it supports IMPORT */
	fdw = GetForeignDataWrapper(server->fdwid);
	if (!OidIsValid(fdw->fdwhandler))
		ereport(ERROR,
				(errcode(ERRCODE_OBJECT_NOT_IN_PREREQUISITE_STATE),
				 errmsg("foreign-data wrapper \"%s\" has no handler",
						fdw->fdwname)));
	fdw_routine = GetFdwRoutine(fdw->fdwhandler);
	if (fdw_routine->ImportForeignSchema == NULL)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_NO_SCHEMAS),
				 errmsg("foreign-data wrapper \"%s\" does not support IMPORT FOREIGN SCHEMA",
						fdw->fdwname)));

	/* Call FDW to get a list of commands */
	cmd_list = fdw_routine->ImportForeignSchema(stmt, server->serverid);

	/* Parse and execute each command */
	foreach(lc, cmd_list)
	{
		char	   *cmd = (char *) lfirst(lc);
		import_error_callback_arg callback_arg;
		ErrorContextCallback sqlerrcontext;
		List	   *raw_parsetree_list;
		ListCell   *lc2;

		/*
		 * Setup error traceback support for ereport().  This is so that any
		 * error in the generated SQL will be displayed nicely.
		 */
		callback_arg.tablename = NULL;	/* not known yet */
		callback_arg.cmd = cmd;
		sqlerrcontext.callback = import_error_callback;
		sqlerrcontext.arg = (void *) &callback_arg;
		sqlerrcontext.previous = error_context_stack;
		error_context_stack = &sqlerrcontext;

		/*
		 * Parse the SQL string into a list of raw parse trees.
		 */
		raw_parsetree_list = pg_parse_query(cmd);

		/*
		 * Process each parse tree (we allow the FDW to put more than one
		 * command per string, though this isn't really advised).
		 */
		foreach(lc2, raw_parsetree_list)
		{
			RawStmt    *rs = lfirst_node(RawStmt, lc2);
			CreateForeignTableStmt *cstmt = (CreateForeignTableStmt *) rs->stmt;
			PlannedStmt *pstmt;

			/*
			 * Because we only allow CreateForeignTableStmt, we can skip parse
			 * analysis, rewrite, and planning steps here.
			 */
			if (!IsA(cstmt, CreateForeignTableStmt))
				elog(ERROR,
					 "foreign-data wrapper \"%s\" returned incorrect statement type %d",
					 fdw->fdwname, (int) nodeTag(cstmt));

			/* Ignore commands for tables excluded by filter options */
			if (!IsImportableForeignTable(cstmt->base.relation->relname, stmt))
				continue;

			/* Enable reporting of current table's name on error */
			callback_arg.tablename = cstmt->base.relation->relname;

			/* Ensure creation schema is the one given in IMPORT statement */
			cstmt->base.relation->schemaname = pstrdup(stmt->local_schema);

			/* No planning needed, just make a wrapper PlannedStmt */
			pstmt = makeNode(PlannedStmt);
			pstmt->commandType = CMD_UTILITY;
			pstmt->canSetTag = false;
			pstmt->utilityStmt = (Node *) cstmt;
			pstmt->stmt_location = rs->stmt_location;
			pstmt->stmt_len = rs->stmt_len;

			/* Execute statement */
			ProcessUtility(pstmt, cmd, false,
						   PROCESS_UTILITY_SUBCOMMAND, NULL, NULL,
						   None_Receiver, NULL);

			/* Be sure to advance the command counter between subcommands */
			CommandCounterIncrement();

			callback_arg.tablename = NULL;
		}

		error_context_stack = sqlerrcontext.previous;
	}
}

/*
 * error context callback to let us supply the failing SQL statement's text
 */
static void
import_error_callback(void *arg)
{
	import_error_callback_arg *callback_arg = (import_error_callback_arg *) arg;
	int			syntaxerrposition;

	/* If it's a syntax error, convert to internal syntax error report */
	syntaxerrposition = geterrposition();
	if (syntaxerrposition > 0)
	{
		errposition(0);
		internalerrposition(syntaxerrposition);
		internalerrquery(callback_arg->cmd);
	}

	if (callback_arg->tablename)
		errcontext("importing foreign table \"%s\"",
				   callback_arg->tablename);
}
