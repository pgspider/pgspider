/*-------------------------------------------------------------------------
 *
 * dct_oracle.c
 *		  Private processing for Oracle
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_oracle/dct_oracle.c
 *
 *-------------------------------------------------------------------------
 */
#include "dct_oracle.h"
#include "commands/defrem.h"
#include "utils/guc.h"
#include "utils/rel.h"

/*
 * Describes the valid options for objects that this wrapper uses.
 */
typedef struct OracleOptions
{
	char	*host;
	char	*dbname;
	char	*table_name;
	char	*username;
	char	*password;
} OracleOptions;

/*
 * Oracle FDW uses table option instead of table_name option.
 */
bool
is_oracle_unique_option(const char *option_name)
{
	if (strcmp(option_name, "table") == 0)
		return true;
	else
		return false;
}

/*
 * Get necessary option values for data source.
 */
static void
oracle_get_option_values(Relation rel, DataCompressionTransferOption * dct_option, OracleOptions *opts)
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

		/*
		* oracle_fdw support 'dbserver' options as a connection string.
		* So just use only 'dbserver' option as a 'host' for connectionURLData.
		*/
		if (strcmp(def->defname, "dbserver") == 0)
			opts->host = defGetString(def);
		/* oracle use 'dbname' same name with 'user' of usermapping */
		else if (strcmp(def->defname, "user") == 0)
		{
			opts->dbname = defGetString(def);
			opts->username = defGetString(def);
		}
		else if (strcmp(def->defname, "table") == 0)
			opts->table_name = defGetString(def);
		else if (strcmp(def->defname, "password") == 0)
			opts->password = defGetString(def);
	}
}

/*
 * Prepare JSON body for DDL request
 */
void
oracle_PrepareDDLRequestData(StringInfo jsonBody,
							int mode,
							Relation rel,
							DDLData ddlData,
							DataCompressionTransferOption * dct_option)
{
	OracleOptions opts;

	memset(&opts, 0, sizeof(opts));
	oracle_get_option_values(rel, dct_option, &opts);

	appendStringInfoString(jsonBody, "{ ");

	/* DDL_CREATE/DDL_DROP */
	appendStringInfo(jsonBody, "\"mode\": %d, ", mode);

	/* Append AuthenticationData */
	dct_stringInfoAppendStringValue(jsonBody, "user", opts.username, ',');
	dct_stringInfoAppendStringValue(jsonBody, "pass", opts.password, ',');

	/* Append ConnectionURLData */
	dct_stringInfoAppendStringValue(jsonBody, "host", opts.host, ',');
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
oracle_PrepareInsertRequestData(StringInfo jsonBody,
							   PGSpiderFdwModifyState *fmstate,
							   ColumnInfo *columnInfos,
							   int numColumn,
							   char *socket_host,
							   int socket_port,
							   DataCompressionTransferOption * dct_option)
{
	Relation rel;
	OracleOptions opts;

	rel = fmstate->rel;
	memset(&opts, 0, sizeof(opts));
	oracle_get_option_values(rel, dct_option, &opts);

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
	dct_stringInfoAppendStringValue(jsonBody, "dbName", opts.dbname, ',');

	/* Append Schema Data */
	dct_stringInfoAppendStringValue(jsonBody, "tableName", opts.table_name, ',');
	appendStringInfo(jsonBody, "\"numColumn\" : %d, ", numColumn);
	appendStringInfoString(jsonBody, "\"columnInfos\"");
	appendStringInfoChar(jsonBody, ':');
	dct_jsonifyColumnInfo(jsonBody, columnInfos, numColumn);

	appendStringInfoChar(jsonBody, '}');
}
