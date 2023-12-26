/*-------------------------------------------------------------------------
 *
 * dct_mysql.h
 *		  Private processing for MySQL
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_mysql/dct_mysql.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef DCT_MYSQL_H
#define DCT_MYSQL_H

#include "postgres.h"
#include "pgspider_fdw.h"
#include "dct_common.h"

extern bool is_mysql_unique_option(const char *option_name);
extern void mysql_PrepareDDLRequestData(StringInfo jsonBody,
										int mode,
										Relation rel,
										DDLData ddlData,
										DataCompressionTransferOption * dct_option);
extern void mysql_PrepareInsertRequestData(StringInfo jsonBody,
										   PGSpiderFdwModifyState *fmstate,
										   ColumnInfo *columnInfos,
										   int numColumn,
										   char *socket_host,
										   int socket_port,
										   DataCompressionTransferOption * dct_option);
#endif	/* DCT_MYSQL_H */
