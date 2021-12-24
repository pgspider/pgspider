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
-- PGSpider Top Node -> Data source
-- stub functions are provided by data source FDW

----------------------------------------------------------
-- Data source: sqlite

--Testcase 6:
CREATE FOREIGN TABLE s3 (id text, time timestamp, tag1 text, value1 float, value2 int, value3 float, value4 int, str1 text, str2 text, __spd_url text) SERVER pgspider_core_svr;
--Testcase 7:
CREATE EXTENSION sqlite_fdw;
--Testcase 8:
CREATE SERVER sqlite_svr FOREIGN DATA WRAPPER sqlite_fdw
OPTIONS (database '/tmp/pgtest.db');
--Testcase 9:
CREATE FOREIGN TABLE s3__sqlite_svr__0 (id text OPTIONS (key 'true'), time timestamp, tag1 text, value1 float, value2 int, value3 float, value4 int, str1 text, str2 text) SERVER sqlite_svr OPTIONS(table 's3');

-- s3 (value1 as float8, value2 as bigint)
--Testcase 10:
\d s3;
--Testcase 11:
SELECT * FROM s3 ORDER BY 1,2,3,4,5,6,7,8,9,10;

-- select abs (builtin function, explain)
--Testcase 12:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3;

-- select abs (buitin function, result)
--Testcase 13:
SELECT * FROM (
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select abs (builtin function, not pushdown constraints, explain)
--Testcase 14:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select abs (builtin function, not pushdown constraints, result)
--Testcase 15:
SELECT * FROM (
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64'
) AS t ORDER BY 1,2,3,4;

-- select abs (builtin function, pushdown constraints, explain)
--Testcase 16:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200;

-- select abs (builtin function, pushdown constraints, result)
--Testcase 17:
SELECT * FROM (
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200
) AS t ORDER BY 1,2,3,4;

-- select abs as nest function with agg (pushdown, explain)
--Testcase 18:
EXPLAIN VERBOSE
SELECT sum(value3),abs(sum(value3)) FROM s3;

-- select abs as nest function with agg (pushdown, result)
--Testcase 19:
SELECT sum(value3),abs(sum(value3)) FROM s3;

-- select abs with non pushdown func and explicit constant (explain)
--Testcase 20:
EXPLAIN VERBOSE
SELECT abs(value3), pi(), 4.1 FROM s3;

-- select abs with non pushdown func and explicit constant (result)
--Testcase 21:
SELECT * FROM (
SELECT abs(value3), pi(), 4.1 FROM s3
) AS t ORDER BY 1,2,3;

-- select abs with order by (explain)
--Testcase 22:
EXPLAIN VERBOSE
SELECT value1, abs(1-value1) FROM s3 ORDER BY abs(1-value1);

-- select abs with order by (result)
--Testcase 23:
SELECT value1, abs(1-value1) FROM s3 ORDER BY abs(1-value1);

-- select abs with order by index (result)
--Testcase 24:
SELECT value1, abs(1-value1) FROM s3 ORDER BY 2,1;

-- select abs with order by index (result)
--Testcase 25:
SELECT value1, abs(1-value1) FROM s3 ORDER BY 1,2;

-- select abs and as
--Testcase 26:
SELECT * FROM (
SELECT abs(value3) as abs1 FROM s3
) AS t ORDER BY 1;

-- select abs with arithmetic and tag in the middle (explain)
--Testcase 27:
EXPLAIN VERBOSE
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3;

-- select abs with arithmetic and tag in the middle (result)
--Testcase 28:
SELECT * FROM (
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select with order by limit (explain)
--Testcase 29:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1;

-- select with order by limit (explain)
--Testcase 30:
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1;

-- select mixing with non pushdown func (all not pushdown, explain)
--Testcase 31:
EXPLAIN VERBOSE
SELECT abs(value1), sqrt(value2), upper(tag1) FROM s3;

-- select mixing with non pushdown func (result)
--Testcase 32:
SELECT * FROM (
SELECT abs(value1), sqrt(value2), upper(tag1) FROM s3
) AS t ORDER BY 1,2,3;

-- sqlite pushdown supported functions (explain)
--Testcase 33:
EXPLAIN VERBOSE
SELECT abs(value3), length(tag1), ltrim(str2), ltrim(str1, '-'), replace(str1, 'XYZ', 'ABC'), round(value3), rtrim(str1, '-'), rtrim(str2), substr(str1, 4), substr(str1, 4, 3) FROM s3;

-- sqlite pushdown supported functions (result)
--Testcase 34:
SELECT * FROM (
SELECT abs(value3), length(tag1), ltrim(str2), ltrim(str1, '-'), replace(str1, 'XYZ', 'ABC'), round(value3), rtrim(str1, '-'), rtrim(str2), substr(str1, 4), substr(str1, 4, 3) FROM s3
) AS t ORDER BY 1,2,3,4,5,6,7,8,9,10;

--Drop all foreign tables
--Testcase 35:
DROP FOREIGN TABLE s3__sqlite_svr__0;
--Testcase 36:
DROP SERVER sqlite_svr;
--Testcase 37:
DROP EXTENSION sqlite_fdw;

--Testcase 38:
DROP FOREIGN TABLE s3;
--Testcase 39:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_core_svr;
--Testcase 40:
DROP SERVER pgspider_core_svr;
--Testcase 41:
DROP EXTENSION pgspider_core_fdw;
