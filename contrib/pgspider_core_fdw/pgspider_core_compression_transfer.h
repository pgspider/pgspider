/*-------------------------------------------------------------------------
 *
 * pgspider_core_compression_transfer.h
 *		  Header file of pgspider_core_compression_transfer
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_core_fdw/pgspider_core_compression_transfer.h
 *
 *-------------------------------------------------------------------------
 */
#include "utils/relcache.h"
#include "pgspider_core_fdw.h"
#include "utils/rel.h"
#include "utils/resowner.h"

/* This structure stores the read buffer of each client socket. */
typedef struct ReadBufferClientSocket
{
	int				client_socket;	/* socket client descriptor */
	int				num_bytes;		/* number bytes were read */
	unsigned char	buffer[8];		/* read buffer */
}			ReadBufferClientSocket;

extern void spd_get_dct_option(Relation rel, int *socket_port, int *function_timeout, char **public_host, int *public_port, char **ifconfig_service);
extern void *spd_socket_server_thread(void *arg);
extern void spd_end_socket_server(int *server_fd, bool *end_server);
extern void spd_end_insert_data_thread(SocketThreadInfo *socketThreadInfo);
extern bool	spd_check_data_compression_transfer_option(ChildInfo  *childInfo, int node_num);
