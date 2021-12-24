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
--                    +-> Child PGSpider Node -> Data source
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
CREATE SERVER pgspider_svr1 FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (host '127.0.0.1', port '5433', dbname 'postgres');
--Testcase 9:
CREATE USER MAPPING FOR CURRENT_USER SERVER pgspider_svr1;
--Testcase 10:
CREATE FOREIGN TABLE s3__pgspider_svr1__0 (
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
) SERVER pgspider_svr1 OPTIONS(table_name 's31griddb');

--Testcase 11:
CREATE SERVER pgspider_svr2 FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (host '127.0.0.1', port '5434', dbname 'postgres');
--Testcase 12:
CREATE USER MAPPING FOR CURRENT_USER SERVER pgspider_svr2;
--Testcase 13:
CREATE FOREIGN TABLE s3__pgspider_svr2__0 (
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
) SERVER pgspider_svr2 OPTIONS(table_name 's32griddb');

--Test foreign table
--Testcase 14:
\d s3;
--Testcase 15:
SELECT * FROM s3 ORDER BY 1,2;

--
-- Test for non-unique functions of GridDB in WHERE clause
--
-- char_length
--Testcase 16:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE char_length(name) > 4 ORDER BY 1;
--Testcase 17:
SELECT * FROM s3 WHERE char_length(name) > 4 ORDER BY 1;
--Testcase 18:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE char_length(name) < 6 ORDER BY 1;
--Testcase 19:
SELECT * FROM s3 WHERE char_length(name) < 6 ORDER BY 1;

--Testcase 20:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE concat(name,' and george') = 'fred and george' ORDER BY 1;
--Testcase 21:
SELECT * FROM s3 WHERE concat(name,' and george') = 'fred and george' ORDER BY 1;

--substr
--Testcase 22:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE substr(name,2,3) = 'red' ORDER BY 1;
--Testcase 23:
SELECT * FROM s3 WHERE substr(name,2,3) = 'red' ORDER BY 1;
--Testcase 24:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE substr(name,1,3) <> 'fre' ORDER BY 1;
--Testcase 25:
SELECT * FROM s3 WHERE substr(name,1,3) <> 'fre' ORDER BY 1;

--upper
--Testcase 26:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE upper(name) = 'FRED' ORDER BY 1;
--Testcase 27:
SELECT * FROM s3 WHERE upper(name) = 'FRED' ORDER BY 1;
--Testcase 28:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE upper(name) <> 'FRED' ORDER BY 1;
--Testcase 29:
SELECT * FROM s3 WHERE upper(name) <> 'FRED' ORDER BY 1;

--lower
--Testcase 30:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE lower(name) = 'george' ORDER BY 1;
--Testcase 31:
SELECT * FROM s3 WHERE lower(name) = 'george' ORDER BY 1;
--Testcase 32:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE lower(name) <> 'bob' ORDER BY 1;
--Testcase 33:
SELECT * FROM s3 WHERE lower(name) <> 'bob' ORDER BY 1;

--round
--Testcase 34:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE round(gpa) > 3.5 ORDER BY 1;
--Testcase 35:
SELECT * FROM s3 WHERE round(gpa) > 3.5 ORDER BY 1;
--Testcase 36:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE round(gpa) <= 3 ORDER BY 1;
--Testcase 37:
SELECT * FROM s3 WHERE round(gpa) <= 3 ORDER BY 1;

--floor
--Testcase 38:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE floor(gpa) = 3 ORDER BY 1;
--Testcase 39:
SELECT * FROM s3 WHERE floor(gpa) = 3 ORDER BY 1;
--Testcase 40:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE floor(gpa) < 2 ORDER BY 1;
--Testcase 41:
SELECT * FROM s3 WHERE floor(gpa) < 3 ORDER BY 1;

--ceiling
--Testcase 42:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE ceiling(gpa) >= 3 ORDER BY 1;
--Testcase 43:
SELECT * FROM s3 WHERE ceiling(gpa) >= 3 ORDER BY 1;
--Testcase 44:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE ceiling(gpa) = 4 ORDER BY 1;
--Testcase 45:
SELECT * FROM s3 WHERE ceiling(gpa) = 4 ORDER BY 1;

--
--Test for unique functions of GridDB in WHERE clause: time functions
--
--griddb_timestamp: push down timestamp function to GridDB
--Testcase 46:
EXPLAIN VERBOSE
SELECT date, strcol, booleancol, bytecol, shortcol, intcol, longcol, floatcol, doublecol FROM s3 WHERE griddb_timestamp(strcol) > '2020-01-05 21:00:00' ORDER BY 1;
--Testcase 47:
SELECT date, strcol, booleancol, bytecol, shortcol, intcol, longcol, floatcol, doublecol FROM s3 WHERE griddb_timestamp(strcol) > '2020-01-05 21:00:00' ORDER BY 1;
--Testcase 48:
EXPLAIN VERBOSE
SELECT date, strcol FROM s3 WHERE date < griddb_timestamp(strcol) ORDER BY 1;
--Testcase 49:
SELECT date, strcol FROM s3 WHERE date < griddb_timestamp(strcol) ORDER BY 1;
--griddb_timestamp: push down timestamp function to GridDB and gets error because GridDB only support YYYY-MM-DDThh:mm:ss.SSSZ format for timestamp function
--UPDATE time_series2__griddb_svr__0 SET strcol = '2020-01-05 21:00:00';
--EXPLAIN VERBOSE
--SELECT date, strcol FROM time_series2 WHERE griddb_timestamp(strcol) = '2020-01-05 21:00:00';
--SELECT date, strcol FROM time_series2 WHERE griddb_timestamp(strcol) = '2020-01-05 21:00:00';

--timestampadd
--YEAR
--Testcase 50:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('YEAR', date1, -1) > '2019-12-29 05:00:00' ORDER BY 1;
--Testcase 51:
SELECT date1 FROM s3 WHERE timestampadd('YEAR', date1, -1) > '2019-12-29 05:00:00' ORDER BY 1;
--Testcase 52:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('YEAR', date1, 5) >= '2025-12-29 04:50:00' ORDER BY 1;
--Testcase 53:
SELECT date1 FROM s3 WHERE timestampadd('YEAR', date1, 5) >= '2025-12-29 04:50:00' ORDER BY 1;
--Testcase 54:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('YEAR', date1, 5) >= '2025-12-29' ORDER BY 1;
--Testcase 55:
SELECT date1 FROM s3 WHERE timestampadd('YEAR', date1, 5) >= '2025-12-29' ORDER BY 1;
--MONTH
--Testcase 56:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MONTH', date1, -3) > '2020-06-29 05:00:00' ORDER BY 1;
--Testcase 57:
SELECT date1 FROM s3 WHERE timestampadd('MONTH', date1, -3) > '2020-06-29 05:00:00' ORDER BY 1;
--Testcase 58:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MONTH', date1, 3) = '2021-03-29 05:00:30' ORDER BY 1;
--Testcase 59:
SELECT date1 FROM s3 WHERE timestampadd('MONTH', date1, 3) = '2021-03-29 05:00:30' ORDER BY 1;
--Testcase 60:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MONTH', date1, 3) >= '2021-03-29' ORDER BY 1;
--Testcase 61:
SELECT date1 FROM s3 WHERE timestampadd('MONTH', date1, 3) >= '2021-03-29' ORDER BY 1;
--DAY
--Testcase 62:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('DAY', date1, -3) > '2020-06-29 05:00:00' ORDER BY 1;
--Testcase 63:
SELECT date1 FROM s3 WHERE timestampadd('DAY', date1, -3) > '2020-06-29 05:00:00' ORDER BY 1;
--Testcase 64:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('DAY', date1, 3) = '2021-01-01 05:00:30' ORDER BY 1;
--Testcase 65:
SELECT date1 FROM s3 WHERE timestampadd('DAY', date1, 3) = '2021-01-01 05:00:30' ORDER BY 1;
--Testcase 66:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('DAY', date1, 3) >= '2021-01-01' ORDER BY 1;
--Testcase 67:
SELECT date1 FROM s3 WHERE timestampadd('DAY', date1, 3) >= '2021-01-01' ORDER BY 1;
--HOUR
--Testcase 68:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('HOUR', date1, -1) > '2020-12-29 04:00:00' ORDER BY 1;
--Testcase 69:
SELECT date1 FROM s3 WHERE timestampadd('HOUR', date1, -1) > '2020-12-29 04:00:00' ORDER BY 1;
--Testcase 70:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('HOUR', date1, 2) >= '2020-12-29 06:50:00' ORDER BY 1;
--Testcase 71:
SELECT date1 FROM s3 WHERE timestampadd('HOUR', date1, 2) >= '2020-12-29 06:50:00' ORDER BY 1;
--MINUTE
--Testcase 72:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MINUTE', date1, 20) = '2020-12-29 05:00:00' ORDER BY 1;
--Testcase 73:
SELECT date1 FROM s3 WHERE timestampadd('MINUTE', date1, 20) = '2020-12-29 05:00:00' ORDER BY 1;
--Testcase 74:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MINUTE', date1, -50) <= '2020-12-29 04:00:00' ORDER BY 1;
--Testcase 75:
SELECT date1 FROM s3 WHERE timestampadd('MINUTE', date1, -50) <= '2020-12-29 04:00:00' ORDER BY 1;
--SECOND
--Testcase 76:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('SECOND', date1, 25) >= '2020-12-29 04:40:30' ORDER BY 1;
--Testcase 77:
SELECT date1 FROM s3 WHERE timestampadd('SECOND', date1, 25) >= '2020-12-29 04:40:30' ORDER BY 1;
--Testcase 78:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('SECOND', date1, -50) <= '2020-12-29 04:00:00' ORDER BY 1;
--Testcase 79:
SELECT date1 FROM s3 WHERE timestampadd('SECOND', date1, -30) = '2020-12-29 05:00:00' ORDER BY 1;
--MILLISECOND
--Testcase 80:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MILLISECOND', date1, 300) = '2020-12-29 05:10:00.420' ORDER BY 1;
--Testcase 81:
SELECT date1 FROM s3 WHERE timestampadd('MILLISECOND', date1, 300) = '2020-12-29 05:10:00.420' ORDER BY 1;
--Testcase 82:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MILLISECOND', date1, -55) = '2020-12-29 05:10:00.065' ORDER BY 1;
--Testcase 83:
SELECT date1 FROM s3 WHERE timestampadd('MILLISECOND', date1, -55) = '2020-12-29 05:10:00.065' ORDER BY 1;
--Input wrong unit
--Testcase 84:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampadd('MICROSECOND', date1, -55) = '2020-12-29 05:10:00.065' ORDER BY 1;

--timestampdiff
--YEAR
--Testcase 85:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampdiff('YEAR', date1, '2018-01-04 08:48:00') > 0 ORDER BY 1;
--Testcase 86:
SELECT date1 FROM s3 WHERE timestampdiff('YEAR', date1, '2018-01-04 08:48:00') > 0 ORDER BY 1;
--Testcase 87:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('YEAR', '2015-07-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 88:
SELECT date2 FROM s3 WHERE timestampdiff('YEAR', '2015-07-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 89:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('YEAR', date1, date2) > 10 ORDER BY 1;
--Testcase 90:
SELECT date1, date2 FROM s3 WHERE timestampdiff('YEAR', date1, date2) > 10 ORDER BY 1;
--MONTH
--Testcase 91:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampdiff('MONTH', date1, '2020-11-04 08:48:00') = 1 ORDER BY 1;
--Testcase 92:
SELECT date1 FROM s3 WHERE timestampdiff('MONTH', date1, '2020-11-04 08:48:00') = 1 ORDER BY 1;
--Testcase 93:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('YEAR', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 94:
SELECT date2 FROM s3 WHERE timestampdiff('YEAR', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 95:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('MONTH', date1, date2) < 10 ORDER BY 1;
--Testcase 96:
SELECT date1, date2 FROM s3 WHERE timestampdiff('MONTH', date1, date2) < 10 ORDER BY 1;
--DAY
--Testcase 97:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('DAY', date2, '2020-12-04 08:48:00') > 20 ORDER BY 1;
--Testcase 98:
SELECT date2 FROM s3 WHERE timestampdiff('DAY', date2, '2020-12-04 08:48:00') > 20 ORDER BY 1;
--Testcase 99:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('DAY', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 100:
SELECT date2 FROM s3 WHERE timestampdiff('DAY', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 101:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('DAY', date1, date2) > 10 ORDER BY 1;
--Testcase 102:
SELECT date1, date2 FROM s3 WHERE timestampdiff('DAY', date1, date2) > 10 ORDER BY 1;
--HOUR
--Testcase 103:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE timestampdiff('HOUR', date1, '2020-12-29 07:40:00') < 0 ORDER BY 1;
--Testcase 104:
SELECT date1 FROM s3 WHERE timestampdiff('HOUR', date1, '2020-12-29 07:40:00') < 0 ORDER BY 1;
--Testcase 105:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('HOUR', '2020-12-15 08:48:00', date2) > 3.5 ORDER BY 1;
--Testcase 106:
SELECT date2 FROM s3 WHERE timestampdiff('HOUR', '2020-12-15 08:48:00', date2) > 3.5 ORDER BY 1;
--Testcase 107:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('HOUR', date1, date2) > 10 ORDER BY 1;
--Testcase 108:
SELECT date1, date2 FROM s3 WHERE timestampdiff('HOUR', date1, date2) > 10 ORDER BY 1;
--MINUTE
--Testcase 109:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('MINUTE', date2, '2020-12-04 08:48:00') > 20 ORDER BY 1;
--Testcase 110:
SELECT date2 FROM s3 WHERE timestampdiff('MINUTE', date2, '2020-12-04 08:48:00') > 20 ORDER BY 1;
--Testcase 111:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('MINUTE', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 112:
SELECT date2 FROM s3 WHERE timestampdiff('MINUTE', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 113:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('MINUTE', date1, date2) > 10 ORDER BY 1;
--Testcase 114:
SELECT date1, date2 FROM s3 WHERE timestampdiff('MINUTE', date1, date2) > 10 ORDER BY 1;
--SECOND
--Testcase 115:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('SECOND', date2, '2020-12-04 08:48:00') > 1000 ORDER BY 1;
--Testcase 116:
SELECT date2 FROM s3 WHERE timestampdiff('SECOND', date2, '2020-12-04 08:48:00') > 1000 ORDER BY 1;
--Testcase 117:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('SECOND', '2020-03-17 04:50:00', date2) < 100 ORDER BY 1;
--Testcase 118:
SELECT date2 FROM s3 WHERE timestampdiff('SECOND', '2020-03-17 04:50:00', date2) < 100 ORDER BY 1;
--Testcase 119:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('SECOND', date1, date2) > 1600000 ORDER BY 1;
--Testcase 120:
SELECT date1, date2 FROM s3 WHERE timestampdiff('SECOND', date1, date2) > 1600000 ORDER BY 1;
--MILLISECOND
--Testcase 121:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('MILLISECOND', date2, '2020-12-04 08:48:00') > 200 ORDER BY 1;
--Testcase 122:
SELECT date2 FROM s3 WHERE timestampdiff('MILLISECOND', date2, '2020-12-04 08:48:00') > 200 ORDER BY 1;
--Testcase 123:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('MILLISECOND', '2020-03-17 08:48:00', date2) < 0 ORDER BY 1;
--Testcase 124:
SELECT date2 FROM s3 WHERE timestampdiff('MILLISECOND', '2020-03-17 08:48:00', date2) < 0 ORDER BY 1;
--Testcase 125:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('MILLISECOND', date1, date2) = -443 ORDER BY 1;
--Testcase 126:
SELECT date1, date2 FROM s3 WHERE timestampdiff('MILLISECOND', date1, date2) = -443 ORDER BY 1;
--Input wrong unit
--Testcase 127:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('MICROSECOND', date2, '2020-12-04 08:48:00') > 20 ORDER BY 1;
--Testcase 128:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE timestampdiff('DECADE', '2020-02-15 08:48:00', date2) < 5 ORDER BY 1;
--Testcase 129:
EXPLAIN VERBOSE
SELECT date1, date2 FROM s3 WHERE timestampdiff('NANOSECOND', date1, date2) > 10 ORDER BY 1;

--to_timestamp_ms
--Normal case
--Testcase 130:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE to_timestamp_ms(intcol) > '1970-01-01 1:00:00' ORDER BY 1;
--Testcase 131:
SELECT date1 FROM s3 WHERE to_timestamp_ms(intcol) > '1970-01-01 1:00:00' ORDER BY 1;
--Return error if column contains -1 value
--Testcase 132:
SELECT date1 FROM s3 WHERE to_timestamp_ms(intcol) > '1970-01-01 1:00:00' ORDER BY 1;

--to_epoch_ms
--Testcase 133:
EXPLAIN VERBOSE
SELECT date1 FROM s3 WHERE intcol < to_epoch_ms(date1) ORDER BY 1;
--Testcase 134:
SELECT date1 FROM s3 WHERE intcol < to_epoch_ms(date1) ORDER BY 1;
--Testcase 135:
EXPLAIN VERBOSE
SELECT date2 FROM s3 WHERE to_epoch_ms(date2) < 1000000000000 ORDER BY 1;

-- Test for now() pushdown function of griddb
-- griddb_now as parameter of timestampdiff()
--Testcase 136:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1;
--Testcase 137:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1;

--Testcase 138:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) > 0 ORDER BY 1;
--Testcase 139:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) > 0 ORDER BY 1;

--Testcase 140:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('HOUR', griddb_now(), '2020-12-04 08:48:00') > 0 ORDER BY 1;
--Testcase 141:
SELECT * FROM s3 WHERE timestampdiff('HOUR', griddb_now(), '2020-12-04 08:48:00') > 0 ORDER BY 1;

--Testcase 142:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', griddb_now(), '2032-12-04 08:48:00') < 0 ORDER BY 1;
--Testcase 143:
SELECT * FROM s3 WHERE timestampdiff('YEAR', griddb_now(), '2032-12-04 08:48:00') < 0 ORDER BY 1;

-- griddb_now as parameter of timestampadd()
--Testcase 144:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE date > timestampadd('YEAR', griddb_now(), -1) ORDER BY 1;
--Testcase 145:
SELECT * FROM s3 WHERE date > timestampadd('YEAR', griddb_now(), -1) ORDER BY 1;

--Testcase 146:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE date < timestampadd('YEAR', griddb_now(), -1) ORDER BY 1;
--Testcase 147:
SELECT * FROM s3 WHERE date < timestampadd('YEAR', griddb_now(), -1) ORDER BY 1;

-- griddb_now() in expression
--Testcase 148:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE date < griddb_now() ORDER BY 1;
--Testcase 149:
SELECT * FROM s3 WHERE date < griddb_now() ORDER BY 1;

--Testcase 150:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE date > griddb_now() ORDER BY 1;
--Testcase 151:
SELECT * FROM s3 WHERE date > griddb_now() ORDER BY 1;

--Testcase 152:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE date <= griddb_now() ORDER BY 1;
--Testcase 153:
SELECT * FROM s3 WHERE date <= griddb_now() ORDER BY 1;

-- griddb_now() to_epoch_ms()
--Testcase 154:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE to_epoch_ms(griddb_now()) > 0 ORDER BY 1;
--Testcase 155:
SELECT * FROM s3 WHERE to_epoch_ms(griddb_now()) > 0 ORDER BY 1;

-- griddb_now() other cases
--Testcase 156:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE griddb_now() IS NOT NULL ORDER BY 1;
--Testcase 157:
SELECT * FROM s3 WHERE griddb_now() IS NOT NULL ORDER BY 1;

--Testcase 158:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) > 0 OR timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1;
--Testcase 159:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) > 0 OR timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1;

--Testcase 160:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 ASC;
--Testcase 161:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 ASC;

--Testcase 162:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 DESC;
--Testcase 163:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 DESC;

--Testcase 164:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 ASC;
--Testcase 165:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 ASC;

--Testcase 166:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 DESC;
--Testcase 167:
SELECT * FROM s3 WHERE timestampdiff('YEAR', date, griddb_now()) < 0 ORDER BY 1 DESC;

--
--Test for unique functions of GridDB in WHERE clause: array functions
--
--array_length
--Testcase 168:
EXPLAIN VERBOSE
SELECT boolarray FROM s3 WHERE array_length(boolarray) = 3 ORDER BY 1;
--Testcase 169:
SELECT boolarray FROM s3 WHERE array_length(boolarray) = 3 ORDER BY 1;
--Testcase 170:
EXPLAIN VERBOSE
SELECT stringarray FROM s3 WHERE array_length(stringarray) = 3 ORDER BY 1;
--Testcase 171:
SELECT stringarray FROM s3 WHERE array_length(stringarray) = 3 ORDER BY 1;
--Testcase 172:
EXPLAIN VERBOSE
SELECT bytearray, shortarray FROM s3 WHERE array_length(bytearray) > array_length(shortarray) ORDER BY 1;
--Testcase 173:
SELECT bytearray, shortarray FROM s3 WHERE array_length(bytearray) > array_length(shortarray) ORDER BY 1;
--Testcase 174:
EXPLAIN VERBOSE
SELECT integerarray, longarray FROM s3 WHERE array_length(integerarray) = array_length(longarray) ORDER BY 1;
--Testcase 175:
SELECT integerarray, longarray FROM s3 WHERE array_length(integerarray) = array_length(longarray) ORDER BY 1;
--Testcase 176:
EXPLAIN VERBOSE
SELECT floatarray, doublearray FROM s3 WHERE array_length(floatarray) - array_length(doublearray) = 0 ORDER BY 1;
--Testcase 177:
SELECT floatarray, doublearray FROM s3 WHERE array_length(floatarray) - array_length(doublearray) = 0 ORDER BY 1;
--Testcase 178:
EXPLAIN VERBOSE
SELECT timestamparray FROM s3 WHERE array_length(timestamparray) < 3 ORDER BY 1;
--Testcase 179:
SELECT timestamparray FROM s3 WHERE array_length(timestamparray) < 3 ORDER BY 1;

--element
--Normal case
--Testcase 180:
EXPLAIN VERBOSE
SELECT boolarray FROM s3 WHERE element(1, boolarray) = 'f' ORDER BY 1;
--Testcase 181:
SELECT boolarray FROM s3 WHERE element(1, boolarray) = 'f' ORDER BY 1;
--Testcase 182:
EXPLAIN VERBOSE
SELECT stringarray FROM s3 WHERE element(1, stringarray) != 'bbb' ORDER BY 1;
--Testcase 183:
SELECT stringarray FROM s3 WHERE element(1, stringarray) != 'bbb' ORDER BY 1;
--Testcase 184:
EXPLAIN VERBOSE
SELECT bytearray, shortarray FROM s3 WHERE element(0, bytearray) = element(0, shortarray) ORDER BY 1;
--Testcase 185:
SELECT bytearray, shortarray FROM s3 WHERE element(0, bytearray) = element(0, shortarray) ORDER BY 1;
--Testcase 186:
EXPLAIN VERBOSE
SELECT integerarray, longarray FROM s3 WHERE element(0, integerarray)*100+44 = element(0,longarray) ORDER BY 1;
--Testcase 187:
SELECT integerarray, longarray FROM s3 WHERE element(0, integerarray)*100+44 = element(0,longarray) ORDER BY 1;
--Testcase 188:
EXPLAIN VERBOSE
SELECT floatarray, doublearray FROM s3 WHERE element(2, floatarray)*10 < element(0,doublearray) ORDER BY 1;
--Testcase 189:
SELECT floatarray, doublearray FROM s3 WHERE element(2, floatarray)*10 < element(0,doublearray) ORDER BY 1;
--Testcase 190:
EXPLAIN VERBOSE
SELECT timestamparray FROM s3 WHERE element(1,timestamparray) > '2020-12-29 04:00:00' ORDER BY 1;
--Testcase 191:
SELECT timestamparray FROM s3 WHERE element(1,timestamparray) > '2020-12-29 04:00:00' ORDER BY 1;
--Return error when getting non-existent element
--Testcase 192:
EXPLAIN VERBOSE
SELECT timestamparray FROM s3 WHERE element(2,timestamparray) > '2020-12-29 04:00:00' ORDER BY 1;
SELECT timestamparray FROM s3 WHERE element(2,timestamparray) > '2020-12-29 04:00:00' ORDER BY 1;

--
--if user selects non-unique functions which Griddb only supports in WHERE clause => do not push down
--if user selects unique functions which Griddb only supports in WHERE clause => still push down, return error of Griddb
--
--Testcase 193:
EXPLAIN VERBOSE
SELECT char_length(name) FROM s3 ORDER BY 1;
--Testcase 194:
SELECT char_length(name) FROM s3 ORDER BY 1;
--Testcase 195:
EXPLAIN VERBOSE
SELECT concat(name,'abc') FROM s3 ORDER BY 1;
--Testcase 196:
SELECT concat(name,'abc') FROM s3 ORDER BY 1;
--Testcase 197:
EXPLAIN VERBOSE
SELECT substr(name,2,3) FROM s3 ORDER BY 1;
--Testcase 198:
SELECT substr(name,2,3) FROM s3 ORDER BY 1;
--Testcase 199:
EXPLAIN VERBOSE
SELECT element(1, timestamparray) FROM s3 ORDER BY 1;
--SELECT element(1, timestamparray) FROM s3 ORDER BY 1;
--Testcase 200:
EXPLAIN VERBOSE
SELECT upper(name) FROM s3 ORDER BY 1;
--Testcase 201:
SELECT upper(name) FROM s3 ORDER BY 1;
--Testcase 202:
EXPLAIN VERBOSE
SELECT lower(name) FROM s3 ORDER BY 1;
--Testcase 203:
SELECT lower(name) FROM s3 ORDER BY 1;
--Testcase 204:
EXPLAIN VERBOSE
SELECT round(gpa) FROM s3 ORDER BY 1;
--Testcase 205:
SELECT round(gpa) FROM s3 ORDER BY 1;
--Testcase 206:
EXPLAIN VERBOSE
SELECT floor(gpa) FROM s3 ORDER BY 1;
--Testcase 207:
SELECT floor(gpa) FROM s3 ORDER BY 1;
--Testcase 208:
EXPLAIN VERBOSE
SELECT ceiling(gpa) FROM s3 ORDER BY 1;
--Testcase 209:
SELECT ceiling(gpa) FROM s3 ORDER BY 1;
--Testcase 210:
EXPLAIN VERBOSE
SELECT griddb_timestamp(strcol) FROM s3 ORDER BY 1;
--SELECT griddb_timestamp(strcol) FROM s3 ORDER BY 1;
--Testcase 211:
EXPLAIN VERBOSE
SELECT timestampadd('YEAR', date1, -1) FROM s3 ORDER BY 1;
--SELECT timestampadd('YEAR', date1, -1) FROM s3 ORDER BY 1;
--Testcase 212:
EXPLAIN VERBOSE
SELECT timestampdiff('YEAR', date1, '2018-01-04 08:48:00') FROM s3 ORDER BY 1;
--SELECT timestampdiff('YEAR', date1, '2018-01-04 08:48:00') FROM s3 ORDER BY 1;
--Testcase 213:
EXPLAIN VERBOSE
SELECT to_timestamp_ms(intcol) FROM s3 ORDER BY 1;
--SELECT to_timestamp_ms(intcol) FROM s3 ORDER BY 1;
--Testcase 214:
EXPLAIN VERBOSE
SELECT to_epoch_ms(date1) FROM s3 ORDER BY 1;
--SELECT to_epoch_ms(date1) FROM s3 ORDER BY 1;
--Testcase 215:
EXPLAIN VERBOSE
SELECT array_length(boolarray) FROM s3 ORDER BY 1;
--SELECT array_length(boolarray) FROM s3 ORDER BY 1;
--Testcase 216:
EXPLAIN VERBOSE
SELECT element(1, stringarray) FROM s3 ORDER BY 1;
--SELECT element(1, stringarray) FROM s3 ORDER BY 1;

--
--Test for unique functions of GridDB in SELECT clause: time-series functions
--
--time_next
--specified time exist => return that row
--Testcase 217:
EXPLAIN VERBOSE
SELECT time_next('2018-12-01 10:00:00') FROM s3 ORDER BY 1;
--Testcase 218:
SELECT time_next('2018-12-01 10:00:00') FROM s3 ORDER BY 1;
--specified time does not exist => return the row whose time  is immediately after the specified time
--Testcase 219:
EXPLAIN VERBOSE
SELECT time_next('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--Testcase 220:
SELECT time_next('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--specified time does not exist, there is no time after the specified time => return no row
--Testcase 221:
EXPLAIN VERBOSE
SELECT time_next('2018-12-01 10:45:00') FROM s3 ORDER BY 1;
--Testcase 222:
SELECT time_next('2018-12-01 10:45:00') FROM s3 ORDER BY 1;

--time_next_only
--even though specified time exist, still return the row whose time is immediately after the specified time
--Testcase 223:
EXPLAIN VERBOSE
SELECT time_next_only('2018-12-01 10:00:00') FROM s3 ORDER BY 1;
--Testcase 224:
SELECT time_next_only('2018-12-01 10:00:00') FROM s3 ORDER BY 1;
--specified time does not exist => return the row whose time  is immediately after the specified time
--Testcase 225:
EXPLAIN VERBOSE
SELECT time_next_only('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--Testcase 226:
SELECT time_next_only('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--there is no time after the specified time => return no row
--Testcase 227:
EXPLAIN VERBOSE
SELECT time_next_only('2018-12-01 10:45:00') FROM s3 ORDER BY 1;
--Testcase 228:
SELECT time_next_only('2018-12-01 10:45:00') FROM s3 ORDER BY 1;

--time_prev
--specified time exist => return that row
--Testcase 229:
EXPLAIN VERBOSE
SELECT time_prev('2018-12-01 10:10:00') FROM s3 ORDER BY 1;
--Testcase 230:
SELECT time_prev('2018-12-01 10:10:00') FROM s3 ORDER BY 1;
--specified time does not exist => return the row whose time  is immediately before the specified time
--Testcase 231:
EXPLAIN VERBOSE
SELECT time_prev('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--Testcase 232:
SELECT time_prev('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--specified time does not exist, there is no time before the specified time => return no row
--Testcase 233:
EXPLAIN VERBOSE
SELECT time_prev('2018-12-01 09:45:00') FROM s3 ORDER BY 1;
--Testcase 234:
SELECT time_prev('2018-12-01 09:45:00') FROM s3 ORDER BY 1;

--time_prev_only
--even though specified time exist, still return the row whose time is immediately before the specified time
--Testcase 235:
EXPLAIN VERBOSE
SELECT time_prev_only('2018-12-01 10:10:00') FROM s3 ORDER BY 1;
--Testcase 236:
SELECT time_prev_only('2018-12-01 10:10:00') FROM s3 ORDER BY 1;
--specified time does not exist => return the row whose time  is immediately before the specified time
--Testcase 237:
EXPLAIN VERBOSE
SELECT time_prev_only('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--Testcase 238:
SELECT time_prev_only('2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--there is no time before the specified time => return no row
--Testcase 239:
EXPLAIN VERBOSE
SELECT time_prev_only('2018-12-01 09:45:00') FROM s3 ORDER BY 1;
--Testcase 240:
SELECT time_prev_only('2018-12-01 09:45:00') FROM s3 ORDER BY 1;

--time_interpolated
--specified time exist => return that row
--Testcase 241:
EXPLAIN VERBOSE
SELECT time_interpolated(value1, '2018-12-01 10:10:00') FROM s3 ORDER BY 1;
--Testcase 242:
SELECT time_interpolated(value1, '2018-12-01 10:10:00') FROM s3 ORDER BY 1;
--specified time does not exist => return the row which has interpolated value.
--The column which is specified as the 1st parameter will be calculated by linearly interpolating the value of the previous and next rows.
--Other values will be equal to the values of rows previous to the specified time.
--Testcase 243:
EXPLAIN VERBOSE
SELECT time_interpolated(value1, '2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--Testcase 244:
SELECT time_interpolated(value1, '2018-12-01 10:05:00') FROM s3 ORDER BY 1;
--specified time does not exist. There is no row before or after the specified time => can not calculate interpolated value, return no row.
--Testcase 245:
EXPLAIN VERBOSE
SELECT time_interpolated(value1, '2018-12-01 09:05:00') FROM s3 ORDER BY 1;
--Testcase 246:
SELECT time_interpolated(value1, '2018-12-01 09:05:00') FROM s3 ORDER BY 1;
--Testcase 247:
EXPLAIN VERBOSE
SELECT time_interpolated(value1, '2018-12-01 10:45:00') FROM s3 ORDER BY 1;
--Testcase 248:
SELECT time_interpolated(value1, '2018-12-01 10:45:00') FROM s3 ORDER BY 1;

--time_sampling by MINUTE
--rows for sampling exists => return those rows
--Testcase 249:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:20:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--Testcase 250:
SELECT time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:20:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--rows for sampling does not exist => return rows that contains interpolated values.
--The column which is specified as the 1st parameter will be calculated by linearly interpolating the value of the previous and next rows.
--Other values will be equal to the values of rows previous to the specified time.
--Testcase 251:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-01 10:05:00', '2018-12-01 10:35:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--Testcase 252:
SELECT time_sampling(value1, '2018-12-01 10:05:00', '2018-12-01 10:35:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--mix exist and non-exist sampling
--Testcase 253:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:40:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--Testcase 254:
SELECT time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:40:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--In linearly interpolating the value of the previous and next rows, if one of the values does not exist => the sampling row will not be returned
--Testcase 255:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-01 09:30:00', '2018-12-01 11:00:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--Testcase 256:
SELECT time_sampling(value1, '2018-12-01 09:30:00', '2018-12-01 11:00:00', 10, 'MINUTE') FROM s3 ORDER BY 1;
--if the first parameter is not set, * will be added as the first parameter.
--When specified time does not exist, all columns (except timestamp key column) will be equal to the values of rows previous to the specified time.
--UPDATE time_series__griddb_svr__0 SET value1 = 5 where date = '2018-12-01 10:40:00';
--EXPLAIN VERBOSE
--SELECT time_sampling('2018-12-01 10:00:00', '2018-12-01 10:40:00', 10, 'MINUTE') FROM s3;
--SELECT time_sampling('2018-12-01 10:00:00', '2018-12-01 10:40:00', 10, 'MINUTE') FROM s3;

--time_sampling by HOUR
--rows for sampling exists => return those rows
--Testcase 257:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-02 10:00:00', '2018-12-02 12:00:00', 2, 'HOUR') FROM s3 ORDER BY 1;
--Testcase 258:
SELECT time_sampling(value1, '2018-12-02 10:00:00', '2018-12-02 12:00:00', 2, 'HOUR') FROM s3 ORDER BY 1;
--rows for sampling does not exist => return rows that contains interpolated values.
--The column which is specified as the 1st parameter will be calculated by linearly interpolating the value of the previous and next rows.
--Other values will be equal to the values of rows previous to the specified time.
--Testcase 259:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-02 10:05:00', '2018-12-02 21:00:00', 3, 'HOUR') FROM s3 ORDER BY 1;
--Testcase 260:
SELECT time_sampling(value1, '2018-12-02 10:05:00', '2018-12-02 21:00:00', 3, 'HOUR') FROM s3 ORDER BY 1;
--mix exist and non-exist sampling
--Testcase 261:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-02 10:00:00', '2018-12-02 21:40:00', 2, 'HOUR') FROM s3 ORDER BY 1;
--Testcase 262:
SELECT time_sampling(value1, '2018-12-02 10:00:00', '2018-12-02 21:40:00', 2, 'HOUR') FROM s3 ORDER BY 1;
--In linearly interpolating the value of the previous and next rows, if one of the values does not exist => the sampling row will not be returned
--Testcase 263:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-02 6:00:00', '2018-12-02 23:00:00', 3, 'HOUR') FROM s3 ORDER BY 1;
--Testcase 264:
SELECT time_sampling(value1, '2018-12-02 6:00:00', '2018-12-02 23:00:00', 3, 'HOUR') FROM s3 ORDER BY 1;
--if the first parameter is not set, * will be added as the first parameter.
--When specified time does not exist, all columns (except timestamp key column) will be equal to the values of rows previous to the specified time.
--DELETE FROM time_series__griddb_svr__0 WHERE value1 = 4;
--EXPLAIN VERBOSE
--SELECT time_sampling('2018-12-02 10:00:00', '2018-12-02 21:40:00', 2, 'HOUR') FROM s3;
--SELECT time_sampling('2018-12-02 10:00:00', '2018-12-02 21:40:00', 2, 'HOUR') FROM s3;

--time_sampling by DAY
--rows for sampling exists => return those rows
--Testcase 265:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-03 11:00:00', '2018-12-04 11:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--Testcase 266:
SELECT time_sampling(value1, '2018-12-03 11:00:00', '2018-12-04 11:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--rows for sampling does not exist => return rows that contains interpolated values.
--The column which is specified as the 1st parameter will be calculated by linearly interpolating the value of the previous and next rows.
--Other values will be equal to the values of rows previous to the specified time.
--Testcase 267:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-03 09:00:00', '2018-12-05 12:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--Testcase 268:
SELECT time_sampling(value1, '2018-12-03 09:00:00', '2018-12-05 12:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--mix exist and non-exist sampling
--Testcase 269:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-03 11:00:00', '2018-12-05 12:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--Testcase 270:
SELECT time_sampling(value1, '2018-12-03 11:00:00', '2018-12-05 12:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--In linearly interpolating the value of the previous and next rows, if one of the values does not exist => the sampling row will not be returned
--Testcase 271:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-03 09:30:00', '2018-12-03 11:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--Testcase 272:
SELECT time_sampling(value1, '2018-12-03 09:30:00', '2018-12-03 11:00:00', 1, 'DAY') FROM s3 ORDER BY 1;
--if the first parameter is not set, * will be added as the first parameter.
--When specified time does not exist, all columns (except timestamp key column) will be equal to the values of rows previous to the specified time.
--DELETE FROM time_series__griddb_svr__0 WHERE value1 = 6;
--EXPLAIN VERBOSE
--SELECT time_sampling(value1, '2018-12-01 11:00:00', '2018-12-03 12:00:00', 1, 'DAY') FROM s3;
--Testcase 273:
SELECT time_sampling(value1, '2018-12-03 11:00:00', '2018-12-03 12:00:00', 1, 'DAY') FROM s3 ORDER BY 1;

--time_sampling by SECOND
--rows for sampling exists => return those rows
--Testcase 274:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-06 10:00:00', '2018-12-06 10:00:20', 10, 'SECOND') FROM s3 ORDER BY 1;
--Testcase 275:
SELECT time_sampling(value1, '2018-12-06 10:00:00', '2018-12-06 10:00:20', 10, 'SECOND') FROM s3 ORDER BY 1;
--rows for sampling does not exist => return rows that contains interpolated values.
--The column which is specified as the 1st parameter will be calculated by linearly interpolating the value of the previous and next rows.
--Other values will be equal to the values of rows previous to the specified time.
--Testcase 276:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-06 10:00:03', '2018-12-06 10:00:35', 15, 'SECOND') FROM s3 ORDER BY 1;
--Testcase 277:
SELECT time_sampling(value1, '2018-12-06 10:00:03', '2018-12-06 10:00:35', 15, 'SECOND') FROM s3 ORDER BY 1;
--mix exist and non-exist sampling
--Testcase 278:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-06 10:00:00', '2018-12-06 11:00:00', 10, 'SECOND') FROM s3 ORDER BY 1;
--Testcase 279:
SELECT time_sampling(value1, '2018-12-06 10:00:00', '2018-12-06 11:00:00', 10, 'SECOND') FROM s3 ORDER BY 1;
--In linearly interpolating the value of the previous and next rows, if one of the values does not exist => the sampling row will not be returned
--Testcase 280:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-06 08:30:00', '2018-12-06 11:00:00', 20, 'SECOND') FROM s3 ORDER BY 1;
--Testcase 281:
SELECT time_sampling(value1, '2018-12-06 08:30:00', '2018-12-06 11:00:00', 20, 'SECOND') FROM s3 ORDER BY 1;
--if the first parameter is not set, * will be added as the first parameter.
--When specified time does not exist, all columns (except timestamp key column) will be equal to the values of rows previous to the specified time.
--DELETE FROM time_series__griddb_svr__0 WHERE value1 = 4;

--EXPLAIN VERBOSE
--SELECT time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 11:00:00', 10, 'SECOND') FROM time_series;
--SELECT time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 11:00:00', 10, 'SECOND') FROM time_series;

--time_sampling by MILLISECOND
--rows for sampling exists => return those rows
--Testcase 282:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-07 10:00:00.100', '2018-12-07 10:00:00.140', 20, 'MILLISECOND') FROM s3 ORDER BY 1;
--SELECT time_sampling(value1, '2018-12-07 10:00:00.100', '2018-12-07 10:00:00.140', 20, 'MILLISECOND') FROM s3 ORDER BY 1;
--rows for sampling does not exist => return rows that contains interpolated values.
--The column which is specified as the 1st parameter will be calculated by linearly interpolating the value of the previous and next rows.
--Other values will be equal to the values of rows previous to the specified time.
--Testcase 283:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-07 10:00:00.115', '2018-12-07 10:00:00.155', 15, 'MILLISECOND') FROM s3 ORDER BY 1;
--Testcase 284:
SELECT time_sampling(value1, '2018-12-07 10:00:00.115', '2018-12-07 10:00:00.155', 15, 'MILLISECOND') FROM s3 ORDER BY 1;
--mix exist and non-exist sampling
--Testcase 285:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-07 10:00:00.100', '2018-12-07 10:00:00.150', 5, 'MILLISECOND') FROM s3 ORDER BY 1;
--SELECT time_sampling(value1, '2018-12-07 10:00:00.100', '2018-12-07 10:00:00.150', 5, 'MILLISECOND') FROM s3 ORDER BY 1;
--In linearly interpolating the value of the previous and next rows, if one of the values does not exist => the sampling row will not be returned
--Testcase 286:
EXPLAIN VERBOSE
SELECT time_sampling(value1, '2018-12-07 10:00:00.002', '2018-12-07 10:00:00.500', 20, 'MILLISECOND') FROM s3 ORDER BY 1;
SELECT time_sampling(value1, '2018-12-07 10:00:00.002', '2018-12-07 10:00:00.500', 20, 'MILLISECOND') FROM s3 ORDER BY 1;
--if the first parameter is not set, * will be added as the first parameter.
--When specified time does not exist, all columns (except timestamp key column) will be equal to the values of rows previous to the specified time.
--DELETE FROM time_series__griddb_svr__0 WHERE value1 = 4;
--EXPLAIN VERBOSE
--SELECT time_sampling(value1, '2018-12-01 10:00:00.100', '2018-12-01 10:00:00.150', 5, 'MILLISECOND') FROM time_series;
--SELECT time_sampling(value1, '2018-12-01 10:00:00.100', '2018-12-01 10:00:00.150', 5, 'MILLISECOND') FROM time_series;

--max_rows
--Testcase 287:
EXPLAIN VERBOSE
SELECT max_rows(value2) FROM s3 ORDER BY 1;
--Testcase 288:
SELECT max_rows(value2) FROM s3 ORDER BY 1;
--Testcase 289:
EXPLAIN VERBOSE
SELECT max_rows(date) FROM s3 ORDER BY 1;
--Testcase 290:
SELECT max_rows(date) FROM s3 ORDER BY 1;

--min_rows
--Testcase 291:
EXPLAIN VERBOSE
SELECT min_rows(value2) FROM s3 ORDER BY 1;
--Testcase 292:
SELECT min_rows(value2) FROM s3 ORDER BY 1;
--Testcase 293:
EXPLAIN VERBOSE
SELECT min_rows(date) FROM s3 ORDER BY 1;
--Testcase 294:
SELECT min_rows(date) FROM s3 ORDER BY 1;

--
--if WHERE clause contains functions which Griddb only supports in SELECT clause => still push down, return error of Griddb
--
--Testcase 295:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE time_next('2018-12-01 10:00:00') = '"2020-01-05 21:00:00,{t,f,t}"' ORDER BY 1;
--Testcase 296:
SELECT * FROM s3 WHERE time_next('2018-12-01 10:00:00') = '"2020-01-05 21:00:00,{t,f,t}"' ORDER BY 1;
--Testcase 297:
EXPLAIN VERBOSE
SELECT date FROM s3 WHERE time_next_only('2018-12-01 10:00:00') = time_interpolated(value1, '2018-12-01 10:10:00') ORDER BY 1;
--Testcase 298:
SELECT date FROM s3 WHERE time_next_only('2018-12-01 10:00:00') = time_interpolated(value1, '2018-12-01 10:10:00') ORDER BY 1;
--Testcase 299:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE time_prev('2018-12-01 10:00:00') = '"2020-01-05 21:00:00,{t,f,t}"' ORDER BY 1;
--Testcase 300:
SELECT * FROM s3 WHERE time_prev('2018-12-01 10:00:00') = '"2020-01-05 21:00:00,{t,f,t}"' ORDER BY 1;
--Testcase 301:
EXPLAIN VERBOSE
SELECT date FROM s3 WHERE time_prev_only('2018-12-01 10:00:00') = time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:40:00', 10, 'MINUTE') ORDER BY 1;
--Testcase 302:
SELECT date FROM s3 WHERE time_prev_only('2018-12-01 10:00:00') = time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:40:00', 10, 'MINUTE') ORDER BY 1;
--Testcase 303:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE max_rows(date) = min_rows(value2) ORDER BY 1;
--SELECT * FROM s3 WHERE max_rows(date) = min_rows(value2) ORDER BY 1;

--
-- Test syntax (xxx()::s3).*
--
--Testcase 304:
EXPLAIN VERBOSE
SELECT (time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:50:00', 20, 'MINUTE')::s3).* FROM s3 ORDER BY 1;
--Testcase 305:
SELECT (time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:50:00', 20, 'MINUTE')::s3).* FROM s3 ORDER BY 1;
--Testcase 306:
EXPLAIN VERBOSE
SELECT (time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:50:00', 20, 'MINUTE')::s3).date FROM s3 ORDER BY 1;
--Testcase 307:
SELECT (time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:50:00', 20, 'MINUTE')::s3).date FROM s3 ORDER BY 1;
--Testcase 308:
EXPLAIN VERBOSE
SELECT (time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:50:00', 20, 'MINUTE')::s3).value1 FROM s3 ORDER BY 1;
--Testcase 309:
SELECT (time_sampling(value1, '2018-12-01 10:00:00', '2018-12-01 10:50:00', 20, 'MINUTE')::s3).value1 FROM s3 ORDER BY 1;

--
-- Test aggregate function time_avg
--
--Testcase 310:
EXPLAIN VERBOSE
SELECT time_avg(value1) FROM s3 ORDER BY 1;
--Testcase 311:
SELECT time_avg(value1) FROM s3 ORDER BY 1;
--Testcase 312:
EXPLAIN VERBOSE
SELECT time_avg(value2) FROM s3 ORDER BY 1;
--Testcase 313:
SELECT time_avg(value2) FROM s3 ORDER BY 1;
-- GridDB does not support select multiple target in a query => do not push down, raise stub function error
--Testcase 314:
EXPLAIN VERBOSE
SELECT time_avg(value1), time_avg(value2) FROM s3 ORDER BY 1;
--SELECT time_avg(value1), time_avg(value2) FROM s3 ORDER BY 1;
-- Do not push down when expected type is not correct, raise stub function error
--Testcase 315:
EXPLAIN VERBOSE
SELECT time_avg(date) FROM s3 ORDER BY 1;
--SELECT time_avg(date) FROM s3 ORDER BY 1;
--Testcase 316:
EXPLAIN VERBOSE
SELECT time_avg(blobcol) FROM s3 ORDER BY 1;
--SELECT time_avg(blobcol) FROM s3 ORDER BY 1;

--
-- Test aggregate function min, max, count, sum, avg, variance, stddev
--
--Testcase 317:
EXPLAIN VERBOSE
SELECT min(age) FROM s3 ORDER BY 1;
--Testcase 318:
SELECT min(age) FROM s3 ORDER BY 1;

--Testcase 319:
EXPLAIN VERBOSE
SELECT max(gpa) FROM s3 ORDER BY 1;
--Testcase 320:
SELECT max(gpa) FROM s3 ORDER BY 1;

--Testcase 321:
EXPLAIN VERBOSE
SELECT count(*) FROM s3 ORDER BY 1;
--Testcase 322:
SELECT count(*) FROM s3 ORDER BY 1;
--Testcase 323:
EXPLAIN VERBOSE
SELECT count(*) FROM s3 WHERE gpa < 3.5 OR age < 42 ORDER BY 1;
--Testcase 324:
SELECT count(*) FROM s3 WHERE gpa < 3.5 OR age < 42 ORDER BY 1;

--Testcase 325:
EXPLAIN VERBOSE
SELECT sum(age) FROM s3 ORDER BY 1;
--Testcase 326:
SELECT sum(age) FROM s3 ORDER BY 1;
--Testcase 327:
EXPLAIN VERBOSE
SELECT sum(age) FROM s3 WHERE round(gpa) > 3.5 ORDER BY 1;
--Testcase 328:
SELECT sum(age) FROM s3 WHERE round(gpa) > 3.5 ORDER BY 1;

--Testcase 329:
EXPLAIN VERBOSE
SELECT avg(gpa) FROM s3 ORDER BY 1;
--Testcase 330:
SELECT avg(gpa) FROM s3 ORDER BY 1;
--Testcase 331:
EXPLAIN VERBOSE
SELECT avg(gpa) FROM s3 WHERE lower(name) = 'george' ORDER BY 1;
--Testcase 332:
SELECT avg(gpa) FROM s3 WHERE lower(name) = 'george' ORDER BY 1;

--Testcase 333:
EXPLAIN VERBOSE
SELECT variance(gpa) FROM s3 ORDER BY 1;
--Testcase 334:
SELECT variance(gpa) FROM s3 ORDER BY 1;
--Testcase 335:
EXPLAIN VERBOSE
SELECT variance(gpa) FROM s3 WHERE gpa > 3.5 ORDER BY 1;
--Testcase 336:
SELECT variance(gpa) FROM s3 WHERE gpa > 3.5 ORDER BY 1;

--Testcase 337:
EXPLAIN VERBOSE
SELECT stddev(age) FROM s3 ORDER BY 1;
--Testcase 338:
SELECT stddev(age) FROM s3 ORDER BY 1;
--Testcase 339:
EXPLAIN VERBOSE
SELECT stddev(age) FROM s3 WHERE char_length(name) > 4 ORDER BY 1;
--Testcase 340:
SELECT stddev(age) FROM s3 WHERE char_length(name) > 4 ORDER BY 1;

--Testcase 341:
EXPLAIN VERBOSE
SELECT max(gpa), min(age) FROM s3 ORDER BY 1;
--Testcase 342:
SELECT max(gpa), min(age) FROM s3 ORDER BY 1;

--Drop all foreign tables
--Testcase 343:
DROP FOREIGN TABLE s3__pgspider_svr1__0;
--Testcase 344:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_svr1;
--Testcase 345:
DROP SERVER pgspider_svr1;

--Testcase 346:
DROP FOREIGN TABLE s3__pgspider_svr2__0;
--Testcase 347:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_svr2;
--Testcase 348:
DROP SERVER pgspider_svr2;

--Testcase 349:
DROP EXTENSION pgspider_fdw;

--Testcase 350:
DROP FOREIGN TABLE s3;
--Testcase 351:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_core_svr;
--Testcase 352:
DROP SERVER pgspider_core_svr;
--Testcase 353:
DROP EXTENSION pgspider_core_fdw;
