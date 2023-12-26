/*-------------------------------------------------------------------------
 *
 * dct_griddb.h
 *		  Private processing for GridDB
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_griddb/dct_griddb.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef DCT_GRIDDB_H
#define DCT_GRIDDB_H

#include "postgres.h"
#include "pgspider_fdw.h"
#include "dct_common.h"

extern bool is_griddb_unique_option(const char *option_name);
extern void griddb_PrepareDDLRequestData(StringInfo jsonBody,
										 int mode,
										 Relation rel,
										 DDLData ddlData,
										 DataCompressionTransferOption * dct_option);
extern void griddb_PrepareInsertRequestData(StringInfo jsonBody,
											PGSpiderFdwModifyState *fmstate,
											ColumnInfo *columnInfos,
											int numColumn,
											char *socket_host,
											int socket_port,
											DataCompressionTransferOption * dct_option);
#endif	/* DCT_GRIDDB_H */
