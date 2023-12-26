/*-------------------------------------------------------------------------
 *
 * dct_influxdb.h
 *		  Private processing for InfluxDB
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_influxdb/dct_influxdb.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef DCT_INFLUXDB_H
#define DCT_INFLUXDB_H

#include "postgres.h"
#include "pgspider_fdw.h"
#include "dct_common.h"

extern bool is_influxdb_unique_option(const char *option_name);
extern void influxdb_PrepareDDLRequestData(StringInfo jsonBody,
										   int mode,
										   Relation rel,
										   DDLData ddlData,
										   DataCompressionTransferOption * dct_option);
extern void influxdb_PrepareInsertRequestData(StringInfo jsonBody,
											  PGSpiderFdwModifyState *fmstate,
											  ColumnInfo *columnInfos,
											  int numColumn,
											  char *socket_host,
											  int socket_port,
											  DataCompressionTransferOption * dct_option);
#endif	/* DCT_INFLUXDB_H */
