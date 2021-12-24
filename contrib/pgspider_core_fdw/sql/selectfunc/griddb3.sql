--Testcase 1:
SET datestyle=ISO;
--Testcase 2:
SET timezone='Japan';

--Testcase 3:
CREATE EXTENSION pgspider_core_fdw;
--Testcase 4:
CREATE SERVER pgspider_core_svr FOREIGN DATA WRAPPER pgspider_core_fdw OPTIONS (host '127.0.0.1');
--Testcase 5:
CREATE USER MAPPING FOR CURRENT_USER SERVER pgspider_core_svr;

----------------------------------------------------------
-- test structure
-- PGSpider Top Node -+-> Child PGSpider Node -> Data source
--                    +-> Data source
-- stub functions are provided by pgspider_fdw and/or Data source FDW (mix use)

----------------------------------------------------------
-- Data source: griddb

--Testcase 6:
CREATE FOREIGN TABLE s3 (
       date timestamp without time zone,
       value1 integer,
       value2 double precision,
       name text,
       age integer,
       location text,
       gpa double precision,
       date1 timestamp without time zone,
       date2 timestamp without time zone,
       strcol text,
       booleancol boolean,
       bytecol smallint,
       shortcol smallint,
       intcol integer,
       longcol bigint,
       floatcol real,
       doublecol double precision,
       blobcol bytea,
       stringarray text[],
       boolarray boolean[],
       bytearray smallint[],
       shortarray smallint[],
       integerarray integer[],
       longarray bigint[],
       floatarray real[],
       doublearray double precision[],
       timestamparray timestamp without time zone[],
       __spd_url text
) SERVER pgspider_core_svr;

--Testcase 7:
CREATE EXTENSION pgspider_fdw;
--Testcase 8:
CREATE SERVER pgspider_svr FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (host '127.0.0.1', port '5433', dbname 'postgres');
--Testcase 9:
CREATE USER MAPPING FOR CURRENT_USER SERVER pgspider_svr;
--Testcase 10:
CREATE FOREIGN TABLE s3__pgspider_svr__0 (
       date timestamp without time zone,
       value1 integer,
       value2 double precision,
       name text,
       age integer,
       location text,
       gpa double precision,
       date1 timestamp without time zone,
       date2 timestamp without time zone,
       strcol text,
       booleancol boolean,
       bytecol smallint,
       shortcol smallint,
       intcol integer,
       longcol bigint,
       floatcol real,
       doublecol double precision,
       blobcol bytea,
       stringarray text[],
       boolarray boolean[],
       bytearray smallint[],
       shortarray smallint[],
       integerarray integer[],
       longarray bigint[],
       floatarray real[],
       doublearray double precision[],
       timestamparray timestamp without time zone[],
       __spd_url text
) SERVER pgspider_svr OPTIONS(table_name 's31griddb');

--Testcase 11:
CREATE EXTENSION griddb_fdw;
--Testcase 12:
CREATE SERVER griddb_svr FOREIGN DATA WRAPPER griddb_fdw  OPTIONS (host '239.0.0.1', port '31999', clustername 'griddbfdwTestCluster');
--Testcase 13:
CREATE USER MAPPING FOR public SERVER griddb_svr OPTIONS (username 'admin', password 'testadmin');
--Testcase 14:
CREATE FOREIGN TABLE s3__griddb_svr__0 (
       date timestamp without time zone  OPTIONS (rowkey 'true'),
       value1 integer,
       value2 double precision,
       name text,
       age integer,
       location text,
       gpa double precision,
       date1 timestamp without time zone,
       date2 timestamp without time zone,
       strcol text,
       booleancol boolean,
       bytecol smallint,
       shortcol smallint,
       intcol integer,
       longcol bigint,
       floatcol real,
       doublecol double precision,
       blobcol bytea,
       stringarray text[],
       boolarray boolean[],
       bytearray smallint[],
       shortarray smallint[],
       integerarray integer[],
       longarray bigint[],
       floatarray real[],
       doublearray double precision[],
       timestamparray timestamp without time zone[]
) SERVER griddb_svr OPTIONS(table_name 's32');

--Test foreign table
--Testcase 15:
\d s3;
--Testcase 16:
SELECT * FROM s3 ORDER BY 1,2;

--
-- Test for non-unique functions of GridDB in WHERE clause
--
-- char_length
--Testcase 17:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE char_length(name) > 4  ORDER BY 1;
--Testcase 18:
SELECT * FROM s3 WHERE char_length(name) > 4  ORDER BY 1;
--Testcase 19:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE char_length(name) < 6  ORDER BY 1;
--Testcase 20:
SELECT * FROM s3 WHERE char_length(name) < 6  ORDER BY 1;

--Testcase 21:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE concat(name,' and george') = 'fred and george' ORDER BY 1;
--Testcase 22:
SELECT * FROM s3 WHERE concat(name,' and george') = 'fred and george' ORDER BY 1;

--substr
--Testcase 23:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE substr(name,2,3) = 'red' ORDER BY 1;
--Testcase 24:
SELECT * FROM s3 WHERE substr(name,2,3) = 'red' ORDER BY 1;
--Testcase 25:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE substr(name,1,3) <> 'fre' ORDER BY 1;
--Testcase 26:
SELECT * FROM s3 WHERE substr(name,1,3) <> 'fre' ORDER BY 1;

--upper
--Testcase 27:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE upper(name) = 'FRED' ORDER BY 1;
--Testcase 28:
SELECT * FROM s3 WHERE upper(name) = 'FRED' ORDER BY 1;
--Testcase 29:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE upper(name) <> 'FRED' ORDER BY 1;
--Testcase 30:
SELECT * FROM s3 WHERE upper(name) <> 'FRED' ORDER BY 1;

--lower
--Testcase 31:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE lower(name) = 'george' ORDER BY 1;
--Testcase 32:
SELECT * FROM s3 WHERE lower(name) = 'george' ORDER BY 1;
--Testcase 33:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE lower(name) <> 'bob' ORDER BY 1;
--Testcase 34:
SELECT * FROM s3 WHERE lower(name) <> 'bob' ORDER BY 1;

--round
--Testcase 35:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE round(gpa) > 3.5 ORDER BY 1;
--Testcase 36:
SELECT * FROM s3 WHERE round(gpa) > 3.5 ORDER BY 1;
--Testcase 37:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE round(gpa) <= 3 ORDER BY 1;
--Testcase 38:
SELECT * FROM s3 WHERE round(gpa) <= 3 ORDER BY 1;

--floor
--Testcase 39:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE floor(gpa) = 3 ORDER BY 1;
--Testcase 40:
SELECT * FROM s3 WHERE floor(gpa) = 3 ORDER BY 1;
--Testcase 41:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE floor(gpa) < 2 ORDER BY 1;
--Testcase 42:
SELECT * FROM s3 WHERE floor(gpa) < 3 ORDER BY 1;

--ceiling
--Testcase 43:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE ceiling(gpa) >= 3 ORDER BY 1;
--Testcase 44:
SELECT * FROM s3 WHERE ceiling(gpa) >= 3 ORDER BY 1;
--Testcase 45:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE ceiling(gpa) = 4 ORDER BY 1;
--Testcase 46:
SELECT * FROM s3 WHERE ceiling(gpa) = 4 ORDER BY 1;

--
--Test for unique functions of GridDB in WHERE clause: time functions
--
--griddb_timestamp: push down timestamp function to GridDB
--Testcase 47:
EXPLAIN VERBOSE
SELECT date, strcol, booleancol, bytecol, shortcol, intcol, longcol, floatcol, doublecol FROM s3 WHERE griddb_timestamp(strcol) > '2020-01-05 21:00:00' ORDER BY 1;
--Testcase 48:
SELECT date, strcol, booleancol, bytecol, shortcol, intcol, longcol, floatcol, doublecol FROM s3 WHERE griddb_timestamp(strcol) > '2020-01-05 21:00:00' ORDER BY 1;
--Testcase 49:
EXPLAIN VERBOSE
SELECT date, strcol FROM s3 WHERE date < griddb_timestamp(strcol) ORDER BY 1;
--Testcase 50:
SELECT date, strcol FROM s3 WHERE date < griddb_timestamp(strcol) ORDER BY 1;
--griddb_timestamp: push down timestamp function to GridDB and gets error because GridDB only support YYYY-MM-DDThh:mm:ss.SSSZ format for timestamp function
--UPDATE time_series2__griddb_svr__0 SET strcol = '2020-01-05 21:00:00';
--EXPLAIN VERBOSE
--SELECT date, strcol FROM time_series2 WHERE griddb_timestamp(strcol) = '2020-01-05 21:00:00';
--SELECT date, strcol FROM time_series2 WHERE griddb_timestamp(strcol) = '2020-01-05 21:00:00';

--timestampadd
--YEAR
--Testcase 51:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('YEAR', date1, -1) > '2019-12-29 05:00:00' ORDER BY 1;
--Testcase 52:
SELECT date1 FROM s3 WHERE timestampadd('YEAR', date1, -1) > '2019-12-29 05:00:00' ORDER BY 1;
--Testcase 53:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('YEAR', date1, 5) >= '2025-12-29 04:50:00' ORDER BY 1;
--Testcase 54:
SELECT date1 FROM s3 WHERE timestampadd('YEAR', date1, 5) >= '2025-12-29 04:50:00' ORDER BY 1;
--Testcase 55:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('YEAR', date1, 5) >= '2025-12-29' ORDER BY 1;
--Testcase 56:
SELECT date1 FROM s3 WHERE timestampadd('YEAR', date1, 5) >= '2025-12-29' ORDER BY 1;
--MONTH
--Testcase 57:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MONTH', date1, -3) > '2020-06-29 05:00:00' ORDER BY 1;
--Testcase 58:
SELECT date1 FROM s3 WHERE timestampadd('MONTH', date1, -3) > '2020-06-29 05:00:00' ORDER BY 1;
--Testcase 59:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MONTH', date1, 3) = '2021-03-29 05:00:30' ORDER BY 1;
--Testcase 60:
SELECT date1 FROM s3 WHERE timestampadd('MONTH', date1, 3) = '2021-03-29 05:00:30' ORDER BY 1;
--Testcase 61:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MONTH', date1, 3) >= '2021-03-29' ORDER BY 1;
--Testcase 62:
SELECT date1 FROM s3 WHERE timestampadd('MONTH', date1, 3) >= '2021-03-29' ORDER BY 1;
--DAY
--Testcase 63:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('DAY', date1, -3) > '2020-06-29 05:00:00' ORDER BY 1;
--Testcase 64:
SELECT date1 FROM s3 WHERE timestampadd('DAY', date1, -3) > '2020-06-29 05:00:00' ORDER BY 1;
--Testcase 65:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('DAY', date1, 3) = '2021-01-01 05:00:30' ORDER BY 1;
--Testcase 66:
SELECT date1 FROM s3 WHERE timestampadd('DAY', date1, 3) = '2021-01-01 05:00:30' ORDER BY 1;
--Testcase 67:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('DAY', date1, 3) >= '2021-01-01' ORDER BY 1;
--Testcase 68:
SELECT date1 FROM s3 WHERE timestampadd('DAY', date1, 3) >= '2021-01-01' ORDER BY 1;
--HOUR
--Testcase 69:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('HOUR', date1, -1) > '2020-12-29 04:00:00' ORDER BY 1;
--Testcase 70:
SELECT date1 FROM s3 WHERE timestampadd('HOUR', date1, -1) > '2020-12-29 04:00:00' ORDER BY 1;
--Testcase 71:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('HOUR', date1, 2) >= '2020-12-29 06:50:00' ORDER BY 1;
--Testcase 72:
SELECT date1 FROM s3 WHERE timestampadd('HOUR', date1, 2) >= '2020-12-29 06:50:00' ORDER BY 1;
--MINUTE
--Testcase 73:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MINUTE', date1, 20) = '2020-12-29 05:00:00' ORDER BY 1;
--Testcase 74:
SELECT date1 FROM s3 WHERE timestampadd('MINUTE', date1, 20) = '2020-12-29 05:00:00' ORDER BY 1;
--Testcase 75:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MINUTE', date1, -50) <= '2020-12-29 04:00:00' ORDER BY 1;
--Testcase 76:
SELECT date1 FROM s3 WHERE timestampadd('MINUTE', date1, -50) <= '2020-12-29 04:00:00' ORDER BY 1;
--SECOND
--Testcase 77:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('SECOND', date1, 25) >= '2020-12-29 04:40:30' ORDER BY 1;
--Testcase 78:
SELECT date1 FROM s3 WHERE timestampadd('SECOND', date1, 25) >= '2020-12-29 04:40:30' ORDER BY 1;
--Testcase 79:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('SECOND', date1, -50) <= '2020-12-29 04:00:00' ORDER BY 1;
--Testcase 80:
SELECT date1 FROM s3 WHERE timestampadd('SECOND', date1, -30) = '2020-12-29 05:00:00' ORDER BY 1;
--MILLISECOND
--Testcase 81:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MILLISECOND', date1, 300) = '2020-12-29 05:10:00.420' ORDER BY 1;
--Testcase 82:
SELECT date1 FROM s3 WHERE timestampadd('MILLISECOND', date1, 300) = '2020-12-29 05:10:00.420' ORDER BY 1;
--Testcase 83:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MILLISECOND', date1, -55) = '2020-12-29 05:10:00.065' ORDER BY 1;
--Testcase 84:
SELECT date1 FROM s3 WHERE timestampadd('MILLISECOND', date1, -55) = '2020-12-29 05:10:00.065' ORDER BY 1;
--Input wrong unit
--Testcase 85:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MICROSECOND', date1, -55) = '2020-12-29 05:10:00.065' ORDER BY 1;

--timestampdiff
--YEAR
--Testcase 86:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampdiff('YEAR', date1, '2018-01-04 08:48:00') > 0 ORDER BY 1;
--Testcase 87:
SELECT date1 FROM s3 WHERE timestampdiff('YEAR', date1, '2018-01-04 08:48:00') > 0 ORDER BY 1;
--Testcase 88:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('YEAR', '2015-07-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 89:
SELECT date2 FROM s3 WHERE timestampdiff('YEAR', '2015-07-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 90:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('YEAR', date1, date2) > 10 ORDER BY 1;
--Testcase 91:
SELECT date1, date2 FROM s3 WHERE timestampdiff('YEAR', date1, date2) > 10 ORDER BY 1;
--MONTH
--Testcase 92:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampdiff('MONTH', date1, '2020-11-04 08:48:00') = 1 ORDER BY 1;
--Testcase 93:
SELECT date1 FROM s3 WHERE timestampdiff('MONTH', date1, '2020-11-04 08:48:00') = 1 ORDER BY 1;
--Testcase 94:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('YEAR', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 95:
SELECT date2 FROM s3 WHERE timestampdiff('YEAR', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 96:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('MONTH', date1, date2) < 10 ORDER BY 1;
--Testcase 97:
SELECT date1, date2 FROM s3 WHERE timestampdiff('MONTH', date1, date2) < 10 ORDER BY 1;
--DAY
--Testcase 98:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('DAY', date2, '2020-12-04 08:48:00') > 20 ORDER BY 1;
--Testcase 99:
SELECT date2 FROM s3 WHERE timestampdiff('DAY', date2, '2020-12-04 08:48:00') > 20 ORDER BY 1;
--Testcase 100:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('DAY', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 101:
SELECT date2 FROM s3 WHERE timestampdiff('DAY', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 102:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('DAY', date1, date2) > 10 ORDER BY 1;
--Testcase 103:
SELECT date1, date2 FROM s3 WHERE timestampdiff('DAY', date1, date2) > 10 ORDER BY 1;
--HOUR
--Testcase 104:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampdiff('HOUR', date1, '2020-12-29 07:40:00') < 0 ORDER BY 1;
--Testcase 105:
SELECT date1 FROM s3 WHERE timestampdiff('HOUR', date1, '2020-12-29 07:40:00') < 0 ORDER BY 1;
--Testcase 106:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('HOUR', '2020-12-15 08:48:00', date2) > 3.5 ORDER BY 1;
--Testcase 107:
SELECT date2 FROM s3 WHERE timestampdiff('HOUR', '2020-12-15 08:48:00', date2) > 3.5 ORDER BY 1;
--Testcase 108:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('HOUR', date1, date2) > 10 ORDER BY 1;
--Testcase 109:
SELECT date1, date2 FROM s3 WHERE timestampdiff('HOUR', date1, date2) > 10 ORDER BY 1;
--MINUTE
--Testcase 110:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('MINUTE', date2, '2020-12-04 08:48:00') > 20 ORDER BY 1;
--Testcase 111:
SELECT date2 FROM s3 WHERE timestampdiff('MINUTE', date2, '2020-12-04 08:48:00') > 20 ORDER BY 1;
--Testcase 112:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('MINUTE', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 113:
SELECT date2 FROM s3 WHERE timestampdiff('MINUTE', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 114:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('MINUTE', date1, date2) > 10 ORDER BY 1;
--Testcase 115:
SELECT date1, date2 FROM s3 WHERE timestampdiff('MINUTE', date1, date2) > 10 ORDER BY 1;
--SECOND
--Testcase 116:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('SECOND', date2, '2020-12-04 08:48:00') > 1000 ORDER BY 1;
--Testcase 117:
SELECT date2 FROM s3 WHERE timestampdiff('SECOND', date2, '2020-12-04 08:48:00') > 1000 ORDER BY 1;
--Testcase 118:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('SECOND', '2020-03-17 04:50:00', date2) < 100 ORDER BY 1;
--Testcase 119:
SELECT date2 FROM s3 WHERE timestampdiff('SECOND', '2020-03-17 04:50:00', date2) < 100 ORDER BY 1;
--Testcase 120:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('SECOND', date1, date2) > 1600000 ORDER BY 1;
--Testcase 121:
SELECT date1, date2 FROM s3 WHERE timestampdiff('SECOND', date1, date2) > 1600000 ORDER BY 1;
--MILLISECOND
--Testcase 122:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('MILLISECOND', date2, '2020-12-04 08:48:00') > 200 ORDER BY 1;
--Testcase 123:
SELECT date2 FROM s3 WHERE timestampdiff('MILLISECOND', date2, '2020-12-04 08:48:00') > 200 ORDER BY 1;
--Testcase 124:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('MILLISECOND', '2020-03-17 08:48:00', date2) < 0 ORDER BY 1;
--Testcase 125:
SELECT date2 FROM s3 WHERE timestampdiff('MILLISECOND', '2020-03-17 08:48:00', date2) < 0 ORDER BY 1;
--Testcase 126:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('MILLISECOND', date1, date2) = -443 ORDER BY 1;
--Testcase 127:
SELECT date1, date2 FROM s3 WHERE timestampdiff('MILLISECOND', date1, date2) = -443 ORDER BY 1;
--Input wrong unit
--Testcase 128:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('MICROSECOND', date2, '2020-12-04 08:48:00') > 20 ORDER BY 1;
--Testcase 129:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('DECADE', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 130:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('NANOSECOND', date1, date2) > 10 ORDER BY 1;

--to_timestamp_ms
--Normal case
--Testcase 131:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE to_timestamp_ms(intcol) > '1970-01-01 1:00:00' ORDER BY 1;
--Testcase 132:
SELECT date1 FROM s3 WHERE to_timestamp_ms(intcol) > '1970-01-01 1:00:00' ORDER BY 1;
--Return error if column contains -1 value
--Testcase 133:
SELECT date1 FROM s3 WHERE to_timestamp_ms(intcol) > '1970-01-01 1:00:00' ORDER BY 1;

--to_epoch_ms
--Testcase 134:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE intcol < to_epoch_ms(date1) ORDER BY 1;
--Testcase 135:
SELECT date1 FROM s3 WHERE intcol < to_epoch_ms(date1) ORDER BY 1;
--Testcase 136:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE to_epoch_ms(date2) < 1000000000000 ORDER BY 1;

-- Test for now() pushdown function of griddb
-- griddb_now as parameter of timestampdiff()
--Testcase 137:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1;
--Testcase 138:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1;

--Testcase 139:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) > 0 ORDER BY 1;
--Testcase 140:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) > 0 ORDER BY 1;

--Testcase 141:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('HOUR', griddb_now(), '2020-12-04 08:48:00') > 0 ORDER BY 1;
--Testcase 142:
SELECT * FROM s3 WHERE timestampdiff('HOUR', griddb_now(), '2020-12-04 08:48:00') > 0 ORDER BY 1;

--Testcase 143:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', griddb_now(), '2032-12-04 08:48:00') < 0 ORDER BY 1;
--Testcase 144:
SELECT * FROM s3 WHERE timestampdiff('YEAR', griddb_now(), '2032-12-04 08:48:00') < 0 ORDER BY 1;

-- griddb_now as parameter of timestampadd()
--Testcase 145:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE date > timestampadd('YEAR', griddb_now(), -1) ORDER BY 1;
--Testcase 146:
SELECT * FROM s3 WHERE date > timestampadd('YEAR', griddb_now(), -1) ORDER BY 1;

--Testcase 147:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE date < timestampadd('YEAR', griddb_now(), -1) ORDER BY 1;
--Testcase 148:
SELECT * FROM s3 WHERE date < timestampadd('YEAR', griddb_now(), -1) ORDER BY 1;

-- griddb_now() in expression
--Testcase 149:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE date < griddb_now() ORDER BY 1;
--Testcase 150:
SELECT * FROM s3 WHERE date < griddb_now() ORDER BY 1;

--Testcase 151:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE date > griddb_now() ORDER BY 1;
--Testcase 152:
SELECT * FROM s3 WHERE date > griddb_now() ORDER BY 1;

--Testcase 153:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE date <= griddb_now() ORDER BY 1;
--Testcase 154:
SELECT * FROM s3 WHERE date <= griddb_now() ORDER BY 1;

-- griddb_now() to_epoch_ms()
--Testcase 155:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE to_epoch_ms(griddb_now()) > 0 ORDER BY 1;
--Testcase 156:
SELECT * FROM s3 WHERE to_epoch_ms(griddb_now()) > 0 ORDER BY 1;

-- griddb_now() other cases
--Testcase 157:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE griddb_now() IS NOT NULL ORDER BY 1;
--Testcase 158:
SELECT * FROM s3 WHERE griddb_now() IS NOT NULL ORDER BY 1;

--Testcase 159:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) > 0 OR timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1;
--Testcase 160:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) > 0 OR timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1;

--Testcase 161:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 ASC;
--Testcase 162:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 ASC;

--Testcase 163:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 DESC;
--Testcase 164:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 DESC;

--Testcase 165:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 ASC;
--Testcase 166:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 ASC;

--Testcase 167:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 DESC;
--Testcase 168:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 DESC;

--
--Test for unique functions of GridDB in WHERE clause: array functions
--
--array_length
--Testcase 169:
EXPLAIN VERBOSE
SELECT boolarray FROM s3 WHERE array_length(boolarray) = 3 ORDER BY 1;
--Testcase 170:
SELECT boolarray FROM s3 WHERE array_length(boolarray) = 3 ORDER BY 1;
--Testcase 171:
EXPLAIN VERBOSE
SELECT stringarray FROM s3 WHERE array_length(stringarray) = 3 ORDER BY 1;
--Testcase 172:
SELECT stringarray FROM s3 WHERE array_length(stringarray) = 3 ORDER BY 1;
--Testcase 173:
EXPLAIN VERBOSE
SELECT bytearray, shortarray FROM s3 WHERE array_length(bytearray) > array_length(shortarray) ORDER BY 1;
--Testcase 174:
SELECT bytearray, shortarray FROM s3 WHERE array_length(bytearray) > array_length(shortarray) ORDER BY 1;
--Testcase 175:
EXPLAIN VERBOSE
SELECT integerarray, longarray FROM s3 WHERE array_length(integerarray) = array_length(longarray) ORDER BY 1;
--Testcase 176:
SELECT integerarray, longarray FROM s3 WHERE array_length(integerarray) = array_length(longarray) ORDER BY 1;
--Testcase 177:
EXPLAIN VERBOSE
SELECT floatarray, doublearray FROM s3 WHERE array_length(floatarray) - array_length(doublearray) = 0 ORDER BY 1, 2;
--Testcase 178:
SELECT floatarray, doublearray FROM s3 WHERE array_length(floatarray) - array_length(doublearray) = 0 ORDER BY 1, 2;
--Testcase 179:
EXPLAIN VERBOSE
SELECT timestamparray FROM s3 WHERE array_length(timestamparray) < 3 ORDER BY 1;
--Testcase 180:
SELECT timestamparray FROM s3 WHERE array_length(timestamparray) < 3 ORDER BY 1;

--element
--Normal case
--Testcase 181:
EXPLAIN VERBOSE
SELECT boolarray FROM s3 WHERE element(1, boolarray) = 'f' ORDER BY 1;
--Testcase 182:
SELECT boolarray FROM s3 WHERE element(1, boolarray) = 'f' ORDER BY 1;
--Testcase 183:
EXPLAIN VERBOSE
SELECT stringarray FROM s3 WHERE element(1, stringarray) != 'bbb' ORDER BY 1;
--Testcase 184:
SELECT stringarray FROM s3 WHERE element(1, stringarray) != 'bbb' ORDER BY 1;
--Testcase 185:
EXPLAIN VERBOSE
SELECT bytearray, shortarray FROM s3 WHERE element(0, bytearray) = element(0, shortarray) ORDER BY 1;
--Testcase 186:
SELECT bytearray, shortarray FROM s3 WHERE element(0, bytearray) = element(0, shortarray) ORDER BY 1;
--Testcase 187:
EXPLAIN VERBOSE
SELECT integerarray, longarray FROM s3 WHERE element(0, integerarray)*100+44 = element(0,longarray) ORDER BY 1;
--Testcase 188:
SELECT integerarray, longarray FROM s3 WHERE element(0, integerarray)*100+44 = element(0,longarray) ORDER BY 1;
--Testcase 189:
EXPLAIN VERBOSE
SELECT floatarray, doublearray FROM s3 WHERE element(2, floatarray)*10 < element(0,doublearray) ORDER BY 1;
--Testcase 190:
SELECT floatarray, doublearray FROM s3 WHERE element(2, floatarray)*10 < element(0,doublearray) ORDER BY 1;
--Testcase 191:
EXPLAIN VERBOSE
SELECT timestamparray FROM s3 WHERE element(1,timestamparray) > '2020-12-29 04:00:00' ORDER BY 1;
--Testcase 192:
SELECT timestamparray FROM s3 WHERE element(1,timestamparray) > '2020-12-29 04:00:00' ORDER BY 1;
--Return error when getting non-existent element
--Testcase 193:
EXPLAIN VERBOSE
SELECT timestamparray FROM s3 WHERE element(2,timestamparray) > '2020-12-29 04:00:00' ORDER BY 1;
--Testcase 194:
SELECT timestamparray FROM s3 WHERE element(2,timestamparray) > '2020-12-29 04:00:00' ORDER BY 1;

--
--if user selects non-unique functions which Griddb only supports in WHERE clause => do not push down
--if user selects unique functions which Griddb only supports in WHERE clause => still push down, return error of Griddb
--
--Testcase 195:
EXPLAIN VERBOSE
SELECT char_length(name) FROM s3 ORDER BY 1;
--Testcase 196:
SELECT char_length(name) FROM s3 ORDER BY 1;
--Testcase 197:
EXPLAIN VERBOSE
SELECT concat(name,'abc') FROM s3 ORDER BY 1;
--Testcase 198:
SELECT concat(name,'abc') FROM s3 ORDER BY 1;
--Testcase 199:
EXPLAIN VERBOSE
SELECT substr(name,2,3) FROM s3 ORDER BY 1;
--Testcase 200:
SELECT substr(name,2,3) FROM s3 ORDER BY 1;
--Testcase 201:
EXPLAIN VERBOSE
SELECT element(1, timestamparray) FROM s3 ORDER BY 1;
--Testcase 202:
SELECT element(1, timestamparray) FROM s3 ORDER BY 1;
--Testcase 203:
EXPLAIN VERBOSE
SELECT upper(name) FROM s3 ORDER BY 1;
--Testcase 204:
SELECT upper(name) FROM s3 ORDER BY 1;
--Testcase 205:
EXPLAIN VERBOSE
SELECT lower(name) FROM s3 ORDER BY 1;
--Testcase 206:
SELECT lower(name) FROM s3 ORDER BY 1;
--Testcase 207:
EXPLAIN VERBOSE
SELECT round(gpa) FROM s3 ORDER BY 1;
--Testcase 208:
SELECT round(gpa) FROM s3 ORDER BY 1;
--Testcase 209:
EXPLAIN VERBOSE
SELECT floor(gpa) FROM s3 ORDER BY 1;
--Testcase 210:
SELECT floor(gpa) FROM s3 ORDER BY 1;
--Testcase 211:
EXPLAIN VERBOSE
SELECT ceiling(gpa) FROM s3 ORDER BY 1;
--Testcase 212:
SELECT ceiling(gpa) FROM s3 ORDER BY 1;
--Testcase 213:
EXPLAIN VERBOSE
SELECT griddb_timestamp(strcol) FROM s3 ORDER BY 1;
--Testcase 214:
SELECT griddb_timestamp(strcol) FROM s3 ORDER BY 1;
--Testcase 215:
EXPLAIN VERBOSE
SELECT timestampadd('YEAR', date1, -1) FROM s3 ORDER BY 1;
--Testcase 216:
SELECT timestampadd('YEAR', date1, -1) FROM s3 ORDER BY 1;
--Testcase 217:
EXPLAIN VERBOSE
SELECT timestampdiff('YEAR', date1, '2018-01-04 08:48:00') FROM s3 ORDER BY 1;
--Testcase 218:
SELECT timestampdiff('YEAR', date1, '2018-01-04 08:48:00') FROM s3 ORDER BY 1;
--Testcase 219:
EXPLAIN VERBOSE
SELECT to_timestamp_ms(intcol) FROM s3 ORDER BY 1;
--Testcase 220:
SELECT to_timestamp_ms(intcol) FROM s3 ORDER BY 1;
--Testcase 221:
EXPLAIN VERBOSE
SELECT to_epoch_ms(date1) FROM s3 ORDER BY 1;
--Testcase 222:
SELECT to_epoch_ms(date1) FROM s3 ORDER BY 1;
--Testcase 223:
EXPLAIN VERBOSE
SELECT array_length(boolarray) FROM s3 ORDER BY 1;
--Testcase 224:
SELECT array_length(boolarray) FROM s3 ORDER BY 1;
--Testcase 225:
EXPLAIN VERBOSE
SELECT element(1, stringarray) FROM s3 ORDER BY 1;
--Testcase 226:
SELECT element(1, stringarray) FROM s3 ORDER BY 1;

--
--Test for unique functions of GridDB in SELECT clause: time-series functions
--
--time_next
--specified time exist => return that row
--Testcase 227:
EXPLAIN VERBOSE
SELECT time_next('2018-12-01 10:00:00') FROM s3 ORDER BY 1;
--Testcase 228:
SELECT time_next('2018-12-01 10:00:00') FROM s3 ORDER BY 1;
--specified time does not exist => return the row whose time  is immediately after the specified time
--Testcase 229:
EXPLAIN VERBOSE
SELECT time_next('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--Testcase 230:
SELECT time_next('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--specified time does not exist, there is no time after the specified time => return no row
--Testcase 231:
EXPLAIN VERBOSE
SELECT time_next('2018-12-01 10:45:00') FROM s3 ORDER BY 1;
--Testcase 232:
SELECT time_next('2018-12-01 10:45:00') FROM s3 ORDER BY 1;

--time_next_only
--even though specified time exist, still return the row whose time is immediately after the specified time
--Testcase 233:
EXPLAIN VERBOSE
SELECT time_next_only('2018-12-01 10:00:00') FROM s3 ORDER BY 1;
--Testcase 234:
SELECT time_next_only('2018-12-01 10:00:00') FROM s3 ORDER BY 1;
--specified time does not exist => return the row whose time  is immediately after the specified time
--Testcase 235:
EXPLAIN VERBOSE
SELECT time_next_only('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--Testcase 236:
SELECT time_next_only('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--there is no time after the specified time => return no row
--Testcase 237:
EXPLAIN VERBOSE
SELECT time_next_only('2018-12-01 10:45:00') FROM s3 ORDER BY 1;
--Testcase 238:
SELECT time_next_only('2018-12-01 10:45:00') FROM s3 ORDER BY 1;

--time_prev
--specified time exist => return that row
--Testcase 239:
EXPLAIN VERBOSE
SELECT time_prev('2018-12-01 10:10:00') FROM s3 ORDER BY 1;
--Testcase 240:
SELECT time_prev('2018-12-01 10:10:00') FROM s3 ORDER BY 1;
--specified time does not exist => return the row whose time  is immediately before the specified time
--Testcase 241:
EXPLAIN VERBOSE
SELECT time_prev('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--Testcase 242:
SELECT time_prev('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--specified time does not exist, there is no time before the specified time => return no row
--Testcase 243:
EXPLAIN VERBOSE
SELECT time_prev('2018-12-01 09:45:00') FROM s3 ORDER BY 1;
--Testcase 244:
SELECT time_prev('2018-12-01 09:45:00') FROM s3 ORDER BY 1;

--time_prev_only
--even though specified time exist, still return the row whose time is immediately before the specified time
--Testcase 245:
EXPLAIN VERBOSE
SELECT time_prev_only('2018-12-01 10:10:00') FROM s3 ORDER BY 1;
--Testcase 246:
SELECT time_prev_only('2018-12-01 10:10:00') FROM s3 ORDER BY 1;
--specified time does not exist => return the row whose time  is immediately before the specified time
--Testcase 247:
EXPLAIN VERBOSE
SELECT time_prev_only('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--Testcase 248:
SELECT time_prev_only('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--there is no time before the specified time => return no row
--Testcase 249:
EXPLAIN VERBOSE
SELECT time_prev_only('2018-12-01 09:45:00') FROM s3 ORDER BY 1;
--Testcase 250:
SELECT time_prev_only('2018-12-01 09:45:00') FROM s3 ORDER BY 1;

--time_interpolated
--specified time exist => return that row
--Testcase 251:
EXPLAIN VERBOSE
SELECT time_interpolated(value1, '2018-12-01 10:10:00') FROM s3 ORDER BY 1;
--Testcase 252:
SELECT time_interpolated(value1, '2018-12-01 10:10:00') FROM s3 ORDER BY 1;
--specified time does not exist => return the row which has interpolated value.
--The column which is specified as the 1st parameter will be calculated by linearly interpolating the value of the previous and next rows.
--Other values will be equal to the values of rows previous to the specified time.
--Testcase 253:
EXPLAIN VERBOSE
SELECT time_interpolated(value1, '2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--Testcase 254:
SELECT time_interpolated(value1, '2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--specified time does not exist. There is no row before or after the specified time => can not calculate interpolated value, return no row.
--Testcase 255:
EXPLAIN VERBOSE
SELECT time_interpolated(value1, '2018-12-01 09:05:00') FROM s3 ORDER BY 1;
--Testcase 256:
SELECT time_interpolated(value1, '2018-12-01 09:05:00') FROM s3 ORDER BY 1;
--Testcase 257:
EXPLAIN VERBOSE
SELECT time_interpolated(value1, '2018-12-01 10:45:00') FROM s3 ORDER BY 1;
--Testcase 258:
SELECT time_interpolated(value1, '2018-12-01 10:45:00') FROM s3 ORDER BY 1;

--time_sampling by MINUTE
--rows for sampling exists => return those rows
--Testcase 259:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:20:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--Testcase 260:
SELECT time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:20:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--rows for sampling does not exist => return rows that contains interpolated values.
--The column which is specified as the 1st parameter will be calculated by linearly interpolating the value of the previous and next rows.
--Other values will be equal to the values of rows previous to the specified time.
--Testcase 261:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-01 10:05:00', '2018-12-01 10:35:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--Testcase 262:
SELECT time_sampling(value1, '2018-12-01 10:05:00', '2018-12-01 10:35:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--mix exist and non-exist sampling
--Testcase 263:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:40:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--Testcase 264:
SELECT time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:40:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--In linearly interpolating the value of the previous and next rows, if one of the values does not exist => the sampling row will not be returned
--Testcase 265:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-01 09:30:00', '2018-12-01 11:00:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--Testcase 266:
SELECT time_sampling(value1, '2018-12-01 09:30:00', '2018-12-01 11:00:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--if the first parameter is not set, * will be added as the first parameter.
--When specified time does not exist, all columns (except timestamp key column) will be equal to the values of rows previous to the specified time.
--UPDATE time_series__griddb_svr__0 SET value1 = 5 where date = '2018-12-01 10:40:00';
--EXPLAIN VERBOSE
--SELECT time_sampling('2018-12-01 10:00:00', '2018-12-01 10:40:00', 10, 'MINUTE') FROM s3;
--SELECT time_sampling('2018-12-01 10:00:00', '2018-12-01 10:40:00', 10, 'MINUTE') FROM s3;

--time_sampling by HOUR
--rows for sampling exists => return those rows
--Testcase 267:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-02 10:00:00', '2018-12-02 12:00:00', 2, 'HOUR') FROM s3 ORDER BY 1;
--Testcase 268:
SELECT time_sampling(value1, '2018-12-02 10:00:00', '2018-12-02 12:00:00', 2, 'HOUR') FROM s3 ORDER BY 1;
--rows for sampling does not exist => return rows that contains interpolated values.
--The column which is specified as the 1st parameter will be calculated by linearly interpolating the value of the previous and next rows.
--Other values will be equal to the values of rows previous to the specified time.
--Testcase 269:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-02 10:05:00', '2018-12-02 21:00:00', 3, 'HOUR') FROM s3 ORDER BY 1;
--Testcase 270:
SELECT time_sampling(value1, '2018-12-02 10:05:00', '2018-12-02 21:00:00', 3, 'HOUR') FROM s3 ORDER BY 1;
--mix exist and non-exist sampling
--Testcase 271:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-02 10:00:00', '2018-12-02 21:40:00', 2, 'HOUR') FROM s3 ORDER BY 1;
--Testcase 272:
SELECT time_sampling(value1, '2018-12-02 10:00:00', '2018-12-02 21:40:00', 2, 'HOUR') FROM s3 ORDER BY 1;
--In linearly interpolating the value of the previous and next rows, if one of the values does not exist => the sampling row will not be returned
--Testcase 273:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-02 6:00:00', '2018-12-02 23:00:00', 3, 'HOUR') FROM s3 ORDER BY 1;
--Testcase 274:
SELECT time_sampling(value1, '2018-12-02 6:00:00', '2018-12-02 23:00:00', 3, 'HOUR') FROM s3 ORDER BY 1;
--if the first parameter is not set, * will be added as the first parameter.
--When specified time does not exist, all columns (except timestamp key column) will be equal to the values of rows previous to the specified time.
--DELETE FROM time_series__griddb_svr__0 WHERE value1 = 4;
--EXPLAIN VERBOSE
--SELECT time_sampling('2018-12-02 10:00:00', '2018-12-02 21:40:00', 2, 'HOUR') FROM s3;
--SELECT time_sampling('2018-12-02 10:00:00', '2018-12-02 21:40:00', 2, 'HOUR') FROM s3;

--time_sampling by DAY
--rows for sampling exists => return those rows
--Testcase 275:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-03 11:00:00', '2018-12-04 11:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--Testcase 276:
SELECT time_sampling(value1, '2018-12-03 11:00:00', '2018-12-04 11:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--rows for sampling does not exist => return rows that contains interpolated values.
--The column which is specified as the 1st parameter will be calculated by linearly interpolating the value of the previous and next rows.
--Other values will be equal to the values of rows previous to the specified time.
--Testcase 277:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-03 09:00:00', '2018-12-05 12:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--Testcase 278:
SELECT time_sampling(value1, '2018-12-03 09:00:00', '2018-12-05 12:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--mix exist and non-exist sampling
--Testcase 279:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-03 11:00:00', '2018-12-05 12:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--Testcase 280:
SELECT time_sampling(value1, '2018-12-03 11:00:00', '2018-12-05 12:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--In linearly interpolating the value of the previous and next rows, if one of the values does not exist => the sampling row will not be returned
--Testcase 281:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-03 09:30:00', '2018-12-03 11:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--Testcase 282:
SELECT time_sampling(value1, '2018-12-03 09:30:00', '2018-12-03 11:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--if the first parameter is not set, * will be added as the first parameter.
--When specified time does not exist, all columns (except timestamp key column) will be equal to the values of rows previous to the specified time.
--DELETE FROM time_series__griddb_svr__0 WHERE value1 = 6;
--EXPLAIN VERBOSE
--SELECT time_sampling(value1, '2018-12-01 11:00:00', '2018-12-03 12:00:00', 1, 'DAY') FROM s3;
--Testcase 283:
SELECT time_sampling(value1, '2018-12-03 11:00:00', '2018-12-03 12:00:00', 1, 'DAY') FROM s3 ORDER BY 1;

--time_sampling by SECOND
--rows for sampling exists => return those rows
--Testcase 284:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-06 10:00:00', '2018-12-06 10:00:20', 10, 'SECOND') FROM s3 ORDER BY 1;
--Testcase 285:
SELECT time_sampling(value1, '2018-12-06 10:00:00', '2018-12-06 10:00:20', 10, 'SECOND') FROM s3 ORDER BY 1;
--rows for sampling does not exist => return rows that contains interpolated values.
--The column which is specified as the 1st parameter will be calculated by linearly interpolating the value of the previous and next rows.
--Other values will be equal to the values of rows previous to the specified time.
--Testcase 286:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-06 10:00:03', '2018-12-06 10:00:35', 15, 'SECOND') FROM s3 ORDER BY 1;
--Testcase 287:
SELECT time_sampling(value1, '2018-12-06 10:00:03', '2018-12-06 10:00:35', 15, 'SECOND') FROM s3 ORDER BY 1;
--mix exist and non-exist sampling
--Testcase 288:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-06 10:00:00', '2018-12-06 11:00:00', 10, 'SECOND') FROM s3 ORDER BY 1;
--Testcase 289:
SELECT time_sampling(value1, '2018-12-06 10:00:00', '2018-12-06 11:00:00', 10, 'SECOND') FROM s3 ORDER BY 1;
--In linearly interpolating the value of the previous and next rows, if one of the values does not exist => the sampling row will not be returned
--Testcase 290:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-06 08:30:00', '2018-12-06 11:00:00', 20, 'SECOND') FROM s3 ORDER BY 1;
--Testcase 291:
SELECT time_sampling(value1, '2018-12-06 08:30:00', '2018-12-06 11:00:00', 20, 'SECOND') FROM s3 ORDER BY 1;
--if the first parameter is not set, * will be added as the first parameter.
--When specified time does not exist, all columns (except timestamp key column) will be equal to the values of rows previous to the specified time.
--DELETE FROM time_series__griddb_svr__0 WHERE value1 = 4;

--EXPLAIN VERBOSE
--SELECT time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 11:00:00', 10, 'SECOND') FROM time_series;
--SELECT time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 11:00:00', 10, 'SECOND') FROM time_series;

--time_sampling by MILLISECOND
--rows for sampling exists => return those rows
--Testcase 292:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-07 10:00:00.100', '2018-12-07 10:00:00.140', 20, 'MILLISECOND') FROM s3 ORDER BY 1;
--Testcase 293:
SELECT time_sampling(value1, '2018-12-07 10:00:00.100', '2018-12-07 10:00:00.140', 20, 'MILLISECOND') FROM s3 ORDER BY 1;
--rows for sampling does not exist => return rows that contains interpolated values.
--The column which is specified as the 1st parameter will be calculated by linearly interpolating the value of the previous and next rows.
--Other values will be equal to the values of rows previous to the specified time.
--Testcase 294:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-07 10:00:00.115', '2018-12-07 10:00:00.155', 15, 'MILLISECOND') FROM s3 ORDER BY 1;
--Testcase 295:
SELECT time_sampling(value1, '2018-12-07 10:00:00.115', '2018-12-07 10:00:00.155', 15, 'MILLISECOND') FROM s3 ORDER BY 1;
--mix exist and non-exist sampling
--Testcase 296:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-07 10:00:00.100', '2018-12-07 10:00:00.150', 5, 'MILLISECOND') FROM s3 ORDER BY 1;
--Testcase 297:
SELECT time_sampling(value1, '2018-12-07 10:00:00.100', '2018-12-07 10:00:00.150', 5, 'MILLISECOND') FROM s3 ORDER BY 1;
--In linearly interpolating the value of the previous and next rows, if one of the values does not exist => the sampling row will not be returned
--Testcase 298:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-07 10:00:00.002', '2018-12-07 10:00:00.500', 20, 'MILLISECOND') FROM s3 ORDER BY 1;
--Testcase 299:
SELECT time_sampling(value1, '2018-12-07 10:00:00.002', '2018-12-07 10:00:00.500', 20, 'MILLISECOND') FROM s3 ORDER BY 1;
--if the first parameter is not set, * will be added as the first parameter.
--When specified time does not exist, all columns (except timestamp key column) will be equal to the values of rows previous to the specified time.
--DELETE FROM time_series__griddb_svr__0 WHERE value1 = 4;
--EXPLAIN VERBOSE
--SELECT time_sampling(value1, '2018-12-01 10:00:00.100', '2018-12-01 10:00:00.150', 5, 'MILLISECOND') FROM time_series;
--SELECT time_sampling(value1, '2018-12-01 10:00:00.100', '2018-12-01 10:00:00.150', 5, 'MILLISECOND') FROM time_series;

--max_rows
--Testcase 300:
EXPLAIN VERBOSE
SELECT max_rows(value2) FROM s3 ORDER BY 1;
--Testcase 301:
SELECT max_rows(value2) FROM s3 ORDER BY 1;
--Testcase 302:
EXPLAIN VERBOSE
SELECT max_rows(date) FROM s3 ORDER BY 1;
--Testcase 303:
SELECT max_rows(date) FROM s3 ORDER BY 1;

--min_rows
--Testcase 304:
EXPLAIN VERBOSE
SELECT min_rows(value2) FROM s3 ORDER BY 1;
--Testcase 305:
SELECT min_rows(value2) FROM s3 ORDER BY 1;
--Testcase 306:
EXPLAIN VERBOSE
SELECT min_rows(date) FROM s3 ORDER BY 1;
--Testcase 307:
SELECT min_rows(date) FROM s3 ORDER BY 1;

--
--if WHERE clause contains functions which Griddb only supports in SELECT clause => still push down, return error of Griddb
--
--Testcase 308:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE time_next('2018-12-01 10:00:00') = '"2020-01-05 21:00:00,{t,f,t}"' ORDER BY 1;
--Testcase 309:
SELECT * FROM s3 WHERE time_next('2018-12-01 10:00:00') = '"2020-01-05 21:00:00,{t,f,t}"' ORDER BY 1;
--Testcase 310:
EXPLAIN VERBOSE
SELECT date FROM s3 WHERE time_next_only('2018-12-01 10:00:00') = time_interpolated(value1, '2018-12-01 10:10:00') ORDER BY 1;
--Testcase 311:
SELECT date FROM s3 WHERE time_next_only('2018-12-01 10:00:00') = time_interpolated(value1, '2018-12-01 10:10:00') ORDER BY 1;
--Testcase 312:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE time_prev('2018-12-01 10:00:00') = '"2020-01-05 21:00:00,{t,f,t}"' ORDER BY 1;
--Testcase 313:
SELECT * FROM s3 WHERE time_prev('2018-12-01 10:00:00') = '"2020-01-05 21:00:00,{t,f,t}"' ORDER BY 1;
--Testcase 314:
EXPLAIN VERBOSE
SELECT date FROM s3 WHERE time_prev_only('2018-12-01 10:00:00') = time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:40:00', 10, 'MINUTE') ORDER BY 1;
--Testcase 315:
SELECT date FROM s3 WHERE time_prev_only('2018-12-01 10:00:00') = time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:40:00', 10, 'MINUTE') ORDER BY 1;
--Testcase 316:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE max_rows(date) = min_rows(value2) ORDER BY 1;
--Testcase 317:
SELECT * FROM s3 WHERE max_rows(date) = min_rows(value2) ORDER BY 1;

--
-- Test syntax (xxx()::s3).*
--
--Testcase 318:
EXPLAIN VERBOSE
SELECT (time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:50:00', 20, 'MINUTE')::s3).* FROM s3 ORDER BY 1;
--Testcase 319:
SELECT (time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:50:00', 20, 'MINUTE')::s3).* FROM s3 ORDER BY 1;
--Testcase 320:
EXPLAIN VERBOSE
SELECT (time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:50:00', 20, 'MINUTE')::s3).date FROM s3 ORDER BY 1;
--Testcase 321:
SELECT (time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:50:00', 20, 'MINUTE')::s3).date FROM s3 ORDER BY 1;
--Testcase 322:
EXPLAIN VERBOSE
SELECT (time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:50:00', 20, 'MINUTE')::s3).value1 FROM s3 ORDER BY 1;
--Testcase 323:
SELECT (time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:50:00', 20, 'MINUTE')::s3).value1 FROM s3 ORDER BY 1;

--
-- Test aggregate function time_avg
--
--Testcase 324:
EXPLAIN VERBOSE
SELECT time_avg(value1) FROM s3 ORDER BY 1;
--Testcase 325:
SELECT time_avg(value1) FROM s3 ORDER BY 1;
--Testcase 326:
EXPLAIN VERBOSE
SELECT time_avg(value2) FROM s3 ORDER BY 1;
--Testcase 327:
SELECT time_avg(value2) FROM s3 ORDER BY 1;
-- GridDB does not support select multiple target in a query => do not push down, raise stub function error
--Testcase 328:
EXPLAIN VERBOSE
SELECT time_avg(value1), time_avg(value2) FROM s3 ORDER BY 1;
--SELECT time_avg(value1), time_avg(value2) FROM s3 ORDER BY 1;
-- Do not push down when expected type is not correct, raise stub function error
--Testcase 329:
EXPLAIN VERBOSE
SELECT time_avg(date) FROM s3 ORDER BY 1;
--SELECT time_avg(date) FROM s3 ORDER BY 1;
--Testcase 330:
EXPLAIN VERBOSE
SELECT time_avg(blobcol) FROM s3 ORDER BY 1;
--SELECT time_avg(blobcol) FROM s3 ORDER BY 1;

--
-- Test aggregate function min, max, count, sum, avg, variance, stddev
--
--Testcase 331:
EXPLAIN VERBOSE
SELECT min(age) FROM s3 ORDER BY 1;
--Testcase 332:
SELECT min(age) FROM s3 ORDER BY 1;

--Testcase 333:
EXPLAIN VERBOSE
SELECT max(gpa) FROM s3 ORDER BY 1;
--Testcase 334:
SELECT max(gpa) FROM s3 ORDER BY 1;

--Testcase 335:
EXPLAIN VERBOSE
SELECT count(*) FROM s3 ORDER BY 1;
--Testcase 336:
SELECT count(*) FROM s3 ORDER BY 1;
--Testcase 337:
EXPLAIN VERBOSE
SELECT count(*) FROM s3 WHERE gpa < 3.5 OR age < 42 ORDER BY 1;
--Testcase 338:
SELECT count(*) FROM s3 WHERE gpa < 3.5 OR age < 42 ORDER BY 1;

--Testcase 339:
EXPLAIN VERBOSE
SELECT sum(age) FROM s3 ORDER BY 1;
--Testcase 340:
SELECT sum(age) FROM s3 ORDER BY 1;
--Testcase 341:
EXPLAIN VERBOSE
SELECT sum(age) FROM s3 WHERE round(gpa) > 3.5 ORDER BY 1;
--Testcase 342:
SELECT sum(age) FROM s3 WHERE round(gpa) > 3.5 ORDER BY 1;

--Testcase 343:
EXPLAIN VERBOSE
SELECT avg(gpa) FROM s3 ORDER BY 1;
--Testcase 344:
SELECT avg(gpa) FROM s3 ORDER BY 1;
--Testcase 345:
EXPLAIN VERBOSE
SELECT avg(gpa) FROM s3 WHERE lower(name) = 'george' ORDER BY 1;
--Testcase 346:
SELECT avg(gpa) FROM s3 WHERE lower(name) = 'george' ORDER BY 1;

--Testcase 347:
EXPLAIN VERBOSE
SELECT variance(gpa) FROM s3 ORDER BY 1;
--Testcase 348:
SELECT variance(gpa) FROM s3 ORDER BY 1;
--Testcase 349:
EXPLAIN VERBOSE
SELECT variance(gpa) FROM s3 WHERE gpa > 3.5 ORDER BY 1;
--Testcase 350:
SELECT variance(gpa) FROM s3 WHERE gpa > 3.5 ORDER BY 1;

--Testcase 351:
EXPLAIN VERBOSE
SELECT stddev(age) FROM s3 ORDER BY 1;
--Testcase 352:
SELECT stddev(age) FROM s3 ORDER BY 1;
--Testcase 353:
EXPLAIN VERBOSE
SELECT stddev(age) FROM s3 WHERE char_length(name) > 4 ORDER BY 1;
--Testcase 354:
SELECT stddev(age) FROM s3 WHERE char_length(name) > 4 ORDER BY 1;

--Testcase 355:
EXPLAIN VERBOSE
SELECT max(gpa), min(age) FROM s3 ORDER BY 1;
--Testcase 356:
SELECT max(gpa), min(age) FROM s3 ORDER BY 1;

--Drop all foreign tables
--Testcase 357:
DROP FOREIGN TABLE s3__griddb_svr__0;
--Testcase 358:
DROP USER MAPPING FOR public SERVER griddb_svr;
--Testcase 359:
DROP SERVER griddb_svr;
--Testcase 360:
DROP EXTENSION griddb_fdw;

--Testcase 361:
DROP FOREIGN TABLE s3__pgspider_svr__0;
--Testcase 362:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_svr;
--Testcase 363:
DROP SERVER pgspider_svr;
--Testcase 364:
DROP EXTENSION pgspider_fdw;

--Testcase 365:
DROP FOREIGN TABLE s3;
--Testcase 366:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_core_svr;
--Testcase 367:
DROP SERVER pgspider_core_svr;
--Testcase 368:
DROP EXTENSION pgspider_core_fdw;
