/*-------------------------------------------------------------------------
 *
 * dct_objstorage.h
 *		  Private processing for Object Storage
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_targetdb/dct_objstorage.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef DCT_OBJSTORAGE_H
#define DCT_OBJSTORAGE_H

#include "postgres.h"
#include "pgspider_fdw.h"
#include "dct_common.h"

extern bool is_objstorage_unique_option(const char *option_name);
extern void objstorage_PrepareDDLRequestData(StringInfo jsonBody,
											 int mode,
											 Relation rel,
											 DDLData ddlData,
											 DataCompressionTransferOption * dct_option);
extern void objstorage_PrepareInsertRequestData(StringInfo jsonBody,
												PGSpiderFdwModifyState *fmstate,
												ColumnInfo *columnInfos,
												int numColumn,
												char *socket_host,
												int socket_port,
												DataCompressionTransferOption * dct_option);
#endif	/* DCT_OBJSTORAGE_H */
