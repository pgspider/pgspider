/*-------------------------------------------------------------------------
 *
 * dct_postgres.h
 *		  Private processing for Postgres
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_postgres/dct_postgres.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef DCT_POSTGRES_H
#define DCT_POSTGRES_H

#include "postgres.h"
#include "pgspider_fdw.h"
#include "dct_common.h"

extern bool is_postgres_unique_option(const char *option_name);
extern void postgres_PrepareDDLRequestData(StringInfo jsonBody,
										   int mode,
										   Relation rel,
										   DDLData ddlData,
										   DataCompressionTransferOption * dct_option);
extern void postgres_PrepareInsertRequestData(StringInfo jsonBody,
											  PGSpiderFdwModifyState *fmstate,
											  ColumnInfo *columnInfos,
											  int numColumn,
											  char *socket_host,
											  int socket_port,
											  DataCompressionTransferOption * dct_option);
#endif	/* DCT_POSTGRES_H */
