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
-- Data source: sqlite

--Testcase 6:
CREATE FOREIGN TABLE s3 (id text, time timestamp, tag1 text, value1 float, value2 int, value3 float, value4 int, str1 text, str2 text, __spd_url text) SERVER pgspider_core_svr;
--Testcase 7:
CREATE EXTENSION pgspider_fdw;
--Testcase 8:
CREATE SERVER pgspider_svr1 FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (host '127.0.0.1', port '5433', dbname 'postgres');
--Testcase 9:
CREATE USER MAPPING FOR CURRENT_USER SERVER pgspider_svr1;
--Testcase 10:
CREATE FOREIGN TABLE s3__pgspider_svr1__0 (id text, time timestamp, tag1 text, value1 float, value2 int, value3 float, value4 int, str1 text, str2 text, __spd_url text) SERVER pgspider_svr1 OPTIONS (table_name 's31sqlite');

--Testcase 11:
CREATE SERVER pgspider_svr2 FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (host '127.0.0.1', port '5434', dbname 'postgres');
--Testcase 12:
CREATE USER MAPPING FOR CURRENT_USER SERVER pgspider_svr2;
--Testcase 13:
CREATE FOREIGN TABLE s3__pgspider_svr2__0 (id text, time timestamp, tag1 text, value1 float, value2 int, value3 float, value4 int, str1 text, str2 text, __spd_url text) SERVER pgspider_svr2 OPTIONS (table_name 's32sqlite');

-- s3 (value1 as float8, value2 as bigint)
--Testcase 14:
\d s3;
--Testcase 15:
SELECT * FROM s3 ORDER BY 1,2,3,4,5,6,7,8,9,10;

-- select abs (builtin function, explain)
--Testcase 16:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 ORDER BY 1;

-- select abs (buitin function, result)
--Testcase 17:
SELECT * FROM (
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select abs (builtin function, not pushdown constraints, explain)
--Testcase 18:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select abs (builtin function, not pushdown constraints, result)
--Testcase 19:
SELECT * FROM (
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64'
) AS t ORDER BY 1,2,3,4;

-- select abs (builtin function, pushdown constraints, explain)
--Testcase 20:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select abs (builtin function, pushdown constraints, result)
--Testcase 21:
SELECT * FROM (
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200
) AS t ORDER BY 1,2,3,4;

-- select abs as nest function with agg (pushdown, explain)
--Testcase 22:
EXPLAIN VERBOSE
SELECT sum(value3),abs(sum(value3)) FROM s3 ORDER BY 1;

-- select abs as nest function with agg (pushdown, result)
--Testcase 23:
SELECT sum(value3),abs(sum(value3)) FROM s3 ORDER BY 1;

-- select abs with non pushdown func and explicit constant (explain)
--Testcase 24:
EXPLAIN VERBOSE
SELECT abs(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select abs with non pushdown func and explicit constant (result)
--Testcase 25:
SELECT * FROM (
SELECT abs(value3), pi(), 4.1 FROM s3
) AS t ORDER BY 1,2,3;

-- select abs with order by (explain)
--Testcase 26:
EXPLAIN VERBOSE
SELECT value1, abs(1-value1) FROM s3 ORDER BY abs(1-value1);

-- select abs with order by (result)
--Testcase 27:
SELECT value1, abs(1-value1) FROM s3 ORDER BY abs(1-value1);

-- select abs with order by index (result)
--Testcase 28:
SELECT value1, abs(1-value1) FROM s3 ORDER BY 2,1;

-- select abs with order by index (result)
--Testcase 29:
SELECT value1, abs(1-value1) FROM s3 ORDER BY 1,2;

-- select abs and as
--Testcase 30:
SELECT * FROM (
SELECT abs(value3) as abs1 FROM s3
) AS t ORDER BY 1;

-- select abs with arithmetic and tag in the middle (explain)
--Testcase 31:
EXPLAIN VERBOSE
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3 ORDER BY 1;

-- select abs with arithmetic and tag in the middle (result)
--Testcase 32:
SELECT * FROM (
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select with order by limit (explain)
--Testcase 33:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1;

-- select with order by limit (explain)
--Testcase 34:
SELECT * FROM (
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1
) AS t ORDER BY 1,2,3;

-- select mixing with non pushdown func (all not pushdown, explain)
--Testcase 35:
EXPLAIN VERBOSE
SELECT abs(value1), sqrt(value2), upper(tag1) FROM s3 ORDER BY 1;

-- select mixing with non pushdown func (result)
--Testcase 36:
SELECT * FROM (
SELECT abs(value1), sqrt(value2), upper(tag1) FROM s3
) AS t ORDER BY 1,2,3;

-- sqlite pushdown supported functions (explain)
--Testcase 37:
EXPLAIN VERBOSE
SELECT abs(value3), length(tag1), ltrim(str2), ltrim(str1, '-'), replace(str1, 'XYZ', 'ABC'), round(value3), rtrim(str1, '-'), rtrim(str2), substr(str1, 4), substr(str1, 4, 3) FROM s3 ORDER BY 1;

-- sqlite pushdown supported functions (result)
--Testcase 38:
SELECT * FROM (
SELECT abs(value3), length(tag1), ltrim(str2), ltrim(str1, '-'), replace(str1, 'XYZ', 'ABC'), round(value3), rtrim(str1, '-'), rtrim(str2), substr(str1, 4), substr(str1, 4, 3) FROM s3
) AS t ORDER BY 1,2,3,4,5,6,7,8,9,10;

--Drop all foreign tables
--Testcase 39:
DROP FOREIGN TABLE s3__pgspider_svr1__0;
--Testcase 40:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_svr1;
--Testcase 41:
DROP SERVER pgspider_svr1;

--Testcase 42:
DROP FOREIGN TABLE s3__pgspider_svr2__0;
--Testcase 43:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_svr2;
--Testcase 44:
DROP SERVER pgspider_svr2;

--Testcase 45:
DROP EXTENSION pgspider_fdw;

--Testcase 46:
DROP FOREIGN TABLE s3;
--Testcase 47:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_core_svr;
--Testcase 48:
DROP SERVER pgspider_core_svr;
--Testcase 49:
DROP EXTENSION pgspider_core_fdw;
