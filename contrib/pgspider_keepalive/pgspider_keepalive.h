/*-------------------------------------------------------------------------
 *
 * pgspider_keepalive.h
 *
 * Portions Copyright (c) 2018, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_keepalive/pgspider_keepalive.h
 *
 *-------------------------------------------------------------------------
 */

#ifndef SPD_FDW_H
#define SPD_FDW_H

#include "utils/dynahash.h"
#include "storage/shmem.h"

extern HTAB *InitPredicateKeepalives();
extern bool check_server_ipname(char *serverName, char *ip);

#endif
