/*-------------------------------------------------------------------------
 *
 * deparse.c
 *		  FDW deparsing module for pgspider_core_fdw
 *
 * Portions Copyright (c) 2018, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_core_fdw/deparse.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"
#include "postgres_fdw/postgres_fdw.h"
#include "stdbool.h"
#include "access/htup_details.h"
#include "utils/syscache.h"
#include "catalog/pg_proc.h"
#include "parser/parsetree.h"
#include "catalog/pg_namespace.h"
#include "utils/lsyscache.h"
#include "pgspider_core_fdw_defs.h"
#include "catalog/pg_type.h"
#include "nodes/nodeFuncs.h"
#include "utils/builtins.h"
#include "pgspider_core_fdw.h"

/* List of stable function with star argument of InfluxDB */
static const char *InfluxDBStableStarFunction[] = {
	"influx_count_all",
	"influx_mode_all",
	"influx_max_all",
	"influx_min_all",
	"influx_sum_all",
	"integral_all",
	"mean_all",
	"median_all",
	"spread_all",
	"stddev_all",
	"first_all",
	"last_all",
	"percentile_all",
	"sample_all",
	"abs_all",
	"acos_all",
	"asin_all",
	"atan_all",
	"atan2_all",
	"ceil_all",
	"cos_all",
	"cumulative_sum_all",
	"derivative_all",
	"difference_all",
	"elapsed_all",
	"exp_all",
	"floor_all",
	"ln_all",
	"log_all",
	"log2_all",
	"log10_all",
	"moving_average_all",
	"non_negative_derivative_all",
	"non_negative_difference_all",
	"pow_all",
	"round_all",
	"sin_all",
	"sqrt_all",
	"tan_all",
	"chande_momentum_oscillator_all",
	"exponential_moving_average_all",
	"double_exponential_moving_average_all",
	"kaufmans_efficiency_ratio_all",
	"kaufmans_adaptive_moving_average_all",
	"triple_exponential_moving_average_all",
	"triple_exponential_derivative_all",
	"relative_strength_index_all",
	NULL
};

/* List of stable function with regular expression argument of InfluxDB */
static const char *InfluxDBStableRegexFunction[] = {
	"percentile",
	"sample",
	"top",
	"cumulative_sum",
	"derivative",
	"difference",
	"elapsed",
	"moving_average",
	"non_negative_derivative",
	"non_negative_difference",
	"chande_momentum_oscillator",
	"exponential_moving_average",
	"double_exponential_moving_average",
	"kaufmans_efficiency_ratio",
	"kaufmans_adaptive_moving_average",
	"triple_exponential_moving_average",
	"triple_exponential_derivative",
	"relative_strength_index",
	NULL
};

/* List of stable agg function with regular expression argument of InfluxDB */
static const char *InfluxDBStableRegexAgg[] = {
	"influx_count",
	"influx_max",
	"influx_min",
	"influx_mode",
	"influx_sum",
	"integral",
	"mean",
	"median",
	"spread",
	"stddev",
	"first",
	"last",
	NULL
};

/* List of stable function with constant argument of GridDB */
static const char *GridDBStableConstArgFunction[] = {
	"time_next",
	"time_next_only",
	"time_prev",
	"time_prev_only",
	NULL
};

/* List of functions return record of griddb */
static const char *GridDBReturnRecordFunctions[] = {
	"time_next",
	"time_next_only",
	"time_prev",
	"time_prev_only",
	"time_interpolated",
	"max_rows",
	"min_rows",
	"time_sampling",
	NULL
};

/* List mysql aggregation stub function */
static const char *MysqlAggregateStubFunction[] = {
	"bit_xor",
	"group_concat",
	"std",
	NULL
};

/*
 * Global context for foreign_expr_walker's search of an expression tree.
 */
typedef struct foreign_glob_cxt
{
	PlannerInfo *root;			/* global planner state */
	RelOptInfo *foreignrel;		/* the foreign relation we are planning for */
	bool		hasAggref;		/* this flag is used to detect if __spd_url is
								 * inside Aggref function */
	int			node_num;		/* number of child node */
} foreign_glob_cxt;

/*
 * Local (per-tree-level) context for foreign_expr_walker's search.
 * This is concerned with identifying collations used in the expression.
 */
typedef enum
{
	FDW_COLLATE_NONE,			/* expression is of a noncollatable type, or
								 * it has default collation that is not
								 * traceable to a foreign Var */
	FDW_COLLATE_SAFE,			/* collation derives from a foreign Var */
	FDW_COLLATE_UNSAFE			/* collation is non-default and derives from
								 * something other than a foreign Var */
} FDWCollateState;

typedef struct foreign_loc_cxt
{
	Oid			collation;		/* OID of current collation, if any */
	FDWCollateState state;		/* state of current collation choice */
} foreign_loc_cxt;

/* Local function forward declarations */
static bool having_clause_tree_walker(Node *node, void *param);

/*
 * Prevent push down of T_Param(Subquery Expressions) which PGSpider cannot bind
 */
static bool
is_valid_type(Oid type)
{
	switch (type)
	{
		case BOOLOID:
			return false;
		case INT2OID:
		case INT4OID:
		case INT8OID:
		case OIDOID:
		case FLOAT4OID:
		case FLOAT8OID:
		case NUMERICOID:
		case VARCHAROID:
		case TEXTOID:
		case TIMEOID:
		case TIMESTAMPOID:
		case TIMESTAMPTZOID:
			return true;
		default:
			elog(WARNING, "Found an unexpected case when check Param type. In default pushdown this case to PGSpider");
			return true;
	}
}

/*
 * spd_is_regex_argument
 *
 * Return true if argument of function is regular expression for InfluxDB
 */
static bool
spd_is_regex_argument(Const *node)
{
	Oid			typoutput;
	bool		typIsVarlena;
	const char *extval;
	const char *first;
	const char *last;

	getTypeOutputInfo(node->consttype, &typoutput, &typIsVarlena);

	extval = OidOutputFunctionCall(typoutput, node->constvalue);
	first = extval;
	last = extval + strlen(extval) - 1;
	/* Check regex */
	if (*first == '/' && *last == '/')
		return true;
	else
		return false;
}

/*
 * Check if expression is safe to push down to remote fdw, and return true if so.
 *
 * This function was created based on deparse.c of other fdw.
 * TODO: This function is maybe missing some type of expression.
 * It should be added more later.
 *
 */
static bool
foreign_expr_walker(Node *node,
					foreign_glob_cxt *glob_cxt,
					foreign_loc_cxt *outer_cxt)
{
	foreign_loc_cxt inner_cxt;

	/* Need do nothing for empty subexpressions */
	if (node == NULL)
		return true;

	/* Set up inner_cxt for possible recursion to child nodes */
	inner_cxt.collation = InvalidOid;
	inner_cxt.state = FDW_COLLATE_NONE;

	switch (nodeTag(node))
	{
		case T_Var:
			{
				Var		   *var = (Var *) node;
				char	   *colname;
				RangeTblEntry *rte;

				/* The case of whole row. */
				if (var->varattno == 0)
					return false;

				rte = planner_rt_fetch(var->varno, glob_cxt->root);
				colname = get_attname(rte->relid, var->varattno, false);

				/* Don't pushed down __spd_url if it is inside Aggref */
				if (glob_cxt->hasAggref && strcmp(colname, SPDURL) == 0)
					return false;
				break;
			}
		case T_Aggref:
			{
				Aggref	   *aggref = (Aggref *) node;
				char	   *funcname = NULL;
				ListCell   *lc;

				/* Get function name */
				funcname = get_func_name(aggref->aggfnoid);

				/*
				 * Pushdown DISTINCT inside aggregate in single node model for
				 * mysql stub aggregate function
				 */
				if (aggref->aggdistinct != NIL)
				{
					if (IS_SPD_MULTI_NODES(glob_cxt->node_num))
					{
						return false;
					}
					else if (strcmp(funcname, "count") && !exist_in_string_list(funcname, MysqlAggregateStubFunction))
					{
						return false;
					}
				}

				/* Set the flag if detected Aggref function */
				glob_cxt->hasAggref = true;

				/*
				 * Recurse to input args. Don't pushed down __spd_url.
				 */
				foreach(lc, aggref->args)
				{
					Node	   *n = (Node *) lfirst(lc);

					/* If TargetEntry, extract the expression from it */
					if (IsA(n, TargetEntry))
					{
						TargetEntry *tle = (TargetEntry *) n;

						n = (Node *) tle->expr;
					}

					if (!foreign_expr_walker(n, glob_cxt, &inner_cxt))
					{
						/* Reset the flag for next recursive check */
						glob_cxt->hasAggref = false;
						return false;
					}
				}

				/* Reset the flag for next recursive check */
				glob_cxt->hasAggref = false;

				/*
				 * The aggregate functions array_agg, json_agg, jsonb_agg,
				 * json_object_agg, jsonb_object_agg, as well as similar
				 * user-defined aggregate functions, produce meaningfully
				 * different result values depending on the order of the input
				 * values. It is hard to control the order of input value in
				 * PGSpider temp table. So, we change there aggregate
				 * functions to not pushdown to FDW
				 */
				if (strcmp(funcname, "array_agg") == 0 ||
					strcmp(funcname, "json_agg") == 0 ||
					strcmp(funcname, "jsonb_agg") == 0 ||
					strcmp(funcname, "json_object_agg") == 0 ||
					strcmp(funcname, "jsonb_object_agg") == 0)
				{
					if (IS_SPD_MULTI_NODES(glob_cxt->node_num))
						return false;
				}
				if (strcmp(funcname, "string_agg") == 0 ||
					strcmp(funcname, "xmlagg") == 0)
				{
					/*
					 * The aggregate functions string_agg, and xmlagg, are not
					 * pushdown to FDW when has ORDER BY
					 */
					if (aggref->aggorder != NIL)
						return false;

					/*
					 * The aggregate functions string_agg is not pushdown to
					 * FDW when the delimiter is not a constant.
					 */
					if (strcmp(funcname, "string_agg") == 0)
					{
						TargetEntry *tle = (TargetEntry *) lsecond(aggref->args);
						Node	   *node = (Node *) tle->expr;

						if (!IsA(node, Const))
							return false;
					}
				}
				if (IS_SPD_MULTI_NODES(glob_cxt->node_num))
				{
					/*
					 * Do not push down specific stub aggregate function for
					 * mysql remote
					 */
					if (exist_in_string_list(funcname, MysqlAggregateStubFunction))
						return false;

					/*
					 * Do not push down star regex function of InfluxDB when
					 * there are multiple nodes
					 */
					if (spd_is_stub_star_regex_function((Expr *) node))
						return false;
				}
				break;
			}
		case T_List:
			{
				List	   *l = (List *) node;
				ListCell   *lc;

				/*
				 * Recurse to component subexpressions.
				 */
				foreach(lc, l)
				{
					if (!foreign_expr_walker((Node *) lfirst(lc), glob_cxt, &inner_cxt))
						return false;
				}
				break;
			}
		case T_FuncExpr:
			{
				FuncExpr   *func = (FuncExpr *) node;

				/*
				 * If having a single node, pushdown function expression. If
				 * it is regular expression function or star function of
				 * InfluxDB, pushdown function expression. Otherwise not
				 * pushdown.
				 */
				if ((func->funcformat == COERCE_EXPLICIT_CALL) && IS_SPD_MULTI_NODES(glob_cxt->node_num))
				{
					if (!spd_is_stub_star_regex_function((Expr *) node))
						return false;
				}

				if (!foreign_expr_walker((Node *) func->args, glob_cxt, &inner_cxt))
					return false;
				break;
			}
		case T_OpExpr:
			{
				OpExpr	   *oe = (OpExpr *) node;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) oe->args, glob_cxt, &inner_cxt))
					return false;
				break;
			}
		case T_Param:
			{
				Param	   *p = (Param *) node;

				/* Check type of T_Param(Subquery Expressions) */
				if (!is_valid_type(p->paramtype))
					return false;
				break;
			}
		case T_BoolExpr:
			{
				BoolExpr   *b = (BoolExpr *) node;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) b->args, glob_cxt, &inner_cxt))
					return false;
				break;
			}
		case T_FieldSelect:
			{
				/*
				 * Do not allow to push down when there are multiple nodes
				 */
				if (IS_SPD_MULTI_NODES(glob_cxt->node_num))
					return false;
				break;
			}
		case T_RowExpr:
			{
				/*
				 * Enable to support push down on Mysql
				 */
				break;
			}
		default:
			break;
	}

	/* It looks OK */
	return true;
}

bool
spd_is_foreign_expr(PlannerInfo *root, RelOptInfo *baserel, Expr *expr)
{
	foreign_glob_cxt glob_cxt;
	foreign_loc_cxt loc_cxt;

	/*
	 * Check that the expression consists of nodes that are safe to execute
	 * remotely.
	 */
	glob_cxt.root = root;
	glob_cxt.foreignrel = baserel;
	glob_cxt.hasAggref = false;
	glob_cxt.node_num = spd_get_node_num(baserel);
	loc_cxt.collation = InvalidOid;
	loc_cxt.state = FDW_COLLATE_NONE;

	if (!foreign_expr_walker((Node *) expr, &glob_cxt, &loc_cxt))
		return false;

	return true;
}

/*
 * Append a SQL string literal representing "val" to buf.
 */
void
spd_deparse_string_literal(StringInfo buf, const char *val)
{
	const char *valptr;

	/*
	 * Rather than making assumptions about the remote server's value of
	 * standard_conforming_strings, always use E'foo' syntax if there are any
	 * backslashes.  This will fail on remote servers before 8.1, but those
	 * are long out of support.
	 */
	if (strchr(val, '\\') != NULL)
		appendStringInfoChar(buf, ESCAPE_STRING_SYNTAX);
	appendStringInfoChar(buf, '\'');
	for (valptr = val; *valptr; valptr++)
	{
		char		ch = *valptr;

		if (SQL_STR_DOUBLE(ch, true))
			appendStringInfoChar(buf, ch);
		appendStringInfoChar(buf, ch);
	}
	appendStringInfoChar(buf, '\'');
}

/*
 * having_clause_tree_walker
 *
 * Check if HAVING expression is safe to pass to child fdws.
 */
static bool
having_clause_tree_walker(Node *node, void *param)
{
	/* Need do nothing for empty subexpression. */
	if (node == NULL)
		return false;

	switch (nodeTag(node))
	{
		case T_Aggref:
			{
				/*
				 * Do not pass to child fdw when HAVING clause contains
				 * aggregate functions
				 */
				return true;
			}
		case T_FuncExpr:
		case T_OpExpr:
			{
				List	   *args = NIL;
				ListCell   *lc;

				if (IsA(node, FuncExpr))
					args = ((FuncExpr *) node)->args;
				else
					args = ((OpExpr *) node)->args;

				foreach(lc, args)
				{
					Expr	   *arg = (Expr *) lfirst(lc);

					if (!(IsA(arg, BoolExpr) || IsA(arg, FuncExpr) || IsA(arg, List)))
					{
						if (!(IsA(arg, Aggref) || IsA(arg, Var) || IsA(arg, Const)))
							return true;
					}
				}
				break;
			}
		default:
			break;
	}

	return expression_tree_walker(node, having_clause_tree_walker, (void *) param);
}

/*
 * spd_is_having_safe
 *
 * Check every conditions whether expression
 * is safe to pass to child FDW or not.
 */
bool
spd_is_having_safe(Node *node)
{
	return (!having_clause_tree_walker(node, NULL));
}

/*
 * order_by_walker
 *
 * Check if HAVING expression is safe to pass to child fdws.
 */
static bool
order_by_walker(Node *node, void *param)
{
	/* Need do nothing for empty subexpression. */
	if (node == NULL)
		return false;

	switch (nodeTag(node))
	{
		case T_Aggref:
			{
				Aggref	   *agg = (Aggref *) node;

				if (agg->aggorder)
					return true;
				break;
			}
		default:
			break;
	}

	return expression_tree_walker(node, order_by_walker, (void *) param);
}

/*
 * spd_is_sorted
 *
 * Check if expression contains aggregation with ORDER BY
 */
bool
spd_is_sorted(Node *node)
{
	return (order_by_walker(node, NULL));
}

/*
 *	Convert type OID + typmod info into a type name
 */
char *
spd_deparse_type_name(Oid type_oid, int32 typemod)
{
	bits16		flags = FORMAT_TYPE_TYPEMOD_GIVEN;

	return format_type_extended(type_oid, typemod, flags);
}


/*
 * Deparse given constant value into buf.
 *
 * This function has to be kept in sync with ruleutils.c's get_const_expr.
 * As for that function, showtype can be -1 to never show "::typename" decoration,
 * or +1 to always show it, or 0 to show it only if the constant wouldn't be assumed
 * to be the right type by default.
 */
void
spd_deparse_const(Const *node, StringInfo buf, int showtype)
{
	Oid			typoutput;
	bool		typIsVarlena;
	char	   *extval;
	bool		isfloat = false;
	bool		needlabel;

	if (node->constisnull)
	{
		appendStringInfoString(buf, "NULL");
		if (showtype >= 0)
			appendStringInfo(buf, "::%s",
							 spd_deparse_type_name(node->consttype,
												   node->consttypmod));
		return;
	}

	getTypeOutputInfo(node->consttype,
					  &typoutput, &typIsVarlena);
	extval = OidOutputFunctionCall(typoutput, node->constvalue);

	switch (node->consttype)
	{
		case INT2OID:
		case INT4OID:
		case INT8OID:
		case OIDOID:
		case FLOAT4OID:
		case FLOAT8OID:
		case NUMERICOID:
			{
				/*
				 * No need to quote unless it's a special value such as 'NaN'.
				 * See comments in get_const_expr().
				 */
				if (strspn(extval, "0123456789+-eE.") == strlen(extval))
				{
					if (extval[0] == '+' || extval[0] == '-')
						appendStringInfo(buf, "(%s)", extval);
					else
						appendStringInfoString(buf, extval);
					if (strcspn(extval, "eE.") != strlen(extval))
						isfloat = true; /* it looks like a float */
				}
				else
					appendStringInfo(buf, "'%s'", extval);
			}
			break;
		case BITOID:
		case VARBITOID:
			appendStringInfo(buf, "B'%s'", extval);
			break;
		case BOOLOID:
			if (strcmp(extval, "t") == 0)
				appendStringInfoString(buf, "true");
			else
				appendStringInfoString(buf, "false");
			break;
		default:
			spd_deparse_string_literal(buf, extval);
			break;
	}

	pfree(extval);

	if (showtype < 0)
		return;

	/*
	 * For showtype == 0, append ::typename unless the constant will be
	 * implicitly typed as the right type when it is read in.
	 *
	 * XXX this code has to be kept in sync with the behavior of the parser,
	 * especially make_const.
	 */
	switch (node->consttype)
	{
		case BOOLOID:
		case INT4OID:
		case UNKNOWNOID:
			needlabel = false;
			break;
		case NUMERICOID:
			needlabel = !isfloat || (node->consttypmod >= 0);
			break;
		default:
			needlabel = true;
			break;
	}
	if (needlabel || showtype > 0)
		appendStringInfo(buf, "::%s",
						 spd_deparse_type_name(node->consttype,
											   node->consttypmod));
}

/*
 * Print the name of an operator.
 */
void
spd_deparse_operator_name(StringInfo buf, Form_pg_operator opform)
{
	char	   *opname;

	/* opname is not a SQL identifier, so we should not quote it. */
	opname = NameStr(opform->oprname);

	/* Print schema name only if it's not pg_catalog */
	if (opform->oprnamespace != PG_CATALOG_NAMESPACE)
	{
		const char *opnspname;

		opnspname = get_namespace_name(opform->oprnamespace);
		/* Print fully qualified operator name. */
		appendStringInfo(buf, "OPERATOR(%s.%s)",
						 quote_identifier(opnspname), opname);
	}
	else
	{
		/* Just print operator name. */
		appendStringInfoString(buf, opname);
	}
}

/*
 * Return true if string existed in list of string
 */
bool
exist_in_string_list(char *str, const char **strlist)
{
	int			i;

	for (i = 0; strlist[i]; i++)
	{
		if (strcmp(str, strlist[i]) == 0)
			return true;
	}
	return false;
}

/*
 * spd_is_stub_star_regex_function
 *
 * Return true if function is regular expression function or star function
 */
bool
spd_is_stub_star_regex_function(Expr *expr)
{
	char	   *opername = NULL;
	ListCell   *lc;

	/* Need do nothing for empty subexpressions */
	if (expr == NULL)
		return false;

	switch (nodeTag(expr))
	{
		case T_Aggref:
			{
				Aggref	   *agg = (Aggref *) expr;

				/* Get function name */
				opername = get_func_name(agg->aggfnoid);

				if ((strlen(opername) > 4) &&
					(strcmp(opername + strlen(opername) - 4, "_all") == 0))
				{
					/* Check stable function with star argument of InfluxDB */
					if (exist_in_string_list(opername, InfluxDBStableStarFunction))
						return true;
				}

				foreach(lc, agg->args)
				{
					Node	   *n = (Node *) lfirst(lc);

					/* If TargetEntry, extract the expression from it */
					if (IsA(n, TargetEntry))
					{
						TargetEntry *tle = (TargetEntry *) n;

						n = (Node *) tle->expr;

						if (IsA(n, Const))
						{
							Const	   *arg = (Const *) n;

							if (arg->consttype == TEXTOID && spd_is_regex_argument(arg))
								return exist_in_string_list(opername, InfluxDBStableRegexAgg);
						}
					}
				}
				break;
			}
		case T_FuncExpr:
			{
				FuncExpr   *fe = (FuncExpr *) expr;

				/* Get function name */
				opername = get_func_name(fe->funcid);

				if ((strlen(opername) > 4) &&
					(strcmp(opername + strlen(opername) - 4, "_all") == 0))
				{
					/* Check stable function with star argument of InfluxDB */
					if (exist_in_string_list(opername, InfluxDBStableStarFunction))
						return true;
				}

				/* Check stable function with constant argument of GridDB */
				if (exist_in_string_list(opername, GridDBStableConstArgFunction))
					return true;

				if (list_length(fe->args) > 0)
				{
					ListCell   *funclc;
					Node	   *firstArg;

					funclc = list_head(fe->args);
					firstArg = (Node *) lfirst(funclc);

					if (IsA(firstArg, Const))
					{
						Const	   *arg = (Const *) firstArg;

						if (arg->consttype == TEXTOID && spd_is_regex_argument(arg))
							return exist_in_string_list(opername, InfluxDBStableRegexFunction);
					}
				}
				break;
			}
		default:
			break;
	}

	return false;
}

/*
 * Return true if tlist has star or regex function
 */
bool
spd_is_record_func(List *tlist)
{
	ListCell   *lc;

	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);
		Oid			funcid;
		Oid			returntype;
		List	   *args;
		char	   *opername;

		if (IsA((Node *) tle->expr, FuncExpr))
		{
			funcid = ((FuncExpr *) tle->expr)->funcid;
			returntype = ((FuncExpr *) tle->expr)->funcresulttype;
			args = ((FuncExpr *) tle->expr)->args;
		}
		else if (IsA((Node *) tle->expr, Aggref))
		{
			funcid = ((Aggref *) tle->expr)->aggfnoid;
			returntype = ((Aggref *) tle->expr)->aggtype;
			args = ((Aggref *) tle->expr)->args;
		}
		else
			return false;

		if ((funcid >= FirstGenbkiObjectId && returntype == TEXTOID))
		{
			ListCell   *funclc;
			Node	   *firstArg;

			opername = get_func_name(funcid);

			/* Check stable function return record of GridDB */
			if (exist_in_string_list(opername, GridDBReturnRecordFunctions))
				return true;

			/* check stable agg with regex argument of InfluxDB */
			if (exist_in_string_list(opername, InfluxDBStableRegexAgg))
				return true;

			if (list_length(args) > 0)
			{
				funclc = list_head(args);
				firstArg = (Node *) lfirst(funclc);
				/* Check stable function with regex argument of InfluxDB */
				if (IsA(firstArg, Const))
				{
					Const	   *arg = (Const *) firstArg;

					if (spd_is_regex_argument(arg))
						return exist_in_string_list(opername, InfluxDBStableRegexFunction);
				}
			}

			if ((strlen(opername) > 4) &&
				(strcmp(opername + strlen(opername) - 4, "_all") == 0))
			{
				/* Check stable function with star argument of InfluxDB */
				if (exist_in_string_list(opername, InfluxDBStableStarFunction))
					return true;
			}
		}
	}

	return false;
}

/* Examine each qual clause in input_conds, and classify them into two groups,
 * which are returned as two lists:
 *	- remote_conds contains expressions that can be evaluated remotely
 *	- local_conds contains expressions that can't be evaluated remotely
 */
void
spd_classifyConditions(PlannerInfo *root,
						RelOptInfo *baserel,
						List *input_conds,
						List **remote_conds,
						List **local_conds)
{
	ListCell   *lc;

	*remote_conds = NIL;
	*local_conds = NIL;

	foreach(lc, input_conds)
	{
		RestrictInfo *clause = (RestrictInfo *) lfirst(lc);
		Expr	   *expr = (Expr *) clause->clause;

		if (spd_expr_has_spdurl(root, (Node *) expr, NULL))
		{
			/*
			 * If it contains SPDURL, we append it to local_conds list.
			 * upper relation uses local_conds will be used to check whether it is safe or not.
			 */
			*local_conds = lappend(*local_conds, clause);
		}
		else
		{
			/* If it does not contain SPDURL, we append it to remote_conds list. */
			*remote_conds = lappend(*remote_conds, clause);
		}
	}
}

/* Output join name for given join type */
const char *
spd_get_jointype_name(JoinType jointype)
{
	switch (jointype)
	{
		case JOIN_INNER:
			return "INNER";

		case JOIN_LEFT:
			return "LEFT";

		case JOIN_RIGHT:
			return "RIGHT";

		case JOIN_FULL:
			return "FULL";

		default:
			/* Shouldn't come here, but protect from buggy code. */
			elog(ERROR, "unsupported join type %d", jointype);
	}

	/* Keep compiler happy */
	return NULL;
}
