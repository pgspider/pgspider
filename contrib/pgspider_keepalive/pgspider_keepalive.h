#ifndef SPD_FDW_H
#define SPD_FDW_H

#include "utils/dynahash.h"
#include "storage/shmem.h"

extern HTAB *InitPredicateKeepalives();
extern bool check_server_ipname(char *serverName, char *ip);

#endif
