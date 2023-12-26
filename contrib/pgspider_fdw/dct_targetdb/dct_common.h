/*-------------------------------------------------------------------------
 *
 * dct_common.h
 *		  Common processing for data sources
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_common.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef COMMON_DEFINE_H
#define COMMON_DEFINE_H

#include "postgres.h"
#include "pgspider_fdw.h"
#include "pgspider_data_compression_transfer.h"
#include "dct_pgspider.h"
#include "dct_postgres.h"
#include "dct_mysql.h"
#include "dct_griddb.h"
#include "dct_oracle.h"
#include "dct_influxdb.h"
#include "dct_objstorage.h"

extern char *dct_escape_json_string(char *string);
extern void dct_stringInfoAppendStringValue(StringInfo strInfo, char *key, char *value, char comma);
extern void dct_jsonifyColumnInfo(StringInfo strInfo, ColumnInfo * colInfo, int len);

#endif	/* COMMON_DEFINE_H */
