/*-------------------------------------------------------------------------
 *
 * pgspider_core_routing.c
 *		  Management of insert target node
 *
 * Portions Copyright (c) 2022, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_core_fdw/pgspider_core_routing.c
 *
 *-------------------------------------------------------------------------
 */
#include <stddef.h>
#include "postgres.h"
#include "access/table.h"
#include "c.h"
#include "foreign/fdwapi.h"
#include "fmgr.h"
#include "lib/dshash.h"
#include "nodes/parsenodes.h"
#include "nodes/pg_list.h"
#include "pg_config_manual.h"
#include "pgspider_core_fdw.h"
#include "postgres_ext.h"
#include "utils/datum.h"
#include "utils/dsa.h"
#include "utils/elog.h"
#include "utils/lsyscache.h"
#include "utils/memutils.h"
#include "utils/rel.h"
#include "utils/relcache.h"

#ifndef WITHOUT_KEEPALIVE
#include "pgspider_keepalive/pgspider_keepalive.h"
#endif
#include "pgspider_core_routing.h"

/* Structure for data stored in DSA (Dynamic Shared memory Area) . */
typedef struct SpdRoutingShared
{
	dshash_table_handle hash_handle;	/* Handle of hash table on DSA which
										 * storing last insert tergets */
	int			tranche_id;		/* A tranche ID of DSA for insert routing */
}			SpdRoutingShared;

/* Structure for data stored in global variable. */
typedef struct SpdRoutingGlb
{
	SpdRoutingShared *shared;	/* Address of shared data via DSA */
	dsa_area   *area;			/* DSA handle */
	dshash_table *hash;			/* Hash table storing last insert tergets */
}			SpdRoutingGlb;

/* An element of hash table on DSA storing a last insert terget. */
typedef struct SpdRoutingElem
{
	Oid			parent;			/* Parent table oid: hash key (must be first) */
	Oid			child;			/* Child table oid */
	char		tablename[NAMEDATALEN]; /* Child table name */
}			SpdRoutingElem;

/* Common data used by insert routing feature shared in a process. */
static SpdRoutingGlb spd_routing_glb;

/* Macros to access a global variable. */
#define g_spd_routing_shared		(spd_routing_glb.shared)
#define g_spd_routing_area		(spd_routing_glb.area)
#define g_spd_routing_hash		(spd_routing_glb.hash)

/*
 * spd_routing_handle_candidate_error
 *		Handles an error occurred on child table.
 *
 *	If throwCandidateError is true, this function throws an error. Else,
 *	report a warning.
 */
void
spd_routing_handle_candidate_error(MemoryContext ccxt, char *relname)
{
	int			elevel;
	MemoryContext ecxt = MemoryContextSwitchTo(ccxt);
	ErrorData  *errdata = CopyErrorData();
	char	   *message;

	/* Get an error message occurred in datasource FDW. */
	message = pstrdup(errdata->message);
	FreeErrorData(errdata);
	FlushErrorState();

	if (throwCandidateError)
	{
		elevel = ERROR;
		MemoryContextSwitchTo(ecxt);
	}
	else
		elevel = WARNING;

	ereport(elevel,
			(errcode(ERRCODE_FDW_ERROR),
			 errmsg("Error occurred on a child table \"%s\".",
					relname),
			 errdetail_internal("%s", message)));
}

/**
 * spd_check_candidate_count
 * 		Check the number of candidates is greater than 0.
 */
static void
spd_check_candidate_count(ChildInfo * pChildInfo, int node_num)
{
	int			i;
	int			num_targets = 0;

	for (i = 0; i < node_num; i++)
	{
		if (pChildInfo[i].child_node_status == ServerStatusAlive)
			num_targets++;
	}
	if (num_targets == 0)
		ereport(ERROR, (errmsg("There is no candidate for INSERT.")));
}

/**
 * spd_candidate_updatable
 *		Check if each child table is updatable or not.
 *
 * If a child table is not updatable, child_node_status is set to
 * ServerStatusNotTarget.
 */
static void
spd_candidate_updatable(ChildInfo * pChildInfo, int node_num)
{
	int			i;
	MemoryContext ccxt = CurrentMemoryContext;

	for (i = 0; i < node_num; i++)
	{
		int			updatable = 0;
		ChildInfo  *pChild = &pChildInfo[i];
		Relation	rel;

		if (pChild->child_node_status != ServerStatusAlive)
			continue;

		rel = RelationIdGetRelation(pChild->oid);

		PG_TRY();
		{
			Oid			server_oid = spd_serverid_of_relation(pChild->oid);
			FdwRoutine *fdwroutine = GetFdwRoutineByServerId(server_oid);

			if (fdwroutine->IsForeignRelUpdatable)
				updatable = fdwroutine->IsForeignRelUpdatable(rel);
			else
				updatable = (1 << CMD_INSERT);
		}
		PG_CATCH();
		{
			char	   *relname = RelationGetRelationName(rel);

			spd_routing_handle_candidate_error(ccxt, relname);
			pChild->child_node_status = ServerStatusNotTarget;
		}
		PG_END_TRY();

		RelationClose(rel);

		if ((updatable & (1 << CMD_INSERT)) == 0)
			pChild->child_node_status = ServerStatusNotTarget;
	}

	/* Check the number of candidates. */
	spd_check_candidate_count(pChildInfo, node_num);
}

/**
 * spd_candidate_alive
 *		Check if each child table is alive or not.
 *
 * If a child table is not alive, child_node_status is set to
 * ServerStatusDead.
 */
static void
spd_candidate_alive(ChildInfo * pChildInfo, int node_num)
{
#ifndef WITHOUT_KEEPALIVE
	int			i;
	MemoryContext ccxt = CurrentMemoryContext;

	for (i = 0; i < node_num; i++)
	{
		char		ip[NAMEDATALEN] = {0};
		Oid			server_oid;
		ForeignServer *fs;

		if (pChildInfo[i].child_node_status != ServerStatusAlive)
			continue;

		server_oid = spd_serverid_of_relation(pChildInfo[i].oid);
		fs = GetForeignServer(server_oid);

		spd_ip_from_server_name(fs->servername, ip);

		if (!check_server_ipname(fs->servername, ip))
		{
			Relation	rel = RelationIdGetRelation(pChildInfo[i].oid);
			char	   *relname = RelationGetRelationName(rel);

			spd_routing_handle_candidate_error(ccxt, relname);
			pChildInfo[i].child_node_status = ServerStatusDead;
			RelationClose(rel);
		}
	}

	/* Check the number of candidates. */
	spd_check_candidate_count(pChildInfo, node_num);
#endif
}

/**
 * spd_routing_candidate_validate
 * 		Validate candidates of insert targets on prepare phase.
 * 		On this phase, we can check (1) whether child table is updatable or not,
 * 		and (2) whether child table is alive or not.
 * 		If a child table is detected as not target, child_node_status is set to
 * 		ServerStatusNotTarget.
 */
void
spd_routing_candidate_validate(ChildInfo * pChildInfo, int node_num)
{
	spd_check_candidate_count(pChildInfo, node_num);

	spd_candidate_alive(pChildInfo, node_num);

	spd_candidate_updatable(pChildInfo, node_num);
}

/**
 * spd_get_spdurl_in_slot
 * 		Get SPDURL column value as string in slot.
 */
static char *
spd_get_spdurl_in_slot(TupleTableSlot *slot, TupleDesc tupdesc)
{
	int			attnum;			/* Attrnum of SPDURL column */
	Form_pg_attribute attr;
	Datum		value;
	bool		isnull;
	Oid			typefnoid;
	bool		isvarlena;
	FmgrInfo	flinfo;
	char	   *spdurl;

	/* Get SPDURL column value as Datum. */
	attnum = tupdesc->natts;
	attr = TupleDescAttr(tupdesc, attnum - 1);
	value = slot_getattr(slot, attnum, &isnull);

	/* Do nothing if SPDURL is NULL. */
	if (isnull)
		return NULL;

	/* Get SPDURL column value as string. */
	getTypeOutputInfo(attr->atttypid, &typefnoid, &isvarlena);
	fmgr_info(typefnoid, &flinfo);
	spdurl = OutputFunctionCall(&flinfo, value);

	if (spdurl != NULL && spdurl[0] != '/')
		elog(ERROR, "Failed to parse URL '%s'. The first character should be '/'.", spdurl);

	return spdurl;
}

/**
 * spd_routing_candidate_spdurl
 * 		Remove un-related tables from candidates based on SPDURL
 * 		column value.
 *
 * 		child_node_status will be set to ServerStatusNotTarget from ServerStatusAlive if un-related table.
 */
void
spd_routing_candidate_spdurl(TupleTableSlot *slot, Relation rel, ChildInfo * pChildInfo, int node_num)
{
	TupleDesc	tupdesc;
	char	   *spdurl;

	/* Get SPDURL value. */
	tupdesc = RelationGetDescr(rel);
	spdurl = spd_get_spdurl_in_slot(slot, tupdesc);

	/* Do nothing if SPDURL is not specified. */
	if (!spdurl)
		return;

	spd_create_child_url(list_make1(makeString(spdurl)), pChildInfo, node_num, true);

	/* Check the number of candidates. */
	spd_check_candidate_count(pChildInfo, node_num);
}

/**
 * spd_routing_last_table
 * 		Find the last insert target. If it is found, the 2nd argument will
 * 		be set to true. Even if the table has been renamed, the 2nd argument
 * 		will be set to false.
 * 		This function returns a hash entry for the target.
 * 		Write lock for shared hash will be acquired.
 */
static SpdRoutingElem *
spd_routing_last_table(Oid parent, bool *found)
{
	SpdRoutingElem *entry;
	char	   *relname;

	entry = dshash_find_or_insert(g_spd_routing_hash, &parent, found);

	if (!(*found))
		return entry;

	/* Get the current table name of child table. */
	relname = get_rel_name(entry->child);

	/* Check whether child table was renamed. */
	if (!relname || strcmp(relname, entry->tablename) != 0)
		*found = false;

	return entry;
}

/**
 * spd_routing_choose
 * 		Choose one child table from candidate for insert.
 */
static int
spd_routing_choose(char *prev_name, ModifyThreadInfo * mtThrdInfo,
				   ChildInfo * pChildInfo, int node_num)
{
	int			i;

	/*
	 * If the previous inserted table is memorized, search the position in
	 * candidates and choose the next one.
	 */
	if (prev_name != NULL)
	{
		for (i = 0; i < node_num; i++)
		{
			int			idx = mtThrdInfo[i].childInfoIndex;
			char	   *relname = get_rel_name(pChildInfo[idx].oid);
			int			cmp = strcmp(prev_name, relname);

			if (cmp >= 0)
				continue;

			if (pChildInfo[idx].child_node_status == ServerStatusAlive)
				return i;
		}

		/*
		 * Here, the previous table name is a last element in candidates. So
		 * the first child table in candidate will be choosen.
		 */
	}

	/* Find the first child table in candidates. */
	for (i = 0; i < node_num; i++)
	{
		int			idx = mtThrdInfo[i].childInfoIndex;

		if (pChildInfo[idx].child_node_status == ServerStatusAlive)
			return i;
	}

	/* Should not reach here. */
	ereport(ERROR, (errmsg("Cannot find an INSERT target.")));
}

/**
 * spd_routing_get_target
 * 		Choose one child table from candidate for insert
 * 		and memorize it in shared memory.
 * 		This function returns an index of target in ModifyThreadInfo array.
 */
int
spd_routing_get_target(Oid parent, ModifyThreadInfo * mtThrdInfo,
					   ChildInfo * pChildInfo, int node_num)
{
	SpdRoutingElem *entry;
	bool		found;
	char	   *prev_name;
	int			i;
	int			idx;
	char	   *relname;

	/* Find the last target and get a lock for the shared hash. */
	entry = spd_routing_last_table(parent, &found);

	/* Choose the insert target. */
	if (found)
		prev_name = entry->tablename;
	else
		prev_name = NULL;

	i = spd_routing_choose(prev_name, mtThrdInfo, pChildInfo, node_num);

	/* Update target information in shared memory. */
	idx = mtThrdInfo[i].childInfoIndex;
	relname = get_rel_name(pChildInfo[idx].oid);
	entry->child = pChildInfo[idx].oid;
	strcpy(entry->tablename, relname);

	/* Release the lock. */
	dshash_release_lock(g_spd_routing_hash, entry);

	return i;
}

/**
 * spd_routing_set_target
 * 		Set the last child table.
 * 		This function returns set target success or not.
 */
bool
spd_routing_set_target(Oid parent, ModifyThreadInfo * mtThrdInfo,
					   ChildInfo * pChildInfo, int last_node)
{
	SpdRoutingElem *entry;
	int			idx;
	char	   *relname;

	/* Find the last target and get a lock for the shared hash. */
	entry = dshash_find(g_spd_routing_hash, &parent, true);

	if (entry == NULL)
		return false;

	/* Update target information in shared memory. */
	idx = mtThrdInfo[last_node].childInfoIndex;
	relname = get_rel_name(pChildInfo[idx].oid);
	entry->child = pChildInfo[idx].oid;
	strcpy(entry->tablename, relname);

	/* Release the lock. */
	dshash_release_lock(g_spd_routing_hash, entry);

	return true;
}

static dshash_parameters
spd_routing_dshash_params(int tranche_id)
{
	dshash_parameters params = {
		sizeof(Oid),
		sizeof(SpdRoutingElem),
		dshash_memcmp,
		dshash_memhash,
		tranche_id
	};

	return params;
}

/**
 * spd_routing_init_dsa
 * 		Create a dynamic shared memory area and a shared data in it.
 *		The location for the shared data is stored in the first argument.
 *		One of the shared data is a hash table which manages an insert target.
 */
static void
spd_routing_init_dsa(SpdInsertTargetLocation * location)
{
	dsa_area   *area;
	dsa_pointer dp;
	SpdRoutingShared *its;
	int			tranche_id;
	dshash_parameters hash_params;
	MemoryContext oldMemoryContext;

	/*
	 * Use the top memory context to keep global variables during a worker
	 * process alive.
	 */
	oldMemoryContext = MemoryContextSwitchTo(TopMemoryContext);

	/*
	 * Create a dynamic shared memory area. This area is kept even if backend
	 * is detached or query is finished.
	 */
	area = dsa_create(LWLockNewTrancheId());
	dsa_pin(area);
	dsa_pin_mapping(area);

	/* Set the global variable. */
	g_spd_routing_area = area;

	/* Create the hash table. */
	tranche_id = LWLockNewTrancheId();
	hash_params = spd_routing_dshash_params(tranche_id);
	g_spd_routing_hash = dshash_create(area, &hash_params, NULL);

	MemoryContextSwitchTo(oldMemoryContext);

	/* Create and set shared variables. */
	dp = dsa_allocate0(area, sizeof(SpdRoutingShared));
	its = (SpdRoutingShared *) dsa_get_address(area, dp);
	its->hash_handle = dshash_get_hash_table_handle(g_spd_routing_hash);
	its->tranche_id = tranche_id;

	/* Register the location of shared variables in shared memory. */
	location->handle = dsa_get_handle(area);
	location->pointer = dp;
}

/**
 * spd_routing_init_shm
 *		Initialize a shared memory for insert target. The shared memory stores
 *		a location for a dynamic shared memory for insert target.
 *
 *		Node:
 *			RequestAddinShmemSpace(sizeof(SpdInsertTargetLocation)); should be
 *			called in CreateSharedMemoryAndSemaphores() during server
 *			initialization.
 */
void
spd_routing_init_shm(void)
{
	SpdInsertTargetLocation *location;
	bool		found;

	/* Get a lock for use of shared memory. */
	LWLockAcquire(AddinShmemInitLock, LW_EXCLUSIVE);

	location = (SpdInsertTargetLocation *) ShmemInitStruct("location of insert target",
														   sizeof(SpdInsertTargetLocation),
														   &found);

	if (!found)
	{
		/* Initialize the variable in dynamic shared memory. */
		spd_routing_init_dsa(location);

		/* Set the global variable. */
		g_spd_routing_shared = (SpdRoutingShared *) dsa_get_address(g_spd_routing_area, location->pointer);
	}
	else
	{
		dshash_parameters hash_params;
		MemoryContext oldMemoryContext;

		oldMemoryContext = MemoryContextSwitchTo(TopMemoryContext);

		/* Set global variables. */
		g_spd_routing_area = dsa_attach(location->handle);
		dsa_pin_mapping(g_spd_routing_area);

		g_spd_routing_shared = (SpdRoutingShared *) dsa_get_address(g_spd_routing_area, location->pointer);
		hash_params = spd_routing_dshash_params(g_spd_routing_shared->tranche_id);

		g_spd_routing_hash = dshash_attach(g_spd_routing_area, &hash_params, g_spd_routing_shared->hash_handle, NULL);

		MemoryContextSwitchTo(oldMemoryContext);
	}

	LWLockRelease(AddinShmemInitLock);
}
