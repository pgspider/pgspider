/*-------------------------------------------------------------------------
 *
 * dct_common.c
 *		  Common utilities processing for data sources
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/pgspider_fdw/dct_common.c
 *
 *-------------------------------------------------------------------------
 */

#include "dct_common.h"

/*
 * dct_escape_json_string
 *		Escapes a string for safe inclusion in JSON.
 */
char *
dct_escape_json_string(char *string)
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
 * dct_stringInfoAppendStringValue
 *		Append key and value pairs.
 */
void
dct_stringInfoAppendStringValue(StringInfo strInfo, char *key, char *value, char comma)
{
	char	   *escaped_key = NULL;

	/* json key must not be NULL. */
	Assert(key != NULL);

	escaped_key = dct_escape_json_string(key);
	if (escaped_key == NULL)
		elog(ERROR, "Cannot escape json column key");

	appendStringInfo(strInfo, "\"%s\" : ", escaped_key);	/* \"key\" : */

	if (value)
		appendStringInfo(strInfo, "\"%s\"", dct_escape_json_string(value));	/* \"value\" */
	else
		appendStringInfoString(strInfo, "null");	/* null */

	if (comma == ',')
		appendStringInfoString(strInfo, ", ");

	if (escaped_key != NULL)
		pfree(escaped_key);
}

/*
 * dct_jsonifyColumnInfo
 *		Append ColumnInfo as json.
 */
void
dct_jsonifyColumnInfo(StringInfo strInfo, ColumnInfo * colInfo, int len)
{
	int			i;
	bool		is_first = true;

	appendStringInfoChar(strInfo, '[');
	for (i = 0; i < len; i++)
	{
		if (!is_first)
			appendStringInfoString(strInfo, ", ");

		appendStringInfoChar(strInfo, '{');

		dct_stringInfoAppendStringValue(strInfo, "columnName", colInfo[i].columnName, ',');
		appendStringInfo(strInfo, "\"notNull\" : %s, ", (colInfo[i].notNull) ? "true" : "false");
		appendStringInfo(strInfo, "\"columnType\" : %d, ", colInfo[i].columnType);
		appendStringInfo(strInfo, "\"typemod\" : %d ", colInfo[i].typemod);

		appendStringInfoChar(strInfo, '}');

		is_first = false;
	}
	appendStringInfoChar(strInfo, ']');
}
