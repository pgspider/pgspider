/*-------------------------------------------------------------------------
 *
 * dct_oracle.h
 *		  Private processing for Oracle
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_oracle/dct_oracle.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef DCT_ORACLE_H
#define DCT_ORACLE_H

#include "postgres.h"
#include "pgspider_fdw.h"
#include "dct_common.h"

extern bool is_oracle_unique_option(const char *option_name);
extern void oracle_PrepareDDLRequestData(StringInfo jsonBody,
										 int mode,
										 Relation rel,
										 DDLData ddlData,
										 DataCompressionTransferOption * dct_option);
extern void oracle_PrepareInsertRequestData(StringInfo jsonBody,
											PGSpiderFdwModifyState *fmstate,
											ColumnInfo *columnInfos,
											int numColumn,
											char *socket_host,
											int socket_port,
											DataCompressionTransferOption * dct_option);
#endif	/* DCT_ORACLE_H */
