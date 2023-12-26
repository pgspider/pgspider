/*-------------------------------------------------------------------------
 *
 * pgspider_core_compression_transfer.c
 *		  Implementation for data compression transfer feature
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_core_fdw/pgspider_core_compression_transfer.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include <arpa/inet.h>
#include <math.h>
#include <netdb.h>
#include <net/if.h>
#include <netinet/in.h>
#include <pthread.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

#include "c.h"
#include "commands/defrem.h"
#include "miscadmin.h"
#include "pgspider_core_compression_transfer.h"
#include "utils/datum.h"
#include "utils/guc.h"

/* FDW module name */
#define PGSPIDER_FDW_NAME			"pgspider_fdw"
#define SERVERID_TABLEID_SIZE   	8
/* For DATA COMPRESSION TRANSFER */
pthread_mutex_t end_socket_server_thread = PTHREAD_MUTEX_INITIALIZER;

/*
 * If system call is interrupted, retry system call
 * Otherwise, exit
 */
#define CHECK_SYSTEMCALL_ERROR(ret, err_mesg, dest, fail_mesg) \
	if (ret == -1) \
	{ \
		if (errno == EINTR) \
			continue; \
		err_mesg = psprintf("%s: %s", fail_mesg, pstrdup(strerror(errno))); \
		goto dest; \
	}

/*
 * Handle timeout error for system call select()
 */
#define CHECK_SYSTEMCALL_SELECT_ERROR(ret, err_mesg, timeout) \
	if (ret == -1) \
	{ \
		if (errno == EINTR) \
			continue; \
		err_mesg = psprintf("Fail to select(): %s", pstrdup(strerror(errno))); \
		break; \
	} \
	else if (ret == 0) \
	{ \
		err_mesg = psprintf("Timeout expired: %d. The timeout period elapsed prior to completion of the operation or the Cloud Function is not responding.", timeout); \
		break; \
	}

/**
 * convert_4_bytes_array_to_int
 *
 * Convert 4 bytes data to an int number.
 * The bytes of byte[] in a big-endian order used in networking (TCP/IP).
 * Need to convert value match with the little-endian system.
 */
static int32
convert_4_bytes_array_to_int(unsigned char byte[])
{
	return (byte[0] << 24) + \
		((byte[1] & 0xFF) << 16) + \
		((byte[2] & 0xFF) << 8) + \
		(byte[3] & 0xFF);
}

/**
 * spd_get_dct_option
 *
 * Get option for data compress transfer feature
 */
void
spd_get_dct_option(Relation rel, int *socket_port, int *function_timeout, char **public_host, int *public_port, char **ifconfig_service)
{
	ForeignTable *table;
	ListCell   *lc;

	table = GetForeignTable(RelationGetRelid(rel));

	foreach(lc, table->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "socket_port") == 0)
			(void) parse_int(defGetString(def), socket_port, 0, NULL);
		else if (strcmp(def->defname, "function_timeout") == 0)
			(void) parse_int(defGetString(def), function_timeout, 0, NULL);
		else if (strcmp(def->defname, "public_host") == 0)
		{
			*public_host = defGetString(def);
		}
		else if (strcmp(def->defname, "public_port") == 0)
		{
			(void) parse_int(defGetString(def), public_port, 0, NULL);
		}
		else if (strcmp(def->defname, "ifconfig_service") == 0)
		{
			*ifconfig_service = defGetString(def);
		}
	}
}

/**
 * spd_setSocketServerThreadContext
 *
 * Set error handling configuration and memory context. Additionally, create
 * memory context for socket server thread.
 *
 * @param[in] socketInfo Thread information
 */
static void
spd_setSocketServerThreadContext(SocketInfo * socketInfo)
{
	CurrentResourceOwner = socketInfo->thrd_ResourceOwner;
	TopMemoryContext = socketInfo->threadTopMemoryContext;

	MemoryContextSwitchTo(socketInfo->threadMemoryContext);

	/* Initialize ErrorContext for each child thread. */
	ErrorContext = AllocSetContextCreate(socketInfo->threadMemoryContext,
										 "socket server Thread ErrorContext",
										 ALLOCSET_DEFAULT_SIZES);
	MemoryContextAllowInCriticalSection(ErrorContext, true);

	/* Declare ereport/elog jump is not available. */
	PG_exception_stack = NULL;
	error_context_stack = NULL;
}

static char *
get_local_ip()
{
	char		hostbuffer[HOST_NAME_MAX];
	char	   *hostIP;
	struct hostent *host_entry;
	int			hostname;

	/* Get host name */
	hostname = gethostname(hostbuffer, sizeof(hostbuffer));
	if (hostname == -1)
		elog(ERROR, "Failed to get host name");

	/* Get host information */
	host_entry = gethostbyname(hostbuffer);
	if (host_entry == NULL)
		elog(ERROR, "Failed to get host information");

	/* Convert Internet network address into ASCII string */
	hostIP = inet_ntoa(*((struct in_addr*)
						host_entry->h_addr_list[0]));

	return pstrdup(hostIP);
}

/**
 * get_listen_ip()
 *
 * Listen ip of host machine
 */
static char *
get_listen_ip(bool local_mode)
{
	if (local_mode)
	{
		return get_local_ip();
	}
	elog(DEBUG1, "pgspider_core_fdw: Listen INADDR_ANY (0.0.0.0)");
	return "0.0.0.0";
}

/**
 * check_end_server
 *
 * Check value of end_server variable. Put the check inside
 * mutex lock to avoid concurrency problem between threads.
 */
static bool
check_end_server(SocketInfo * socket_info)
{
	pthread_mutex_lock(&end_socket_server_thread);
	if (socket_info->end_server)
	{
		pthread_mutex_unlock(&end_socket_server_thread);
		return true;
	}
	else
	{
		pthread_mutex_unlock(&end_socket_server_thread);
		return false;
	}
}

/**
 * spd_end_insert_data_thread
 *
 * Notify insert_data thread of pgspider_fdw to end
 */
void
spd_end_insert_data_thread(SocketThreadInfo * socketThreadInfo)
{
	pthread_mutex_lock(&socketThreadInfo->socket_thread_info_mutex);
	/* notify socket client connection refuse to read/write */
	shutdown(socketThreadInfo->socket_id, SHUT_RDWR);
	/* notify send_insert_data thread exit */
	socketThreadInfo->childThreadState = DCT_MDF_STATE_END;
	pthread_mutex_unlock(&socketThreadInfo->socket_thread_info_mutex);
}

/**
 * spd_end_insert_data_thread
 *
 * Notify socket server to end
 */
void
spd_end_socket_server(int *server_fd, bool *end_server)
{
	pthread_mutex_lock(&end_socket_server_thread);
	/*
	 * Notify socket server refuse to accept.
	 * Shutdown also needs to be inside mutex to avoid race condition
	 * of checking end_server to exit the loop at socket server.
	 */
	shutdown((*server_fd), SHUT_RD);
	(*end_server) = true;
	pthread_mutex_unlock(&end_socket_server_thread);
}

/**
 * spd_initReadBufferSocketClient
 *
 * Init value for ReadBufferSocketClient struct.
 */
static void
spd_initReadBufferSocketClient(ReadBufferClientSocket * readbuffer, int client_socket)
{
	readbuffer->client_socket = client_socket;
	readbuffer->num_bytes = 0;
	memset(&readbuffer->buffer, 0, 8);
}

/**
 *	spd_freeThreadContextList
 *
 * 	context_freelists is the thread local variable used in each child thread.
 * 	It is used to save memory context which is allocated/deleted for re-use if any.
 * 	Free all items in the list before thread exit to avoid memory leak.
 */
static void
spd_freeThreadContextList(void)
{
	MemoryContextFreeContextList();
}

/**
 * spd_socket_server_thread
 *
 * Initialize socket server and listen connection.
 */
void *
spd_socket_server_thread(void *arg)
{
	SocketInfo	   *socketInfo = (SocketInfo *) arg;
	bool			local_mode = true;
	Latch			LocalLatchData;
	int 			server_fd = -1;	/* Server file descriptor */
	int 			client_socket = -1;
	struct 			sockaddr_in address, cli;
	int32 			serverID, tableID;
	int 			opt = 1;
	int 			addrlen = sizeof(address);
	int 			client = sizeof(cli);
	struct timeval 	timeout = {.tv_usec = 0};
	ListCell 	   *lc;
	char	 	   *listen_ip;
	bool	  		matched_child_thread;
	fd_set			working_fds, master_fds;
	int 			rv, max_fd, ret;
	int 			socket_port = socketInfo->socket_port;
	int 			function_timeout = socketInfo->function_timeout;
	List		   *client_fds = NIL;

	/*
	 * MyLatch is the thread local variable, when creating child thread we
	 * need to init it for use in child thread.
	 */
	MyLatch = &LocalLatchData;
	InitLatch(MyLatch);

	/* Configuration for context of error handling and memory context. */
	spd_setSocketServerThreadContext(socketInfo);

	if (socketInfo->public_host != NULL || socketInfo->ifconfig_service != NULL)
	{
		local_mode = false;
	}
	/* get public ip of socket server */
	listen_ip = get_listen_ip(local_mode);

	/* Create socket descriptor */
	if ((server_fd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0)) < 0)
	{
		socketInfo->err = strerror(errno);
		pthread_exit(NULL);
	}

	/* Set and bind port */
	if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT,
				   &opt, sizeof(opt)))
	{
		socketInfo->err = strerror(errno);
		goto SOCKET_SERVER_THREAD_EXIT;
	}

	address.sin_family = AF_INET;
	address.sin_addr.s_addr = inet_addr(listen_ip);
	address.sin_port = htons(socket_port);

	if (bind(server_fd, (struct sockaddr *) &address, addrlen) < 0)
	{
		socketInfo->err = strerror(errno);
		goto SOCKET_SERVER_THREAD_EXIT;
	}

	/*
	 * Add socket descriptor to SocketInfo for easily access in further.
	 *
	 * When ending ForeignModify or there is any error during ForeignModify,
	 * spd_socket_server_thread need to be terminated, but it still may be waiting for a new client connection by accept which is in blocking mode,
	 * so other threads can use server_fd to shutdown the server socket to un-block accept function call then server socket thread can terminate.
	 */
	socketInfo->server_fd = server_fd;

	/* Listen and wait for connection from Function */
	if (listen(server_fd, SOMAXCONN) < 0)
	{
		socketInfo->err = strerror(errno);
		goto SOCKET_SERVER_THREAD_EXIT;
	}

	/* clear the set */
	FD_ZERO(&master_fds);
	/* add our file descriptor to the set */
	FD_SET(server_fd, &master_fds);

	/* timeout for socket server */
	timeout.tv_sec = function_timeout;

	/* use max_fd to monitor needed file descriptor */
	max_fd = server_fd;

	do
	{
		/* Copy the master fd_set over to the working fd_set */
		memcpy(&working_fds, &master_fds, sizeof(master_fds));

		rv = select(max_fd + 1, &working_fds, NULL, NULL, &timeout);
		CHECK_SYSTEMCALL_SELECT_ERROR(rv, socketInfo->err, function_timeout)

		/* Incoming request connect */
		if (FD_ISSET(server_fd, &working_fds))
		{
			client_socket = accept(server_fd, (struct sockaddr *) &cli, (socklen_t *) & client);
			if (client_socket > 0)
			{
				ReadBufferClientSocket *read_buffer_client = (ReadBufferClientSocket *) palloc0(sizeof(ReadBufferClientSocket));

				spd_initReadBufferSocketClient(read_buffer_client, client_socket);
				client_fds = lappend(client_fds, read_buffer_client);

				max_fd = (server_fd >= client_socket) ? server_fd : client_socket;
				FD_SET(client_socket, &master_fds);
				continue;
			}
			else if (check_end_server(socketInfo))
			{
				/* Break when received end_server request from EndForeignModify*/
				break;
			}
			else if (errno != EINTR) /* Got error */
			{
				socketInfo->err = strerror(errno);
				break;
			}
		}

		foreach(lc, client_fds)
		{
			ReadBufferClientSocket *read_buffer_client = (ReadBufferClientSocket *) lfirst(lc);

			/* Incoming data on client socket */
			if (!FD_ISSET(read_buffer_client->client_socket, &working_fds))
				continue;

			/* read serverID/tableID */
			ret = read(read_buffer_client->client_socket, &read_buffer_client->buffer[read_buffer_client->num_bytes], SERVERID_TABLEID_SIZE - read_buffer_client->num_bytes);
			CHECK_SYSTEMCALL_ERROR(ret, socketInfo->err, SOCKET_SERVER_THREAD_EXIT, "Fail to read serverID and tableID")

			read_buffer_client->num_bytes += ret;

			/* Need to continue read */
			if (read_buffer_client->num_bytes < SERVERID_TABLEID_SIZE)
				break;

			/* Read done */
			serverID = convert_4_bytes_array_to_int(&read_buffer_client->buffer[0]);
			tableID = convert_4_bytes_array_to_int(&read_buffer_client->buffer[4]);

			/* Remove unused client from list to avoid redundant check */
			client_fds = foreach_delete_current(client_fds, lc);

			FD_CLR(read_buffer_client->client_socket, &master_fds);

			matched_child_thread = false;

			/* Set socket_id = connected_socket for child thread of ExecuteBatchInsert pgspider_fdw */
			foreach(lc, socketInfo->socketThreadInfos)
			{
				SocketThreadInfo *socketThreadInfo = (SocketThreadInfo *) lfirst(lc);
				pthread_mutex_lock(&socketThreadInfo->socket_thread_info_mutex);
				if (socketThreadInfo->serveroid == serverID && socketThreadInfo->tableoid == tableID)
				{
					socketThreadInfo->childThreadState = DCT_MDF_STATE_EXEC_BATCH_INSERT;
					socketThreadInfo->socket_id = read_buffer_client->client_socket;
					matched_child_thread = true;
					pthread_mutex_unlock(&socketThreadInfo->socket_thread_info_mutex);
					break;
				}
				pthread_mutex_unlock(&socketThreadInfo->socket_thread_info_mutex);
			}

			if (!matched_child_thread)
			{
				socketInfo->err = psprintf("No child thread matches. Server ID = %d, Table ID = %d.", serverID, tableID);
				goto SOCKET_SERVER_THREAD_EXIT;
			}
		}
	} while (!check_end_server(socketInfo));	/* Continue waiting if end_server is false */

SOCKET_SERVER_THREAD_EXIT:

	if (close(server_fd) == -1)
		socketInfo->err = strerror(errno);

	spd_freeThreadContextList();

	pthread_exit(NULL);
}

/**
 * check_data_compression_transfer_option
 *
 * Get all options of child node. If there is pgspider_fdw
 * and it has option 'endpoint', return true
 */
bool
spd_check_data_compression_transfer_option(ChildInfo * childInfo, int node_num)
{
	int			i;
	ListCell   *lc;
	ForeignServer *fs;

	for (i = 0; i < node_num; i++)
	{
		ForeignDataWrapper *fdw;
		ChildInfo  *pChildInfo = &childInfo[i];

		fs = GetForeignServer(pChildInfo->server_oid);
		fdw = GetForeignDataWrapper(fs->fdwid);

		if (strcmp(fdw->fdwname, PGSPIDER_FDW_NAME) == 0)
		{
			foreach(lc, fs->options)
			{
				DefElem    *def = (DefElem *) lfirst(lc);

				if (strcmp(def->defname, "endpoint") == 0)
					return true;
			}
		}
	}
	return false;
}
