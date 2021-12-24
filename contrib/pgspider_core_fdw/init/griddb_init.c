#include "gridstore.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stddef.h>

typedef struct {
  GSContainer *container;
  GSContainerInfo info;
} table_info;

#define STRING_MAX_LENGTH 1000

/**
 * Create table info
 * Arguments: GridStore instance, table name, table info, number of column, [ column1_name, column1_type, column1_options, column2_name, column2_type, column2_options,...
 */
void set_tableInfo (GSGridStore *store,
                    const GSChar *tbl_name,
                    table_info *tbl_info,
                    GSContainerType container_type,
                    size_t column_count,...)
{
  GSResult ret;
  tbl_info->info = (GSContainerInfo)GS_CONTAINER_INFO_INITIALIZER;
  tbl_info->info.type = container_type;
  tbl_info->info.name = tbl_name;
  tbl_info->info.columnCount = column_count;
  /* Set column info */
  GSColumnInfo column_info = GS_COLUMN_INFO_INITIALIZER;
  GSColumnInfo *column_info_list = calloc(column_count, sizeof(GSColumnInfo));
  int i;
  va_list valist;
  const GSChar *rowkey;
  va_start(valist, column_count);
  for (i = 0; i < column_count; i++) {
    column_info.name = va_arg(valist, GSChar*);
    if (i == 0) {
      rowkey = column_info.name;
    }
    column_info.type = va_arg(valist, GSType);
    column_info.options = va_arg(valist, GSTypeOption);
    column_info_list[i] = column_info;
  }
  va_end(valist);
  tbl_info->info.columnInfoList = column_info_list;
  tbl_info->info.rowKeyAssigned = GS_TRUE;
  /* Drop the old container if it existed */
  gsDropContainer(store, tbl_info->info.name);
  /* Create a Collection (Delete if schema setting is NULL) */
  ret = gsPutContainerGeneral(store, NULL, &(tbl_info->info), GS_FALSE, &(tbl_info->container));
  if (ret != GS_RESULT_OK) {
    printf("CREATE CONTAINER FAILED %s\n", tbl_name);
  }
  /* Set the autocommit mode to OFF */
  gsSetAutoCommit(tbl_info->container, GS_FALSE);
  /* Set an index on the Row-key Column */
  gsCreateIndex(tbl_info->container, rowkey, GS_INDEX_FLAG_DEFAULT);
}

static void deconstructArray(GSType gs_type, GSChar *array_cols, void ***elem_values, int *num_elems)
{
  GSChar        **stringaData;
  GSBool        **boolaData;
  int8_t	      *byteaData;
  int16_t       *shortaData;
  int32_t       *intaData;
  int64_t       *longaData;
  float         *floataData;
  double        *doubleaData;
  GSTimestamp   *tsaData;
  GSChar        *temp;
  GSChar        *token;
  int           i = 0;
  int           str_len = strlen(array_cols);
  int           count_elems = 1;

  temp = (GSChar *)malloc(str_len * sizeof(GSChar));

  if ((array_cols[0] != '{') && (array_cols[str_len - 1] != '}'))
  {
    printf("DATA ERROR");
    return;
  }

  /* Copy data and count element */
  for (i = 0; i < str_len - 2; i++)
  {
    temp[i] = array_cols[i + 1];
    if (temp[i] == ',')
      count_elems++;
  }
  /* null terminated */
  temp[str_len - 2] = 0;

  /* Allocate memory */
  if (gs_type == GS_TYPE_STRING_ARRAY)
    stringaData = (GSChar **)malloc(sizeof(GSChar *) * count_elems);
  else if (gs_type == GS_TYPE_BOOL_ARRAY)
    boolaData = (GSBool **) malloc(sizeof(GSBool *) * count_elems);
  else if (gs_type == GS_TYPE_BYTE_ARRAY)
    byteaData = (int8_t *) malloc(sizeof(int8_t) * count_elems);
  else if (gs_type == GS_TYPE_SHORT_ARRAY)
    shortaData = (int16_t *) malloc(sizeof(int16_t) * count_elems);
  else if (gs_type == GS_TYPE_INTEGER_ARRAY)
    intaData = (int32_t *) malloc(sizeof(int32_t) * count_elems);
  else if (gs_type == GS_TYPE_LONG_ARRAY)
    longaData = (int64_t *) malloc(sizeof(int64_t) * count_elems);
  else if (gs_type == GS_TYPE_FLOAT_ARRAY)
    floataData = (float *) malloc(sizeof(float) * count_elems);
  else if (gs_type == GS_TYPE_DOUBLE_ARRAY)
    doubleaData = (double *) malloc(sizeof(double) * count_elems);
  else if (gs_type == GS_TYPE_TIMESTAMP_ARRAY)
    tsaData = (GSTimestamp *) malloc(sizeof(GSTimestamp) * count_elems);

  /* Get element */
  i = 0;
  while (token = strtok_r(temp, ",", &temp))
  {
    if (gs_type == GS_TYPE_STRING_ARRAY)
      stringaData[i] = token;
    else if (gs_type == GS_TYPE_BOOL_ARRAY)
    {
      if (strcmp(token, "true") == 0 ||
          strcmp(token, "t") == 0)
        boolaData[i] = (GSBool *) GS_TRUE;
      else
        boolaData[i] = (GSBool *) GS_FALSE;
    }
    else if (gs_type == GS_TYPE_BYTE_ARRAY)
        byteaData[i] = (int8_t) atoi(token);
    else if (gs_type == GS_TYPE_SHORT_ARRAY)
        shortaData[i] = (int16_t) atoi(token);
    else if (gs_type == GS_TYPE_INTEGER_ARRAY)
        intaData[i] = (int32_t) atoi(token);
    else if (gs_type == GS_TYPE_LONG_ARRAY)
        longaData[i] = (int64_t) atol(token);
    else if (gs_type == GS_TYPE_FLOAT_ARRAY)
        floataData[i] = strtof(token, NULL);
    else if (gs_type == GS_TYPE_DOUBLE_ARRAY)
        doubleaData[i] = strtod(token, NULL);
    else if (gs_type == GS_TYPE_TIMESTAMP_ARRAY)
        gsParseTime(token, &tsaData[i]);

    i++;
  }

  /* Return values */
  if (gs_type == GS_TYPE_STRING_ARRAY)
    *elem_values = (void**)stringaData;
  else if (gs_type == GS_TYPE_BOOL_ARRAY)
    *elem_values = (void**)boolaData;
  else if (gs_type == GS_TYPE_BYTE_ARRAY)
    *elem_values = (void**)byteaData;
  else if (gs_type == GS_TYPE_SHORT_ARRAY)
    *elem_values = (void**)shortaData;
  else if (gs_type == GS_TYPE_INTEGER_ARRAY)
    *elem_values = (void**)intaData;
  else if (gs_type == GS_TYPE_LONG_ARRAY)
    *elem_values = (void**)longaData;
  else if (gs_type == GS_TYPE_FLOAT_ARRAY)
    *elem_values = (void**)floataData;
  else if (gs_type == GS_TYPE_DOUBLE_ARRAY)
    *elem_values = (void**)doubleaData;
  else if (gs_type == GS_TYPE_TIMESTAMP_ARRAY)
    *elem_values = (void**)tsaData;

  *num_elems = count_elems;
}

/**
 * Insert records from TSV file
 * Arguments: GridStore instance, table info, TSV file path
 */
void insertRecordsFromTSV (GSGridStore *store, table_info *tbl_info, char* file_path)
{
  int i;
  // Create array to save a record
  char** record_cols = (char**) malloc(tbl_info->info.columnCount * sizeof(char*));

  for (i = 0; i < tbl_info->info.columnCount; i++) {
    record_cols[i] = (char*) malloc(STRING_MAX_LENGTH * sizeof(char));
  }

  // Open .data file (tab-separated values file)
  char line[STRING_MAX_LENGTH];
  char* data;
  int offset;
  FILE *infile;
  GSRow *row;
  GSResult ret;
  infile = fopen(file_path, "r");

  if (!infile) {
    printf("Couldn't open %s for reading\n", file_path);
    return;
  }

  while(fgets(line, sizeof(line), infile) != NULL) {
    data = line;
    i = 0;
    while (sscanf(data, " %[^\t^\n]%n", record_cols[i], &offset) == 1) {
      data += offset;
      i++;
    }

    /* Prepare data for a Row */
    {
      gsCreateRowByStore(store, &(tbl_info->info), &row);
      for (i = 0; i < tbl_info->info.columnCount; i++) 
      {
        int gs_type = tbl_info->info.columnInfoList[i].type;
        switch (gs_type) {
          case GS_TYPE_STRING:
            gsSetRowFieldByString(row, i, record_cols[i]);
            break;
          case GS_TYPE_BOOL:
            {
              GSBool boolVal;

              if (strcmp(record_cols[i], "t") == 0 ||
                  strcmp(record_cols[i], "true") == 0)
                boolVal = GS_TRUE; 
              else
                boolVal = GS_FALSE;
              gsSetRowFieldByBool(row, i, boolVal);
              break;
            }
          case GS_TYPE_BYTE:
            gsSetRowFieldByByte(row, i, (int8_t)atoi(record_cols[i]));
            break;
          case GS_TYPE_SHORT:
            gsSetRowFieldByShort(row, i, (int16_t)atoi(record_cols[i]));
            break;
          case GS_TYPE_INTEGER:
            gsSetRowFieldByInteger(row, i, (int32_t)atoi(record_cols[i]));
            break;
          case GS_TYPE_LONG:
            gsSetRowFieldByLong(row, i, atol(record_cols[i]));
            break;
          case GS_TYPE_FLOAT:
            gsSetRowFieldByFloat(row, i, strtof(record_cols[i], NULL));
            break;
          case GS_TYPE_DOUBLE:
            gsSetRowFieldByDouble(row, i, strtod(record_cols[i], NULL));
            break;
          case GS_TYPE_TIMESTAMP:
          {
            GSTimestamp timestamp;

            gsParseTime(record_cols[i], &timestamp);
            gsSetRowFieldByTimestamp(row, i, timestamp);
            break;
          }
          case GS_TYPE_BLOB:
          {
            GSBlob blobVal;

            blobVal.size = strlen(record_cols[i]);
            blobVal.data = (const void *)(record_cols[i]);

            gsSetRowFieldByBlob(row, i, &blobVal);
            break;
          }
          case GS_TYPE_STRING_ARRAY:
          {
            GSChar **stringaData;
            int     num_elems = 0;

            deconstructArray(gs_type, record_cols[i], (void ***)&stringaData, &num_elems);

            gsSetRowFieldByStringArray(row, i, (const GSChar**) stringaData, num_elems);

            if (*stringaData != NULL)
              free(*stringaData);
            break;
          }
           case GS_TYPE_BOOL_ARRAY:
           {
             GSBool	   **boolaData;
             int     num_elems = 0;

             deconstructArray(gs_type, record_cols[i], (void ***)&boolaData, &num_elems);
             gsSetRowFieldByBoolArray(row, i, (const GSBool*) boolaData, num_elems);

            if (boolaData != NULL)
              free(boolaData);
            break;
           }
          case GS_TYPE_BYTE_ARRAY:
          {
            int8_t *byteaData;
            int     num_elems = 0;

            deconstructArray(gs_type, record_cols[i], (void ***)&byteaData, &num_elems);
            gsSetRowFieldByByteArray(row, i, (const int8_t*) byteaData, num_elems);
            
            if (byteaData != NULL)
               free(byteaData);
            break;
          }
          case GS_TYPE_SHORT_ARRAY:
          {
            int16_t *shortaData;
            int num_elems = 0;

            deconstructArray(gs_type, record_cols[i], (void ***)&shortaData, &num_elems);
            gsSetRowFieldByShortArray(row, i, (const int16_t *)shortaData, num_elems);

            if (shortaData != NULL)
              free(shortaData);
            break;
          }
          case GS_TYPE_INTEGER_ARRAY:
          {
            int32_t *intaData;
            int num_elems = 0;

            deconstructArray(gs_type, record_cols[i], (void ***)&intaData, &num_elems);
            gsSetRowFieldByIntegerArray(row, i, (const int32_t *)intaData, num_elems);

            if (intaData != NULL)
              free(intaData);
            break;
          }
          case GS_TYPE_LONG_ARRAY:
          {
            int64_t *longaData;
            int num_elems = 0;

            deconstructArray(gs_type, record_cols[i], (void ***)&longaData, &num_elems);
            gsSetRowFieldByLongArray(row, i, (const int64_t *)longaData, num_elems);

            if (longaData != NULL)
              free(longaData);
            break;
          }          
          case GS_TYPE_FLOAT_ARRAY:
          {
            float *floataData;
            int num_elems = 0;

            deconstructArray(gs_type, record_cols[i], (void ***)&floataData, &num_elems);
            gsSetRowFieldByFloatArray(row, i, (const float *)floataData, num_elems);

            if (floataData != NULL)
              free(floataData);
            break;
          }          
          case GS_TYPE_DOUBLE_ARRAY:
          {
            float *doubleaData;
            int num_elems = 0;

            deconstructArray(gs_type, record_cols[i], (void ***)&doubleaData, &num_elems);
            gsSetRowFieldByDoubleArray(row, i, (const double *)doubleaData, num_elems);

            if (doubleaData != NULL)
              free(doubleaData);
            break;
          }          
          case GS_TYPE_TIMESTAMP_ARRAY:
          {
            GSTimestamp *tsaData;
            int num_elems = 0;

            deconstructArray(gs_type, record_cols[i], (void ***)&tsaData, &num_elems);
            gsSetRowFieldByTimestampArray(row, i, tsaData, num_elems);

            if (tsaData != NULL)
              free(tsaData);
            break;
          }          
          default:
            break;
        }        
      }
    }

    /* Adding row */
    ret = gsPutRow(tbl_info->container, NULL, row, NULL);
    if (ret != GS_RESULT_OK)
    {
      printf("ADDING ROW FAILED\n");
      return;
    }

    gsCloseRow(&row);
  }

  /* Commit the transaction (Release the lock) */
  ret = gsCommit(tbl_info->container);

  return;
}

/**
 * Init data for multi layer test
 */
void multi_layer_test(GSGridStore *store)
{
  table_info TEST_MULTI_TBL;

  set_tableInfo(store, "test_multi", &TEST_MULTI_TBL, GS_CONTAINER_COLLECTION,
                1,
                "i", GS_TYPE_INTEGER, GS_TYPE_OPTION_NOT_NULL);

  insertRecordsFromTSV(store, &TEST_MULTI_TBL, "/tmp/griddb_core_multi.data");
}

/**
 * Init data for selectfunc test
 */
void select_func_test(GSGridStore *store)
{
  table_info s3,
      s31,
      s32;

  set_tableInfo(store, "s3", &s3, GS_CONTAINER_TIME_SERIES,
                27,
                "date", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NOT_NULL,
                "value1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
                "value2", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
                "name", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
                "age", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
                "location", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
                "gpa", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
                "date1", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE,
                "date2", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE,
                "strcol", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
                "booleancol", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
                "bytecol", GS_TYPE_BYTE, GS_TYPE_OPTION_NULLABLE,
                "shortcol", GS_TYPE_SHORT, GS_TYPE_OPTION_NULLABLE,
                "intcol", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
                "longcol", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE,
                "floatcol", GS_TYPE_FLOAT, GS_TYPE_OPTION_NULLABLE,
                "doublecol", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
                "blobcol", GS_TYPE_BLOB, GS_TYPE_OPTION_NULLABLE,
                "stringarray", GS_TYPE_STRING_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "boolarray", GS_TYPE_BOOL_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "bytearray", GS_TYPE_BYTE_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "shortarray", GS_TYPE_SHORT_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "integerarray", GS_TYPE_INTEGER_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "longarray", GS_TYPE_LONG_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "floatarray", GS_TYPE_FLOAT_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "doublearray", GS_TYPE_DOUBLE_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "timestamparray", GS_TYPE_TIMESTAMP_ARRAY, GS_TYPE_OPTION_NULLABLE);

  set_tableInfo(store, "s31", &s31, GS_CONTAINER_TIME_SERIES,
                27,
                "date", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NOT_NULL,
                "value1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
                "value2", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
                "name", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
                "age", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
                "location", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
                "gpa", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
                "date1", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE,
                "date2", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE,
                "strcol", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
                "booleancol", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
                "bytecol", GS_TYPE_BYTE, GS_TYPE_OPTION_NULLABLE,
                "shortcol", GS_TYPE_SHORT, GS_TYPE_OPTION_NULLABLE,
                "intcol", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
                "longcol", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE,
                "floatcol", GS_TYPE_FLOAT, GS_TYPE_OPTION_NULLABLE,
                "doublecol", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
                "blobcol", GS_TYPE_BLOB, GS_TYPE_OPTION_NULLABLE,
                "stringarray", GS_TYPE_STRING_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "boolarray", GS_TYPE_BOOL_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "bytearray", GS_TYPE_BYTE_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "shortarray", GS_TYPE_SHORT_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "integerarray", GS_TYPE_INTEGER_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "longarray", GS_TYPE_LONG_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "floatarray", GS_TYPE_FLOAT_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "doublearray", GS_TYPE_DOUBLE_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "timestamparray", GS_TYPE_TIMESTAMP_ARRAY, GS_TYPE_OPTION_NULLABLE);

  set_tableInfo(store, "s32", &s32, GS_CONTAINER_TIME_SERIES,
                27,
                "date", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NOT_NULL,
                "value1", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
                "value2", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
                "name", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
                "age", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
                "location", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
                "gpa", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
                "date1", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE,
                "date2", GS_TYPE_TIMESTAMP, GS_TYPE_OPTION_NULLABLE,
                "strcol", GS_TYPE_STRING, GS_TYPE_OPTION_NULLABLE,
                "booleancol", GS_TYPE_BOOL, GS_TYPE_OPTION_NULLABLE,
                "bytecol", GS_TYPE_BYTE, GS_TYPE_OPTION_NULLABLE,
                "shortcol", GS_TYPE_SHORT, GS_TYPE_OPTION_NULLABLE,
                "intcol", GS_TYPE_INTEGER, GS_TYPE_OPTION_NULLABLE,
                "longcol", GS_TYPE_LONG, GS_TYPE_OPTION_NULLABLE,
                "floatcol", GS_TYPE_FLOAT, GS_TYPE_OPTION_NULLABLE,
                "doublecol", GS_TYPE_DOUBLE, GS_TYPE_OPTION_NULLABLE,
                "blobcol", GS_TYPE_BLOB, GS_TYPE_OPTION_NULLABLE,
                "stringarray", GS_TYPE_STRING_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "boolarray", GS_TYPE_BOOL_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "bytearray", GS_TYPE_BYTE_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "shortarray", GS_TYPE_SHORT_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "integerarray", GS_TYPE_INTEGER_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "longarray", GS_TYPE_LONG_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "floatarray", GS_TYPE_FLOAT_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "doublearray", GS_TYPE_DOUBLE_ARRAY, GS_TYPE_OPTION_NULLABLE,
                "timestamparray", GS_TYPE_TIMESTAMP_ARRAY, GS_TYPE_OPTION_NULLABLE);

  insertRecordsFromTSV(store, &s3, "/tmp/griddb_selectfunc.dat");
  insertRecordsFromTSV(store, &s31, "/tmp/griddb_selectfunc1.dat");
  insertRecordsFromTSV(store, &s32, "/tmp/griddb_selectfunc2.dat");
}

/**
 * Connect to GridDB cluster and insert data to the database
 * Arguments: IP address, port, cluster name, username, password
 */
int griddb_preparation (const char *addr,
                        const char *port,
                        const char *cluster_name,
                        const char *user,
                        const char *passwd,
                        const char *test_mode)
{
  static const GSBool update = GS_TRUE;
  GSColumnInfo* columnInfoList;
  GSGridStore *store;
  GSRow *row;
  GSQuery *query;
  GSRowSet *rs;
  GSResult ret;
  int count;
  int32_t id;
  const GSPropertyEntry props[] = {
      {"notificationAddress", addr},
      {"notificationPort", port},
      {"clusterName", cluster_name},
      {"user", user},
      {"password", passwd}};
  const size_t prop_count = sizeof(props) / sizeof(*props);
  /* Create a GridStore instance */
  gsGetGridStore(gsGetDefaultFactory(), props, prop_count, &store);

  if (atoi(test_mode) == 0)
    multi_layer_test(store);
  else if (atoi(test_mode) == 1)
    select_func_test(store);
  else
    printf("Does not support this test mode");

  /* Release the resource */
  gsCloseGridStore(&store, GS_TRUE);
}

/* Main funtion */
void main(int argc, char *argv[])
{
  griddb_preparation(argv[1], argv[2], argv[3], argv[4], argv[5], argv[6]);
}