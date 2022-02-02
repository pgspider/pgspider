/*-------------------------------------------------------------------------
 *
 * pgspider_fdw.h
 *		  Foreign-data wrapper for remote PGSpider servers
 *
 * Portions Copyright (c) 2012-2020, PostgreSQL Global Development Group
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/pgspider_fdw.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef PGSPIDER_FDW_H
#define PGSPIDER_FDW_H

#include "foreign/foreign.h"
#include "lib/stringinfo.h"
#include "libpq-fe.h"
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
	List	   *shippable_extensions;	/* OIDs of whitelisted extensions */

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

	/* Function pushdown surppot in target list */
	bool		is_tlist_func_pushdown;
}			PGSpiderFdwRelationInfo;

/* in pgspider_fdw.c */
extern int	pgspider_set_transmission_modes(void);
extern void pgspider_reset_transmission_modes(int nestlevel);

/* in connection.c */
extern PGconn *PGSpiderGetConnection(UserMapping *user, bool will_prep_stmt);
extern void PGSpiderReleaseConnection(PGconn *conn);
extern unsigned int PGSpiderGetCursorNumber(PGconn *conn);
extern unsigned int PGSpiderGetPrepStmtNumber(PGconn *conn);
extern PGresult * pgspiderfdw_get_result(PGconn *conn, const char *query);
extern PGresult * pgspiderfdw_exec_query(PGconn *conn, const char *query);
extern void pgspiderfdw_report_error(int elevel, PGresult *res, PGconn *conn,
							   bool clear, const char *sql);

/* in option.c */
extern int	PGSpiderExtractConnectionOptions(List *defelems,
									 const char **keywords,
									 const char **values);
extern List *PGSpiderExtractExtensionList(const char *extensionsString,
								  bool warnOnMissing);

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
extern void PGSpiderDeparseInsertSql(StringInfo buf, RangeTblEntry *rte,
							 Index rtindex, Relation rel,
							 List *targetAttrs, bool doNothing,
							 List *withCheckOptionList, List *returningList,
							 List **retrieved_attrs);
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
extern void PGSpiderDeparseAnalyzeSql(StringInfo buf, Relation rel,
							  List **retrieved_attrs);
extern void PGSpiderDeparseStringLiteral(StringInfo buf, const char *val);
extern Expr *find_em_expr_for_rel(EquivalenceClass *ec, RelOptInfo *rel);
extern Expr *pgspider_find_em_expr_for_input_target(PlannerInfo *root,
										   EquivalenceClass *ec,
										   PathTarget *target);
extern List *pgspider_build_tlist_to_deparse(RelOptInfo *foreignrel);
extern void PGSpiderDeparseSelectStmtForRel(StringInfo buf, PlannerInfo *root,
									RelOptInfo *foreignrel, List *tlist,
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
#endif							/* PGSPIDER_FDW_H */
