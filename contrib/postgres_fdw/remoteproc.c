/*-------------------------------------------------------------------------
 *
 * remotefunc.c
 *		  Stored function/procedure management for postgres_fdw
 *
 * Portions Copyright (c) 2022, Toshiba corporation
 *
 * IDENTIFICATION
 *		  contrib/postgres_fdw/remotefunc.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#ifdef PD_STORED
#include "catalog/namespace.h"
#include "catalog/pg_aggregate.h"
#include "catalog/pg_operator.h"
#include "catalog/pg_proc.h"
#include "catalog/pg_proc_d.h"
#include "miscadmin.h"
#include "postgres_fdw.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/syscache.h"

/*
 * Append a function definition into the list.
 */
static List *
append_func_def(List *list, StringInfo buf, Oid funcid,
					   const char *fmt)
{
	HeapTuple		proctup;
	Form_pg_proc	procform;
	char		   *nsp;
	Datum			d;
	char		   *funcstr;

	proctup = SearchSysCache1(PROCOID, ObjectIdGetDatum(funcid));
	if (!HeapTupleIsValid(proctup))
		elog(ERROR, "cache lookup failed for function %u", funcid);
	procform = (Form_pg_proc) GETSTRUCT(proctup);

	nsp = get_namespace_name(procform->pronamespace);
	appendStringInfo(buf, fmt,
					 quote_qualified_identifier(nsp,
					 							NameStr(procform->proname)));
	ReleaseSysCache(proctup);

	d = DirectFunctionCall2(pg_get_functiondef, DatumGetInt32(funcid),
							DatumGetBool(true));
	funcstr = text_to_cstring(DatumGetTextP(d));
	list = lappend(list, funcstr);

	return list;
}

/*
 * Construct CREATE AGGREGATE query like pg_get_functiondef which is for
 * CREATE FUNCTION.
 */
static List *
get_aggregatedef(Form_pg_proc proc)
{
	StringInfoData	buf;
	HeapTuple		aggTuple;
	Form_pg_aggregate aggform;
	char		   *nsp;
	List		   *sqls = NIL;
	Datum			d;
	bool			isNull;

	initStringInfo(&buf);

	aggTuple = SearchSysCache1(AGGFNOID,
							   ObjectIdGetDatum(proc->oid));
	aggform = (Form_pg_aggregate) GETSTRUCT(aggTuple);

	nsp = get_namespace_name(proc->pronamespace);
	appendStringInfo(&buf, "CREATE OR REPLACE AGGREGATE %s(",
					 quote_qualified_identifier(nsp,
					 							NameStr(proc->proname)));

	/* Append arguments. */
	d = DirectFunctionCall2(pg_get_function_arguments, ObjectIdGetDatum(proc->oid),
							DatumGetBool(true));
	appendStringInfo(&buf, "%s)", text_to_cstring(DatumGetTextP(d)));

	appendStringInfoString(&buf, "(\n");

	/* Append SFUNC. */
	sqls = append_func_def(sqls, &buf, aggform->aggtransfn, " SFUNC = %s");

	/* Append STYPE. */
	appendStringInfo(&buf, ",\n STYPE = %s", format_type_be_qualified(aggform->aggtranstype));

	/* Append SSPACE if specified. */
	if (aggform->aggtransspace > 0)
		appendStringInfo(&buf, ",\n SSPACE = %d", aggform->aggtransspace);
	
	/* Append FINALFUNC if specified. */
	if (OidIsValid(aggform->aggfinalfn))
		sqls = append_func_def(sqls, &buf, aggform->aggfinalfn,
							   ",\n FINALFUNC = %s");

	/* Append FINALFUNC_EXTRA if specified. */
	if (aggform->aggfinalextra)
		appendStringInfoString(&buf, ",\n FINALFUNC_EXTRA");
		
	/* Append FINALFUNC_MODIFY if not default value. */
	if (aggform->aggfinalmodify == AGGMODIFY_SHAREABLE)
		appendStringInfoString(&buf, ",\n FINALFUNC_MODIFY = SHAREABLE");
	else if (aggform->aggfinalmodify == AGGMODIFY_READ_WRITE)
		appendStringInfoString(&buf, ",\n FINALFUNC_MODIFY = READ_WRITE");
	else
		Assert (aggform->aggfinalmodify==AGGMODIFY_READ_ONLY);

	/* Append COMBINEFUNC if specified. */
	if (OidIsValid(aggform->aggcombinefn))
		sqls = append_func_def(sqls, &buf, aggform->aggcombinefn,
							   ",\n COMBINEFUNC = %s");

	/* Append SERIALFUNC if specified. */
	if (OidIsValid(aggform->aggserialfn))
		sqls = append_func_def(sqls, &buf, aggform->aggserialfn,
							   ",\n SERIALFUNC = %s");

	/* Append DESERIALFUNC if specified. */
	if (OidIsValid(aggform->aggdeserialfn))
		sqls = append_func_def(sqls, &buf, aggform->aggdeserialfn,
							   ",\n DESERIALFUNC = %s");

	/* Append INITCOND if specified. */
	d = SysCacheGetAttr(AGGFNOID, aggTuple,
						Anum_pg_aggregate_agginitval,
						&isNull);
	if (!isNull)
	{
		char   *initValue = text_to_cstring(DatumGetTextP(d));
		appendStringInfo(&buf, ",\n INITCOND = \'%s\'", initValue);
	}

	/* Append MSFUNC if specified. */
	if (OidIsValid(aggform->aggdeserialfn))
		sqls = append_func_def(sqls, &buf, aggform->aggmtransfn,
							   ",\n MSFUNC = %s");

	/* Append MINVFUNC if specified. */
	if (OidIsValid(aggform->aggminvtransfn))
		sqls = append_func_def(sqls, &buf, aggform->aggminvtransfn,
							   ",\n MINVFUNC = %s");

	/* Append MSTYPE if specified. */
	if (aggform->aggmtranstype > 0)
		appendStringInfo(&buf, " MSTYPE = %s", format_type_be(aggform->aggmtranstype));

	/* Append MSSPACE if specified. */
	if (aggform->aggmtransspace > 0)
		appendStringInfo(&buf, ",\n MSSPACE = %d", aggform->aggmtransspace);

	/* Append MFINALFUNC if specified. */
	if (OidIsValid(aggform->aggmfinalfn))
		sqls = append_func_def(sqls, &buf, aggform->aggmfinalfn,
							   ",\n MFINALFUNC = %s");

	/* Append MFINALFUNC_EXTRA if specified. */
	if (aggform->aggmfinalextra)
		appendStringInfoString(&buf, ",\n MFINALFUNC_EXTRA");

	/* Append FINALFUNC_MODIFY if not default value. */
	if (aggform->aggmfinalmodify == AGGMODIFY_SHAREABLE)
		appendStringInfoString(&buf, ",\n MFINALFUNC_MODIFY = SHAREABLE");
	else if (aggform->aggmfinalmodify == AGGMODIFY_READ_WRITE)
		appendStringInfoString(&buf, ",\n MFINALFUNC_MODIFY = READ_WRITE");
	else
		Assert (aggform->aggmfinalmodify==AGGMODIFY_READ_ONLY);

	/* Append INITCOND if specified. */
	d = SysCacheGetAttr(AGGFNOID, aggTuple,
						Anum_pg_aggregate_aggminitval,
						&isNull);
	if (!isNull)
	{
		char   *minitValue = text_to_cstring(DatumGetTextP(d));
		appendStringInfo(&buf, ",\n MINITCOND = \'%s\'", minitValue);
	}

	/* Append SORTOP if specified. */
	if (OidIsValid(aggform->aggsortop))
	{
		HeapTuple	opertup;
		Form_pg_operator	operclass;

		opertup = SearchSysCache1(OPEROID,
								  ObjectIdGetDatum(aggform->aggsortop));
		operclass = (Form_pg_operator) GETSTRUCT(opertup);
		appendStringInfo(&buf, ",\n SORTOP = %s", NameStr(operclass->oprname));
		ReleaseSysCache(opertup);
	}

	/* Append PARALLEL if not default value. */
	if (proc->proparallel == PROPARALLEL_SAFE)
		appendStringInfoString(&buf, ",\n PARALLEL = SAFE");
	else if (proc->proparallel == PROPARALLEL_RESTRICTED)
		appendStringInfoString(&buf, ",\n PARALLEL = RESTRICTED");
	else
		Assert (proc->proparallel==PROPARALLEL_UNSAFE);

	appendStringInfoString(&buf, ")");

	/* Append CREATE AGGREGATE query. */
	sqls = lappend(sqls, buf.data);

	ReleaseSysCache(aggTuple);
	
	return sqls;
}

/*
 * Get a function definition as a string by using pg_get_functiondef().
 */
static List *
get_functiondef_string(Oid funcid)
{
	HeapTuple	proctup;
	Form_pg_proc	proc;
	List	   *sqls = NIL;
	
	/*
	 * Detect the function kind. In case of normal function, we can use
	 * pg_get_functiondef() implemented in PostgreSQL core. But in case
	 * of aggregate function, we need to construct the function
	 * definition string manually.
	 */
	proctup = SearchSysCache1(PROCOID, ObjectIdGetDatum(funcid));
	if (!HeapTupleIsValid(proctup))
		elog(ERROR, "cache lookup failed for function or aggregate %u",
			 funcid);
	proc = (Form_pg_proc) GETSTRUCT(proctup);

	if (proc->prokind == PROKIND_AGGREGATE)
	{
		sqls = get_aggregatedef(proc);
	}
	else
	{
		char   *funcstr;
		Datum		d;

		d = DirectFunctionCall2(pg_get_functiondef, DatumGetInt32(funcid),
								DatumGetBool(true));
		funcstr = text_to_cstring(DatumGetTextP(d));
		sqls = lappend(sqls, funcstr);
	}

	ReleaseSysCache(proctup);

	return sqls;
}

/*
 * Create a function in PostgreSQL.
 */
static void
create_function(UserMapping *user, Oid funcoid)
{
	List	   *sqls;
	PGconn	   *conn;
    PGresult   *res;
	ListCell	*lc;

	sqls = get_functiondef_string(funcoid);

	conn = GetConnection(user, false, NULL);

	foreach(lc, sqls)
	{
		char *sql = (char *) lfirst(lc);

		elog(DEBUG1, "Executing:\n%s", sql);
	    res = pgfdw_exec_query(conn, sql, NULL);
    	if (PQresultStatus(res) != PGRES_COMMAND_OK)
			pgfdw_report_error(ERROR, res, conn, false, sql);
		PQclear(res);
	}
}

typedef struct private_data
{
	PGconn	   *conn;
	PGresult   *res;
	int			cur;
	char	   *sql;
} private_data;

/*
 * Execute a function.
 * If 'async' parameter is true, it is required to execute a function
 * asynchronously. If false, it is not required it. It means that
 * either asynchronous or synchronous is acceptable. In postgres_fdw,
 * it always execites a function asynchronously.
 */
void
postgresExecuteFunction(Oid funcoid, Oid tableoid,
						List *args, bool async, void **private)
{
	ForeignTable *table;
	ForeignServer *server;
	UserMapping *user;
	StringInfoData buf;
	PGconn	   *conn;
	PGresult   *res = NULL;
	private_data *fdw_private;

	table = GetForeignTable(tableoid);
	server = GetForeignServer(table->serverid);
	user = GetUserMapping(GetUserId(), server->serverid);

	create_function(user, funcoid);

	initStringInfo(&buf);
	deparseFunctionQuery(&buf, funcoid, tableoid, args);

	conn = GetConnection(user, false, NULL);

	elog(DEBUG1, "Executing:\n%s", buf.data);
	if (!PQsendQuery(conn, buf.data))
		pgfdw_report_error(ERROR, NULL, conn, false, buf.data);

	fdw_private = palloc0(sizeof(private_data));
	fdw_private->conn = conn;
	fdw_private->res = res;
	fdw_private->cur = 0;
	fdw_private->sql = buf.data;
	*private = fdw_private;
}

/*
 * Get a result of the function executed by postgresExecuteFunction,
 * return a row in the result. This function will be called repeatedly
 * until this function returns false.
 */
bool
postgresGetFunctionResultOne(void *private, AttInMetadata *attinmeta,
							 Datum *value, bool *null)
{
	private_data *fdw_private = (private_data *) private;
	PGresult *res;
	int		i = fdw_private->cur;

	if (fdw_private->res == NULL)
	{
		/* Fetch a result set if it has not done yet in case of async execution. */
		res = pgfdw_get_result(fdw_private->conn, fdw_private->sql);
		if (PQresultStatus(res) != PGRES_TUPLES_OK)
			pgfdw_report_error(ERROR, res, fdw_private->conn, false, fdw_private->sql);
		fdw_private->res = res;
	}
	else
		res = fdw_private->res;

	if (fdw_private->cur >= PQntuples(res))
	{
		if (res)
		{
			PQclear(res);
			fdw_private->res = NULL;
		}
		return false;
	}

	if (PQnfields(res) != 1)
		elog(ERROR, "A single field is expected, but there are multiple fields %d", PQnfields(res));

	if (PQgetisnull(res, i, 0))
	{
		*null = true;
		*value = PointerGetDatum(NULL);
	}
	else
	{
		*null = false;
		/* Apply the input function even to nulls, to support domains */
		*value = InputFunctionCall(&attinmeta->attinfuncs[0],
									  PQgetvalue(res, i, 0),
									  attinmeta->attioparams[0],
									  attinmeta->atttypmods[0]);
	}

	fdw_private->cur++;

	return true;
}

/*
 * Clean up
 */
void
postgresFinalizeFunction(void *private)
{
	private_data *fdw_private = (private_data *) private;
	if (fdw_private->res)
	{
		PQclear(fdw_private->res);
		fdw_private->res = NULL;
	}
}
#endif
