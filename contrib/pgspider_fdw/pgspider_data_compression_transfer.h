/*-------------------------------------------------------------------------
 *
 * pgspider_data_compression_transfer.h
 *		  Foreign-data wrapper for remote PGSpider servers
 *
 * Portions Copyright (c) 2012-2021, PostgreSQL Global Development Group
 * Portions Copyright (c) 2018, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/pgspider_data_compression_transfer.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef PGSPIDER_DATA_COMPRESSION_TRANSFER_H
#define PGSPIDER_DATA_COMPRESSION_TRANSFER_H

#include <curl/curl.h>

#include "pgspider_fdw.h"


#define FUNCTION_SUCCESS 					"SUCCESS"
#define PGSPIDER_FDW_NAME 					"pgspider_fdw"
#define POSTGRES_FDW_NAME 					"postgres_fdw"
#define MYSQL_FDW_NAME 						"mysql_fdw"
#define GRIDDB_FDW_NAME 					"griddb_fdw"
#define ORACLE_FDW_NAME 					"oracle_fdw"
#define INFLUXDB_FDW_NAME 					"influxdb_fdw"
#define PGFDW_HEADER_FORMAT_JSON 			"Content-Type:application/json"
#define PGFDW_HEADER_KEY_CONTENT_LENGTH 	"Content-Length"
#define PGFDW_HTTP_POST_METHOD 				"POST"
#define PGFDW_MAX_CURL_BODY_LENGTH 			2147483648	/* 2GB */
#define CURL_TIMEOUT_GCP		 			3600	/* max timeout for
													 * function of GCP */
#define REST_OK 							0
#define PGREST_HTTP_RES_STATUS_OK 			200
#define BOOL_SIZE							1
#define CHAR_SIZE							1
#define SHORT_SIZE							2
#define INT_SIZE							4
#define FLOAT_SIZE							4
#define LONG_SIZE							8
#define DOUBLE_SIZE							8
#define DATA_TYPE_SIZE						2
#define TIMESTAMP_SIZE						8
#define COMP_DECOMP_LENGTH					8

/*
 * If system call is interrupted, retry system call
 * Otherwise, exit
 */
#define PGSFDW_CHECK_SYSTEMCALL_ERROR(ret, err_mesg, fail_mesg) \
	if (ret == -1) \
	{ \
		if (errno == EINTR) \
			break; \
		err_mesg = psprintf("%s: %s", fail_mesg, pstrdup(strerror(errno))); \
		return false; \
	}

/*
 * Handle timeout error for system call select()
 */
#define PGSFDW_CHECK_SYSTEMCALL_SELECT_ERROR(ret, err_mesg, timeout) \
	if (ret == -1) \
	{ \
		if (errno == EINTR) \
			continue; \
		err_mesg = psprintf("Fail to select(): %s", pstrdup(strerror(errno))); \
		return false; \
	} \
	else if (ret == 0) \
	{ \
		err_mesg = psprintf("Timeout expired: %d. The timeout period elapsed prior to completion of the operation or the Cloud Function is not responding.", timeout); \
		return false; \
	}

#define PGSFDW_CHECK_READ_SEND_RESULT(ret, dest) \
	if (!ret) \
		goto dest;
/*
 * This enum represents the common data type mapping between PGSpider and JDBC.
 */
typedef enum TransferDataType
{
	BOOL_ARRAY_TYPE,
	BYTEA_ARRAY_TYPE,
	CHAR_ARRAY_TYPE,
	BPCHAR_ARRAY_TYPE,
	INT8_ARRAY_TYPE,
	INT4_ARRAY_TYPE,
	INT2_ARRAY_TYPE,
	TEXT_ARRAY_TYPE,
	FLOAT4_ARRAY_TYPE,
	FLOAT8_ARRAY_TYPE,
	VARCHAR_ARRAY_TYPE,
	NUMERIC_ARRAY_TYPE,
	DATE_ARRAY_TYPE,
	TIME_ARRAY_TYPE,
	TIMETZ_ARRAY_TYPE,
	TIMESTAMP_ARRAY_TYPE,
	TIMESTAMPTZ_ARRAY_TYPE,
	BIGINT_TYPE,
	TEXT_TYPE,
	BIT_TYPE,
	BYTEA_TYPE,
	BOOLEAN_TYPE,
	DATE_TYPE,
	DOUBLE_PRECISION_TYPE,
	FLOAT_TYPE,
	INTEGER_TYPE,
	CHAR_TYPE,
	NUMERIC_TYPE,
	VARCHAR_TYPE,
	BPCHAR_TYPE,
	SMALLINT_TYPE,
	TIME_TYPE,
	TIME_WITH_TIMEZONE_TYPE,
	TIMESTAMP_TYPE,
	TIMESTAMP_WITH_TIMEZONE_TYPE
}			TransferDataType;

/*
 * This enum represents the database of data source.
 */
typedef enum TargetDB
{
	POSTGRESDB,
	PGSPIDERDB,
	MYSQLDB,
	GRIDDB,
	INFLUXDB,
	ORACLEDB
}			TargetDB;

/*
 * This enum represents state send/read data of client socket.
 */
typedef enum ClientRDWRState
{
	STATE_SEND_COMPRESS_LENGTH,
	STATE_SEND_COMPRESS_DATA,
	STATE_READ_MESSAGE_LENGTH,
	STATE_READ_MESSAGE_DATA,
	STATE_EXIT,
}			ClientRDWRState;

/*
 * This enum represents the execution mode to be executed.
 */
typedef enum PGSpiderExecuteMode
{
	DDL_CREATE,
	DDL_DROP,
	BATCH_INSERT
}			PGSpiderExecuteMode;

/*
 * header_entry: a pair of header key and its value
 */
typedef struct header_entry
{
	char	   *key;
	char	   *value;
}			header_entry;

/*
 * Response body data structure
 */
typedef struct body_res
{
	char	   *data;
	size_t		size;
}			body_res;

/*
 * Struct for data to be transferred using compression.
 */
typedef struct TransferValue
{
	Datum		value;			/* datum value that is to be transferred */
	bool		isNull;			/* true if the transferred value is NULL */
}			TransferValue;

/*
 * Struct for information used to authenticate on the remote data source.
 */
typedef struct AuthenticationData
{
	char	   *user;			/* username used to authenticate at the cloud
								 * data source */
	char	   *pwd;			/* password used to authenticate at the cloud
								 * data source */
	char	   *token;			/* token used to authenticate at the InfluxDB
								 * data source */
}			AuthenticationData;

/*
 * Struct for information required to create connection URL to remote data source.
 */
typedef struct ConnectionURLData
{
	TargetDB	targetDB;		/* kind of database on the data source */
	char	   *host;			/* host address of the data source */
	int			port;			/* port address of the data source */
	char	   *clusterName;	/* cluster name, in case of GridDB */
	char	   *dbName;			/* database name */
	char	   *org;			/* organization name of data store of InfluxDB */
}			ConnectionURLData;

/*
 * Struct for Column information of the target table.
 */
typedef struct ColumnInfo
{
	char	   *columnName;		/* column name on the foreign table */
	bool		notNull;		/* true if 'NOT NULL' is specified on the
								 * column */
	TransferDataType columnType;	/* data type of the column */
	int			typemod;		/* type modifier in case of varchar(n),
								 * char(n), etc */
	bool		isTagKey;		/* true if column is tag key,
								 * specify for InfluxDB server */
}			ColumnInfo;


/*
 * Struct for DDL information required to execute a DDL query.
 */
typedef struct DDLData
{
	char	   *tableName;		/* table name that is to be created */
	int			numColumn;		/* number of columns of the table */
	ColumnInfo *columnInfos;	/* list of column information */
	bool		existFlag;		/* true if 'IF EXISTS' flag is used in
								 * creating data source table */
}			DDLData;

/*
 * Struct for Insertion data information required to execute a INSERT query
 */
typedef struct InsertData
{
	char	   *tableName;		/* table name that is to be created */
	TransferValue *values;		/* values of data to be inserted */
	int			numSlot;		/* number of slots to be inserted */
	ColumnInfo *columnInfos;	/* list of column information */
	int			numColumn;		/* number of columns of the table */
}			InsertData;

/*
 * Socket information used while transferring compressed data.
 */
typedef struct SocketInfo
{
	SocketThreadInfo *socketThreadInfo; /* shared socket thread info */
	char	   *compressedData; /* compressed insert data */
	char	   *sizeInfos;		/* size of compressed and uncompressed insert
								 * data */
	int			compressedlength;	/* length of compressed insert data */
	int 		function_timeout;	/* timeout to read/write data */

	MemoryContext send_insert_data_ctx;

	char	   *result;			/* the result received from the Function */
}			SocketInfo;

/*
 * Option information for Data Compression Transfer Feauture
 */
typedef struct DataCompressionTransferOption
{
	char	   *endpoint;		/* specifies the endpoint of Function */
	char	   *proxy;			/* proxy for cURL request */
	char	   *table_name;		/* specifies the table name of target server */
	int			serverID;		/* indicates server ID of target server */
	int			userID;			/* indicates user ID of target server */
	int			function_timeout;	/* timeout to rest API request */
	char	   *org;				/* organization name of data store of InfluxDB*/
	List	   *tagsList;		/* Contain tag keys of a foreign table,
								 * specify for InfluxDB server */
}			DataCompressionTransferOption;


extern void	PGSpiderRequestFunctionStart(PGSpiderExecuteMode mode,
										 DataCompressionTransferOption * dct_option,
										 PGSpiderFdwModifyState * fmstate,
										 AuthenticationData * authData,
										 ConnectionURLData * connData,
										 DDLData * ddlData);
extern void pgspiderPrepareAuthenticationData(AuthenticationData * authData, DataCompressionTransferOption *dct_option);
extern void pgspiderPrepareConnectionURLData(ConnectionURLData * connData, Relation rel, DataCompressionTransferOption *dct_option);
extern void pgspiderPrepareDDLData(DDLData * ddldata, Relation rel, bool existFlag, DataCompressionTransferOption *dct_option);
extern void get_data_compression_transfer_option(PGSpiderExecuteMode mode, Relation rel, DataCompressionTransferOption * dct_option);
extern void init_InsertData(InsertData * data);
extern void init_AuthenticationData(AuthenticationData * data);
extern void init_ConnectionURLData(ConnectionURLData * data);
extern void init_DDLData(DDLData * data);
extern void init_DataCompressionTransferOption(DataCompressionTransferOption * data);
extern char *pgspiderCompressData(PGSpiderFdwModifyState * fmstate, InsertData * insertData, char **sizeInfors, int *compressedlength);
extern void *send_insert_data_thread(void *arg);
extern bool check_data_compression_transfer_option(Relation rel);
extern ColumnInfo * create_column_info_array(Relation rel, List *target_attrs, List *tagsList);
extern TransferValue *create_values_array(PGSpiderFdwModifyState * fmstate, TupleTableSlot **slots, int numSlots);
#endif							/* PGSPIDER_DATA_COMPRESSION_TRANSFER_H */
