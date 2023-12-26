/*-------------------------------------------------------------------------
 *
 * dct_griddb.c
 *		  Private processing for GridDB
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_griddb/dct_griddb.c
 *
 *-------------------------------------------------------------------------
 */
#include "dct_griddb.h"
#include "commands/defrem.h"
#include "utils/guc.h"
#include "utils/rel.h"

/*
 * Describes the valid options for objects that this wrapper uses.
 */
typedef struct GriddbOptions
{
	char	*host;
	int		 port;
	char	*dbname;
	char	*clusterName;
	char	*table_name;
	char	*username;
	char	*password;
} GriddbOptions;

/*
 * There is no option that is different from pgspider_fdw, so no unique option.
 * This function always return false.
 */
bool
is_griddb_unique_option(const char *option_name)
{
	return false;
}

/*
 * Get necessary option values for data source.
 */
static void
griddb_get_option_values(Relation rel, DataCompressionTransferOption * dct_option, GriddbOptions *opts)
{
	List	   *options;
	ListCell   *lc;
	ForeignServer *source_server;
	ForeignTable *table;
	UserMapping *user;

	/* Get foreign table of pgspider_fdw */
	table = GetForeignTable(RelationGetRelid(rel));
	/* Get source server (not relay server)*/
	source_server = GetForeignServer(dct_option->serverID);
	user = GetUserMapping(dct_option->userID, dct_option->serverID);

	options = NIL;
	options = list_concat(options, source_server->options);
	options = list_concat(options, table->options);
	options = list_concat(options, user->options);

	foreach(lc, options)
	{
		DefElem	*def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "host") == 0)
			opts->host = defGetString(def);
		else if (strcmp(def->defname, "port") == 0)
			(void) parse_int(defGetString(def), &opts->port, 0, NULL);
		else if (strcmp(def->defname, "database") == 0)
			opts->dbname = defGetString(def);
		else if (strcmp(def->defname, "clustername") == 0)
			opts->clusterName = defGetString(def);
		else if (strcmp(def->defname, "table_name") == 0)
			opts->table_name = defGetString(def);
		else if (strcmp(def->defname, "username") == 0)
			opts->username = defGetString(def);
		else if (strcmp(def->defname, "password") == 0)
			opts->password = defGetString(def);
	}

	/* database of griddb_fdw, default public */
	if (opts->dbname == NULL)
	{
		opts->dbname = "public";
	}
}

/*
 * Prepare JSON body for DDL request
 */
void
griddb_PrepareDDLRequestData(StringInfo jsonBody,
							int mode,
							Relation rel,
							DDLData ddlData,
							DataCompressionTransferOption * dct_option)
{
	GriddbOptions opts;

	memset(&opts, 0, sizeof(opts));
	griddb_get_option_values(rel, dct_option, &opts);

	appendStringInfoString(jsonBody, "{ ");

	/* DDL_CREATE/DDL_DROP */
	appendStringInfo(jsonBody, "\"mode\": %d, ", mode);

	/* Append AuthenticationData */
	dct_stringInfoAppendStringValue(jsonBody, "user", opts.username, ',');
	dct_stringInfoAppendStringValue(jsonBody, "pass", opts.password, ',');

	/* Append ConnectionURLData */
	dct_stringInfoAppendStringValue(jsonBody, "host", opts.host, ',');
	appendStringInfo(jsonBody, "\"port\" : %d, ", opts.port);
	dct_stringInfoAppendStringValue(jsonBody, "clusterName", opts.clusterName, ',');
	dct_stringInfoAppendStringValue(jsonBody, "dbName", opts.dbname, ',');

	/* Append DDLData */
	dct_stringInfoAppendStringValue(jsonBody, "tableName", opts.table_name, ',');
	appendStringInfo(jsonBody, "\"numColumn\" : %d, ", ddlData.numColumn);
	appendStringInfo(jsonBody, "\"existFlag\" : %s, ", ddlData.existFlag ? "true" : "false");
	appendStringInfoString(jsonBody, "\"columnInfos\"");
	appendStringInfoChar(jsonBody, ':');
	dct_jsonifyColumnInfo(jsonBody, ddlData.columnInfos, ddlData.numColumn); /* last element */

	appendStringInfoChar(jsonBody, '}');
}

/*
 * Prepare JSON body for Insert request
 */
void
griddb_PrepareInsertRequestData(StringInfo jsonBody,
							   PGSpiderFdwModifyState *fmstate,
							   ColumnInfo *columnInfos,
							   int numColumn,
							   char *socket_host,
							   int socket_port,
							   DataCompressionTransferOption * dct_option)
{
	Relation rel;
	GriddbOptions opts;

	rel = fmstate->rel;
	memset(&opts, 0, sizeof(opts));
	griddb_get_option_values(rel, dct_option, &opts);

	/* parse all data to json */
	appendStringInfoString(jsonBody, "{ ");

	/* BATCH INSERT */
	appendStringInfo(jsonBody, "\"mode\": %d, ", BATCH_INSERT);

	dct_stringInfoAppendStringValue(jsonBody, "host_socket", socket_host, ',');
	appendStringInfo(jsonBody, "\"port_socket\" : %d, ", fmstate->socket_port);
	appendStringInfo(jsonBody, "\"serverID\": %d, ", fmstate->socketThreadInfo.serveroid);
	appendStringInfo(jsonBody, "\"tableID\" : %d, ", fmstate->socketThreadInfo.tableoid);

	/* Append AuthenticationData */
	dct_stringInfoAppendStringValue(jsonBody, "user", opts.username, ',');
	dct_stringInfoAppendStringValue(jsonBody, "pass", opts.password, ',');

	/* Append ConnectionURLData */
	dct_stringInfoAppendStringValue(jsonBody, "host", opts.host, ',');
	appendStringInfo(jsonBody, "\"port\" : %d, ", opts.port);
	dct_stringInfoAppendStringValue(jsonBody, "clusterName", opts.clusterName, ',');
	dct_stringInfoAppendStringValue(jsonBody, "dbName", opts.dbname, ',');

	/* Append Schema Data */
	dct_stringInfoAppendStringValue(jsonBody, "tableName", opts.table_name, ',');
	appendStringInfo(jsonBody, "\"numColumn\" : %d, ", numColumn);
	appendStringInfoString(jsonBody, "\"columnInfos\"");
	appendStringInfoChar(jsonBody, ':');
	dct_jsonifyColumnInfo(jsonBody, columnInfos, numColumn);

	appendStringInfoChar(jsonBody, '}');
}
