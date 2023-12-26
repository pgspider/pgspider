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
#include "catalog/pg_proc_d.h"
#include "executor/nodeDist.h"
#include "foreign/foreign.h"
#include "miscadmin.h"
#include "utils/builtins.h"
#include "utils/catcache.h"
#include "utils/syscache.h"
#include "pgspider_core_fdw.h"

typedef struct child_state
{
	Oid				tableoid;			/* table OID of child node */
	bool			finished;			/* determine finish when fetch result in each child node */
	void		   *fdw_private;		/* child node information */
	ExecFunction	pgExecFunc;			/* function pointer to execute aggregate query on child node */
	GetFunctionResultOne pgFetchFunc;	/* function pointer to get result of aggregate query on child node */
	FinFunction		pgFinFunc;			/* function pointer to clean result of child node */
} child_state;

typedef struct dist_func_state
{
	List   *status;	/* List of child_state */
	int		next_child;
} dist_func_state;

/*
 * Find child nodes belonging to the multi-tenant table.
 * Child node information is stored into child_state structure
 * and this function returns a list of child_state.
 */
static List *
childfunc_target_server(Oid tableoid)
{
	List	   *status = NIL;
	int			num_child;
	Oid		   *oids;	/* Oids of child tables */

	spd_calculate_datasource_count(tableoid, &num_child, &oids);

	for (int i = 0; i < num_child; i++)
	{
		child_state		   *state;
		ExecFunction		pgExecFunc;
		GetFunctionResultOne pgFetchFunc;
		FinFunction		pgFinFunc;
		Oid				serveroid;
		ForeignServer	   *server;
		ForeignDataWrapper *fdw;
		char *fdwlib_name = NULL;

		serveroid = GetForeignServerIdByRelId(oids[i]);
		server = GetForeignServer(serveroid);
		fdw = GetForeignDataWrapper(server->fdwid);

		/* Create fdw lib name simply by fdw name */
		fdwlib_name = psprintf("$libdir/%s", fdw->fdwname);

		pgFetchFunc = (GetFunctionResultOne) load_external_function(fdwlib_name, "GetFunctionResultOne", false, NULL);;
		pgFinFunc = (FinFunction) load_external_function(fdwlib_name, "FinalizeFunction", false, NULL);
		pgExecFunc = (ExecFunction) load_external_function(fdwlib_name, "ExecuteFunction", false, NULL);

		if (pgFetchFunc == NULL || pgFinFunc == NULL || pgExecFunc == NULL)
			elog(ERROR, "%s does not support Parallel Distributed Stored Function", fdw->fdwname);

		state = palloc0(sizeof(child_state));

		state->tableoid = oids[i];
		state->finished = false;
		state->fdw_private = NULL;
		state->pgFetchFunc = pgFetchFunc;
		state->pgFinFunc = pgFinFunc;
		state->pgExecFunc = pgExecFunc;

		status = lappend(status, state);
	}

	return status;
}

/*
 * Create and initialize a instance of dist_func_state structure.
 */
static dist_func_state *
init_func_state(Oid tableoid, List *args)
{
	dist_func_state *func_state;

	func_state = palloc0(sizeof(dist_func_state));

	func_state->status = childfunc_target_server(tableoid);
	func_state->next_child = 0;

	return func_state;
}

/*
 * Call ExecuteFunction of child FDW.
 */
void
spdExecuteFunction(Oid funcoid, Oid tableoid,
				   List *args, bool async, void **private)
{
    dist_func_state *func_state;
	ListCell   *lc;

    func_state = init_func_state(tableoid, args);

	foreach (lc, func_state->status)
	{
		child_state	   *state = (child_state *) lfirst(lc);

		state->pgExecFunc(funcoid, state->tableoid, args, async,
				   &state->fdw_private);
	}

	*private = func_state;
}

/*
 * Call ExplainFunction of child FDW.
 */
void
spdExplainFunction(Oid funcoid, Oid tableoid,
				   List *args, bool async, void *private)
{
	ExplainState *es = (ExplainState *) private;
	int			num_child;
	Oid		   *oids;	/* Oids of child tables */

	spd_calculate_datasource_count(tableoid, &num_child, &oids);

	for (int i = 0; i < num_child; i++)
	{
		ForeignServer	   *server;
		ForeignDataWrapper *fdw;
		ExplainFunc		pgExplainFunc;
		Oid				serveroid;
		char *fdwlib_name = NULL;


		serveroid = GetForeignServerIdByRelId(oids[i]);
		server = GetForeignServer(serveroid);
		fdw = GetForeignDataWrapper(server->fdwid);

		/* Create fdw lib name simply by fdw name */
		fdwlib_name = psprintf("$libdir/%s", fdw->fdwname);

		pgExplainFunc = (ExplainFunc) load_external_function(fdwlib_name, "ExplainFunction", false, NULL);
		if (pgExplainFunc == NULL)
			elog(ERROR, "%s does not support Parallel Distribusted Stored Function", fdw->fdwname);

		ExplainPropertyText("Node", server->servername, es);

		es->indent++;
		pgExplainFunc(funcoid, oids[i], args, async, es);
		es->indent--;
	}
}

/*
 * Return one record of child function acquired from one of child node.
 * The target child node is determined by rotation.
 */
bool
spdGetFunctionResultOne(void *private, AttInMetadata *attinmeta,
						Datum *values, bool *nulls)
{
    dist_func_state *func_state = (dist_func_state *) private;
	int			num_child;
	int			i;
	bool		fetched = false;

	num_child = list_length(func_state->status);
	for (i = func_state->next_child; i < func_state->next_child + num_child; i++)
	{
		bool	ret;
		int		id = i % num_child;
		child_state *state = (child_state *) list_nth(func_state->status, id);

		if (state->finished)
			continue;

		ret = state->pgFetchFunc(state->fdw_private, attinmeta, values, nulls);
		if (ret == true)
		{
            func_state->next_child = id;
            fetched = true;
            break;
		}

		state->finished = true;
	}

	return fetched;
}

void
spdFinalizeFunction(void *private)
{
    dist_func_state *func_state = (dist_func_state *) private;
	int			num_child;
	int			i;

	num_child = list_length(func_state->status);
	for (i = 0; i < num_child; i++)
	{
		child_state *state = (child_state *) list_nth(func_state->status, i);

		state->pgFinFunc(state->fdw_private);
	}
}
#endif  /* PD_STORED */
