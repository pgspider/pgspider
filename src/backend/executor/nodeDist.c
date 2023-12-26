/*-------------------------------------------------------------------------
 *
 * nodeDist.c
 *	  Routines to handle distributed function nodes.
 *
 * Portions Copyright (c) 2022, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *	  src/backend/executor/nodeDist.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#ifdef PD_STORED
#include "catalog/pg_aggregate.h"
#include "executor/executor.h"
#include "executor/nodeAgg.h"
#include "executor/nodeDist.h"
#include "miscadmin.h"
#include "nodes/makefuncs.h"
#include "nodes/nodeFuncs.h"
#include "utils/syscache.h"

#define PGSPIDER_CORE_FDW_NAME "pgspider_core_fdw"

typedef struct dist_func_state
{
	GetFunctionResultOne pgFetchFunc;
	FinFunction		pgFinFunc;
	AttInMetadata *attinmeta;
	TupleTableSlot *slot;
	void	   *fdw_private;
} dist_func_state;

/*
 * Call the child func of all aggregates for one group.
 *
 * This function handles only one grouping set at a time, which the caller must
 * have selected.  It's also the caller's responsibility to adjust the supplied
 * pergroup parameter to point to the current set's transvalues.
 *
 * Results are stored in the output econtext aggvalues/aggnulls.
 */
/*
 * Create an aggregate function node. The code is referring to
 * ParseFuncOrColumn() in parse_func.c.
 */
static Aggref *
makeAggRef(Oid funcoid, Oid rettype)
{
	Aggref		   *aggref = makeNode(Aggref);

	aggref->aggfnoid = funcoid;
	aggref->aggtype = rettype;
	/* aggcollid and inputcollid will be set by parse_collate.c */
	aggref->aggtranstype = InvalidOid;	/* will be set by planner */
	/* aggargtypes will be set by transformAggregateCall */
	/* aggdirectargs and args will be set by transformAggregateCall */
	/* aggorder and aggdistinct will be set by transformAggregateCall */
	aggref->aggfilter = NULL;
	aggref->aggstar = false;
	aggref->aggvariadic = false;
	aggref->aggkind = AGGKIND_NORMAL;
	/* agglevelsup will be set by transformAggregateCall */
	aggref->aggsplit = AGGSPLIT_SIMPLE; /* planner might change this */
	aggref->location = -1;

	return aggref;
}

/*
 * Create and initialize a state for distrubuted function.
 */
static dist_func_state *
init_func_state(Oid funcoid, Oid rettype)
{
	Aggref		   *aggref;
	TargetEntry	   *tle;
	List		   *tlist_child;
	TupleDesc		tupdesc;
	TupleTableSlot *slot;
	GetFunctionResultOne pgFetchFunc;
	FinFunction		pgFinFunc;
	dist_func_state *func_state;
	char			*fdwlib_name = NULL;

	/* Create pgspider_core_fdw lib name */
	fdwlib_name = psprintf("$libdir/%s", PGSPIDER_CORE_FDW_NAME);

	pgFetchFunc = (GetFunctionResultOne) load_external_function(fdwlib_name, "spdGetFunctionResultOne", true, NULL);
	pgFinFunc = (FinFunction) load_external_function(fdwlib_name, "spdFinalizeFunction", true, NULL);

	/* Create a target list of child function. */
	aggref = makeAggRef(funcoid, rettype);
	tle = makeTargetEntry((Expr *) aggref, 1, NULL, false);
	tlist_child = list_make1(tle);
	
	/* Create a slot to store a result of child funcrion. */
	tupdesc = ExecCleanTypeFromTL(tlist_child);
	slot = MakeTupleTableSlot(tupdesc, &TTSOpsVirtual);

	/* Create an instance managing a function state. */
	func_state = palloc0(sizeof(dist_func_state));
	func_state->pgFetchFunc = pgFetchFunc;
	func_state->pgFinFunc = pgFinFunc;
	func_state->attinmeta = TupleDescGetAttInMetadata(tupdesc);
	func_state->slot = slot;

	return func_state;
}

/*
 * Detect a target relation (multi-tenant table) and arguments
 * of the distributed function. 
 */
static void
childfunc_target(AggState *aggstate, Oid *tableoid, List **args)
{
	PlanState *pstate;
	ForeignScanState *node;
	Plan	  *outerPlan;

	pstate = outerPlanState(aggstate);
	if (!IsA(pstate, ForeignScanState))
		elog(ERROR, "Unexpected node type (%d)", pstate->type);
	node = castNode(ForeignScanState, pstate);

	/* Detect a target relation. */
	*tableoid = RelationGetRelid(node->ss.ss_currentRelation);

	/* Get arguments of distributed function. */
	outerPlan = node->ss.ps.plan;
	*args = outerPlan->targetlist;
}

/*
 * Call a child function.
 */
static void
call_childfunc(AggState *aggstate,
			   AggStatePerAgg peragg,
			   dist_func_state *func_state)
{
	ExecFunction pgExecFunc;
	Oid			 tableoid;
	List		*args;
	char		*fdwlib_name = NULL;

	/* Create pgspider_core_fdw lib name */
	fdwlib_name = psprintf("$libdir/%s", PGSPIDER_CORE_FDW_NAME);

	/* Get a relation of multi-tenant table and function arguments. */
	childfunc_target(aggstate, &tableoid, &args);

	/* Execute the function. */
	pgExecFunc = (ExecFunction) load_external_function(fdwlib_name, "spdExecuteFunction", true, NULL);

	pgExecFunc(peragg->childfn_oid, tableoid, args, peragg->async, &func_state->fdw_private);
}

/*
 * Get one record of child function.
 */
static void
getvalue_fromchild(dist_func_state *func_state)
{
	Datum	   value;
	bool	   isnull;
	TupleTableSlot *slot = func_state->slot;
	bool		fetched;

	ExecClearTuple(slot);

	fetched = func_state->pgFetchFunc(func_state->fdw_private,
									  func_state->attinmeta,
									  &value, &isnull);

	if (fetched)
	{
		slot->tts_values[0] = value;
		slot->tts_isnull[0] = isnull;
		ExecStoreVirtualTuple(slot);
	}
}

static void
finalize_child(dist_func_state *func_state)
{
	func_state->pgFinFunc(func_state->fdw_private);
}

/* 
 * Execute a distributed function. This function is an entry point
 * from nodeAgg.c to operate a distributed function.
 * This function is implemented by refering agg_retrieve_direct()
 * in nodeAgg.c.
 */
TupleTableSlot *
agg_retrieve_distributed_func(AggState *aggstate)
{
	Agg		   *node = aggstate->phase->aggnode;
	ExprContext *econtext;
	ExprContext *tmpcontext;
	AggStatePerAgg peragg;
	AggStatePerGroup *pergroups;
	TupleTableSlot *outerslot;
	TupleTableSlot *firstSlot;
	TupleTableSlot *result;
	bool		hasGroupingSets = aggstate->phase->numsets > 0;
	int			numGroupingSets = Max(aggstate->phase->numsets, 1);
	int			currentSet;
	int			nextSetSize;
	int			numReset;
	int			i;
	dist_func_state	   *func_state = NULL;

	/*
	 * get state info from node
	 *
	 * econtext is the per-output-tuple expression context
	 *
	 * tmpcontext is the per-input-tuple expression context
	 */
	econtext = aggstate->ss.ps.ps_ExprContext;
	tmpcontext = aggstate->tmpcontext;

	peragg = aggstate->peragg;
	pergroups = aggstate->pergroups;
	firstSlot = aggstate->ss.ss_ScanTupleSlot;

	/*
	 * We loop retrieving groups until we find one matching
	 * aggstate->ss.ps.qual
	 *
	 * For grouping sets, we have the invariant that aggstate->projected_set
	 * is either -1 (initial call) or the index (starting from 0) in
	 * gset_lengths for the group we just completed (either by projecting a
	 * row or by discarding it in the qual).
	 */
	while (!aggstate->agg_done)
	{
		/*
		 * Clear the per-output-tuple context for each group, as well as
		 * aggcontext (which contains any pass-by-ref transvalues of the old
		 * group).  Some aggregate functions store working state in child
		 * contexts; those now get reset automatically without us needing to
		 * do anything special.
		 *
		 * We use ReScanExprContext not just ResetExprContext because we want
		 * any registered shutdown callbacks to be called.  That allows
		 * aggregate functions to ensure they've cleaned up any non-memory
		 * resources.
		 */
		ReScanExprContext(econtext);

		/*
		 * Determine how many grouping sets need to be reset at this boundary.
		 */
		if (aggstate->projected_set >= 0 &&
			aggstate->projected_set < numGroupingSets)
			numReset = aggstate->projected_set + 1;
		else
			numReset = numGroupingSets;

		/*
		 * numReset can change on a phase boundary, but that's OK; we want to
		 * reset the contexts used in _this_ phase, and later, after possibly
		 * changing phase, initialize the right number of aggregates for the
		 * _new_ phase.
		 */

		for (i = 0; i < numReset; i++)
		{
			ReScanExprContext(aggstate->aggcontexts[i]);
		}

		/*
		 * Check if input is complete and there are no more groups to project
		 * in this phase; move to next phase or mark as done.
		 */
		if (aggstate->input_done == true &&
			aggstate->projected_set >= (numGroupingSets - 1))
		{
			if (aggstate->current_phase < aggstate->numphases - 1)
			{
				InitializePhase(aggstate, aggstate->current_phase + 1);
				aggstate->input_done = false;
				aggstate->projected_set = -1;
				numGroupingSets = Max(aggstate->phase->numsets, 1);
				node = aggstate->phase->aggnode;
				numReset = numGroupingSets;
			}
			else if (aggstate->aggstrategy == AGG_MIXED)
			{
				/*
				 * Mixed mode; we've output all the grouped stuff and have
				 * full hashtables, so switch to outputting those.
				 */
				InitializePhase(aggstate, 0);
				aggstate->table_filled = true;
				ResetTupleHashIterator(aggstate->perhash[0].hashtable,
									   &aggstate->perhash[0].hashiter);
				SelectCurrentSet(aggstate, 0, true);
				return AggRetrieveHashTable(aggstate);
			}
			else
			{
				aggstate->agg_done = true;
				break;
			}
		}

		/*
		 * Get the number of columns in the next grouping set after the last
		 * projected one (if any). This is the number of columns to compare to
		 * see if we reached the boundary of that set too.
		 */
		if (aggstate->projected_set >= 0 &&
			aggstate->projected_set < (numGroupingSets - 1))
			nextSetSize = aggstate->phase->gset_lengths[aggstate->projected_set + 1];
		else
			nextSetSize = 0;

		/*----------
		 * If a subgroup for the current grouping set is present, project it.
		 *
		 * We have a new group if:
		 *	- we're out of input but haven't projected all grouping sets
		 *	  (checked above)
		 * OR
		 *	  - we already projected a row that wasn't from the last grouping
		 *		set
		 *	  AND
		 *	  - the next grouping set has at least one grouping column (since
		 *		empty grouping sets project only once input is exhausted)
		 *	  AND
		 *	  - the previous and pending rows differ on the grouping columns
		 *		of the next grouping set
		 *----------
		 */
		tmpcontext->ecxt_innertuple = econtext->ecxt_outertuple;
		if (aggstate->input_done ||
			(node->aggstrategy != AGG_PLAIN &&
			 aggstate->projected_set != -1 &&
			 aggstate->projected_set < (numGroupingSets - 1) &&
			 nextSetSize > 0 &&
			 !ExecQualAndReset(aggstate->phase->eqfunctions[nextSetSize - 1],
							   tmpcontext)))
		{
			aggstate->projected_set += 1;

			Assert(aggstate->projected_set < numGroupingSets);
			Assert(nextSetSize > 0 || aggstate->input_done);
		}
		else
		{
			/*
			 * We no longer care what group we just projected, the next
			 * projection will always be the first (or only) grouping set
			 * (unless the input proves to be empty).
			 */
			aggstate->projected_set = 0;

			/*
			 * Initialize working state for a new input tuple group.
			 */
			InitializeAggregates(aggstate, pergroups, numReset);

			func_state = init_func_state(peragg->childfn_oid, peragg->rettypechild);
			call_childfunc(aggstate, peragg, func_state);

			/* ***** Async support (start) ***** */
			if (!peragg->async)
			/* ***** Async support (end) ***** */
				getvalue_fromchild(func_state);
			
			tmpcontext->ecxt_outertuple = func_state->slot;

			/*
			 * Process each outer-plan tuple, and then fetch the next one,
			 * until we exhaust the outer plan or cross a group boundary.
			 */
			for (;;)
			{
				/*
				 * During phase 1 only of a mixed agg, we need to update
				 * hashtables as well in advance_aggregates.
				 */
				if (aggstate->aggstrategy == AGG_MIXED &&
					aggstate->current_phase == 1)
				{
					LookupHashEntries(aggstate);
				}

				/* Advance the aggregates (or combine functions) */
				AdvanceAggregates(aggstate);

				/* Reset per-input-tuple context after each tuple */
				ResetExprContext(tmpcontext);

				/* ***** Async support (start) ***** */
				if (peragg->async)
					ExecClearTuple(func_state->slot);
				else
				/* ***** Async support (end) ***** */
					getvalue_fromchild(func_state);
				
				outerslot = func_state->slot;
				if (TupIsNull(outerslot))
				{
					/* no more outer-plan tuples available */

					if (hasGroupingSets)
					{
						aggstate->input_done = true;
						break;
					}
					else
					{
						aggstate->agg_done = true;
						break;
					}
				}
				/* set up for next advance_aggregates call */
				tmpcontext->ecxt_outertuple = outerslot;
			}

			/*
			 * Use the representative input tuple for any references to
			 * non-aggregated input columns in aggregate direct args, the node
			 * qual, and the tlist.  (If we are not grouping, and there are no
			 * input rows at all, we will come here with an empty firstSlot
			 * ... but if not grouping, there can't be any references to
			 * non-aggregated input columns, so no problem.)
			 */
			econtext->ecxt_outertuple = firstSlot;
		}

		Assert(aggstate->projected_set >= 0);

		currentSet = aggstate->projected_set;

		PrepareProjectionSlot(aggstate, econtext->ecxt_outertuple, currentSet);

		SelectCurrentSet(aggstate, currentSet, false);

		FinalizeAggregates(aggstate,
							peragg,
							pergroups[currentSet]);

		/* ***** Async support (start) ***** */
		if (peragg->async && func_state != NULL)
		{
			do
			{
				getvalue_fromchild(func_state);
			} while (!TupIsNull(func_state->slot));
		}
		/* ***** Async support (end) ***** */

		finalize_child(func_state);

		/*
		 * If there's no row to project right now, we must continue rather
		 * than returning a null since there might be more groups.
		 */
		result = ProjectAggregates(aggstate);
		if (result)
			return result;
	}

	/* No more groups */
	return NULL;
}

/*
 * Support Exaplain query for distributed function. This function is an
 * entry point from explain.c to operate Explain for distributed function.
 */
void
agg_explain_distributed_func(AggState *aggstate, ExplainState *es)
{
	AggStatePerAgg peragg = aggstate->peragg;
	Oid			tableoid;
	List	   *args;
	char	   *fdwlib_name = NULL;
	ExplainFunc pgExplainFunc;

	/* Get a relation of multi-tenant table and function arguments. */
	childfunc_target(aggstate, &tableoid, &args);

	/* Create pgspider_core_fdw lib name */
	fdwlib_name = psprintf("$libdir/%s", PGSPIDER_CORE_FDW_NAME);

	pgExplainFunc = (ExplainFunc) load_external_function(fdwlib_name, "spdExplainFunction", true, NULL);

	pgExplainFunc(peragg->childfn_oid, tableoid, args, peragg->async, es);
}

/*
 * Judge if it is a distributed function or not.
 */
bool
is_distributed_function(PlanState *planstate)
{

	List	   *targetList = planstate->plan->targetlist;
	TargetEntry *tle;
	Expr	   *node;
	Aggref	   *aggref;
	HeapTuple	aggTuple;
	Oid			parentfn;
	bool		is_dist_func;

	if (targetList == NIL)
		return false;

	tle = linitial_node(TargetEntry, targetList);
	node = tle->expr;

	if (nodeTag(node) != T_Aggref)
		return false;

	aggref = (Aggref *) node;

	aggTuple = SearchSysCache1(AGGFNOID,
							   ObjectIdGetDatum(aggref->aggfnoid));
	if (!HeapTupleIsValid(aggTuple))
		elog(ERROR, "cache lookup failed for aggregate %u",
			 aggref->aggfnoid);

	parentfn = AggregateGetFunctionFromTuple(aggTuple,
											 Anum_pg_aggregate_aggparentfn);
	if (OidIsValid(parentfn))
		is_dist_func = true;
	else
		is_dist_func = false;
	ReleaseSysCache(aggTuple);
	
	return is_dist_func;
}
#endif

