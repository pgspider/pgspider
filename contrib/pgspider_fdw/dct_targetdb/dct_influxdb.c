/*-------------------------------------------------------------------------
 *
 * dct_influxdb.c
 *		  Private processing for InfluxDB
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_influxdb/dct_influxdb.c
 *
 *-------------------------------------------------------------------------
 */
#include "dct_influxdb.h"
#include "commands/defrem.h"
#include "utils/guc.h"
#include "utils/varlena.h"
#include "utils/rel.h"

/*
 * Describes the valid options for objects that this wrapper uses.
 */
typedef struct InfluxdbOptions
{
	char	*host;
	int		 port;
	char	*dbname;
	char	*table_name;
	char	*token;
	char	*org;
	List	*tags;
} InfluxdbOptions;

/*
 * InfluxDB FDW does not support org option now, it is specified by user
 * through MIGRATE command.
 * InfluxDB support tags option to indicates this column as containing values
 * of tags in InfluxDB measurement.
 *
 * This function help to ignore its validation in pgspider_fdw.
 */
bool
is_influxdb_unique_option(const char *option_name)
{
	if (strcmp(option_name, "org") == 0 || strcmp(option_name, "tags") == 0 || strcmp(option_name, "table") == 0)
		return true;
	else
		return false;
}

/*
 * Parse a comma-separated string and return a list of tag keys of a foreign table.
 * Specify for only InfluxDB server.
 */
static List *
extract_tags_list(char *in_string)
{
	List	   *tags_list = NIL;

	/* SplitIdentifierString scribbles on its input, so pstrdup first */
	if (!SplitIdentifierString(pstrdup(in_string), ',', &tags_list))
	{
		/* Syntax error in tags list */
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("parameter \"%s\" must be a list of tag keys",
						"tags")));
	}

	return tags_list;
}

/*
 * Get necessary option values for data source.
 */
static void
influxdb_get_option_values(Relation rel, DataCompressionTransferOption * dct_option, InfluxdbOptions *opts)
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
		else if (strcmp(def->defname, "dbname") == 0)
			opts->dbname = defGetString(def);
		else if (strcmp(def->defname, "table") == 0)
			opts->table_name = defGetString(def);
		else if (strcmp(def->defname, "tags") == 0)
			opts->tags = extract_tags_list(defGetString(def));
		else if (strcmp(def->defname, "org") == 0)
			opts->org = defGetString(def);
		else if (strcmp(def->defname, "auth_token") == 0)
			opts->token = defGetString(def);
	}

	if (!opts->org)
		elog(ERROR, "PGSpider: org must be specified along with relay");
}

/*
 * Prepare JSON body for DDL request
 */
void
influxdb_PrepareDDLRequestData(StringInfo jsonBody,
							   int mode,
							   Relation rel,
							   DDLData ddlData,
							   DataCompressionTransferOption * dct_option)
{
	InfluxdbOptions opts;

	memset(&opts, 0, sizeof(opts));
	influxdb_get_option_values(rel, dct_option, &opts);

	appendStringInfoString(jsonBody, "{ ");

	/* DDL_CREATE/DDL_DROP */
	appendStringInfo(jsonBody, "\"mode\": %d, ", mode);

	/* Append AuthenticationData */
	dct_stringInfoAppendStringValue(jsonBody, "token", opts.token, ',');

	/* Append ConnectionURLData */
	dct_stringInfoAppendStringValue(jsonBody, "host", opts.host, ',');
	appendStringInfo(jsonBody, "\"port\" : %d, ", opts.port);
	dct_stringInfoAppendStringValue(jsonBody, "dbName", opts.dbname, ',');
	dct_stringInfoAppendStringValue(jsonBody, "org", opts.org, ',');

	/* Append DDLData */
	dct_stringInfoAppendStringValue(jsonBody, "tableName", opts.table_name, ',');
	appendStringInfo(jsonBody, "\"existFlag\" : %s, ", ddlData.existFlag ? "true" : "false");

	appendStringInfoChar(jsonBody, '}');
}

/*
 * Prepare JSON body for Insert request
 */
void
influxdb_PrepareInsertRequestData(StringInfo jsonBody,
								  PGSpiderFdwModifyState *fmstate,
								  ColumnInfo *columnInfos,
								  int numColumn,
								  char *socket_host,
								  int socket_port,
								  DataCompressionTransferOption * dct_option)
{
	Relation rel;
	InfluxdbOptions opts;
	ListCell *lc;

	rel = fmstate->rel;
	memset(&opts, 0, sizeof(opts));
	influxdb_get_option_values(rel, dct_option, &opts);

	/* parse all data to json */
	appendStringInfoString(jsonBody, "{ ");

	/* BATCH INSERT */
	appendStringInfo(jsonBody, "\"mode\": %d, ", BATCH_INSERT);

	dct_stringInfoAppendStringValue(jsonBody, "host_socket", socket_host, ',');
	appendStringInfo(jsonBody, "\"port_socket\" : %d, ", socket_port);
	appendStringInfo(jsonBody, "\"serverID\": %d, ", fmstate->socketThreadInfo.serveroid);
	appendStringInfo(jsonBody, "\"tableID\" : %d, ", fmstate->socketThreadInfo.tableoid);

	/* Append AuthenticationData */
	dct_stringInfoAppendStringValue(jsonBody, "token", opts.token, ',');

	/* Append ConnectionURLData */
	dct_stringInfoAppendStringValue(jsonBody, "host", opts.host, ',');
	appendStringInfo(jsonBody, "\"port\" : %d, ", opts.port);
	dct_stringInfoAppendStringValue(jsonBody, "dbName", opts.dbname, ',');
	dct_stringInfoAppendStringValue(jsonBody, "org", opts.org, ',');

	/* Append Schema Data */
	dct_stringInfoAppendStringValue(jsonBody, "tableName", opts.table_name, ',');
	appendStringInfo(jsonBody, "\"numColumn\" : %d, ", numColumn);
	appendStringInfoString(jsonBody, "\"columnInfos\"");
	appendStringInfoChar(jsonBody, ':');
	dct_jsonifyColumnInfo(jsonBody, columnInfos, numColumn);

	if (list_length(opts.tags) == 0)
		appendStringInfoString(jsonBody, ", \"tags\" : null");
	else
	{
		bool		is_first = true;

		appendStringInfoString(jsonBody, ", \"tags\" : [");

		foreach(lc, opts.tags)
		{
			char *tag_key = (char *) lfirst(lc);

			if (!is_first)
				appendStringInfoString(jsonBody, ", ");

			appendStringInfo(jsonBody, "\"%s\"", dct_escape_json_string(tag_key));	/* \"value\" */

			is_first = false;
		}
		appendStringInfoString(jsonBody, "]");
	}


	appendStringInfoChar(jsonBody, '}');
}
