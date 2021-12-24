/*-------------------------------------------------------------------------
 *
 * pgspider_keepalive.c
 *
 * Portions Copyright (c) 2018-2021, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_keepalive/pgspider_keepalive.c
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"
#include "pgspider_keepalive.h"


/* These are always necessary for a bgworker */
#include "miscadmin.h"
#include "postmaster/bgworker.h"
#include "storage/ipc.h"
#include "storage/latch.h"
#include "storage/lwlock.h"
#include "storage/proc.h"

/* these headers are used by this particular worker's code */
#include "access/xact.h"
#include "executor/spi.h"
#include "fmgr.h"
#include "lib/stringinfo.h"
#include "pgstat.h"
#include "utils/builtins.h"
#include "utils/snapmgr.h"
#include "tcop/utility.h"
#include "pthread.h"
#include "foreign/foreign.h"
#include "commands/defrem.h"
#include "nodes/nodeFuncs.h"
#include "utils/memutils.h"
#include "unistd.h"

#define CMDLEN (50 + IPV6LEN)
#define IPV6LEN (45)

PG_MODULE_MAGIC;

typedef struct nodeinfotag
{
	char		nodeName[NAMEDATALEN];
	char		ip[IPV6LEN];
}			nodeinfotag;

typedef struct NODEINFO
{
	/* tag */
	nodeinfotag tag;

	/* data */
	bool		isAlive;
}			NODEINFO;

void		_PG_init(void);
void		worker_spi_main(Datum) pg_attribute_noreturn();

/* flags set by signal handlers */
static volatile sig_atomic_t got_sighup = false;
static volatile sig_atomic_t got_sigterm = false;

/* postgresql.conf value */
static int	max_child_nodes;
static int	checknodes_interval;
static int	timeout_time;
static int	keepalive_time;
static HTAB *keepshNodeHash;

/* shared child and parent flag */
static bool join_flag;
static pthread_mutex_t hash_mutex = PTHREAD_MUTEX_INITIALIZER;

static void create_alive_list(StringInfoData *buf, NODEINFO * *nodeInfo, char ***fdwname, int *svrnum);
static void create_child_info(NODEINFO * nodeInfo, pthread_t **threads, int svrnum);
static void create_child_threads(NODEINFO * nodeInfo, int *numThreads, pthread_t *threads, int svrnum);
static void delete_oldhash(NODEINFO * nodeInfo, int svrnum);
static void InitKeepaliveShm();
static void InitSharedMemoryKeepalives();
static void join_childs(int numThreads, pthread_t *threads);
static void *pgspider_check_childnnode(void *arg);
static shmem_startup_hook_type shmem_startup_prev = NULL;
void		worker_pgspider_keepalive(Datum main_arg);
void		InitSharedMemoryKeepalives();

/*
 * Signal handler for SIGTERM
 *		Set a flag to let the main loop to terminate, and set our latch to wake
 *		it up.
 */
static void
pgspider_keepalive_sigterm(SIGNAL_ARGS)
{
	int			save_errno = errno;

	got_sigterm = true;
	SetLatch(MyLatch);

	errno = save_errno;
}

/*
 * Signal handler for SIGHUP
 *		Set a flag to tell the main loop to reread the config file, and set
 *		our latch to wake it up.
 */
static void
pgspider_keepalive_sighup(SIGNAL_ARGS)
{
	int			save_errno = errno;

	got_sighup = true;
	SetLatch(MyLatch);

	errno = save_errno;
}

/*
 * Threads execute this function. ping to child node and update hash table.
 */
static void *
pgspider_check_childnnode(void *arg)
{
	/* initialize */
	bool		latest_isAlive = true;
	bool		current_isAlive = true;
	NODEINFO   *nodeInfo = (NODEINFO *) arg;
	char		cmd[CMDLEN];
	int			ret;
	int			i;
	nodeinfotag key = {{0}};

	ErrorContext = AllocSetContextCreate(TopMemoryContext,
										 "Pgspider keep alive ErrorContext",
										 ALLOCSET_DEFAULT_SIZES);
	MemoryContextAllowInCriticalSection(ErrorContext, true);

	strcpy(key.nodeName, nodeInfo->tag.nodeName);
	strcpy(key.ip, nodeInfo->tag.ip);
#ifndef WIN32
	sprintf(cmd, "ping %s -c 1 -t %d > /dev/null 2>&1 ", nodeInfo->tag.ip, timeout_time);
#else
	sprintf(cmd, "ping %s -n 1 -w %d > nul ", nodeInfo->tag.ip, timeout_time * 1000);
#endif
	elog(INFO, "KeepAlive threads start '%s %s' ", nodeInfo->tag.nodeName, nodeInfo->tag.ip);
	while (1)
	{
		/* Check child nodes using ping */
		ret = system(cmd);
		if (ret != 0)
			current_isAlive = false;
		else
			current_isAlive = true;
		/* Update hash if necessary */
		if (current_isAlive != latest_isAlive)
		{
			NODEINFO   *entry;
			bool		found;

			elog(LOG, "Node '%s' status is changed: [%d] -> [%d]", key.nodeName, latest_isAlive, current_isAlive);
			pthread_mutex_lock(&hash_mutex);
			entry = hash_search(keepshNodeHash, &key, HASH_ENTER, &found);
			if (!found)
				elog(LOG, "Not find same hash in pgspider_keepalive %s", key.nodeName);
			entry->isAlive = current_isAlive;
			pthread_mutex_unlock(&hash_mutex);
			nodeInfo->isAlive = current_isAlive;
		}
		latest_isAlive = current_isAlive;
		for (i = 0; i < keepalive_time; i++)
		{
			sleep(1);
			/* Check finishing flag */
			if (join_flag == true)
			{
				MemoryContextDelete(ErrorContext);
				return 0;
			}
		}
	}
}

/*
 * This is initializing for keep alive shared hash in postmaster.
 */
static void
InitKeepaliveShm()
{
	HASHCTL		info;
	long		init_table_size,
				max_table_size;

	max_table_size = max_child_nodes;
	init_table_size = max_table_size / 2;

	/*
	 * Allocate hash table for LOCK structs.  This stores per-locked-object
	 * information.
	 */
	MemSet(&info, 0, sizeof(info));
	info.keysize = sizeof(nodeinfotag);
	info.entrysize = sizeof(NODEINFO);
	info.num_partitions = 4;

	keepshNodeHash = ShmemInitHash("keep alive",
								   init_table_size,
								   max_table_size,
								   &info,
								   HASH_ELEM | HASH_BLOBS | HASH_PARTITION);
}


/*
 * Create server and IP list from pg_spd_node_info with SPI.
 */
static void
create_alive_list(StringInfoData *buf, NODEINFO * *nodeInfo, char ***fdwname, int *svrnum)
{
	int			ret;
	char	   *sql = "SELECT * FROM pg_spd_node_info;";
	int			i;
	MemoryContext oldcontext;

	oldcontext = CurrentMemoryContext;

	/* get server info */
	/* We can now execute queries via SPI */
	SetCurrentStatementStartTimestamp();
	StartTransactionCommand();
	SPI_connect();
	PushActiveSnapshot(GetTransactionSnapshot());
	PG_TRY();
	{
		ret = SPI_execute(sql, false, 0);
	}
	PG_CATCH();
	{
		/*
		 * This case is can not find pg_spd_node_info, but if it is error,
		 * keep-alive is finished (If table can not find, then SPI_exec do
		 * ereport(ERROR), and process is finished) so then keep-alive doesn't
		 * create hash table and threads. Parent thread monitor
		 * pg_spd_node_info.
		 */
		FlushErrorState();
		elog(INFO, "'SELECT * FROM pg_spd_node_info' is failed");
		*svrnum = 0;
		SPI_finish();
		PopActiveSnapshot();
		CommitTransactionCommand();
		return;
	}
	PG_END_TRY();
	if (ret != SPI_OK_SELECT)
	{
		*svrnum = 0;
		return;
	}
	/* Set and server name, FDW name and IP */
	*fdwname = (char **) MemoryContextAlloc(oldcontext, SPI_processed * sizeof(char *));
	*nodeInfo = (NODEINFO *) MemoryContextAlloc(oldcontext, SPI_processed * sizeof(NODEINFO));
	for (i = 0; i < SPI_processed; i++)
	{
		char	   *srvname;
		char	   *ipstr;
		char	   *fdwstr;

		(*fdwname)[i] = (char *) MemoryContextAlloc(oldcontext, NAMEDATALEN * sizeof(char));
		srvname = SPI_getvalue(SPI_tuptable->vals[i],
							   SPI_tuptable->tupdesc,
							   2);
		fdwstr = SPI_getvalue(SPI_tuptable->vals[i],
							  SPI_tuptable->tupdesc,
							  3);
		ipstr = SPI_getvalue(SPI_tuptable->vals[i],
							 SPI_tuptable->tupdesc,
							 4);
		/* TODO: Delete this line when fix setting script */
		if (strcmp(fdwstr, "griddb_fdw") == 0)
			strcpy((*nodeInfo)[i].tag.ip, "");
		else
			strcpy((*nodeInfo)[i].tag.ip, ipstr);
		strcpy((*nodeInfo)[i].tag.nodeName, srvname);
		strcpy((*fdwname)[i], fdwstr);
	}
	*svrnum = SPI_processed;
	SPI_finish();
	PopActiveSnapshot();
	CommitTransactionCommand();
}

/*
 * Create hash table on shared memory.
 */
static void
create_child_info(NODEINFO * nodeInfo, pthread_t **threads, int svrnum)
{
	NODEINFO   *entry;
	int			i;
	bool		found;

	if (svrnum != 0)
		*threads = palloc(sizeof(pthread_t) * svrnum);
	for (i = 0; i < svrnum; i++)
	{
		nodeinfotag key = {{0}};

		strcpy(key.nodeName, nodeInfo[i].tag.nodeName);
		strcpy(key.ip, nodeInfo[i].tag.ip);
		entry = hash_search(keepshNodeHash, &key, HASH_ENTER, &found);
		entry->isAlive = true;
	}
}

/*
 * Create child thread
 */
static void
create_child_threads(NODEINFO * nodeInfo, int *numThreads, pthread_t *threads, int svrnum)
{
	int			i;
	int			ret;

	elog(INFO, "create_child_threads");
	*numThreads = 0;

	/*
	 * If IP = "", it is nothing ip case(e.g. file_fdw). It doesn't change
	 * alive flag
	 */
	for (i = 0; i < svrnum; i++)
	{
		if (strcmp("", nodeInfo[i].tag.ip) != 0)
		{
			ret = pthread_create(&threads[*numThreads], NULL, &pgspider_check_childnnode, &nodeInfo[i]);
			if (ret != 0)
				elog(ERROR, "PGSpider keep alive can not create child thread : %d", ret);
			*numThreads += 1;
		}
		else
		{
			elog(INFO, "%s is not supported FDW, 'alive' always.", nodeInfo[i].tag.nodeName);
		}
	}
}

static bool
check_hashtable_with_nodeinfotable(char *serverName, char *ip, bool *ret)
{
	nodeinfotag key = {{0}};
	bool		found;
	NODEINFO   *entry;

	strcpy(key.nodeName, serverName);
	strcpy(key.ip, ip);

	entry = hash_search(keepshNodeHash, &key, HASH_FIND, &found);
	if (found)
	{
		*ret = entry->isAlive;
		return true;
	}
	return false;
}


/*
 * Checking server is exist in hash table.
 * This is called by pgspider_core_fdw.
 */
bool
check_server_ipname(char *serverName, char *ip)
{
	HASHCTL		info;
	long		init_table_size,
				max_table_size;
	bool		ret = true;

	max_table_size = max_child_nodes;
	init_table_size = max_table_size / 2;

	/*
	 * attach shared memory
	 */
	MemSet(&info, 0, sizeof(info));
	info.keysize = sizeof(nodeinfotag);
	info.entrysize = sizeof(NODEINFO);
	info.num_partitions = 4;
	if (!keepshNodeHash)
	{
		keepshNodeHash = ShmemInitHash("keep alive",
									   init_table_size,
									   max_table_size,
									   &info,
									   HASH_ELEM | HASH_BLOBS | HASH_PARTITION);
	}
	if (ip == NULL)
		return true;
	/* check node info table */
	if (check_hashtable_with_nodeinfotable(serverName, ip, &ret))
		return ret;
	return true;
}

/*
 * Delete shared hash table elem
 */
static void
delete_oldhash(NODEINFO * nodeInfo, int svrnum)
{
	int			i;
	bool		found;

	for (i = 0; i < svrnum; i++)
	{
		nodeinfotag key = {{0}};

		strcpy(key.nodeName, nodeInfo[i].tag.nodeName);
		strcpy(key.ip, nodeInfo[i].tag.ip);
		hash_search(keepshNodeHash, &key, HASH_REMOVE, &found);
	}
}

static void
join_childs(int numThreads, pthread_t *threads)
{
	int			i;

	join_flag = true;
	for (i = 0; i < numThreads; i++)
	{
		pthread_join(threads[i], NULL);
	}
}

static void
freenodeInfos(int curSvrNum, char **curFdwName, NODEINFO * curNodeInfo)
{
	int			i;

	if (curFdwName != NULL)
	{
		for (i = 0; i < curSvrNum; i++)
		{
			if (curFdwName[i] != NULL)
				pfree(curFdwName[i]);
		}
		if (curFdwName != NULL)
			pfree(curFdwName);
	}
	if (curNodeInfo != NULL)
		pfree(curNodeInfo);
}

/*
 * Get newest server infomation and compare current shared hash.
 * If it is not same, then re-create threads.
 */
static void
check_server_info(NODEINFO * latestNodeInfo, char **latestFdwName, int numThreads, pthread_t *threads, int svrnum)
{
	NODEINFO   *curNodeInfo = NULL;
	char	  **curFdwName = NULL;
	int			curSvrNum = 0;
	int			i;
	int			rc;

	while (!got_sigterm)
	{
		/* Get current server name and IP */
		create_alive_list(NULL, &curNodeInfo, &curFdwName, &curSvrNum);
		if (curSvrNum != svrnum)
		{
			goto END;
		}

		/*
		 * Check hash table's servername and IP same as current server name
		 * and IP
		 */
		for (i = 0; i < curSvrNum; i++)
		{
			if (strcmp(curNodeInfo[i].tag.nodeName, latestNodeInfo[i].tag.nodeName) != 0 ||
				strcmp(curFdwName[i], latestFdwName[i]) != 0)
				goto END;
		}
		freenodeInfos(curSvrNum, curFdwName, curNodeInfo);
		rc = WaitLatch(MyLatch,
					   WL_LATCH_SET | WL_TIMEOUT | WL_POSTMASTER_DEATH,
					   keepalive_time * 1000L,
					   PG_WAIT_EXTENSION);
		if (!rc)
			proc_exit(1);
		curNodeInfo = NULL;
		curFdwName = NULL;
		ResetLatch(MyLatch);
	}
END:
	elog(LOG, "System table is changed. KeepAlive recreate threads.");
	/* join child threads */
	join_childs(numThreads, threads);
	/* delete all hash table data */
	delete_oldhash(latestNodeInfo, svrnum);
	freenodeInfos(curSvrNum, curFdwName, curNodeInfo);
}

/*
 * This is keep alive main thread.
 */
void
worker_pgspider_keepalive(Datum main_arg)
{
	int			i;
	int			numThreads;
	int			svrnum;
	StringInfoData buf;
	pthread_t  *threads = NULL;
	NODEINFO   *nodeInfo = NULL;
	char	  **fdwName = NULL;

	/* Establish signal handlers before unblocking signals. */
	pqsignal(SIGHUP, pgspider_keepalive_sighup);
	pqsignal(SIGTERM, pgspider_keepalive_sigterm);

	/* We're now ready to receive signals */
	BackgroundWorkerUnblockSignals();

	/* Connect to our database */
	BackgroundWorkerInitializeConnection("postgres", NULL, 0);

	pthread_mutex_init(&hash_mutex, NULL);

	/*
	 * Main loop: do this until the SIGTERM handler tells us to terminate
	 */

	/* Init ErrorContext for each child thread */
	ErrorContext = AllocSetContextCreate(TopMemoryContext,
										 "Pgspider keep alive ErrorContext",
										 ALLOCSET_DEFAULT_SIZES);
	MemoryContextAllowInCriticalSection(ErrorContext, true);

	while (!got_sigterm)
	{
		join_flag = false;

		CHECK_FOR_INTERRUPTS();

		/*
		 * In case of a SIGHUP, just reload the configuration.
		 */
		if (got_sighup)
		{
			got_sighup = false;
			ProcessConfigFile(PGC_SIGHUP);
		}
		SetCurrentStatementStartTimestamp();

		/* Create child nodeinfo */
		create_alive_list(&buf, &nodeInfo, &fdwName, &svrnum);
		/* Create hash table in shared memory */
		create_child_info(nodeInfo, &threads, svrnum);
		/* Create child threads */
		create_child_threads(nodeInfo, &numThreads, threads, svrnum);

		/*
		 * check server info. If server information is changed, then return
		 * this routine
		 */
		check_server_info(nodeInfo, fdwName, numThreads, threads, svrnum);

		/* initialize */
		if (fdwName != NULL)
		{
			for (i = 0; i < svrnum; i++)
			{
				pfree(fdwName[i]);
			}
			pfree(fdwName);
		}
		if (nodeInfo != NULL)
			pfree(nodeInfo);
		if (threads != NULL)
			pfree(threads);
		nodeInfo = NULL;
		fdwName = NULL;
		threads = NULL;
	}
	MemoryContextDelete(ErrorContext);
	proc_exit(1);
}

static void
InitSharedMemoryKeepalives()
{
	Size		size = hash_estimate_size(max_child_nodes, sizeof(NODEINFO));

	RequestAddinShmemSpace(size);
}


/*
 * Entrypoint of this module.
 *
 * We register more than one worker process here, to demonstrate how that can
 * be done.
 */
void
_PG_init(void)
{
	BackgroundWorker worker;

	if (!process_shared_preload_libraries_in_progress)
		return;

	/* get the configuration */
	DefineCustomIntVariable("pgspider_keepalive.timeout_time",
							"polling time to child node ",
							NULL,
							&timeout_time,
							10,
							1,
							INT_MAX,
							PGC_POSTMASTER,
							0,
							NULL,
							NULL,
							NULL);

	DefineCustomIntVariable("pgspider_keepalive.keepalive_interval",
							"keep alive interval.",
							NULL,
							&keepalive_time,
							10,
							1,
							INT_MAX,
							PGC_POSTMASTER,
							0,
							NULL,
							NULL,
							NULL);
	DefineCustomIntVariable("pgspider_keepalive.checknodes_interval",
							"Number of workers.",
							NULL,
							&checknodes_interval,
							10,
							1,
							INT_MAX,
							PGC_POSTMASTER,
							0,
							NULL,
							NULL,
							NULL);
	DefineCustomIntVariable("pg_promoter.max_child_nodes",
							"Connection information for primary server",
							NULL,
							&max_child_nodes,
							1024,
							1,
							INT_MAX,
							PGC_POSTMASTER,
							0,
							NULL,
							NULL,
							NULL);
	/* Alloc shared memory */
	InitSharedMemoryKeepalives();
	/* set up common data for all our workers */
	memset(&worker, 0, sizeof(worker));
	worker.bgw_flags = BGWORKER_SHMEM_ACCESS |
		BGWORKER_BACKEND_DATABASE_CONNECTION;
	worker.bgw_start_time = BgWorkerStart_ConsistentState;
	worker.bgw_restart_time = BGW_NEVER_RESTART;
	sprintf(worker.bgw_name, "pgspider_keepalive");
	sprintf(worker.bgw_library_name, "pgspider_keepalive");
	sprintf(worker.bgw_function_name, "worker_pgspider_keepalive");
	worker.bgw_notify_pid = 0;

	/*
	 * Now fill in worker-specific data, and do the actual registrations.
	 */
	shmem_startup_prev = shmem_startup_hook;
	shmem_startup_hook = InitKeepaliveShm;

	RegisterBackgroundWorker(&worker);
}
