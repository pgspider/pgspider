/*-------------------------------------------------------------------------
 *
 * nodeDist.h
 *	  prototypes for nodeDist.c
 *
 *
 * Portions Copyright (c) 2022, TOSHIBA CORPORATION
 *
 * src/include/executor/nodeDist.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef NODEDIST_H
#define NODEDIST_H

#include "postgres.h"

#ifdef PD_STORED
#include "foreign/foreign.h"
#include "funcapi.h"
#include "utils/rel.h"
#include "utils/relcache.h"

typedef void (*ExecFunction) (Oid, Oid, List*,
							  bool, void**);
typedef bool (*GetFunctionResultOne) (void*, AttInMetadata*,
									  Datum*, bool*);
typedef void (*FinFunction) (void*);

extern TupleTableSlot *agg_retrieve_distributed_func(AggState *aggstate);
extern bool is_distributed_function(PlanState *planstate);

#endif							/* PD_STORED */
#endif							/* NODEDIST_H */
