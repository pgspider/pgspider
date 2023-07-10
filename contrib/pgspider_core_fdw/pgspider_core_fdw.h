/*-------------------------------------------------------------------------
 *
 * pgspider_core_fdw.h
 *		  Header file of pgspider_core_fdw
 *
 * Portions Copyright (c) 2018, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_core_fdw/pgspider_core_fdw.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef PGSPIDER_CORE_FDW_H
#define PGSPIDER_CORE_FDW_H

#include "foreign/fdwapi.h"
#include "foreign/foreign.h"
#include "lib/stringinfo.h"
#include "nodes/pathnodes.h"
#include "utils/relcache.h"
#include "utils/resowner.h"
#include "catalog/pg_operator.h"
#include "optimizer/planner.h"
#ifdef PD_STORED
#include "funcapi.h"
#endif
#include "pgspider_core_fdw_defs.h"
#include "pgspider_core_timemeasure.h"

/* For checking single node or multiple node */
#define SPD_SINGLE_NODE	1
#define IS_SPD_MULTI_NODES(nodenum) (nodenum > SPD_SINGLE_NODE)

/* For bulk insert */
#define SPD_SINGLE_NODE_BULK_INSERT 0
#define SPD_MULTIPLE_NODE_BULK_INSERT 1
#define SPD_BATCH_SIZE_MAX_LIMIT 6553500

enum SpdServerstatus
{
	ServerStatusAlive,
	ServerStatusIn,
	ServerStatusDead,
	ServerStatusNotTarget,
};

/* This structure stores child pushdown information about child path. */
typedef struct ChildPushdownInfo
{
	RelOptKind	relkind;			/* Child relation kind. */
	Path		*path;				/* The best child path for child GetForeignPlan. */

	bool		orderby_pushdown;	/* True if child node can pushdown ORDER BY to remote server. */
	bool		limit_pushdown;		/* True if child node can pushdown LIMIT/OFFSET to remote server. */
}			ChildPushdownInfo;

/* This structure stores child information about plan. */
typedef struct ChildInfo
{
	/* USE ONLY IN PLANNING */
	RelOptInfo *baserel;
	RelOptInfo *input_rel_local;	/* Child input relation for creating child upper paths. */
	List	   *url_list;
	AggPath    *aggpath;
#ifdef ENABLE_PARALLEL_S3
	Value	   *s3file;
#endif
	RelOptInfo *joinrel;		/* Child relation info for join pushdown */
	FdwRoutine *fdwroutine;

	ChildPushdownInfo pushdown_info;	/* Child pushdown information */

	/* USE IN BOTH PLANNING AND EXECUTION */
	PlannerInfo *root;
	Plan	   *plan;
	enum SpdServerstatus child_node_status;
	Oid			server_oid;		/* child table's server oid */
	Oid			oid;			/* child table's table oid */
	Agg		   *pAgg;			/* "Aggref" for Disable of aggregation push
								 * down servers */
	bool		pseudo_agg;		/* True if aggregate function is calcuated on
								 * pgspider_core. It mean that it is not
								 * pushed down. This is a cache for searching
								 * pPseudoAggList by server oid. */
	List	   *fdw_private;	/* Private information of child fdw */

	/* USE ONLY IN EXECUTION */
	int			index_threadinfo;	/* index for ForeignScanThreadInfo array */
}			ChildInfo;

/*
 * SpdModifyThreadState
 *		State of foreign modify child thread.
 *
 * There four state groups:
 *	- "execute state": child thread start init modify data.
 *	- "end state": child thread wait and free scan resource if requested.
 *	- "error state": child thread in error handing.
 *
 * Note:
 *	- the "state" and "state group" order should not be changed.
 *	- when creating new state at the beginning or end of each group,
 * it may affect other code, for example spd_wait_transaction_foreign_modify_thread_safe
 * will wait for the thread to come out of "execution state" under the
 * condition "<= SPD_MDF_STATE_EXEC".
 */
typedef enum
{
	/* execute state */
	SPD_MDF_STATE_INIT,			/* child thread initialize resource: global variable, memory context... */
	SPD_MDF_STATE_BEGIN,		/* child thread start call BeginForeignModify of child node */
	SPD_MDF_STATE_PRE_EXEC,		/* child thread calling BeginForeignModify of child node  */
	SPD_MDF_STATE_EXEC_SIMPLE_INSERT,	/* child thread start batch insert to child node */
	SPD_MDF_STATE_EXEC_BATCH_INSERT,	/* child thread start foreign insert to child node */
	SPD_MDF_STATE_EXEC, 		/* child thread doing foreign modify to child node */

	/* end state */
	SPD_MDF_STATE_PRE_END,		/* child thread wait end foreign modify request from main thread */
	SPD_MDF_STATE_END,			/* child thread calling end foreign modify of child node */
	SPD_MDF_STATE_FINISH,		/* child thread exited without ERROR */

	/* error state */
	SPD_MDF_STATE_ERROR_INIT,	/* child thread encountered an ERROR */
	SPD_MDF_STATE_ERROR			/* child thread got ERROR signal from main thread */
}			SpdModifyThreadState;

typedef struct ModifyThreadInfo
{
	struct FdwRoutine *fdwroutine;	/* Foreign Data wrapper  routine */
	struct ModifyTableState *mtstate;	/* ModifyTable state data */
	int			eflags;			/* it used to set on Plan nodes(bitwise OR of
								 * the flag bits ) */
	Oid			serverId;		/* use it for server id */
	ForeignServer *foreignServer;	/* cache this for performance */
	ForeignDataWrapper *fdw;	/* cache this for performance */
	bool		requestExecModify; /* main thread request ExecForeignModify to
									* child thread */
	bool		requestEndModify; /* main thread request EndForeignModify to child
								 * thread */
	TupleTableSlot *slot;
	TupleTableSlot *planSlot;
	TupleTableSlot *rslot;

	int			childInfoIndex; /* index of child info array */
	MemoryContext threadMemoryContext;
	MemoryContext threadTopMemoryContext;
	MemoryContext temp_cxt;		/* context for temporary data */
	SpdModifyThreadState state;
	pthread_mutex_t stateMutex;	/* Use for state mutex */
	ResourceOwner thrd_ResourceOwner;
	void	   *private;
	int			transaction_level;
	bool		is_joined;
	int			subplan_index;
	char	   *child_thread_error_msg; /* child thread error message to transfer to main thread */

	/* FOR BATCH INSERT */
	int			batch_size;		/* use to save batch_size of child node */
	int			numSlots;		/* number of slot need to insert in batch mode */
	TupleTableSlot **rslots;	/* returning array of slot */
	TupleTableSlot **slots;		/* array of slot for bulk insert */
	TupleTableSlot **planSlots;	/* array of plan slot for bulk insert */
}			ModifyThreadInfo;

typedef enum
{
	SPD_WAKE_UP,	/* wake up request for child thread and
					 * default for runing state */
	SPD_PENDING		/* pending request for child thread */
}			SpdPendingRequest;

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

	/* True means that the ORDER BY is safe to push down */
	bool		orderby_is_pushdown_safe;

	/* True means that ORDER BY is given to child node */
	bool		child_orderby_needed;

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
	char	   *relation_name;

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

	/* Upper relation information */
	UpperRelationKind stage;
}			SpdRelationInfo;

typedef struct SocketInfo
{
	int 	socket_port;		/* port of socket server */
	int 	function_timeout;	/* timeout to listen for socket server */
	int     server_fd;			/* socket file descriptor */
	bool	end_server;			/* flag to determine if socket server closed */
	char   *err;				/* the error message of child socket server thread */
	List   *socketThreadInfos;	/* Shared list with child pgspider_fdw */

	/* context for server socket thread */
	ResourceOwner thrd_ResourceOwner;
	MemoryContext threadTopMemoryContext;
	MemoryContext threadMemoryContext;
}			SocketInfo;

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
	List	   *base_remote_conds;	/* Base restrict conditions are given to child */
	List	   *base_local_conds;	/* Base restrict conditions are not given to child */
	List	   *upper_targets;
	List	   *url_list;		/* IN clause for SELECT */

	PlannerInfo *spd_root;		/* Copy of root planner info. This is used by
								 * aggregation pushdown. */
	SpdRelationInfo rinfo;		/* pgspider relation info */
	TupleDesc	child_comp_tupdesc; /* temporary tuple desc */
	List	   *pPseudoAggList; /* List of server oids which aggregate
								 * function is not pushed down */
	RelOptInfo *joinrel_child;	/* Child join relation. */

	/* USE IN BOTH PLANNING AND EXECUTION */
	int			node_num;		/* number of child tables */
	int			nThreads;		/* Number of alive threads */
	int			idx_url_tlist;	/* index of __spd_url in tlist. -1 if not used */

	bool		agg_query;		/* aggregation flag */
	bool		isFirst;		/* First time of iteration foreign scan with
								 * aggregation query */
	bool		groupby_has_spdurl; /* flag to check if __spd_url is in group
									 * clause */

	List	   *child_comp_tlist;	/* child complite target list */
	List	   *child_tlist;	/* child target list without __spd_url */
	List	   *mapping_tlist;	/* mapping list orig and pgspider */

	List	   *groupby_target; /* group target tlist number */

	TupleTableSlot *child_comp_slot;	/* temporary slot */
	StringInfo	groupby_string; /* GROUP BY string for aggregation temp table */

	ChildInfo  *childinfo;		/* ChildInfo List */

	List	   *having_quals;	/* qualitifications for HAVING which are
								 * passed to childs */
	bool		has_having_quals;	/* Root plan has qualification applied for
									 * HAVING */
	bool		has_stub_star_regex_function;	/* mark if query has stub star
												 * regex function */
	bool		record_function;	/* mark if function return record type */

	bool		orderby_query;	/* ORDER BY flag */
	bool		limit_query;	/* LIMIT/OFFSET flag */

	CmdType		operation;

	SpdTimeMeasureInfo tm_info; /* time measure info */

	/* USE ONLY IN EXECUTION */
	pthread_t	foreign_scan_threads[NODES_MAX];	/* scan child node thread */
	pthread_t	foreign_modify_threads[NODES_MAX];	/* modify child node thread  */
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
	MemoryContext temp_cxt;		/* context for temporary data */
	pthread_rwlock_t scan_mutex;
	pthread_rwlock_t modify_mutex;
	int			startNodeId;	/* Node ID to start checking child slot for
								 * round robin */
	int			lastThreadId;	/* The index of the last thread that we get
								 * the slot from */
	SpdPendingRequest requestPendingChildThread;			/* pending request for all child thread */
	pthread_mutex_t	thread_pending_mutex;	/* mutex for pending condition */
	pthread_cond_t	thread_pending_cond;	/* pending condition */
	Oid			modify_serveroid;			/* The oid of the server that we get the slot from */
	Oid			modify_tableoid;			/* The oid of the foreign table that we get the slot from */

	/* USE ONLY IN EXECUTION OF DATA COMPRESSION TRANSFER */
	bool 		data_compression_transfer_enabled;	/* flag to determine execute data compression transfer feature */
	pthread_t	socket_server_thread;		/* socket server thread */
	SocketInfo *socketInfo;					/* socket info thread of socket server */
}			SpdFdwPrivate;

 /* in pgspider_core_deparse.c */
extern bool spd_is_foreign_expr(PlannerInfo *, RelOptInfo *, Expr *);
extern bool spd_is_having_safe(Node *node);
extern bool spd_is_sorted(Node *node);
extern void spd_deparse_const(Const *node, StringInfo buf, int showtype);
extern char *spd_deparse_type_name(Oid type_oid, int32 typemod);
extern void spd_deparse_string_literal(StringInfo buf, const char *val);
extern void spd_deparse_operator_name(StringInfo buf, Form_pg_operator opform);
extern bool spd_is_stub_star_regex_function(Expr *expr);
extern bool spd_is_record_func(List *tlist);
extern void spd_classifyConditions(PlannerInfo *root,
									RelOptInfo *baserel,
									List *input_conds,
									List **remote_conds,
									List **local_conds);
extern bool spd_expr_has_spdurl(PlannerInfo *root, Node *expr, List **target_exprs);
extern const char *spd_get_jointype_name(JoinType jointype);
extern bool exist_in_string_list(char *funcname, const char **funclist);

 /* in pgspider_core_option.c */
extern int	spdExtractConnectionOptions(List *defelems,
										const char **keywords,
										const char **values);

/* in pgspider_core_option.c */
extern int	spd_get_node_num(RelOptInfo *baserel);

/* in pgspider_core_fdw.c */
Oid spd_serverid_of_relation(Oid foreigntableid);
void spd_calculate_datasource_count(Oid foreigntableid, int *nums, Oid **oids);
void spd_servername_from_tableoid(Oid foreigntableid, char *srvname);
void spd_ip_from_server_name(char *serverName, char *ip);
List *spd_ParseUrl(List *spd_url_list);
List *spd_create_child_url(List *spd_url_list, ChildInfo *pChildInfo,
						   int node_num, bool status_is_set);

extern bool throwCandidateError;

#ifdef PD_STORED
/* in pgspider_core_remotefunc.c */
void spdExecuteFunction(Oid funcoid, Oid tableoid, List *args,
						bool async, void **private);
bool spdGetFunctionResultOne(void *private, AttInMetadata *attinmeta,
							 Datum *values, bool *nulls);
void spdFinalizeFunction(void *private);

#endif

#endif							/* PGSPIDER_CORE_FDW_H */
