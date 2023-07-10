/*-------------------------------------------------------------------------
 *
 * pgspider_core_routing.h
 *		  Header file of pgspider_core_routing
 *
 * Portions Copyright (c) 2022, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_core_fdw/pgspider_core_routing.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef PGSPIDER_CORE_ROUTING_H
#define PGSPIDER_CORE_ROUTING_H
#include "pgspider_core_fdw.h"

void		spd_routing_init_shm(void);
void		spd_routing_handle_candidate_error(MemoryContext ccxt, char *relname);
void		spd_routing_candidate_validate(ChildInfo * pChildInfo, int node_num);
void		spd_routing_candidate_spdurl(TupleTableSlot *slot, Relation rel,
										 ChildInfo * pChildInfo, int node_num);
int			spd_routing_get_target(Oid parent, ModifyThreadInfo *mtThrdInfo,
								   ChildInfo * pChildInfo, int node_num);
bool			spd_routing_set_target(Oid parent, ModifyThreadInfo *mtThrdInfo,
								   ChildInfo * pChildInfo, int node_num);

#endif							/* PGSPIDER_CORE_ROUTING_H */
