/*-------------------------------------------------------------------------
 *
 * pgspider_data_compression_transfer.c
 *		  Foreign-data wrapper for remote PGSpider servers
 *
 * Portions Copyright (c) 2012-2021, PostgreSQL Global Development Group
 * Portions Copyright (c) 2018, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/pgspider_data_compression_transfer.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include <arpa/inet.h>
#include <limits.h>
#include <lz4.h>
#include <netdb.h>
#include <unistd.h>

#include "access/heapam.h"
#include "catalog/pg_type.h"
#include "commands/defrem.h"
#include "miscadmin.h"
#include "pgspider_data_compression_transfer.h"
#include "utils/builtins.h"
#include "utils/datetime.h"
#include "utils/lsyscache.h"
#include "utils/memutils.h"
#include "utils/syscache.h"
#include "utils/varlena.h"
#include "storage/latch.h"


/*
 * init_InsertData
 *		Initialize InsertData context
 */
void
init_InsertData(InsertData * data)
{
	data->tableName = NULL;
	data->values = NULL;
	data->columnInfos = NULL;
	data->numSlot = 0;
	data->numColumn = 0;
}

/*
 * init_AuthenticationData
 *		Initialize AuthenticationData context
 */
void
init_AuthenticationData(AuthenticationData * data)
{
	data->user = NULL;
	data->pwd = NULL;
	data->token = NULL;
}

/*
 * init_ConnectionURLData
 * 		Initialize ConnectionURLData context
 */
void
init_ConnectionURLData(ConnectionURLData * data)
{
	data->targetDB = -1;
	data->host = NULL;
	data->port = 0;
	data->clusterName = NULL;
	data->dbName = NULL;
	data->org = NULL;
}

/*
 * init_DDLData
 * 		Initialize DDLData context
 */
void
init_DDLData(DDLData * data)
{
	data->tableName = NULL;
	data->columnInfos = NULL;
	data->numColumn = 0;
	data->existFlag = false;
}

/*
 * init_DataCompressionTransferOption
 * 		Initialize DataCompressionTransferOption context
 */
void
init_DataCompressionTransferOption(DataCompressionTransferOption * data)
{
	data->endpoint = NULL;
	data->proxy = NULL;
	data->table_name = NULL;
	data->serverID = 0;
	data->userID = 0;
	data->function_timeout = 0;
	data->org = NULL;
	data->tagsList = NULL;
}

/*
 * pgspiderGetExternalIp
 * 		Get public ip of host machine
 */
static char *
pgspiderGetExternalIp(void)
{
	char		hostbuffer[HOST_NAME_MAX];
	char	   *hostIP;
	struct hostent *host_entry;
	int			hostname;

	/* Get host name */
	hostname = gethostname(hostbuffer, sizeof(hostbuffer));
	if (hostname == -1)
		elog(ERROR, "Failed to get host name");

	/* Get host information */
	host_entry = gethostbyname(hostbuffer);
	if (host_entry == NULL)
		elog(ERROR, "Failed to get host information");

	/* Convert Internet network address into ASCII string */
	hostIP = inet_ntoa(*((struct in_addr *)
						 host_entry->h_addr_list[0]));

	return pstrdup(hostIP);
}

/*
 * pgspiderMappingArrayElementType
 *		Mapping array element type
 */
static TransferDataType
pgspiderMappingArrayElementType(TransferDataType arrayType)
{
	switch (arrayType)
	{
		case BOOL_ARRAY_TYPE:
			return BOOLEAN_TYPE;
		case CHAR_ARRAY_TYPE:
			return CHAR_TYPE;
		case INT8_ARRAY_TYPE:
			return BIGINT_TYPE;
		case FLOAT8_ARRAY_TYPE:
			return DOUBLE_PRECISION_TYPE;
		case INT4_ARRAY_TYPE:
			return INTEGER_TYPE;
		case FLOAT4_ARRAY_TYPE:
			return FLOAT_TYPE;
		case INT2_ARRAY_TYPE:
			return SMALLINT_TYPE;
		default:
			/* Should not go here */
			elog(ERROR, "Unsupported array type %d", arrayType);
	}
}

/*
 * pgspiderDeconstructArrayDatumToSize
 *		Deconstruct an array to datum array of element values and elements
 */
static void
pgspiderDeconstructArrayDatumToSize(Datum arrayDatum, List **valueList, int *totalSize)
{
	ArrayType  *array;
	Oid			elmtype;
	int16		elmlen;
	bool		elmbyval;
	char		elmalign;
	int			i;
	int			size = 0;
	Datum	   *elem_values;
	bool	   *elem_nulls;
	int			num_elem;

	array = DatumGetArrayTypeP(arrayDatum);
	elmtype = ARR_ELEMTYPE(array);

	get_typlenbyvalalign(elmtype, &elmlen, &elmbyval, &elmalign);
	deconstruct_array(array, elmtype, elmlen, elmbyval, elmalign, &elem_values, &elem_nulls, &num_elem);

	/* store numElement to list. */
	*valueList = lappend(*valueList, makeInteger(num_elem));
	/* store element_values and element_nulls to list. */
	*valueList = lappend(*valueList, elem_nulls);
	*valueList = lappend(*valueList, elem_values);

	/* size to store number of element in the array. */
	size += INT_SIZE;

	for (i = 0; i < num_elem; i++)
	{
		/* store isNull property. */
		size += 1;
		/* if the element is not null, store the element. */
		if (!elem_nulls[i])
			size += elmlen;
	}

	*totalSize += size;
}

/*
 * pgspiderSerializeValue
 *		Serialize value of transfer data to a char array.
 */
static void
pgspiderSerializeValue(List *valueList, int *listIndex, Datum value, TransferDataType columnType,
					   char **nextIndex, PGSpiderFdwModifyState * fmstate, int columnIndex)
{
	int			copiedSize;
	int			idx;
	int			len;
	bool	   *elem_nulls;
	Datum	   *elem_values;
	char	   *dat;
	char	   *result;

	switch (columnType)
	{
			/*
			 * Current implementation only supports 1-dimension array.
			 */
		case BOOL_ARRAY_TYPE:
		case CHAR_ARRAY_TYPE:
		case INT8_ARRAY_TYPE:
		case FLOAT8_ARRAY_TYPE:
		case INT4_ARRAY_TYPE:
		case FLOAT4_ARRAY_TYPE:
		case INT2_ARRAY_TYPE:
			{
				len = intVal(list_nth(valueList, *listIndex));
				(*listIndex)++;
				elem_nulls = (bool *) list_nth(valueList, *listIndex);
				(*listIndex)++;
				elem_values = (Datum *) list_nth(valueList, *listIndex);
				(*listIndex)++;

				memcpy(*nextIndex, &len, INT_SIZE);
				(*nextIndex) += INT_SIZE;

				for (idx = 0; idx < len; idx++)
				{
					**nextIndex = elem_nulls[idx];
					(*nextIndex) += BOOL_SIZE;
					if (!elem_nulls[idx])
						pgspiderSerializeValue(valueList, listIndex, elem_values[idx],
											   pgspiderMappingArrayElementType(columnType),
											   nextIndex, fmstate, columnIndex);
				}
				break;
			}
		case BPCHAR_ARRAY_TYPE:
		case TEXT_ARRAY_TYPE:
		case VARCHAR_ARRAY_TYPE:
		case NUMERIC_ARRAY_TYPE:
		case DATE_ARRAY_TYPE:
		case TIME_ARRAY_TYPE:
		case TIMETZ_ARRAY_TYPE:
		case TIMESTAMP_ARRAY_TYPE:
		case TIMESTAMPTZ_ARRAY_TYPE:
			{
				len = intVal(list_nth(valueList, *listIndex));
				(*listIndex)++;
				elem_nulls = (bool *) list_nth(valueList, *listIndex);
				(*listIndex)++;

				memcpy(*nextIndex, &len, INT_SIZE);
				(*nextIndex) += INT_SIZE;

				for (idx = 0; idx < len; idx++)
				{
					memcpy(*nextIndex, &elem_nulls[idx], BOOL_SIZE);
					**nextIndex = elem_nulls[idx];
					(*nextIndex) += BOOL_SIZE;
					if (!elem_nulls[idx])
					{
						char	   *strValue = strVal(list_nth(valueList, *listIndex));

						(*listIndex)++;
						copiedSize = strlen(strValue) + 1;
						memcpy(*nextIndex, strValue, copiedSize - 1);
						(*nextIndex) += copiedSize;
					}
				}
				break;
			}
			/* 1 byte */
		case BOOLEAN_TYPE:
		case CHAR_TYPE:
			{
				unsigned char ch = (unsigned char) DatumGetChar(value);

				memcpy(*nextIndex, &ch, CHAR_SIZE);
				(*nextIndex) += CHAR_SIZE;
				break;
			}
			/* 2 bytes */
		case SMALLINT_TYPE:
			{
				int16		shortValue = DatumGetInt16(value);

				copiedSize = sizeof(int16);
				memcpy(*nextIndex, &shortValue, copiedSize);
				(*nextIndex) += copiedSize;
				break;
			}
			/* 4 bytes */
		case INTEGER_TYPE:
			{
				int32		intValue = DatumGetInt32(value);

				copiedSize = sizeof(int32);
				memcpy(*nextIndex, &intValue, copiedSize);
				(*nextIndex) += copiedSize;
				break;
			}
			/* 4 bytes */
		case FLOAT_TYPE:
			{
				float4		floatValue = DatumGetFloat4(value);

				copiedSize = sizeof(float4);
				memcpy(*nextIndex, &floatValue, copiedSize);
				(*nextIndex) += copiedSize;
				break;
			}
			/* 8 bytes */
		case BIGINT_TYPE:
			{
				int64		int8Value = DatumGetInt64(value);

				copiedSize = sizeof(int64);
				memcpy(*nextIndex, &int8Value, copiedSize);
				(*nextIndex) += copiedSize;
				break;
			}
			/* 8 bytes */
		case DOUBLE_PRECISION_TYPE:
			{
				float8		float8Value = DatumGetFloat8(value);

				copiedSize = sizeof(float8);
				memcpy(*nextIndex, &float8Value, copiedSize);
				(*nextIndex) += copiedSize;
				break;
			}
		case BYTEA_TYPE:
			{
				result = DatumGetPointer(value);

				if (VARATT_IS_1B(result))
				{
					len = VARSIZE_1B(result) - VARHDRSZ_SHORT;
					dat = VARDATA_1B(result);
				}
				else
				{
					len = VARSIZE_4B(result) - VARHDRSZ;;
					dat = VARDATA_4B(result);
				}

				copiedSize = sizeof(len);
				memcpy(*nextIndex, &len, copiedSize);
				(*nextIndex) += copiedSize;
				memcpy(*nextIndex, (char *) dat, len);
				(*nextIndex) += len;
				break;
			}
			/* varied bytes */
		case TEXT_TYPE:
		case BIT_TYPE:
		case DATE_TYPE:
		case NUMERIC_TYPE:
		case VARCHAR_TYPE:
		case BPCHAR_TYPE:
		case TIME_TYPE:
		case TIME_WITH_TIMEZONE_TYPE:
			{
				char	   *strValue = OutputFunctionCall(&fmstate->p_flinfo[columnIndex], value);

				copiedSize = strlen(strValue) + 1;
				memcpy(*nextIndex, strValue, copiedSize - 1);
				(*nextIndex) += copiedSize;
				break;
			}
		case TIMESTAMP_TYPE:
		case TIMESTAMP_WITH_TIMEZONE_TYPE:
			{
				Timestamp	valueTimestamp = DatumGetTimestamp(value);
				int64		valueMicroSecs = valueTimestamp + (POSTGRES_EPOCH_JDATE - UNIX_EPOCH_JDATE) * USECS_PER_DAY;

				copiedSize = sizeof(int64);
				memcpy(*nextIndex, &valueMicroSecs, copiedSize);
				(*nextIndex) += copiedSize;
				break;
			}
		default:
			elog(ERROR, "Unsupported datatype %d.", (int) columnType);
	}
}

/*
 * pgspiderCalculateInsertDataSize
 *		Calculate total size needed to serialize an InsertData struct.
 *
 * We only add datum values (after deconstruction) of array types to valueList
 * because we need the length of the array and its element right now in order
 * to allocate a suitable size, and we do not want to deconstruct_array again.
 *
 * For other datatypes, we just add the required size. Their
 * `datum to typed data` conversions will be done during serialization.
 */
static int
pgspiderCalculateInsertDataSize(PGSpiderFdwModifyState * fmstate, InsertData * insertData, List **valueList)
{
	ArrayType  *array;
	Datum	   *elem_values;
	bool	   *elem_nulls;
	Oid			elmtype;
	int16		elmlen;
	bool		elmbyval;
	char		elmalign;
	int			num_elem,
				idx;
	int			size = 0;
	int			i;
	int			len;

	/*
	 * Add size to store tableName, added by 1 to store '\0' which indicates
	 * the end of the string.
	 */
	size += strlen(insertData->tableName) + 1;

	/* Number of columns must be positive. */
	Assert(insertData->numColumn > 0);

	/* Add size to store the value of numColumn and numSlot. */
	size += sizeof(insertData->numColumn) + sizeof(insertData->numSlot);

	/* Add size to store the array of columnInfos. */
	for (i = 0; i < insertData->numColumn; i++)
	{
		/* size to store column name. */
		size += strlen(insertData->columnInfos[i].columnName) + 1;
		/* size to store notNull indicator. */
		size += BOOL_SIZE;
		/* size to store column type. */
		size += DATA_TYPE_SIZE;

		/*
		 * size to store typmode of BIT type. This is required for JDBC to
		 * cast to binary of `n` bits.
		 */
		if (insertData->columnInfos[i].columnType == BIT_TYPE)
			size += SHORT_SIZE;

		/* size to store isTagKey. */
		size += BOOL_SIZE;
	}

	/* Add size to store the array of values. */
	for (i = 0; i < insertData->numSlot * insertData->numColumn; i++)
	{
		/* size to store isNull value */
		size += sizeof(bool);

		/* size to store the value itself if the value is not NULL */
		if (!insertData->values[i].isNull)
		{
			int			columnIndex = i % insertData->numColumn;

			switch (insertData->columnInfos[columnIndex].columnType)
			{
				case BOOL_ARRAY_TYPE:
				case CHAR_ARRAY_TYPE:
				case FLOAT8_ARRAY_TYPE:
				case FLOAT4_ARRAY_TYPE:
				case INT8_ARRAY_TYPE:
				case INT4_ARRAY_TYPE:
				case INT2_ARRAY_TYPE:
					pgspiderDeconstructArrayDatumToSize(insertData->values[i].value, valueList, &size);
					break;
					/* array of string */
				case BPCHAR_ARRAY_TYPE:
				case TEXT_ARRAY_TYPE:
				case VARCHAR_ARRAY_TYPE:
				case NUMERIC_ARRAY_TYPE:
				case DATE_ARRAY_TYPE:
				case TIME_ARRAY_TYPE:
				case TIMETZ_ARRAY_TYPE:
				case TIMESTAMP_ARRAY_TYPE:
				case TIMESTAMPTZ_ARRAY_TYPE:
					{
						array = DatumGetArrayTypeP(insertData->values[i].value);
						elmtype = ARR_ELEMTYPE(array);

						get_typlenbyvalalign(elmtype, &elmlen, &elmbyval, &elmalign);
						deconstruct_array(array, elmtype, elmlen, elmbyval, elmalign, &elem_values, &elem_nulls, &num_elem);
						/* save num to list */
						*valueList = lappend(*valueList, makeInteger(num_elem));
						size += INT_SIZE;
						/* save element_nulls to list */
						*valueList = lappend(*valueList, elem_nulls);

						for (idx = 0; idx < num_elem; idx++)
						{
							size += BOOL_SIZE;
							if (!elem_nulls[idx])
							{
								Oid			outputFunctionId;
								bool		typeVarLength;

								/*
								 * add size to store the element if it is not
								 * NULL
								 */
								char	   *stringValue;

								getTypeOutputInfo(elmtype, &outputFunctionId,
												  &typeVarLength);
								stringValue = OidOutputFunctionCall(outputFunctionId,
																	elem_values[idx]);

								*valueList = lappend(*valueList, makeString(stringValue));
								/* add the size. */
								size += strlen(stringValue) + 1;
							}
						}
					}
					break;
					/* 1 byte */
				case BOOLEAN_TYPE:
					size += BOOL_SIZE;
					break;
				case CHAR_TYPE:
					size += CHAR_SIZE;
					break;
					/* 2 bytes */
				case SMALLINT_TYPE:
					size += SHORT_SIZE;
					break;
					/* 4 bytes */
				case INTEGER_TYPE:
					size += INT_SIZE;
					break;
				case FLOAT_TYPE:
					size += FLOAT_SIZE;
					break;
					/* 8 bytes */
				case BIGINT_TYPE:
					size += LONG_SIZE;
					break;
				case DOUBLE_PRECISION_TYPE:
					size += DOUBLE_SIZE;
					break;
				case TIMESTAMP_WITH_TIMEZONE_TYPE:
				case TIMESTAMP_TYPE:
					size += TIMESTAMP_SIZE;
					break;
				case BYTEA_TYPE:
					{
						char	   *result = DatumGetPointer(insertData->values[i].value);

						/* size to store value length. */
						size += INT_SIZE;

						if (VARATT_IS_1B(result))
							len = VARSIZE_1B(result) - VARHDRSZ_SHORT;
						else
							len = VARSIZE_4B(result) - VARHDRSZ;

						size += len;
					}
					break;
					/* varied bytes */
				case TEXT_TYPE:
				case BIT_TYPE:
				case DATE_TYPE:
				case NUMERIC_TYPE:
				case VARCHAR_TYPE:
				case BPCHAR_TYPE:
				case TIME_TYPE:
				case TIME_WITH_TIMEZONE_TYPE:
					{
						char	   *strValue = OutputFunctionCall(&fmstate->p_flinfo[columnIndex], insertData->values[i].value);

						size += strlen(strValue) + 1;
					}
					break;
				default:
					elog(ERROR, "Unsupported datatype %d for column %s.", (int) insertData->columnInfos[columnIndex].columnType,
						 insertData->columnInfos[columnIndex].columnName);
			}
		}
	}
	return size;
}

/*
 * pgspiderSerializeData
 *		Serialize an InsertData struct to a char array.
 */
static char *
pgspiderSerializeData(PGSpiderFdwModifyState * fmstate, InsertData * insertData, int *serializedSize)
{
	int			copiedSize;
	char	   *serializedBytes,
			   *nextIndex;
	int			i;
	List	   *valueList = NIL;
	int			listIndex = 0;

	/* Calculate size of InsertData significant for serialization. */
	*serializedSize = pgspiderCalculateInsertDataSize(fmstate, insertData, &valueList);
	serializedBytes = palloc0(*serializedSize * sizeof(char));
	if (serializedBytes == NULL)
		elog(ERROR, "pgspider_fdw: Allocation of serialized data failed.");

	/*
	 * Initialize `nextIndex` to be the first position of serializedBytes.
	 * This will be increased to the next position that is available to copy.
	 */
	nextIndex = serializedBytes;

	copiedSize = strlen(insertData->tableName) + 1;
	memcpy(nextIndex, insertData->tableName, copiedSize - 1);
	nextIndex += copiedSize;

	copiedSize = sizeof(insertData->numColumn);
	memcpy(nextIndex, &insertData->numColumn, copiedSize);
	nextIndex += copiedSize;

	copiedSize = sizeof(insertData->numSlot);
	memcpy(nextIndex, &insertData->numSlot, copiedSize);
	nextIndex += copiedSize;

	/* Serialize columnInfos */
	for (i = 0; i < insertData->numColumn; i++)
	{
		ColumnInfo	col = insertData->columnInfos[i];

		copiedSize = strlen(col.columnName) + 1;
		memcpy(nextIndex, col.columnName, copiedSize - 1);
		nextIndex += copiedSize;
		*nextIndex = col.notNull;
		nextIndex += BOOL_SIZE;
		memcpy(nextIndex, &col.columnType, DATA_TYPE_SIZE);
		nextIndex += DATA_TYPE_SIZE;

		*nextIndex = col.isTagKey;
		nextIndex += BOOL_SIZE;

		if (col.columnType == BIT_TYPE)
		{
			/* Only support 1 modifier, so only need 2 bytes */
			memcpy(nextIndex, &col.typemod, SHORT_SIZE);
			nextIndex += SHORT_SIZE;
		}
	}

	/* Serialize transfer value */
	for (i = 0; i < insertData->numSlot * insertData->numColumn; i++)
	{
		/* Serialize the boolean value of isNull */
		copiedSize = sizeof(bool);
		memcpy(nextIndex, &insertData->values[i].isNull, copiedSize);
		nextIndex += copiedSize;
		if (!insertData->values[i].isNull)
		{
			int			columnIndex = i % insertData->numColumn;

			pgspiderSerializeValue(valueList, &listIndex, insertData->values[i].value,
								   insertData->columnInfos[columnIndex].columnType,
								   &nextIndex, fmstate, columnIndex);
		}
	}

	return serializedBytes;
}

/*
 * pgspider_get_modifier
 *		Add typmod decoration to the basic type name
 *		Support only for BITOID(n), VARCHAROID(n), BPCHAROID(n) type.
 */
static int
pgspider_get_modifier(Oid type_oid, int32 typmod, Oid typmodout)
{
	bits16		flags;
	bool		with_typemod;

	flags = FORMAT_TYPE_TYPEMOD_GIVEN;

	if (!pgspider_is_builtin(type_oid, InvalidOid))
		flags |= FORMAT_TYPE_FORCE_QUALIFY;
	with_typemod = (flags & FORMAT_TYPE_TYPEMOD_GIVEN) != 0 && (typmod >= 0);

	if (!with_typemod)
		return -1;

	/* Shouldn't be called if typmod is -1 */
	Assert(typmod >= 0);

	if (typmodout == InvalidOid)
	{
		return (int) typmod;
	}
	else
	{
		/* Use the type-specific typmodout procedure */
		char	   *tmstr;

		tmstr = DatumGetCString(OidFunctionCall1(typmodout,
												 Int32GetDatum(typmod)));
		/* exclude '(' and ')' at the begin and the end of tmstr, e.g. (10) */
		tmstr[strlen(tmstr) - 1] = 0;
		return (int) atoi(tmstr + 1);
	}
}

/*
 * transfer_data_type_mapping
 *		Data type mapping for Data Compression Transfer Feature
 */
static TransferDataType
transfer_data_type_mapping(Oid typ, int32 typmod, Oid typmodout, int *typmodoutInt)
{
	switch (typ)
	{
		case BOOLARRAYOID:
			return BOOL_ARRAY_TYPE;
		case CHARARRAYOID:
			return CHAR_ARRAY_TYPE;
		case BPCHARARRAYOID:
			return BPCHAR_ARRAY_TYPE;
		case INT8ARRAYOID:
			return INT8_ARRAY_TYPE;
		case INT4ARRAYOID:
			return INT4_ARRAY_TYPE;
		case INT2ARRAYOID:
			return INT2_ARRAY_TYPE;
		case TEXTARRAYOID:
			return TEXT_ARRAY_TYPE;
		case FLOAT4ARRAYOID:
			return FLOAT4_ARRAY_TYPE;
		case FLOAT8ARRAYOID:
			return FLOAT8_ARRAY_TYPE;
		case VARCHARARRAYOID:
			return VARCHAR_ARRAY_TYPE;
		case NUMERICARRAYOID:
			return NUMERIC_ARRAY_TYPE;
		case DATEARRAYOID:
			return DATE_ARRAY_TYPE;
		case TIMEARRAYOID:
			return TIME_ARRAY_TYPE;
		case TIMETZARRAYOID:
			return TIMETZ_ARRAY_TYPE;
		case TIMESTAMPARRAYOID:
			return TIMESTAMP_ARRAY_TYPE;
		case TIMESTAMPTZARRAYOID:
			return TIMESTAMPTZ_ARRAY_TYPE;
		case INT8OID:
			return BIGINT_TYPE;
		case TEXTOID:
			return TEXT_TYPE;
		case BITOID:
			*typmodoutInt = pgspider_get_modifier(typ, typmod, typmodout);
			return BIT_TYPE;
		case BYTEAOID:
			return BYTEA_TYPE;
		case BOOLOID:
			return BOOLEAN_TYPE;
		case CHAROID:
			return CHAR_TYPE;
		case DATEOID:
			return DATE_TYPE;
		case NUMERICOID:
			return NUMERIC_TYPE;
		case FLOAT8OID:
			return DOUBLE_PRECISION_TYPE;
		case FLOAT4OID:
			return FLOAT_TYPE;
		case INT4OID:
			return INTEGER_TYPE;
		case VARCHAROID:
			*typmodoutInt = pgspider_get_modifier(typ, typmod, typmodout);
			return VARCHAR_TYPE;
		case BPCHAROID:
			*typmodoutInt = pgspider_get_modifier(typ, typmod, typmodout);
			return BPCHAR_TYPE;
		case INT2OID:
			return SMALLINT_TYPE;
		case TIMEOID:
			return TIME_TYPE;
		case TIMETZOID:
			return TIME_WITH_TIMEZONE_TYPE;
		case TIMESTAMPOID:
			return TIMESTAMP_TYPE;
		case TIMESTAMPTZOID:
			return TIMESTAMP_WITH_TIMEZONE_TYPE;
		default:
			elog(ERROR, "Unsupported datatype");
	}
}

/*
 * Parse a comma-separated string and return a list of tag keys of a foreign table.
 * Specify for only InfluxDB server.
 */
static List *
pgspider_extract_tags_list(char *in_string)
{
	List	   *tags_list = NIL;

	/* SplitIdentifierString scribbles on its input, so pstrdup first */
	if (!SplitIdentifierString(pstrdup(in_string), ',', &tags_list))
	{
		/* Syntax error in tags list */
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("parameter \"%s\" must be a list of tag keys",
						"tags")));
	}

	return tags_list;
}

/*
 * This function check whether column is tag key or not.
 * Return true if it is tag, otherwise return false.
 * Specify for InfluxDB server.
 */
static bool
pgspider_is_tag_key(const char *colname, List *tagsList)
{
	ListCell   *lc;

	/* If there is no tag in tagsList, it means column is field */
	if (list_length(tagsList) == 0)
		return false;

	/* Check whether column is tag or not */
	foreach(lc, tagsList)
	{
		char	   *name = (char *) lfirst(lc);

		if (strcmp(colname, name) == 0)
			return true;
	}

	return false;
}

/*
 * create_column_info_array
 *		Create array of columns for Data Compression Transfer Feature
 */
ColumnInfo *
create_column_info_array(Relation rel, List *target_attrs, List *tagsList)
{
	ColumnInfo *columnInfos;
	ListCell   *lc;
	TupleDesc	tupdesc = RelationGetDescr(rel);
	int			i = 0;
	HeapTuple	tuple;
	Form_pg_type typeform;

	columnInfos = (ColumnInfo *) palloc0(sizeof(ColumnInfo) * list_length(target_attrs));

	foreach(lc, target_attrs)
	{
		int			attnum = lfirst_int(lc);
		Form_pg_attribute attr = TupleDescAttr(tupdesc, attnum - 1);
		int			typemodout = 0;
		TransferDataType typ;

		tuple = SearchSysCache1(TYPEOID, ObjectIdGetDatum(attr->atttypid));
		if (!HeapTupleIsValid(tuple))
			elog(ERROR, "cache lookup failed for type %u", attr->atttypid);

		typeform = (Form_pg_type) GETSTRUCT(tuple);
		ReleaseSysCache(tuple);

		typ = transfer_data_type_mapping(attr->atttypid, attr->atttypmod, typeform->typmodout, &typemodout);
		columnInfos[i].columnName = NameStr(attr->attname);
		columnInfos[i].notNull = attr->attnotnull;
		columnInfos[i].columnType = typ;

		if (pgspider_is_tag_key(columnInfos[i].columnName, tagsList))
			columnInfos[i].isTagKey = true;
		else
			columnInfos[i].isTagKey = false;

		columnInfos[i].typemod = typemodout;
		i++;
	}

	return columnInfos;
}

/*
 * create_column_info_array
 *		Create array of values for Data Compression Transfer Feature
 */
TransferValue *
create_values_array(PGSpiderFdwModifyState * fmstate, TupleTableSlot **slots, int numSlots)
{
	TransferValue *p_values;
	int			i;
	int			pindex = 0;

	p_values = (TransferValue *) palloc(sizeof(TransferValue) * fmstate->p_nums * numSlots);

	/* get following parameters from slots */
	if (slots != NULL && fmstate->target_attrs != NIL)
	{
		ListCell   *lc;

		for (i = 0; i < numSlots; i++)
		{
			foreach(lc, fmstate->target_attrs)
			{
				int			attnum = lfirst_int(lc);
				Datum		value;
				bool		isnull;

				value = slot_getattr(slots[i], attnum, &isnull);
				if (isnull)
				{
					p_values[pindex].isNull = true;
					p_values[pindex].value = 0;
				}
				else
				{
					p_values[pindex].value = value;
					p_values[pindex].isNull = false;
				}
				pindex++;
			}
		}
	}

	Assert(pindex == fmstate->p_nums * numSlots);

	return p_values;
}

/*
 * pgspider_escape_json_string
 *		Escapes a string for safe inclusion in JSON.
 */
static char *
pgspider_escape_json_string(char *string)
{
	StringInfo	buffer;
	const char *ptr;
	int			i;
	int			segment_start_idx;
	int			len;
	bool		needed_escaping = false;

	if (string == NULL)
		return NULL;

	for (ptr = string; *ptr; ++ptr)
	{
		if (*ptr == '"' || *ptr == '\r' || *ptr == '\n' || *ptr == '\t' ||
			*ptr == '\\')
		{
			needed_escaping = true;
			break;
		}
	}

	if (!needed_escaping)
		return pstrdup(string);

	buffer = makeStringInfo();
	len = strlen(string);
	segment_start_idx = 0;
	for (i = 0; i < len; ++i)
	{
		if (string[i] == '"' || string[i] == '\r' || string[i] == '\n' ||
			string[i] == '\t' || string[i] == '\\')
		{
			if (segment_start_idx < i)
				appendBinaryStringInfo(buffer, string + segment_start_idx,
									   i - segment_start_idx);

			appendStringInfoChar(buffer, '\\');
			if (string[i] == '"')
				appendStringInfoChar(buffer, '"');
			else if (string[i] == '\r')
				appendStringInfoChar(buffer, 'r');
			else if (string[i] == '\n')
				appendStringInfoChar(buffer, 'n');
			else if (string[i] == '\t')
				appendStringInfoChar(buffer, 't');
			else if (string[i] == '\\')
				appendStringInfoChar(buffer, '\\');

			segment_start_idx = i + 1;
		}
	}
	if (segment_start_idx < len)
		appendBinaryStringInfo(buffer, string + segment_start_idx,
							   len - segment_start_idx);
	return buffer->data;
}

/*
 * stringInfoAppendStringValue
 *		Append key and value pairs.
 */
static void
stringInfoAppendStringValue(StringInfo strInfo, char *key, char *value, char comma)
{
	char	   *escaped_key = NULL;

	/* json key must not be NULL. */
	Assert(key != NULL);

	escaped_key = pgspider_escape_json_string(key);
	if (escaped_key == NULL)
		elog(ERROR, "Cannot escape json column key");

	appendStringInfo(strInfo, "\"%s\" : ", escaped_key);	/* \"key\" : */

	if (value)
		appendStringInfo(strInfo, "\"%s\"", pgspider_escape_json_string(value));	/* \"value\" */
	else
		appendStringInfoString(strInfo, "null");	/* null */

	if (comma == ',')
		appendStringInfoString(strInfo, ", ");

	if (escaped_key != NULL)
		pfree(escaped_key);
}

/*
 * jsonifyColumnInfo
 *		Append ColumnInfo as json.
 */
static void
jsonifyColumnInfo(StringInfo strInfo, ColumnInfo * colInfo, int len)
{
	int			i;
	bool		is_first = true;

	appendStringInfoChar(strInfo, '[');
	for (i = 0; i < len; i++)
	{
		if (!is_first)
			appendStringInfoString(strInfo, ", ");

		appendStringInfoChar(strInfo, '{');

		stringInfoAppendStringValue(strInfo, "columnName", colInfo[i].columnName, ',');
		appendStringInfo(strInfo, "\"notNull\" : %s, ", (colInfo[i].notNull) ? "true" : "false");
		appendStringInfo(strInfo, "\"columnType\" : %d, ", colInfo[i].columnType);
		appendStringInfo(strInfo, "\"typemod\" : %d ", colInfo[i].typemod);

		appendStringInfoChar(strInfo, '}');

		is_first = false;
	}
	appendStringInfoChar(strInfo, ']');
}

/*
 * pgspiderPrepareConnectionURLData
 * 		Prepare Conection URL Data before sending data to Function.
 */
void
pgspiderPrepareConnectionURLData(ConnectionURLData * connData, Relation rel, DataCompressionTransferOption *dct_option)
{
	ForeignDataWrapper *fdw;
	ForeignServer *fs;
	UserMapping *user;
	ListCell   *lc;

	fs = GetForeignServer(dct_option->serverID);
	fdw = GetForeignDataWrapper(fs->fdwid);
	user = GetUserMapping(dct_option->userID, dct_option->serverID);

	if (strcmp(fdw->fdwname, POSTGRES_FDW_NAME) == 0)
		connData->targetDB = POSTGRESDB;
	else if (strcmp(fdw->fdwname, PGSPIDER_FDW_NAME) == 0)
		connData->targetDB = PGSPIDERDB;
	else if (strcmp(fdw->fdwname, MYSQL_FDW_NAME) == 0)
		connData->targetDB = MYSQLDB;
	else if (strcmp(fdw->fdwname, GRIDDB_FDW_NAME) == 0)
		connData->targetDB = GRIDDB;
	else if (strcmp(fdw->fdwname, ORACLE_FDW_NAME) == 0)
		connData->targetDB = ORACLEDB;
	else if (strcmp(fdw->fdwname, INFLUXDB_FDW_NAME) == 0)
		connData->targetDB = INFLUXDB;
	else
		elog(ERROR, "Not support datasource type: %s", fdw->fdwname);

	/*
	 * oracle_fdw support 'dbserver' options as a connection string and
	 * 'dbname' same name with 'user' of usermapping. So just use only
	 * 'dbserver' option as a 'host' for connectionURLData.
	 */
	if (connData->targetDB == ORACLEDB)
	{
		foreach(lc, user->options)
		{
			DefElem    *def = (DefElem *) lfirst(lc);

			if (strcmp(def->defname, "user") == 0)
			{
				connData->dbName = defGetString(def);
				break;
			}
		}
	}

	/* get option */
	foreach(lc, fs->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (connData->targetDB == ORACLEDB)
		{
			if (strcmp(def->defname, "dbserver") == 0)
			{
				connData->host = defGetString(def);
				break;
			}
		}
		else
		{
			if (strcmp(def->defname, "host") == 0)
			{
				connData->host = defGetString(def);
				continue;
			}
			else if (strcmp(def->defname, "port") == 0)
			{
				(void) parse_int(defGetString(def), &connData->port, 0, NULL);
				continue;
			}

			if (connData->targetDB == PGSPIDERDB ||
				connData->targetDB == POSTGRESDB ||
				connData->targetDB == INFLUXDB)
			{
				if (strcmp(def->defname, "dbname") == 0)
					connData->dbName = defGetString(def);
			}
			else if (connData->targetDB == GRIDDB)
			{
				if (strcmp(def->defname, "clustername") == 0)
					connData->clusterName = defGetString(def);
				else if (strcmp(def->defname, "database") == 0)
					connData->dbName = defGetString(def);
			}
		}
	}

	/* database of griddb_fdw, default public */
	if (connData->dbName == NULL && connData->targetDB == GRIDDB)
		connData->dbName = "public";

	/*
	 * database of mysql_fdw. In mysql_fdw, dbname option is an option of
	 * foreign table.
	 */
	if (connData->targetDB == MYSQLDB)
	{
		ForeignTable *sourceTable;

		sourceTable = GetForeignTable(RelationGetRelid(rel));
		foreach(lc, sourceTable->options)
		{
			DefElem    *def = (DefElem *) lfirst(lc);

			if (strcmp(def->defname, "dbname") == 0)
			{
				connData->dbName = defGetString(def);
				break;
			}
		}
	}

	/* Save organization name to make connection to InfluxDB */
	if (connData->targetDB == INFLUXDB)
		connData->org = dct_option->org;
}

/*
 * pgspiderPrepareAuthenticationData
 *		Prepare Authentication Data before sending data to Function.
 */
void
pgspiderPrepareAuthenticationData(AuthenticationData * authData, DataCompressionTransferOption *dct_option)
{
	UserMapping *user;
	ListCell   *lc;

	user = GetUserMapping(dct_option->userID, dct_option->serverID);

	foreach(lc, user->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "username") == 0 ||
			strcmp(def->defname, "user") == 0)
			authData->user = defGetString(def);
		else if (strcmp(def->defname, "password") == 0)
			authData->pwd = defGetString(def);
		else if (strcmp(def->defname, "auth_token") == 0)
			authData->token = defGetString(def);
	}
}

/*
 * pgspiderPrepareDDLData
 *		Prepare DDL Data before sending data to Function.
 */
void
pgspiderPrepareDDLData(DDLData * ddldata, Relation rel, bool existFlag, DataCompressionTransferOption * dct_option)
{
	TupleDesc	tupdesc = RelationGetDescr(rel);
	List	   *target_attrs = NIL;
	int			i;

	for (i = 0; i < tupdesc->natts; i++)
	{
		Form_pg_attribute att = TupleDescAttr(tupdesc, i);

		/* Ignore dropped columns. */
		if (att->attisdropped)
			continue;

		target_attrs = lappend_int(target_attrs, i + 1);
	}

	ddldata->columnInfos = create_column_info_array(rel, target_attrs, NULL);
	ddldata->tableName = dct_option->table_name;
	ddldata->numColumn = list_length(target_attrs);
	ddldata->existFlag = existFlag;
}

/*
 * pgspiderPrepareDDLRequestData
 *		Prepare DDL request to a curl request
 */
static void
pgspiderPrepareDDLRequestData(StringInfo jsonBody,
							  int mode,
							  AuthenticationData * authData,
							  ConnectionURLData * connData,
							  DDLData * ddlData)
{
	appendStringInfoString(jsonBody, "{ ");

	/* DDL_CREATE/DDL_DROP */
	appendStringInfo(jsonBody, "\"mode\": %d, ", mode);

	/* Append AuthenticationData */
	stringInfoAppendStringValue(jsonBody, "user", authData->user, ',');
	stringInfoAppendStringValue(jsonBody, "pass", authData->pwd, ',');
	stringInfoAppendStringValue(jsonBody, "token", authData->token, ',');

	/* Append ConnectionURLData */
	appendStringInfo(jsonBody, "\"targetDB\" : %d, ", connData->targetDB);
	stringInfoAppendStringValue(jsonBody, "host", connData->host, ',');
	appendStringInfo(jsonBody, "\"port\" : %d, ", connData->port);
	stringInfoAppendStringValue(jsonBody, "clusterName", connData->clusterName, ',');
	stringInfoAppendStringValue(jsonBody, "dbName", connData->dbName, ',');
	stringInfoAppendStringValue(jsonBody, "org", connData->org, ',');

	/* Append DDLData */
	stringInfoAppendStringValue(jsonBody, "tableName", ddlData->tableName, ',');
	appendStringInfo(jsonBody, "\"numColumn\" : %d, ", ddlData->numColumn);
	appendStringInfo(jsonBody, "\"existFlag\" : %s, ", (ddlData->existFlag) ? "true" : "false");
	appendStringInfoString(jsonBody, "\"columnInfos\"");
	appendStringInfoChar(jsonBody, ':');
	jsonifyColumnInfo(jsonBody, ddlData->columnInfos, ddlData->numColumn);	/* last element */

	appendStringInfoString(jsonBody, " }");
}

/*
 * pgspiderRequestExecInsert
 *		Prepare INSERT request to send through socket
 */
static void
pgspiderPrepareInsertRequestData(StringInfo jsonBody,
								 char *socket_host,
								 int socket_port,
								 int serverID,
								 int tableID,
								 AuthenticationData * authData,
								 ConnectionURLData * connData)
{
	/* parse all data to json */
	appendStringInfoString(jsonBody, "{ ");

	/* BATCH INSERT */
	appendStringInfo(jsonBody, "\"mode\": %d, ", BATCH_INSERT);

	stringInfoAppendStringValue(jsonBody, "host_socket", socket_host, ',');
	appendStringInfo(jsonBody, "\"port_socket\" : %d, ", socket_port);
	appendStringInfo(jsonBody, "\"serverID\": %d, ", serverID);
	appendStringInfo(jsonBody, "\"tableID\" : %d, ", tableID);

	/* Append AuthenticationData */
	stringInfoAppendStringValue(jsonBody, "user", authData->user, ',');
	stringInfoAppendStringValue(jsonBody, "pass", authData->pwd, ',');
	stringInfoAppendStringValue(jsonBody, "token", authData->token, ',');

	/* Append ConnectionURLData */
	appendStringInfo(jsonBody, "\"targetDB\" : %d, ", connData->targetDB);
	stringInfoAppendStringValue(jsonBody, "host", connData->host, ',');
	appendStringInfo(jsonBody, "\"port\" : %d, ", connData->port);
	stringInfoAppendStringValue(jsonBody, "clusterName", connData->clusterName, ',');
	stringInfoAppendStringValue(jsonBody, "dbName", connData->dbName, ',');
	stringInfoAppendStringValue(jsonBody, "org", connData->org, '\0');

	appendStringInfoString(jsonBody, " }");
}

/*
 * pgspider_write_body
 *		Internal function used to write the body response into a response data structure
 */
static size_t
pgspider_write_body(void *contents, size_t size, size_t nmemb, void *user_data)
{
	size_t		realsize = size * nmemb;
	body_res   *body_data = (body_res *) user_data;

	if (body_data->data == NULL)
		body_data->data = palloc0(realsize + 1);
	else
	{
		body_data->data = repalloc(body_data->data, body_data->size + realsize + 1);
		memset(&(body_data->data[body_data->size]), 0, realsize + 1);
	}

	memcpy(&(body_data->data[body_data->size]), contents, realsize);
	body_data->size += realsize;

	return realsize;
}

/*
 * pgspider_curl_init
 *		Set HTTP version, proxy, endpoint, and body for a curl request
 *		return a curl handler which can be used to perform a curl request.
 */
static void
pgspider_curl_init(char *proxy, char *endpoint, int function_timeout,
				   size_t (*write_body_function) (void *contents, size_t size, size_t nmemb, void *user_data),
				   void *body, CURL * curl_handle)
{
	/* Sepcifies HTTP protocol version to use Use HTTP/1.1 as default */
	if (curl_easy_setopt(curl_handle, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_NONE) != CURLE_OK)
		elog(ERROR, "pgspider_fdw: could not set HTTP version for CURLOPT_HTTP_VERSION option");

	/* set URL */
	if (curl_easy_setopt(curl_handle, CURLOPT_URL, endpoint) != CURLE_OK)
		elog(ERROR, "pgspider_fdw: could not set URL for CURLOPT_URL option");

	if (proxy != NULL)
	{
		/* set proxy */
		if (strcmp(proxy, "no") == 0)
		{
			/* If proxy is specified, set CURLOPT_PROXY to "" (empty string) */
			if (curl_easy_setopt(curl_handle, CURLOPT_PROXY, "") != CURLE_OK)
				elog(ERROR, "pgspider_fdw: could not set empty proxy for CURLOPT_PROXY option");
		}
		else
		{
			if (curl_easy_setopt(curl_handle, CURLOPT_PROXY, proxy) != CURLE_OK)
				elog(ERROR, "pgspider_fdw: could not set '%s' proxy for CURLOPT_PROXY option.", proxy);

			/*
			 * The FDW sets CURLOPT_NOPROXY to "" (empty string): will
			 * explicitly enable the proxy for all host names, even if there
			 * is an environment variable set for it
			 */
			if (curl_easy_setopt(curl_handle, CURLOPT_NOPROXY, "") != CURLE_OK)
				elog(ERROR, "pgspider_fdw: could not set empty noproxy for CURLOPT_NOPROXY option.");
		}
	}

	/*
	 * Set timeout. GCP not asynchronize the use timeout limitation is 60
	 * minutes
	 */
	if (curl_easy_setopt(curl_handle, CURLOPT_TIMEOUT, function_timeout) != CURLE_OK)
		elog(ERROR, "pgspider_fdw: could not set timeout for CURLOPT_TIMEOUT option");

	/* set http method */
	if (curl_easy_setopt(curl_handle, CURLOPT_CUSTOMREQUEST, PGFDW_HTTP_POST_METHOD) != CURLE_OK)
		elog(ERROR, "pgspider_fdw: could not set '%s' method for CURLOPT_CUSTOMREQUEST option.", PGFDW_HTTP_POST_METHOD);

	if (write_body_function != NULL)
	{
		/* Set CURLOPT_WRITEFUNCTION if specified */
		if (curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, write_body_function) != CURLE_OK)
			elog(ERROR, "pgspider_fdw: could not set write function callback for CURLOPT_WRITEFUNCTION option.");

		/* Set CURLOPT_WRITEDATA if specified */
		if (curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, body) != CURLE_OK)
			elog(ERROR, "pgspider_fdw: could not set argument of write function callback for CURLOPT_WRITEDATA option.");
	}
}

/*
 * pgspiderCompressData
 *		Compress an InsertData struct to a char array using LZ4 library.
 *
 * Return the compressed data in char array.
 */
char *
pgspiderCompressData(PGSpiderFdwModifyState * fmstate, InsertData * insertData, char **sizeInfors, int *compressedlength)
{
	char	   *serializedBytes,
			   *compressedBytes;
	int			maxCompressedSize,
				actualCompressedSize;
	int			uncompressedSize;

	serializedBytes = pgspiderSerializeData(fmstate, insertData, &uncompressedSize);

	/*
	 * Based on compression algorithm of LZ4, compressed size may be larger
	 * than the original size. However, the size is bounded by alignment
	 * convention of LZ4.
	 */
	maxCompressedSize = LZ4_compressBound(uncompressedSize);
	if (maxCompressedSize <= 0)
		elog(ERROR, "pgspider_fdw: input size is incorrect (too large or negative).");

	/* Get a memory segment to store enough compressed data. */
	compressedBytes = palloc0(maxCompressedSize * sizeof(char));

	/* Compress and get the actual size of compressed data. */
	actualCompressedSize = LZ4_compress_fast(serializedBytes, compressedBytes, uncompressedSize, maxCompressedSize, 4);
	if (actualCompressedSize <= 0)
		elog(ERROR, "pgspider_fdw: Cannot compress the insert data.");

	elog(INFO, "compression ratio: %.3f", (float) uncompressedSize / actualCompressedSize);

	*compressedlength = actualCompressedSize;

	/*
	 * Allocate a memory segment to store size of compressed and uncompressed
	 * data.
	 */
	*sizeInfors = palloc0(2 * INT_SIZE);

	/* Copy the size of compressed and uncompressed data to be transferred. */
	memcpy(*sizeInfors, &actualCompressedSize, INT_SIZE);
	memcpy(*sizeInfors + INT_SIZE, &uncompressedSize, INT_SIZE);

	return compressedBytes;
}

/*
 * PGSpiderRequestFunctionStart
 *		Send request to Function and get result from response.
 */
void
PGSpiderRequestFunctionStart(PGSpiderExecuteMode mode,
							 DataCompressionTransferOption * dct_option,
							 PGSpiderFdwModifyState * fmstate,
							 AuthenticationData * authData,
							 ConnectionURLData * connData,
							 DDLData * ddlData)
{
	CURL	   *volatile curl_handle = NULL;
	struct curl_slist *volatile header_list = NULL;
	struct curl_slist *tmp_list = NULL;
	char	   *socket_host;
	StringInfoData jsonBody;

	initStringInfo(&jsonBody);

	switch (mode)
	{
		case DDL_CREATE:
		case DDL_DROP:
			pgspiderPrepareDDLRequestData(&jsonBody, mode, authData, connData, ddlData);
			break;
		case BATCH_INSERT:
			socket_host = pgspiderGetExternalIp();
			pgspiderPrepareInsertRequestData(&jsonBody, socket_host,
											 fmstate->socket_port,
											 fmstate->socketThreadInfo.serveroid,
											 fmstate->socketThreadInfo.tableoid,
											 authData, connData);
			break;
		default:
			elog(ERROR, "Unsupported execution mode");
	}

	PG_TRY();
	{
		long		status;		/* HTTP response status code */
		static char curl_errbuf[CURL_ERROR_SIZE];
		CURLcode	res = CURLE_OK;
		StringInfoData http_header;
		CURLoption	post_size_opt = 0;
		body_res	body;

		/* Initialize response */
		body.data = NULL;
		body.size = 0;

		/* Initialize curl handler */
		curl_handle = curl_easy_init();
		if (curl_handle == NULL)
			elog(ERROR, "pgspider_fdw: could not initialize Curl handler.");

		pgspider_curl_init(dct_option->proxy, dct_option->endpoint, dct_option->function_timeout, pgspider_write_body, (void *) &body, curl_handle);

		/* set content-length */
		initStringInfo(&http_header);
		appendStringInfo(&http_header, "%s: %d", PGFDW_HEADER_KEY_CONTENT_LENGTH, jsonBody.len);

		if ((header_list = curl_slist_append(header_list, http_header.data)) == NULL)
			elog(ERROR, "pgspider_fdw: could not append Content-Length to header list.");

		/* Append header */
		/* set content-type. Use tmp_list to avoid memory leak if curl_slist_append error. */
		if ((tmp_list = curl_slist_append(header_list, PGFDW_HEADER_FORMAT_JSON)) == NULL)
			elog(ERROR, "pgspider_fdw: could not append HTTP header to header list.");

		header_list = tmp_list;

		if (curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, header_list) != CURLE_OK)
			elog(ERROR, "pgspider_fdw: could not set Content-Type option.");

		/* set content data */

		/*
		 * If POST data langer than 2GB use CURLOPT_POSTFIELDSIZE_LARGE option
		 * else use CURLOPT_POSTFIELDSIZE option.
		 */
		if (jsonBody.len < PGFDW_MAX_CURL_BODY_LENGTH)
			post_size_opt = CURLOPT_POSTFIELDSIZE;
		else
			post_size_opt = CURLOPT_POSTFIELDSIZE_LARGE;

		if (curl_easy_setopt(curl_handle, post_size_opt, (curl_off_t) jsonBody.len) != CURLE_OK ||
			curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, jsonBody.data) != CURLE_OK ||
			curl_easy_setopt(curl_handle, CURLOPT_POST, 1) != CURLE_OK)
			elog(ERROR, "pgspider_fdw: could not set HTTP version for CURLOPT_POSTFIELDS option");

		/*
		 * Set a buffer that libcurl may store human readable error messages
		 * on failures or problems
		 */
		if (curl_easy_setopt(curl_handle, CURLOPT_ERRORBUFFER, curl_errbuf) != CURLE_OK)
			elog(ERROR, "pgspider_fdw: could not set error buffer for error messages");

		/* clean error buffer before request */
		curl_errbuf[0] = 0;

		/* Send request */
		res = curl_easy_perform(curl_handle);

		if (res != CURLE_OK)
			elog(ERROR, "pgspider_fdw: %s", curl_errbuf);

		/*
		 * Receive response
		 */

		/* HTTP status code */
		if (curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &status) != CURLE_OK)
			elog(ERROR, "pgspider_fdw: Cannot receive status code");

		/* Check error response */
		if (status != PGREST_HTTP_RES_STATUS_OK)
			elog(ERROR, "pgspider_fdw: %s", body.data);

		curl_slist_free_all(header_list);
		curl_easy_cleanup(curl_handle);
	}
	PG_CATCH();
	{
		if (header_list)
			curl_slist_free_all(header_list);
		if (curl_handle)
			curl_easy_cleanup(curl_handle);
		PG_RE_THROW();
	}
	PG_END_TRY();
}

/*
 * convert_4_bytes_array_to_int
 * 		Convert 4 bytes data to an int number.
 * 		The bytes of byte[] in a big-endian order used in networking (TCP/IP).
 * 		Need to convert value match with the little-endian system.
 */
static int32
convert_4_bytes_array_to_int(unsigned char byte[])
{
	return (byte[0] << 24) + \
		((byte[1] & 0xFF) << 16) + \
		((byte[2] & 0xFF) << 8) + \
		(byte[3] & 0xFF);
}

/*
 * send_data
 *		Sending data through socket client.
 *		Continue sending until the expected size is reached.
 */
static bool
send_data(int socket_id, int expected_size, char *data, char **err_msg, int function_timeout, char *detailed_msg)
{
	int		numBytes = 0;
	int		ret;
	fd_set	write_fds;
	struct timeval timeout = {.tv_usec = 0};

	/* timeout for read/write data with Function side */
	timeout.tv_sec = function_timeout;

	for (numBytes = 0; numBytes < expected_size; )
	{
		/* clear the set */
		FD_ZERO(&write_fds);
		/* add socket file descriptor to the set */
		FD_SET(socket_id, &write_fds);

		ret = select(socket_id + 1, NULL, &write_fds, NULL, &timeout);
		PGSFDW_CHECK_SYSTEMCALL_SELECT_ERROR(ret, (*err_msg), function_timeout)

		/* send compression/decompression length of insert data */
		if (!FD_ISSET(socket_id, &write_fds))
			continue;

		ret = send(socket_id, &data[numBytes], expected_size - numBytes, 0);
		PGSFDW_CHECK_SYSTEMCALL_ERROR(ret, (*err_msg), detailed_msg)

		numBytes += ret;
	}

	return true;
}

/*
 * read_data
 *		Reading data through socket client.
 *		Continue reading until the expected size is reached.
 */
static bool
read_data(int socket_id, int expected_size, unsigned char *buffer, char **err_msg, int function_timeout, char *detailed_msg)
{
	int		numBytes = 0;
	int		ret;
	fd_set	read_fds;
	struct timeval timeout = {.tv_usec = 0};

	/* timeout for read/write data with Function side */
	timeout.tv_sec = function_timeout;
	for (numBytes = 0; numBytes < expected_size; )
	{
		/* clear the set */
		FD_ZERO(&read_fds);
		/* add socket file descriptor to the set */
		FD_SET(socket_id, &read_fds);

		ret = select(socket_id + 1, &read_fds, NULL, NULL, &timeout);
		PGSFDW_CHECK_SYSTEMCALL_SELECT_ERROR(ret, (*err_msg), function_timeout)

		/* read length of the message from the Function */
		if (!FD_ISSET(socket_id, &read_fds))
			continue;

		ret = read(socket_id, &buffer[numBytes], expected_size - numBytes);
		PGSFDW_CHECK_SYSTEMCALL_ERROR(ret, (*err_msg), detailed_msg)

		numBytes += ret;
	}

	return true;
}

/*
 * pgspider_setSendInsertDataThreadContext
 * 		Set error handling configuration and memory context. Additionally, create
 * 		memory context for send insert data thread.
 */
static void
pgspider_setSendInsertDataThreadContext(SocketInfo * socketInfo)
{
	MemoryContextSwitchTo(socketInfo->send_insert_data_ctx);

	/* Initialize ErrorContext for each child thread. */
	ErrorContext = AllocSetContextCreate(socketInfo->send_insert_data_ctx,
										 "send insert data Thread ErrorContext",
										 ALLOCSET_DEFAULT_SIZES);
	MemoryContextAllowInCriticalSection(ErrorContext, true);

	/* Declare ereport/elog jump is not available. */
	PG_exception_stack = NULL;
	error_context_stack = NULL;
}

/*
 * send_insert_data_thread
 * 		Send insertion data to Function through socket and receive result.
 */
void *
send_insert_data_thread(void *arg)
{
	SocketInfo *socketInfo = (SocketInfo *) arg;
	SocketThreadInfo *socketThreadInfo = socketInfo->socketThreadInfo;
	Latch		LocalLatchData;
	unsigned char *result_len_buffer;
	int32		result_len;
	unsigned char *result_buffer;
	int			function_timeout = socketInfo->function_timeout;
	bool		ret;

	/*
	 * MyLatch is the thread local variable, when creating child thread we
	 * need to init it for use in child thread.
	 */
	MyLatch = &LocalLatchData;
	InitLatch(MyLatch);

	/* Configuration for context of error handling and memory context. */
	pgspider_setSendInsertDataThreadContext(socketInfo);

	/*
	 * Sleep until Function requests PGSpider to send data. socket_id and
	 * childThreadState will be changed from socket_server thread.
	 */
	while (socketThreadInfo->childThreadState == DCT_MDF_STATE_BEGIN || socketInfo->socketThreadInfo->socket_id == 0)
	{
		if (socketThreadInfo->childThreadState == DCT_MDF_STATE_END)
			break;
		usleep(1);
	}

	pthread_mutex_lock(&socketThreadInfo->socket_thread_info_mutex);
	if (socketThreadInfo->childThreadState == DCT_MDF_STATE_FINISH ||
		socketThreadInfo->childThreadState == DCT_MDF_STATE_END)
	{
		/* set FINISH state if thread is required end */
		socketThreadInfo->childThreadState = DCT_MDF_STATE_FINISH;
		if (socketThreadInfo->socket_id > 0)
			close(socketThreadInfo->socket_id);
		pthread_mutex_unlock(&socketThreadInfo->socket_thread_info_mutex);
		pthread_exit(NULL);
	}
	pthread_mutex_unlock(&socketThreadInfo->socket_thread_info_mutex);

	ret = send_data(socketThreadInfo->socket_id, COMP_DECOMP_LENGTH,
					socketInfo->sizeInfos, &socketInfo->result, function_timeout,
					"Fail to send compression/decompression length");
	PGSFDW_CHECK_READ_SEND_RESULT(ret, INSERT_DATA_FINISH)

	ret = send_data(socketThreadInfo->socket_id, socketInfo->compressedlength,
					socketInfo->compressedData, &socketInfo->result, function_timeout,
					"Fail to send compressed insert data");
	PGSFDW_CHECK_READ_SEND_RESULT(ret, INSERT_DATA_FINISH)

	result_len_buffer = (unsigned char *) palloc0(sizeof(result_len));
	ret = read_data(socketThreadInfo->socket_id, sizeof(result_len),
					result_len_buffer, &socketInfo->result, function_timeout,
					"Fail to read length of the message from the Function");
	PGSFDW_CHECK_READ_SEND_RESULT(ret, INSERT_DATA_FINISH)
	result_len = convert_4_bytes_array_to_int(result_len_buffer);

	result_buffer = (unsigned char *) palloc0(sizeof(unsigned char) * result_len + 1);
	ret = read_data(socketThreadInfo->socket_id, result_len,
					result_buffer, &socketInfo->result, function_timeout,
					"Fail to read the message from the Function");
	PGSFDW_CHECK_READ_SEND_RESULT(ret, INSERT_DATA_FINISH)

	socketInfo->result = (char *) result_buffer;

INSERT_DATA_FINISH:
	socketThreadInfo->childThreadState = DCT_MDF_STATE_FINISH;
	if (close(socketThreadInfo->socket_id) == -1)
		socketInfo->result = strerror(errno);

	pthread_mutex_destroy(&socketThreadInfo->socket_thread_info_mutex);

	pthread_exit(NULL);
}

/*
 * check_data_compression_transfer_option
 *		Data Compression Transfer Feauture will be enabled if
 *		'endpoint' option exists.
 */
bool
check_data_compression_transfer_option(Relation rel)
{
	ListCell   *lc;
	ForeignServer *server;
	ForeignTable *table;

	table = GetForeignTable(RelationGetRelid(rel));
	server = GetForeignServer(table->serverid);

	/* Get options for Data Compression Transfer */
	foreach(lc, server->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "endpoint") == 0)
			return true;
	}

	return false;
}

/*
 * get_data_compression_transfer_option
 *		Get options for Data Compression Transfer
 */
void
get_data_compression_transfer_option(PGSpiderExecuteMode mode, Relation rel, DataCompressionTransferOption * dct_option)
{
	List	   *options;
	ListCell   *lc;
	ForeignServer *server;
	ForeignTable *table;
	char	   *schema_name = NULL;
	char	   *table_option = NULL;

	table = GetForeignTable(RelationGetRelid(rel));
	server = GetForeignServer(table->serverid);

	options = NIL;
	options = list_concat(options, table->options);
	options = list_concat(options, server->options);

	foreach(lc, options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "endpoint") == 0)
			dct_option->endpoint = defGetString(def);
		else if (strcmp(def->defname, "proxy") == 0)
			dct_option->proxy = defGetString(def);
		else if (strcmp(def->defname, "schema_name") == 0)
			schema_name = defGetString(def);
		else if (strcmp(def->defname, "table_name") == 0)
			dct_option->table_name = defGetString(def);
		/* oracle_fdw use `table` instead of `table_name` option */
		else if (strcmp(def->defname, "table") == 0)
			table_option = defGetString(def);
		else if (strcmp(def->defname, "serverid") == 0)
			(void) parse_int(defGetString(def), &dct_option->serverID, 0, NULL);
		else if (strcmp(def->defname, "userid") == 0)
			(void) parse_int(defGetString(def), &dct_option->userID, 0, NULL);
		else if (strcmp(def->defname, "org") == 0)
			dct_option->org = defGetString(def);
		else if (strcmp(def->defname, "tags") == 0)
			dct_option->tagsList = pgspider_extract_tags_list(defGetString(def));
	}

	/*
	 * table name to be sent to Function will contain schema if needed.
	 *
	 * Use table option if 'table' or 'table_name' is specified.
	 */
	if (table_option != NULL)
		dct_option->table_name = table_option;
	else if (schema_name && dct_option->table_name)
		dct_option->table_name = psprintf("%s\".\"%s", schema_name, dct_option->table_name);
}
