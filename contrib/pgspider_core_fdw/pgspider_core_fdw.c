/*-------------------------------------------------------------------------
 *
 * pgspider_core_fdw.c
 *		  Main source code of pgspider_core_fdw
 *
 * Portions Copyright (c) 2018, TOSHIBA CORPERATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_core_fdw/pgspider_core_fdw.c
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"
#include "c.h"
#include "fmgr.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif


#include <stddef.h>
#include <sys/time.h>
#include <unistd.h>
#include <pthread.h>
#include <math.h>
#include "access/table.h"
#include "access/xact.h"
#include "catalog/pg_type.h"
#include "commands/explain.h"
#include "catalog/pg_proc.h"
#include "foreign/fdwapi.h"
#include "foreign/foreign.h"
#include "executor/spi.h"
#include "miscadmin.h"
#include "nodes/nodeFuncs.h"
#include "nodes/makefuncs.h"
#include "optimizer/pathnode.h"
#include "optimizer/paths.h"
#include "optimizer/planmain.h"
#include "optimizer/plancat.h"
#include "optimizer/restrictinfo.h"
#include "optimizer/optimizer.h"
#include "optimizer/tlist.h"
#include "parser/parsetree.h"
#include "storage/ipc.h"
#include "utils/guc.h"
#include "utils/builtins.h"
#include "utils/datum.h"
#include "utils/syscache.h"
#include "utils/lsyscache.h"
#include "storage/lmgr.h"
#include "catalog/pg_foreign_table.h"
#include "pgspider_core_fdw_defs.h"
#include "funcapi.h"
#include "catalog/pg_operator.h"
#include "pgspider_core_fdw.h"
#ifndef WITHOUT_KEEPALIVE
#include "pgspider_keepalive/pgspider_keepalive.h"
#endif

#define BUFFERSIZE 1024
#define QUERY_LENGTH 512
#define MAX_URL_LENGTH	256

/* See pg_proc.h or pg_aggregate.h */
#define COUNT_OID 2147
#define SUM_OID 2108
#define STD_OID 2155
#define VAR_OID 2148

#define AVG_MIN_OID 2100
#define AVG_MAX_OID 2106
#define VAR_MIN_OID 2148
#define VAR_MAX_OID 2153
#define STD_MIN_OID 2154
#define STD_MAX_OID 2159

#define SUM_BIGINT_OID 2107
#define SUM_INT4_OID 2108
#define SUM_INT2_OID 2109
#define SUM_FLOAT4_OID 2110
#define SUM_FLOAT8_OID 2111
#define SUM_NUMERI_OID 2114

#define MIN_BIGINT_OID 2131
#define MIN_INT4_OID  2132
#define MIN_INT2_OID  2133
#define MIN_FLOAT4_OID 2135
#define MIN_FLOAT8_OID 2136
#define MIN_NUMERI_OID 2146

#define MAX_BIGINT_OID 2115
#define MAX_INT4_OID  2116
#define MAX_INT2_OID  2117
#define MAX_FLOAT4_OID 2119
#define MAX_FLOAT8_OID 2120
#define MAX_NUMERI_OID 2130

#define OPEXPER_INT4_OID 514
#define OPEXPER_INT4_FUNCID 141
#define OPEXPER_INT2_OID 526
#define OPEXPER_INT2_FUNCID 152
#define OPEXPER_INT8_OID 686
#define OPEXPER_INT8_FUNCID 465
#define OPEXPER_NUMERI_OID 1760
#define OPEXPER_NUMERI_FUNCID 1726
#define FLOAT8MUL_OID 594
#define FLOAT8MUL_FUNID 216
#define DOUBLE_LENGTH 8

/* FDW module name */
#define PGSPIDER_FDW_NAME "pgspider_fdw"
#define MYSQL_FDW_NAME "mysql_fdw"
#define FILE_FDW_NAME "file_fdw"
#define AVRO_FDW_NAME "avro_fdw"
#define POSTGRES_FDW_NAME "postgres_fdw"
#define PARQUET_S3_FDW_NAME "parquet_s3_fdw"

/* Temporary table name used for calculation of aggregate functions */
#define AGGTEMPTABLE "__spd__temptable"

/* Return true if avg, var, stddev */
#define IS_SPLIT_AGG(aggfnoid) ((aggfnoid >= AVG_MIN_OID && aggfnoid <= AVG_MAX_OID) ||(aggfnoid >= VAR_MIN_OID && aggfnoid <= VAR_MAX_OID) ||(aggfnoid >= STD_MIN_OID && aggfnoid <= STD_MAX_OID))
/* Affect memory and BeginForeignScan time */
#define SPD_TUPLE_QUEUE_LEN 5000
/* Index of the last element removed */
#define SPD_LAST_GET_IDX(QUEUE) ((QUEUE)->start - 1)
/* For checking single node or multiple node */
#define SPD_SINGLE_NODE	1

typedef enum
{
	SPD_FS_STATE_INIT,
	SPD_FS_STATE_BEGIN,
	SPD_FS_STATE_ITERATE,
	SPD_FS_STATE_END,
	SPD_FS_STATE_FINISH,
	SPD_FS_STATE_ERROR,
}			SpdForeignScanThreadState;


/*
 * This structure stores tuples of child thread for passing to parent.
 * It is allocated for each thread.
 */
typedef struct SpdTupleQueue
{
	struct TupleTableSlot *tuples[SPD_TUPLE_QUEUE_LEN];
	int			start;			/* index of the first element */
	int			len;			/* number of the elements */
	int			isFinished;		/* true if scan is finished */
	bool		skipLast;		/* true if skip last value copy */
	pthread_mutex_t qmutex;		/* mutex */
}			SpdTupleQueue;

/* This structure stores child thread information. */
typedef struct ForeignScanThreadInfo
{
	struct FdwRoutine *fdwroutine;	/* Foreign Data wrapper  routine */
	struct ForeignScanState *fsstate;	/* ForeignScan state data */
	int			eflags;			/* it used to set on Plan nodes(bitwise OR of
								 * the flag bits ) */
	Oid			serverId;		/* use it for server id */
	ForeignServer *foreignServer;	/* cache this for performance */
	ForeignDataWrapper *fdw;	/* cache this for performance */
	bool		requestEndScan; /* main thread request endForeingScan to child
								 * thread */
	bool		requestRescan;	/* main thread request rescan to child thread */
	bool		requestStartScan; /* main thread request startscan to child thread */
	SpdTupleQueue tupleQueue;	/* queue for passing tuples from child to
								 * parent */
	int			childInfoIndex; /* index of child info array */
	MemoryContext threadMemoryContext;
	MemoryContext threadTopMemoryContext;
	pthread_mutex_t nodeMutex;	/* Use for ReScan call */
	SpdForeignScanThreadState state;
	pthread_t	me;
	ResourceOwner thrd_ResourceOwner;
	void	   *private;

}			ForeignScanThreadInfo;

typedef struct ForeignScanThreadArg
{
	ForeignScanThreadInfo *mainThreadsInfo;
	ForeignScanThreadInfo *childThreadsInfo;
} ForeignScanThreadArg;

enum SpdFdwModifyPrivateIndex
{
	/* SQL statement to execute remotely (as a String node) */
	ForeignFdwPrivate,
	/* Integer list of target attribute numbers for INSERT/UPDATE */
	ServerOid
};

/* For EXPLAIN */
static const char *SpdServerstatusStr[] = {
	"Alive",
	"Not specified by IN",
	"Dead"
};

enum SpdServerstatus
{
	ServerStatusAlive,
	ServerStatusIn,
	ServerStatusDead,
};

const char *AggtypeStr[] = {"NON-AGG", "NON-SPLIT", "AVG", "VARIANCE", "STDDEV", "SPREAD"};

enum Aggtype
{
	NON_AGG_FLAG,
	NON_SPLIT_AGG_FLAG,
	AVG_FLAG,
	VAR_FLAG,
	DEV_FLAG,
	SPREAD_FLAG,
};

/* split agg names for searching on catalog (last must be "") */
const char *CatalogSplitAggStr[] = {"SPREAD",
									""};

const enum Aggtype CatalogSplitAggType[] = {SPREAD_FLAG,
											NON_AGG_FLAG};

/* True if the command is non split aggregate function. */
#define IS_NON_SPLIT_AGG(agg_command) \
	(!pg_strcasecmp(agg_command, "MAX") || !pg_strcasecmp(agg_command, "MIN") || \
	!pg_strcasecmp(agg_command, "BIT_OR") || !pg_strcasecmp(agg_command, "BIT_AND") || \
	!pg_strcasecmp(agg_command, "BOOL_AND") || !pg_strcasecmp(agg_command, "BOOL_OR") || \
	!pg_strcasecmp(agg_command, "EVERY") || !pg_strcasecmp(agg_command, "XMLAGG"))

/*
 * 'Mappingcells.mapping' stores index of compressed tlist when splitting one agg into multiple aggs.
 * mapping[AGG_SPLIT_COUNT]  :COUNT(x)
 * mapping[AGG_SPLIT_SUM]    :SUM(x)
 * mapping[AGG_SPLIT_SUM_SQ] :SUM(x*x)
 *
 * mapping[AGG_SPLIT_NONE] is used for non-agg target or non-split agg such as sum and count.
 * Please see spd_add_to_flat_tlist about how we use this struct.
 */
#define AGG_SPLIT_NONE	0
#define AGG_SPLIT_COUNT	0
#define AGG_SPLIT_SUM	1
#define AGG_SPLIT_SUM_SQ	2
/* The number of split agg */
#define MAX_SPLIT_NUM	3

/* This structure represents how an aggregate function is split. */
typedef struct Mappingcells
{
	int			mapping[MAX_SPLIT_NUM]; /* pgspider target list */
	enum Aggtype aggtype;		/* agg type */
	StringInfo	agg_command;	/* agg function name */
	int			original_attnum;	/* original attribute */
	StringInfo	agg_const;		/* constant argument of function */
}			Mappingcells;

/*
 * This struct is used to store a list of mapping cells and the entire expression.
 * It is added to support combination of aggregate functions and operators.
 */
typedef struct Extractcells
{
	List 		*cells;			/* List of mapping cells */
	Expr		*expr;			/* Original expression. It is used for extraction (when create plan)
								 * and for rebuilding query on temp table */
	int			ext_num;		/* Number of extracted cells */
	bool		is_truncated;	/* True if value needs to be truncated. */
	bool		is_having_qual;	/* True if expression is a qualification applied to HAVING. */
	bool		is_contain_group_by;	/* True if expression contains a Var which existed in GROUP BY */
}			Extractcells;

/* This structure stores child information about plan. */
typedef struct ChildInfo
{
	/* USE ONLY IN PLANNING */
	RelOptInfo *baserel;
	PlannerInfo *grouped_root_local;
	RelOptInfo *grouped_rel_local;
	List	   *url_list;
	AggPath    *aggpath;
#ifdef ENABLE_PARALLEL_S3
	Value	   *s3file;
#endif
	RelOptInfo	*joinrel;	/* Child relation info for join pushdown */
	FdwRoutine *fdwroutine;

	/* USE IN BOTH PLANNING AND EXECUTION */
	PlannerInfo *root;
	Plan	   *plan;
	enum SpdServerstatus child_node_status;
	Oid			server_oid;		/* child table's server oid */
	Oid			oid;			/* child table's table oid */
	Agg		   *pAgg;			/* "Aggref" for Disable of aggregation push
								 * down servers */
	bool		pseudo_agg;		/* True if aggregate function is calcuated on pgspider_core.
								 * It mean that it is not pushed down. This is a cache for
								 * searching pPseudoAggList by server oid. */

	/* USE ONLY IN EXECUTION */
	int			index_threadinfo;	/* index for ForeignScanThreadInfo array */
}			ChildInfo;

/*
 * FDW-specific planner information is kept in RelOptInfo.fdw_private for a
 * pgspider_core_fdw foreign table. For a baserel, this struct is created by
 * pgspiderGetForeignRelSize, although some fields are not filled till later.
 * pgspiderGetForeignJoinPaths creates it for a joinrel, and
 * pgspiderGetForeignUpperPaths creates it for an upperrel.
 */
typedef struct SpdRelationInfo
{
	/*
	 * True means that the relation can be pushed down. Always true for simple
	 * foreign scan.
	 */
	bool		pushdown_safe;

	/*
	 * Restriction clauses, divided into safe and unsafe to pushdown subsets.
	 * All entries in these lists should have RestrictInfo wrappers; that
	 * improves efficiency of selectivity and cost estimation.
	 */
	List	   *remote_conds;
	List	   *local_conds;

	/* Actual remote restriction clauses for scan (sans RestrictInfos) */
	List	   *final_remote_exprs;

	/* Estimated size and cost for a scan, join, or grouping/aggregation. */
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;

	/*
	 * Estimated costs excluding costs for transferring those rows from the
	 * foreign server. These are only used by estimate_path_cost_size().
	 */
	Cost		rel_startup_cost;
	Cost		rel_total_cost;

	/* Cached catalog information. */
	ForeignTable *table;
	ForeignServer *server;
	UserMapping *user;			/* only set in use_remote_estimate mode */

	/*
	 * Name of the relation while EXPLAINing ForeignScan. It is used for join
	 * relations but is set for all relations. For join relation, the name
	 * indicates which foreign tables are being joined and the join type used.
	 */
	char	*relation_name;

	/* Outer relation information */
	RelOptInfo *outerrel;

	/* Grouping information */
	List	   *grouped_tlist;

	/* Subquery information */
	bool		make_outerrel_subquery; /* do we deparse outerrel as a
										 * subquery? */
	bool		make_innerrel_subquery; /* do we deparse innerrel as a
										 * subquery? */
	Relids		lower_subquery_rels;	/* all relids appearing in lower
										 * subqueries */

	/*
	 * Index of the relation.  It is used to create an alias to a subquery
	 * representing the relation.
	 */
	int			relation_index;
}			SpdRelationInfo;

/*
 * SpdFdwPrivate keeps child node plan information for each child table belonging to the parent table.
 * pgspider_core creates plans for child table node from each spd_GetForeignRelSize(), spd_GetForeignPaths(), spd_GetForeignPlan().
 * SpdFdwPrivate is created at spd_GetForeignSize() using spd_AllocatePrivate(),
 * and freed at spd_EndForeignScan() using spd_ReleasePrivate().
 *
 * We classify SpdFdwPrivate member into the following categories
 *  a) necessary only in planning routines(before getForeignPlan)
 *  b) necessary only in execution routines(after beginForeignScan)
 *  c) necessary both in planning and execution routines.
 * We should pass only c) members from getForeignPlan to beginForeignScan for speedup.
 * We use serialization and de-serialization method for passing c) members.
 */
typedef struct SpdFdwPrivate
{
	/* USE ONLY IN PLANNING */
	List	   *baserestrictinfo;	/* root node base strict info */
	List	   *upper_targets;
	List	   *url_list;		/* IN clause for SELECT */

	PlannerInfo *spd_root;		/* Copy of root planner info. This is used by
								 * aggregation pushdown. */
	SpdRelationInfo rinfo;	/* pgspider relation info */
	TupleDesc	child_comp_tupdesc; /* temporary tuple desc */
	List	   *pPseudoAggList; /* List of server oids which aggregate function is not pushed down */
	RelOptInfo *joinrel_child;	/* Child join relation. */

	/* USE IN BOTH PLANNING AND EXECUTION */
	int			node_num;		/* number of child tables */
	int			nThreads;		/* Number of alive threads */
	int			idx_url_tlist;	/* index of __spd_url in tlist. -1 if not used */

	bool		agg_query;		/* aggregation flag */
	bool		isFirst;		/* First time of iteration foreign scan with
								 * aggregation query */
	bool		groupby_has_spdurl; /* flag to check if __spd_url is in group clause */

	List	   *child_comp_tlist;	/* child complite target list */
	List	   *child_tlist;	/* child target list without __spd_url */
	List	   *mapping_tlist;	/* mapping list orig and pgspider */

	List	   *groupby_target; /* group target tlist number */

	TupleTableSlot *child_comp_slot;	/* temporary slot */
	StringInfo	groupby_string; /* GROUP BY string for aggregation temp table */

	ChildInfo  *childinfo;		/* ChildInfo List */

	List	   *having_quals;	/* qualitifications for HAVING which are passed to childs */
	bool		has_having_quals;	/* Root plan has qualification applied for HAVING */
	bool		has_stub_star_regex_function;	/* mark if query has stub star regex function */
	bool		record_function;	/* mark if function return record type */

	/* USE ONLY IN EXECUTION */
	pthread_t	foreign_scan_threads[NODES_MAX];	/* child node thread  */
	Datum	  **agg_values;		/* aggregation temp table result set */
	bool	  **agg_nulls;		/* aggregation temp table result set */
	int			agg_tuples;		/* Number of aggregation tuples from temp
								 * table */
	int			agg_num;		/* agg_values cursor */
	Oid		   *agg_value_type; /* aggregation parameters */
	Datum	   *ret_agg_values; /* result for groupby */
	int			temp_num_cols;	/* number of columns of temp table */
	char	   *temp_table_name;	/* name of temp table */
	bool		is_explain;		/* explain or not */
	MemoryContext es_query_cxt; /* temporary context */
	pthread_rwlock_t scan_mutex;
	int			startNodeId;	/* Node ID to start checking child slot for round robin */
}			SpdFdwPrivate;

typedef struct SpdFdwModifyState
{
	Oid			modify_server_oid;
}			SpdFdwModifyState;

typedef struct SpdurlWalkerContext
{
	PlannerInfo	   *root;
	List		   *target_exprs;
}		SpdurlWalkerContext;

/* Refer spd_GetChildRoot. */
typedef struct SpdChildRootId {
	Oid serveroid;
	int childid;
} SpdChildRootId;

/* local function forward declarations */
void		_PG_init(void);

static void spd_GetForeignRelSize(PlannerInfo *root, RelOptInfo *baserel,
					  Oid foreigntableid);
static void spd_GetForeignPaths(PlannerInfo *root, RelOptInfo *baserel,
					Oid foreigntableid);
static ForeignScan *spd_GetForeignPlan(PlannerInfo *root, RelOptInfo *baserel,
				   Oid foreigntableid, ForeignPath *best_path,
				   List *tlist, List *scan_clauses,
				   Plan *outer_plan);
static void spd_BeginForeignScan(ForeignScanState *node, int eflags);
static TupleTableSlot *spd_IterateForeignScan(ForeignScanState *node);
static void spd_ReScanForeignScan(ForeignScanState *node);
static void spd_EndForeignScan(ForeignScanState *node);
static void spd_GetForeignUpperPaths(PlannerInfo *root,
						 UpperRelationKind stage,
						 RelOptInfo *input_rel,
						 RelOptInfo *output_rel, void *extra);
static void spd_GetForeignJoinPaths(PlannerInfo *root,
											  RelOptInfo *joinrel,
											  RelOptInfo *outerrel,
											  RelOptInfo *innerrel,
											  JoinType jointype,
											  JoinPathExtraData *extra);

/*
 * Helper functions
 */
static bool foreign_grouping_ok(PlannerInfo *root, RelOptInfo *grouped_rel);
static Path *get_foreign_grouping_paths(PlannerInfo *root,
						   RelOptInfo *input_rel,
						   RelOptInfo *grouped_rel);

static void spd_AddForeignUpdateTargets(Query *parsetree,
							RangeTblEntry *target_rte,
							Relation target_relation);

static List *spd_PlanForeignModify(PlannerInfo *root,
					  ModifyTable *plan,
					  Index resultRelation,
					  int subplan_index);

static void spd_BeginForeignModify(ModifyTableState *mtstate,
					   ResultRelInfo *rinfo,
					   List *fdw_private,
					   int subplan_index,
					   int eflags);

static void spd_ExplainForeignScan(ForeignScanState *node, ExplainState *es);

static TupleTableSlot *spd_ExecForeignInsert(EState *estate,
					  ResultRelInfo *rinfo,
					  TupleTableSlot *slot,
					  TupleTableSlot *planSlot);

static TupleTableSlot *spd_ExecForeignUpdate(EState *estate,
					  ResultRelInfo *rinfo,
					  TupleTableSlot *slot,
					  TupleTableSlot *planSlot);

static TupleTableSlot *spd_ExecForeignDelete(EState *estate,
					  ResultRelInfo *rinfo,
					  TupleTableSlot *slot,
					  TupleTableSlot *planSlot);

static void spd_EndForeignModify(EState *estate,
					 ResultRelInfo *rinfo);

static bool spd_can_skip_deepcopy(char *fdwname);
static bool spd_checkurl_clauses(PlannerInfo *root, List *baserestrictinfo);
static void rebuild_target_expr(Node* node, StringInfo buf, Extractcells *extcells,
								int *cellid, List *groupby_target, bool isfirst);
#ifdef ENABLE_PARALLEL_S3
List *getS3FileList(Oid foreigntableid);
#endif
static bool is_target_contain_group_by(PathTarget *grouping_target, List *groupClause,
									   Expr *expr, ListCell *lc, int index);

/* Queue functions */
static bool spd_queue_add(SpdTupleQueue * que, TupleTableSlot *slot, bool deepcopy);
static TupleTableSlot *spd_queue_get(SpdTupleQueue * que, bool *is_finished);
static void spd_queue_reset(SpdTupleQueue * que);
static void spd_queue_init(SpdTupleQueue * que, TupleDesc tupledesc, const TupleTableSlotOps *tts_ops, bool skipLast);
static void spd_queue_notify_finish(SpdTupleQueue * que);
static void spd_execute_local_query(char *query, pthread_rwlock_t *scan_mutex);

static List *spd_catalog_makedivtlist(Aggref *aggref, List *newList, enum Aggtype aggtype);
static TupleTableSlot *spd_AddSpdUrl(ForeignScanThreadInfo *pFssThrdInfo, TupleTableSlot *parent_slot, TupleTableSlot *node_slot, SpdFdwPrivate *fdw_private, bool is_first_iterate);
static TupleTableSlot *spd_AddSpdUrlForGroupby(ForeignScanThreadInfo *pFssThrdInfo, TupleTableSlot *parent_slot, TupleTableSlot *node_slot, SpdFdwPrivate *fdw_private);
static Datum spd_AddSpdUrlForRecord(Datum record, char *spdurl);

/* postgresql.conf paramater */
static bool throwErrorIfDead;
static bool isPrintError;

/* We need to make postgres_fdw_options variable initial one time */
static bool isPostgresFdwInit = false;
pthread_mutex_t postgres_fdw_mutex = PTHREAD_MUTEX_INITIALIZER;

/* We write lock SPI function and read lock child fdw routines */
pthread_mutex_t error_mutex = PTHREAD_MUTEX_INITIALIZER;
/*
 * g_node_offset shows child node offset into list_thread_top_contexts array.
 * In a query execution, a single child node may have multiple child threads
 * when there are multiple scannings, so each child threads must have its own
 * child thread top memory context to avoid corrupt child top memory by threads
 * concurrency.
 */
static int g_node_offset = 0;
static List *list_thread_top_contexts = NIL;
static int64 temp_table_id = 0;
static bool registered_reset_callback = false;

/* Utility functions for target list */
static List *spd_add_to_flat_tlist(List *tlist, Expr *exprs, List **mapping_tlist,
								   List **compress_tlist_tle, Index sgref, List **upper_targets,
								   bool allow_duplicate, bool is_having_qual, bool is_contain_group_by, SpdFdwPrivate * fdw_private);
static bool	is_field_selection(List *tlist);
static bool	is_cast_function(List *tlist);
static List	*spd_update_scan_tlist(List *tlist, List *child_scan_tlist, PlannerInfo *root);
static TargetEntry *spd_tlist_member_match_var(Var *var, List *targetlist);
static TargetEntry *spd_tlist_member(Expr *node, List *targetlist, int *target_num);
static void spd_apply_pathtarget_labeling_to_tlist(List *tlist, PathTarget *target);

static bool spd_expr_has_spdurl(PlannerInfo *root, Node *expr, List **target_exprs);
static bool check_spdurl_walker(Node *node, SpdurlWalkerContext *ctx);


/************************************************************
 *                                                          *
 *                  PUBLIC FUNCTION                         *
 *                                                          *
 ***********************************************************/

/*
 * spd_get_node_num
 *
 * Get number of child node.
 */
int
spd_get_node_num(RelOptInfo *baserel)
{
	SpdFdwPrivate *fdw_private = (SpdFdwPrivate *) baserel->fdw_private;

	return fdw_private->node_num;
}


/************************************************************
 *                                                          *
 *                  STATIC FUNCTION                         *
 *                                                          *
 ***********************************************************/

/*
 * spd_tlist_member_match_var
 *
 * Modified version of tlist_member_match_var.
 * Ignore duplicate item in the target list.
 */
static TargetEntry *
spd_tlist_member_match_var(Var *var, List *targetlist)
{
	ListCell   *temp;

	foreach(temp, targetlist)
	{
		TargetEntry *tlentry = (TargetEntry *) lfirst(temp);
		Var		   *tlvar = (Var *) tlentry->expr;

		/* Ignore the duplicate item if it's ressortgroupref was set */
		if (!tlvar || !IsA(tlvar, Var) || (tlentry->ressortgroupref != 0))
			continue;
		if (var->varno == tlvar->varno &&
			var->varattno == tlvar->varattno &&
			var->varlevelsup == tlvar->varlevelsup &&
			var->vartype == tlvar->vartype)
			return tlentry;
	}
	return NULL;
}

/*
 * spd_tlist_member
 *
 * Modified version of tlist_member with a new parameter 'target_num'.
 *
 * Finds the (first) member of the given tlist whose expression is
 * equal() to the given expression. Result is NULL if no such member.
 *
 * @param[in] node Serching expression
 * @param[in] targetlist Target list to be searched
 * @param[out] target_num The index in the list will be set if found
 */
static TargetEntry *
spd_tlist_member(Expr *node, List *targetlist, int *target_num)
{
	ListCell   *temp;

	*target_num = 0;
	foreach(temp, targetlist)
	{
		TargetEntry *tlentry = (TargetEntry *) lfirst(temp);

		if (equal(node, tlentry->expr))
			return tlentry;
		*target_num += 1;
	}
	return NULL;
}

/*
 * spd_apply_pathtarget_labeling_to_tlist
 *
 * Modified version of apply_pathtarget_labeling_to_tlist.
 * Apply any sortgrouprefs in the PathTarget to matching tlist entries without error checking.
 */
static void
spd_apply_pathtarget_labeling_to_tlist(List *tlist, PathTarget *target)
{
	int			i;
	ListCell   *lc;

	/* Nothing to do if PathTarget has no sortgrouprefs data */
	if (target->sortgrouprefs == NULL)
		return;

	/* Reset sortgrouprefs in the tlist */
	foreach(lc, tlist)
	{
		TargetEntry *tle = (TargetEntry *) lfirst(lc);

		tle->ressortgroupref = 0;
	}

	i = 0;
	foreach(lc, target->exprs)
	{
		Expr	   *expr = (Expr *) lfirst(lc);
		TargetEntry *tle;

		if (target->sortgrouprefs[i])
		{
			int target_num = 0; 	/* this variable is not used */

			/*
			 * For Vars, use tlist_member_match_var's weakened matching rule;
			 * this allows us to deal with some cases where a set-returning
			 * function has been inlined, so that we now have more knowledge
			 * about what it returns than we did when the original Var was
			 * created.  Otherwise, use regular equal() to find the matching
			 * TLE.  (In current usage, only the Var case is actually needed;
			 * but it seems best to have sane behavior here for non-Vars too.)
			 */
			if (expr && IsA(expr, Var))
				tle = spd_tlist_member_match_var((Var *) expr, tlist);
			else
				tle = spd_tlist_member(expr, tlist, &target_num);

			if (tle != NULL && tle->ressortgroupref == 0)
				tle->ressortgroupref = target->sortgrouprefs[i];
		}
		i++;
	}
}

/*
 * Remove items which are not pushed down in the scan tlist.
 */
static List *
spd_update_scan_tlist(List *tlist, List *child_scan_tlist, PlannerInfo *root)
{
	ListCell *lc;
	Var *spdurl_var = NULL;
	List *scan_tlist;

	foreach (lc, tlist)
	{
		TargetEntry *tle = (TargetEntry *)lfirst(lc);
		RangeTblEntry *rte;
		char *colname;

		if (IsA((Node *)tle->expr, Var))
		{
			Var *var = (Var *)tle->expr;

			rte = planner_rt_fetch(var->varno, root);
			colname = get_attname(rte->relid, var->varattno, false);
			if (strcmp(colname, SPDURL) == 0)
			{
				spdurl_var = var;
				break;
			}
		}
	}

	/* Place __spd_url into the last of tlist */
	if (spdurl_var)
		scan_tlist = add_to_flat_tlist(child_scan_tlist, list_make1(spdurl_var));
	else
		scan_tlist = list_copy(child_scan_tlist);

	return scan_tlist;
}

static SpdFdwPrivate *
spd_AllocatePrivate()
{
	/* Take from TopTransactionContext */
	SpdFdwPrivate *p = (SpdFdwPrivate *)
	MemoryContextAllocZero(TopTransactionContext, sizeof(*p));

	return p;
}

/* Declaration for dynamic loading. */
PG_FUNCTION_INFO_V1(pgspider_core_fdw_handler);

/*
 * pgspider_fdw_handler populates a FdwRoutine with pointers to the functions
 * implemented within this file.
 */
Datum
pgspider_core_fdw_handler(PG_FUNCTION_ARGS)
{
	FdwRoutine *fdwroutine = makeNode(FdwRoutine);

	fdwroutine->GetForeignRelSize = spd_GetForeignRelSize;
	fdwroutine->GetForeignPaths = spd_GetForeignPaths;
	fdwroutine->GetForeignPlan = spd_GetForeignPlan;
	fdwroutine->BeginForeignScan = spd_BeginForeignScan;
	fdwroutine->IterateForeignScan = spd_IterateForeignScan;
	fdwroutine->ReScanForeignScan = spd_ReScanForeignScan;
	fdwroutine->EndForeignScan = spd_EndForeignScan;
	fdwroutine->GetForeignUpperPaths = spd_GetForeignUpperPaths;
	fdwroutine->GetForeignJoinPaths = spd_GetForeignJoinPaths;
	fdwroutine->ExplainForeignScan = spd_ExplainForeignScan;

	fdwroutine->AddForeignUpdateTargets = spd_AddForeignUpdateTargets;
	fdwroutine->PlanForeignModify = spd_PlanForeignModify;
	fdwroutine->BeginForeignModify = spd_BeginForeignModify;
	fdwroutine->ExecForeignInsert = spd_ExecForeignInsert;
	fdwroutine->ExecForeignUpdate = spd_ExecForeignUpdate;
	fdwroutine->ExecForeignDelete = spd_ExecForeignDelete;
	fdwroutine->EndForeignModify = spd_EndForeignModify;

	PG_RETURN_POINTER(fdwroutine);
}

/*
 * Return true if having FieldSelect node
 */
static bool	is_field_selection(List *tlist)
{
	ListCell *lc;

	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);

		if (IsA((Node *) tle->expr, FieldSelect))
			return true;
	}

	return false;
}

/*
 * Return true if all elements are FuncExpr node
 */
static bool is_cast_function(List *tlist)
{
	ListCell *lc;

	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);

		if (!IsA((Node *) tle->expr, FuncExpr))
			return false;
	}

	return true;
}

/**
 * Return true if the oid is for split agg functions except avg, var and stddev
 */
static bool
is_catalog_split_agg(Oid oid, enum Aggtype *type)
{
	const char *proname;
	int			i;
	bool		result = false;

	proname = get_func_name(oid);

	for (i = 0; CatalogSplitAggStr[i][0] != '\0'; i++)
	{
		if (!pg_strcasecmp(proname, CatalogSplitAggStr[i]))
		{
			result = true;

			if (type)
				*type = CatalogSplitAggType[i];
			break;
		}
	}

	return result;
}

/*
 * spd_can_skip_deepcopy
 *
 * Return true if this fdw can skip deepcopy when adding tuple to a queue.
 * Returning true means that fdw allocates tuples in CurrentMemoryContext.
 *
 * @param[in] fdwname FDW module name
 */
static bool
spd_can_skip_deepcopy(char *fdwname)
{
	if (strcmp(fdwname, AVRO_FDW_NAME) == 0)
		return true;
	return false;
}

/**
 * spd_queue_notify_finish
 *
 * Notify parent thread that child fdw scan is finished.
 *
 * @param[in,out] que Tuple queue
 */
static void
spd_queue_notify_finish(SpdTupleQueue * que)
{
	pthread_mutex_lock(&que->qmutex);
	que->isFinished = true;
	pthread_mutex_unlock(&que->qmutex);
}

/*
 * spd_queue_add
 *
 * Add 'slot' to queue.
 * Return false immediately if queue is full.
 * Deepcopy each column value of slot If 'deepcopy' is true.
 *
 * @param[in,out] que Tuple queue
 * @param[in] slot Tuple slot to be added
 * @param[in] deepcopy True if requireing deep copy
 */
static bool
spd_queue_add(SpdTupleQueue * que, TupleTableSlot *slot, bool deepcopy)
{
	int			natts;
	int			idx;
	int			i;

	pthread_mutex_lock(&que->qmutex);

	if (que->len >= SPD_TUPLE_QUEUE_LEN)
	{
		/* queue is full */
		pthread_mutex_unlock(&que->qmutex);
		return false;
	}

	idx = (que->start + que->len) % SPD_TUPLE_QUEUE_LEN;

	if (idx == SPD_LAST_GET_IDX(que))
	{
		/* This tuple slot may be being used by core */
		pthread_mutex_unlock(&que->qmutex);
		return false;
	}

	/* Clear slot before storing new data */
	ExecClearTuple(que->tuples[idx]);

	/* Not minimal tuple */
	Assert(!TTS_IS_MINIMALTUPLE(slot));

	/*
	 * Note: In some fdws, for instance, file_fdw, we need to check whether the heap tuple is not null or not.
	 * If it is NULL, we cannot use copy_heap_tuple() because __spd_url column attribute is not valid.
	 */
	if (TTS_IS_HEAPTUPLE(slot) && ((HeapTupleTableSlot*) slot)->tuple)
	{
		/*
		 * TODO: we can probably skip heap_copytuple as in virtual tuple case
		 * for some fdws
		 */
		ExecStoreHeapTuple(slot->tts_ops->copy_heap_tuple(slot),
					que->tuples[idx],
					false);
	}
	else
	{
		/* Virtual tuple */
		natts = que->tuples[idx]->tts_tupleDescriptor->natts;
		memcpy(que->tuples[idx]->tts_isnull, slot->tts_isnull, natts * sizeof(bool));

		/* Deep copy tts_values[i] if necessary. */
		if (deepcopy)
		{
			FormData_pg_attribute *attrs = slot->tts_tupleDescriptor->attrs;

			for (i = 0; i < natts; i++)
			{
				if (slot->tts_isnull[i])
					continue;
				que->tuples[idx]->tts_values[i] = datumCopy(slot->tts_values[i],
															attrs[i].attbyval, attrs[i].attlen);
			}
		}
		else

			/*
			 * Even if deep copy is not necessary, tts_values array cannot be
			 * reused because it is overwritten by child fdw
			 */
			memcpy(que->tuples[idx]->tts_values, slot->tts_values, (natts * sizeof(Datum)));

		ExecStoreVirtualTuple(que->tuples[idx]);
	}

	que->len++;
	pthread_mutex_unlock(&que->qmutex);
	return true;
}

/*
 * spd_queue_get
 *
 * Return tuple slot if exist else NULL if queue is empty.
 *
 * @param[in,out] que Tuple queue
 * @param[out] is_finished True will be set if queue is empty and child foreign scan is finished.
 */
static TupleTableSlot *
spd_queue_get(SpdTupleQueue * que, bool *is_finished)
{
	TupleTableSlot *temp;

	pthread_mutex_lock(&que->qmutex);
	if (que->len == 0)
	{
		/* Update only when queue is empty */
		*is_finished = que->isFinished;
		pthread_mutex_unlock(&que->qmutex);
		return NULL;
	}

	temp = que->tuples[que->start];
	que->start = (que->start + 1) % SPD_TUPLE_QUEUE_LEN;
	que->len--;

	pthread_mutex_unlock(&que->qmutex);


	return temp;
}

/*
 * spd_queue_get
 *
 * Reset queue.
 *
 * @param[in,out] que Tuple queue
 */
static void
spd_queue_reset(SpdTupleQueue * que)
{
	que->len = 0;
	que->start = 0;
	que->isFinished = false;
}

/*
 * spd_queue_init
 *
 * Initialize the queue.
 *
 * @param[in,out] que Tuple queue
 * @param[in] tupledesc Tuple descriptor
 * @param[in] tts_ops Tuple table slot options
 * @param[in] skip_last True if it should skip the last column
 */
static void
spd_queue_init(SpdTupleQueue * que, TupleDesc tupledesc, const TupleTableSlotOps *tts_ops, bool skip_last)
{
	int			j;

	que->skipLast = skip_last;
	/* Create tuple descriptor for queue */
	for (j = 0; j < SPD_TUPLE_QUEUE_LEN; j++)
	{
		TupleTableSlot *slot = MakeSingleTupleTableSlot(tupledesc, tts_ops);

		que->tuples[j] = slot;
		slot->tts_values = palloc(tupledesc->natts * sizeof(Datum));
		slot->tts_isnull = palloc(tupledesc->natts * sizeof(bool));
	}
	spd_queue_reset(que);
	pthread_mutex_init(&que->qmutex, NULL);
}

/**
 * Print mapping_tlist for debug.
 *
 * @param[in] mapping_tlist Mapping information of target list to be printed out
 * @param[in] loglevel Log level
 */
static void
print_mapping_tlist(List *mapping_tlist, int loglevel)
{
	ListCell   *lc;

	foreach(lc, mapping_tlist)
	{
		Extractcells	*extcells = lfirst(lc);
		ListCell		*extlc;
		foreach(extlc, extcells->cells)
		{
			Mappingcells *cells = lfirst(extlc);

			elog(loglevel, "mapping_tlist (%d %d %d)/ original_attnum=%d  aggtype=\"%s\"",
				cells->mapping[AGG_SPLIT_COUNT], cells->mapping[AGG_SPLIT_SUM], cells->mapping[AGG_SPLIT_SUM_SQ],
				cells->original_attnum, AggtypeStr[cells->aggtype]);
		}
	}
}

/**
 * spd_append_procname
 *
 * Add a aggregate function name of 'aggoid' to 'aggname'
 * by fetching from pg_proc system catalog.
 *
 * @param[in] aggoid Aggregate function oid
 * @param[out] aggname Aggregate function name
 */
static void
spd_append_procname(Oid aggoid, StringInfo aggname)
{
	const char *proname;

	proname = get_func_name(aggoid);
	appendStringInfoString(aggname, proname);
}


/*
 * spd_SerializeSpdFdwPrivate
 *
 * Serialize fdw_private as a list to be copied using copyObject.
 * Each element of list in serialize and deserialize functions should be the same order.
 *
 * @param[in] fdw_private SpdFdwPrivate to be serialized
 * @return List Serialized list
 */
static List *
spd_SerializeSpdFdwPrivate(SpdFdwPrivate * fdw_private)
{
	ListCell   *lc;
	List	   *lfdw_private = NIL;
	int			i = 0;

	lfdw_private = lappend(lfdw_private, makeInteger(fdw_private->node_num));
	lfdw_private = lappend(lfdw_private, makeInteger(fdw_private->nThreads));
	lfdw_private = lappend(lfdw_private, makeInteger(fdw_private->idx_url_tlist));
	lfdw_private = lappend(lfdw_private, makeInteger(fdw_private->agg_query));
	lfdw_private = lappend(lfdw_private, makeInteger(fdw_private->isFirst));
	lfdw_private = lappend(lfdw_private, makeInteger(fdw_private->groupby_has_spdurl));
	lfdw_private = lappend(lfdw_private, makeInteger(fdw_private->has_stub_star_regex_function));
	lfdw_private = lappend(lfdw_private, makeInteger(fdw_private->record_function));

	if (fdw_private->agg_query)
	{
		lfdw_private = lappend(lfdw_private, fdw_private->groupby_target);
		lfdw_private = lappend(lfdw_private, fdw_private->child_comp_tlist);
		lfdw_private = lappend(lfdw_private, fdw_private->child_tlist);

		/* Save length of mapping tlist */
		lfdw_private = lappend(lfdw_private, makeInteger(list_length(fdw_private->mapping_tlist)));

		foreach(lc, fdw_private->mapping_tlist)
		{
			Extractcells	*extcells = (Extractcells *) lfirst(lc);
			ListCell		*tmplc;

			/* Save length of extracted list */
			lfdw_private = lappend(lfdw_private, makeInteger(list_length(extcells->cells)));

			foreach(tmplc, extcells->cells)
			{
				Mappingcells *cells = lfirst(tmplc);

				for (i = 0; i < MAX_SPLIT_NUM; i++)
				{
					lfdw_private = lappend(lfdw_private, makeInteger(cells->mapping[i]));
				}
				lfdw_private = lappend(lfdw_private, makeInteger(cells->aggtype));
				lfdw_private = lappend(lfdw_private, makeString(cells->agg_command ? cells->agg_command->data : ""));
				lfdw_private = lappend(lfdw_private, makeString(cells->agg_const ? cells->agg_const->data : ""));
				lfdw_private = lappend(lfdw_private, makeInteger(cells->original_attnum));
			}
			lfdw_private = lappend(lfdw_private, extcells->expr);
			lfdw_private = lappend(lfdw_private, makeInteger(extcells->ext_num));
			lfdw_private = lappend(lfdw_private, makeInteger((extcells->is_truncated)?1:0));
			lfdw_private = lappend(lfdw_private, makeInteger((extcells->is_having_qual)?1:0));
			lfdw_private = lappend(lfdw_private, makeInteger((extcells->is_contain_group_by)?1:0));
		}
		lfdw_private = lappend(lfdw_private, makeString(fdw_private->groupby_string ? fdw_private->groupby_string->data : ""));
		lfdw_private = lappend(lfdw_private, makeInteger((fdw_private->has_having_quals)?1:0));
	}

	for (i = 0; i < fdw_private->node_num; i++)
	{
		ChildInfo *pChildInfo = &fdw_private->childinfo[i];
		lfdw_private = lappend(lfdw_private, makeInteger(pChildInfo->pseudo_agg));
		lfdw_private = lappend(lfdw_private, makeInteger(pChildInfo->child_node_status));
		lfdw_private = lappend(lfdw_private, makeInteger(pChildInfo->server_oid));
		lfdw_private = lappend(lfdw_private, makeInteger(pChildInfo->oid));

		/* Plan */
		lfdw_private = lappend(lfdw_private, copyObject(pChildInfo->plan));

		/* Agg plan */
		if (pChildInfo->pseudo_agg)
			lfdw_private = lappend(lfdw_private, copyObject(pChildInfo->pAgg));

		/* Root */
		lfdw_private = lappend(lfdw_private, copyObject(pChildInfo->root->parse));

	}

	return lfdw_private;
}

/*
 * spd_DeserializeSpdFdwPrivate
 *
 * De-serialize a list to SpdFdwPrivate structure.
 * Each element of list in serialize and deserialize functions should be the same order.
 *
 * @param[in] lfdw_private Serialized list created by spd_SerializeSpdFdwPrivate
 * @return SpdFdwPrivate* Deserialized fdw_private
 */
static SpdFdwPrivate *
spd_DeserializeSpdFdwPrivate(List *lfdw_private)
{
	int			i = 0;
	int			j = 0;
	int			mapping_tlist_len = 0;
	ListCell   *lc = list_head(lfdw_private);
	SpdFdwPrivate *fdw_private = palloc0(sizeof(SpdFdwPrivate));

	fdw_private->node_num = intVal(lfirst(lc));
	lc = lnext(lfdw_private, lc);

	fdw_private->nThreads = intVal(lfirst(lc));
	lc = lnext(lfdw_private, lc);

	fdw_private->idx_url_tlist = intVal(lfirst(lc));
	lc = lnext(lfdw_private, lc);

	fdw_private->agg_query = intVal(lfirst(lc)) ? true : false;
	lc = lnext(lfdw_private, lc);

	fdw_private->isFirst = intVal(lfirst(lc)) ? true : false;
	lc = lnext(lfdw_private, lc);

	fdw_private->groupby_has_spdurl = intVal(lfirst(lc)) ? true : false;
	lc = lnext(lfdw_private, lc);

	fdw_private->has_stub_star_regex_function = intVal(lfirst(lc)) ? true : false;
	lc = lnext(lfdw_private, lc);

	fdw_private->record_function = intVal(lfirst(lc)) ? true : false;
	lc = lnext(lfdw_private, lc);

	if (fdw_private->agg_query)
	{
		fdw_private->groupby_target = (List *) lfirst(lc);
		lc = lnext(lfdw_private, lc);

		fdw_private->child_comp_tlist = (List *) lfirst(lc);
		lc = lnext(lfdw_private, lc);

		fdw_private->child_tlist = (List *) lfirst(lc);
		lc = lnext(lfdw_private, lc);

		/* Get length of mapping_tlist */
		mapping_tlist_len = intVal(lfirst(lc));
		lc = lnext(lfdw_private, lc);

		fdw_private->mapping_tlist = NIL;
		for (i = 0; i < mapping_tlist_len; i++)
		{
			int 			ext_tlist_num = 0;
			Extractcells	*extcells = (Extractcells *) palloc0(sizeof(Extractcells));

			ext_tlist_num = intVal(lfirst(lc));
			lc = lnext(lfdw_private, lc);

			for (j = 0; j < ext_tlist_num; j++)
			{
				int k;
				Mappingcells *cells = (Mappingcells *) palloc0(sizeof(Mappingcells));

				for (k = 0; k < MAX_SPLIT_NUM; k++)
				{
					cells->mapping[k] = intVal(lfirst(lc));
					lc = lnext(lfdw_private, lc);
				}
				cells->aggtype = intVal(lfirst(lc));
				lc = lnext(lfdw_private, lc);
				cells->agg_command = makeStringInfo();
				appendStringInfoString(cells->agg_command, strVal(lfirst(lc)));
				lc = lnext(lfdw_private, lc);
				cells->agg_const = makeStringInfo();
				appendStringInfoString(cells->agg_const, strVal(lfirst(lc)));
				lc = lnext(lfdw_private, lc);
				cells->original_attnum = intVal(lfirst(lc));
				lc = lnext(lfdw_private, lc);
				extcells->cells = lappend(extcells->cells, cells);
			}
			extcells->expr = lfirst(lc);
			lc = lnext(lfdw_private, lc);
			extcells->ext_num = intVal(lfirst(lc));
			lc = lnext(lfdw_private, lc);
			extcells->is_truncated = (intVal(lfirst(lc))?true:false);
			lc = lnext(lfdw_private, lc);
			extcells->is_having_qual = (intVal(lfirst(lc))?true:false);
			lc = lnext(lfdw_private, lc);
			extcells->is_contain_group_by = (intVal(lfirst(lc))?true:false);
			lc = lnext(lfdw_private, lc);
			fdw_private->mapping_tlist = lappend(fdw_private->mapping_tlist, extcells);
		}

		fdw_private->groupby_string = makeStringInfo();
		appendStringInfoString(fdw_private->groupby_string, strVal(lfirst(lc)));
		lc = lnext(lfdw_private, lc);

		fdw_private->has_having_quals =(intVal(lfirst(lc))?true:false);
		lc = lnext(lfdw_private, lc);
	}

	fdw_private->childinfo = (ChildInfo *) palloc0(sizeof(ChildInfo) * fdw_private->node_num);
	for (i = 0; i < fdw_private->node_num; i++)
	{
		ChildInfo *pChildInfo = &fdw_private->childinfo[i];

		pChildInfo->pseudo_agg = intVal(lfirst(lc));
		lc = lnext(lfdw_private, lc);

		pChildInfo->child_node_status = intVal(lfirst(lc));
		lc = lnext(lfdw_private, lc);

		pChildInfo->server_oid = intVal(lfirst(lc));
		lc = lnext(lfdw_private, lc);

		pChildInfo->oid = intVal(lfirst(lc));
		lc = lnext(lfdw_private, lc);

		/* Plan */
		pChildInfo->plan = (Plan *) lfirst(lc);
		lc = lnext(lfdw_private, lc);

		/* Agg plan */
		if (pChildInfo->pseudo_agg)
		{
			pChildInfo->pAgg = (Agg *) lfirst(lc);
			lc = lnext(lfdw_private, lc);
		}

		/* Root */
		pChildInfo->root = (PlannerInfo *) palloc0(sizeof(PlannerInfo));
		pChildInfo->root->parse = (Query *) lfirst(lc);
		lc = lnext(lfdw_private, lc);
	}

	return fdw_private;
}

/**
 * extract_expr_walker
 *
 * Use expression_tree_walker to walk through the expression.
 * Return true if detect any node which is not Var or Const.
 * The 2nd argument is not used but need to be defined so that
 * we call expression_tree_walker.
 *
 * @param[in] node Expression to be checked
 * @param[in] param Context argument
 */
static bool
extract_expr_walker(Node *node, void *param)
{
	if (node == NULL)
		return false;

	if (!(IsA(node, Var)) && !(IsA(node, Const)))
		return true;

	return expression_tree_walker(node, extract_expr_walker, (void *) param);
}

/**
 * is_need_extract
 *
 * Check if it is necessary to extract the expression.
 * When expression contains only const and var, no need to extract.
 *
 * @param[in] node Expression to be checked
 */
static bool
is_need_extract(Node *node)
{
	return expression_tree_walker(node, extract_expr_walker, NULL);
}

/**
 * init_mappingcell
 *
 * Initialize value for a mapping cell
 *
 * @param[in,out] mapcells The mapping cells that needs to be initialized
 */
static void
init_mappingcell(Mappingcells **mapcells)
{
	int i;

	*mapcells = (struct Mappingcells *) palloc0(sizeof(struct Mappingcells));

	/* Initialize mapcells */
	for (i = 0; i < MAX_SPLIT_NUM; i++)
	{
		/* these store 0-index, so initialize with -1 */
		(*mapcells)->mapping[i] = -1;
	}
	(*mapcells)->original_attnum = -1;
	(*mapcells)->agg_command = makeStringInfo();
	(*mapcells)->agg_const = makeStringInfo();
}

/**
 * add_node_to_list
 *
 * This function is used to add node to tlist, compress_tlist_tle and compress_tlist.
 * It also set data for mapcell.
 *
 * @param[in] expr Expression
 * @param[in,out] tlist Flattened tlist
 * @param[in,out] mapcells The mapping cell which is corresponding to the expr
 * @param[in,out] compress_tlist_tle Compressed child tlist with target entry
 * @param[in,out] compress_tlist Compressed child tlist without target entry
 * @param[in] sgref Sort group reference for target entry
 * @param[in] is_agg_ope True if combination of aggregate function and operators
 * @param[in] allow_duplicate Allow or not allow a target can be duplicated in grouping target list
 */
static void
add_node_to_list(Expr *expr, List **tlist, Mappingcells **mapcells, List **compress_tlist_tle, List **compress_tlist, Index sgref, bool is_agg_ope, bool allow_duplicate)
{
	/* Non-agg group by target or non-split agg such as sum or count */
	TargetEntry	*tle_temp;
	TargetEntry	*tle;
	int			target_num = 0;
	int			next_resno = list_length(*tlist) + 1;
	int			next_resno_temp = list_length(*compress_tlist_tle) + 1;

	tle = spd_tlist_member(expr, *tlist, &target_num);
	/* original */
	if (allow_duplicate || !tle)
	{
		if (allow_duplicate)
			target_num = list_length(*tlist);

		/*
		 * When expression is a combination of operator and aggregate function,
		 * no need to add to tlist because the whole expression has been added
		 * in spd_add_to_flat_tlist.
		 */
		if (is_agg_ope == false)
		{
			tle = makeTargetEntry(copyObject(expr),
								next_resno++,
								NULL,
								false);
			tle->ressortgroupref = sgref;
			*tlist = lappend(*tlist, tle);
		}
		else
			target_num = list_length(*tlist) - 1;
	}
	else if (tle)
	{
		target_num = list_length(*tlist) - 1;
	}
	(*mapcells)->aggtype = NON_AGG_FLAG;
	(*mapcells)->original_attnum = target_num;
	/* div tlist */
	tle_temp = spd_tlist_member(expr, *compress_tlist_tle, &target_num);
	if (allow_duplicate || !tle_temp)
	{
		tle_temp = makeTargetEntry(copyObject(expr),
									next_resno_temp++,
									NULL,
									false);
		tle_temp->ressortgroupref = sgref;
		*compress_tlist_tle = lappend(*compress_tlist_tle, tle_temp);
		*compress_tlist = lappend(*compress_tlist, expr);
	}
	else if (tle_temp)
	{
		/*
		 * If var was added inside extract_expr, ressortgroupref was not set.
		 * we need to set it at this place
		 */
		if (sgref > 0)
			tle_temp->ressortgroupref = sgref;
	}
	/* If allow duplicate, so need to change mapping to the last of compress_tlist. */
	if (allow_duplicate)
	{
		(*mapcells)->mapping[AGG_SPLIT_NONE] = list_length(*compress_tlist) - 1;
	}
	else
	{
		(*mapcells)->mapping[AGG_SPLIT_NONE] = target_num;
	}
}

/**
 * set_split_agg_info
 * Set aggfnoid, aggtype, aggtranstype
 *
 * @param[in,out] tempAgg - temporary aggregate
 */
static void
set_split_agg_info(Aggref *tempAgg, Oid aggfnoid, Oid aggtype, Oid aggtranstype)
{
	tempAgg->aggfnoid = aggfnoid;
	tempAgg->aggtype = aggtype;
	tempAgg->aggtranstype = aggtranstype;
}
/**
 * set_split_op_info
 *
 * Set aggfnoid, aggtype, aggtranstype
 *
 * @param[in,out] opexpr Expression to be set
 */
static void
set_split_op_info(OpExpr *opexpr, Oid opno, Oid opfuncid, Oid opresulttype)
{
	opexpr->opno = opno;
	opexpr->opfuncid = opfuncid;
	opexpr->opresulttype = opresulttype;
}
/**
 * set_split_numeric_info
 *
 * Set information for splitted SUM(x) and SUM(x*x) when aggtype is NUMERICOID
 *
 * @param[in,out] tempAgg Expression of aggregate function
 * @param[in,out] opexpr Expression of function argument
 */
static void
set_split_numeric_info(Aggref *tempAgg, OpExpr *opexpr)
{
	Oid argoid = linitial_oid(tempAgg->aggargtypes);

	/*
	 * SUM will return bigint (INT8) for smallint (INT2) or int (INT4) arguments,
	 * numeric for bigint (INT8) arguments.
	 * For numeric type and bigint, aggtranstype is INTERNALOID.
	 * For int and smallint, aggtranstype is INT8OID.
	 * For x*x, the multiply operator will return the same type as input.
	 */
	switch (argoid)
	{
		case NUMERICOID:
		{
			set_split_agg_info(tempAgg, SUM_NUMERI_OID, NUMERICOID, INTERNALOID);
			if(opexpr)
				set_split_op_info(opexpr, OPEXPER_NUMERI_OID, OPEXPER_NUMERI_FUNCID, NUMERICOID);
			break;
		}
		case INT8OID:
		{
			set_split_agg_info(tempAgg, SUM_BIGINT_OID, NUMERICOID, INTERNALOID);
			if(opexpr)
				set_split_op_info(opexpr, OPEXPER_INT8_OID, OPEXPER_INT8_FUNCID, INT8OID);
			break;
		}
		case INT4OID:
		{
			set_split_agg_info(tempAgg, SUM_INT4_OID, INT8OID, INT8OID);
			if(opexpr)
				set_split_op_info(opexpr, OPEXPER_INT4_OID, OPEXPER_INT4_FUNCID, INT4OID);
			break;
		}
		case INT2OID:
		{
			set_split_agg_info(tempAgg, SUM_INT2_OID, INT8OID, INT8OID);
			if(opexpr)
				set_split_op_info(opexpr, OPEXPER_INT2_OID, OPEXPER_INT2_FUNCID, INT2OID);
			break;
		}
		default:
			Assert(false);
			break;
	}
}

/*
 * add_nodes_to_list
 *
 * This function is used to add multiple nodes to tlist, compress_tlist_tle and compress_tlist.
 * It also set data for mapcell.
 *
 * @param[in] expr - the original expression
 * @param[in] exprs - the expression list to add
 * @param[in,out] tlist - flattened tlist
 * @param[in,out] mapcells - the mapping cell which is corresponding to the expr
 * @param[in,out] compress_tlist_tle - compressed child tlist with target entry
 * @param[in,out] compress_tlist - compressed child tlist without target entry
 * @param[in] is_agg_ope - true if combination of aggregate function and operators
 * @param[in] allow_duplicate - allow or not allow a target can be duplicated in grouping target list
 */
static void
add_nodes_to_list(Expr *aggref, List *exprs, List **tlist, Mappingcells **mapcells, List **compress_tlist_tle, List **compress_tlist, bool is_agg_ope, bool allow_duplicate)
{
	/* Non-agg group by target or non-split agg such as sum or count */
	TargetEntry	*tle_temp;
	TargetEntry	*tle;
	int			target_num = 0;
	int			next_resno = list_length(*tlist) + 1;
	int			next_resno_temp = list_length(*compress_tlist_tle) + 1;
	ListCell	*lc;
	int         i = 0;

	tle = spd_tlist_member(aggref, *tlist, &target_num);
	/* original */
	if (allow_duplicate || !tle)
	{
		if (allow_duplicate)
			target_num = list_length(*tlist);

		/* When expression is a combination of operator and aggregate function,
		 * no need to add to tlist because the whole expression has been added in spd_add_to_flat_tlist
		 */
		if (is_agg_ope == false)
		{
			tle = makeTargetEntry(copyObject(aggref),
								  next_resno++,
								  NULL,
								  false);
			*tlist = lappend(*tlist, tle);
		}
		else
			target_num = list_length(*tlist) - 1;
	}
	else if (tle)
	{
		target_num = list_length(*tlist) - 1;
	}

	(*mapcells)->original_attnum = target_num;

	foreach(lc, exprs)
	{
		Expr *expr = (Expr *) lfirst(lc);

		tle_temp = spd_tlist_member(expr, *compress_tlist_tle, &target_num);
		if (allow_duplicate || !tle_temp)
		{
			tle_temp = makeTargetEntry(copyObject(expr),
									   next_resno_temp++,
									   NULL,
									   false);
			*compress_tlist_tle = lappend(*compress_tlist_tle, tle_temp);
			*compress_tlist = lappend(*compress_tlist, expr);
		}
		/* If allow duplicate, so need to change mapping to the last of compress_tlist */
		if (allow_duplicate)
		{
			(*mapcells)->mapping[i] = list_length(*compress_tlist) - 1;
		}
		else
		{
			(*mapcells)->mapping[i] = target_num;
		}
		i++;
	}
}

/**
 * createVarianceExpr
 *
 * Create an expression of variance.
 *
 * @param[in,out] baseExpr An expression is created by copying this base expression
 * @param[in] making_div_list True if this function is called from spd_makedivtlist(),
 *                            false if called from extract_expr().
 * @return Created expression
 */
static Aggref *
createVarianceExpr(Aggref *baseExpr, bool making_div_list)
{
	TargetEntry *tarexpr;
	Aggref	   *tempVar = copyObject(baseExpr);
	TargetEntry *oparg = (TargetEntry *) linitial(tempVar->args);
	Var		   *opvar = (Var *) oparg->expr;
	OpExpr	   *opexpr = (OpExpr *) makeNode(OpExpr);

	opexpr->xpr.type = T_OpExpr;
	opexpr->opretset = false;
	opexpr->opcollid = 0;
	opexpr->inputcollid = 0;
	opexpr->location = 0;
	opexpr->args = NULL;

	tempVar->aggfnoid = VAR_OID;

	/* Create top targetentry */
	if (tempVar->aggtype == NUMERICOID)
	{
		set_split_numeric_info(tempVar, opexpr);
	}
	else if (!making_div_list || tempVar->aggtype <= FLOAT8OID || tempVar->aggtype >= FLOAT4OID)
	{
		set_split_agg_info(tempVar, SUM_FLOAT8_OID, FLOAT8OID, FLOAT8OID);
		set_split_op_info(opexpr, FLOAT8MUL_OID, FLOAT8MUL_FUNID, FLOAT8OID);
	}
	opexpr->args = lappend(opexpr->args, opvar);
	opexpr->args = lappend(opexpr->args, opvar);
	/* Create var targetentry */
	tarexpr = makeTargetEntry((Expr *) opexpr,
							1,
							NULL,
							false);
	tarexpr->ressortgroupref = oparg->ressortgroupref;
	tempVar->args = lappend(tempVar->args, tarexpr);
	tempVar->args = list_delete_first(tempVar->args);

	return tempVar;
}

static void
extract_expr_Var(Node *node, Extractcells **extcells, List **tlist, List **compress_tlist_tle, List **compress_tlist, int sgref, bool is_agg_ope)
{
	Aggref 			*aggref = (Aggref*) node;
	Mappingcells 	*mapcells;

	/* Initialize mapcells. */
	init_mappingcell(&mapcells);

	/* Append original target list. */
	if (IsA(node, Aggref))
	{
		mapcells->aggtype = NON_SPLIT_AGG_FLAG;
		spd_append_procname(aggref->aggfnoid, mapcells->agg_command);

		/*
		* If aggregate functions is string_agg(expression, delimiter)
		* check the delimiter exist or not, if exist save the delimiter
		* to mapcells->agg_const.
		*/
		if (!pg_strcasecmp(mapcells->agg_command->data, "STRING_AGG"))
		{
			ListCell   *arg;
			/* Check all the arguments. */
			foreach(arg, aggref->args)
			{
				TargetEntry *tle = (TargetEntry *) lfirst(arg);
				Node	   *node = (Node *) tle->expr;

				switch (nodeTag(node))
				{
				case T_Const:
				{
					Const *const_tmp = (Const *) node;

					if (const_tmp->constisnull)
					{
						continue;
					}

					spd_deparse_const(const_tmp, mapcells->agg_const, -1);
				}
				break;
				default:
					break;
				}
			}
		}
	}
	else
		mapcells->aggtype = NON_AGG_FLAG;

	add_node_to_list((Expr *) node, tlist, &mapcells, compress_tlist_tle, compress_tlist, sgref, is_agg_ope, false);
	(*extcells)->ext_num++;

	(*extcells)->cells = lappend((*extcells)->cells, mapcells);
}

static void
extract_expr_Aggref(Node *node, Extractcells **extcells, List **tlist, List **compress_tlist_tle, List **compress_tlist, int sgref, bool is_agg_ope)
{
	Aggref 			*aggref = (Aggref*) node;
	int 			target_num = 0;
	TargetEntry 	*tle;
	TargetEntry 	*tle_temp;
	int				next_resno = list_length(*tlist) + 1;
	int				next_resno_temp = list_length(*compress_tlist_tle) + 1;
	Mappingcells 	*mapcells;
	enum Aggtype    aggtype;

	/* When aggref is avg, variance or stddev, split it. */
	if (IS_SPLIT_AGG(aggref->aggfnoid))
	{
		/* Prepare COUNT Query. */
		Aggref	   *tempCount = copyObject(aggref);
		Aggref	   *tempSum = copyObject(aggref);

		/* Initialize mapcells. */
		init_mappingcell(&mapcells);

		if (aggref->aggtype == FLOAT4OID || aggref->aggtype == FLOAT8OID)
			set_split_agg_info(tempSum, SUM_FLOAT8_OID, FLOAT8OID, FLOAT8OID);
		else if (aggref->aggtype == NUMERICOID)
			set_split_numeric_info(tempSum, NULL);
		else
			set_split_agg_info(tempSum, SUM_INT4_OID, INT8OID, INT8OID);

		set_split_agg_info(tempCount, COUNT_OID, INT8OID, INT8OID);

		/* Add original mapping list to avg, var, stddev. */
		if (!spd_tlist_member((Expr*) aggref, *tlist, &target_num))
		{
			if (is_agg_ope == false)
			{
				tle = makeTargetEntry(copyObject((Expr*) aggref),
					next_resno++,
					NULL,
					false);
				*tlist = lappend(*tlist, tle);
				mapcells->original_attnum = target_num;
			}
			else
				mapcells->original_attnum = list_length(*tlist) - 1;
		}
		else
			mapcells->original_attnum = list_length(*tlist) - 1;

		/* Set avg flag. */
		if (aggref->aggfnoid >= AVG_MIN_OID && aggref->aggfnoid <= AVG_MAX_OID)
			mapcells->aggtype = AVG_FLAG;
		else if (aggref->aggfnoid >= VAR_MIN_OID && aggref->aggfnoid <= VAR_MAX_OID)
			mapcells->aggtype = VAR_FLAG;
		else if (aggref->aggfnoid >= STD_MIN_OID && aggref->aggfnoid <= STD_MAX_OID)
			mapcells->aggtype = DEV_FLAG;

		spd_append_procname(aggref->aggfnoid, mapcells->agg_command);

		/* count */
		if (!spd_tlist_member((Expr *) tempCount, *compress_tlist_tle, &target_num))
		{
			tle_temp = makeTargetEntry((Expr *) tempCount,
				next_resno_temp++,
				NULL,
				false);
			*compress_tlist_tle = lappend(*compress_tlist_tle, tle_temp);
			*compress_tlist = lappend(*compress_tlist, tempCount);
		}
		mapcells->mapping[AGG_SPLIT_COUNT] = target_num;
		/* sum */
		if (!spd_tlist_member((Expr *) tempSum, *compress_tlist_tle, &target_num))
		{
			tle_temp = makeTargetEntry((Expr *) tempSum,
				next_resno_temp++,
				NULL,
				false);
			*compress_tlist_tle = lappend(*compress_tlist_tle, tle_temp);
			*compress_tlist = lappend(*compress_tlist, tempSum);
		}
		mapcells->mapping[AGG_SPLIT_SUM] = target_num;
		(*extcells)->ext_num = (*extcells)->ext_num + 2;
		/* variance(SUM(x*x)) */
		if ((aggref->aggfnoid >= VAR_MIN_OID && aggref->aggfnoid <= VAR_MAX_OID)
			|| (aggref->aggfnoid >= STD_MIN_OID && aggref->aggfnoid <= STD_MAX_OID))
		{
			Aggref	   *tempVar = createVarianceExpr(aggref, false);

			if (!spd_tlist_member((Expr *) tempVar, *compress_tlist_tle, &target_num))
			{
				tle_temp = makeTargetEntry((Expr *) tempVar,
					next_resno_temp++,
					NULL,
					false);
				*compress_tlist_tle = lappend(*compress_tlist_tle, tle_temp);
				*compress_tlist = lappend(*compress_tlist, tle_temp);
			}
			mapcells->mapping[AGG_SPLIT_SUM_SQ] = target_num;
			(*extcells)->ext_num++;
		}

		(*extcells)->cells = lappend((*extcells)->cells, mapcells);
	}
	else if (is_catalog_split_agg(aggref->aggfnoid, &aggtype))
	{
		List   *exprs = NULL;

		/* Initialize mapcells. */
		init_mappingcell(&mapcells);

		exprs = spd_catalog_makedivtlist(aggref, exprs, aggtype);
		if (exprs != NULL)
		{
			add_nodes_to_list((Expr *) node, exprs, tlist, &mapcells, compress_tlist_tle, compress_tlist, is_agg_ope, false);
			mapcells->aggtype = aggtype;
			appendStringInfoString(mapcells->agg_command, AggtypeStr[aggtype]);
			(*extcells)->ext_num += list_length(exprs);
		}

		(*extcells)->cells = lappend((*extcells)->cells, mapcells);
	}
	else
		extract_expr_Var(node, extcells, tlist, compress_tlist_tle, compress_tlist, sgref, is_agg_ope);

}

/**
 * extract_expr
 *
 * Extract an expression.
 *
 * @param[in] node Expression
 * @param[in,out] extcells Target mapping list
 * @param[in,out] tlist Flattened tlist
 * @param[in,out] compress_tlist_tle Compressed child tlist with target entry
 * @param[in,out] compress_tlist Compressed child tlist without target entry
 * @param[in] sgref Sort group reference for target entry
 * @param[in] is_agg_ope True if combination of aggregate function and operators
 */
static void
extract_expr(Node *node, Extractcells **extcells, List **tlist, List **compress_tlist_tle, List **compress_tlist, int sgref, bool is_agg_ope)
{
	if (node == NULL)
		return;

	switch(nodeTag(node))
	{
		case T_OpExpr:
		case T_BoolExpr:
		case T_ScalarArrayOpExpr:
		{
			List		*args;
			bool		is_extract_expr;

			if (IsA(node, OpExpr))
				args = ((OpExpr *)node)->args;
			else if (IsA(node, BoolExpr))
				args = ((BoolExpr *)node)->args;
			else
				args = ((ScalarArrayOpExpr *)node)->args;

			if ((*extcells)->is_contain_group_by || (*extcells)->is_having_qual)
				is_extract_expr = true;
			else
				is_extract_expr = is_need_extract(node);

			if (is_extract_expr)
				extract_expr((Node *)args, extcells, tlist, compress_tlist_tle, compress_tlist, sgref, is_agg_ope);
			else
			{
				/* When no need to extract, add the node to the compress_tlist and compress_tlist_tle directly. */
				Mappingcells	*mapcells;

				init_mappingcell(&mapcells);
				add_node_to_list((Expr *) node, tlist, &mapcells, compress_tlist_tle, compress_tlist, sgref, is_agg_ope, false);
				(*extcells)->ext_num++;
				(*extcells)->cells = lappend((*extcells)->cells, mapcells);
			}
			break;
		}
		case T_List:
		{
			List		*l = (List *) node;
			ListCell	*lc;

			foreach(lc, l)
			{
				extract_expr((Node *)lfirst(lc), extcells, tlist, compress_tlist_tle, compress_tlist, sgref, is_agg_ope);
			}
			break;
		}
		case T_FuncExpr:
		{
			FuncExpr	*func = (FuncExpr *) node;

			if(func->args)
				extract_expr((Node *)func->args, extcells, tlist, compress_tlist_tle, compress_tlist, sgref, is_agg_ope);
			break;
		}
		case T_Aggref:
			extract_expr_Aggref(node, extcells, tlist, compress_tlist_tle, compress_tlist, sgref, is_agg_ope);
			break;
		case T_Var:
			extract_expr_Var(node, extcells, tlist, compress_tlist_tle, compress_tlist, sgref, is_agg_ope);
			break;
		case T_CoerceViaIO:
		{
			CoerceViaIO *cio = (CoerceViaIO *) node;

			if (cio->arg)
				extract_expr((Node *)cio->arg, extcells, tlist, compress_tlist_tle, compress_tlist, sgref, is_agg_ope);
			break;
		}
		default:
			break;
	}
}

/**
 * spd_add_to_flat_tlist
 *
 * Modified version of add_to_flat_tlist.
 * Add more items to a flattened tlist (if they're not already in it).
 * Split-agg is divided into multiple aggref. For example, if 'expr' is avg,
 * then count and sum is added to 'compress_tlist_tle' and 'compress_tlist'.
 * 'compress_tlist_tle' and 'compress_tlist' are almost the same except for target entry.
 *
 * Example of mapping_tlist by print_mapping_tlist():
 *
 * postgres=# explain verbose SELECT sum(i),t, avg(i), sum(i)  FROM t1 GROUP BY t;
 * DEBUG:  mapping_tlist (0 -1 -1)/ original_attnum=0  aggtype="NON-SPLIT"
 * DEBUG:  mapping_tlist (1 -1 -1)/ original_attnum=1 aggtype="NON-AGG"
 * DEBUG:  mapping_tlist (2 0 -1)/ original_attnum=2  aggtype="AVG"
 * DEBUG:  mapping_tlist (0 -1 -1)/ original_attnum=0 aggtype="NON-SPLIT"
 *                               QUERY PLAN
 * ----------------------------------------------------------------------
 * Foreign Scan
 *   Output: (sum(i)), t, (avg(i)), (sum(i))
 *      Remote SQL: SELECT sum(i), t, count(i) FROM public.t1 GROUP BY 2
 *
 * As Remote SQL shows, compress_tlist is sum(i), t, count(i).
 * mapping_tlist (2 0 -1) of avg() means count is mapped to 2nd of compress_tlist
 * and sum is mapped to 0th of compress_tlist.
 *
 * @param[in,out] tlist Flattened tlist
 * @param[in] expr Expression (usually, but not necessarily, Vars)
 * @param[out] mapping_tlist Target mapping list for child node
 * @param[out] compress_tlist_tle Compressed child tlist with target entry
 * @param[in] sgref Sort group reference for target entry
 * @param[out] compress_tlist Compressed child tlist without target entry
 * @param[in] allow_duplicate Allow or not allow a target can be duplicated in grouping target list
 */
static List *
spd_add_to_flat_tlist(List *tlist, Expr *expr, List **mapping_tlist,
					  List **compress_tlist_tle, Index sgref,
					  List **compress_tlist, bool allow_duplicate,
					  bool is_having_qual, bool is_contain_group_by, SpdFdwPrivate *fdw_private)
{
	int			next_resno = list_length(tlist) + 1;
	int			target_num = 0;
	TargetEntry *tle;
	Extractcells* extcells = (struct Extractcells *) palloc0(sizeof(struct Extractcells));

	extcells->cells = NIL;
	extcells->expr = copyObject(expr);
	extcells->is_truncated = false;
	extcells->is_having_qual = is_having_qual;
	extcells->is_contain_group_by = is_contain_group_by;

	if (fdw_private->node_num == SPD_SINGLE_NODE)
	{
		Mappingcells *mapcells;

		init_mappingcell(&mapcells);
		add_node_to_list(expr, &tlist, &mapcells, compress_tlist_tle, compress_tlist, sgref, false, allow_duplicate);

		extcells->cells = lappend(extcells->cells, mapcells);

		*mapping_tlist = lappend(*mapping_tlist, extcells);
		return tlist;
	}

	switch (nodeTag(expr))
	{
		case T_OpExpr:
		case T_BoolExpr:
		{
			/* Add original mapping list. */
			if (!spd_tlist_member(expr, tlist, &target_num) && !is_having_qual)
			{
				tle = makeTargetEntry(copyObject(expr),
									  next_resno++,
									  NULL,
									  false);
				tlist = lappend(tlist, tle);

			}
			if (is_having_qual)
				extract_expr((Node *) expr, &extcells, &tlist, compress_tlist_tle, compress_tlist, sgref, false);
			else
				extract_expr((Node *) expr, &extcells, &tlist, compress_tlist_tle, compress_tlist, sgref, true);
			break;
		}
		case T_Aggref:
		{
			extract_expr((Node *) expr, &extcells, &tlist, compress_tlist_tle, compress_tlist, sgref, false);
			break;
		}
		case T_FieldSelect:
		{
			List		*aggvars;
			ListCell	*lc;

			aggvars = pull_var_clause((Node *) expr,
									  PVC_INCLUDE_AGGREGATES);
			foreach(lc, aggvars)
			{
				Expr	   *inner_expr = (Expr *) lfirst(lc);

				if (IsA(inner_expr, Aggref))
				{
					Mappingcells *mapcells;

					init_mappingcell(&mapcells);
					add_node_to_list(inner_expr, &tlist, &mapcells, compress_tlist_tle, compress_tlist, sgref, false, allow_duplicate);

					extcells->cells = lappend(extcells->cells, mapcells);

					if (!(((Aggref *) inner_expr)->aggfnoid) >= FirstBootstrapObjectId
						&& (((Aggref *) inner_expr)->aggtype) == TEXTOID)
						fdw_private->record_function = true;
				}
			}
			break;
		}
		default:
		{
			Mappingcells *mapcells;

			/* Check stub function */
			if (IsA(expr, FuncExpr) && spd_is_stub_star_regex_function(expr))
			{
				fdw_private->has_stub_star_regex_function = true;
				fdw_private->record_function = true;
			}

			init_mappingcell(&mapcells);
			add_node_to_list(expr, &tlist, &mapcells, compress_tlist_tle, compress_tlist, sgref, false, allow_duplicate);

			extcells->cells = lappend(extcells->cells, mapcells);
			break;
		}
	}

	*mapping_tlist = lappend(*mapping_tlist, extcells);
	return tlist;
}

/**
 * Get a list of child node oid and the number of childs of the parent table.
 * Child table name is calculated based on the format of child table name which
 * "ParentTableName__NodeName__sequenceNum".
 *
 * @param[in] foreigntableid Parent table's oid
 * @param[out] nums The number of child nodes
 * @param[out] oid Oid list of child table
 */
static void
spd_calculate_datasouce_count(Oid foreigntableid, int *nums, Oid **oid)
{
	char		query[QUERY_LENGTH];
	int			ret;
	int			i;
	int			spi_temp;
	MemoryContext oldcontext;
	MemoryContext spicontext;

	oldcontext = CurrentMemoryContext;
	ret = SPI_connect();
	if (ret < 0)
		elog(ERROR, "SPI_connect failed. Returned %d.", ret);

	/*
	 * Child table name is "ParentTableName_NodeName_sequenceNum".
	 * We creates SQL searching child table oids whose name is like "ParentTableName_...".
	 * Tables whose name is like "<tablename>_<columnname>_seq" is excepted, because this is
	 * a system table.
	 * If using function pg_catalog.setval, for example, pg_catalog.setval('<table>_<column>_seq', 10, false),
	 * relname of this system also matches the format.
	 */
	sprintf(query, "SELECT oid, relname FROM pg_class WHERE (relname LIKE (SELECT relname FROM pg_class WHERE oid = %d) ||"
			"'\\_\\_%%') AND (relname NOT LIKE '%%\\_%%\\_seq') ORDER BY relname;", foreigntableid);

	ret = SPI_execute(query, true, 0);
	if (ret != SPI_OK_SELECT)
	{
		SPI_finish();
		elog(ERROR, "SPI_execute failed. Retrned %d. SQL is %s.", ret, query);
	}
	spi_temp = SPI_processed;
	spicontext = MemoryContextSwitchTo(oldcontext);
	*oid = (Oid *) palloc0(sizeof(Oid) * spi_temp);
	MemoryContextSwitchTo(spicontext);

	if (SPI_processed > 0)
	{
		for (i = 0; i < SPI_processed; i++)
		{
			bool		isnull;

			oid[0][i] = DatumGetObjectId(SPI_getbinval(SPI_tuptable->vals[i], SPI_tuptable->tupdesc, 1, &isnull));
		}
	}

	*nums = SPI_processed;
	SPI_finish();
}

/**
 * Get serverid of the foreign table from id.
 *
 * @param[in] foreigntableid Foreign table id
 * @return Foreign server id
 */
static Oid
serverid_of_relation(Oid foreigntableid)
{
	ForeignTable	*ft = GetForeignTable(foreigntableid);
	return ft->serverid;
}

/**
 * spd_servername_from_tableoid
 *
 * Get a foreign server name from foreign table oid.
 *
 * @param[in] foreigntableid Foreign table id
 * @param[out] srvname Foreign server name
 */
static void
spd_servername_from_tableoid(Oid foreigntableid, char *srvname)
{
	ForeignServer *server;
	HeapTuple	tuple;
	Form_pg_foreign_table fttableform;

	/* First, determine FDW validator associated to the foreign table. */
	tuple = SearchSysCache1(FOREIGNTABLEREL, foreigntableid);
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for function");
	fttableform = (Form_pg_foreign_table) GETSTRUCT(tuple);
	server = GetForeignServer(fttableform->ftserver);
	ReleaseSysCache(tuple);
	sprintf(srvname,"%s", server->servername);
	return;

}

/**
 * spd_calculate_datasouce_oids
 *
 * Get child table oids from parent table name.
 *
 * @param[in] parentTableName Parent table name
 * @param[in] fdw_private Child table plan information
 * @param[out] oid Child table oids
 */
static void
spd_calculate_datasouce_oids(char *parentTableName, SpdFdwPrivate *fdw_private, Oid **oid)
{
	char		query[QUERY_LENGTH];
	char	   *entry = NULL;
	int			i;
	int			ret;
	MemoryContext oldcontext = CurrentMemoryContext;

	/* Get child server name from child's foreign table id. */
	if (fdw_private->url_list == NIL)
	{
		sprintf(query, "SELECT oid from pg_class WHERE relname LIKE \
                '%s\\_\\_\%%' ORDER BY relname;", parentTableName);
	}
	else
	{
		/* If IN clause is used, then return IN child tables only. */
		sprintf(query, "SELECT oid from pg_class WHERE relname LIKE \
                '%s\\_\\_%s\\_\\_\%%' ORDER BY relname;", parentTableName, entry);
	}
	ret = SPI_connect();
	if (ret < 0)
		elog(ERROR, "SPI_connect failed. Returned %d.", ret);
	ret = SPI_execute(query, true, 0);
	if (ret != SPI_OK_SELECT)
	{
		SPI_finish();
		elog(ERROR, "SPI_execute failed. Retrned %d. SQL is %s.", ret, query);
	}
	if (SPI_processed < 1)
	{
		SPI_finish();
		elog(ERROR, "Not found a child table of '%s'.", parentTableName);
	}
	*oid = MemoryContextAlloc(oldcontext, sizeof(Oid) * SPI_processed);
	for (i = 0; i < SPI_processed; i++)
	{
		bool		isnull;

		(*oid)[i] = DatumGetObjectId(SPI_getbinval(SPI_tuptable->vals[i],
												   SPI_tuptable->tupdesc,
												   1,
												   &isnull));
	}
	fdw_private->node_num = SPI_processed;
	SPI_finish();
}

/**
 * spd_ip_from_server_name
 *
 * Get server ip address from server name by searching pg_spd_node_info table.
 *
 * @param[in] serverName Server name
 * @param[out] ip IP address
 */
static void
spd_ip_from_server_name(char *serverName, char *ip)
{
	char		sql[NAMEDATALEN * 2] = {0};
	char	   *ipstr;
	int			ret;

	sprintf(sql, "SELECT ip FROM pg_spd_node_info WHERE servername = '%s';", serverName);
	ret = SPI_connect();
	if (ret < 0)
		elog(ERROR, "SPI_connect failed. Returned %d.", ret);

	ret = SPI_execute(sql, true, 0);
	if (ret != SPI_OK_SELECT)
	{
		SPI_finish();
		elog(ERROR, "SPI_execute failed. Retrned %d. SQL is %s.", ret, sql);
	}

	if (SPI_processed > 1)
	{
		int n = SPI_processed;
		SPI_finish();
		elog(ERROR, "Cannot get server IP correctly. Returned %d", n);
	}

	if (SPI_processed == 1)
	{
		ipstr = SPI_getvalue(SPI_tuptable->vals[0],
								  SPI_tuptable->tupdesc,
								   1);
		strcpy(ip, ipstr);
	}
	SPI_finish();
	return;
}

/**
 * spd_aliveError
 *
 * Emit error with server name information.
 *
 * @param[in] fs Foreign server
 */
static void
spd_aliveError(ForeignServer *fs)
{
	elog(ERROR, "PGSpider can not get data from child node : %s", fs->servername);
}

/**
 * spd_ErrorCb
 *
 * Error callback for child thread.
 *
 * @param[in] arg
 */
static void
spd_ErrorCb(void *arg)
{
	if (throwErrorIfDead)
	{
		pthread_mutex_lock(&error_mutex);
		EmitErrorReport();
		pthread_mutex_unlock(&error_mutex);
	}
}

/*
 * spd_setThreadContext
 *
 * Set error handling configuration and memory context. Additionally, create
 * memory context for IterateForeignScan.
 *
 * @param[in] fssthrdInfo Thread information
 * @param[out] pErrcallback Error handling function is registered here
 * @param[out] tuplectx Created memory context
 */
static void
spd_setThreadContext(ForeignScanThreadInfo *fssthrdInfo, ErrorContextCallback *pErrcallback, MemoryContext *tuplectx)
{

	CurrentResourceOwner = fssthrdInfo->thrd_ResourceOwner;
	TopMemoryContext = fssthrdInfo->threadTopMemoryContext;

	MemoryContextSwitchTo(fssthrdInfo->threadMemoryContext);

	/* Initialize ErrorContext for each child thread. */
	ErrorContext = AllocSetContextCreate(fssthrdInfo->threadMemoryContext,
										"Thread ErrorContext",
										ALLOCSET_DEFAULT_SIZES);
	MemoryContextAllowInCriticalSection(ErrorContext, true);

	tuplectx[0] = AllocSetContextCreate(fssthrdInfo->threadMemoryContext,
										"thread tuple contxt1",
										ALLOCSET_DEFAULT_SIZES);
	tuplectx[1] = AllocSetContextCreate(fssthrdInfo->threadMemoryContext,
										"thread tuple contxt2",
										ALLOCSET_DEFAULT_SIZES);

	/* Declare ereport/elog jump is not available. */
	PG_exception_stack = NULL;
	pErrcallback->callback = spd_ErrorCb;
	pErrcallback->arg = NULL;
	pErrcallback->previous = NULL;
	error_context_stack = pErrcallback;
}

/*
 *	spd_freeThreadContextList
 *
 * 	context_freelists is the thread local variable used in each child thread.
 * 	It is used to save memory context which is allocated/deleted for re-use if any.
 * 	Free all items in the list before thread exit to avoid memory leak.
 */
static void
spd_freeThreadContextList(void)
{
	MemoryContextFreeContextList();
}

/*
 * spd_BeginForeignScanChild
 *
 * BeginForeignScan for child node.
 *
 * @param[in] fssthrdInfoThread information
 * @param[in] pChildInfo Child information
 * @param[in] scan_mutex Mutex for scanning
 * @param[in,out] is_first True if it is the first time
 */
static void
spd_BeginForeignScanChild(ForeignScanThreadInfo *fssthrdInfo, ChildInfo *pChildInfo,
						  pthread_rwlock_t *scan_mutex, bool *is_first)
{
	fssthrdInfo->state = SPD_FS_STATE_BEGIN;

	SPD_READ_LOCK_TRY(scan_mutex);

	PG_TRY();
	{
		/*
		 * If Aggregation does not push down, BeginForeignScan will be executed in
		 * ExecInitNode.
		 */
		if (!pChildInfo->pseudo_agg)
		{
			if (strcmp(fssthrdInfo->fdw->fdwname, POSTGRES_FDW_NAME) == 0 && !isPostgresFdwInit)
			{
				/* We need to make postgres_fdw_options variable initial one time */
				SPD_LOCK_TRY(&postgres_fdw_mutex);
				fssthrdInfo->fdwroutine->BeginForeignScan(fssthrdInfo->fsstate,
														  fssthrdInfo->eflags);
				isPostgresFdwInit = true;
				SPD_UNLOCK_CATCH(&postgres_fdw_mutex);
			}
			else if (strcmp(fssthrdInfo->fdw->fdwname, MYSQL_FDW_NAME) == 0)
			{
				/*
				 * In case child node is mysql_fdw, the main query need to wait
				 * sub-query finished before call BeginForeignScan.
				 * If main query: requestStartScan flag is true.
				 * If sub query: requestStartScan flag is false.
				 * In case subquery, we will call BeginForeignScan immediately.
				 * In case main query, we will wait subquery finished before call BeginForeignScan.
				 */
				if(*is_first && fssthrdInfo->requestStartScan)
				{
					*is_first = false;
					fssthrdInfo->fdwroutine->BeginForeignScan(fssthrdInfo->fsstate,
						fssthrdInfo->eflags);
				}
			}
			else
			{
				fssthrdInfo->fdwroutine->BeginForeignScan(fssthrdInfo->fsstate,
					fssthrdInfo->eflags);
			}
		}
	}
	PG_CATCH();
	{
		fssthrdInfo->state = SPD_FS_STATE_ERROR;
	}
	PG_END_TRY();

	SPD_RWUNLOCK_CATCH(scan_mutex);
}

/*
 * spd_IterateForeignScanChildLoop
 *
 * Call IterateForeignScan repeatedlly. The result is stored into queue.
 * If pgspider_core_fdw calculates the aggregate, this function executes it at the beggining.
 *
 * @param[in,out] fssthrdInfo Thread information
 * @param[in] pChildInfo Child information
 * @param[in] scan_mutex Mutex for scanning
 * @param[in] fdw_private_main fdw_private of main thread
 * @param[out] agg_result Aggregation result if pgspider_core calculats the aggregation
 * @param[in] tuplectx Memory context for tuple
 */
static void
spd_IterateForeignScanChildLoop(ForeignScanThreadInfo *fssthrdInfo, ChildInfo *pChildInfo,
								pthread_rwlock_t *scan_mutex, SpdFdwPrivate *fdw_private_main,
								PlanState **pagg_result, MemoryContext *tuplectx)
{
	bool		is_first_iterate = true;
	int			tuple_cnt = 0;

	fssthrdInfo->requestStartScan = false;

	fssthrdInfo->state = SPD_FS_STATE_ITERATE;

	/* Executes the aggregate if necessary. */
	if (pChildInfo->pseudo_agg)
	{
		SPD_WRITE_LOCK_TRY(scan_mutex);
		fssthrdInfo->fsstate->ss.ps.state->es_param_exec_vals = fssthrdInfo->fsstate->ss.ps.ps_ExprContext->ecxt_param_exec_vals;
		if (strcmp(fssthrdInfo->fdw->fdwname, POSTGRES_FDW_NAME) == 0 && !isPostgresFdwInit)
		{
			/* We need to make postgres_fdw_options variable initial one time */
			SPD_LOCK_TRY(&postgres_fdw_mutex);
			*pagg_result = ExecInitNode((Plan *) pChildInfo->pAgg, fssthrdInfo->fsstate->ss.ps.state, 0);
			isPostgresFdwInit = true;
			SPD_UNLOCK_CATCH(&postgres_fdw_mutex);
		} else
		{
			*pagg_result = ExecInitNode((Plan *) pChildInfo->pAgg, fssthrdInfo->fsstate->ss.ps.state, 0);
		}
		SPD_RWUNLOCK_CATCH(scan_mutex);
	}

	/* Start Iterate Foreign Scan loop. */
	PG_TRY();
	{
		TupleTableSlot *spdurl_slot = MakeSingleTupleTableSlot(fdw_private_main->child_comp_tupdesc,
			fssthrdInfo->fsstate->ss.ss_ScanTupleSlot->tts_ops);

		while (1)
		{
			bool		success;
			bool		deepcopy;
			TupleTableSlot *slot;

#ifdef GETPROGRESS_ENABLED
			/* When get result request recieved, then break. */
			if (getResultFlag)
			{
				spd_queue_notify_finish(&fssthrdInfo->tupleQueue);
				break;
			}
#endif

			/*
			 * Call child fdw iterateForeignScan using two memory contexts
			 * alternately. We switch contexts and reset old one every
			 * SPD_TUPLE_QUEUE_LEN tuples to minimize memory usage. This
			 * number guareantee tuples allocated by these contexts are alive
			 * until parent thread finishes processing and we can skip
			 * deepcopy when passing to parent thread. We could use query
			 * memory context and make parent thread free tuples, but it's
			 * slower than current code.
			 */

			/*----------
    		 * Example:
    		 * +----------------+-------+-------+-------+
		     * | memory context | slot0 | slot1 | slot2 |
		     * +----------------+-------+-------+-------+
		     * | tuplectx[0]    |     0 |     1 |     2 |
		     * | tuplectx[1]    |     3 |     4 |     5 |
		     * | tuplectx[0]    |     6 |     7 |     8 |
		     * | ...            |   ... |   ... |   ... |
		     *----------
		     */

			/*
			 * Above tables represent cases where queue length is 3. Tuple
			 * 0,1,2 (tuples generated when tuple_cnt is 0,1,2) are allocated
			 * by tuplectx[0]. Tuple 3,4,5 are allocated by tuplectx[1] and so
			 * on. When child thread succeeded in adding tuple 5, which use
			 * the same slot as tuple 2, parent thread finishes using tuple 2.
			 * So it's safe to reset tuplectx[0] before adding tuple 6.
			 */

			int			len = SPD_TUPLE_QUEUE_LEN;
			int			ctx_idx = (tuple_cnt / len) % 2;

			if (tuple_cnt % len == 0)
			{
				MemoryContextReset(tuplectx[ctx_idx]);
				MemoryContextSwitchTo(tuplectx[ctx_idx]);
			}
			if (pChildInfo->pseudo_agg)
			{
				/*
				 * Retreives aggregated value tuple from inlying non pushdown
				 * source.
				 */
				SPD_READ_LOCK_TRY(scan_mutex);
				slot = SPI_execAgg((AggState *) *pagg_result);
				SPD_RWUNLOCK_CATCH(scan_mutex);

				/*
				 * Need deep copy when adding slot to queue because
				 * CurrentMemoryContext does not affect SPI_execAgg, and hence
				 * tuples are not allocated by tuplectx[ctx_idx].
				 */
				deepcopy = true;
			}
			else
			{
				SPD_READ_LOCK_TRY(scan_mutex);
				/*
				 * Make child node use per-tuple memory context created by pgspider_core_fdw
				 * instead of using per-tuple memory context from core backend.
				 */
				fssthrdInfo->fsstate->ss.ps.ps_ExprContext->ecxt_per_tuple_memory = tuplectx[ctx_idx];
				slot = fssthrdInfo->fdwroutine->IterateForeignScan(fssthrdInfo->fsstate);
				SPD_RWUNLOCK_CATCH(scan_mutex);

				deepcopy = true;

				/*
				 * Deep copy can be skipped if that fdw allocates tuples in
				 * CurrentMemoryContext. postgres_fdw needs deep copy because
				 * it creates new contexts and allocate tuples on it, which
				 * may be shorter life than above tuplectx[ctx_idx].
				 */
				if (spd_can_skip_deepcopy(fssthrdInfo->fdw->fdwname))
					deepcopy = false;
			}

			if (TupIsNull(slot))
			{
				spd_queue_notify_finish(&fssthrdInfo->tupleQueue);
				break;
			}
			else{
				ExecClearTuple(spdurl_slot);
				slot = spd_AddSpdUrl(fssthrdInfo, spdurl_slot, slot, fdw_private_main, is_first_iterate);
			}

			while (1)
			{
				success = spd_queue_add(&fssthrdInfo->tupleQueue, slot, deepcopy);
				if (success)
					break;

				/* If rescan or endscan is requested, break immediately. */
				if (fssthrdInfo->requestRescan || fssthrdInfo->requestEndScan)
					break;

				/*
				 * TODO: Now that queue is introduced, using usleep(1) or
				 * condition variable may be better than pthread_yield for
				 * reducing cpu usage.
				 */
				pthread_yield();
			}
			tuple_cnt++;
			if (fssthrdInfo->requestRescan || fssthrdInfo->requestEndScan)
				break;

#ifdef GETPROGRESS_ENABLED
			/* When get result request recieved */
			if (!slot->tts_isempty && getResultFlag)
			{
				spd_queue_notify_finish(&fssthrdInfo->tupleQueue);
				cancel = PQgetCancel((PGconn *) fssthrdInfo->fsstate->conn);
				if (!PQcancel(cancel, errbuf, BUFFERSIZE))
					elog(WARNING, "Failed to PQgetCancel");
				PQfreeCancel(cancel);
				break;
			}
#endif
			is_first_iterate = false;
		}
	}
	PG_CATCH();
	{
		fssthrdInfo->state = SPD_FS_STATE_ERROR;

#ifdef GETPROGRESS_ENABLED
		if (fssthrdInfo->fsstate->conn)
		{
			cancel = PQgetCancel((PGconn *) fssthrdInfo->fsstate->conn);
			if (!PQcancel(cancel, errbuf, BUFFERSIZE))
				elog(WARNING, "Failed to PQgetCancel");
			PQfreeCancel(cancel);
		}
#endif
		elog(DEBUG1, "Thread error occurred during IterateForeignScan(). %s:%d",
			__FILE__, __LINE__);
	}
	PG_END_TRY();
}

/*
 * spd_EndForeignScanChild
 *
 * Waiting for the thread to become the end state and then call EndForeignScan.
 * If the rescan is required, it resets the queue and doesn't call EndForeignScan.
 *
 * @param[in] fssthrdInfoThread information
 * @param[in] pChildInfo Child information
 * @param[in] scan_mutex Mutex for scanning
 * @param[in] agg_result Aggregation result if pgspider_core calculats the aggregation
 * @param[in] tuplectx Memory context for tuple
 */
static void
spd_EndForeignScanChild(ForeignScanThreadInfo *fssthrdInfo, ChildInfo *pChildInfo,
						pthread_rwlock_t *scan_mutex, PlanState *agg_result,
						MemoryContext *tuplectx)
{
	PG_TRY();
	{
		while (1)
		{
			if (fssthrdInfo->requestEndScan)
			{
				/* End of the ForeignScan */
				fssthrdInfo->state = SPD_FS_STATE_END;
				SPD_READ_LOCK_TRY(scan_mutex);
				if (!pChildInfo->pseudo_agg)
				{
					fssthrdInfo->fdwroutine->EndForeignScan(fssthrdInfo->fsstate);
				}
				else
				{
					ExecEndNode(agg_result);
				}


				SPD_RWUNLOCK_CATCH(scan_mutex);
				fssthrdInfo->requestEndScan = false;
				break;
			}
			else if (fssthrdInfo->requestRescan)
			{

				/*
				 * Initialize queue. In LIMIT query, queue may have remaining
				 * tuples which should be discarded.
				 */
				spd_queue_reset(&fssthrdInfo->tupleQueue);

				MemoryContextReset(tuplectx[0]);
				MemoryContextReset(tuplectx[1]);

				MemoryContextSwitchTo(fssthrdInfo->threadMemoryContext);

				/* Can't goto RESCAN directly due to PG_TRY.  */
				break;
			}
			/* Wait for a request from main thread. */
			usleep(1);
		}
	}
	PG_CATCH();
	{
		fssthrdInfo->state = SPD_FS_STATE_ERROR;
		elog(DEBUG1, "Thread error occurred during EndForeignScan(). %s:%d",
			__FILE__, __LINE__);
	}
	PG_END_TRY();

}

/*
 * spd_RescanForeignScanChild
 *
 * Do rescan if it is queried before iteration.
 * Rescan is executed about join, union and some operation. If rescan is
 * needed, fssthrdInfo->requestRescan flag is TRUE. But first time rescan
 * is not needed. (fssthrdInfo->state = SPD_FS_STATE_BEGIN)
 * Then skip to rescan sequence.
 *
 * @param[in] fssthrdInfoThread information
 * @param[in] scan_mutex Mutex for scanning
 */
static void
spd_RescanForeignScanChild(ForeignScanThreadInfo *fssthrdInfo, pthread_rwlock_t *scan_mutex)
{
	if (fssthrdInfo->requestRescan &&
		fssthrdInfo->state != SPD_FS_STATE_BEGIN)
	{
		SPD_READ_LOCK_TRY(scan_mutex);
		fssthrdInfo->fdwroutine->ReScanForeignScan(fssthrdInfo->fsstate);
		SPD_RWUNLOCK_CATCH(scan_mutex);

		fssthrdInfo->requestRescan = false;
		fssthrdInfo->state = SPD_FS_STATE_BEGIN;
	}
}

/**
 * spd_ForeignScan_thread
 *
 * Child threads execute this routine, NOT main thread.
 * spd_ForeignScan_thread executes the following operations for each child thread.
 *
 * Child threads execute BeginForeignScan, IterateForeignScan, EndForeignScan
 * of child fdws in this routine.
 *
 * @param[in] arg ForeignScanThreadInfo
 */
static void *
spd_ForeignScan_thread(void *arg)
{
	ForeignScanThreadArg *fssthrdInfo_tmp = (ForeignScanThreadArg *) arg;
	ForeignScanThreadInfo *fssthrdInfo_main = fssthrdInfo_tmp->mainThreadsInfo;
	ForeignScanThreadInfo *fssthrdInfo = fssthrdInfo_tmp->childThreadsInfo;
	MemoryContext tuplectx[2];
	ErrorContextCallback errcallback;
	SpdFdwPrivate *fdw_private = (SpdFdwPrivate *) fssthrdInfo->private;
	SpdFdwPrivate *fdw_private_main = (SpdFdwPrivate *) fssthrdInfo_main->private;
	PlanState  *agg_result = NULL;
	ChildInfo *pChildInfo = &fdw_private->childinfo[fssthrdInfo->childInfoIndex];
	/* Flag use for check whether mysql_fdw called BeginForeignScan or not */
	bool		is_first = true;
#ifdef GETPROGRESS_ENABLED
	PGcancel   *cancel;
	char		errbuf[BUFFERSIZE];
#endif
#ifdef MEASURE_TIME
	struct timeval s,
				e,
				e1;

	gettimeofday(&s, NULL);
#endif

	/* Configuration for context of error handling and memory context. */
	spd_setThreadContext(fssthrdInfo, &errcallback, tuplectx);

	/* Begin Foreign Scan */
	spd_BeginForeignScanChild(fssthrdInfo, pChildInfo, &fdw_private->scan_mutex, &is_first);
	if (fssthrdInfo->state == SPD_FS_STATE_ERROR)
		goto THREAD_EXIT;

#ifdef MEASURE_TIME
	gettimeofday(&e, NULL);
	elog(DEBUG1, "thread%d begin foreign scan time = %lf", fssthrdInfo->serverId, (e.tv_sec - s.tv_sec) + (e.tv_usec - s.tv_usec) * 1.0E-6);
#endif

RESCAN:
	/* Rescan Foreign Scan */
	spd_RescanForeignScanChild(fssthrdInfo, &fdw_private->scan_mutex);

	/*
	 * requestStartScan is used in case a query has parameter.
	 *
	 * Main query and sub query is executed in two thread parallel.
	 * For main query, it needs to wait for sub-plan is initialized by the core engine.
	 * After sub-plan is initialized, the core engine starts Portal Run and calls
	 * spd_IterateForeignScan. requestStartScan will be enabled in this routine.
	 *
	 * During waiting to start scan, if it receives a request to re-scan, go back to RESCAN.
	 * If it receives request to end scan if error occurs, exit the transaction.
	 */
	while (!fssthrdInfo->requestStartScan &&
			fssthrdInfo->state == SPD_FS_STATE_BEGIN)
	{
		usleep(1);
		if (fssthrdInfo->requestEndScan)
			goto THREAD_END;

		if (fssthrdInfo->requestRescan)
		{
			fssthrdInfo->state = SPD_FS_STATE_ITERATE;
			goto RESCAN;
		}
	}

	/*
	 * In case child node is mysql_fdw, the main query need to wait
	 * sub-query finished before call BeginForeignScan.
	 * If main query: requestStartScan flag is true.
	 * If sub query: requestStartScan flag is false.
	 * In case subquery, we will call BeginForeignScan immediately.
	 * In case main query, we will wait subquery finished before call BeginForeignScan.
	 */
	if (!pChildInfo->pseudo_agg)
	{
		if (strcmp(fssthrdInfo->fdw->fdwname, MYSQL_FDW_NAME) == 0 &&
					is_first && fssthrdInfo->requestStartScan)
		{
			is_first = false;
			fssthrdInfo->fdwroutine->BeginForeignScan(fssthrdInfo->fsstate,
														fssthrdInfo->eflags);
		}
	}

	/* Itegrate Foreign Scan */
	spd_IterateForeignScanChildLoop(fssthrdInfo, pChildInfo, &fdw_private->scan_mutex, fdw_private_main, &agg_result, tuplectx);
#ifdef MEASURE_TIME
	gettimeofday(&e1, NULL);
	elog(DEBUG1, "thread%d end ite time = %lf", fssthrdInfo->serverId, (e1.tv_sec - e.tv_sec) + (e1.tv_usec - e.tv_usec) * 1.0E-6);
#endif
	if (fssthrdInfo->state == SPD_FS_STATE_ERROR)
		goto THREAD_EXIT;


THREAD_END:
	/* Waiting for the timing to call End Foreign Scan. */
	spd_EndForeignScanChild(fssthrdInfo, pChildInfo, &fdw_private->scan_mutex, agg_result, tuplectx);

	if (fssthrdInfo->state == SPD_FS_STATE_ERROR)
		goto THREAD_EXIT;
	else if (fssthrdInfo->requestRescan)
		goto RESCAN;


	fssthrdInfo->state = SPD_FS_STATE_FINISH;
THREAD_EXIT:
	spd_queue_notify_finish(&fssthrdInfo->tupleQueue);

	spd_freeThreadContextList();

#ifdef MEASURE_TIME
	gettimeofday(&e, NULL);
	elog(DEBUG1, "thread%d all time = %lf", fssthrdInfo->serverId, (e.tv_sec - s.tv_sec) + (e.tv_usec - s.tv_usec) * 1.0E-6);
#endif
	pthread_exit(NULL);
}

/**
 * spd_ParseUrl
 *
 * Parse IN url name.
 * parse list is 5 pattern.
 * Pattern1 Url = /sample/test/
 *  First URL "sample"  Throwing URL "/test/"
 * Pattern2 Url = /sample/
 *  First URL "sample"  Throwing URL NULL
 * Pattern4 Url = "/"
 *  First URL NULL  Throwing URL NULL
 * Pattern5 Url = "/sample"
 *  First URL "sample"  Throwing URL NULL
 *
 * @param[in] spd_url_list URL list to be parsed
 * @return The list of parsed URL. Parsed URL is also a list.
 *			  The 1st element is an original URL, the 2nd element
 *			  is a throwing URL.
 */
static List *
spd_ParseUrl(List *spd_url_list)
{
	char	   *tp;
	char	   *throw_tp;
	char	   *url_option;
	char	   *next = NULL;
	char	   *throwing_url = NULL;
	int			original_len;
	ListCell   *lc;
	List *parsed_url = NIL;

	foreach(lc, spd_url_list)
	{
		char	   *url_str = (char *) lfirst(lc);
		List	   *url_parse_list = NULL;

		url_option = pstrdup(url_str);
		if (url_option[0] != '/')
			elog(ERROR, "Failed t parse URL '%s' in IN clause. The first character should be '/'.", url_str);
		url_option++;
		tp = strtok_r(url_option, "/", &next);
		if (tp == NULL)
			break;

		url_parse_list = lappend(url_parse_list, tp);	/* Original URL */

		throw_tp = strtok_r(NULL, "/", &next);
		if (throw_tp != NULL)
		{
			original_len = strlen(tp) + 1;
			throwing_url = pstrdup(&url_str[original_len]); /* Throwing URL */
			if (strlen(throwing_url) != 1)
				url_parse_list = lappend(url_parse_list, throwing_url);
		}
		parsed_url = lappend(parsed_url, url_parse_list);
	}
	return parsed_url;
}


/**
 * Create new URL with deleting first node name from parent URL string.
 * For example, if the input URL is "/foo/bar/",
 *
 * @param[in] childnums The number of child tables
 * @param[in] spd_url_list URL of parent
 * @param[in,out] fdw_private Parsed URLs are stored in fdw_private->url_list
 */
static void
spd_create_child_url(int childnums, List *spd_url_list, SpdFdwPrivate * fdw_private)
{
	char	   *original_url = NULL;
	char	   *throwing_url = NULL;
	ListCell   *lc;
	int i;
	/*
	 * Entry is first parsing word(, then entry is "foo", entry2 is
	 * "bar")
	 */
	fdw_private->url_list = spd_ParseUrl(spd_url_list);
	if (fdw_private->url_list == NULL)
		elog(ERROR, "IN clause is used but no URL found. Please specify URL.");

	foreach(lc, fdw_private->url_list)
	{
		List	   *url_parse_list = (List *) lfirst(lc);

		original_url = (char *) list_nth(url_parse_list, 0);
		if (url_parse_list->length > 1)
		{
			throwing_url = (char *) list_nth(url_parse_list, 1);
		}
		/* If IN clause is used, then store parsed URL. */
		for (i=0; i < childnums; i++)
		{
			char		srvname[NAMEDATALEN];
			Oid			temp_oid = fdw_private->childinfo[i].oid;
			Oid			temp_tableid;
			ForeignServer *temp_server;
			ForeignDataWrapper *temp_fdw = NULL;

			spd_servername_from_tableoid(temp_oid, srvname);

			if (strcmp(original_url, srvname) != 0)
			{
				elog(DEBUG1, "Can not find a child node of '%s'.", original_url);
				/* for multi in node */
				if (fdw_private->childinfo[i].child_node_status != ServerStatusAlive)
					fdw_private->childinfo[i].child_node_status = ServerStatusIn;
				continue;
			}
			fdw_private->childinfo[i].child_node_status = ServerStatusAlive;

			/*
			 * If child-child node exists, then create New IN clause. New IN
			 * clause is used by child pgspider server.
			 */
			if (throwing_url != NULL)
			{
				/* If child fdw is pgspider_fdw, then store a throwing URL. */
				temp_tableid = GetForeignServerIdByRelId(temp_oid);
				temp_server = GetForeignServer(temp_tableid);
				temp_fdw = GetForeignDataWrapper(temp_server->fdwid);
				if (strcmp(temp_fdw->fdwname, PGSPIDER_FDW_NAME) != 0)
				{
					elog(ERROR, "Trying to pushdown IN clause. But child node is not %s.", PGSPIDER_FDW_NAME);
				}
				fdw_private->childinfo[i].url_list = lappend(fdw_private->childinfo[i].url_list, throwing_url);
			}
		}
	}
}

/**
 * check_basestrictinfo
 *
 * Create a base plan for each child table and save into entry_baserel.
 *
 * @param[in] root Planner info
 * @param[in] fdw Child table's fdw
 * @param[in,out] entry_baserel Child table's restrictinfo is saved
 */
static void
check_basestrictinfo(PlannerInfo *root, ForeignDataWrapper *fdw, RelOptInfo *entry_baserel)
{
	ListCell   *lc;
	List *restrictinfo = NIL; /* new restrictinfo after removing SPDURL */

	if (strcmp(fdw->fdwname, PGSPIDER_FDW_NAME) == 0)
	{
		foreach(lc, entry_baserel->baserestrictinfo)
		{
			RestrictInfo *clause = (RestrictInfo *) lfirst(lc);
			Expr	   *expr = (Expr *) clause->clause;

			if (spd_expr_has_spdurl(root, (Node *) expr, NULL))
				entry_baserel->baserestrictinfo = NULL;
		}
	}
	/* Create new restrictinfo. */
	foreach(lc, entry_baserel->baserestrictinfo)
	{
		RestrictInfo *clause = (RestrictInfo *) lfirst(lc);
		Expr	   *expr = (Expr *) clause->clause;
		List	   *target_exprs = NIL;

		if (spd_expr_has_spdurl(root, (Node *) expr, &target_exprs) != true)
		{
			entry_baserel->reltarget->exprs = list_concat(entry_baserel->reltarget->exprs, target_exprs);
			/* If it does not contaon SPDURL, we append it to new restrictinfo list. */
			restrictinfo = lappend(restrictinfo, clause);
		}
	}
	entry_baserel->baserestrictinfo = restrictinfo;
}

/**
 * var_is_spdurl
 *
 * Check if Var name is SPDURL or not.
 *
 * @param[in] var Var expression
 * @param[in] root Planner info
 * @return True if it is SPDURL.
 */
static bool
var_is_spdurl(Var *var, PlannerInfo *root)
{
	RangeTblEntry *rte;
	char	   *colname;

	rte = planner_rt_fetch(var->varno, root);
	colname = get_attname(rte->relid, var->varattno, false);

	if (strcmp(colname, SPDURL) == 0)
		return true;
	else
		return false;
}

/**
 * detect_spdurl_expr
 *
 * Search SPDURL expression in the list.
 * This function is a core function of get_index_spdurl_from_targets()
 * and remove_spdurl_from_targets(). If the 3rd argument (url_idx) is
 * given (not NULL), it behaves for get_index_spdurl_from_targets() and
 * url_idx is set and return the function by NULL. Otherwise
 * (url_idx is NULL), it behaves for remove_spdurl_from_targets() and
 * SPDURL in the list is removed.
 *
 * @param[in,out] exprs The target expression list
 * @param[in] root Planner info
 * @param[out] url_idx Position of SPDURL in the list
 */
static List *
detect_spdurl_expr(List *exprs, PlannerInfo *root, int *url_idx)
{
	ListCell   *lc;
	int			i = -1;

	foreach (lc, exprs)
	{
		Node	   *node = (Node *) lfirst(lc);
		Node	   *varnode;
		Var		   *var;

		/*
		 * "i" is the position in the list (0 origin). Because the operation
		 * in this has 'continue;', "i" is initialized with -1 and inremented
		 * at the top of foreach.
		 */
		i++;

		if (IsA(node, TargetEntry))
			varnode = (Node *) (((TargetEntry *) node)->expr);
		else
			varnode = node;

		if (!IsA(varnode, Var))
			continue;

		var = (Var *) varnode;

		/* Check whole row reference. */
		if (var->varattno == 0)
			continue;

		/* Check var is SPDURL. */
		if (!var_is_spdurl(var, root))
			continue;

		/* Here, SPDURL is found. */
		if (url_idx)
		{
			/* For get_index_spdurl_from_targets() */
			*url_idx = i;
			return NIL;
		}
		else
		{
			/* For get_index_spdurl_from_targets() */
			exprs = foreach_delete_current(exprs, lc);
		}
	}

	if (url_idx)
		*url_idx = -1;
	return exprs;
}

/**
 * remove_spdurl_from_targets
 *
 * Remove all SPDURL from target list 'exprs'
 *
 * @param[in,out] exprs The target expression list
 * @param[in] root Planner info
 */
static List *
remove_spdurl_from_targets(List *exprs, PlannerInfo *root)
{
	return detect_spdurl_expr(exprs, root, NULL);
}

/**
 * get_index_spdurl_from_targets
 *
 * Find __spd_url from target list 'exprs' and if the first __spd_url is found,
 * return the index as 'url_idx'.
 *
 * @param[in,out] exprs The target expression list
 * @param[in] root Planner info
 */
static int
get_index_spdurl_from_targets(List *exprs, PlannerInfo *root)
{
	int url_idx = -1;
	detect_spdurl_expr(exprs, root, &url_idx);
	return url_idx;
}

/**
 * remove_spdurl_from_group_clause
 *
 * Remove SPDURL from 'groupClause' lists
 *
 * @param[in] root Planner info
 * @param[in] tlist Target list
 * @param[in,out] groupClause Grouping clause
 */
static List *
remove_spdurl_from_group_clause(PlannerInfo *root, List *tlist, List *groupClause)
{
	ListCell   *lc;

	if (groupClause == NULL)
		return NULL;

	foreach (lc, groupClause)
	{
		SortGroupClause *sgc = (SortGroupClause *) lfirst(lc);
		TargetEntry *tle = get_sortgroupclause_tle(sgc, tlist);

		if (IsA(tle->expr, Var))
		{
			if (var_is_spdurl((Var *) tle->expr, root))
			{
				groupClause = foreach_delete_current(groupClause, lc);
			}
		}
	}
	return groupClause;
}

/**
 * groupby_has_spdurl
 *
 * Check whether SPDURL exists or not in GROUP BY.
 *
 * @param[in] root Planner info
 * @return True if SPDURL exists
 */
static bool
groupby_has_spdurl(PlannerInfo *root)
{
	List	   *target_list = root->parse->targetList;
	List	   *group_clause = root->parse->groupClause;
	ListCell   *lc;

	foreach(lc, group_clause)
	{
		SortGroupClause *sgc = (SortGroupClause *) lfirst(lc);
		TargetEntry *te = get_sortgroupclause_tle(sgc, target_list);

		if (te == NULL)
			return false;
		/* Check __spd_url in the target entry */
		if (IsA(te->expr, Var))
		{
			if (var_is_spdurl((Var *) te->expr, root))
				return true;
		}
	}
	return false;
}

/*
 * spd_makeRangeTableEntry
 * 
 * Create new range table entry.
 * 
 * @param[in] relid Relation OID
 * @param[in] relkind relation kind (see pg_class.relkind)
 * @param[in] spd_url_list URL list
 * @return Created range table entry
 */
static RangeTblEntry *
spd_makeRangeTableEntry(Oid relid, char relkind, List *spd_url_list)
{
	RangeTblEntry  *rte;

	/* Build a minimal RTE for the rel. */
	rte = makeNode(RangeTblEntry);
	rte->rtekind = RTE_RELATION;
	rte->relid = relid;
	rte->relkind = relkind;
	rte->eref = makeNode(Alias);
	rte->eref->aliasname = pstrdup("");
	rte->lateral = false;
	rte->inh = false;
	rte->inFromCl = true;
	rte->eref = makeAlias(pstrdup(""), NIL);
	rte->rellockmode = AccessShareLock;	/* For SELECT query */

	/*
	 * If child node is pgspider_fdw and IN clause is used, then should set new IN
	 * clause URL at child node planner URL.
	 */
	if (spd_url_list != NIL)
		rte->spd_url_list = list_copy(spd_url_list);

	return rte;
}

/*
 * spd_CreateRoot
 * 
 * Create new PlannerInfo.
 * 
 * @param[in] root Root base planner infromation
 * @param[in] rtable Range table
 * @return Created PlannerInfo
 */
static PlannerInfo *
spd_CreateRoot(PlannerInfo *root, List *rtable)
{
	PlannerInfo	   *new_root;
	Query		   *query;
	PlannerGlobal  *glob;

	/*
	 * Set up mostly-dummy planner state PlannerInfo can not deep copy
	 * with copyObject(). But it should create dummy PlannerInfo for each
	 * child table. Following code is copied from plan_cluster_use_sort(),
	 * it create simple PlannerInfo.
	 */
	query = makeNode(Query);
	query->commandType = CMD_SELECT;
	glob = makeNode(PlannerGlobal);

	new_root = makeNode(PlannerInfo);
	new_root->parse = query;
	new_root->glob = glob;
	new_root->query_level = 1;
	new_root->planner_cxt = CurrentMemoryContext;
	new_root->wt_param_id = -1;
	new_root->ec_merging_done = root->ec_merging_done;

	/*
	 * Use placeholder list only for child node's GetForeignRelSize in this routine.
	 * PlaceHolderVar in relation target list will be checked against PlaceHolder List
	 * in root planner info.
	 */
	new_root->placeholder_list = copyObject(root->placeholder_list);

	/* Set a range table. */
	query->rtable = rtable;

	/* Set up RTE/RelOptInfo arrays. */
	setup_simple_rel_arrays(new_root);

	return new_root;
}

/*
 * spd_calculate_datasource_tableoid
 *
 * Calculate child_server's child table oid belonging to parent table.
 *
 * @param[in] parent_table OID of parent table
 * @param[in] child_server OID of child table
 */
static Oid
spd_calculate_datasource_tableoid(Oid parent_table, Oid child_server)
{
	Oid	   *oids = NULL;
	int		nums;
	int		i;
	Oid tableoid = 0;

	spd_calculate_datasouce_count(parent_table, &nums, &oids);

	/* Search the oid of which foreign server is a target. */
	for (i = 0; i < nums; i++)
	{
		Oid oid_server = serverid_of_relation(oids[i]);
		if (oid_server == child_server)
		{
			tableoid = oids[i];
			break;
		}
	}

	/* Not found */
	if (oids)
		pfree(oids);

	return tableoid;
}

/*
 * spd_CreateChildRoot
 *
 * Create new child PlannerInfo. Range table in PlannerInfo also needs to be created.
 * When creating a range table, we set rte->relid for child to relation id of child table.
 * So we need to calculate child table OID from parent table OID.
 *
 * @param[in] root Root base planner infromation
 * @param[in] relid Index in range table
 * @param[in] tableOid OID of child table
 * @param[in] oid_server OID of child node
 * @param[in] spd_url_list URL list
 * @return Created PlannerInfo
 */
static PlannerInfo *
spd_CreateChildRoot(PlannerInfo *root, Index relid, Oid tableOid, Oid oid_server,
					List *spd_url_list)
{
	PlannerInfo	   *child_root;
	List		   *rtable = NIL;
	ListCell	   *lc;
	Index			i = 1;

	/* Create a child range table. */
	foreach(lc, root->parse->rtable)
	{
		RangeTblEntry *rte = (RangeTblEntry *) lfirst(lc);
		RangeTblEntry *child_rte;
		Oid child_relid;

		/*
		 * Get a child table oid corresponding to the parent table oid. That of the 
		 * current target table is already calculated. So we use it. Otherwise, we
		 * get it by querying the system table by spd_calculate_datasource_tableoid.
		 */
		if (i == relid)
			child_relid = tableOid;
		else if (rte->relid != 0)
			child_relid = spd_calculate_datasource_tableoid(rte->relid, oid_server);
		else
			child_relid  = 0;

		/* Create a range table entry. */
		child_rte = spd_makeRangeTableEntry(child_relid, rte->relkind, spd_url_list);

		rtable = lappend(rtable, child_rte);

		i++;
	}

	/* Create a child root. */
	child_root = spd_CreateRoot(root, rtable);

	return child_root;
}

/*
 * spd_GetChildRoot
 *
 * Get a child PlannerInfo. If it already exists, we use it, otherwise we create new.
 * We memorize a child root in the parent's root->child_root. In case of use of multiple
 * tables such as join, the same root is used for table. If the child root is already
 * created, we refer it. SpdChildRootId is a structure to store an identifier for
 * detecting that a child root is already created or not.
 * Parent PlannerInfo needs to store multiple child PlannerInfo for child nodes. In
 * order to distinct them, server OID is stored in child_root->child_root.
 * 
 * @param[in] root Root base planner infromation
 * @param[in] relid Index in range table
 * @param[in] tableoid OID of child table
 * @param[in] oid_server OID of child node
 * @param[in] spd_url_list URL list
 * @return Child PlannerInfo
 */
static PlannerInfo *
spd_GetChildRoot(PlannerInfo *root, Index relid, Oid child_tableoid, Oid oid_server,
				 List *spd_url_list, int i_child)
{
	ListCell *lc;
	PlannerInfo *child_root = NULL;
	SpdChildRootId *child_root_id;

	foreach(lc, root->child_root)
	{
		PlannerInfo *child = lfirst(lc);

		child_root_id = (SpdChildRootId *) linitial(child->child_root);
		if (child_root_id->serveroid == oid_server &&
			child_root_id->childid == i_child)
		{
			child_root = child;
			break;
		}
	}

	if (child_root == NULL)
	{
		child_root = spd_CreateChildRoot(root, relid, child_tableoid, oid_server, 
										 spd_url_list);
	
		child_root_id = palloc0(sizeof(SpdChildRootId));
		child_root_id->serveroid = oid_server;
		child_root_id->childid = i_child;

		child_root->child_root = lappend(child_root->child_root, child_root_id);
		root->child_root = lappend(root->child_root, child_root);
	}

	/*
	 * Because in build_simple_rel() function, it assumes that a relation was already locked before open.
	 * So, we need to lock relation by id in dummy root in advance.
	 */
	LockRelationOid(child_tableoid, AccessShareLock);

	return child_root;
}

/*
 * spd_CreateChildBaserel
 *
 * Create RelOptInfo for child node.
 *
 * @param[in] child_root Child PlannerInfo
 * @param[in] root Parent PlannerInfo
 * @param[in] baserel Parent RelOptInfo
 * @param[in] fdwname FDW name
 *
 */
static RelOptInfo *
spd_CreateChildBaserel(PlannerInfo *child_root, PlannerInfo *root, RelOptInfo *baserel, char *fdwname)
{
	RelOptInfo *child_baserel;

	/* If it already exists, we use it. */
	if (child_root->simple_rel_array[baserel->relid])
		return child_root->simple_rel_array[baserel->relid];
		
	/*
	 * Build RelOptInfo Build simple relation and copy target list and
	 * strict info from root information.
	 */
	child_baserel = build_simple_rel(child_root, baserel->relid, RELOPT_BASEREL);
	child_baserel->reltarget->exprs = copyObject(baserel->reltarget->exprs);
	child_baserel->baserestrictinfo = copyObject(baserel->baserestrictinfo);

	/*
	 * Copy attr_needed from parent. The aray size is defined in
	 * get_relation_info() called by build_simple_rel().
	 */
	memcpy(child_baserel->attr_needed, baserel->attr_needed,
		   sizeof(Relids) * (child_baserel->max_attr - child_baserel->min_attr + 1));
	memcpy(child_baserel->attr_widths, baserel->attr_widths,
		   sizeof(int32) * (child_baserel->max_attr - child_baserel->min_attr + 1));

	/* Remove SPDURL from target lists if a child is not pgspider_fdw. */
	if (strcmp(fdwname, PGSPIDER_FDW_NAME) != 0)
	{
		child_baserel->reltarget->exprs = remove_spdurl_from_targets(child_baserel->reltarget->exprs, root);
	}

	return child_baserel;
}

/**
 * spd_GetForeignRelSizeChild
 *
 * Create a base plan for each child table and save into childinfo.
 *
 * @param[in] root Root base planner infromation
 * @param[in] baserel Root base relation option
 * @param[in] oid Child table's oids
 * @param[in] oid_nums The number of child tables
 * @param[in] r_entry Root entry
 * @param[in] new_inurl New IN clause url
 * @param[in,out] childinfo Child table's base plan is saved here
 * @param[out] idx_url_tlist The position of SPDURL in tlist
 */
static void
spd_GetForeignRelSizeChild(PlannerInfo *root, RelOptInfo *baserel,
					Oid *oid, int oid_nums,
					RangeTblEntry *r_entry,
					List *new_inurl, ChildInfo *childinfo,
					int *idx_url_tlist)
{
	int			i = 0;

	for (i = 0; i < oid_nums; i++)
	{
		Oid			oid_server;
		ForeignServer *fs;
		ForeignDataWrapper *fdw;
		RelOptInfo	*child_baserel;
		Oid			rel_oid = 0;
		PlannerInfo *child_root = NULL;
		char		ip[NAMEDATALEN] = {0};

		rel_oid = childinfo[i].oid;
		if (rel_oid == 0)
			continue;

		oid_server = serverid_of_relation(rel_oid);
		childinfo[i].server_oid = oid_server;
		childinfo[i].fdwroutine = GetFdwRoutineByServerId(oid_server);

		/* Get child planner info. */
		child_root = spd_GetChildRoot(root, baserel->relid, rel_oid, oid_server,
											  childinfo[i].url_list, i);

		fs = GetForeignServer(oid_server);
		fdw = GetForeignDataWrapper(fs->fdwid);

		/* Create child base relation. */
		child_baserel = spd_CreateChildBaserel(child_root, root, baserel, fdw->fdwname);

		if (strcmp(fdw->fdwname, PARQUET_S3_FDW_NAME) == 0)
		{
#ifdef ENABLE_PARALLEL_S3
			if (childinfo[i].s3file != NULL)
				child_baserel->fdw_private = list_make1(list_make1(childinfo[i].s3file));
			else
#endif
			child_baserel->fdw_private = NIL;
		}

		/*
		 * FDW uses basestrictinfo to check column type and number.
		 * Delete SPDURL column info for child node
		 * baserel's basestrictinfo. (PGSpider FDW uses parent basestrictinfo)
		 */
		check_basestrictinfo(root, fdw, child_baserel);
		spd_ip_from_server_name(fs->servername, ip);

		/* Check server name and ip. */
#ifndef WITHOUT_KEEPALIVE
		if (check_server_ipname(fs->servername, ip))
		{
#endif
			/* Do child node's GetForeignRelSize. */
			PG_TRY();
			{
				childinfo[i].fdwroutine->GetForeignRelSize(child_root, child_baserel, rel_oid);
				childinfo[i].root = child_root;
			}
			PG_CATCH();
			{
				/*
				 * Even if it fails to create dummy_root_list, pgspider_core should
				 * stop following steps for failed child table. So we set
				 * fdw_private->child_table_alive to FALSE.
				 *
				 * spd_beginForeignScan() get information of child tables from
				 * system table and compare it with
				 * fdw_private->dummy_base_rel_list. That's why, the length of
				 * fdw_private->dummy_base_rel_list should match the number of
				 * all of the child tables belonging to parent table.
				 */
				childinfo[i].root = root;
				childinfo[i].child_node_status = ServerStatusDead;

				/*
				 * If an error is occurred, child node fdw does not output Error.
				 * It should be clear Error stack.
				 */
				elog(WARNING, "GetForeignRelSize of child[%d] failed.", i);
				if (throwErrorIfDead)
				{
					spd_aliveError(fs);
				}
				FlushErrorState();
			}
			PG_END_TRY();
#ifndef WITHOUT_KEEPALIVE
		}
		else
		{
			childinfo[i].root = root;
			childinfo[i].child_node_status = ServerStatusDead;
			if (throwErrorIfDead)
				spd_aliveError(fs);
		}
#endif
		childinfo[i].baserel = child_baserel;
	}
}

/**
 * spd_CopyRoot
 *
 * Create base plan for each child tables and save into fdw_private.
 *
 * @param[in] root Root base planner infromation
 * @param[in] baserel Root base relation option
 * @param[inout] fdw_private Child table's base plan is saved
 * @param[in] relid Relation id
 */
static void
spd_CopyRoot(PlannerInfo *root, RelOptInfo *baserel, SpdFdwPrivate *fdw_private, Oid relid)
{
	List *rtable = NIL;
	ListCell	   *lc;

	fdw_private->isFirst = true;

	/* Create a range table. */
	foreach(lc, root->parse->rtable)
	{
		RangeTblEntry *rte = (RangeTblEntry *) lfirst(lc);
		RangeTblEntry *new_rte;

		/* Create a range table entry. */
		new_rte = spd_makeRangeTableEntry(rte->relid, rte->relkind, NULL);

		rtable = lappend(rtable, new_rte);
	}

	/* Create new root. */
	fdw_private->spd_root = spd_CreateRoot(root, rtable);

	/* Memorize baserestrictinfo into fdw_private so that we can refer it later. */
	fdw_private->baserestrictinfo = copyObject(baserel->baserestrictinfo);
}

#ifdef ENABLE_PARALLEL_S3
static void
spd_extractS3Nodes(int *nums, Oid **oid, SpdFdwPrivate *fdw_private)
{
	bool   *isS3;
	List	**s3filelist;
	Oid		*newoid;
	int		idx = 0;
	int 	num_orig = *nums;
	Oid 	*oid_orig = *oid;
	int		s3num = 0; /* additional node count for S3 */
	int		i;

	isS3 = (bool *) palloc0(sizeof(bool) * num_orig);
	s3filelist = (List **) palloc0(sizeof(List *) * num_orig);

	/* Determine whether each server is Parquet S3 FDW or not. */
	for (i = 0; i < num_orig; i++)
	{
		Oid			temp_tableid = GetForeignServerIdByRelId(oid_orig[i]);
		ForeignServer *temp_server = GetForeignServer(temp_tableid);
		ForeignDataWrapper *temp_fdw = GetForeignDataWrapper(temp_server->fdwid);
		if (strcmp(temp_fdw->fdwname, PARQUET_S3_FDW_NAME) == 0)
		{
			isS3[i] = true;
			s3filelist[i] = getS3FileList(oid_orig[i]);
			if (s3filelist[i] != NIL)
			{
				s3num += list_length(s3filelist[i]) - 1;
			}
			else
				isS3[i] = false;
		}
		else
			isS3[i] = false;
	}

	/* Create child info for additional S3 nodes. */
	fdw_private->node_num = num_orig + s3num;
	fdw_private->childinfo = (ChildInfo *) palloc0(sizeof(ChildInfo) * (fdw_private->node_num));
	newoid = (Oid *) palloc0(sizeof(Oid) * (fdw_private->node_num));
	for (i = 0; i < num_orig; i++)
	{
		fdw_private->childinfo[i].child_node_status = ServerStatusDead;
		if (isS3[i])
		{
			int j;
			for (j = 0; j < list_length(s3filelist[i]); j++)
			{
				fdw_private->childinfo[idx].oid = oid_orig[i];
				fdw_private->childinfo[idx].s3file = list_nth(s3filelist[i], j);
				newoid[idx] = oid_orig[i];
				idx++;
			}
		}
		else
		{
			fdw_private->childinfo[idx].oid = oid_orig[i];
			fdw_private->childinfo[idx].s3file = NULL;
			newoid[idx] = oid_orig[i];
			idx++;
		}
	}
	pfree(isS3);
	pfree(s3filelist);

	/* Set output variables. */
	*nums += s3num;
	pfree(*oid);
	*oid = newoid;
}
#endif

/**
 * spd_GetForeignRelSize
 *
 * 1. Check number of child tables and get these oids.
 * 2. Check IN clause and create new IN clause for passing to child node (delete a head of URL)
 * 3. Create base plan for each child table and save into fdw_private.
 *
 * Original FDW create fdw's using by root and baserel.
 * pgspider_core should create child node plan information.
 * The main thread creates it using this function.
 *
 * @param[in] root Bbase planner information
 * @param[in] baserel Base relation option
 * @param[in] foreigntableid Parent foreign table id
 */
static void
spd_GetForeignRelSize(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid)
{
	SpdFdwPrivate *fdw_private;
	Oid		   *oid = NULL;
	int			nums;
	List	   *new_inurl = NULL;
	RangeTblEntry *r_entry;
	char	   *namespace = NULL;
	char	   *relname = NULL;
	char	   *refname = NULL;
	RangeTblEntry *rte;
	int i;
	int rtn = 0;
	StringInfo relation_name = makeStringInfo();

	/* Reset child node offset to 0 for new query execution. */
	g_node_offset = 0;

	baserel->rows = 1000;
	fdw_private = spd_AllocatePrivate();
	fdw_private->idx_url_tlist = -1;	/* -1: not have __spd_url */
	fdw_private->rinfo.pushdown_safe = true;
	baserel->fdw_private = (void *) fdw_private;

	/* Get child datasouce oids and counts. */
	spd_calculate_datasouce_count(foreigntableid, &nums, &oid);
	if (nums == 0)
		ereport(ERROR, (errmsg("Cannot Find child datasources.")));

#ifdef ENABLE_PARALLEL_S3
	spd_extractS3Nodes(&nums, &oid, fdw_private);
#else
	fdw_private->node_num = nums;
	fdw_private->childinfo = (ChildInfo *) palloc0(sizeof(ChildInfo) * nums);

	for (i = 0; i < nums; i++)
	{
		fdw_private->childinfo[i].oid = oid[i];
		/* Initialize all child node status. */
		fdw_private->childinfo[i].child_node_status = ServerStatusDead;
	}
#endif

	Assert(IS_SIMPLE_REL(baserel));
	r_entry = root->simple_rte_array[baserel->relid];
	Assert(r_entry != NULL);

	/* Check to IN clause and execute only IN URL server */
	if (r_entry->spd_url_list != NULL)
		spd_create_child_url(nums, r_entry->spd_url_list, fdw_private);
	else
	{
		for (i = 0; i < nums; i++)
		{
			fdw_private->childinfo[i].child_node_status = ServerStatusAlive;
		}
	}

	/* Create base plan for each child tables and execute GetForeignRelSize. */
	spd_GetForeignRelSizeChild(root, baserel, oid, nums, r_entry, new_inurl,
				 fdw_private->childinfo, &fdw_private->idx_url_tlist);

	/*
	 * Set the name of relation in fpinfo, while we are constructing it here.
	 * It will be used to build the string describing the join relation in
	 * EXPLAIN output. We can't know whether VERBOSE option is specified or
	 * not, so always schema-qualify the foreign table name.
	 */
	rte = planner_rt_fetch(baserel->relid, root);
	namespace = get_namespace_name(get_rel_namespace(foreigntableid));
	relname = get_rel_name(foreigntableid);
	refname = rte->eref->aliasname;
	appendStringInfo(relation_name, "%s.%s",
					 quote_identifier(namespace),
					 quote_identifier(relname));
	if (*refname && strcmp(refname, relname) != 0)
		appendStringInfo(relation_name, " %s",
						 quote_identifier(rte->eref->aliasname));

	fdw_private->rinfo.relation_name = pstrdup(relation_name->data);
	spd_CopyRoot(root, baserel, fdw_private, foreigntableid);
	/* No outer and inner relations. */
	fdw_private->rinfo.make_outerrel_subquery = false;
	fdw_private->rinfo.make_innerrel_subquery = false;
	fdw_private->rinfo.lower_subquery_rels = NULL;
	/* Set the relation index. */
	fdw_private->rinfo.relation_index = baserel->relid;
	/* Init mutex.*/
	SPD_RWLOCK_INIT(&fdw_private->scan_mutex, &rtn);
	if (rtn != SPD_RWLOCK_INIT_OK)
		elog(ERROR, "Failed to initialize a read-write lock object. Returned %d.", rtn);

	pfree(relation_name->data);
	pfree(relation_name);
}

/**
 * spd_makedivtlist
 *
 * Splitting one aggref into multiple aggref
 *
 * @param[in] aggref Aggregation entry
 * @param[in,out] newList List of new exprs
 */
static List *
spd_makedivtlist(Aggref *aggref, List *newList)
{
	/* Prepare SUM Query */
	Aggref	   *tempCount = copyObject((Aggref *) aggref);
	Aggref	   *tempSum;
	TargetEntry *tle_temp;

	tempSum = copyObject(tempCount);
	if (tempSum->aggtype <= INT8OID)
	{
		set_split_agg_info(tempSum, SUM_OID, INT8OID, INT8OID);
	}
	else if (tempSum->aggtype == NUMERICOID)
	{
		set_split_numeric_info(tempSum, NULL);
	}
	else
	{
		set_split_agg_info(tempSum, SUM_FLOAT8_OID, FLOAT8OID, FLOAT8OID);
	}
	set_split_agg_info(tempCount, COUNT_OID, INT8OID, INT8OID);

	newList = lappend(newList, tempCount);
	newList = lappend(newList, tempSum);
	if ((aggref->aggfnoid >= VAR_MIN_OID && aggref->aggfnoid <= VAR_MAX_OID)
		|| (aggref->aggfnoid >= STD_MIN_OID && aggref->aggfnoid <= STD_MAX_OID))
	{
		Aggref	   *tempVar = createVarianceExpr(tempCount, true);

		tle_temp = makeTargetEntry((Expr *) tempVar,	/* copy needed?? */
								   0,
								   NULL,
								   false);
		newList = lappend(newList, tle_temp);
	}

	return newList;

}

/**
 * spd_catalog_makedivtlist
 *
 * Splitting one aggref into multiple aggref (catalogue version)
 *
 * @param[in] aggref - aggregation entry
 * @param[in,out] list - list of new exprs
 * @param[in] type - agg type in CatalogSplitAggType
 */

static List *
spd_catalog_makedivtlist(Aggref *aggref, List *newList, enum Aggtype aggtype)
{
	switch (aggtype)
	{
		case SPREAD_FLAG:
		{
			Aggref *tempMin = copyObject(aggref);
			Aggref *tempMax;
			Oid    maxoid;

			if (aggref->aggtype == FLOAT4OID || aggref->aggtype == FLOAT8OID)
			{
				tempMin->aggfnoid = MIN_FLOAT8_OID;
				tempMin->aggtype = FLOAT8OID;
				tempMin->aggtranstype = FLOAT8OID;
				maxoid = MAX_FLOAT8_OID;
			}
			else
			{
				tempMin->aggfnoid = MIN_BIGINT_OID;
				tempMin->aggtype = INT8OID;
				tempMin->aggtranstype = INT8OID;
				maxoid = MAX_BIGINT_OID;
			}
			tempMax = copyObject(tempMin);
			tempMax->aggfnoid = maxoid;

			newList = lappend(newList, tempMin);
			newList = lappend(newList, tempMax);
			break;
		}
		default:
			break;
	}

	return newList;
}


/**
 * spd_make_tlist_for_baserel
 *
 * Making tlist for basrel with some checking
 *
 * @param[in,out] original tlits - list of target exprs
 * @param[in] root - base planner information
 * @param[in] include_field_select - select field node or not
 */

static List *
spd_make_tlist_for_baserel(List *tlist, PlannerInfo *root, bool include_field_select)
{
	ListCell	*lc;
	List		*new_tlist = NIL;
	Var			*spdurl_var = NULL;

	foreach(lc, tlist)
	{
		TargetEntry *ent = (TargetEntry *) lfirst(lc);
		Node *node = (Node *)ent->expr;

		if (!(include_field_select) && IsA(node, FieldSelect))
			continue;

		if (IsA(node, FuncExpr))
		{
			FuncExpr	*func = (FuncExpr *) node;
			char		*opername = NULL;

			/* Get function name and schema */
			opername = get_func_name(func->funcid);

			/* influx_time() should be used with group by, so it is removed from tlist in baserel. */
			if (strcmp(opername, "influx_time") == 0)
				continue;

			/* If there is __spd_url in function's argument, remove the function and add vars instead. */
			if (spd_expr_has_spdurl(root, (Node *) func->args, NULL))
			{
				ListCell *vars_lc;

				foreach(vars_lc, pull_var_clause((Node *) func->args, PVC_RECURSE_PLACEHOLDERS))
				{
					Var	*var = (Var *) lfirst(vars_lc);
					RangeTblEntry *rte;
					char	   *colname;

					rte = planner_rt_fetch(var->varno, root);
					colname = get_attname(rte->relid, var->varattno, false);
					if (strcmp(colname, SPDURL) == 0)
						spdurl_var = var;
					else
						new_tlist = add_to_flat_tlist(new_tlist, list_make1(var));
				}
				continue;
			}
		}

		new_tlist = add_to_flat_tlist(new_tlist, list_make1(node));
	}

	/* Place __spd_url into the last of tlist */
	if (spdurl_var)
		new_tlist = add_to_flat_tlist(new_tlist, list_make1(spdurl_var));

	return new_tlist;
}

/**
 * spd_merge_tlist
 *
 * Merge tlist into base tlist
 *
 * @param[in,out] base tlits - list of target exprs
 * @param[in] tlits to be merged - list of target exprs
 * @param[in] root - base planner infromation
 */

static List *
spd_merge_tlist(List *base_tlist, List *tlist, PlannerInfo *root)
{
	ListCell	*lc;
	Var			*spdurl_var = NULL;

	foreach(lc, tlist)
	{
		TargetEntry *tle = (TargetEntry *) lfirst(lc);
		Node *node = (Node *)tle->expr;
		Var	*var = (Var *) tle->expr;
		RangeTblEntry *rte;
		char	   *colname;

		if (IsA(node, Var))
		{
			rte = planner_rt_fetch(var->varno, root);
			colname = get_attname(rte->relid, var->varattno, false);
			if (strcmp(colname, SPDURL) == 0)
			{
				spdurl_var = var;
				continue;
			}
		}
		base_tlist = add_to_flat_tlist(base_tlist, list_make1(node));
	}

	/* Place __spd_url into the last of tlist */
	if (spdurl_var)
		base_tlist = add_to_flat_tlist(base_tlist, list_make1(spdurl_var));

	return base_tlist;
}

/*
 * spd_GetForeignUpperPathsChild
 *
 * Create upper paths for child node. This function creates PlannerInfo and RelOptInfo
 * for child node and call child GetForeignUpperPaths().
 * If pgspider_core cannot pushdown aggregation, this function returns false.
 *
 * @param[in] pChildInfo Child information
 * @param[in] fdw_private
 * @param[in] root Parent PlannerInfo
 * @param[in] stage
 * @param[in] output_rel Parent outer relation
 * @param[in] extra Extra argument given to parent GetForeignUpperPaths
 * @param[in] spd_root
 * @param[out] pushdown It is set to True if child node pushdown the aggregation.
 *						Otherwise, dont't update this variable.
 */
static bool
spd_GetForeignUpperPathsChild(ChildInfo *pChildInfo, SpdFdwPrivate *fdw_private, PlannerInfo *root,
							  UpperRelationKind stage, RelOptInfo *output_rel, void *extra,
							  PlannerInfo *spd_root, bool *pushdown)
{
	ListCell   *lc;
	ForeignServer *fs;
	ForeignDataWrapper *fdw;
	PlannerInfo *root_child = pChildInfo->root;
	RelOptInfo *baserel_child = pChildInfo->baserel;
	RelOptInfo *output_rel_child;
	Index	   *sortgrouprefs = NULL;
	Node	   *extra_having_quals = NULL;
	int			listn = 0;

	fs = GetForeignServer(pChildInfo->server_oid);
	fdw = GetForeignDataWrapper(fs->fdwid);

	/* If child node is not pgspider_fdw, don't pushdown aggregation if scan clauses have SPDURL. */
	if (strcmp(fdw->fdwname, PGSPIDER_FDW_NAME) != 0)
	{
		if (spd_checkurl_clauses(root, fdw_private->baserestrictinfo))
			return false;
	}

	/* pdate dummy child root */
	root_child->parse->groupClause = list_copy(root->parse->groupClause);

	if (fdw_private->having_quals != NIL)
	{
		/*
		* Set information about HAVING clause from pgspider_core_fdw
		* to GroupPathExtraData and dummy_root.
		*/
		root_child->parse->havingQual = (Node *)copyObject(fdw_private->having_quals);
		root_child->hasHavingQual = true;
	}
	else
	{
		/* Does not let child node execute HAVING. */
		root_child->parse->havingQual = NULL;
		root_child->hasHavingQual = false;
	}

	/* Currently dummy. @todo more better parsed object. */
	root_child->parse->hasAggs = true;

	/* Call below FDW to check it is OK to pushdown or not. */
	/* refer relnode.c fetch_upper_rel() */
	output_rel_child = makeNode(RelOptInfo);
	output_rel_child->reloptkind = RELOPT_UPPER_REL;
	output_rel_child->relids = bms_copy(baserel_child->relids);

	if (pChildInfo->fdwroutine->GetForeignUpperPaths != NULL)
	{
		extra_having_quals = (Node *)copyObject(((GroupPathExtraData *)extra)->havingQual);

		if (fdw_private->having_quals != NIL)
			((GroupPathExtraData *)extra)->havingQual = (Node *)copyObject(fdw_private->having_quals);
		else
			((GroupPathExtraData *)extra)->havingQual = NULL;

		output_rel_child->reltarget = copy_pathtarget(output_rel->reltarget);
		output_rel_child->reltarget->exprs = list_copy(fdw_private->upper_targets);
	}
	else
	{
		output_rel_child->reltarget = create_empty_pathtarget();
	}

	root_child->upper_rels[UPPERREL_GROUP_AGG] =
		lappend(root_child->upper_rels[UPPERREL_GROUP_AGG],
			output_rel_child);

	root_child->upper_targets[UPPERREL_GROUP_AGG] =
		make_pathtarget_from_tlist(fdw_private->child_comp_tlist);
	root_child->upper_targets[UPPERREL_WINDOW] =
		copy_pathtarget(spd_root->upper_targets[UPPERREL_WINDOW]);
	root_child->upper_targets[UPPERREL_FINAL] =
		copy_pathtarget(spd_root->upper_targets[UPPERREL_FINAL]);

	/*
	* Remove SPDURL from target lists and group clause if a
	* child is not pgspider_fdw.
	*/
	if (strcmp(fdw->fdwname, PGSPIDER_FDW_NAME) != 0 && fdw_private->groupby_has_spdurl)
	{
		/* Remove SPDURL from group clause. */
		root_child->parse->groupClause = remove_spdurl_from_group_clause(root, fdw_private->child_comp_tlist, root_child->parse->groupClause);

		/* Modify child tlist. We use child tlist for fetching data from child node. */
		fdw_private->child_tlist = remove_spdurl_from_targets(fdw_private->child_tlist, root);

		/* Update path target from new target list without SPDURL. */
		root_child->upper_targets[UPPERREL_GROUP_AGG] = make_pathtarget_from_tlist(fdw_private->child_tlist);

		if (pChildInfo->fdwroutine->GetForeignUpperPaths != NULL)
		{
			/* Remove SPDURL from target list. */
			output_rel_child->reltarget->exprs = remove_spdurl_from_targets(output_rel_child->reltarget->exprs, root);
		}
		else
		{
			List * tempList;

			/* Make tlist from path target. */
			tempList = make_tlist_from_pathtarget(fdw_private->rinfo.outerrel->reltarget);
			/* Remove SPDURL. */
			tempList = remove_spdurl_from_targets(tempList, root);
			/* Update path target */
			fdw_private->rinfo.outerrel->reltarget = make_pathtarget_from_tlist(tempList);
		}
	}

	/* Fill sortgrouprefs for child using child target entry list */
	sortgrouprefs = palloc0(sizeof(Index) * list_length(fdw_private->child_tlist));

	foreach (lc, fdw_private->child_tlist)
	{
		TargetEntry *tmp_entry = (TargetEntry *)lfirst(lc);

		sortgrouprefs[listn++] = tmp_entry->ressortgroupref;
	}
	root_child->upper_targets[UPPERREL_GROUP_AGG]->sortgrouprefs = sortgrouprefs;
	output_rel_child->reltarget->sortgrouprefs = sortgrouprefs;

	if (pChildInfo->fdwroutine->GetForeignUpperPaths != NULL)
	{
		pChildInfo->fdwroutine->GetForeignUpperPaths(root_child,
			stage, baserel_child, output_rel_child, extra);
		/* Give original HAVING qualifications for GroupPathExtra->havingQual. */
		((GroupPathExtraData *)extra)->havingQual = extra_having_quals;
	}

	if (output_rel_child->pathlist != NULL)
	{
		/* Push down aggregate case */
		pChildInfo->grouped_root_local = root_child;
		pChildInfo->grouped_rel_local = output_rel_child;

		/* If at least one child fdw pushdown aggregate, parent also pushdown it. */
		*pushdown = true;
	}
	else
	{
		/* Not pushdown case */
		struct Path *tmp_path;
		Query	   *query = root->parse;
		AggClauseCosts aggcosts_child;
		PathTarget *grouping_target = output_rel->reltarget;
		AggStrategy aggStrategy = AGG_PLAIN;

		MemSet(&aggcosts_child, 0, sizeof(AggClauseCosts));
		tmp_path = linitial(baserel_child->pathlist);

		if (query->groupClause)
		{
			aggStrategy = AGG_HASHED;
			foreach(lc, grouping_target->exprs)
			{
				Node * node = lfirst(lc);

				/* If there is ORDER BY inside aggregate function, set AggStrategy to AGG_SORTED */
				if (spd_is_sorted(node))
				{
					aggStrategy = AGG_SORTED;
					break;
				}
			}
		}
		/*
		* Pass dummy_aggcosts because create_agg_path requires
		* aggcosts in cases other than AGG_HASH.
		*/
		pChildInfo->aggpath = (AggPath *) create_agg_path((PlannerInfo *) root_child,
			output_rel_child, tmp_path,
			root_child->upper_targets[UPPERREL_GROUP_AGG],
			aggStrategy, AGGSPLIT_SIMPLE,
			root_child->parse->groupClause, NULL, &aggcosts_child,
			1);

		fdw_private->pPseudoAggList = lappend_oid(fdw_private->pPseudoAggList, pChildInfo->server_oid);
	}

	return true;
}

/**
 * spd_GetForeignUpperPaths
 *
 * Add paths for post-join operations like aggregation, grouping etc. if
 * corresponding operations are safe to be pushed down.
 *
 * Right now, we only support aggregate, grouping and having clause pushdown.
 *
 * @param[in] root Base planner infromation
 * @param[in] stage Not used
 * @param[in] input_rel Input RelOptInfo
 * @param[out] output_rel Output RelOptInfo
 * @param[in] extra Extra parameter
 */
static void
spd_GetForeignUpperPaths(PlannerInfo *root, UpperRelationKind stage,
						 RelOptInfo *input_rel, RelOptInfo *output_rel, void *extra)
{
	SpdFdwPrivate  *fdw_private,
				   *in_fdw_private;
	List	   *newList = NIL;
	ListCell   *lc;
	PlannerInfo *spd_root;
	int			listn = 0;
	RelOptInfo *dummy_output_rel;
	Path	   *path;
	bool		pushdown = false;
	int			i = 0;

	/*
	 * If input rel is not safe to be pushed down, then simply return as we cannot
	 * perform any post-join operations on the foreign server.
	 */
	in_fdw_private = (SpdFdwPrivate *) input_rel->fdw_private;
	if (!in_fdw_private || !in_fdw_private->childinfo ||
		!in_fdw_private->rinfo.pushdown_safe)
		return;

	/* Ignore stages we don't support and skip any duplicate calls. */
	if (stage != UPPERREL_GROUP_AGG || output_rel->fdw_private)
		return;

	/*
	 * Prepare SpdFdwPrivate for output RelOptInfo. spd_AllocatePrivate do
	 * zero clear.
	 */
	fdw_private = spd_AllocatePrivate();
	fdw_private->idx_url_tlist = -1;	/* -1: not have __spd_url */
	fdw_private->node_num = in_fdw_private->node_num;
	fdw_private->url_list = in_fdw_private->url_list;
	fdw_private->agg_query = true;
	fdw_private->baserestrictinfo = copyObject(in_fdw_private->baserestrictinfo);
	spd_root = in_fdw_private->spd_root;

	/* Currently dummy. @todo more better parsed object. */
	spd_root->parse->hasAggs = true;
	/* Call below FDW to check it is OK to pushdown or not. */
	/* refer relnode.c fetch_upper_rel() */
	dummy_output_rel = makeNode(RelOptInfo);
	dummy_output_rel->reloptkind = RELOPT_UPPER_REL;
	dummy_output_rel->reltarget = create_empty_pathtarget();
	spd_root->upper_rels[UPPERREL_GROUP_AGG] =
		lappend(spd_root->upper_rels[UPPERREL_GROUP_AGG],
				dummy_output_rel);
	/* make pathtarget */
	spd_root->upper_targets[UPPERREL_GROUP_AGG] =
		copy_pathtarget(root->upper_targets[UPPERREL_GROUP_AGG]);
	spd_root->upper_targets[UPPERREL_WINDOW] =
		copy_pathtarget(root->upper_targets[UPPERREL_WINDOW]);
	spd_root->upper_targets[UPPERREL_FINAL] =
		copy_pathtarget(root->upper_targets[UPPERREL_FINAL]);

	if (fdw_private->node_num > SPD_SINGLE_NODE)
	{
		/* Divide split-agg into multiple non-split agg */
		foreach (lc, spd_root->upper_targets[UPPERREL_GROUP_AGG]->exprs)
		{
			Aggref *aggref;
			Expr *temp_expr;
			enum Aggtype aggtype;

			temp_expr = lfirst(lc);
			aggref = (Aggref *)temp_expr;
			listn++;
			if (IS_SPLIT_AGG(aggref->aggfnoid))
				newList = spd_makedivtlist(aggref, newList);
			else if (IsA(temp_expr, Aggref) &&
					 is_catalog_split_agg(aggref->aggfnoid, &aggtype))
				newList = spd_catalog_makedivtlist(aggref, newList, aggtype);
			else
				newList = lappend(newList, temp_expr);
		}
		spd_root->upper_targets[UPPERREL_GROUP_AGG]->exprs = list_copy(newList);

	}

	fdw_private->childinfo = in_fdw_private->childinfo;
	fdw_private->rinfo.pushdown_safe = false;
	fdw_private->having_quals = NIL;
	fdw_private->has_having_quals = false;
	output_rel->fdw_private = fdw_private;
	output_rel->relid = input_rel->relid;

	/* Get parent agg path and create mapping_tlist. */
	path = get_foreign_grouping_paths(root, input_rel, output_rel);
	if (path == NULL)
		return;

	if (fdw_private->node_num > SPD_SINGLE_NODE)
		spd_root->upper_targets[UPPERREL_GROUP_AGG]->exprs = list_copy(newList);

	/* Set flag if group by has SPDURL. */
	fdw_private->groupby_has_spdurl = groupby_has_spdurl(root);

	/* Get index of SPDURL in the target list. */
	if (fdw_private->groupby_has_spdurl)
		fdw_private->idx_url_tlist = get_index_spdurl_from_targets(fdw_private->child_comp_tlist, root);

	/* child_tlist will be used instead of child_comp_tlist, because we will remove __spd_url from child_tlist. */
	fdw_private->child_tlist = list_copy(fdw_private->child_comp_tlist);

	/* Create path for each child node. */
	for (i = 0; i < fdw_private->node_num; i++)
	{
		ChildInfo *pChildInfo = &in_fdw_private->childinfo[i];

		if (pChildInfo->child_node_status != ServerStatusAlive)
			continue;

		if (!spd_GetForeignUpperPathsChild(pChildInfo, fdw_private, root, stage, output_rel, extra, spd_root, &pushdown))
			return;
	}

	/* Add generated path into grouped_rel by add_path(). */
	if (pushdown)
		add_path(output_rel, path);
}

/**
 * get_foreign_grouping_paths
 *
 * Get foreign path for grouping and/or aggregation.
 *
 * Given input_rel represents the underlying scan. The paths are added to the
 * given grouped_rel.
 *
 * @param[in] root Base planner information
 * @param[in] input_rel Input RelOptInfo
 * @param[in] grouped_rel Grouped relation RelOptInfo
 */
static Path *
get_foreign_grouping_paths(PlannerInfo *root, RelOptInfo *input_rel,
						   RelOptInfo *grouped_rel)
{
	Query	   *parse = root->parse;
	SpdFdwPrivate *ifpinfo = input_rel->fdw_private;
	SpdFdwPrivate *fpinfo = grouped_rel->fdw_private;
	ForeignPath *grouppath;
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;

	/* Nothing to be done, if there is no grouping or aggregation required. */
	if (!parse->groupClause && !parse->groupingSets && !parse->hasAggs &&
		!root->hasHavingQual)
		return NULL;

	/* Save the input_rel as outerrel in fpinfo. */
	fpinfo->rinfo.outerrel = input_rel;

	/*
	 * Copy foreign table, foreign server, user mapping, FDW options etc
	 * from the input relation's fpinfo.
	 */
	fpinfo->rinfo.table = ifpinfo->rinfo.table;
	fpinfo->rinfo.server = ifpinfo->rinfo.server;
	fpinfo->rinfo.user = ifpinfo->rinfo.user;

	/* Assess if it is safe to push down aggregation and grouping. */
	if (!foreign_grouping_ok(root, grouped_rel))
		return NULL;

	/*
	 * If no grouping, numGroups should be set 1.
	 * When creating upper path, rows is passed to pathnode->path.rows.
	 * When creating aggregation plan, somehow path.rows is passed to dNumGroups.
	 */
	if (!parse->groupClause)
	{
		/* Not grouping */
		rows = 1;
	}
	else if (parse->groupingSets)
	{
		/* Empty grouping sets ... one result row for each one */
		rows = list_length(parse->groupingSets);
	}
	else if (parse->hasAggs || root->hasHavingQual)
	{
		/* Plain aggregation, one result row */
		rows = 1;
	}
	else
	{
		rows = 0;
	}

	width = 0;
	startup_cost = 0;
	total_cost = 0;

	/* Now update this information in the fpinfo. */
	fpinfo->rinfo.rows = rows;
	fpinfo->rinfo.width = width;
	fpinfo->rinfo.startup_cost = startup_cost;
	fpinfo->rinfo.total_cost = total_cost;

	/* Create and add foreign path to the grouping relation. */
	grouppath = create_foreign_upper_path(root,
										grouped_rel,
										root->upper_targets[UPPERREL_GROUP_AGG],
										rows,
										startup_cost,
										total_cost,
										NIL,	/* no pathkeys */
										NULL,	/* no fdw_outerpath */
										NIL);	/* no fdw_private */
	return (Path *) grouppath;
}

/**
 * is_target_contain_group_by
 *
 * Check if the target expression contains a Var which exists in GROUP BY.
 *
 * @param[in] grouping_target Grouping targets
 * @param[in] groupClause List of SortGroupClause
 * @param[in] expr The expression that needs to check
 * @param[in] lc Next cell in Grouping targets (after the cell that we check)
 * @param[in] index Next index in Grouping targets (after the cell that we check)
 */
static bool
is_target_contain_group_by(PathTarget *grouping_target, List *groupClause, Expr *expr, ListCell *lc, int index)
{
	for_each_cell(lc, grouping_target->exprs, lc)
	{
		Index		sgref = get_pathtarget_sortgroupref(grouping_target, index);
		SortGroupClause *sgc = get_sortgroupref_clause_noerr(sgref, groupClause);
		Expr	   *groupByExpr = (Expr *) lfirst(lc);

		/* Check whether this expression is part of GROUP BY clause. */
		if (sgref && sgc)
		{
			/*
			 * Only need to continue if the expression is different from GROUP BY target.
			 * It is safe to push down if the expression is completely equal to GROUP target.
			 * Example: SELECT c1/4 FROM tbl GROUP BY c1/4; => safe to push down, no need to extract.
			 */
			if (!equal(expr, groupByExpr))
			{
				List		*aggvars;
				ListCell	*lc2;

				/* Pull out all Var and Aggref from the expression */
				aggvars = pull_var_clause((Node *) expr,
								PVC_INCLUDE_AGGREGATES);

				foreach(lc2, aggvars)
				{
					Expr	*v = (Expr *) lfirst(lc2);

					/* If the Var in GROUP BY matches with the Var in expression, need to extract */
					if (IsA(v, Var) && equal(groupByExpr, v))
						return true;
				}
			}
		}
		index++;
	}

	return false;
}

/*
 * is_shippable_grouping_target
 *
 * Evaluate grouping targets and check whether they are safe to push down
 * to the foreign side.  All GROUP BY expressions will be part of the
 * grouping target and thus there is no need to evaluate it separately.
 * While doing so, add required expressions into target list which can
 * then be used to pass to foreign server.
 */
static bool
is_shippable_grouping_target(PlannerInfo *root, RelOptInfo *grouped_rel, SpdFdwPrivate *fpinfo,
							 PathTarget *grouping_target, Query *query, List **ptlist,
							 List **pcompress_child_tlist, List **pmapping_tlist, List **pupper_targets)
{
	int			i = 0;
	ListCell   *lc;
	int			groupby_cursor = 0;
	List *tlist = NIL;
	List *compress_child_tlist = NIL;
	List *mapping_tlist = NIL;
	List *upper_targets = NIL;

	fpinfo->groupby_target = NULL;

	foreach(lc, grouping_target->exprs)
	{
		Expr	   *expr = (Expr *) lfirst(lc);
		Index		sgref = get_pathtarget_sortgroupref(grouping_target, i);
		ListCell   *l;
		SortGroupClause *sgc = get_sortgroupref_clause_noerr(sgref, query->groupClause);

		/* Check whether this expression is constant column */
		if (IsA(expr, Const) && fpinfo->node_num > SPD_SINGLE_NODE)
		{
			/* Constant column is not pushable. */
			grouping_target->exprs = foreach_delete_current(grouping_target->exprs, lc);
			if (sgref && sgc)
			{
				query->groupClause = list_delete_ptr(query->groupClause, sgc);
			}

			i++;
			continue;
		}

		/* Check whether this expression is part of GROUP BY clause. */
		if (sgref && sgc)
		{
			int			before_listnum;
			bool		allow_duplicate = true;
			int			target_num = 0;
			/*
			 * If any of the GROUP BY expression is not shippable we can not
			 * push down aggregation to the foreign server.
			 */
			if (!spd_is_foreign_expr(root, grouped_rel, expr))
				return false;
			/* Pushable, add to tlist */
			before_listnum = list_length(compress_child_tlist);
			/*
			 * When expr is already in compress_child_tlist, add as duplicated will cause
			 * wrong query when rebuilding query on temp table. No need to add as duplicated.
			 */
			if (!spd_tlist_member(expr, mapping_tlist, &target_num) && spd_tlist_member(expr, compress_child_tlist, &target_num))
				allow_duplicate = false;
			tlist = spd_add_to_flat_tlist(tlist, expr, &mapping_tlist, &compress_child_tlist, sgref, &upper_targets, allow_duplicate, false, false, fpinfo);
			groupby_cursor += list_length(compress_child_tlist) - before_listnum;
			/*
			 * When Operator expression contains group by column, the column will be added
			 * into compress_child_tlist when extracting the expression. Because of that,
			 * the groupby_cursor will be equal to before_listnum. We need to find the index of
			 * column in compress_child_tlist to set groupby_target.
			 */
			if (groupby_cursor == before_listnum)
			{
				int target_num;

				if(spd_tlist_member(expr, compress_child_tlist, &target_num))
					fpinfo->groupby_target = lappend_int(fpinfo->groupby_target, target_num);
			}
			else
				fpinfo->groupby_target = lappend_int(fpinfo->groupby_target, groupby_cursor - 1);
		}
		else
		{
			/* Check entire expression whether it is pushable or not. */
			if (spd_is_foreign_expr(root, grouped_rel, expr))
			{
				/*
				 * If it is pushable, add to tlist.
				 * Check if the SELECT target contains the Var which is existed in GROUP BY
				 * to avoid wrong result when executing query on temp table.
				 * Example: SELECT c1/4 FROM tbl GROUP BY c1; => remote query: SELECT c1 FROM tbl;
				 */
				int			before_listnum = list_length(compress_child_tlist);
				bool		is_contain_group_by = is_target_contain_group_by(grouping_target, query->groupClause, expr, list_head(grouping_target->exprs), 0);

				tlist = spd_add_to_flat_tlist(tlist, expr, &mapping_tlist, &compress_child_tlist, sgref, &upper_targets, false, false, is_contain_group_by, fpinfo);
				groupby_cursor += list_length(compress_child_tlist) - before_listnum;
			}
			else
			{
				List	   *aggvars;

				/* Not matched exactly, pull the var with aggregates then check it again. */
				aggvars = pull_var_clause((Node *) expr,
										  PVC_INCLUDE_AGGREGATES);

				if (!spd_is_foreign_expr(root, grouped_rel, (Expr *) aggvars))
					return false;

				/*
				 * Add aggregates, if any, into the targetlist.  Plain var
				 * nodes should be either same as some GROUP BY expression or
				 * part of some GROUP BY expression. In later case, the query
				 * cannot refer plain var nodes without the surrounding
				 * expression.  In both the cases, they are already part of
				 * the targetlist and thus no need to add them again.  In fact
				 * adding pulled plain var nodes in SELECT clause will cause
				 * an error on the foreign server if they are not same as some
				 * GROUP BY expression.
				 */
				foreach(l, aggvars)
				{
					Expr	   *expr = (Expr *) lfirst(l);

					if (IsA(expr, Aggref))
					{
						int			before_listnum = list_length(compress_child_tlist);

						tlist = spd_add_to_flat_tlist(tlist, expr, &mapping_tlist, &compress_child_tlist, sgref, &upper_targets, false, false, false, fpinfo);
						groupby_cursor += list_length(compress_child_tlist) - before_listnum;
					}
				}
			}
		}

		/* Save the push down target list */
		i++;
	}

	/* Set output variables. */
	*ptlist = tlist;
	*pcompress_child_tlist = compress_child_tlist;
	*pmapping_tlist = mapping_tlist;
	*pupper_targets = upper_targets;

	return true;
}

/**
 * foreign_grouping_ok
 *
 * Assess whether the aggregation, grouping and having operations can be pushed
 * down to the foreign server. As a side effect, save information we obtain in
 * this function to SpdFdwPrivate of the input relation.
 *
 * @param[in] root Base planner information
 * @param[in] grouped_rel Grouped relation RelOptInfo
 */
static bool
foreign_grouping_ok(PlannerInfo *root, RelOptInfo *grouped_rel)
{
	Query	   *query = copyObject(root->parse);
	PathTarget *grouping_target;
	SpdFdwPrivate *fpinfo = (SpdFdwPrivate *) grouped_rel->fdw_private;
	SpdFdwPrivate *ofpinfo;
	List	   *tlist = NIL;
	List	   *mapping_tlist = NIL;
	List	   *compress_child_tlist = NIL;
	List	   *upper_targets = NIL;

	/* Grouping Sets are not pushable. */
	if (query->groupingSets)
		return false;

	/* Get the fpinfo of the underlying scan relation. */
	ofpinfo = (SpdFdwPrivate *) fpinfo->rinfo.outerrel->fdw_private;

	/*
	 * If underneath input relation has any local conditions, those conditions
	 * are required to be applied before performing aggregation. Hence the
	 * aggregate cannot be pushed down.
	 */
	if (ofpinfo->rinfo.local_conds)
		return false;

	/*
	 * The targetlist expected from this node and the targetlist pushed down
	 * to the foreign server may be different. The latter requires
	 * sortgrouprefs to be set to push down GROUP BY clause, but should not
	 * have those arising from ORDER BY clause. These sortgrouprefs may be
	 * different from those in the plan's targetlist. Use a copy of path
	 * target to record the new sortgrouprefs.
	 */
	grouping_target = copy_pathtarget(root->upper_targets[UPPERREL_GROUP_AGG]);

	fpinfo->has_stub_star_regex_function = false;

	/*
	 * Evaluate grouping targets and check whether they are safe to push down
	 * to the foreign side.
	 */
	if (!is_shippable_grouping_target(root, grouped_rel, fpinfo, grouping_target,
									  query, &tlist, &compress_child_tlist,
									  &mapping_tlist, &upper_targets))
		return false;

	/* If all target list is constant column, we don't pushdown this query. */
	if (mapping_tlist == NIL)
		return false;

	/*
	 * Classify the pushable and non-pushable having clauses and save them in
	 * remote_conds and local_conds of the grouped rel's fpinfo.
	 */
	if (root->hasHavingQual && query->havingQual)
	{
		ListCell   *lc;

		/* Mark root plan has qualification applied to HAVING */
		fpinfo->has_having_quals = true;

		foreach(lc, (List *) query->havingQual)
		{
			Expr	   *expr = (Expr *) lfirst(lc);
			RestrictInfo *rinfo;

			/*
			 * Currently, the core code doesn't wrap havingQuals in
			 * RestrictInfos, so we must make our own.
			 */
			Assert(!IsA(expr, RestrictInfo));
			rinfo = make_restrictinfo(expr, true, false, false, root->qual_security_level,
									  grouped_rel->relids, NULL, NULL);
			if (!spd_is_foreign_expr(root, grouped_rel, expr))
				return false;

			fpinfo->rinfo.remote_conds = lappend(fpinfo->rinfo.remote_conds, rinfo);

			/* Check qualifications whether can be passed to child nodes. */
			if(spd_is_having_safe((Node *) rinfo->clause))
				fpinfo->having_quals = lappend(fpinfo->having_quals, rinfo->clause);

			/*
			 * Filter operation for HAVING clause will be executed by SELECT query
			 * for temptable with full root HAVING query.
			 *
			 * Extract qualification to mapping list.
			 */
			if (fpinfo->node_num > SPD_SINGLE_NODE)
			{
				tlist = spd_add_to_flat_tlist(tlist, rinfo->clause, &mapping_tlist,
												&compress_child_tlist, 0, &upper_targets, false, true, false, fpinfo);
			}
			else
			{
				List *agg_vars;
				ListCell *agg_lc;

				agg_vars = pull_var_clause((Node*)rinfo->clause, PVC_INCLUDE_AGGREGATES);
				foreach(agg_lc, agg_vars)
				{
					Expr *expr = (Expr*)lfirst(agg_lc);

					if (IsA(expr, Aggref))
					{
						tlist = spd_add_to_flat_tlist(tlist, expr, &mapping_tlist,
												&compress_child_tlist, 0, &upper_targets, false, true, false, fpinfo);
					}
				}
			}
		}
	}

	/*
	 * After building new tlist, we need to set ressortgroupref
	 * according to the original order in the group by clause.
	 */
	if (fpinfo->node_num == SPD_SINGLE_NODE)
	{
		spd_apply_pathtarget_labeling_to_tlist(compress_child_tlist, grouping_target);
		spd_apply_pathtarget_labeling_to_tlist(tlist, grouping_target);
	}

	/* Set root->parse. */
	root->parse = query;

	/* Store generated targetlist. */
	fpinfo->rinfo.grouped_tlist = tlist;

	/* Safe to pushdown. */
	fpinfo->rinfo.pushdown_safe = true;

	/*
	 * Set cached relation costs to some negative value, so that we can detect
	 * when they are set to some sensible costs, during one (usually the
	 * first) of the calls to estimate_path_cost_size().
	 */
	fpinfo->rinfo.rel_startup_cost = -1;
	fpinfo->rinfo.rel_total_cost = -1;

	/*
	 * Set the string describing this grouped relation to be used in EXPLAIN
	 * output of corresponding ForeignScan.
	 */
	fpinfo->rinfo.relation_name = psprintf("Aggregate on (%s)", ofpinfo->rinfo.relation_name);
	fpinfo->mapping_tlist = mapping_tlist;
	fpinfo->child_comp_tlist = compress_child_tlist;
	fpinfo->upper_targets = upper_targets;

	return true;
}


/*
 * spd_CreateChildJoinRel
 *
 * Create child join relation.
 * Refer make_join_rel() in joinrels.c.
 */
static RelOptInfo *
spd_CreateChildJoinRel(PlannerInfo *root_child, RelOptInfo *rel1, RelOptInfo *rel2)
{
	Relids		joinrelids;
	SpecialJoinInfo *sjinfo;
	bool		reversed;
	SpecialJoinInfo sjinfo_data;
	RelOptInfo *joinrel_child;
	List	   *restrictlist;

	/* Construct Relids set that identifies the joinrel. */
	joinrelids = bms_union(rel1->relids, rel2->relids);

	/* Check validity and determine join type. */
	if (!spd_join_is_legal(root_child, rel1, rel2, joinrelids,
					   &sjinfo, &reversed))
	{
		/* invalid join path */
		bms_free(joinrelids);
		return NULL;
	}

	/* Swap rels if needed to match the join info. */
	if (reversed)
	{
		RelOptInfo *trel = rel1;

		rel1 = rel2;
		rel2 = trel;
	}

	/*
	 * If it's a plain inner join, then we won't have found anything in
	 * join_info_list.  Make up a SpecialJoinInfo so that selectivity
	 * estimation functions will know what's being joined.
	 */
	if (sjinfo == NULL)
	{
		sjinfo = &sjinfo_data;
		sjinfo->type = T_SpecialJoinInfo;
		sjinfo->min_lefthand = rel1->relids;
		sjinfo->min_righthand = rel2->relids;
		sjinfo->syn_lefthand = rel1->relids;
		sjinfo->syn_righthand = rel2->relids;
		sjinfo->jointype = JOIN_INNER;
		/* we don't bother trying to make the remaining fields valid */
		sjinfo->lhs_strict = false;
		sjinfo->delay_upper_joins = false;
		sjinfo->semi_can_btree = false;
		sjinfo->semi_can_hash = false;
		sjinfo->semi_operators = NIL;
		sjinfo->semi_rhs_exprs = NIL;
	}

	/*
	 * Find or build the join RelOptInfo, and compute the restrictlist that
	 * goes with this particular joining.
	 */
	joinrel_child = build_join_rel(root_child, joinrelids, rel1, rel2, sjinfo,
										  &restrictlist);

	bms_free(joinrelids);

	return joinrel_child;
}

static bool
spd_JoinPushable(SpdFdwPrivate *fdw_private_outer,
					  SpdFdwPrivate *fdw_private_inner)
{
	ChildInfo *pChildInfo_outer = &fdw_private_outer->childinfo[0];
	ChildInfo *pChildInfo_inner = &fdw_private_inner->childinfo[0];

	/* We cannot pushdown join if there are multiple nodes. */
	if (fdw_private_outer->node_num != 1 || fdw_private_inner->node_num != 1)
		return false;

	/* We cannot pushdown join if inner relation and outer relation are different nodes. */
	if (pChildInfo_outer->server_oid != pChildInfo_inner->server_oid)
		return false;

	if (pChildInfo_outer->fdwroutine->GetForeignJoinPaths == NULL ||
		 pChildInfo_inner->fdwroutine->GetForeignJoinPaths == NULL)
		return false;

	return true;
}

/**
 * Return true if there is SPDURL in expressions.
 *
 * @param[in] root Base planner infromation
 * @param[in] expr Expression to be searched
 * @param[out] target_exprs Var expressions are stored here if SPDURL
 *             is not used.
 */
static bool
spd_expr_has_spdurl(PlannerInfo *root, Node *expr, List **target_exprs)
{
	SpdurlWalkerContext ctx = {0};
	bool		has_spdurl;

	ctx.root = root;
	has_spdurl = check_spdurl_walker(expr, &ctx);
	
	if (target_exprs)
		*target_exprs = ctx.target_exprs;
	else
		list_free(ctx.target_exprs);

	if (has_spdurl)
		return true;
	else
		return false;
}

/**
 * Return true if there is at least one SPDURL in expressions list.
 *
 * @param[in] root Base planner infromation
 * @param[in] exprs Expression list to be searched
 */
static bool
spd_exprs_has_spdurl(PlannerInfo *root, List *exprs)
{
	ListCell   *lc;

	foreach(lc, exprs)
	{
		Expr	   *expr = (Expr *) lfirst(lc);
		bool		has_spdurl;

		has_spdurl = spd_expr_has_spdurl(root, (Node *) expr, NULL);
		if (has_spdurl)
			return true;
	}
	return false;
}

static RelOptInfo *
spd_GetForeignJoinPathsChild(SpdFdwPrivate *fdw_private_outer,
									 SpdFdwPrivate *fdw_private_inner,
									 PlannerInfo *root,
									 RelOptInfo *joinrel,
									 RelOptInfo *outerrel,
									 RelOptInfo *innerrel,
									 JoinType jointype,
									 JoinPathExtraData *extra)
{
	ChildInfo *pChildInfo_inner = &fdw_private_inner->childinfo[0];
	PlannerInfo *root_child = linitial(root->child_root);
	RelOptInfo *outerrel_child;
	RelOptInfo *innerrel_child;
	RelOptInfo *joinrel_child;

	/* Create child base relations of inner and outer relation. */
	if (outerrel->reloptkind == RELOPT_JOINREL)
		outerrel_child = fdw_private_outer->joinrel_child;
	else
		outerrel_child = root_child->simple_rel_array[outerrel->relid];

	if (innerrel->reloptkind == RELOPT_JOINREL)
		innerrel_child = fdw_private_inner->joinrel_child;
	else
		innerrel_child = root_child->simple_rel_array[innerrel->relid];

	/* Create child join relation. */
	joinrel_child = spd_CreateChildJoinRel(root_child, outerrel_child, innerrel_child);
	if (!joinrel_child)
		return NULL;

	pChildInfo_inner->fdwroutine->GetForeignJoinPaths(root_child, joinrel_child,
							  								 outerrel_child, innerrel_child,
															 jointype, extra);

	if (!joinrel_child->pathlist)
		return NULL;
	
	return joinrel_child;
}

/*
 * postgresGetForeignJoinPaths
 *		Add possible ForeignPath to joinrel, if join is safe to push down.
 */
static void
spd_GetForeignJoinPaths(PlannerInfo *root,
							  RelOptInfo *joinrel,
							  RelOptInfo *outerrel,
							  RelOptInfo *innerrel,
							  JoinType jointype,
							  JoinPathExtraData *extra)
{
	SpdFdwPrivate *fdw_private;
	SpdFdwPrivate *fdw_private_outer = outerrel->fdw_private;
	SpdFdwPrivate *fdw_private_inner = innerrel->fdw_private;
	RelOptInfo	*joinrel_child;
	ForeignPath *joinpath;
	double		rows;
	Cost		startup_cost;
	Cost		total_cost;
	Path	   *epq_path;		/* Path to create plan to be executed when
								 * EvalPlanQual gets triggered. */

	/*
	 * Skip if this join combination has been considered already.
	 */
	if (joinrel->fdw_private)
		return;

	/*
	 * This code does not work for joins with lateral references, since those
	 * must have parameterized paths, which we don't generate yet.
	 */
	if (!bms_is_empty(joinrel->lateral_relids))
		return;

	if (!fdw_private_outer || !fdw_private_inner)
		return;

	/* Check if we can pushdow join. */
	if (!spd_JoinPushable(fdw_private_outer, fdw_private_inner))
		return;

	/* Now we don't support to pushdown join if SPDURL is used. */
	if (spd_exprs_has_spdurl(root, joinrel->reltarget->exprs))
		return;

	/* Create path for child node. */
	joinrel_child = spd_GetForeignJoinPathsChild(fdw_private_outer, fdw_private_inner, root, joinrel, outerrel, innerrel, jointype, extra);
	if (!joinrel_child)
		return;

	/*
	 * Create unfinished PgFdwRelationInfo entry which is used to indicate
	 * that the join relation is already considered, so that we won't waste
	 * time in judging safety of join pushdown and adding the same paths again
	 * if found safe. Once we know that this join can be pushed down, we fill
	 * the entry.
	 */
	fdw_private = spd_AllocatePrivate();
	fdw_private->idx_url_tlist = -1;	/* -1: not have SPDURL */
	fdw_private->node_num = 1;
	fdw_private->childinfo = fdw_private_inner->childinfo;
	fdw_private->joinrel_child = joinrel_child;
	/*
	 * Refering postgres_fdw.c @ postgresGetForeignPlan()
	 * For a join rel, baserestrictinfo is NIL
	 */
	fdw_private->baserestrictinfo = NIL;
	joinrel->fdw_private = fdw_private;

	/*
	 * If there is a possibility that EvalPlanQual will be executed, we need
	 * to be able to reconstruct the row using scans of the base relations.
	 * GetExistingLocalJoinPath will find a suitable path for this purpose in
	 * the path list of the joinrel, if one exists.  We must be careful to
	 * call it before adding any ForeignPath, since the ForeignPath might
	 * dominate the only suitable local path available.  We also do it before
	 * calling foreign_join_ok(), since that function updates fpinfo and marks
	 * it as pushable if the join is found to be pushable.
	 */
	if (root->parse->commandType == CMD_DELETE ||
		root->parse->commandType == CMD_UPDATE ||
		root->rowMarks)
	{
		epq_path = GetExistingLocalJoinPath(joinrel);
		if (!epq_path)
		{
			elog(DEBUG3, "could not push down foreign join because a local path suitable for EPQ checks was not found");
			return;
		}
	}
	else
		epq_path = NULL;

	/* Set estimated rows and costs. */
	rows = joinrel_child->rows;
	startup_cost = 0;
	total_cost = 0;
	joinrel->rows = rows;
	joinrel->reltarget->width = joinrel_child->reltarget->width;
	fdw_private->rinfo.startup_cost = startup_cost;
	fdw_private->rinfo.total_cost = total_cost;

	/*
	 * Create a new join path and add it to the joinrel which represents a
	 * join between foreign tables.
	 */
	joinpath = create_foreign_join_path(root,
										joinrel,
										NULL,	/* default pathtarget */
										rows,
										startup_cost,
										total_cost,
										NIL,	/* no pathkeys */
										joinrel->lateral_relids,
										epq_path,
										NIL);	/* no fdw_private */

	/* Add generated path into joinrel by add_path(). */
	add_path(joinrel, (Path *) joinpath);
}

/**
 * Produce extra output for EXPLAIN of a ForeignScan on a foreign table
 *
 * @param[in] node Node information to be explained
 * @param[in] es Explain state
 */
static void
spd_ExplainForeignScan(ForeignScanState *node,
					   ExplainState *es)
{
	FdwRoutine *fdwroutine;
	int			i;
	SpdFdwPrivate *fdw_private;
	ForeignScanThreadInfo *fssThrdinfo = node->spd_fsstate;

	/* Reset child node offset to 0 for new query execution. */
	g_node_offset = 0;

	fdw_private = (SpdFdwPrivate *) fssThrdinfo[0].private;

	if (fdw_private == NULL)
		elog(ERROR, "fdw_private is NULL");

	/* Call child FDW's ExplainForeignScan(). */
	for (i = 0; i < fdw_private->node_num; i++)
	{
		ForeignServer *fs;
		ChildInfo *pChildInfo = &fdw_private->childinfo[i];

		fs = GetForeignServer(pChildInfo->server_oid);
		fdwroutine = GetFdwRoutineByServerId(pChildInfo->server_oid);

		if (fdwroutine->ExplainForeignScan == NULL)
			continue;

		ExplainPropertyText(psprintf("Node: %s / Status", fs->servername),
							SpdServerstatusStr[pChildInfo->child_node_status], es);

		if (pChildInfo->child_node_status != ServerStatusAlive)
			continue;

		es->indent++;

		PG_TRY();
		{
			int			idx = pChildInfo->index_threadinfo;

			if (es->verbose && fdw_private->agg_query)
				ExplainPropertyText("Agg push-down", pChildInfo->pseudo_agg ? "no" : "yes", es);

			fdwroutine->ExplainForeignScan(((ForeignScanThreadInfo *) node->spd_fsstate)[idx].fsstate, es);
		}
		PG_CATCH();
		{
			/*
			 * If ExplainForeignScan fails in child FDW, then set
			 * fdw_private->child_table_alive to FALSE.
			 */
			pChildInfo->child_node_status = ServerStatusDead;
			elog(WARNING, "ExplainForeignScan of child[%d] failed.", i);
			FlushErrorState();
		}
		PG_END_TRY();
		es->indent--;
	}
}

/**
 * spd_GetForeignPaths
 *
 * Get foreign paths for each child tables using fdws
 * saving each foreign path into base rel list.
 *
 * spd_GetForeignRelSize() saves baserel list into fdw_private of aliving child nodes.
 * GetForeignPaths() is executed for only aliving child nodes.
 *
 * @param[in] root Base planner infromation
 * @param[in] baserel Base relation option
 * @param[in] foreigntableid Parent foreign table id
 */
static void
spd_GetForeignPaths(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid)
{
	int			i;
	SpdFdwPrivate *fdw_private = (SpdFdwPrivate *) baserel->fdw_private;
	Cost		startup_cost = 0;
	Cost		total_cost = 0;
	Cost		rows = 0;

	if (fdw_private == NULL)
	{
		elog(ERROR, "fdw_private is NULL");
	}
	/* Create foreign paths using base_rel_list to each child node. */
	for (i = 0; i < fdw_private->node_num; i++)
	{
		ChildInfo *pChildInfo = &fdw_private->childinfo[i];

		/* Skip dead node. */
		if (pChildInfo->child_node_status != ServerStatusAlive)
		{
			continue;
		}


		PG_TRY();
		{
			Path	   *childpath;
			Oid			oid_server;
			ForeignServer *fs;
			ForeignDataWrapper *fdw;

			oid_server = serverid_of_relation(pChildInfo->oid);
			fs = GetForeignServer(oid_server);
			fdw = GetForeignDataWrapper(fs->fdwid);

			/*
			 * The ECs need to reached canonical state. Otherwise, pathkeys of
			 * parquet_s3_fdw could be rendered non-canonical.
			 */
			if (strcmp(fdw->fdwname, PARQUET_S3_FDW_NAME) == 0)
				pChildInfo->root->ec_merging_done = root->ec_merging_done;

			pChildInfo->fdwroutine->GetForeignPaths((PlannerInfo *) pChildInfo->root,
										(RelOptInfo *) pChildInfo->baserel,
										pChildInfo->oid);
			/* Add child node costs. */
			if (pChildInfo->baserel->pathlist != NULL)
			{
				childpath = (Path *) lfirst_node(ForeignPath, list_head(pChildInfo->baserel->pathlist));
				startup_cost += childpath->startup_cost;
				total_cost += childpath->total_cost;
				rows += childpath->rows;
			}
		}
		PG_CATCH();
		{
			/*
			 * If fail to create foreign paths, then set
			 * fdw_private->child_table_alive to FALSE.
			 */
			pChildInfo->child_node_status = ServerStatusDead;

			elog(WARNING, "GetForeignPaths of child[%d] failed.", i);
			FlushErrorState();
			if (throwErrorIfDead)
			{
				ForeignServer *fs = GetForeignServer(pChildInfo->server_oid);
				spd_aliveError(fs);
			}
		}
		PG_END_TRY();
	}
	baserel->rows = rows;

	add_path(baserel, (Path *) create_foreignscan_path(root, baserel,
											NULL,
											baserel->rows,
											startup_cost,
											total_cost,
											NIL,	/* no pathkeys*/
											baserel->lateral_relids,
											NULL,	/* no outerpath*/
											NULL));
}


/**
 * outer_var_walker
 *
 * Change expr Var node type to OUTER VAR recursively.
 *
 * @param[in,out] node Plan tree node
 * @param[in,out] param  Attribute number
 */
static bool
outer_var_walker(Node *node, void *param)
{
	if (node == NULL)
		return false;

	if (IsA(node, Var))
	{
		Var		   *expr = (Var *) node;

		expr->varno = OUTER_VAR;
		return false;
	}
	return expression_tree_walker(node, outer_var_walker, (void *) param);
}

/**
 * spd_createPushDownPlan
 *
 * Build aggregation plan for each push down cases and
 * save each foreign plan into base rel list.
 *
 * @param[in] tlist Target list
 */
static List *
spd_createPushDownPlan(List *tlist)
{

	/*
	 * Temporary create TargetEntry: @todo make correct targetenrty, as if it
	 * is the correct aggregation. (count, max, etc..)
	 */
	TargetEntry *tle;
	Aggref	   *aggref;
	ListCell   *lc;
	List	   *dummy_tlist = NIL;

	dummy_tlist = copyObject(tlist);
	foreach(lc, dummy_tlist)
	{
		tle = lfirst_node(TargetEntry, lc);
		aggref = (Aggref *) tle->expr;

		outer_var_walker((Node *) aggref, NULL);
	}
	return dummy_tlist;
}

/**
 * Return true if SPDURL is found in 'node'.
 *
 * @param[in] node Expression
 * @param[in] root Root planner info
 */
static bool
check_spdurl_walker(Node *node, SpdurlWalkerContext *ctx)
{
	if (node == NULL)
		return false;

	if (IsA(node, Var))
	{
		Var		   *var = (Var *) node;
		PlannerInfo *root = ctx->root;
		char	   *colname;
		RangeTblEntry *rte;

		/* The case of whole row. */
		if (var->varattno == 0)
			return true;

		rte = planner_rt_fetch(var->varno, root);
		colname = get_attname(rte->relid, var->varattno, false);
		if (strcmp(colname, SPDURL) == 0)
		{
			/* Stop the search. */
			return true;
		}
		else
		{
			ctx->target_exprs = lappend(ctx->target_exprs, node);
			return false;
		}
	}
	return expression_tree_walker(node, check_spdurl_walker, (void *) ctx);
}

/**
 * Search SPDURL for each clause of 'scan_clauses' in order to decide
 * whether it can be pushed down or not.
 * If found, store 'baserestrictinfo' to 'push_scan_clauses'.
 * If not found, store NULL to 'push_scan_clauses'.
 *
 * @param[in] scan_clauses Scan clauses to be checked
 * @param[in] root Base planner infromation
 * @param[in] baserestrictinfo Restrict information
 */
static bool
spd_checkurl_clauses(PlannerInfo *root, List *baserestrictinfo)
{
	ListCell   *lc;

	foreach(lc, baserestrictinfo)
	{
		RestrictInfo *clause = (RestrictInfo *) lfirst(lc);
		Expr	   *expr = (Expr *) clause->clause;

		if (spd_expr_has_spdurl(root, (Node *) expr, NULL))
		{
			/* don't pushdown *all* where caluses if spd_url is found */
			return true;
		}
	}
	return false;
}

static Sort *
spd_make_sort(Plan *lefttree, int numCols,
		  AttrNumber *sortColIdx, Oid *sortOperators,
		  Oid *collations, bool *nullsFirst)
{
	Sort	   *node = makeNode(Sort);
	Plan	   *plan = &node->plan;

	plan->targetlist = lefttree->targetlist;
	plan->qual = NIL;
	plan->lefttree = lefttree;
	plan->righttree = NULL;
	node->numCols = numCols;
	node->sortColIdx = sortColIdx;
	node->sortOperators = sortOperators;
	node->collations = collations;
	node->nullsFirst = nullsFirst;

	return node;
}

static Sort *
spd_make_sort_from_groupcols(List *groupcls,
						 AttrNumber *grpColIdx,
						 Plan *lefttree)
{
	List	   *sub_tlist = lefttree->targetlist;
	ListCell   *l;
	int			numsortkeys;
	AttrNumber *sortColIdx;
	Oid		   *sortOperators;
	Oid		   *collations;
	bool	   *nullsFirst;

	/* Convert list-ish representation to arrays wanted by executor */
	numsortkeys = list_length(groupcls);
	sortColIdx = (AttrNumber *) palloc(numsortkeys * sizeof(AttrNumber));
	sortOperators = (Oid *) palloc(numsortkeys * sizeof(Oid));
	collations = (Oid *) palloc(numsortkeys * sizeof(Oid));
	nullsFirst = (bool *) palloc(numsortkeys * sizeof(bool));

	numsortkeys = 0;
	foreach(l, groupcls)
	{
		SortGroupClause *grpcl = (SortGroupClause *) lfirst(l);
		TargetEntry *tle = get_tle_by_resno(sub_tlist, grpColIdx[numsortkeys]);

		if (!tle)
			elog(ERROR, "could not retrieve tle for sort-from-groupcols");

		sortColIdx[numsortkeys] = tle->resno;
		sortOperators[numsortkeys] = grpcl->sortop;
		collations[numsortkeys] = exprCollation((Node *) tle->expr);
		nullsFirst[numsortkeys] = grpcl->nulls_first;
		numsortkeys++;
	}

	return spd_make_sort(lefttree, numsortkeys,
					 sortColIdx, sortOperators,
					 collations, nullsFirst);
}

/*
 * spd_CreateAggNodeForPseudoAgg
 *
 * Create Agg Node for child node in order to calculate aggregate function by pgspider_core
 * if aggregate is not pushed down. Created Agg Node is stored in pChildInfo->pAgg.
 *
 * @param[in,out] pChildInfo Child information
 * @param[in] groupby_has_spdurl True if GROU BY has SPD_URL
 * @param[in] child_tlist Target list of child
 * @param[in] fsplan Foreign plan of child node
 * @param[in] groupingSets
 *
 */
static void
spd_CreateAggNodeForPseudoAgg(ChildInfo *pChildInfo, bool groupby_has_spdurl,
							  List *child_tlist, ForeignScan *fsplan,
							  List *groupingSets)
{
	List *agg_child_tlist;
	ListCell *lc;
	int			idx = 0;
	Plan *sort_plan = NULL;

	/*
	 * If groupby has SPDURL, SPDURL will be removed from the target
	 * list. Before creating aggregation plan, re-indexing item by
	 * resno for child target list. This helps SPI_execAgg puts data
	 * to right position after calculation.
	 */
	if (groupby_has_spdurl)
	{
		foreach(lc, child_tlist)
		{
			TargetEntry *ent = (TargetEntry*)lfirst(lc);

			idx++;
			ent->resno = idx;
		}
	}

	agg_child_tlist = spd_createPushDownPlan(child_tlist);

	/*
	 * Create aggregation plan with foreign table scan.
	 * extract_grouping_cols() requires targetlist of subplan.
	 */
	if (pChildInfo->aggpath->aggstrategy == AGG_SORTED)
	{
		AttrNumber *new_grpColIdx;

		new_grpColIdx = extract_grouping_cols(pChildInfo->aggpath->groupClause,
			fsplan->scan.plan.targetlist);

		sort_plan = (Plan*)
			spd_make_sort_from_groupcols(pChildInfo->aggpath->groupClause,
				new_grpColIdx,
				(Plan*)fsplan);
	}

	pChildInfo->pAgg = make_agg(agg_child_tlist,
		NULL,
		pChildInfo->aggpath->aggstrategy,
		pChildInfo->aggpath->aggsplit,
		list_length(pChildInfo->aggpath->groupClause),
		extract_grouping_cols(pChildInfo->aggpath->groupClause, fsplan->scan.plan.targetlist),
		extract_grouping_ops(pChildInfo->aggpath->groupClause),
		extract_grouping_collations(pChildInfo->aggpath->groupClause, fsplan->scan.plan.targetlist),
		groupingSets,
		NIL,
		pChildInfo->aggpath->path.rows,
		pChildInfo->aggpath->transitionSpace,
		sort_plan != NULL ? sort_plan : (Plan*)fsplan);
}

/**
 * spd_GetForeignPlansChild
 *
 * Build foreign plan for each child tables using fdws.
 * saving each foreign plan into  base rel list
 *
 * @param[in] root Base planner infromation
 * @param[in] baserel Base relation option
 * @param[in] foreigntableid Parent foreing table id
 * @param[in] best_path Best path selected by postgres core
 * @param[in] ptemptlist Target_list of pgspider core
 * @param[in] push_scan_clauses Where scan clauses
 * @param[in] outer_plan Outer plan
 * @param[in] childinfo Child information
 */
static void
spd_GetForeignPlansChild(PlannerInfo *root, RelOptInfo *baserel,
						 ForeignPath *best_path, List *ptemptlist, List **push_scan_clauses,
						 Plan *outer_plan, ChildInfo *childinfo)
{
	int			i;
	SpdFdwPrivate *fdw_private = (SpdFdwPrivate *) baserel->fdw_private;

	/* Create Foreign plans for each child. */
	for (i = 0; i < fdw_private->node_num; i++)
	{
		ForeignPath* child_path;
		ForeignScan *fsplan = NULL;
		List	   *temptlist;
		ChildInfo *pChildInfo = &childinfo[i];

		/* Skip dead node. */
		if (pChildInfo->baserel == NULL)
			break;
		if (pChildInfo->child_node_status != ServerStatusAlive)
			continue;

		/*
		 * Checking if aggregate function is pushed down or not by searching the list is costly.
		 * So we cache the result into pseudo_agg.
		 */
		if (list_member_oid(fdw_private->pPseudoAggList, pChildInfo->server_oid))
			pChildInfo->pseudo_agg = true;
		else
			pChildInfo->pseudo_agg = false;

		PG_TRY();
		{
			/* Create plan. */
			if (pChildInfo->grouped_rel_local != NULL)
			{
				/* Check if pathlist of aggregate push down. */
				if (!pChildInfo->grouped_rel_local->pathlist)
					elog(ERROR, "Agg path is not found.");

				/* FDWs expect NULL scan clauses for UPPER REL. */
				*push_scan_clauses = NULL;

				/* Pick any agg path */
				child_path = lfirst(list_head(pChildInfo->grouped_rel_local->pathlist));
				temptlist = PG_build_path_tlist((PlannerInfo *) pChildInfo->root, (Path *) child_path);
				fsplan = pChildInfo->fdwroutine->GetForeignPlan(pChildInfo->grouped_root_local,
													pChildInfo->grouped_rel_local,
													pChildInfo->oid,
													(ForeignPath *) child_path,
													temptlist,
													*push_scan_clauses,
													outer_plan);
			}
			else
			{
				ForeignServer *fs;
				ForeignDataWrapper *fdw;
				RelOptInfo *rel_child;
				Oid oid_child;

				if (IS_JOIN_REL(baserel))
				{
					rel_child = fdw_private->joinrel_child;
					/*
					 * Because reltarget created by GetForeignJoinPaths is modified in
					 * postgres core, we re-create it for child relation based on parent.
					 */
					rel_child->reltarget = copy_pathtarget(baserel->reltarget);
					rel_child->reltarget->exprs = list_copy(baserel->reltarget->exprs);
					oid_child = 0;
				}
				else
				{
					rel_child = pChildInfo->baserel;
					oid_child = pChildInfo->oid;
				}

				/*
				 * For non agg query or not push down agg case, do same thing
				 * as create_scan_plan() to generate target list
				 */
				fs = GetForeignServer(pChildInfo->server_oid);
				fdw = GetForeignDataWrapper(fs->fdwid);

				/* Add all columns of the table */
				if (IS_SIMPLE_REL(baserel) && ptemptlist != NULL)
					temptlist = list_copy(ptemptlist);
				else if (IS_JOIN_REL(baserel))
				{
					child_path = lfirst(list_head(rel_child->pathlist));
					temptlist = PG_build_path_tlist(pChildInfo->root, (Path *) child_path);
				}
				else
					temptlist = (List *) build_physical_tlist(pChildInfo->root, rel_child);

				/*
				 * Fill sortgrouprefs to temptlist. temptlist is non aggref
				 * target list, we should use non aggref pathtarget to apply.
				 */
				if (IS_UPPER_REL(baserel) && root->parse->groupClause != NULL)
				{
					apply_pathtarget_labeling_to_tlist(temptlist, fdw_private->rinfo.outerrel->reltarget);
				}

				/* Remove SPDURL from target lists if a child is not pgspider_fdw. */
				if (strcmp(fdw->fdwname, PGSPIDER_FDW_NAME) != 0 && IS_SIMPLE_REL(baserel))
				{
					temptlist = remove_spdurl_from_targets(temptlist, root);
					// fixme: update fdw_private->idx_url_tlist
				}

				/*
				 * We pass "best_path" to child GetForeignPlan. This is the
				 * path for parent fdw and not for child fdws. We should pass
				 * correct child path, but now we pass at least fdw_private of
				 * child path.
				 */
				child_path = lfirst(list_head(rel_child->pathlist));
				best_path->fdw_private = child_path->fdw_private;

				/*
				 * Check whether scan_clauses include SPDURL. If it includes
				 * SPDURL in WHERE clauses, then NOT pushdown all caluses.
				 */
				if (spd_checkurl_clauses(root, fdw_private->baserestrictinfo))
				{
					*push_scan_clauses = NULL;
				}
				else
				{
					*push_scan_clauses = fdw_private->baserestrictinfo;
				}
				fsplan = pChildInfo->fdwroutine->GetForeignPlan((PlannerInfo *) pChildInfo->root,
													rel_child,
													oid_child,
													(ForeignPath *) best_path,
													temptlist,
													*push_scan_clauses,
													outer_plan);
			}
		}
		PG_CATCH();
		{
			/*
			 * If fail to get foreign plan, then set
			 * fdw_private->child_table_alive to FALSE.
			 */
			pChildInfo->child_node_status = ServerStatusDead;
			elog(WARNING, "GetForeignPlan of child[%d] failed.", i);
			FlushErrorState();
			if (throwErrorIfDead)
			{
				ForeignServer *fs = GetForeignServer(pChildInfo->server_oid);
				spd_aliveError(fs);
			}
		}
		PG_END_TRY();

		/* For aggregation and can not pushdown fdw's */
		if (pChildInfo->pseudo_agg)
		{
			spd_CreateAggNodeForPseudoAgg(pChildInfo, fdw_private->groupby_has_spdurl,
				fdw_private->child_tlist, fsplan, root->parse->groupingSets);
		}

		pChildInfo->plan = (Plan *) fsplan;
	}
}

/**
 * spd_CompareTargetList
 *
 * Compare two given target lists.
 * Return true if it is same list.
 *
 * @param[in] List *tlist1 - target_list
 * @param[in] List *tlist2 - target_list
 *
 */
static bool
spd_CompareTargetList(List *tlist1, List *tlist2)
{
	ListCell   *lc1;
	ListCell   *lc2;

	if (list_length(tlist1) != list_length(tlist2))
		return false;

	forboth(lc1, tlist1, lc2, tlist2)
	{
		TargetEntry *ent1 = (TargetEntry *) lfirst(lc1);
		TargetEntry *ent2 = (TargetEntry *) lfirst(lc2);

		if (!equal(ent1->expr, ent2->expr))
			return false;
	}

	return true;
}

/*
 * spd_CreateGroupbyString
 *
 * Create "GROUP BY" string.
 *
 * @param[in] groupby_target Grouping targets
 * @return Created string
 */
static StringInfo
spd_CreateGroupbyString(List *groupby_target)
{
	ListCell   *lc;
	bool		first = true;
	StringInfo groupby_string = makeStringInfo();

	appendStringInfo(groupby_string, "GROUP BY ");
	foreach(lc, groupby_target)
	{
		int			cl = lfirst_int(lc);

		if (!first)
			appendStringInfoString(groupby_string, ", ");
		first = false;

		appendStringInfo(groupby_string, "col%d", cl);
	}

	return groupby_string;
}

/**
 * spd_GetForeignPlan
 *
 * Build foreign plan for each child tables using fdws.
 * saving each foreign plan into  base rel list
 *
 * @param[in] root - base planner infromation
 * @param[in] baserel - base relation option
 * @param[in] foreigntableid - Parent foreing table id
 * @param[in] ForeignPath *best_path - path of
 * @param[in] List *tlist - target_list
 * @param[in] List *scan_clauses where
 * @param[in] Plan *outer_plan outer_plan
 *
 */
static ForeignScan *
spd_GetForeignPlan(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid,
				   ForeignPath *best_path, List *tlist, List *scan_clauses,
				   Plan *outer_plan)
{
	int			i;
	SpdFdwPrivate *fdw_private = (SpdFdwPrivate *) baserel->fdw_private;
	Index		scan_relid;
	List	   *fdw_scan_tlist = NIL;	/* Need dummy tlist for pushdown case. */
	List	   *push_scan_clauses = scan_clauses;
	ListCell   *lc;
	ChildInfo  *childinfo;
	List	   *lfdw_private = NIL;
	List	   *ptemptlist;
	ForeignScan	*tmp;

	if (fdw_private == NULL)
		elog(ERROR, "fdw_private is NULL");

	fdw_scan_tlist = fdw_private->rinfo.grouped_tlist;

	/* Create "GROUP BY" string */
	if (root->parse->groupClause != NULL)
		fdw_private->groupby_string = spd_CreateGroupbyString(fdw_private->groupby_target);

	childinfo = fdw_private->childinfo;

	/* Prepare parent temp tlist */
	ptemptlist = spd_make_tlist_for_baserel(tlist, root, true);

	/* Create Foreign plans for each child with function pushdown. */
	spd_GetForeignPlansChild(root, baserel, best_path, ptemptlist, &push_scan_clauses,
							 outer_plan, childinfo);

	if (IS_SIMPLE_REL(baserel) || IS_JOIN_REL(baserel))
	{
		ForeignScan *fsplan = NULL;
		bool exist_pushdown_child = false;
		bool exist_non_pushdown_child = false;
		bool different_pushdown = false;
		List *child_fdw_scan_tlist = NIL;

		for (i = 0; i < fdw_private->node_num; i++)
		{
			fsplan = (ForeignScan *) childinfo[i].plan;

			/* By IN clause, childinfo has NULL fsplan, ignore it. */
			if (fsplan != NULL)
			{
				if (fsplan->fdw_scan_tlist == NULL)
					exist_non_pushdown_child = true;
				else if (exist_pushdown_child == false)
				{
					exist_pushdown_child = true;
					child_fdw_scan_tlist = fsplan->fdw_scan_tlist;
				}
				else if (child_fdw_scan_tlist != NULL)
				{
					if (!spd_CompareTargetList(child_fdw_scan_tlist, fsplan->fdw_scan_tlist))
						different_pushdown = true;
				}

				/* Check mix use of pushdown / non-pushdown */
				if (different_pushdown ||
					(fsplan->fdw_scan_tlist == NULL && exist_pushdown_child) ||
					(fsplan->fdw_scan_tlist != NULL && exist_non_pushdown_child))
				{
					/* Create Foreign plans for each child without function pushdown. */
					spd_GetForeignPlansChild(root, baserel, best_path, NULL, &push_scan_clauses,
											 outer_plan, childinfo);
					exist_pushdown_child = false;
					break;
				}
			}
		}
		if (exist_pushdown_child)
		{
			/*
			 * If pushdown function in the target list is casted to field selection, don't add FieldSelect node to the scan tlist.
			 * the core code will separate the record returned by casted pushdown function.
			 */
			if (is_field_selection(ptemptlist) && is_cast_function(child_fdw_scan_tlist))
			{
				/* prepare new temptlist without FieldSelect node */
				ptemptlist = spd_make_tlist_for_baserel(tlist, root, false);
			}

			if (spd_is_record_func(child_fdw_scan_tlist))
				fdw_private->record_function = true;

			if (IS_JOIN_REL(baserel))
			{
				/*
				 * For a join relation, the target list is same as that of child node.
				 * ptemptlist is unnecessary because it is created from base relation
				 * by spd_make_tlist_for_baserel().
				 */
				fdw_scan_tlist = child_fdw_scan_tlist;
			}
			else
				fdw_scan_tlist = spd_merge_tlist(child_fdw_scan_tlist, ptemptlist, root);
			fdw_private->idx_url_tlist = get_index_spdurl_from_targets(fdw_scan_tlist, root);
		}
		else
		{
			fdw_scan_tlist = NULL;
		}
		if (IS_JOIN_REL(baserel))
			scan_relid = 0;
		else
			scan_relid = baserel->relid;
	}
	else
	{
		/* Aggregate push down */
		scan_relid = 0;

		if (fdw_private->node_num == SPD_SINGLE_NODE)
		{
			ForeignScan *fsplan =  NULL;

			fsplan = (ForeignScan *) childinfo[0].plan;

			/* Update pushdown plan */
			fdw_scan_tlist = spd_update_scan_tlist(tlist, fsplan->fdw_scan_tlist, root);
			fdw_private->child_tlist = list_copy(fsplan->fdw_scan_tlist);
			fdw_private->child_comp_tlist = list_copy(fdw_scan_tlist);

			if (spd_is_record_func(fdw_scan_tlist))
				fdw_private->record_function = true;

			/* Update new index of __spd_url if any */
			if (fdw_private->groupby_has_spdurl)
				fdw_private->idx_url_tlist = get_index_spdurl_from_targets(fdw_scan_tlist, root);
		}
	}

	/* Calculate which condition should be filtered in core: when baserel is simple rel or when there is pseudoconstant (Example: WHERE false) */
	scan_clauses = NIL;
	if (fdw_private->baserestrictinfo)
	{
		/*
		 * In this case, PGSpider should filter baserestrictinfo because
		 * these are not passed to child fdw because of SPDURL.
		 */
		foreach(lc, fdw_private->baserestrictinfo)
		{
			RestrictInfo *ri = lfirst_node(RestrictInfo, lc);

			/* When there is pseudoconstant, need to filter in core (Example: WHERE false) */
			if ((IS_SIMPLE_REL(baserel) && !push_scan_clauses) || ri->pseudoconstant)
			{
				scan_clauses = lappend(scan_clauses, ri->clause);
				if (fdw_scan_tlist != NIL)
					fdw_scan_tlist = add_to_flat_tlist(fdw_scan_tlist,
												   pull_var_clause((Node *) ri->clause,
																   PVC_RECURSE_PLACEHOLDERS));
			}
		}
	}

	/*
	 * We collect local conditions which are pushed down by child node
	 * in order to make postgresql core execute that filter.
	 */
	if (IS_SIMPLE_REL(baserel) || IS_JOIN_REL(baserel))
	{
		for (i = 0; i < fdw_private->node_num; i++)
		{
			ChildInfo *pChildInfo = &fdw_private->childinfo[i];
			if (!pChildInfo->plan)
				continue;

			foreach(lc, pChildInfo->plan->qual)
			{
				Expr	   *expr = (Expr *) lfirst(lc);

				scan_clauses = list_append_unique_ptr(scan_clauses, expr);

				if (fdw_scan_tlist != NIL)
					fdw_scan_tlist = add_to_flat_tlist(fdw_scan_tlist,
												   pull_var_clause((Node *) expr,
																   PVC_RECURSE_PLACEHOLDERS));
			}
		}
		if (fdw_scan_tlist != NIL)
			fdw_private->idx_url_tlist = get_index_spdurl_from_targets(fdw_scan_tlist, root);
	}
	else
	{
		/*
		 * For single node, in case of grouping with having, we need to update having quals to scan clauses
		 */
		if (fdw_private->node_num == SPD_SINGLE_NODE && fdw_private->has_having_quals)
		{
			scan_clauses= extract_actual_clauses(fdw_private->rinfo.remote_conds, false);
			if (fdw_scan_tlist != NIL)
			{
				foreach(lc, scan_clauses)
				{
					Expr	   *expr = (Expr *) lfirst(lc);

					fdw_scan_tlist = add_to_flat_tlist(fdw_scan_tlist,
														pull_var_clause((Node *) expr,
																		PVC_RECURSE_AGGREGATES));
				}
			}
		}
	}
	/* for debug */
	if (log_min_messages <= DEBUG1 || client_min_messages <= DEBUG1)
		print_mapping_tlist(fdw_private->mapping_tlist, DEBUG1);

	/*
	 * Serialize fdw_private's members to a list. The list to be placed in the
	 * ForeignScan plan node, where they will be available to be deserialized
	 * at execution time The list must be represented in a form that
	 * copyObject knows how to copy.
	 */
	lfdw_private = spd_SerializeSpdFdwPrivate(fdw_private);
	tmp = make_foreignscan(tlist,
							scan_clauses,	/* scan_clauses, */
							/* NULL, */
							scan_relid,
							NIL,
							lfdw_private,
							fdw_scan_tlist,
							NIL,
							outer_plan);
	return tmp;

}

/**
 * Print error if any child is dead.
 *
 * @param[in] childnums The number of child nodes
 * @param[in] childinfo Child information
 */
static void
spd_PrintError(int childnums, ChildInfo * childinfo)
{
	int			i;
	ForeignServer *fs;

	for (i = 0; i < childnums; i++)
	{
		if (childinfo[i].child_node_status == ServerStatusDead)
		{
			fs = GetForeignServer(childinfo[i].server_oid);
			elog(WARNING, "Can not get data from %s", fs->servername);
		}
	}
}

/**
 * End all child node thread.
 *
 * @param[in] node
 */
static void
spd_end_child_node_thread(ForeignScanState *node, bool is_abort)
{
	int						node_incr;
	int						rtn;
	ForeignScanThreadInfo	*fssThrdInfo = node->spd_fsstate;
	SpdFdwPrivate 			*fdw_private;

	if (!fssThrdInfo)
		return;

	fdw_private = (SpdFdwPrivate *) fssThrdInfo[0].private;
	if (!fdw_private)
		return;

	/* Print error nodes. */
	for (node_incr = 0; node_incr < fdw_private->nThreads; node_incr++)
	{
		if (fssThrdInfo[node_incr].state == SPD_FS_STATE_ERROR)
		{
			fdw_private->childinfo[fssThrdInfo[node_incr].childInfoIndex].child_node_status = ServerStatusDead;
		}
	}
	if (isPrintError)
		spd_PrintError(fdw_private->node_num, fdw_private->childinfo);

	if (!fdw_private->is_explain)
	{
		/* In case of abort transaction, we don't need to drop temp table, it will control by spi module. */
		if (fdw_private->temp_table_name != NULL && !is_abort)
		{
			spd_execute_local_query(psprintf("DROP TABLE IF EXISTS %s", fdw_private->temp_table_name), &fdw_private->scan_mutex);
		}
		for (node_incr = 0; node_incr < fdw_private->nThreads; node_incr++)
		{
			fssThrdInfo[node_incr].requestEndScan = true;
			/* Cleanup the thread-local structures. */
			rtn = pthread_join(fdw_private->foreign_scan_threads[node_incr], NULL);
			if (rtn != 0)
				elog(WARNING, "Failed to join thread in EndForeignScan of thread[%d]. Returned %d.", node_incr, rtn);
		}
	}
}

/**
 * Callback function to be called before abort transaction.
 *
 * @param[in] arg ForeignScanState
 */
static void
spd_abort_transaction_callback(void *arg)
{
	/* Reset child node offset to 0 for new query execution. */
	g_node_offset = 0;

	AssertArg(arg);

	if (IsA(arg, ForeignScanState))
	{
		spd_end_child_node_thread((ForeignScanState *)arg, true);
		/*
		 * Call this function to allow backend to check memory context size as usual
		 * because the child threads finished running.
		 */
		skip_memory_checking(false);
	}
}

/**
 * Callback function to be called when context reset/delete.
 * Reset error context stack and re-enable register reset
 * callback flag and unregister all abort callback.
 *
 * @param[in] arg
 */
static void
spd_reset_callback(void *arg)
{
	registered_reset_callback = false;
	AtFinishTransaction();
}

/**
 * Register a function to be called when context reset/delete.
 *
 * @param[in] query_context MemoryContext
 */
static void
spd_register_reset_callback(MemoryContext query_context)
{
	if (!registered_reset_callback)
	{
		MemoryContextCallback *cb = MemoryContextAlloc(query_context, sizeof(MemoryContextCallback));

		registered_reset_callback = true;

		cb->arg = NULL;
		cb->func = spd_reset_callback;
		MemoryContextRegisterResetCallback(query_context, cb);
	}
}

/*
 * spd_CreateTupleDescAndSlotForGroupBySpdurl
 *
 * In case of Aggregation, a temptable will be created according to the child compress list.
 * This function create a slot with adding for SPDURL column.
 *
 * @param[in,out] fdw_private
 */
static void
spd_CreateTupleDescAndSlotForGroupBySpdurl(SpdFdwPrivate *fdw_private)
{
	TupleDesc	tupledesc;
	ListCell* lc;
	int 		i = 0;

	/*
	 * When we add SPDURL back to parent node, we need to create tuple
	 * descriptor for parent slot according to child comp tlist.
	 */
	tupledesc = CreateTemplateTupleDesc(list_length(fdw_private->child_comp_tlist));
	foreach(lc, fdw_private->child_comp_tlist)
	{
		TargetEntry* ent = (TargetEntry*)lfirst(lc);

		TupleDescInitEntry(tupledesc, i + 1, NULL, exprType((Node*)ent->expr), -1, 0);
		i++;
	}

	/* Construct TupleDesc, and assign a local typmod. */
	tupledesc = BlessTupleDesc(tupledesc);
	fdw_private->child_comp_tupdesc = CreateTupleDescCopy(tupledesc);

	/* Init temporary slot for adding SPDURL back. */
	fdw_private->child_comp_slot = MakeSingleTupleTableSlot(CreateTupleDescCopy(fdw_private->child_comp_tupdesc), &TTSOpsHeapTuple);
}

/*
 * spd_CreateChildFsstate
 *
 * Create a child foreign scan state.
 *
 * @param[in] node Parent node
 * @param[in] pChildInfo Child information
 * @param[in] eflags A flag fiven by BeginForeignScan
 * @param[in] rtable List of range table entry
 * @param[in] rd Relation of child table
 * @return Created foreign scan state
 */
static ForeignScanState *
spd_CreateChildFsstate(ForeignScanState *node, ChildInfo *pChildInfo, int eflags, List *rtable, Relation rd)
{
	ForeignScanState *fsstate_child;
	ForeignScan *fsplan_child;
	EState *estate = node->ss.ps.state;
	int			natts;

	fsstate_child = makeNode(ForeignScanState);
	memcpy(&fsstate_child->ss, &node->ss, sizeof(ScanState));
	/* Copy Agg plan when psuedo aggregation case. */
	if (pChildInfo->pseudo_agg)
	{
		/* Not push down aggregate to child fdw */
		fsplan_child = (ForeignScan *) copyObject(pChildInfo->plan);
	}
	else
	{
		/* Push down case */
		fsstate_child->ss = node->ss;
		fsplan_child = (ForeignScan *) copyObject(node->ss.ps.plan);
	}
	fsplan_child->scan.scanrelid = ((ForeignScan *)pChildInfo->plan)->scan.scanrelid;
	fsplan_child->fdw_private = ((ForeignScan *) pChildInfo->plan)->fdw_private;
	fsplan_child->fdw_exprs = ((ForeignScan *) pChildInfo->plan)->fdw_exprs;
	fsstate_child->ss.ps.plan = (Plan *) fsplan_child;

	/* Create and initialize EState. */
	fsstate_child->ss.ps.state = CreateExecutorState();
	fsstate_child->ss.ps.state->es_top_eflags = eflags;
	fsstate_child->ss.ps.ps_ExprContext = CreateExprContext(estate);

	/* Init external params. */
	fsstate_child->ss.ps.state->es_param_list_info =
		copyParamList(estate->es_param_list_info);

	/*
	* Init range table, in which we use range table array for exec_rt_fetch() because it is faster than rt_fetch().
	*/
	ExecInitRangeTable(fsstate_child->ss.ps.state, rtable);
	fsstate_child->ss.ps.state->es_plannedstmt = copyObject(node->ss.ps.state->es_plannedstmt);
	fsstate_child->ss.ps.state->es_plannedstmt->planTree = copyObject(fsstate_child->ss.ps.plan);

	fsstate_child->ss.ss_currentRelation = rd;

	natts = fsstate_child->ss.ss_ScanTupleSlot->tts_tupleDescriptor->natts;

	fsstate_child->ss.ss_ScanTupleSlot->tts_mcxt = node->ss.ss_ScanTupleSlot->tts_mcxt;
	fsstate_child->ss.ss_ScanTupleSlot->tts_values = (Datum *)
		MemoryContextAlloc(node->ss.ss_ScanTupleSlot->tts_mcxt, natts * sizeof(Datum));
	fsstate_child->ss.ss_ScanTupleSlot->tts_isnull = (bool *)
		MemoryContextAlloc(node->ss.ss_ScanTupleSlot->tts_mcxt, natts * sizeof(bool));

	return fsstate_child;
}

/*
 * spd_ConfigureChildMemoryContext
 *
 * @param[in,out] fssThrdInfo Thread information
 * @param[in] nodeId Node ID. This is used for determining the position of fssThrdInfo and list_thread_top_contexts.
 * @param[in] es_query_cxt Query context of parent node
 */
static void
spd_ConfigureChildMemoryContext(ForeignScanThreadInfo *fssThrdInfo, int nodeId, MemoryContext es_query_cxt)
{
	ForeignScanThreadInfo *pFssThrdInfo = &fssThrdInfo[nodeId];

	/* Allocate top memory context for each thread to avoid race condition */
	if (g_node_offset + nodeId >= list_length(list_thread_top_contexts))
	{
		MemoryContext oldcontext;

		pFssThrdInfo->threadTopMemoryContext = AllocSetContextCreate(TopMemoryContext,
			"thread top memory context",
			ALLOCSET_DEFAULT_MINSIZE,
			ALLOCSET_DEFAULT_INITSIZE,
			ALLOCSET_DEFAULT_MAXSIZE);

		oldcontext = MemoryContextSwitchTo(TopMemoryContext);
		list_thread_top_contexts = lappend(list_thread_top_contexts, pFssThrdInfo->threadTopMemoryContext);
		MemoryContextSwitchTo(oldcontext);
	}
	else
	{
		pFssThrdInfo->threadTopMemoryContext = (MemoryContext) list_nth(list_thread_top_contexts, g_node_offset + nodeId);
	}

	/*
	* memory context tree: paraent es_query_cxt -> threadMemoryContext ->
	* child es_query_cxt -> child expr context
	*/
	pFssThrdInfo->threadMemoryContext =
		AllocSetContextCreate(es_query_cxt,
			"thread memory context",
			ALLOCSET_DEFAULT_MINSIZE,
			ALLOCSET_DEFAULT_INITSIZE,
			ALLOCSET_DEFAULT_MAXSIZE);

	pFssThrdInfo->fsstate->ss.ps.state->es_query_cxt =
		AllocSetContextCreate(pFssThrdInfo->threadMemoryContext,
			"thread es_query_cxt",
			ALLOCSET_DEFAULT_MINSIZE,
			ALLOCSET_DEFAULT_INITSIZE,
			ALLOCSET_DEFAULT_MAXSIZE);
}

/**
 * Create tuple table slot for child node and initialize queue.
 *
 * @param[in] node Foreign scan state of parent
 * @param[in] pChildInfo Child information
 * @param[in] fdw_private
 * @param[in] tupledesc_agg Tuple descriptor of aggregate
 * @param[in,out] pFssThrdInfo Slot and queue are created here
 */
static void
spd_makeChildTupleSlotAndQueue(ForeignScanState *node, ChildInfo *pChildInfo,
							   SpdFdwPrivate *fdw_private, TupleDesc tupledesc_agg,
							   ForeignScanThreadInfo *pFssThrdInfo)
{
	TupleDesc	tupledesc;
	TupleDesc	tupledesc_child;
	bool		skiplast = false;
	MemoryContext oldContext;

	if (fdw_private->agg_query)
	{
		/* Create child descriptor using child_tlist. */
		ListCell *lc;

		tupledesc = tupledesc_agg;

		if (pChildInfo->pseudo_agg)
		{
			/*
			 * Create tuple slot based on *child* ForeignScan plan target
			 * list. This tuple is for ExecAgg and different from one used
			 * in queue.
			 */
			tupledesc_child = ExecCleanTypeFromTL(pFssThrdInfo->fsstate->ss.ps.plan->targetlist);
		}
		else
		{
			/*
			 * If child plan has local conditions that applied for HAVING clause,
			 * then we need to create more child slots for aggreate targets that
			 * extracted from these local conditions.
			 */
			if (pChildInfo->plan->qual)
			{
				List *child_tlist = list_copy(fdw_private->child_tlist);
				List *aggvars = NIL;

				foreach(lc, pChildInfo->plan->qual)
				{
					Expr *clause = (Expr*)lfirst(lc);

					aggvars = list_concat(aggvars, pull_var_clause((Node*)clause, PVC_INCLUDE_AGGREGATES));
				}
				foreach(lc, aggvars)
				{
					Expr *expr = (Expr*)lfirst(lc);

					/*
					 * If aggregates within local conditions are not safe to push down by child FDW,
					 * then we add aggregates to child target list.
					 */
					if (IsA(expr, Aggref))
					{
						child_tlist = add_to_flat_tlist(child_tlist, list_make1(expr));
					}
				}

				/* Create child slots based on child target list. */
				tupledesc_child = ExecCleanTypeFromTL(child_tlist);
			}
			else
				tupledesc_child = CreateTupleDescCopy(tupledesc);
		}

	}
	else
	{
		/*
		 * Create tuple slot based on *parent* ForeignScan tuple
		 * descriptor.
		 */

		tupledesc = CreateTupleDescCopy(node->ss.ss_ScanTupleSlot->tts_tupleDescriptor);

		tupledesc_child = tupledesc;
	}

	oldContext = MemoryContextSwitchTo(pFssThrdInfo->threadMemoryContext);
	pFssThrdInfo->fsstate->ss.ss_ScanTupleSlot =
		MakeSingleTupleTableSlot(tupledesc_child, node->ss.ss_ScanTupleSlot->tts_ops);

	/*
	 * For non-aggregate query, tupledesc we use for a queue has __spd_url
	 * column at the last because it has all table columns. This is
	 * inconsistent with the child tuple except for pgspider_fdw and cause
	 * problems when copying to a queue. To avoid it, we will skip copy of
	 * the last element of tuple. Execeptions are target list pushdown
	 * case where as in aggregate query case, tuple descriptor corresponds
	 * to a target list from which spd_url is removed.
	 */
	if (!fdw_private->agg_query &&
		strcmp(pFssThrdInfo->fdw->fdwname, PGSPIDER_FDW_NAME) != 0)
		skiplast = true;

	if (fdw_private->groupby_has_spdurl)
		spd_queue_init(&pFssThrdInfo->tupleQueue, fdw_private->child_comp_tupdesc, node->ss.ss_ScanTupleSlot->tts_ops, skiplast);
	else
		spd_queue_init(&pFssThrdInfo->tupleQueue, tupledesc, node->ss.ss_ScanTupleSlot->tts_ops, skiplast);
	MemoryContextSwitchTo(oldContext);
}

/*
 * spd_setThreadInfo
 *
 * Set member variables of ForeignScanThreadInfo.
 *
 * @param[in] node Foreign scan state of parent
 * @param[in] fdw_private
 * @param[in] pChildInfo Child information
 * @param[in] fsstate_child Foreign scan state of child node
 * @param[in] tupledesc_agg Tuple descriptor created by spd_CreateAggTupleDesc()
 * @param[in] eflags A flag fiven by BeginForeignScan
 * @param[out] pFssThrdInfo Variables in this structure are set
 */
static void
spd_setThreadInfo(ForeignScanState *node, SpdFdwPrivate *fdw_private, ChildInfo *pChildInfo,
				  ForeignScanState *fsstate_child, TupleDesc tupledesc_agg, int eflags,
				  ForeignScanThreadInfo *pFssThrdInfo)
{
	pFssThrdInfo->fsstate = fsstate_child;

	pFssThrdInfo->eflags = eflags;
	pFssThrdInfo->requestEndScan = false;
	pFssThrdInfo->requestRescan = false;

	/*
	* If query has no parameter, it can be executed immediately for improving the performance.
	* If query has parameter, sub-plan needs to be initialized, so it needs to wait the core engine
	* initializes the sub-plan.
	*/
	if (pChildInfo->pseudo_agg)
	{
		/* Not push down aggregate to child fdw */
		pFssThrdInfo->requestStartScan = (node->ss.ps.state->es_subplanstates == NIL);
	}
	else
	{
		/* Push down case */
		ForeignScan *fsplan_child = (ForeignScan*) pFssThrdInfo->fsstate->ss.ps.plan;
		pFssThrdInfo->requestStartScan = (fsplan_child->fdw_exprs == NIL);
	}

	pFssThrdInfo->serverId = pChildInfo->server_oid;
	pFssThrdInfo->fdwroutine = GetFdwRoutineByServerId(pChildInfo->server_oid);
	/*
	* GetForeignServer and GetForeignDataWrapper are slow. So we will
	* cache here.
	*/
	pFssThrdInfo->foreignServer = GetForeignServer(pChildInfo->server_oid);
	pFssThrdInfo->fdw = GetForeignDataWrapper(pFssThrdInfo->foreignServer->fdwid);

	pFssThrdInfo->thrd_ResourceOwner =
		ResourceOwnerCreate(CurrentResourceOwner, "thread resource owner");
	pFssThrdInfo->private = fdw_private;
}

/*
 * spd_CreateAggTupleDesc
 *
 * Create tuple descriptor for aggregation.
 *
 * @param[in] child_tlist Target list of child node
 * @@return Created tuple descriptor
 */
static TupleDesc
spd_CreateAggTupleDesc(List *child_tlist)
{
	TupleDesc tupledesc_agg;
	int			child_attr = 0; /* attribute number of child */
	ListCell* lc;

	/* Create child descriptor using child_tlist. */
	TupleDesc	desc = CreateTemplateTupleDesc(list_length(child_tlist));

	foreach(lc, child_tlist)
	{
		TargetEntry *ent = (TargetEntry*)lfirst(lc);

		TupleDescInitEntry(desc, child_attr + 1, NULL, exprType((Node*)ent->expr), -1, 0);
		child_attr++;
	}
	/* Construct TupleDesc and assign a local typmod. */
	tupledesc_agg = BlessTupleDesc(desc);

	return tupledesc_agg;
}

/*
 * sdp_CreateChildThreads
 *
 * Launch child threads and wait for child threads initialization.
 *
 * @param[in] fdw_private
 * @param[in] fssThrdInfoChild Child thread information
 * @param[in] fssThrdInfo Parent thread information
 */
static void
sdp_CreateChildThreads(SpdFdwPrivate *fdw_private, ForeignScanThreadInfo *fssThrdInfoChild, ForeignScanThreadInfo *fssThrdInfo)
{
	int	i;
	int  nThreads = fdw_private->nThreads;
	ForeignScanThreadArg *fssThrdChildInfo;

	fssThrdChildInfo = (ForeignScanThreadArg *) palloc0(sizeof(ForeignScanThreadArg) * fdw_private->node_num);

	for (i = 0; i < nThreads; i++)
	{
		int			thread_create_err;

		fssThrdChildInfo[i].mainThreadsInfo = fssThrdInfo;
		fssThrdChildInfo[i].childThreadsInfo = &fssThrdInfoChild[i];
		thread_create_err =
			pthread_create(&fdw_private->foreign_scan_threads[i],
				NULL,
				&spd_ForeignScan_thread,
				(void *) &fssThrdChildInfo[i]);
		if (thread_create_err != 0)
		{
			ereport(ERROR, (errmsg("Cannot create thread! error=%d",
				thread_create_err)));
		}
	}


	/* Wait for state change. */
	for (i = 0; i < nThreads; i++)
	{
		while (fssThrdInfoChild[i].state == SPD_FS_STATE_INIT)
		{
			pthread_yield();
		}
	}
}

/**
 * Main thread setup ForeignScanState for child fdw, including
 * tuple descriptor.
 * First, get all child's table information.
 * Next, set information and create child's thread.
 *
 * @param[in] node Foreign scan state of main thread
 * @param[in] eflags
 */
static void
spd_BeginForeignScan(ForeignScanState *node, int eflags)
{
	ForeignScan *fsplan = (ForeignScan *) node->ss.ps.plan;
	ForeignScanThreadInfo *fssThrdInfo;
	EState	   *estate = node->ss.ps.state;
	SpdFdwPrivate *fdw_private;
	int			node_incr;		/* node_incr is variable of number of
								 * fssThrdInfo. */
	ChildInfo  *childinfo;
	int			i;
	Query	   *query;
	TupleDesc	tupledesc_agg = NULL;

	/*
	 * Register callback to query memory context to reset normalize id hash
	 * table at the end of the query.
	 */
	hash_register_reset_callback(estate->es_query_cxt);
	node->spd_fsstate = NULL;

	/* Deserialize fdw_private list to SpdFdwPrivate object. */
	fdw_private = spd_DeserializeSpdFdwPrivate(fsplan->fdw_private);

	/*
	 * Create tuple descriptor and tuple table slot which are used if GROUP BY has SPDURL.
	 */
	if (fdw_private->groupby_has_spdurl)
		spd_CreateTupleDescAndSlotForGroupBySpdurl(fdw_private);

	/* Create temporary context */
	fdw_private->es_query_cxt = estate->es_query_cxt;

	/*
	 * Not return from this function unlike usual fdw BeginForeignScan
	 * implementation because we need to create ForeignScanState for child
	 * fdws. It is assigned to fssThrdInfo[node_incr].fsstate.
	 */
	if (eflags & EXEC_FLAG_EXPLAIN_ONLY)
		fdw_private->is_explain = true;

	/* Type of query to be used for computing intermediate results. */
#ifdef GETPROGRESS_ENABLED
	if (fdw_private->agg_query)
		node->ss.ps.state->es_progressState->ps_aggQuery = true;
	else
		node->ss.ps.state->es_progressState->ps_aggQuery = false;
	if (getResultFlag)
		return;
	/* Supporting for Progress */
	node->ss.ps.state->es_progressState->ps_totalRows = 0;
	node->ss.ps.state->es_progressState->ps_fetchedRows = 0;
#endif

	node->ss.ps.state->agg_query = 0;
	/* Get all the foreign nodes from conf file */
	fssThrdInfo = (ForeignScanThreadInfo *) palloc0(sizeof(ForeignScanThreadInfo) * fdw_private->node_num);
	node->spd_fsstate = fssThrdInfo;

	node_incr = 0;
	childinfo = fdw_private->childinfo;

	/* Create tuple descriptor for aggregation. */
	if (fdw_private->agg_query)
		tupledesc_agg = spd_CreateAggTupleDesc(fdw_private->child_tlist);

	for (i = 0; i < fdw_private->node_num; i++)
	{
		RangeTblEntry *rte;
		Relation	rd;
		ChildInfo *pChildInfo = &fdw_private->childinfo[i];
		ForeignScanState *fsstate_child;
		int	k;

		/*
		 * Check child table node is dead or alive. Execute(Create child
		 * thread) only aliving nodes. So, childinfo[i] and fssThrdInfo[i]
		 * do not correspond.
		 */
		if (pChildInfo->child_node_status != ServerStatusAlive)
		{
			/* Don't set thread information of dead node. */
			continue;
		}

#ifdef GETPROGRESS_ENABLED
		if (getResultFlag)
			break;
#endif

		/* This should be a new RTE list. coming from dummy rtable */
		query = ((PlannerInfo *) childinfo[i].root)->parse;

		rte = lfirst_node(RangeTblEntry, list_head(query->rtable));

		if (query->rtable->length != estate->es_range_table->length)
			for (k = query->rtable->length; k < estate->es_range_table->length; k++)
				query->rtable = lappend(query->rtable, rte);

		/* Get current relation ID from current server oid. */
		rd = RelationIdGetRelation(pChildInfo->oid);

		/*
		 * For prepared statement, dummy root is not created at the next execution, so we need to lock relation again.
		 * We don't need unlock relation because lock will be released at transaction end.
		 * https://www.postgresql.org/docs/12/sql-lock.html
		 */
		if (!CheckRelationLockedByMe(rd, AccessShareLock, true))
			LockRelationOid(pChildInfo->oid, AccessShareLock);

		/* Create child fsstate. */
		fsstate_child = spd_CreateChildFsstate(node, pChildInfo, eflags, query->rtable, rd);

		/* Set member variables in ForeignScanThreadInfo. */
		spd_setThreadInfo(node, fdw_private, pChildInfo, fsstate_child, tupledesc_agg,
						  eflags, &fssThrdInfo[node_incr]);

		/* Settings of memory context for child node. */
		spd_ConfigureChildMemoryContext(fssThrdInfo, node_incr, estate->es_query_cxt);

		/* Create child tuple slot and initialize queue. */
		spd_makeChildTupleSlotAndQueue(node, pChildInfo, fdw_private, tupledesc_agg, &fssThrdInfo[node_incr]);

		/* We save correspondence between fssThrdInfo and childinfo. */
		fssThrdInfo[node_incr].childInfoIndex = i;
		childinfo[i].index_threadinfo = node_incr;

		/*
		 * For explain case, call BeginForeignScan because some
		 * fdws(ex:mysql_fdw) requires BeginForeignScan is already called when
		 * ExplainForeignScan is called. For non explain case, child threads
		 * call BeginForeignScan.
		 */
		if (eflags & EXEC_FLAG_EXPLAIN_ONLY)
		{
			fssThrdInfo[node_incr].fdwroutine->BeginForeignScan(fssThrdInfo[node_incr].fsstate,
																eflags);
		}

		node_incr++;
	}

	fdw_private->nThreads = node_incr;

	/* Increasing node offset by number of child nodes. */
	g_node_offset += fdw_private->node_num;

	/* Skip thread creation in explain case. */
	if (eflags & EXEC_FLAG_EXPLAIN_ONLY)
	{
		return;
	}

	/*
	 * PGSpider needs to notify all childs node thread to quit
	 * before memory context of thread is release and avoid child
	 * node thread access to Transaction State. We register abort
	 * transaction call back for each node. In case error, backend
	 * call AbortTransaction, we will call abort transaction callback
	 * to quit all threads avoid thread access to free memory zone
	 * and Transaction State.
	 */
	RegisterAbortTransactionCallback(spd_abort_transaction_callback, (void *)node);

	/*
	 * We register ResetCallback for es_query_cxt to unregister
	 * abort transaction call back when finish transaction.
	 */
	spd_register_reset_callback(estate->es_query_cxt);

	/*
	 * Call this function to prevent backend from checking memory context
	 * while child thread is running.
	 */
	skip_memory_checking(true);

	/* Launch child threads. */
	sdp_CreateChildThreads(fdw_private, fssThrdInfo, (ForeignScanThreadInfo*) node->spd_fsstate);

	fdw_private->isFirst = true;
	fdw_private->startNodeId = 0;
	return;
}

/**
 * spd_execute_local_query
 *
 * Execute a query for local pgspider (especially CREATE/DROP temp table).
 * This is called by aggregate Push-down case.
 *
 * @param[in] query SQL to be executed
 * @param[in] scan_mutex Mutex
 */
static void
spd_execute_local_query(char *query, pthread_rwlock_t *scan_mutex)
{
	int			ret;

	SPD_WRITE_LOCK_TRY(scan_mutex);
	ret = SPI_connect();
	if (ret < 0)
		elog(ERROR, "SPI connect failure - returned %d", ret);
	ret = SPI_exec(query, 1);
	elog(DEBUG1, "execute temp table DDL: %s", query);
	if (ret != SPI_OK_UTILITY)
		elog(ERROR, "execute spi CREATE TEMP TABLE failed %d", ret);
	SPI_finish();
	SPD_RWUNLOCK_CATCH(scan_mutex);
}

/**
 * spd_insert_into_temp_table
 *
 * Insert results of child node into temp table.
 * This is called by aggregate Push-down case.
 *
 * @param[in] slot
 * @param[in] node
 * @param[in,out] fdw_private
 */
static void
spd_insert_into_temp_table(TupleTableSlot *slot, ForeignScanState *node, SpdFdwPrivate *fdw_private)
{
	int			ret;
	int			i;
	int			colid = 0;
	bool		isfirst = true;
	StringInfo	sql = makeStringInfo();
	List	   *mapping_tlist;
	ListCell   *lc;
	StringInfo	debugValues = makeStringInfo();

	/* For execute query */
	Oid* argtypes = palloc0(sizeof(Oid));
	Datum* values = palloc0(sizeof(Datum));
	char* nulls = palloc0(sizeof(char));

	SPD_WRITE_LOCK_TRY(&fdw_private->scan_mutex);
	ret = SPI_connect();
	if (ret < 0)
		elog(ERROR, "SPI_connect failed. Returned %d.", ret);

	appendStringInfo(sql, "INSERT INTO %s VALUES( ", fdw_private->temp_table_name);
	colid = 0;
	mapping_tlist = fdw_private->mapping_tlist;
	foreach(lc, mapping_tlist)
	{
		Extractcells *extcells = (Extractcells *) lfirst(lc);
		ListCell	 *extlc;

		foreach(extlc, extcells->cells)
		{
			Mappingcells *mapcels = (Mappingcells *) lfirst(extlc);
			Datum		attr;
			char		*value;
			bool		isnull;
			Oid			typoutput;
			bool		typisvarlena;
			int			child_typid;

			for (i = 0; i < MAX_SPLIT_NUM; i++)
			{
				Form_pg_attribute sattr = TupleDescAttr(slot->tts_tupleDescriptor, colid);

				if (colid != mapcels->mapping[i])
					continue;

				/* Realloc memory when there are more than 1 column */
				if (colid > 0)
				{
					argtypes = repalloc(argtypes, (colid + 1) * sizeof(Oid));
					values = repalloc(values, (colid + 1) * sizeof(Datum));
					nulls = repalloc(nulls, (colid + 1) * sizeof(char));
				}
				if (isfirst)
					isfirst = false;
				else
					appendStringInfo(sql, ",");
				/* Append place holder */
				appendStringInfo(sql, "$%d", colid + 1);

				getTypeOutputInfo(sattr->atttypid, &typoutput, &typisvarlena);
				child_typid = exprType((Node *) ((TargetEntry *) list_nth(fdw_private->child_comp_tlist, colid))->expr);

				/*
				* SPI_execute_with_args receives a nulls array.
				* If the value is not null, value of entry will be ' '.
				* If the value is null, value of entry will be 'n'.
				*/
				nulls[colid] = ' ';

				/* Set data type. */
				argtypes[colid] = child_typid;

				/* Set value. */
				attr = slot_getattr(slot, mapcels->mapping[i] + 1, &isnull);
				if (isnull)
				{
					nulls[colid] = 'n';
					colid++;
					continue;
				}
				value = OidOutputFunctionCall(typoutput, attr);
				appendStringInfo(debugValues, "%s, ", value != NULL?value:"");
				/* Not null */
				values[colid] = attr;
				/* Set data for special data */
				if (sattr->atttypid == UNKNOWNOID)
				{
					argtypes[colid] = TEXTOID;
					if (!isnull)
						values[colid] = CStringGetTextDatum(DatumGetCString(values[colid]));
				}
				else if (!isnull)
				{
					int16 typLen;
					bool  typByVal;

					/* Copy datum to current context. */
					get_typlenbyval(sattr->atttypid, &typLen, &typByVal);
					if (!typByVal) {
						if (typisvarlena) {
							/* Need to copy data. */
							values[colid] = PointerGetDatum(PG_DETOAST_DATUM_COPY(values[colid]));
						}
						else
						{
							values[colid] = datumCopy(values[colid], typByVal, typLen);
						}
					}
				}
				colid++;
			}
		}
	}
	appendStringInfo(sql, ")");
	elog(DEBUG1, "Inserting into temp table: %s, values: %s", sql->data, debugValues->data);
	ret = SPI_execute_with_args(sql->data, colid, argtypes, values, nulls, false, 1);
	if (ret != SPI_OK_INSERT)
	{
		SPI_finish();
		elog(ERROR, "Failed to insert into temp table. Retrned %d. SQL is %s.", ret, sql->data);
	}

	SPI_finish();

	SPD_RWUNLOCK_CATCH(&fdw_private->scan_mutex);
}

/**
 * datum_is_converted
 *
 * This function is used to convert datum value to expected data type (data type of column of temp table)
 * when data type of column of temp table is different from returned data type of query.
 * If this function cannot convert or no need to convert, return false.
 *
 * @param[in] original_type
 * @param[in] original_value
 * @param[in] expected_type
 * @param[in,out] expected_value
 */
static bool
datum_is_converted(Oid original_type, Datum original_value, Oid expected_type, Datum *expected_value, bool is_truncated)
{
	Datum value;
	PGFunction conversion_func = NULL;
	bool unexpected = false;
	bool rounded_up = false;

	switch (original_type)
	{
		case NUMERICOID:
			if (expected_type == INT8OID)
			{
				conversion_func = numeric_int8;

				if (is_truncated)
				{
					/* Check if the value will be rounded up by numeric_int8. */
					char *tmp;
					double tmp_dbl_val;

					tmp = DatumGetCString(DirectFunctionCall1(numeric_out, original_value));
					tmp_dbl_val = strtod(tmp, NULL);
					if ((tmp_dbl_val - trunc(tmp_dbl_val)) >= 0.5)
					{
						rounded_up = true;
					}
				}
			}
			else
				unexpected = true;
			break;
		case FLOAT8OID:
			if (expected_type == FLOAT4OID)
				conversion_func = dtof;
			else if (expected_type == NUMERICOID)
				conversion_func = float8_numeric;
			else
				unexpected = true;
			break;
		case INT8OID:
			if (expected_type == INT4OID)
				conversion_func = int84;
			else
				unexpected = true;
			break;
		case TEXTARRAYOID:
			if (expected_type == TIMESTAMPARRAYOID)
				break;	/* No need to convert */
			else
				unexpected = true;
			break;
		case TEXTOID:
			if (expected_type == VARCHAROID)
				break;	/* No need to convert */
			else
				unexpected = true;
			break;
		default:
			unexpected = true;
			break;
	}

	if (conversion_func != NULL)
	{
		value = DirectFunctionCall1(conversion_func, original_value);
		/*
		 * When need to truncated but value is rounded up by numeric_int8 function,
		 * decrease value by 1 to get expected value.
		 */
		if (is_truncated == true && rounded_up == true)
			value--;
		*expected_value = value;
		return true;
	}
	else
	{
		/* Display a warning message when there is unexpected case. */
		if (unexpected == true)
			elog(WARNING, "Found an unexpected case when converting data to expected data of temp table. The value will be copied without conversion.");
		return false;
	}
}

/**
 * emit_context_error
 *
 * This callback function is used to display error message without context.
 */
static void
emit_context_error(void* context)
{
	ErrorData *err;
	MemoryContext oldcontext;

	oldcontext = MemoryContextSwitchTo(context);
	err = CopyErrorData();
	MemoryContextSwitchTo(oldcontext);

	/* Display error without displaying context */
	if (strcmp(err->message, "cannot take square root of a negative number") == 0)
		elog(ERROR, "Can not return value because of rounding problem from child node.");
	else
		elog(err->elevel, "%s", err->message);
}

/**
 * spd_execute_select_temp_table
 *
 * Execute SELECT query and store result to fdw_private->agg_values.
 * This is called by aggregate Push-down case.
 *
 * @param[in,out] fdw_private
 * @param[in] sql
 */
static void
spd_execute_select_temp_table(SpdFdwPrivate *fdw_private, char *sql)
{
	int			ret;
	int			i,
				k;
	int			colid = 0;
	MemoryContext oldcontext;
	ListCell   *lc;
	ErrorContextCallback errcallback;

	SPD_WRITE_LOCK_TRY(&fdw_private->scan_mutex);
	ret = SPI_connect();
	if (ret < 0)
		elog(ERROR, "SPI_connect failed. Returned %d.", ret);

	/* Set up callback to display error without CONTEXT information. */
	errcallback.callback = emit_context_error;
	errcallback.arg = fdw_private->es_query_cxt;
	errcallback.previous = NULL;
	error_context_stack = &errcallback;

	ret = SPI_exec(sql, 0);

	if (ret != SPI_OK_SELECT)
	{
		SPI_finish();
		elog(ERROR, "Failed to select from temp table. Retrned %d. SQL is %s.", ret, sql);
	}

	if (SPI_processed == 0)
	{
		SPI_finish();
		goto end;
	}

	/*
	 * Store memory of new agg tuple. It will be used in next iterate foreign
	 * scan in spd_select_return_aggslot.
	 */
	oldcontext = MemoryContextSwitchTo(fdw_private->es_query_cxt);

	fdw_private->agg_values = (Datum **) palloc0(SPI_processed * sizeof(Datum *));
	fdw_private->agg_nulls = (bool **) palloc0(SPI_processed * sizeof(bool *));

	/*
	 * Length of agg_value_type, agg_values[i] and agg_nulls[i] are the number
	 * of columns of the temp table.
	 */
	fdw_private->agg_value_type = (Oid *) palloc0(fdw_private->temp_num_cols * sizeof(Oid));
	for (i = 0; i < SPI_processed; i++)
	{
		fdw_private->agg_values[i] = (Datum *) palloc0(fdw_private->temp_num_cols * sizeof(Datum));
		fdw_private->agg_nulls[i] = (bool *) palloc0(fdw_private->temp_num_cols * sizeof(bool));
	}
	/* In case of rescan, we need to reinitial agg_num variable. */
	fdw_private->agg_num = 0;
	fdw_private->agg_tuples = SPI_processed;
	for (k = 0; k < SPI_processed; k++)
	{
		colid = 0;
		foreach(lc, fdw_private->mapping_tlist)
		{
			Extractcells		*extcells = (Extractcells *) lfirst(lc);
			Oid					expected_type = exprType((Node *) extcells->expr);
			Datum				datum;
			Form_pg_attribute	attr = TupleDescAttr(SPI_tuptable->tupdesc, colid);
			bool				isnull = false;

			if (extcells->is_having_qual)
				continue;

			fdw_private->agg_value_type[colid] = attr->atttypid;

			datum = SPI_getbinval(SPI_tuptable->vals[k],
								SPI_tuptable->tupdesc,
								colid + 1,
								&isnull);

			if (isnull)
				fdw_private->agg_nulls[k][colid] = true;
			else if (fdw_private->agg_value_type[colid] != expected_type)
			/* Only convert when data type of column of temp table is different from returned data */
			{
				if (datum_is_converted(fdw_private->agg_value_type[colid], datum, expected_type,
											&fdw_private->agg_values[k][colid], extcells->is_truncated))
				{
					fdw_private->agg_value_type[colid] = expected_type;
				}
				else
				{
					/* Copy datum. */
					fdw_private->agg_values[k][colid] = datumCopy(datum,
															attr->attbyval,
															attr->attlen);
				}
			}
			else
			{
				/* We need to deep copy datum from SPI memory context. */
				fdw_private->agg_values[k][colid] = datumCopy(datum,
															attr->attbyval,
															attr->attlen);
			}

			colid++;
		}
	}
	Assert(colid == fdw_private->temp_num_cols);

	MemoryContextSwitchTo(oldcontext);
	SPI_finish();
end:;
	SPD_RWUNLOCK_CATCH(&fdw_private->scan_mutex);
}

/**
 * spd_calc_aggvalues
 *
 * This is called by aggregate pushdown case.
 * Calculate one result row specified by 'rowid' and store it to 'slot'.
 *
 * @param[in] fdw_private
 * @param[in] rowid Index of fdw_private->agg_values
 * @param[out] slot Result is stored here
 */
static void
spd_calc_aggvalues(SpdFdwPrivate *fdw_private, int rowid, TupleTableSlot *slot)
{
	Datum	   		*ret_agg_values;
	HeapTuple		tuple;
	bool	   		*nulls;
	int				target_column;	/* Number of target in slot */
	int				map_column;		/* Number of target in query */
	ListCell		*lc;
	Mappingcells	*mapcells;

	/* Clear Tuple if agg results is empty. */
	if (!fdw_private->agg_values)
	{
		ExecClearTuple(slot);
		fdw_private->agg_num++;
		return;
	}

	target_column = 0;
	map_column = 0;
	ret_agg_values = (Datum *) palloc0(slot->tts_tupleDescriptor->natts * sizeof(Datum));
	nulls = (bool *) palloc0(slot->tts_tupleDescriptor->natts * sizeof(bool));

	foreach(lc, fdw_private->mapping_tlist)
	{
		Extractcells	*extcells = lfirst(lc);
		ListCell		*extlc;

		extlc = list_head(extcells->cells);
		mapcells = (Mappingcells *) lfirst(extlc);

		if (target_column != mapcells->original_attnum)
		{
			map_column++;
			continue;
		}

		if (fdw_private->agg_nulls[rowid][map_column])
			nulls[target_column] = true;
		ret_agg_values[target_column] = fdw_private->agg_values[rowid][map_column];

		target_column++;
		map_column++;
	}

	if ((TTS_IS_HEAPTUPLE(slot) && ((HeapTupleTableSlot*) slot)->tuple)){
		tuple = heap_form_tuple(slot->tts_tupleDescriptor, ret_agg_values, nulls);
		ExecStoreHeapTuple(tuple, slot, false);
	}else{
		slot->tts_values = ret_agg_values;
		slot->tts_isnull = nulls;
		/* To avoid assert failure in ExecStoreVirtualTuple, set tts_flags empty. */
		slot->tts_flags |= TTS_FLAG_EMPTY;
		ExecStoreVirtualTuple(slot);
	}

	fdw_private->agg_num++;
}

static void
rebuild_target_OpExpr(Node *node, StringInfo buf, Extractcells *extcells, int *cellid, List *groupby_target, bool isfirst)
{
	OpExpr				*ope = (OpExpr *) node;
	HeapTuple			tuple;
	Form_pg_operator	form;
	char				oprkind;
	char				*opname;
	ListCell			*arg;
	bool				is_extract_expr;

	/* Retrieve information about the operator from system catalog. */
	tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(ope->opno));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for operator %u.", ope->opno);
	form = (Form_pg_operator) GETSTRUCT(tuple);
	oprkind = form->oprkind;

	/* Always parenthesize the expression. */
	appendStringInfoChar(buf, '(');

	if (extcells->is_having_qual || extcells->is_contain_group_by)
		is_extract_expr = true;
	else
		is_extract_expr = is_need_extract((Node *)ope);

	if (!is_extract_expr)
	{
		ListCell *extlc;
		int id = 0;

		foreach(extlc, extcells->cells)
		{
			/* Find the mapping cell. */
			Mappingcells *cell = (Mappingcells *) lfirst(extlc);
			int mapping;
			if (id != (*cellid))
			{
				id++;
				continue;
			}

			mapping = cell->mapping[AGG_SPLIT_NONE];

			Assert(list_member_int(groupby_target, mapping));

			/*
			* This is GROUP BY target. Ex: 't' in select sum(i), t
			* from t1 group by t.
			*/
			appendStringInfo(buf, "col%d", mapping);
			break;
		}
		(*cellid)++;
	}
	else
	{
		/* Deparse left operand. */
		if (oprkind == 'r' || oprkind == 'b')
		{
			arg = list_head(ope->args);
			rebuild_target_expr(lfirst(arg), buf, extcells, cellid, groupby_target, isfirst);
			appendStringInfoChar(buf, ' ');
		}

		/* Set operator name. */
		opname = NameStr(form->oprname);
		appendStringInfoString(buf, opname);

		/* If operator is division, need to truncate. Set is_truncate to true. */
		if (strcmp(opname, "/") == 0)
			extcells->is_truncated = true;

		/* Deparse right operand. */
		if (oprkind == 'l' || oprkind == 'b')
		{
			arg = list_tail(ope->args);
			appendStringInfoChar(buf, ' ');
			rebuild_target_expr(lfirst(arg), buf, extcells, cellid, groupby_target, isfirst);
		}
	}
	appendStringInfoChar(buf, ')');

	ReleaseSysCache(tuple);
}

static void
rebuild_target_Aggref(Node *node, StringInfo buf, Extractcells *extcells, int* cellid, List *groupby_target, bool isfirst)
{
	ListCell	*extlc;
	int			id = 0;
	Aggref *	aggref = (Aggref *) node;
	bool		has_Order_by = aggref->aggorder?true:false;

	foreach(extlc, extcells->cells)
	{
		/* Find the mapping cell. */
		Mappingcells *cell = (Mappingcells *) lfirst(extlc);
		int mapping;
		if (id != (*cellid))
		{
			id++;
			continue;
		}

		switch (cell->aggtype)
		{
			case AVG_FLAG:
			{
				/* Use CASE WHEN to avoid division by zero error. */
				if (has_Order_by)
					appendStringInfo(buf, "(CASE WHEN SUM(col%d) = 0 THEN NULL ELSE (SUM(col%d ORDER BY col%d)/SUM(col%d))::float8 END)", cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_SUM], cell->mapping[AGG_SPLIT_SUM], cell->mapping[AGG_SPLIT_COUNT]);
				else
					appendStringInfo(buf, "(CASE WHEN SUM(col%d) = 0 THEN NULL ELSE (SUM(col%d)/SUM(col%d))::float8 END)", cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_SUM], cell->mapping[AGG_SPLIT_COUNT]);
				break;
			}
			case VAR_FLAG:
			{
				/* Use CASE WHEN to avoid division by zero error. */
				if (has_Order_by)
					appendStringInfo(buf, "(CASE WHEN SUM(col%d) = 0 OR SUM(col%d) = 1 THEN NULL ELSE ((SUM(col%d ORDER BY col%d) - POWER(SUM(col%d ORDER BY col%d), 2)/SUM(col%d))/(SUM(col%d) - 1))::float8 END)",
						cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_SUM_SQ], cell->mapping[AGG_SPLIT_SUM_SQ], cell->mapping[AGG_SPLIT_SUM], cell->mapping[AGG_SPLIT_SUM], cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_COUNT]);
				else
					appendStringInfo(buf, "(CASE WHEN SUM(col%d) = 0 OR SUM(col%d) = 1 THEN NULL ELSE ((SUM(col%d) - POWER(SUM(col%d), 2)/SUM(col%d))/(SUM(col%d) - 1))::float8 END)",
						cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_SUM_SQ], cell->mapping[AGG_SPLIT_SUM], cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_COUNT]);
				break;
			}
			case DEV_FLAG:
			{
				/* Use CASE WHEN to avoid division by zero error. */
				if (has_Order_by)
					appendStringInfo(buf, "(CASE WHEN SUM(col%d) = 0 OR SUM(col%d) = 1 THEN NULL ELSE (sqrt((SUM(col%d ORDER BY col%d) - POWER(SUM(col%d ORDER BY col%d), 2)/SUM(col%d))/(SUM(col%d) - 1)))::float8 END)",
						cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_SUM_SQ], cell->mapping[AGG_SPLIT_SUM_SQ], cell->mapping[AGG_SPLIT_SUM], cell->mapping[AGG_SPLIT_SUM], cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_COUNT]);
				else
					appendStringInfo(buf, "(CASE WHEN SUM(col%d) = 0 OR SUM(col%d) = 1 THEN NULL ELSE (sqrt((SUM(col%d) - POWER(SUM(col%d), 2)/SUM(col%d))/(SUM(col%d) - 1)))::float8 END)",
						cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_SUM_SQ], cell->mapping[AGG_SPLIT_SUM], cell->mapping[AGG_SPLIT_COUNT], cell->mapping[AGG_SPLIT_COUNT]);
				break;
			}
			case SPREAD_FLAG:
			{
				appendStringInfo(buf, "MAX(col%d) - MIN(col%d)", cell->mapping[AGG_SPLIT_SUM], cell->mapping[AGG_SPLIT_COUNT]);
				break;
			}
			default:
			{
				char	   *agg_command = cell->agg_command->data;
				char		*agg_const = cell->agg_const->data;		/* constant argument of function */
				mapping = cell->mapping[AGG_SPLIT_NONE];

				/* If original aggregate function is count, change to sum to count all data from multiple nodes. */
				if (!pg_strcasecmp(agg_command, "SUM") || !pg_strcasecmp(agg_command, "COUNT"))
					if (has_Order_by)
						appendStringInfo(buf, "SUM(col%d ORDER BY col%d)", mapping, mapping);
					else
						appendStringInfo(buf, "SUM(col%d)", mapping);
				else if (IS_NON_SPLIT_AGG(agg_command))
					appendStringInfo(buf, "%s(col%d)", agg_command, mapping);

				/*
				 * This is for string_agg function. This function require delimiter to work.
				 */
				else if (!pg_strcasecmp(agg_command, "STRING_AGG"))
				{
					appendStringInfo(buf, "%s(col%d, %s)", agg_command, mapping, agg_const);
				}
				/*
				 * This is for influx db functions. MAX has not effect to
				 * result. We have to consider multi-tenant.
				 */
				else if (!pg_strcasecmp(agg_command, "INFLUX_TIME") || !pg_strcasecmp(agg_command, "LAST"))
					appendStringInfo(buf, "MAX(col%d)", mapping);
				/*
				 * Other aggregation not listed above. TODO: SUM may be
				 * incorrect for multi-tenant table.
				 */
				else
					appendStringInfo(buf, "SUM(col%d)", mapping);

				break;

			}
		}
		(*cellid)++;
		break;
	}
}

static void
rebuild_target_FuncExpr(Node* node, StringInfo buf, Extractcells *extcells, int *cellid, List *groupby_target, bool isfirst)
{
	FuncExpr	   *func = (FuncExpr *) node;
	Oid				rettype = func->funcresulttype;
	int32			coercedTypmod;
	char		   *opername = NULL;

	/* To handle case user cast data type using "::" */
	if (func->funcformat == COERCE_EXPLICIT_CAST)
		appendStringInfoChar(buf, '(');

	/* Get function name */
	opername = get_func_name(func->funcid);

	if(func->args)
	{
		/* Append function name when function is called directly */
		if (func->funcformat == COERCE_EXPLICIT_CALL)
			appendStringInfo(buf, "%s(", opername);

		rebuild_target_expr((Node *)func->args, buf, extcells, cellid, groupby_target, isfirst);

		if (func->funcformat == COERCE_EXPLICIT_CALL)
			appendStringInfoChar(buf, ')');
	}
	else
	{
		/* When there is no arguments, only need to append function name and "()". */
		appendStringInfo(buf, "%s()", opername);
	}

	/* To handle case user cast data type using "::" */
	if (func->funcformat == COERCE_EXPLICIT_CAST)
	{
		/* Get the typmod if this is a length-coercion function. */
		(void) exprIsLengthCoercion((Node *) node, &coercedTypmod);

		appendStringInfo(buf, ")::%s",
			spd_deparse_type_name(rettype, coercedTypmod));
	}
}

/**
 * rebuild_target_expr
 *
 * This function rebuilds the target expression which will be used on temp table.
 * It is based on the original expression and the mapping data.
 *
 * @param[in] node Original expression
 * @param[in,out] buf Target expression
 * @param[in] extcells Extracted cells which contains mapping data
 * @param[in] cellid The cell id which will be mapped
 * @param[in] isfirst True if this expression is the first expression in query
 */
static void
rebuild_target_expr(Node* node, StringInfo buf, Extractcells *extcells, int *cellid, List *groupby_target, bool isfirst)
{
	if (node == NULL)
		return;

	switch(nodeTag(node))
	{
		case T_OpExpr:
			rebuild_target_OpExpr(node, buf, extcells, cellid, groupby_target, isfirst);
			break;
		case T_Aggref:
			rebuild_target_Aggref(node, buf, extcells, cellid, groupby_target, isfirst);
			break;
		case T_FuncExpr:
			rebuild_target_FuncExpr(node, buf, extcells, cellid, groupby_target, isfirst);
			break;
		case T_List:
		{
			List	   *l = (List *) node;
			ListCell   *lc;

			foreach(lc, l)
			{
				rebuild_target_expr((Node *)lfirst(lc), buf, extcells, cellid, groupby_target, isfirst);
			}
			break;
		}
		case T_Const:
			spd_deparse_const((Const *) node, buf, 0);
			break;
		case T_Var:
		{
			ListCell *extlc;
			int id = 0;

			foreach(extlc, extcells->cells)
			{
				/* Find the mapping cell. */
				Mappingcells *cell = (Mappingcells *) lfirst(extlc);
				int mapping;
				if (id != (*cellid))
				{
					id++;
					continue;
				}

				mapping = cell->mapping[AGG_SPLIT_NONE];
				/* Append var name. */
				appendStringInfo(buf, "col%d", mapping);
				break;
			}
			(*cellid)++;
			break;
		}
		case T_BoolExpr:
		{
			BoolExpr	*b = (BoolExpr *) node;
			const char	*op = NULL;		/* keep compiler quiet */
			bool		first;
			ListCell	*lc;

			switch (b->boolop)
			{
				case AND_EXPR:
					op = "AND";
					break;
				case OR_EXPR:
					op = "OR";
					break;
				case NOT_EXPR:
					appendStringInfoString(buf, "(NOT ");
					rebuild_target_expr((Node*) linitial(b->args), buf, extcells, cellid, groupby_target, true);
					appendStringInfoChar(buf, ')');
					return;
			}

			appendStringInfoChar(buf, '(');
			first = true;
			foreach(lc, b->args)
			{
				if (!first)
					appendStringInfo(buf, " %s ", op);
				rebuild_target_expr((Node *) lfirst(lc), buf, extcells, cellid, groupby_target, true);
				first = false;
			}
			appendStringInfoChar(buf, ')');

			break;
		}
		case T_ScalarArrayOpExpr:
		{
			ScalarArrayOpExpr *oe = (ScalarArrayOpExpr *) node;
			HeapTuple	tuple;
			Form_pg_operator form;

			/* Retrieve information about the operator from system catalog. */
			tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(oe->opno));
			if (!HeapTupleIsValid(tuple))
				elog(ERROR, "cache lookup failed for operator %u", oe->opno);
			form = (Form_pg_operator) GETSTRUCT(tuple);

			/* Sanity check. */
			Assert(list_length(oe->args) == 2);

			/* Always parenthesize the expression. */
			appendStringInfoChar(buf, '(');

			/* Deparse left operand. */
			rebuild_target_expr((Node*) linitial(oe->args), buf, extcells, cellid, groupby_target, true);
			appendStringInfoChar(buf, ' ');

			/* Deparse operator name plus decoration. */
			spd_deparse_operator_name(buf, form);
			appendStringInfo(buf, " %s (", oe->useOr ? "ANY" : "ALL");

			/* Deparse right operand. */
			rebuild_target_expr((Node*) lsecond(oe->args), buf, extcells, cellid, groupby_target, true);
			appendStringInfoChar(buf, ')');

			/* Always parenthesize the expression. */
			appendStringInfoChar(buf, ')');

			ReleaseSysCache(tuple);
			break;
		}
		case T_CoerceViaIO:
		{
			CoerceViaIO *cio = (CoerceViaIO *) node;

			if (cio->arg)
				rebuild_target_expr((Node *) cio->arg, buf, extcells, cellid, groupby_target, true);

			break;
		}
		default:
			break;
	}
}

/**
 * spd_select_from_temp_table
 *
 * Get a record by creating select query for temp table.
 * This is called by aggregate pushdown case.
 * If GROUP BY is used, spd_IterateForeignScan calls this fundction in the first time.
 * From the second time, spd_IterateForeignScan calls spd_select_return_aggslot().
 *
 * 1. Get all record from child node result.
 * 2. Set all getting record to fdw_private->agg_values.
 * 3. Create first record and return it..
 *
 * @param[in,out] slot
 * @param[in] node
 * @param[in] fdw_private
 */
static TupleTableSlot *
spd_select_from_temp_table(TupleTableSlot *slot, ForeignScanState *node, SpdFdwPrivate *fdw_private)
{
	StringInfo	sql = makeStringInfo();
	ListCell	*lc;
	int			j = 0;
	bool		isfirst = true;
	int			target_num = 0;		/* Number of target in query */

	/* Create Select query. */
	appendStringInfo(sql, "SELECT ");

	foreach(lc, fdw_private->mapping_tlist)
	{
		Extractcells *extcells = (Extractcells *) lfirst(lc);
		ListCell *extlc;

		if (extcells->is_having_qual)
			continue;

		/* No extract case */
		if (extcells->ext_num == 0)
		{
			Mappingcells	*cells;
			char			*agg_command;
			int				agg_type;
			char			*agg_const;
			int				mapping;

			extlc = list_head(extcells->cells);
			cells = (Mappingcells *) lfirst(extlc);
			agg_command = cells->agg_command->data;
			agg_type = cells->aggtype;
			agg_const = cells->agg_const->data;

			mapping = cells->mapping[AGG_SPLIT_NONE];

			if (isfirst)
				isfirst = false;
			else
				appendStringInfo(sql, ",");

			/*
			 * For those columns listed in the grouping target but not
			 * listed in the target list. For example, SELECT avg(i) FROM
			 * t1 GROUP BY i,t. column name i and column name t not listed
			 * in the target list, so agg_command is NULL.
			 */
			if (agg_command == NULL)
			{
				appendStringInfo(sql, "col%d", mapping);
				continue;
			}
			else if (agg_type != NON_AGG_FLAG)
			{
				/*
				 * This is for aggregate functions.
				 */
				if (!pg_strcasecmp(agg_command, "SUM") || !pg_strcasecmp(agg_command, "COUNT") ||
					!pg_strcasecmp(agg_command, "AVG") || !pg_strcasecmp(agg_command, "VARIANCE") ||
					!pg_strcasecmp(agg_command, "STDDEV"))
					/*
					 * These functions are split by some functions and pushed down. After getting
					 * these results from child nodes, they needs to be merged by SUM().
					 */
					appendStringInfo(sql, "SUM(col%d)", mapping);
				else if (IS_NON_SPLIT_AGG(agg_command))
					appendStringInfo(sql, "%s(col%d)", agg_command, mapping);
				/*
				 * This is for string_agg function. This function requires delimiter to work.
				 */
				else if (!pg_strcasecmp(agg_command, "STRING_AGG"))
				{
					appendStringInfo(sql, "%s(col%d, %s)", agg_command, mapping, agg_const);
				}
				/*
				 * This is for influx db functions. MAX has not effect to
				 * result. We have to consider multi-tenant.
				 */
				else if (!pg_strcasecmp(agg_command, "INFLUX_TIME") || !pg_strcasecmp(agg_command, "LAST"))
					appendStringInfo(sql, "MAX(col%d)", mapping);

				/*
				 * Other aggregation not listed above. TODO: SUM may be
				 * incorrect for multi-tenant table.
				 */
				else
					appendStringInfo(sql, "SUM(col%d)", mapping);
			}
			else			/* non agg */
			{

				/*
				 * Ex: SUM(i)/2
				 */
				if (!list_member_int(fdw_private->groupby_target, mapping) &&
					!fdw_private->has_stub_star_regex_function)
				{
					appendStringInfo(sql, "SUM(col%d)", mapping);
				}

				/*
				 * This is GROUP BY target. Ex: 't' in select sum(i), t
				 * from t1 group by t.
				 */
				else
				{
					appendStringInfo(sql, "col%d", mapping);
				}
			}
			target_num++;
			j++;
		}
		/* Extract case */
		else
		{
			Expr	*expr = copyObject(extcells->expr);
			int		cellid = 0;
			if (isfirst)
				isfirst = false;
			else
				appendStringInfo(sql, ",");
			rebuild_target_expr((Node *) expr, sql, extcells, &cellid, fdw_private->groupby_target, isfirst);
			target_num++;
		}
	}

	fdw_private->temp_num_cols = target_num;
	appendStringInfo(sql, " FROM %s ", fdw_private->temp_table_name);
	/* Append GROUP BY clause. */
	if (fdw_private->groupby_string != 0 && !fdw_private->has_stub_star_regex_function)
		appendStringInfo(sql, "%s", fdw_private->groupby_string->data);

	/* Append HAVING clause. */
	if (fdw_private->has_having_quals)
	{
		Expr	*expr;
		bool	is_first = true;
		appendStringInfo(sql, " HAVING ");
		foreach(lc, fdw_private->mapping_tlist)
		{
			Extractcells *extcells = (Extractcells *) lfirst(lc);
			int		cellid = 0;

			if (!extcells->is_having_qual)
				continue;

			/* Extract case */
			expr = copyObject(extcells->expr);

			if (!is_first)
				appendStringInfoString(sql, " AND ");

			rebuild_target_expr((Node *) expr, sql, extcells, &cellid, fdw_private->groupby_target, true);
			is_first = false;
		}
	}

	elog(DEBUG1, "Selecting from temp table: %s.", sql->data);
	/* Execute aggregate query to temp table. */
	spd_execute_select_temp_table(fdw_private, sql->data);
	/* Calc and set agg values. */
	spd_calc_aggvalues(fdw_private, 0, slot);

	pfree(sql->data);
	pfree(sql);

	return slot;
}

/**
 * spd_select_return_aggslot
 *
 * Copy from fdw_private->agg_values to returning slot.
 * This is used in "GROUP BY" clause.
 *
 * @param[in,out] slot
 * @param[in] node
 * @param[in] fdw_private
 */
static TupleTableSlot *
spd_select_return_aggslot(TupleTableSlot *slot, ForeignScanState *node, SpdFdwPrivate * fdw_private)
{
	if (fdw_private->agg_num < fdw_private->agg_tuples)
	{
		spd_calc_aggvalues(fdw_private, fdw_private->agg_num, slot);
		return slot;
	}
	else
		return NULL;
}

/**
 * spd_create_temp_table_sql
 *
 * Create a SQL query of creating temp table for executing GROUP BY.
 *
 * @param[out] create_sql
 * @param[in] mapping_tlist
 * @param[in] temp_table
 * @param[in] child_comp_tlist
 */
static void
spd_create_temp_table_sql(StringInfo create_sql, List *mapping_tlist,
					char *temp_table, List *child_comp_tlist)
{
	ListCell   *lc;
	int			colid = 0;
	int			i;
	int			typeid;
	int			typmod;

	colid = 0;
	appendStringInfo(create_sql, "CREATE TEMP TABLE %s(", temp_table);
	foreach(lc, mapping_tlist)
	{
		Extractcells	*extcells = lfirst(lc);
		ListCell		*extlc;

		foreach(extlc, extcells->cells)
		{
			Mappingcells *cells = lfirst(extlc);

			for (i = 0; i < MAX_SPLIT_NUM; i++)
			{
				/* Append aggregate string. */
				if (colid == cells->mapping[i])
				{
					if (colid != 0)
						appendStringInfo(create_sql, ",");
					appendStringInfo(create_sql, "col%d ", colid);
					typeid = exprType((Node *) ((TargetEntry *) list_nth(child_comp_tlist, colid))->expr);
					typmod = exprTypmod((Node *) ((TargetEntry *) list_nth(child_comp_tlist, colid))->expr);

					/* Append column name and column type. */
					appendStringInfo(create_sql, " %s", spd_deparse_type_name(typeid, typmod));

					colid++;
				}
			}
		}
	}
	appendStringInfo(create_sql, ")");
	elog(DEBUG1, "Create temp table: %s.", create_sql->data);
}

/*
 * Add SPDURL value to the last position of a record value.
 * For example, given a record (1, a). New record will be (1, a, spdurl).
 */
static Datum
spd_AddSpdUrlForRecord(Datum record, char *spdurl)
{
	char	   *new_record;
	char	   *tmpstr = TextDatumGetCString(record);
	char	   *last = strrchr(tmpstr, ',');
	char	   *new_spdurl;

	if (!(tmpstr[0] == '(' && tmpstr[strlen(tmpstr) - 1] == ')'))
		return record;

	last++;
	last[strlen(last) - 1] = '\0';
	if (last[0] == '/' && last[strlen(last) - 1] == '/' && strlen(last) > 1)
	{
		new_spdurl = psprintf("/%s%s", spdurl, last);
		new_record = strndup(tmpstr, last - tmpstr);
		new_record = psprintf("%s%s)", new_record, new_spdurl);
	}
	else
	{
		new_spdurl = spdurl;
		new_record = psprintf("%s,/%s/)", tmpstr, new_spdurl);
	}

	return CStringGetTextDatum(new_record);
}

/*
 * spd_AddSpdUrlForGroupby
 *
 * Add SPDURL value into the slot. This function is used for the query of which GROUP BY has SPDURL.
 *
 * @param[in] pFssThrdInfo Thread information of the child
 * @param[in,out] parent_slot Parent tuple table slot
 * @param[in,out] node_slot Child tuple table slot
 * @param[in] fdw_private Private info
 */
static TupleTableSlot *
spd_AddSpdUrlForGroupby(ForeignScanThreadInfo *pFssThrdInfo, TupleTableSlot *parent_slot,
						TupleTableSlot *node_slot, SpdFdwPrivate *fdw_private)
{
	Datum	   *values;
	bool	   *nulls;
	bool	   *replaces;
	ForeignServer *fs;
	ForeignDataWrapper *fdw;
	int			i;
	char	   *spdurl;
	int			natts;

	/*
	 * Length of parent should be greater than or equal to length of
	 * child slot. If SPDURL is not specified, length is same.
	 */
	Assert(parent_slot->tts_tupleDescriptor->natts >=
		   node_slot->tts_tupleDescriptor->natts);

	fs = pFssThrdInfo->foreignServer;
	fdw = pFssThrdInfo->fdw;

	/* Initialize new tuple buffer. */
	natts = parent_slot->tts_tupleDescriptor->natts;
	values = (Datum *) palloc0(sizeof(Datum) * natts);
	nulls = (bool *) palloc0(sizeof(bool) * natts);
	replaces = (bool *) palloc0(sizeof(bool) * natts);

	/*
	* Insert SPDURL column to slot. heap_modify_tuple will replace the
	* existing column. To insert new column and its data, we also follow the
	* similar steps like heap_modify_tuple. First, deform tuple to get data
	* values, Second, modify data values (insert new columm). Then, form
	* tuple with new data values. Finally, copy identification info (if any).
	*/

	if (TTS_IS_HEAPTUPLE(node_slot))
	{
		HeapTuple	newtuple;

		/* Extract data to values/isnulls. */
		heap_deform_tuple(node_slot->tts_ops->get_heap_tuple(node_slot), node_slot->tts_tupleDescriptor, values, nulls);

		/* Insert SPDURL to the array. */
		if (strcmp(fdw->fdwname, PGSPIDER_FDW_NAME) != 0)
		{
			spdurl = psprintf("/%s/", fs->servername);
			for (i = natts - 2; i >= fdw_private->idx_url_tlist; i--)
			{
				values[i + 1] = values[i];
				nulls[i + 1] = nulls[i];
			}
			values[fdw_private->idx_url_tlist] = CStringGetTextDatum(spdurl);
			nulls[fdw_private->idx_url_tlist] = false;
			/* Form new tuple with new values. */
			newtuple = heap_form_tuple(parent_slot->tts_tupleDescriptor,
				values,
				nulls);
		}
		else
		{
			spdurl = psprintf("/%s%s", fs->servername, TextDatumGetCString(values[fdw_private->idx_url_tlist]));
			values[fdw_private->idx_url_tlist] = CStringGetTextDatum(spdurl);
			nulls[fdw_private->idx_url_tlist] = false;
			replaces[fdw_private->idx_url_tlist] = true;
			/* Modify tuple with new values */
			newtuple = heap_modify_tuple(node_slot->tts_ops->get_heap_tuple(node_slot), node_slot->tts_tupleDescriptor,
				values, nulls, replaces);
		}

		/*
		* copy the identification info of the old tuple: t_ctid, t_self,
		* and OID (if any).
		*/
		newtuple->t_data->t_ctid = node_slot->tts_ops->get_heap_tuple(node_slot)->t_data->t_ctid;
		newtuple->t_self = node_slot->tts_ops->get_heap_tuple(node_slot)->t_self;
		newtuple->t_tableOid = node_slot->tts_ops->get_heap_tuple(node_slot)->t_tableOid;

		ExecStoreHeapTuple(newtuple, parent_slot, false);

		pfree(values);
		pfree(nulls);
	}
	else
	{
		/* tuple mode is VIRTUAL. */
		int			offset = 0;

		for (i = 0; i < natts; i++)
		{
			if (i == fdw_private->idx_url_tlist)
			{
				spdurl = psprintf("/%s/", fs->servername);
				values[i] = CStringGetTextDatum(spdurl);
				nulls[i] = false;
				offset = -1;
			}
			else
			{
				values[i] = node_slot->tts_values[i + offset];
				nulls[i] = node_slot->tts_isnull[i + offset];
			}
		}
		parent_slot->tts_values = values;
		parent_slot->tts_isnull = nulls;
		/* to avoid assert failure in ExecStoreVirtualTuple, set tts_flags empty */
		parent_slot->tts_flags |= TTS_FLAG_EMPTY;
		ExecStoreVirtualTuple(parent_slot);
	}
	return parent_slot;
}

/**
 * spd_AddSpdUrl
 *
 * Add SPDURL value into result slot.
 * If child node is pgspider, then concatinate node name.
 * We don't convert heap tuple to virtual tuple because for update
 * using postgres_fdw and pgspider_fdw, ctid which virtual tuples
 * don't have is necessary.
 *
 * @param[in] pFssThrdInfo Thread information of the child
 * @param[in,out] parent_slot Parent tuple table slot
 * @param[in,out] node_slot Child tuple table slot
 * @param[in] fdw_private Private info
 * @param[in] is_first_iterate True if it is the first time calling.
 */
static TupleTableSlot *
spd_AddSpdUrl(ForeignScanThreadInfo *pFssThrdInfo, TupleTableSlot *parent_slot,
			  TupleTableSlot *node_slot, SpdFdwPrivate *fdw_private,
			  bool is_first_iterate)
{
	Datum	   *values;
	bool	   *nulls;
	bool	   *replaces;
	ForeignServer *fs;
	ForeignDataWrapper *fdw;
	int			i;
	int			natts;

	/* Make tts_values and tts_nulls valid. */
	slot_getallattrs(node_slot);

	/* If GROUP BY has SPDURL, the logic is different. */
	if (fdw_private->groupby_has_spdurl)
		return spd_AddSpdUrlForGroupby(pFssThrdInfo, parent_slot,
									   node_slot, fdw_private);

	fs = pFssThrdInfo->foreignServer;
	fdw = pFssThrdInfo->fdw;

	/* Initialize new tuple buffer. */
	natts = node_slot->tts_tupleDescriptor->natts;
	values = palloc0(sizeof(Datum) * node_slot->tts_tupleDescriptor->natts);
	nulls = palloc0(sizeof(bool) * node_slot->tts_tupleDescriptor->natts);
	replaces = palloc0(sizeof(bool) * node_slot->tts_tupleDescriptor->natts);

	/* Calculate the location of SPDURL at only 1st time of iteration of addSpdUrl. */
	if (is_first_iterate)
	{
		for (i = 0; i < node_slot->tts_tupleDescriptor->natts; i++)
		{
			Form_pg_attribute attr = TupleDescAttr(node_slot->tts_tupleDescriptor, i);
			if (strcmp(attr->attname.data, SPDURL) == 0)
			{
				fdw_private->idx_url_tlist = i;
				break;
			}
		}
	}

	for (i = 0; i < natts; i++)
	{
		char	   *value;
		Form_pg_attribute attr = TupleDescAttr(node_slot->tts_tupleDescriptor, i);
		int			tnum = -1;

		/*
		 * Check if i th attribute is SPDURL or not. If so, fill SPDURL slot.
		 */
		if ((i == fdw_private->idx_url_tlist))
		{
			bool		isnull;

			/* Check child node is pgspider or not. */
			if (strcmp(fdw->fdwname, PGSPIDER_FDW_NAME) == 0 && node_slot->tts_isnull[i] == false)
			{

				Datum		col = slot_getattr(node_slot, i + 1, &isnull);
				char	   *s;

				if (isnull)
					elog(ERROR, "Child node name is nothing. %s should return node name.", PGSPIDER_FDW_NAME);

				s = TextDatumGetCString(col);

				/*
				 * if child node is pgspider, concatinate child node name
				 * and child child node name.
				 */
				value = psprintf("/%s%s", fs->servername, s);
			}
			else
			{
				/*
				 * Child node is NOT pgspider, create column name
				 * attribute.
				 */
				value = psprintf("/%s/", fs->servername);
			}

			if (attr->atttypid != TEXTOID)
				elog(ERROR, "%s column must be text type. But type id is %d.", SPDURL, attr->atttypid);
			replaces[i] = true;
			nulls[i] = false;

			if (i == fdw_private->idx_url_tlist)
				values[i] = CStringGetTextDatum(value);
			tnum = i;
		}
		else if (fdw_private->record_function == true)
		{
			replaces[i] = true;
			nulls[i] = false;
			if (attr->atttypid == TEXTOID)
			{
				values[i] = spd_AddSpdUrlForRecord(node_slot->tts_values[i], fs->servername);
			}
			else
			{
				values[i] = node_slot->tts_values[i];
			}
			tnum = i;
		}

		if (tnum != -1)
		{
			if (TTS_IS_HEAPTUPLE(node_slot) && ((HeapTupleTableSlot *)node_slot)->tuple)
			{
				/* tuple mode is HEAP. */
				HeapTuple newtuple = heap_modify_tuple(node_slot->tts_ops->get_heap_tuple(node_slot),
													   node_slot->tts_tupleDescriptor,
													   values, nulls, replaces);
				ExecStoreHeapTuple(newtuple, node_slot, false);
			}
			else
			{
				/* tuple mode is VIRTUAL. */
				node_slot->tts_values[tnum] = values[tnum];
				node_slot->tts_isnull[tnum] = false;
				/* to avoid assert failure in ExecStoreVirtualTuple */
				node_slot->tts_flags |= TTS_FLAG_EMPTY;
				ExecStoreVirtualTuple(node_slot);
			}
		}
	}

	return node_slot;
}

/**
 * nextChildTuple
 *
 * Return slot and node id of child fdw which returns the slot if available.
 * Return NULL if all threads are finished.
 *
 * @param[in] fssThrdInfo
 * @param[in] nThreads
 * @param[out] nodeId
 */
static TupleTableSlot *
nextChildTuple(ForeignScanThreadInfo *fssThrdInfo, int nThreads, int *nodeId, int *startNodeId)
{
	int			count = 0;
	int			start = *startNodeId;
	bool		all_thread_finished = true;
	TupleTableSlot *slot;

	for (count = start;; count++)
	{
		bool		is_finished = false;
		int real_count = count % nThreads;
		if (count >= nThreads+start)
		{
			if (all_thread_finished)
			{
				return NULL;	/* There is no iterating thread. */
			}
			all_thread_finished = true;
			count = start;
			pthread_yield();
		}
		slot = spd_queue_get(&fssThrdInfo[real_count].tupleQueue, &is_finished);
		if (slot)
		{
			/* tuple found */
			*nodeId = real_count;
			if(start >= nThreads){
				*startNodeId = 0;
			}
			else{
				*startNodeId = start + 1;
			}
			return slot;
		}
		else if (!is_finished)
		{
			/* No tuple yet, but the thread is running. */
			all_thread_finished = false;
		}
	}
	Assert(false);
}

/**
 * spd_IterateForeignScan
 *
 * spd_IterateForeignScan iterates on each child node and returns the tuple table slot
 * in a round robin fashion.
 *
 * @param[in] node
 */
static TupleTableSlot *
spd_IterateForeignScan(ForeignScanState *node)
{
	ForeignScan *fsplan = (ForeignScan *) node->ss.ps.plan;
	int			count = 0;
	ForeignScanThreadInfo *fssThrdInfo = node->spd_fsstate;
	TupleTableSlot *slot = NULL,
			   *tempSlot = NULL;
	SpdFdwPrivate *fdw_private;
	List	   *mapping_tlist;
	MemoryContext oldcontext;
	int node_incr;

	fdw_private = (SpdFdwPrivate *) fssThrdInfo[0].private;

	if (fdw_private == NULL)
		fdw_private = spd_DeserializeSpdFdwPrivate(fsplan->fdw_private);

#ifdef GETPROGRESS_ENABLED
	if (getResultFlag)
		return NULL;
#endif
	if (fdw_private->nThreads == 0)
		return NULL;

	mapping_tlist = fdw_private->mapping_tlist;

	/*
	 * After the core engine initialize stuff for query, it jump to spd_IterateForeingScan,
	 * in this routine, we need to send request for the each child node start scan.
	 */
	for (node_incr = 0; node_incr < fdw_private->nThreads; node_incr++)
	{
		if (!fssThrdInfo[node_incr].requestStartScan && fdw_private->isFirst)
		{
			/* Request to continue the each query transaction. */
			fssThrdInfo[node_incr].requestStartScan = true;
		}
	}

	if (fdw_private->agg_query && fdw_private->node_num > 1)
	{
		/* Create temp table if it is the 1st time. */
		if (fdw_private->isFirst)
		{
			StringInfo	create_sql = makeStringInfo();

			/*
			 * Store temp table name, it will be used to drop table in next
			 * iterate foreign scan.
			 */
			oldcontext = MemoryContextSwitchTo(fdw_private->es_query_cxt);

			/*
			 * Use temp table name like __spd__temptable_(NUMBER) to avoid
			 * using the same table in different foreign scan.
			 */
			fdw_private->temp_table_name = psprintf(AGGTEMPTABLE "_" INT64_FORMAT,
													temp_table_id++);
			/* Switch to CurrentMemoryContext. */
			MemoryContextSwitchTo(oldcontext);

			spd_create_temp_table_sql(create_sql, mapping_tlist,
								fdw_private->temp_table_name, fdw_private->child_comp_tlist);
			spd_execute_local_query(create_sql->data, &fdw_private->scan_mutex);
			pfree(create_sql->data);
			pfree(create_sql);

			/*
			 * Run aggregation query for all data source threads and combine
			 * results.
			 */
			for (;;)
			{
				slot = nextChildTuple(fssThrdInfo, fdw_private->nThreads, &count, &fdw_private->startNodeId);
				if (slot == NULL)
					break;

				spd_insert_into_temp_table(slot, node, fdw_private);

#ifdef GETPROGRESS_ENABLED
				if (getResultFlag)
					break;
#endif
			}
			/* First time getting with pushdown from temp table. */
			tempSlot = node->ss.ss_ScanTupleSlot;
			tempSlot = spd_select_from_temp_table(tempSlot, node, fdw_private);
		}
		else
		{
			/* Second time getting from temporary result set. */
			tempSlot = node->ss.ss_ScanTupleSlot;
			tempSlot = spd_select_return_aggslot(tempSlot, node, fdw_private);
		}

		fdw_private->isFirst = false;

		return tempSlot;
	}
	else
	{
		/* Utilize isFirst to mark this processing is implemented one time only. */
		fdw_private->isFirst = false;

		slot = nextChildTuple(fssThrdInfo, fdw_private->nThreads, &count, &fdw_private->startNodeId);
	}

	return slot;
}

/**
 * spd_ReScanForeignScan
 *
 * spd_ReScanForeignScan restarts the spd plan
 *
 * @param[in] node
 */
static void
spd_ReScanForeignScan(ForeignScanState *node)
{

	SpdFdwPrivate *fdw_private;
	int			node_incr;
	ForeignScanThreadInfo *fssThrdInfo;

	fssThrdInfo = node->spd_fsstate;
	fdw_private = (SpdFdwPrivate *) fssThrdInfo[0].private;

	if (fdw_private == NULL)
		return;

	/*
	 * Number of child threads is only alive threads. Firstly, check to number
	 * of aliving child threads.
	 */
	for (node_incr = 0; node_incr < fdw_private->nThreads; node_incr++)
	{
		if (fssThrdInfo[node_incr].state != SPD_FS_STATE_ERROR &&
			fssThrdInfo[node_incr].state != SPD_FS_STATE_FINISH )
		{
			/*
			 * In case of rescan, need to update chgParam variable from
			 * core engine. Postgres FDW need chgParam to determine
			 * clear cursor or not.
			 */
			fssThrdInfo[node_incr].fsstate->ss.ps.chgParam = bms_copy(node->ss.ps.chgParam);
			fssThrdInfo[node_incr].requestRescan = true;
			fdw_private->isFirst = true;
			fdw_private->startNodeId = 0;
		}
	}

	pthread_yield();

	for (node_incr = 0; node_incr < fdw_private->nThreads; node_incr++)
	{
		if (fssThrdInfo[node_incr].state != SPD_FS_STATE_ERROR &&
			fssThrdInfo[node_incr].state != SPD_FS_STATE_FINISH)
		{
			/* Break this loop when child thread starts scan again. */
			while (fssThrdInfo[node_incr].requestRescan)
			{
				pthread_yield();
			}
		}
	}

	return;
}

/**
 * spd_EndForeignScan
 *
 * spd_EndForeignScan ends the spd plan (i.e. does nothing).
 *
 * @param[in] node
 */
static void
spd_EndForeignScan(ForeignScanState *node)
{
	int			node_incr;
	ForeignScanThreadInfo *fssThrdInfo = node->spd_fsstate;
	SpdFdwPrivate *fdw_private;

	/* Reset child node offset to 0 for new query execution. */
	g_node_offset = 0;

	if (!fssThrdInfo)
		return;

	fdw_private = (SpdFdwPrivate *) fssThrdInfo[0].private;
	if (!fdw_private)
		return;

	spd_end_child_node_thread((ForeignScanState *)node, false);

	/*
	 * Call this function to allow backend to check memory context size as usual
	 * because the child threads finished running.
	 */
	skip_memory_checking(false);

	/* Wait until all the remote connections get closed. */
	for (node_incr = 0; node_incr < fdw_private->nThreads; node_incr++)
	{
		/* In case of abort transaction, the ss_currentRelation was closed by backend. */
		if (fssThrdInfo[node_incr].fsstate->ss.ss_currentRelation)
			RelationClose(fssThrdInfo[node_incr].fsstate->ss.ss_currentRelation);

		/* Free ResouceOwner before MemoryContextDelete. */
		ResourceOwnerRelease(fssThrdInfo[node_incr].thrd_ResourceOwner,
							 RESOURCE_RELEASE_BEFORE_LOCKS, false, false);
		ResourceOwnerRelease(fssThrdInfo[node_incr].thrd_ResourceOwner,
							 RESOURCE_RELEASE_LOCKS, false, false);
		ResourceOwnerRelease(fssThrdInfo[node_incr].thrd_ResourceOwner,
							 RESOURCE_RELEASE_AFTER_LOCKS, false, false);
		ResourceOwnerDelete(fssThrdInfo[node_incr].thrd_ResourceOwner);
	}

	if (fdw_private->is_explain)
	{
		for (node_incr = 0; node_incr < fdw_private->nThreads; node_incr++)
		{
			fssThrdInfo[node_incr].fdwroutine->EndForeignScan(fssThrdInfo[node_incr].fsstate);
		}
		return;
	}

	for (node_incr = 0; node_incr < fdw_private->nThreads; node_incr++)
	{
		pfree(fssThrdInfo[node_incr].fsstate);

		/*
		 * In case of abort transaction, no need to call spd_aliveError
		 * because this function will call elog ERROR, it will raise
		 * abort event again.
		 */
		if (throwErrorIfDead && fssThrdInfo[node_incr].state == SPD_FS_STATE_ERROR)
		{
			ForeignServer *fs;

			fs = GetForeignServer(fdw_private->childinfo[node_incr].server_oid);

			/*
			 * If not free memory before calling spd_aliveError,
			 * this function will raise abort event, and function
			 * spd_EndForeignScan return immediately not reach to
			 * end cause leak memory. We free memory before call
			 * spd_aliveError to avoid memory leak.
			 */
			pfree(fssThrdInfo);
			node->spd_fsstate = NULL;
			spd_aliveError(fs);
		}
	}
	pfree(fssThrdInfo);
	node->spd_fsstate = NULL;
}

/**
 * spd_check_url_update
 *
 * Check and create URL. If URL is nothing or can not find server
 * then return error.
 *
 * @param[in] target_rte
 * @return Created URL
 */
static List *
spd_check_url_update(RangeTblEntry *target_rte)
{
	if (target_rte->spd_url_list)
	{
		List *url_list = spd_ParseUrl(target_rte->spd_url_list);
		if (list_length(url_list) > 0)
		{
			/* URL is acceptable. */
			return url_list;
		}
	}
	elog(ERROR, "No URL is specified. INSERT/UPDATE/DELETE requires URL.");
}

/**
 * getModifyingFdwRoutine
 *
 * Return serveroid of child node to be modified.
 * If multiple child nodes are found, the 1st found node is used.
 *
 * @param[in] Relation parent relation
 * @return server oid of child node
 */
static Oid
getModifyingFdwRoutine(Relation rel, SpdFdwPrivate *fdw_private)
{
	Oid		   *oid = NULL;
	Oid			oid_server;

	spd_calculate_datasouce_oids(RelationGetRelationName(rel), fdw_private, &oid);
	if (fdw_private->node_num == 0)
		ereport(ERROR, (errmsg("Cannot Find child datasources.")));
	if (oid[0] == 0)
		ereport(ERROR, (errmsg("Child server oid is invalid: %d", oid[0])));

	oid_server = serverid_of_relation(oid[0]);

	return oid_server;
}

/**
 * spd_AddForeignUpdateTargets
 *
 * Add column(s) needed for update/delete on a foreign table,
 * we are using first column as row identification column, so we are adding that into target
 * list.
 * And check IN clause. Currently, IN must be used.
 *
 * @param[in] Query *parsetree,
 * @param[in] RangeTblEntry *target_rte
 * @param[in] Relation target_relation
 */
static void
spd_AddForeignUpdateTargets(Query *parsetree,
							RangeTblEntry *target_rte,
							Relation target_relation)
{
	MemoryContext oldcontext;
	FdwRoutine *fdwroutine;
	SpdFdwPrivate *fdw_private;
	Oid			oid_server = 0;

	fdw_private = spd_AllocatePrivate();
	oldcontext = MemoryContextSwitchTo(TopTransactionContext);
	/* Checking IN clause. */
	fdw_private->url_list = spd_check_url_update(target_rte);
	oid_server = getModifyingFdwRoutine(target_relation, fdw_private);
	fdwroutine = GetFdwRoutineByServerId(oid_server);

	MemoryContextSwitchTo(oldcontext);
	fdwroutine->AddForeignUpdateTargets(parsetree, target_rte, target_relation);
	return;
}

/**
 * spd_PlanForeignModify
 *
 * Add column(s) needed for update/delete on a foreign table,
 * we are using first column as row identification column, so we are adding that into target
 * list.
 * And check IN clause. Currently, IN must be used.
 *
 * @param[in] root
 * @param[in] plan
 * @param[in] resultRelation
 * @param[in] subplan_index
 */
static List *
spd_PlanForeignModify(PlannerInfo *root,
					  ModifyTable *plan,
					  Index resultRelation,
					  int subplan_index)
{
	RangeTblEntry *rte = planner_rt_fetch(resultRelation, root);
	MemoryContext oldcontext;
	FdwRoutine *fdwroutine;
	SpdFdwPrivate *fdw_private;
	Relation	rel;
	Oid			oid_server = 0;
	List	   *child_list = NULL;
	int			nums=0;

	oldcontext = MemoryContextSwitchTo(TopTransactionContext);
	fdw_private = spd_AllocatePrivate();

	fdw_private->url_list = spd_check_url_update(rte);

	spd_create_child_url(nums, rte->spd_url_list, fdw_private);

	rel = table_open(rte->relid, NoLock);
	oid_server = getModifyingFdwRoutine(rel, fdw_private);
	fdwroutine = GetFdwRoutineByServerId(oid_server);

	MemoryContextSwitchTo(oldcontext);
	child_list = fdwroutine->PlanForeignModify(root, plan, resultRelation, subplan_index);

	table_close(rel, NoLock);
	return list_make2(child_list, makeInteger(oid_server));
}

/**
 * spd_BeginForeignModify
 *
 * Add column(s) needed for update/delete on a foreign table,
 * we are using first column as row identification column, so we are adding that into target
 * list.
 *
 * @param[in] mtstate
 * @param[in] resultRelInfo
 * @param[in] fdw_private
 * @param[in] subplan_index
 * @param[in] eflags
 */
static void
spd_BeginForeignModify(ModifyTableState *mtstate,
					   ResultRelInfo *resultRelInfo,
					   List *fdw_private,
					   int subplan_index,
					   int eflags)
{

	Oid			oid_server = intVal(list_nth(fdw_private, ServerOid));
	List	   *child_fdw_private = (List *) list_nth(fdw_private, ForeignFdwPrivate);
	FdwRoutine *fdwroutine;
	SpdFdwModifyState *fmstate = (SpdFdwModifyState *) palloc0(sizeof(SpdFdwModifyState));

	fmstate->modify_server_oid = oid_server;

	fdwroutine = GetFdwRoutineByServerId(oid_server);
	fdwroutine->BeginForeignModify(mtstate, resultRelInfo, child_fdw_private, subplan_index, eflags);
	resultRelInfo->ri_FdwState = fmstate;
	return;
}

/**
 * spd_ExecForeignInsert
 *
 * Insert one row into a foreign table.
 *
 * @param[in] estate
 * @param[in] resultRelInfo
 * @param[in] slot
 * @param[in] planSlot
 */
static TupleTableSlot *
spd_ExecForeignInsert(EState *estate,
					  ResultRelInfo *resultRelInfo,
					  TupleTableSlot *slot,
					  TupleTableSlot *planSlot)
{
	SpdFdwModifyState *fmstate = (SpdFdwModifyState *) resultRelInfo->ri_FdwState;
	Oid			oid_server = fmstate->modify_server_oid;
	FdwRoutine *fdwroutine;

	fdwroutine = GetFdwRoutineByServerId(oid_server);
	return fdwroutine->ExecForeignInsert(estate, resultRelInfo, slot, planSlot);
}


/**
 * spd_ExecForeignUpdate
 *
 * Update one row in a foreign table
 *
 * @param[in] estate
 * @param[in] resultRelInfo
 * @param[in] slot
 * @param[in] planSlot
 */
static TupleTableSlot *
spd_ExecForeignUpdate(EState *estate,
					  ResultRelInfo *resultRelInfo,
					  TupleTableSlot *slot,
					  TupleTableSlot *planSlot)
{
	SpdFdwModifyState *fmstate = (SpdFdwModifyState *) resultRelInfo->ri_FdwState;
	Oid			oid_server = fmstate->modify_server_oid;
	FdwRoutine *fdwroutine;

	fdwroutine = GetFdwRoutineByServerId(oid_server);
	return fdwroutine->ExecForeignUpdate(estate, resultRelInfo, slot, planSlot);
}

/**
 * spd_ExecForeignDelete
 *
 * Delete one row in a foreign table, call child table.
 *
 * @param[in] estate
 * @param[in] resultRelInfo
 * @param[in] slot
 * @param[in] planSlot
 */
static TupleTableSlot *
spd_ExecForeignDelete(EState *estate,
					  ResultRelInfo *resultRelInfo,
					  TupleTableSlot *slot,
					  TupleTableSlot *planSlot)
{
	SpdFdwModifyState *fmstate = (SpdFdwModifyState *) resultRelInfo->ri_FdwState;
	Oid			oid_server = fmstate->modify_server_oid;
	FdwRoutine *fdwroutine;

	fdwroutine = GetFdwRoutineByServerId(oid_server);
	return fdwroutine->ExecForeignDelete(estate, resultRelInfo, slot, planSlot);

}

/**
 * spd_EndForeignModify
 *
 * Call EndForeignModify of child fdw.
 *
 * @param[in] estate
 * @param[in] resultRelInfo
 */
static void
spd_EndForeignModify(EState *estate,
					 ResultRelInfo *resultRelInfo)
{
	SpdFdwModifyState *fmstate = (SpdFdwModifyState *) resultRelInfo->ri_FdwState;
	Oid			oid_server = fmstate->modify_server_oid;
	FdwRoutine *fdwroutine;

	fdwroutine = GetFdwRoutineByServerId(oid_server);
	fdwroutine->EndForeignModify(estate, resultRelInfo);
}

#ifdef ENABLE_PARALLEL_S3
void parquet_s3_init();
void parquet_s3_shutdown();
#endif


static void
spd_fini(int code, Datum arg)
{
#ifdef ENABLE_PARALLEL_S3
    parquet_s3_shutdown();
#endif
}

void
_PG_init(void)
{
	/* Get the configuration. */
	DefineCustomBoolVariable("pgspider_core_fdw.throw_error_ifdead",
							 "set alive error",
							 NULL,
							 &throwErrorIfDead,
							 true,
							 PGC_USERSET,
							 0,
							 NULL,
							 NULL,
							 NULL);

	/* Get the configuration. */
	DefineCustomBoolVariable("pgspider_core_fdw.print_error_nodes",
							 "print error nodes",
							 NULL,
							 &isPrintError,
							 false,
							 PGC_USERSET,
							 0,
							 NULL,
							 NULL,
							 NULL);
#ifdef ENABLE_PARALLEL_S3
	parquet_s3_init();
#endif
	on_proc_exit(&spd_fini, 0);
}


