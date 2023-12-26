/*-------------------------------------------------------------------------
 *
 * dct_objstorage.c
 *		  Private processing for Object Storage
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_targetdb/dct_objstorage.c
 *
 *-------------------------------------------------------------------------
 */
#include "dct_objstorage.h"
#include "commands/defrem.h"
#include "utils/guc.h"
#include "utils/rel.h"

/*
 * Describes the valid options for objects that this wrapper uses.
 */
typedef struct ObjStorageOptions
{
	char	*endpoint;     /* Contain host and port information of cloud storage */
	char	*region;       /* Contain the region information of cloud storage */
	char	*storage_type; /* Determine the storage type */
	char	*format;       /* Determine the file format */
	char	*user;         /* User name or access key for connecting to cloud storage */
	char	*password;     /* Password or secret key for connecting to cloud storage */
	char	*filename;     /* Path of file to insert on clound storage */
	char	*dirname;      /* Path to directory to insert on clound storage */
} ObjStorageOptions;

/*
 * Check whether the given option_name is Object Storage's unique option or not.
 * Return true if it is Object Storage's unique option.
 * Return false if it is not Object Storage's unique option.
 *
 * pgspider's is_valid_option() function calls this function to ignore unique option validation
 * if the given option is Object Storage's unique option.
 */
bool
is_objstorage_unique_option(const char *option_name)
{
	if (strcmp(option_name, "region") == 0 ||
		strcmp(option_name, "storage_type") == 0 ||
		strcmp(option_name, "format") == 0 ||
		strcmp(option_name, "dirname") == 0 ||
		strcmp(option_name, "filename") == 0)
		return true;
	else
		return false;
}

/*
 * Get necessary option values for data source.
 */
static void
objstorage_get_option_values(Relation rel, DataCompressionTransferOption * dct_option, ObjStorageOptions *opts)
{
	List	   *options;
	ListCell   *lc;
	ForeignServer *target_server;
	ForeignTable *table;
	UserMapping *user;

	/* Get foreign table of pgspider_fdw */
	table = GetForeignTable(RelationGetRelid(rel));
	/* Get source server (not relay server)*/
	target_server = GetForeignServer(dct_option->serverID);
	user = GetUserMapping(dct_option->userID, dct_option->serverID);

	options = NIL;
	options = list_concat(options, target_server->options);
	options = list_concat(options, table->options);
	options = list_concat(options, user->options);

	foreach(lc, options)
	{
		DefElem	*def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "endpoint") == 0)
		{
			opts->endpoint = defGetString(def);
		}
		else if (strcmp(def->defname, "region") == 0)
		{
			opts->region = defGetString(def);
		}
		else if (strcmp(def->defname, "storage_type") == 0)
		{
			char *storageType = defGetString(def);

			/* Only support s3 storage */
			if (strcmp(storageType, "s3") == 0)
				opts->storage_type = defGetString(def);
			else
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("Only support \"s3\" storage type")));
		}
		else if (strcmp(def->defname, "format") == 0)
		{
			char *format;
			format = defGetString(def);

			/* Only support parquet format */
			if (strcmp(format, "parquet") == 0)
				opts->format = defGetString(def);
			else
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("Only support \"parquet\" format")));
		}
		else if (strcmp(def->defname, "user") == 0)
			opts->user = defGetString(def);
		else if (strcmp(def->defname, "password") == 0)
			opts->password = defGetString(def);
		else if (strcmp(def->defname, "filename") == 0)
			opts->filename = defGetString(def);
		else if (strcmp(def->defname, "dirname") == 0)
			opts->dirname = defGetString(def);
	}

	/* Either region or endpoint is required */
	if (opts->region == NULL && opts->endpoint == NULL)
		ereport(ERROR,
			(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("either \"region\" or \"endpoint\" is required")));
	/* region and endpoint cannot set at the same time */
	else if (opts->region != NULL && opts->endpoint != NULL)
		ereport(ERROR,
			(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("\"region\" and \"endpoint\" cannot set at the same time")));

	/* Either filename or dirname is required */
	if (opts->filename == NULL && opts->dirname == NULL)
		ereport(ERROR,
			(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("either \"filename\" or \"dirname\" is required")));
	/* filename and dirname cannot set at the same time */
	else if (opts->filename != NULL && opts->dirname != NULL)
		ereport(ERROR,
			(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("\"filename\" and \"dirname\" cannot set at the same time")));

	/* storage_stype is required */
	if (opts->storage_type == NULL)
		ereport(ERROR,
			(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("\"storage_type\" is required")));

	/* format is required */
	if (opts->format == NULL)
		ereport(ERROR,
			(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("\"format\" is required")));

	/* user is required */
	if (opts->user == NULL)
		ereport(ERROR,
			(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("\"user\" is required")));

	/* password is required */
	if (opts->password == NULL)
		ereport(ERROR,
			(errcode(ERRCODE_INVALID_PARAMETER_VALUE), errmsg("\"password\" is required")));

	/* default value of region */
	if (opts->region == NULL)
		opts->region = "ap-northeast-1";
}

/*
 * Prepare JSON body for DDL request
 */
void
objstorage_PrepareDDLRequestData(StringInfo jsonBody,
							   int mode,
							   Relation rel,
							   DDLData ddlData,
							   DataCompressionTransferOption * dct_option)
{
	ObjStorageOptions opts;

	memset(&opts, 0, sizeof(opts));
	objstorage_get_option_values(rel, dct_option, &opts);

	appendStringInfoString(jsonBody, "{ ");

	/* DDL_CREATE/DDL_DROP */
	appendStringInfo(jsonBody, "\"mode\": %d, ", mode);

	/* Append AuthenticationData */
	dct_stringInfoAppendStringValue(jsonBody, "user", opts.user, ',');
	dct_stringInfoAppendStringValue(jsonBody, "pass", opts.password, ',');

	/* Append ConnectionURLData */
	dct_stringInfoAppendStringValue(jsonBody, "endpoint", opts.endpoint, ',');
	dct_stringInfoAppendStringValue(jsonBody, "region", opts.region, ',');
	dct_stringInfoAppendStringValue(jsonBody, "storage_type", opts.storage_type, ',');
	dct_stringInfoAppendStringValue(jsonBody, "format", opts.format, ',');

	/* Append DDLData */
	dct_stringInfoAppendStringValue(jsonBody, "filename", opts.filename, ',');
	dct_stringInfoAppendStringValue(jsonBody, "dirname", opts.dirname, ',');
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
objstorage_PrepareInsertRequestData(StringInfo jsonBody,
								  PGSpiderFdwModifyState *fmstate,
								  ColumnInfo *columnInfos,
								  int numColumn,
								  char *socket_host,
								  int socket_port,
								  DataCompressionTransferOption * dct_option)
{
	Relation rel;
	ObjStorageOptions opts;

	rel = fmstate->rel;
	memset(&opts, 0, sizeof(opts));
	objstorage_get_option_values(rel, dct_option, &opts);

	/* parse all data to json */
	appendStringInfoString(jsonBody, "{ ");

	/* BATCH INSERT */
	appendStringInfo(jsonBody, "\"mode\": %d, ", BATCH_INSERT);

	dct_stringInfoAppendStringValue(jsonBody, "host_socket", socket_host, ',');
	appendStringInfo(jsonBody, "\"port_socket\" : %d, ", fmstate->socket_port);
	appendStringInfo(jsonBody, "\"serverID\": %d, ", fmstate->socketThreadInfo.serveroid);
	appendStringInfo(jsonBody, "\"tableID\" : %d, ", fmstate->socketThreadInfo.tableoid);

	/* Append AuthenticationData */
	dct_stringInfoAppendStringValue(jsonBody, "user", opts.user, ',');
	dct_stringInfoAppendStringValue(jsonBody, "pass", opts.password, ',');

	/* Append ConnectionURLData */
	dct_stringInfoAppendStringValue(jsonBody, "endpoint", opts.endpoint, ',');
	dct_stringInfoAppendStringValue(jsonBody, "region", opts.region, ',');
	dct_stringInfoAppendStringValue(jsonBody, "storage_type", opts.storage_type, ',');
	dct_stringInfoAppendStringValue(jsonBody, "format", opts.format, ',');

	/* Append Schema Data */
	dct_stringInfoAppendStringValue(jsonBody, "filename", opts.filename, ',');
	dct_stringInfoAppendStringValue(jsonBody, "dirname", opts.dirname, ',');
	appendStringInfo(jsonBody, "\"numColumn\" : %d, ", numColumn);
	appendStringInfoString(jsonBody, "\"columnInfos\"");
	appendStringInfoChar(jsonBody, ':');
	dct_jsonifyColumnInfo(jsonBody, columnInfos, numColumn);

	appendStringInfoChar(jsonBody, '}');
}
