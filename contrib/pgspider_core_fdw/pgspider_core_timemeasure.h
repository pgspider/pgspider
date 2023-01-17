/*-------------------------------------------------------------------------
 *
 * pgspider_core_timemeasure.h
 *		  Header file of pgspider_core_timemeasure
 *
 * Portions Copyright (c) 2022, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_core_fdw/pgspider_core_timemeasure.h
 *
 *-------------------------------------------------------------------------
 */

#ifndef PGSPIDER_CORE_TIMEMEASURE_H
#define PGSPIDER_CORE_TIMEMEASURE_H

#define SPD_TM_PARENT_ID -1

#define SPD_TM_CHILD_BASE_ID	SPD_TM_CHILD_TOTAL_TIME

/* ID indicating the type of time to record */
typedef enum
{
	SPD_TM_PARENT_BEGINFOREIGNSCAN = 0,
	SPD_TM_PARENT_ITERATE,
	SPD_TM_PARENT_RESCAN,
	SPD_TM_PARENT_ENDFOREIGNSCAN,
	SPD_TM_PARENT_WAIT_FOR_QUEUE_FINISH,
	SPD_TM_PARENT_TIME_NUM,

	SPD_TM_CHILD_TOTAL_TIME,
	SPD_TM_CHILD_WAIT_FOR_SUB_QUERY,
	SPD_TM_CHILD_WAIT_FOR_PENDING_REQUEST,
	SPD_TM_CHILD_WAIT_FOR_QUEUE_GET,
	SPD_TM_CHILD_WAIT_FOR_QUEUE_ADD,
	SPD_TM_CHILD_WAIT_FOR_END_REQUEST,
	SPD_TM_CHILD_TIME_NUM
}			SpdTmTimeID;

/*
 *  Option title and values
 *  Used in pgspider_core_option.c
 */
#define SPD_TM_OPTION_TITLE "time_measure_mode"
#define SPD_TM_OPTION_QUIET   "quiet"
#define SPD_TM_OPTION_NORMAL  "normal"
#define SPD_TM_OPTION_VERBOSE "verbose"

/* type of time_measure_mode */
typedef enum
{
	SPD_TM_MODE_QUIET = 0,
	SPD_TM_MODE_NORMAL,
	SPD_TM_MODE_VERBOSE
}			SpdTmMode;

/* SpdTmTime */
typedef struct SpdTmTime
{
	instr_time	wall;			/* elapsed time */
	instr_time	cpu;			/* cpu time */
}			SpdTmTime;

/*
 * Structure for storing measurement start time and integrated value together.
 * Used to integrate the difference in wall time and cpu time.
 */
typedef struct SpdTmTimeSet
{
	SpdTmTime	start;			/* measurement start time */
	SpdTmTime	sum;			/* Integrated value */
}			SpdTmTimeSet;

/* Values measured in a child thread when verbose mode is on. */
typedef struct SpdTmIntegrationTimeInfoChild
{
	SpdTmTimeSet wait_for_pending_request;
	SpdTmTimeSet wait_for_queue_get;
	SpdTmTimeSet wait_for_queue_add;

	int			called_times;	/* Number of times child thread called
								 * iterateforeignscan of foreign table */
}			SpdTmIntegrationTimeInfoChild;

/* Child thread info */
typedef struct SpdTmChildThreadInfo
{
	int			total_iteratescan_num;
	int			rescan_num;

	char	   *table_name;

	SpdTmIntegrationTimeInfoChild *iteratescan_info;

	SpdTmTimeSet times[SPD_TM_CHILD_TIME_NUM - SPD_TM_CHILD_BASE_ID];
}			SpdTmChildThreadInfo;

/* Values measured in the parent thread when verbose mode is on. */
typedef struct SpdTmIntegrationTimeInfo
{
	SpdTmTimeSet integration_time;	/* elapsed time and cpu time of
									 * iterateforeignscan */
	SpdTmTimeSet wait_for_queue_finish;

	int			called_times;	/* Number of times called parent thread's
								 * IterateForeignScan */
}			SpdTmIntegrationTimeInfo;

/*
 * Main data of this module.
 */
typedef struct SpdTimeMeasureInfo
{
	SpdTmMode	mode;			/* time_measure_mode option */
	int			thread_num;
	char	   *table_name;
	char	   *ref_name;

	int			parent_total_iteratescan_num;
	int			parent_rescan_num;

	SpdTmTime	parent_start_time;
	SpdTmTimeSet parent_times[SPD_TM_PARENT_TIME_NUM];

	SpdTmIntegrationTimeInfo *parent_iteratescan_info;
	SpdTmChildThreadInfo *child_threads;
}			SpdTimeMeasureInfo;

 /* in pgspider_core_timemeasure.c */
extern SpdTmMode spd_tm_get_option(Oid foreigntableid);

extern void spd_tm_serialize_info(SpdTimeMeasureInfo * info, List *lfdw_private);
extern void spd_tm_deserialize_info(SpdTimeMeasureInfo * info, List *lfdw_private, ListCell *lc);

extern void spd_tm_init(SpdTimeMeasureInfo * info);
extern void spd_tm_child_thread_init(SpdTimeMeasureInfo * info, int id, char *table_name);

extern void spd_tm_time_set_start(SpdTimeMeasureInfo * info, int id, SpdTmTimeID time_id);
extern void spd_tm_accum_diff(SpdTimeMeasureInfo * info, int id, SpdTmTimeID time_id);

extern void spd_tm_count_iterateforeignscan(SpdTimeMeasureInfo * info, int id);
extern void spd_tm_count_rescanforeignscan(SpdTimeMeasureInfo * info, int id);

extern void spd_tm_print(SpdTimeMeasureInfo * info);

#endif							/* PGSPIDER_CORE_TIMEMEASURE_H */
