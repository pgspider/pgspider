/*-------------------------------------------------------------------------
 *
 * pgspider_fdw.h
 *		  Foreign-data wrapper for remote PGSpider servers
 *
 * Portions Copyright (c) 2012-2023, PostgreSQL Global Development Group
 * Portions Copyright (c) 2018, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/pgspider_fdw.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef PGSPIDER_FDW_H
#define PGSPIDER_FDW_H

#include "foreign/foreign.h"
#include "funcapi.h"
#include "lib/stringinfo.h"
#include "libpq-fe.h"
#include "nodes/execnodes.h"
#include "nodes/pathnodes.h"
#include "utils/relcache.h"


/*
 * FDW-specific planner information kept in RelOptInfo.fdw_private for a
 * pgspider_fdw foreign table.  For a baserel, this struct is created by
 * pgspiderGetForeignRelSize, although some fields are not filled till later.
 * pgspiderGetForeignJoinPaths creates it for a joinrel, and
 * pgspiderGetForeignUpperPaths creates it for an upperrel.
 */
typedef struct PGSpiderFdwRelationInfo
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

	/* Bitmap of attr numbers we need to fetch from the remote server. */
	Bitmapset  *attrs_used;

	/* True means that the query_pathkeys is safe to push down */
	bool		qp_is_pushdown_safe;

	/* Cost and selectivity of local_conds. */
	QualCost	local_conds_cost;
	Selectivity local_conds_sel;

	/* Selectivity of join conditions */
	Selectivity joinclause_sel;

	/* Estimated size and cost for a scan, join, or grouping/aggregation. */
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;

	/*
	 * Estimated number of rows fetched from the foreign server, and costs
	 * excluding costs for transferring those rows from the foreign server.
	 * These are only used by estimate_path_cost_size().
	 */
	double		retrieved_rows;
	Cost		rel_startup_cost;
	Cost		rel_total_cost;

	/* Options extracted from catalogs. */
	bool		use_remote_estimate;
	Cost		fdw_startup_cost;
	Cost		fdw_tuple_cost;
	List	   *shippable_extensions;	/* OIDs of shippable extensions */
	bool		async_capable;

	/* Cached catalog information. */
	ForeignTable *table;
	ForeignServer *server;
	UserMapping *user;			/* only set in use_remote_estimate mode */

	int			fetch_size;		/* fetch size for this remote table */

	/*
	 * Name of the relation, for use while EXPLAINing ForeignScan.  It is used
	 * for join and upper relations but is set for all relations.  For a base
	 * relation, this is really just the RT index as a string; we convert that
	 * while producing EXPLAIN output.  For join and upper relations, the name
	 * indicates which base foreign tables are included and the join type or
	 * aggregation type used.
	 */
	char	   *relation_name;

	/* Join information */
	RelOptInfo *outerrel;
	RelOptInfo *innerrel;
	JoinType	jointype;
	/* joinclauses contains only JOIN/ON conditions for an outer join */
	List	   *joinclauses;	/* List of RestrictInfo */

	/* Upper relation information */
	UpperRelationKind stage;

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

	/* Function pushdown support in target list */
	bool		is_tlist_func_pushdown;
}			PGSpiderFdwRelationInfo;

/*
 * Extra control information relating to a connection.
 */
typedef struct PGSpiderFdwConnState
{
	AsyncRequest *pendingAreq;	/* pending async request */
}			PGSpiderFdwConnState;

/*
 * Information about NAT network settings
 */
typedef struct PGSpiderPublicHostInfo
{
	char *public_host;
	int   public_port;
	char *ifconfig_service;
}           PGSpiderPublicHostInfo;

/*
 * Method used by ANALYZE to sample remote rows.
 */
typedef enum PGSpiderFdwSamplingMethod
{
	ANALYZE_SAMPLE_OFF,			/* no remote sampling */
	ANALYZE_SAMPLE_AUTO,		/* choose by server version */
	ANALYZE_SAMPLE_RANDOM,		/* remote random() */
	ANALYZE_SAMPLE_SYSTEM,		/* TABLESAMPLE system */
	ANALYZE_SAMPLE_BERNOULLI	/* TABLESAMPLE bernoulli */
} PGSpiderFdwSamplingMethod;

/*
 * Execution state of a foreign insert/update/delete operation.
 */
typedef struct PGSpiderFdwModifyState
{
	SocketThreadInfo socketThreadInfo;	/* shared socket thread info */

	Relation	rel;			/* relcache entry for the foreign table */
	AttInMetadata *attinmeta;	/* attribute datatype conversion metadata */

	/* for remote query execution */
	PGconn	   *conn;			/* connection for the scan */
	PGSpiderFdwConnState *conn_state;	/* extra per-connection state */
	char	   *p_name;			/* name of prepared statement, if created */

	/* extracted fdw_private data */
	char	   *query;			/* text of INSERT/UPDATE/DELETE command */
	char	   *orig_query;		/* original text of INSERT command */
	List	   *target_attrs;	/* list of target attribute numbers */
	int			values_end;		/* length up to the end of VALUES */
	int			batch_size;		/* value of FDW option "batch_size" */
	bool		has_returning;	/* is there a RETURNING clause? */
	List	   *retrieved_attrs;	/* attr numbers retrieved by RETURNING */

	/* info about parameters for prepared statement */
	AttrNumber	ctidAttno;		/* attnum of input resjunk ctid column */
	int			p_nums;			/* number of parameters to transmit */
	FmgrInfo   *p_flinfo;		/* output conversion functions for them */

	/* batch operation stuff */
	int			num_slots;		/* number of slots to insert */

	/* working memory context */
	MemoryContext temp_cxt;		/* context for per-tuple temporary data */

	/* for update row movement if subplan result rel */
	struct PGSpiderFdwModifyState *aux_fmstate; /* foreign-insert state, if
												 * created */
	int			socket_port;		/* port of socket server */
	int			function_timeout;	/* timeout to rest API request */
	pthread_t	socket_thread;	/* child thread to send insertion data */
	bool		data_compression_transfer_enabled;	/* true if data compression transfer
											 * feature is used */
	PGSpiderPublicHostInfo *public_host_info; /* public host info if db are behide the NAT */
}			PGSpiderFdwModifyState;

/* in pgspider_fdw.c */
extern int	pgspider_set_transmission_modes(void);
extern void pgspider_reset_transmission_modes(int nestlevel);
extern void pgspider_process_pending_request(AsyncRequest *areq);

/* in connection.c */
extern PGconn *PGSpiderGetConnection(UserMapping *user, bool will_prep_stmt,
							 PGSpiderFdwConnState * *state);
extern void PGSpiderReleaseConnection(PGconn *conn);
extern unsigned int PGSpiderGetCursorNumber(PGconn *conn);
extern unsigned int PGSpiderGetPrepStmtNumber(PGconn *conn);
extern void do_sql_command(PGconn *conn, const char *sql);
extern PGresult *pgspiderfdw_get_result(PGconn *conn, const char *query);
extern PGresult *pgspiderfdw_exec_query(PGconn *conn, const char *query,
								  PGSpiderFdwConnState * state);
extern void pgspiderfdw_report_error(int elevel, PGresult *res, PGconn *conn,
							   bool clear, const char *sql);

/* in option.c */
extern int	PGSpiderExtractConnectionOptions(List *defelems,
									 const char **keywords,
									 const char **values);
extern List *PGSpiderExtractExtensionList(const char *extensionsString,
								  bool warnOnMissing);
extern char *process_pgfdw_appname(const char *appname);
extern char *pgfdw_application_name;

/* in deparse.c */
extern void PGSpiderClassifyConditions(PlannerInfo *root,
							   RelOptInfo *baserel,
							   List *input_conds,
							   List **remote_conds,
							   List **local_conds);
extern bool pgspider_is_foreign_expr(PlannerInfo *root,
							RelOptInfo *baserel,
							Expr *expr);
extern bool pgspider_is_foreign_param(PlannerInfo *root,
							 RelOptInfo *baserel,
							 Expr *expr);
extern bool pgspider_is_foreign_pathkey(PlannerInfo *root,
							   RelOptInfo *baserel,
							   PathKey *pathkey);
extern void PGSpiderDeparseInsertSql(StringInfo buf, RangeTblEntry *rte,
							 Index rtindex, Relation rel,
							 List *targetAttrs, bool doNothing,
							 List *withCheckOptionList, List *returningList,
							 List **retrieved_attrs, int *values_end_len);
extern void PGSpiderRebuildInsertSql(StringInfo buf, Relation rel,
							 char *orig_query, List *target_attrs,
							 int values_end_len, int num_params,
							 int num_rows);
extern void PGSpiderDeparseUpdateSql(StringInfo buf, RangeTblEntry *rte,
							 Index rtindex, Relation rel,
							 List *targetAttrs,
							 List *withCheckOptionList, List *returningList,
							 List **retrieved_attrs);
extern void PGSpiderDeparseDirectUpdateSql(StringInfo buf, PlannerInfo *root,
								   Index rtindex, Relation rel,
								   RelOptInfo *foreignrel,
								   List *targetlist,
								   List *targetAttrs,
								   List *remote_conds,
								   List **params_list,
								   List *returningList,
								   List **retrieved_attrs);
extern void PGSpiderDeparseDeleteSql(StringInfo buf, RangeTblEntry *rte,
							 Index rtindex, Relation rel,
							 List *returningList,
							 List **retrieved_attrs);
extern void PGSpiderDeparseDirectDeleteSql(StringInfo buf, PlannerInfo *root,
								   Index rtindex, Relation rel,
								   RelOptInfo *foreignrel,
								   List *remote_conds,
								   List **params_list,
								   List *returningList,
								   List **retrieved_attrs);
extern void PGSpiderDeparseAnalyzeSizeSql(StringInfo buf, Relation rel);
extern void PGSpiderDeparseAnalyzeInfoSql(StringInfo buf, Relation rel);
extern void PGSpiderDeparseAnalyzeSql(StringInfo buf, Relation rel,
							  PGSpiderFdwSamplingMethod sample_method,
							  double sample_frac,
							  List **retrieved_attrs);
extern void PGSpiderDeparseTruncateSql(StringInfo buf,
							   List *rels,
							   DropBehavior behavior,
							   bool restart_seqs);
extern void PGSpiderDeparseStringLiteral(StringInfo buf, const char *val);
extern EquivalenceMember *pgspider_find_em_for_rel(PlannerInfo *root,
										  EquivalenceClass *ec,
										  RelOptInfo *rel);
extern EquivalenceMember *pgspider_find_em_for_rel_target(PlannerInfo *root,
												 EquivalenceClass *ec,
												 RelOptInfo *rel);
extern List *pgspider_build_tlist_to_deparse(RelOptInfo *foreignrel);
extern void PGSpiderDeparseSelectStmtForRel(StringInfo buf, PlannerInfo *root,
									RelOptInfo *rel, List *tlist,
									List *remote_conds, List *pathkeys,
									bool has_final_sort, bool has_limit,
									bool is_subquery,
									List **retrieved_attrs, List **params_list);
extern const char *pgspider_get_jointype_name(JoinType jointype);

/* in shippable.c */
extern bool pgspider_is_builtin(Oid objectId, Oid classId);
extern bool pgspider_is_shippable(Oid objectId, Oid classId, PGSpiderFdwRelationInfo * fpinfo);

extern bool pgspider_is_foreign_function_tlist(PlannerInfo *root,
											   RelOptInfo *baserel,
											   List *tlist);
extern List *pgspider_pull_func_clause(Node *node);

extern PGDLLEXPORT int	ExecForeignDDL(Oid serverOid,
						   Relation rel,
						   int operation,
						   bool if_not_exists);

#endif							/* PGSPIDER_FDW_H */
