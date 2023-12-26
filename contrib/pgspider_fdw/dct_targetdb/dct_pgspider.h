/*-------------------------------------------------------------------------
 *
 * dct_pgspider.h
 *		  Private processing for PGSpider
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_pgspider/dct_pgspider.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef DCT_PGSPIDER_H
#define DCT_PGSPIDER_H

#include "postgres.h"
#include "pgspider_fdw.h"
#include "dct_common.h"

extern bool is_pgspider_unique_option(const char *option_name);
extern void pgspider_PrepareDDLRequestData(StringInfo jsonBody,
										   int mode,
										   Relation rel,
										   DDLData ddlData,
										   DataCompressionTransferOption * dct_option);
extern void pgspider_PrepareInsertRequestData(StringInfo jsonBody,
											  PGSpiderFdwModifyState *fmstate,
											  ColumnInfo *columnInfos,
											  int numColumn,
											  char *socket_host,
											  int socket_port,
											  DataCompressionTransferOption * dct_option);
#endif	/* DCT_PGSPIDER_H */
