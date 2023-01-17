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

#include "foreign/foreign.h"
#include "lib/stringinfo.h"
#include "nodes/pathnodes.h"
#include "utils/relcache.h"
#include "catalog/pg_operator.h"
#include "optimizer/planner.h"

/* For checking single node or multiple node */
#define SPD_SINGLE_NODE	1
#define IS_SPD_MULTI_NODES(nodenum) (nodenum > SPD_SINGLE_NODE)

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

#endif							/* PGSPIDER_CORE_FDW_H */
