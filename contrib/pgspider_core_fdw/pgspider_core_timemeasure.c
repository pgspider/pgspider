/*-------------------------------------------------------------------------
 *
 * pgspider_core_timemeasure.c
 *		  Source code of pgspider_core_timemeasure
 *
 * Portions Copyright (c) 2022, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_core_fdw/pgspider_core_timemeasure.c
 *
 *-------------------------------------------------------------------------
 */

#include <time.h>

#include "postgres.h"
#include "c.h"
#include "fmgr.h"

#include "lib/stringinfo.h"
#include "portability/instr_time.h"
#include "commands/defrem.h"
#include "foreign/foreign.h"
#include "pgspider_core_timemeasure.h"

/* log level for debug code in this file */
#define SPD_TM_LOG_LEVEL DEBUG1

/* local function forward declarations */
static void spd_tm_init_parent_iteration_info(SpdTmIntegrationTimeInfo * time_info);
static void spd_tm_init_child_iteration_info(SpdTmIntegrationTimeInfoChild * time_info);
static SpdTmTimeSet * spd_tm_get_time_pointer(SpdTimeMeasureInfo * info, int id, SpdTmTimeID time_id);
static SpdTmTimeSet * spd_tm_get_time_pointer_verbose(SpdTimeMeasureInfo * info, int id, SpdTmTimeID time_id, int rescan_num);
static void spd_tm_time_set_current(SpdTmTime * time);
static void spd_tm_accum_diff_for_spdtmtime(SpdTmTimeSet * target);
static void spd_tm_add_string_info_base(StringInfoData *buf, char *title, SpdTmTime time);
static void spd_tm_add_string_info(StringInfoData *buf, char *title, SpdTmTime time);
static void spd_tm_add_string_info_with_times(StringInfoData *buf, char *title, SpdTmTime time, int times);
static void append_table_name(StringInfoData *buf, SpdTimeMeasureInfo * info);

/**
 * spd_tm_init
 *
 * Initializes the value of the variable pointed to by the address passed as an argument,
 * and creates a storage location for data for child threads.
 *
 * Assuming that info's member valiables mode and thread_num are assigned a value
 * before this funcion is called.
 *
 * @param[in,out] info SpdTimeMeasureInfo
 */
void
spd_tm_init(SpdTimeMeasureInfo * info)
{
	if (info->mode == SPD_TM_MODE_QUIET)
		return;

	/* Initialize */
	info->parent_total_iteratescan_num = 0;
	info->parent_rescan_num = 0;
	info->parent_iteratescan_info = (SpdTmIntegrationTimeInfo *) palloc0(sizeof(SpdTmIntegrationTimeInfo) * 1);

	/* Reserve a data storage location for child threads */
	info->child_threads = (SpdTmChildThreadInfo *) palloc0(sizeof(SpdTmChildThreadInfo) * (info->thread_num + 1));
	for (int i = 0; i < info->thread_num; i++)
	{
		info->child_threads[i].iteratescan_info = (SpdTmIntegrationTimeInfoChild *) palloc0(sizeof(SpdTmIntegrationTimeInfoChild) * 1);
	}

	/* Record the start time of the parent thread */
	spd_tm_time_set_current(&info->parent_start_time);
}


/**
 * spd_tm_serialize_info
 *
 * Adds the members of the SpdTimeMeasureInfo to lfdw_private and returns.
 * Assumed to be called from spd_SerializeSpdFdwPrivate.
 *
 * @param[in] info SpdTimeMeasureInfo to be serialized
 * @param[in, out] lfdw_private Serialized list
 */
void
spd_tm_serialize_info(SpdTimeMeasureInfo * info, List *lfdw_private)
{
	lfdw_private = lappend(lfdw_private, makeInteger(info->thread_num));
	lfdw_private = lappend(lfdw_private, makeInteger(info->mode));
	lfdw_private = lappend(lfdw_private, makeString(info->table_name));
	lfdw_private = lappend(lfdw_private, makeString(info->ref_name));
}

/**
 * spd_tm_deserialize_info
 *
 * Takes the members of the SpdTimeMeasureInfo from lfdw_private and returns.
 * Assumed to be called from spd_DeserializeSpdFdwPrivate.
 *
 * @param[in,out] info SpdTimeMeasureInfo to be serialized
 * @param[in] lfdw_private Serialized list
 * @param[in,out] lc ListCell
 */
void
spd_tm_deserialize_info(SpdTimeMeasureInfo * info, List *lfdw_private, ListCell *lc)
{
	info->thread_num = intVal(lfirst(lc));
	lc = lnext(lfdw_private, lc);
	info->mode = intVal(lfirst(lc));
	lc = lnext(lfdw_private, lc);
	info->table_name = strVal(lfirst(lc));
	lc = lnext(lfdw_private, lc);
	info->ref_name = strVal(lfirst(lc));
	lc = lnext(lfdw_private, lc);
}

/**
 * spd_tm_count_iterateforeignscan
 *
 * Increment the number of IterationForeignScan calls.
 * For id, specify SPD_TM_PARENT_ID or the index of the child thread.
 *
 * @param[in,out] info SpdTimeMeasureInfo
 * @param[in] id SPD_TM_PARENT_ID or index of child thread
 */
void
spd_tm_count_iterateforeignscan(SpdTimeMeasureInfo * info, int id)
{
	if (info->mode == SPD_TM_MODE_QUIET)
		return;

	if (id == SPD_TM_PARENT_ID)
	{
		info->parent_total_iteratescan_num++;
		info->parent_iteratescan_info[info->parent_rescan_num].called_times++;
		ereport(SPD_TM_LOG_LEVEL, (errmsg_internal("%p: parent iteratescan_num: %d", info, info->parent_total_iteratescan_num)), errhidestmt(true));
	}
	else
	{
		info->child_threads[id].total_iteratescan_num++;
		info->child_threads[id].iteratescan_info[info->child_threads[id].rescan_num].called_times++;
		ereport(SPD_TM_LOG_LEVEL, (errmsg_internal("%p: child[%d] iteratescan_num: %d", info, id, info->child_threads[id].total_iteratescan_num)), errhidestmt(true));
	}
}

static void
spd_tm_init_spd_tm_time(SpdTmTime * time)
{
	INSTR_TIME_SET_ZERO(time->wall);
	INSTR_TIME_SET_ZERO(time->cpu);
}

/**
 * spd_tm_init_parent_iteration_info
 *
 * Initialize the elapsed time and CPU time values of the structure members passed as arguments.
 *
 * @param[in,out] time_info SpdTmIntegrationTimeInfo
 */
static void
spd_tm_init_parent_iteration_info(SpdTmIntegrationTimeInfo * time_info)
{
	time_info->called_times = 0;
	spd_tm_init_spd_tm_time(&time_info->integration_time.sum);
	spd_tm_init_spd_tm_time(&time_info->wait_for_queue_finish.sum);
}

/**
 * spd_tm_init_parent_iteration_info
 *
 * Initialize the elapsed time and CPU time values of the structure members passed as arguments.
 *
 * @param[in,out] time_info SpdTmIntegrationTimeInfoChild
 */
static void
spd_tm_init_child_iteration_info(SpdTmIntegrationTimeInfoChild * time_info)
{
	time_info->called_times = 0;
	spd_tm_init_spd_tm_time(&time_info->wait_for_pending_request.sum);
	spd_tm_init_spd_tm_time(&time_info->wait_for_queue_add.sum);
	spd_tm_init_spd_tm_time(&time_info->wait_for_queue_get.sum);
}


/**
 * spd_tm_count_rescanforeignscan
 *
 * Increment the number of ReScanForeignScan calls.
 * For id, specify SPD_TM_PARENT_ID or the index of the child thread.
 *
 * @param[in,out] info SpdTimeMeasureInfo
 * @param[in] id SPD_TM_PARENT_ID or index of child thread
 */
void
spd_tm_count_rescanforeignscan(SpdTimeMeasureInfo * info, int id)
{
	if (info->mode == SPD_TM_MODE_QUIET)
		return;

	ereport(SPD_TM_LOG_LEVEL, (errmsg_internal("%p: spd_tm_count_rescanforeignscan: %d", info, id)), errhidestmt(true));

	if (id == SPD_TM_PARENT_ID)
	{
		info->parent_rescan_num++;
		info->parent_iteratescan_info = (SpdTmIntegrationTimeInfo *) repalloc(info->parent_iteratescan_info, sizeof(SpdTmIntegrationTimeInfo) * (1 + info->parent_rescan_num));
		spd_tm_init_parent_iteration_info(&info->parent_iteratescan_info[info->parent_rescan_num]);
		ereport(SPD_TM_LOG_LEVEL, (errmsg_internal("%p: parent_rescan_num: %d", info, info->parent_rescan_num)), errhidestmt(true));
	}
	else
	{
		info->child_threads[id].rescan_num++;
		info->child_threads[id].iteratescan_info = (SpdTmIntegrationTimeInfoChild *) repalloc(info->child_threads[id].iteratescan_info, sizeof(SpdTmIntegrationTimeInfoChild) * (1 + info->child_threads[id].rescan_num));
		spd_tm_init_child_iteration_info(&info->child_threads[id].iteratescan_info[info->child_threads[id].rescan_num]);
		ereport(SPD_TM_LOG_LEVEL, (errmsg_internal("%p: child[%d].rescan_num: %d", info, id, info->child_threads[id].rescan_num)), errhidestmt(true));
	}
}

/**
 * spd_tm_time_set_current
 *
 * Save the current time in wall and cpu of the passed structure.
 *
 * @param[in,out] time SpdTimeMeasureInfo
 */
static void
spd_tm_time_set_current(SpdTmTime * time)
{
	struct timespec ts;

	if (!time)
		return;

	clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ts);
	time->cpu = (instr_time) ts;

	INSTR_TIME_SET_CURRENT(time->wall);
}

/**
 * spd_tm_get_time_pointer
 *
 * Returns the address of SpdTmTime corresponding to the ID and time_id.
 *
 * @param[in,out] info SpdTimeMeasureInfo
 * @param[in] id SPD_TM_PARENT_ID or index of child thread
 * @param[in] time_id SpdTmTimeID
 * @return SpdTmTime
 */
static SpdTmTimeSet *
spd_tm_get_time_pointer(SpdTimeMeasureInfo * info, int id, SpdTmTimeID time_id)
{
	SpdTmTimeSet *ret;

	if (id == SPD_TM_PARENT_ID)
		ret = &info->parent_times[time_id];
	else
		ret = &info->child_threads[id].times[time_id - SPD_TM_CHILD_BASE_ID];

	return ret;
}

/**
 * spd_tm_get_rescan_num
 *
 * Returns the number of times the rescan was called.
 *
 * @param[in,out] info SpdTimeMeasureInfo
 * @param[in] id SPD_TM_PARENT_ID or index of child thread
 * @return SpdTmTime
 */
static int
spd_tm_get_rescan_num(SpdTimeMeasureInfo * info, int id)
{
	if (id == SPD_TM_PARENT_ID)
		return info->parent_rescan_num;
	else
		return info->child_threads[id].rescan_num;
}

/**
 * spd_tm_get_time_pointer_verbose
 *
 * Returns the address of SpdTmTime corresponding to the ID, time_id and rescan_num.
 *
 * @param[in] info SpdTimeMeasureInfo
 * @param[in] id SPD_TM_PARENT_ID or index of child thread
 * @param[in] time_id SpdTmTimeID
 * @param[in] rescan_num
 * @return SpdTmTime*
 */
static SpdTmTimeSet *
spd_tm_get_time_pointer_verbose(SpdTimeMeasureInfo * info, int id, SpdTmTimeID time_id, int rescan_num)
{
	SpdTmTimeSet *ret;

	switch (time_id)
	{
		case SPD_TM_PARENT_ITERATE:
			ret = &info->parent_iteratescan_info[rescan_num].integration_time;
			break;
		case SPD_TM_PARENT_WAIT_FOR_QUEUE_FINISH:
			ret = &info->parent_iteratescan_info[rescan_num].wait_for_queue_finish;
			break;
		case SPD_TM_CHILD_WAIT_FOR_PENDING_REQUEST:
			ret = &info->child_threads[id].iteratescan_info[rescan_num].wait_for_pending_request;
			break;
		case SPD_TM_CHILD_WAIT_FOR_QUEUE_ADD:
			ret = &info->child_threads[id].iteratescan_info[rescan_num].wait_for_queue_add;
			break;
		case SPD_TM_CHILD_WAIT_FOR_QUEUE_GET:
			ret = &info->child_threads[id].iteratescan_info[rescan_num].wait_for_queue_get;
			break;
		default:
			ret = NULL;
			break;
	}
	return ret;
}

/**
 * spd_tm_time_set_start
 *
 * Stores the current time in a variable that corresponds to id and time_id.
 *
 * @param[in,out] info SpdTimeMeasureInfo
 * @param[in] id SPD_TM_PARENT_ID or index of child thread
 * @param[in] time_id SpdTmTimeID
 */
void
spd_tm_time_set_start(SpdTimeMeasureInfo * info, int id, SpdTmTimeID time_id)
{
	if (info->mode == SPD_TM_MODE_QUIET)
		return;

	spd_tm_time_set_current(&(spd_tm_get_time_pointer(info, id, time_id))->start);

	if (info->mode == SPD_TM_MODE_VERBOSE)
		spd_tm_time_set_current(&(spd_tm_get_time_pointer_verbose(info, id, time_id, spd_tm_get_rescan_num(info, id)))->start);
}

/**
 * spd_tm_accum_diff_for_spdtmtime
 *
 * @param target[in,out] SpdTimeMeasureInfo
 */
static void
spd_tm_accum_diff_for_spdtmtime(SpdTmTimeSet * target)
{
	SpdTmTime	end;

	if (target == NULL)
		return;

	spd_tm_time_set_current(&end);

	INSTR_TIME_ACCUM_DIFF(target->sum.wall, end.wall, target->start.wall);
	INSTR_TIME_ACCUM_DIFF(target->sum.cpu, end.cpu, target->start.cpu);
}

/**
 * spd_tm_accum_diff
 *
 * Accumulates the difference between
 * the time saved when spd_tm_time_set_start was called and
 * the time when this function was called.
 *
 * @param[in,out] info SpdTimeMeasureInfo
 * @param[in] id SPD_TM_PARENT_ID or index of child thread
 * @param[in] time_id SpdTmTimeID
 */
void
spd_tm_accum_diff(SpdTimeMeasureInfo * info, int id, SpdTmTimeID time_id)
{
	if (info->mode == SPD_TM_MODE_QUIET)
		return;

	spd_tm_accum_diff_for_spdtmtime(spd_tm_get_time_pointer(info, id, time_id));

	if (info->mode == SPD_TM_MODE_VERBOSE)
		spd_tm_accum_diff_for_spdtmtime(spd_tm_get_time_pointer_verbose(info, id, time_id, spd_tm_get_rescan_num(info, id)));
}

/**
 * spd_tm_child_thread_init
 *
 * Stores foreign table name of child thread.
 *
 * @param[in,out] info SpdTimeMeasureInfo
 * @param[in] id SPD_TM_PARENT_ID or index of child thread
 * @param[in] table_name child thread's foreign table name
 */
void
spd_tm_child_thread_init(SpdTimeMeasureInfo * info, int id, char *table_name)
{
	if (info->mode == SPD_TM_MODE_QUIET)
		return;

	info->child_threads[id].table_name = table_name;
}

/**
 * spd_tm_add_string_info_base
 *
 * Add title and time info string into buf.
 *
 *   ex)  BeginForeignScan           173.953 ms  100.537 ms
 *
 */
static void
spd_tm_add_string_info_base(StringInfoData *buf, char *title, SpdTmTime time)
{
	appendStringInfo(buf,
					 "\r%-27s %8.3f ms %8.3f ms",
					 title,
					 INSTR_TIME_GET_MILLISEC(time.wall),
					 INSTR_TIME_GET_MILLISEC(time.cpu));
}

/**
 * spd_tm_add_string_info
 * Add string of spd_tm_add_string_info_base and line feed into buf.
 */
static void
spd_tm_add_string_info(StringInfoData *buf, char *title, SpdTmTime time)
{
	spd_tm_add_string_info_base(buf, title, time);
	appendStringInfoChar(buf, '\n');
}

/**
 * spd_tm_add_string_info_with_times
 *
 * Add string of spd_tm_add_string_info_base and "( n times)" into buf.
 * ex) IterateForeignScan        1703.522 ms 1598.402 ms ( 72 times)
 */
static void
spd_tm_add_string_info_with_times(StringInfoData *buf, char *title, SpdTmTime time, int times)
{
	spd_tm_add_string_info_base(buf, title, time);
	appendStringInfo(buf, " (%3d times)\n", times);
}

/**
 * append_table_name
 *
 * Add name of multi tenant teble into buf.
 * If the multi tenant table has reference, it prints "table_name as reference".
 *
 *   ex1) table1mt
 *   ex2) table1mt as ref_0
 *
 */
static void
append_table_name(StringInfoData *buf, SpdTimeMeasureInfo * info)
{
	if (info->ref_name == NULL || strcmp(info->table_name, info->ref_name) == 0)
		appendStringInfo(buf, "%s", info->table_name);
	else
		appendStringInfo(buf, "%s as %s", info->table_name, info->ref_name);
}

/**
 * spd_tm_print
 *
 * Outputs the information in info to the log.
 * If time_measure_mode option value is "quiet" or not specified,
 * nothing is output.
 */
void
spd_tm_print(SpdTimeMeasureInfo * info)
{
	StringInfoData buf;
	SpdTmTime	end;

	if (info->mode == SPD_TM_MODE_QUIET)
		return;

	/* Measure and store the elapsed time and CPU time of the parent thread */
	spd_tm_time_set_current(&end);
	INSTR_TIME_SUBTRACT(end.wall, info->parent_start_time.wall);
	INSTR_TIME_SUBTRACT(end.cpu, info->parent_start_time.cpu);

	/* Accumulate the character string to be output to the log in buf */
	initStringInfo(&buf);
	appendStringInfoChar(&buf, '\n');
	appendStringInfo(&buf, "\r---- Parent Thread ----\n");
	appendStringInfo(&buf, "\rmulti tenant table: ");
	append_table_name(&buf, info);
	appendStringInfoChar(&buf, '\n');

	appendStringInfo(&buf, "\relapsed time: %.3f ms, thread cpu time: %.3f ms\n",
					 INSTR_TIME_GET_MILLISEC(end.wall),
					 INSTR_TIME_GET_MILLISEC(end.cpu));
	appendStringInfoChar(&buf, '\n');

	spd_tm_add_string_info(&buf, "BeginForeignScan", info->parent_times[SPD_TM_PARENT_BEGINFOREIGNSCAN].sum);
	spd_tm_add_string_info_with_times(&buf, "IterateForeignScan", info->parent_times[SPD_TM_PARENT_ITERATE].sum, info->parent_total_iteratescan_num);
	if (info->mode == SPD_TM_MODE_VERBOSE && info->parent_rescan_num > 0)
	{
		for (int i = 0; i <= info->parent_rescan_num; i++)
		{
			if (info->parent_iteratescan_info[i].called_times == 0)
				continue;

			spd_tm_add_string_info_with_times(&buf, "  IterateForeignScan", info->parent_iteratescan_info[i].integration_time.sum, info->parent_iteratescan_info[i].called_times);
			spd_tm_add_string_info(&buf, "    WaitForQueueFinish", info->parent_iteratescan_info[i].wait_for_queue_finish.sum);
		}
	}
	spd_tm_add_string_info_with_times(&buf, "ReScanForeignScan", info->parent_times[SPD_TM_PARENT_RESCAN].sum, info->parent_rescan_num);
	spd_tm_add_string_info(&buf, "EndForeignScan", info->parent_times[SPD_TM_PARENT_ENDFOREIGNSCAN].sum);
	appendStringInfoChar(&buf, '\n');

	spd_tm_add_string_info(&buf, "WaitForQueueFinish", info->parent_times[SPD_TM_PARENT_WAIT_FOR_QUEUE_FINISH].sum);
	appendStringInfoChar(&buf, '\n');

	appendStringInfo(&buf, "\r---- Child Threads (%d threads) ----\n", info->thread_num);

	/* add string of child thread's info into buf */
	for (int i = 0; i < info->thread_num; i++)
	{
		SpdTmTime	child_thread_total_time;

		child_thread_total_time = spd_tm_get_time_pointer(info, i, SPD_TM_CHILD_TOTAL_TIME)->sum;
		appendStringInfo(&buf, "\rThread %d (foreignTable: %s)\n", i, info->child_threads[i].table_name);
		appendStringInfo(&buf, "\relapsed time: %.3f ms, thread cpu time: %.3f ms\n",
						 INSTR_TIME_GET_MILLISEC(child_thread_total_time.wall),
						 INSTR_TIME_GET_MILLISEC(child_thread_total_time.cpu));
		appendStringInfoChar(&buf, '\n');

		appendStringInfo(&buf, "\r  %-27s %3d times\n", "IterateForeignScan", info->child_threads[i].total_iteratescan_num);
		if (info->mode == SPD_TM_MODE_VERBOSE && info->child_threads[i].rescan_num > 0)
		{
			for (int rescan_num = 0; rescan_num <= info->child_threads[i].rescan_num; rescan_num++)
			{
				appendStringInfo(&buf, "\r    %-25s %3d times\n", "IterateForeignScan", info->child_threads[i].iteratescan_info[rescan_num].called_times);

				spd_tm_add_string_info(&buf, "      WaitForPendingRequest", spd_tm_get_time_pointer_verbose(info, i, SPD_TM_CHILD_WAIT_FOR_PENDING_REQUEST, rescan_num)->sum);
				spd_tm_add_string_info(&buf, "      WaitForQueueGet", spd_tm_get_time_pointer_verbose(info, i, SPD_TM_CHILD_WAIT_FOR_QUEUE_GET, rescan_num)->sum);
				spd_tm_add_string_info(&buf, "      WaitForQueueAdd", spd_tm_get_time_pointer_verbose(info, i, SPD_TM_CHILD_WAIT_FOR_QUEUE_ADD, rescan_num)->sum);
			}
		}

		appendStringInfo(&buf, "\r  %-27s %3d times\n", "RescanForeignScan", info->child_threads[i].rescan_num);
		appendStringInfoChar(&buf, '\n');

		spd_tm_add_string_info(&buf, "  WaitForSubQuery", spd_tm_get_time_pointer(info, i, SPD_TM_CHILD_WAIT_FOR_SUB_QUERY)->sum);
		spd_tm_add_string_info(&buf, "  WaitForPendingRequest", spd_tm_get_time_pointer(info, i, SPD_TM_CHILD_WAIT_FOR_PENDING_REQUEST)->sum);
		spd_tm_add_string_info(&buf, "  WaitForQueueGet", spd_tm_get_time_pointer(info, i, SPD_TM_CHILD_WAIT_FOR_QUEUE_GET)->sum);
		spd_tm_add_string_info(&buf, "  WaitForQueueAdd", spd_tm_get_time_pointer(info, i, SPD_TM_CHILD_WAIT_FOR_QUEUE_ADD)->sum);
		spd_tm_add_string_info(&buf, "  WaitForEndRequest", spd_tm_get_time_pointer(info, i, SPD_TM_CHILD_WAIT_FOR_END_REQUEST)->sum);
		appendStringInfoChar(&buf, '\n');
	}

	appendStringInfoChar(&buf, '\n');
	appendStringInfo(&buf, "\r---- END ----");

	/* Output buff to log and free buf */
	ereport(LOG, (errmsg_internal("%s", buf.data), errhidestmt(true)));
	pfree(buf.data);
}

/**
 * spd_tm_get_option_strings_by_option_name
 * Get the value of the option specified by option_name from options.
 */
static char *
spd_tm_get_option_strings_by_option_name(List *options, char *option_name)
{
	ListCell   *lc;
	DefElem    *def;

	foreach(lc, options)
	{
		def = (DefElem *) lfirst(lc);
		if (strcmp(def->defname, option_name) == 0)
			return defGetString(def);
	}
	return NULL;
}

/**
 * spd_tm_get_option
 *
 * Get time_measure_mode option value from foreign table & foreign server.
 * Determin the final mode from the acquired value and return it.
 *
 */
SpdTmMode
spd_tm_get_option(Oid foreigntableid)
{
	ForeignTable *table;
	ForeignServer *server;
	char	   *server_opt,
			   *table_opt,
			   *temp;
	SpdTmMode	ret;

	table = GetForeignTable(foreigntableid);
	server = GetForeignServer(table->serverid);

	table_opt = spd_tm_get_option_strings_by_option_name(table->options, SPD_TM_OPTION_TITLE);
	server_opt = spd_tm_get_option_strings_by_option_name(server->options, SPD_TM_OPTION_TITLE);

	if ((server_opt && strcmp(server_opt, SPD_TM_OPTION_QUIET) == 0) ||
		(table_opt && strcmp(table_opt, SPD_TM_OPTION_QUIET) == 0))
		temp = SPD_TM_OPTION_QUIET;
	else if (table_opt != NULL)
		temp = table_opt;
	else
		temp = server_opt;

	if (temp == NULL || strcmp(temp, SPD_TM_OPTION_QUIET) == 0)
		ret = SPD_TM_MODE_QUIET;
	else if (strcmp(temp, SPD_TM_OPTION_NORMAL) == 0)
		ret = SPD_TM_MODE_NORMAL;
	else if (strcmp(temp, SPD_TM_OPTION_VERBOSE) == 0)
		ret = SPD_TM_MODE_VERBOSE;
	else
		ret = SPD_TM_MODE_QUIET;

	return ret;
}
