/*-------------------------------------------------------------------------
 *
 * aggregatecmds.c
 *
 *	  Routines for aggregate-manipulation commands
 *
 * Portions Copyright (c) 1996-2023, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 *
 * IDENTIFICATION
 *	  src/backend/commands/aggregatecmds.c
 *
 * DESCRIPTION
 *	  The "DefineFoo" routines take the parse tree and pick out the
 *	  appropriate arguments/flags, passing the results to the
 *	  corresponding "FooDefine" routines (in src/catalog) that do
 *	  the actual catalog-munging.  These routines also verify permission
 *	  of the user to execute the command.
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "access/htup_details.h"
#include "catalog/dependency.h"
#include "catalog/pg_aggregate.h"
#include "catalog/pg_namespace.h"
#include "catalog/pg_proc.h"
#include "catalog/pg_type.h"
#include "commands/alter.h"
#include "commands/defrem.h"
#include "miscadmin.h"
#include "parser/parse_func.h"
#include "parser/parse_type.h"
#include "utils/acl.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/syscache.h"


static char extractModify(DefElem *defel);

#ifdef PD_STORED
static bool
interpret_function_parameter_list_try(ParseState *pstate,
									  List *parameters,
									  Oid languageOid,
									  ObjectType objtype,
									  oidvector **p_parameterTypes,
									  Oid *p_variadicArgType,
									  bool error_if_failed)
{
	oidvector  *parameterTypes;
	List	   *parameterTypes_list = NIL;
	ArrayType  *allParameterTypes;
	ArrayType  *parameterModes;
	ArrayType  *parameterNames;
	List	   *inParameterNames_list = NIL;
	List	   *parameterDefaults;
	Oid			variadicArgType;
	Oid			requiredResultType;

	PG_TRY();
	{

		interpret_function_parameter_list(pstate,
										  parameters,
										  languageOid,
										  objtype,
										  &parameterTypes,
										  &parameterTypes_list,
										  &allParameterTypes,
										  &parameterModes,
										  &parameterNames,
										  &inParameterNames_list,
										  &parameterDefaults,
										  &variadicArgType,
										  &requiredResultType);
	}
	PG_CATCH();
	{
		if (error_if_failed)
			PG_RE_THROW();
		else
			return false;
	}
	PG_END_TRY();

	if (p_parameterTypes)
		*p_parameterTypes = parameterTypes;
	if (p_variadicArgType)
		*p_variadicArgType = variadicArgType;

	return true;
}

static ObjectAddress
DefineDistributedFunc(ParseState *pstate,
					  char *distName,
					  Oid distNamespace,
					  List *args,
					  bool replace,
					  List *nameParent,
					  List *argsParent,
					  List *nameChild,
					  List *argsChild
					  )
{
	int			numArgs;
	oidvector  *parameterTypes;
	ArrayType  *allParameterTypes;
	List	   *parameterTypes_list = NIL;
	ArrayType  *parameterModes;
	ArrayType  *parameterNames;
	List	   *inParameterNames_list = NIL;
	List	   *parameterDefaults;
	Oid			variadicArgType;
	Oid			requiredResultType;

	int			numArgsParent;
	oidvector  *parameterTypesParent;
	Oid			variadicArgTypeParent;
	bool		ret;
#if 1 /* Parent is 0 arg */
	ObjectType	objtype;
#endif

	Assert(nameParent != NIL);
	Assert(nameChild != NIL);

	numArgs = list_length(args);
	interpret_function_parameter_list(pstate,
									  args,
									  InvalidOid,
									  OBJECT_AGGREGATE,
									  &parameterTypes,
									  &parameterTypes_list,
									  &allParameterTypes,
									  &parameterModes,
									  &parameterNames,
									  &inParameterNames_list,
									  &parameterDefaults,
									  &variadicArgType,
									  &requiredResultType);
										
	/* Parameter defaults are not currently allowed by the grammar */
	Assert(parameterDefaults == NIL);
	/* There shouldn't have been any OUT parameters, either */
	Assert(requiredResultType == InvalidOid);

#if 1 /* Parent is 0 arg */
	if (argsParent == NIL)
	{
		numArgsParent = 0;
		objtype = OBJECT_FUNCTION;
	}
	else
#endif
	{
		argsParent = linitial_node(List, argsParent);
		numArgsParent = list_length(argsParent);
		objtype = OBJECT_AGGREGATE;
	}
	interpret_function_parameter_list_try(pstate,
									argsParent,
									InvalidOid,
									objtype,
									&parameterTypesParent,
									&variadicArgTypeParent,
									true);

	if (argsChild != NIL)
	{
		argsChild = linitial_node(List, argsChild);
		if (!equal(argsChild, args))
		elog(ERROR, "Argument of child function must be same as that of distributed function");
	}

	ret = interpret_function_parameter_list_try(pstate,
												args,
												InvalidOid,
												OBJECT_AGGREGATE,
												NULL,
												NULL,
												false);
	if (!ret)
		ret = interpret_function_parameter_list_try(pstate,
													args,
													InvalidOid,
													OBJECT_FUNCTION,
													NULL,
													NULL,
													true);


	return DistributedFuncCreate(distName,
								 distNamespace,
								 replace,
								 numArgs,
								 0,		/* numDirectArgs */
								 parameterTypes,
								 PointerGetDatum(allParameterTypes),
								 PointerGetDatum(parameterModes),
								 PointerGetDatum(parameterNames),
								 parameterDefaults,
								 variadicArgType,
								 nameParent,
								 nameChild,
								 parameterTypesParent,
								 numArgsParent,
								 variadicArgTypeParent);
}
#endif

/*
 *	DefineAggregate
 *
 * "oldstyle" signals the old (pre-8.2) style where the aggregate input type
 * is specified by a BASETYPE element in the parameters.  Otherwise,
 * "args" is a pair, whose first element is a list of FunctionParameter structs
 * defining the agg's arguments (both direct and aggregated), and whose second
 * element is an Integer node with the number of direct args, or -1 if this
 * isn't an ordered-set aggregate.
 * "parameters" is a list of DefElem representing the agg's definition clauses.
 */
ObjectAddress
DefineAggregate(ParseState *pstate,
				List *name,
				List *args,
				bool oldstyle,
				List *parameters,
				bool replace)
{
	char	   *aggName;
	Oid			aggNamespace;
	AclResult	aclresult;
	char		aggKind = AGGKIND_NORMAL;
	List	   *transfuncName = NIL;
	List	   *finalfuncName = NIL;
	List	   *combinefuncName = NIL;
	List	   *serialfuncName = NIL;
	List	   *deserialfuncName = NIL;
	List	   *mtransfuncName = NIL;
	List	   *minvtransfuncName = NIL;
	List	   *mfinalfuncName = NIL;
	bool		finalfuncExtraArgs = false;
	bool		mfinalfuncExtraArgs = false;
	char		finalfuncModify = 0;
	char		mfinalfuncModify = 0;
	List	   *sortoperatorName = NIL;
	TypeName   *baseType = NULL;
	TypeName   *transType = NULL;
	TypeName   *mtransType = NULL;
	int32		transSpace = 0;
	int32		mtransSpace = 0;
	char	   *initval = NULL;
	char	   *minitval = NULL;
	char	   *parallel = NULL;
	int			numArgs;
	int			numDirectArgs = 0;
	oidvector  *parameterTypes;
	ArrayType  *allParameterTypes;
	ArrayType  *parameterModes;
	ArrayType  *parameterNames;
	List	   *parameterDefaults;
	Oid			variadicArgType;
	Oid			transTypeId;
	Oid			mtransTypeId = InvalidOid;
	char		transTypeType;
	char		mtransTypeType = 0;
	char		proparallel = PROPARALLEL_UNSAFE;
	ListCell   *pl;
#ifdef PD_STORED
	List	   *parent = NIL;
	List	   *parentargs = NIL;
	List	   *child = NIL;
	List	   *childargs = NIL;
#endif

	/* Convert list of names to a name and namespace */
	aggNamespace = QualifiedNameGetCreationNamespace(name, &aggName);

	/* Check we have creation rights in target namespace */
	aclresult = object_aclcheck(NamespaceRelationId, aggNamespace, GetUserId(), ACL_CREATE);
	if (aclresult != ACLCHECK_OK)
		aclcheck_error(aclresult, OBJECT_SCHEMA,
					   get_namespace_name(aggNamespace));

	/* Deconstruct the output of the aggr_args grammar production */
	if (!oldstyle)
	{
		Assert(list_length(args) == 2);
		numDirectArgs = intVal(lsecond(args));
		if (numDirectArgs >= 0)
			aggKind = AGGKIND_ORDERED_SET;
		else
			numDirectArgs = 0;
		args = linitial_node(List, args);
	}

	/* Examine aggregate's definition clauses */
	foreach(pl, parameters)
	{
		DefElem    *defel = lfirst_node(DefElem, pl);

		/*
		 * sfunc1, stype1, and initcond1 are accepted as obsolete spellings
		 * for sfunc, stype, initcond.
		 */
		if (strcmp(defel->defname, "sfunc") == 0)
			transfuncName = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "sfunc1") == 0)
			transfuncName = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "finalfunc") == 0)
			finalfuncName = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "combinefunc") == 0)
			combinefuncName = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "serialfunc") == 0)
			serialfuncName = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "deserialfunc") == 0)
			deserialfuncName = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "msfunc") == 0)
			mtransfuncName = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "minvfunc") == 0)
			minvtransfuncName = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "mfinalfunc") == 0)
			mfinalfuncName = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "finalfunc_extra") == 0)
			finalfuncExtraArgs = defGetBoolean(defel);
		else if (strcmp(defel->defname, "mfinalfunc_extra") == 0)
			mfinalfuncExtraArgs = defGetBoolean(defel);
		else if (strcmp(defel->defname, "finalfunc_modify") == 0)
			finalfuncModify = extractModify(defel);
		else if (strcmp(defel->defname, "mfinalfunc_modify") == 0)
			mfinalfuncModify = extractModify(defel);
		else if (strcmp(defel->defname, "sortop") == 0)
			sortoperatorName = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "basetype") == 0)
			baseType = defGetTypeName(defel);
		else if (strcmp(defel->defname, "hypothetical") == 0)
		{
			if (defGetBoolean(defel))
			{
				if (aggKind == AGGKIND_NORMAL)
					ereport(ERROR,
							(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
							 errmsg("only ordered-set aggregates can be hypothetical")));
				aggKind = AGGKIND_HYPOTHETICAL;
			}
		}
		else if (strcmp(defel->defname, "stype") == 0)
			transType = defGetTypeName(defel);
		else if (strcmp(defel->defname, "stype1") == 0)
			transType = defGetTypeName(defel);
		else if (strcmp(defel->defname, "sspace") == 0)
			transSpace = defGetInt32(defel);
		else if (strcmp(defel->defname, "mstype") == 0)
			mtransType = defGetTypeName(defel);
		else if (strcmp(defel->defname, "msspace") == 0)
			mtransSpace = defGetInt32(defel);
		else if (strcmp(defel->defname, "initcond") == 0)
			initval = defGetString(defel);
		else if (strcmp(defel->defname, "initcond1") == 0)
			initval = defGetString(defel);
		else if (strcmp(defel->defname, "minitcond") == 0)
			minitval = defGetString(defel);
		else if (strcmp(defel->defname, "parallel") == 0)
			parallel = defGetString(defel);
#ifdef PD_STORED
		else if (strcmp(defel->defname, "parent") == 0)
			parent = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "parentargs") == 0)
			parentargs = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "child") == 0)
			child = defGetQualifiedName(defel);
		else if (strcmp(defel->defname, "childargs") == 0)
			childargs = defGetQualifiedName(defel);
#else
		else if (strcmp(defel->defname, "parent") == 0 ||
				 strcmp(defel->defname, "parentargs") == 0 ||
				 strcmp(defel->defname, "child") == 0 ||
				 strcmp(defel->defname, "childargs") == 0)
			ereport(ERROR,
					(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
					 errmsg("distributed function feature is not enabled. Please rebuild with ebabling PD_STORED")));
#endif
		else
			ereport(WARNING,
					(errcode(ERRCODE_SYNTAX_ERROR),
					 errmsg("aggregate attribute \"%s\" not recognized",
							defel->defname)));
	}

#ifdef PD_STORED
	if (parent != NIL || child != NIL)
	{
		return DefineDistributedFunc(pstate, aggName, aggNamespace, args,
									 replace, parent, parentargs, child,
									 childargs);
	}
#endif

	/*
	 * make sure we have our required definitions
	 */
	if (transType == NULL)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
				 errmsg("aggregate stype must be specified")));
	if (transfuncName == NIL)
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
				 errmsg("aggregate sfunc must be specified")));

	/*
	 * if mtransType is given, mtransfuncName and minvtransfuncName must be as
	 * well; if not, then none of the moving-aggregate options should have
	 * been given.
	 */
	if (mtransType != NULL)
	{
		if (mtransfuncName == NIL)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
					 errmsg("aggregate msfunc must be specified when mstype is specified")));
		if (minvtransfuncName == NIL)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
					 errmsg("aggregate minvfunc must be specified when mstype is specified")));
	}
	else
	{
		if (mtransfuncName != NIL)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
					 errmsg("aggregate msfunc must not be specified without mstype")));
		if (minvtransfuncName != NIL)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
					 errmsg("aggregate minvfunc must not be specified without mstype")));
		if (mfinalfuncName != NIL)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
					 errmsg("aggregate mfinalfunc must not be specified without mstype")));
		if (mtransSpace != 0)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
					 errmsg("aggregate msspace must not be specified without mstype")));
		if (minitval != NULL)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
					 errmsg("aggregate minitcond must not be specified without mstype")));
	}

	/*
	 * Default values for modify flags can only be determined once we know the
	 * aggKind.
	 */
	if (finalfuncModify == 0)
		finalfuncModify = (aggKind == AGGKIND_NORMAL) ? AGGMODIFY_READ_ONLY : AGGMODIFY_READ_WRITE;
	if (mfinalfuncModify == 0)
		mfinalfuncModify = (aggKind == AGGKIND_NORMAL) ? AGGMODIFY_READ_ONLY : AGGMODIFY_READ_WRITE;

	/*
	 * look up the aggregate's input datatype(s).
	 */
	if (oldstyle)
	{
		/*
		 * Old style: use basetype parameter.  This supports aggregates of
		 * zero or one input, with input type ANY meaning zero inputs.
		 *
		 * Historically we allowed the command to look like basetype = 'ANY'
		 * so we must do a case-insensitive comparison for the name ANY. Ugh.
		 */
		Oid			aggArgTypes[1];

		if (baseType == NULL)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
					 errmsg("aggregate input type must be specified")));

		if (pg_strcasecmp(TypeNameToString(baseType), "ANY") == 0)
		{
			numArgs = 0;
			aggArgTypes[0] = InvalidOid;
		}
		else
		{
			numArgs = 1;
			aggArgTypes[0] = typenameTypeId(NULL, baseType);
		}
		parameterTypes = buildoidvector(aggArgTypes, numArgs);
		allParameterTypes = NULL;
		parameterModes = NULL;
		parameterNames = NULL;
		parameterDefaults = NIL;
		variadicArgType = InvalidOid;
	}
	else
	{
		/*
		 * New style: args is a list of FunctionParameters (possibly zero of
		 * 'em).  We share functioncmds.c's code for processing them.
		 */
		Oid			requiredResultType;

		if (baseType != NULL)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
					 errmsg("basetype is redundant with aggregate input type specification")));

		numArgs = list_length(args);
		interpret_function_parameter_list(pstate,
										  args,
										  InvalidOid,
										  OBJECT_AGGREGATE,
										  &parameterTypes,
										  NULL,
										  &allParameterTypes,
										  &parameterModes,
										  &parameterNames,
										  NULL,
										  &parameterDefaults,
										  &variadicArgType,
										  &requiredResultType);
		/* Parameter defaults are not currently allowed by the grammar */
		Assert(parameterDefaults == NIL);
		/* There shouldn't have been any OUT parameters, either */
		Assert(requiredResultType == InvalidOid);
	}

	/*
	 * look up the aggregate's transtype.
	 *
	 * transtype can't be a pseudo-type, since we need to be able to store
	 * values of the transtype.  However, we can allow polymorphic transtype
	 * in some cases (AggregateCreate will check).  Also, we allow "internal"
	 * for functions that want to pass pointers to private data structures;
	 * but allow that only to superusers, since you could crash the system (or
	 * worse) by connecting up incompatible internal-using functions in an
	 * aggregate.
	 */
	transTypeId = typenameTypeId(NULL, transType);
	transTypeType = get_typtype(transTypeId);
	if (transTypeType == TYPTYPE_PSEUDO &&
		!IsPolymorphicType(transTypeId))
	{
		if (transTypeId == INTERNALOID && superuser())
			 /* okay */ ;
		else
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
					 errmsg("aggregate transition data type cannot be %s",
							format_type_be(transTypeId))));
	}

	if (serialfuncName && deserialfuncName)
	{
		/*
		 * Serialization is only needed/allowed for transtype INTERNAL.
		 */
		if (transTypeId != INTERNALOID)
			ereport(ERROR,
					(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
					 errmsg("serialization functions may be specified only when the aggregate transition data type is %s",
							format_type_be(INTERNALOID))));
	}
	else if (serialfuncName || deserialfuncName)
	{
		/*
		 * Cannot specify one function without the other.
		 */
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
				 errmsg("must specify both or neither of serialization and deserialization functions")));
	}

	/*
	 * If a moving-aggregate transtype is specified, look that up.  Same
	 * restrictions as for transtype.
	 */
	if (mtransType)
	{
		mtransTypeId = typenameTypeId(NULL, mtransType);
		mtransTypeType = get_typtype(mtransTypeId);
		if (mtransTypeType == TYPTYPE_PSEUDO &&
			!IsPolymorphicType(mtransTypeId))
		{
			if (mtransTypeId == INTERNALOID && superuser())
				 /* okay */ ;
			else
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_FUNCTION_DEFINITION),
						 errmsg("aggregate transition data type cannot be %s",
								format_type_be(mtransTypeId))));
		}
	}

	/*
	 * If we have an initval, and it's not for a pseudotype (particularly a
	 * polymorphic type), make sure it's acceptable to the type's input
	 * function.  We will store the initval as text, because the input
	 * function isn't necessarily immutable (consider "now" for timestamp),
	 * and we want to use the runtime not creation-time interpretation of the
	 * value.  However, if it's an incorrect value it seems much more
	 * user-friendly to complain at CREATE AGGREGATE time.
	 */
	if (initval && transTypeType != TYPTYPE_PSEUDO)
	{
		Oid			typinput,
					typioparam;

		getTypeInputInfo(transTypeId, &typinput, &typioparam);
		(void) OidInputFunctionCall(typinput, initval, typioparam, -1);
	}

	/*
	 * Likewise for moving-aggregate initval.
	 */
	if (minitval && mtransTypeType != TYPTYPE_PSEUDO)
	{
		Oid			typinput,
					typioparam;

		getTypeInputInfo(mtransTypeId, &typinput, &typioparam);
		(void) OidInputFunctionCall(typinput, minitval, typioparam, -1);
	}

	if (parallel)
	{
		if (strcmp(parallel, "safe") == 0)
			proparallel = PROPARALLEL_SAFE;
		else if (strcmp(parallel, "restricted") == 0)
			proparallel = PROPARALLEL_RESTRICTED;
		else if (strcmp(parallel, "unsafe") == 0)
			proparallel = PROPARALLEL_UNSAFE;
		else
			ereport(ERROR,
					(errcode(ERRCODE_SYNTAX_ERROR),
					 errmsg("parameter \"parallel\" must be SAFE, RESTRICTED, or UNSAFE")));
	}

	/*
	 * Most of the argument-checking is done inside of AggregateCreate
	 */
	return AggregateCreate(aggName, /* aggregate name */
						   aggNamespace,	/* namespace */
						   replace,
						   aggKind,
						   numArgs,
						   numDirectArgs,
						   parameterTypes,
						   PointerGetDatum(allParameterTypes),
						   PointerGetDatum(parameterModes),
						   PointerGetDatum(parameterNames),
						   parameterDefaults,
						   variadicArgType,
						   transfuncName,	/* step function name */
						   finalfuncName,	/* final function name */
						   combinefuncName, /* combine function name */
						   serialfuncName,	/* serial function name */
						   deserialfuncName,	/* deserial function name */
						   mtransfuncName,	/* fwd trans function name */
						   minvtransfuncName,	/* inv trans function name */
						   mfinalfuncName,	/* final function name */
						   finalfuncExtraArgs,
						   mfinalfuncExtraArgs,
						   finalfuncModify,
						   mfinalfuncModify,
						   sortoperatorName,	/* sort operator name */
						   transTypeId, /* transition data type */
						   transSpace,	/* transition space */
						   mtransTypeId,	/* transition data type */
						   mtransSpace, /* transition space */
						   initval, /* initial condition */
						   minitval,	/* initial condition */
						   proparallel);	/* parallel safe? */
}

/*
 * Convert the string form of [m]finalfunc_modify to the catalog representation
 */
static char
extractModify(DefElem *defel)
{
	char	   *val = defGetString(defel);

	if (strcmp(val, "read_only") == 0)
		return AGGMODIFY_READ_ONLY;
	if (strcmp(val, "shareable") == 0)
		return AGGMODIFY_SHAREABLE;
	if (strcmp(val, "read_write") == 0)
		return AGGMODIFY_READ_WRITE;
	ereport(ERROR,
			(errcode(ERRCODE_SYNTAX_ERROR),
			 errmsg("parameter \"%s\" must be READ_ONLY, SHAREABLE, or READ_WRITE",
					defel->defname)));
	return 0;					/* keep compiler quiet */
}
