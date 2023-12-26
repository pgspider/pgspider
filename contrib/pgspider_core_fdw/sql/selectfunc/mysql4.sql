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
-- Data source: mysql

--Testcase 6:
CREATE FOREIGN TABLE s3 (id int, tag1 text, value1 float, value2 int, value3 float, value4 int, str1 text, str2 text, __spd_url text) SERVER pgspider_core_svr;
--Testcase 7:
CREATE FOREIGN TABLE ftextsearch (id int, content text, __spd_url text) SERVER pgspider_core_svr;
--Testcase 8:
CREATE EXTENSION pgspider_fdw;
--Testcase 9:
CREATE SERVER pgspider_svr1 FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (host '127.0.0.1', port '5433', dbname 'postgres');

--Testcase 10:
CREATE USER MAPPING FOR CURRENT_USER SERVER pgspider_svr1;
--Testcase 11:
CREATE FOREIGN TABLE s3__pgspider_svr1__0 (id int, tag1 text, value1 float, value2 int, value3 float, value4 int, str1 text, str2 text, __spd_url text) SERVER pgspider_svr1 OPTIONS (table_name 's31mysql');

--Testcase 12:
CREATE SERVER pgspider_svr2 FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (host '127.0.0.1', port '5434', dbname 'postgres');
--Testcase 13:
CREATE USER MAPPING FOR CURRENT_USER SERVER pgspider_svr2;
--Testcase 14:
CREATE FOREIGN TABLE s3__pgspider_svr2__0 (id int, tag1 text, value1 float, value2 int, value3 float, value4 int, str1 text, str2 text, __spd_url text) SERVER pgspider_svr2 OPTIONS (table_name 's32mysql');

--Testcase 15:
CREATE FOREIGN TABLE ftextsearch__pgspider_svr1__0 (id int, content text) SERVER pgspider_svr1 OPTIONS (table_name 'ftextsearch1');
--Testcase 16:
CREATE FOREIGN TABLE ftextsearch__pgspider_svr2__0 (id int, content text) SERVER pgspider_svr2 OPTIONS (table_name 'ftextsearch2');

-- s3 (value1 as float8, value2 as bigint)
--Testcase 17:
\d s3;
--Testcase 18:
SELECT * FROM s3 ORDER BY 1,2,3,4,5,6,7,8,9;

-- select float8() (not pushdown, remove float8, explain)
--Testcase 19:
EXPLAIN VERBOSE
SELECT float8(value1), float8(value2), float8(value3), float8(value4) FROM s3 ORDER BY 1,2,3,4;

-- select float8() (not pushdown, remove float8, result)
--Testcase 20:
SELECT float8(value1), float8(value2), float8(value3), float8(value4) FROM s3 ORDER BY 1,2,3,4;

-- select abs (builtin function, explain)
--Testcase 21:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 ORDER BY 1,2,3,4;

-- select abs (buitin function, result)
--Testcase 22:
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 ORDER BY 1,2,3,4;

-- select abs (builtin function, not pushdown constraints, explain)
--Testcase 23:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1,2,3,4;

-- select abs (builtin function, not pushdown constraints, result)
--Testcase 24:
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1,2,3,4;

-- select abs (builtin function, pushdown constraints, explain)
--Testcase 25:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200 ORDER BY 1,2,3,4;

-- select abs (builtin function, pushdown constraints, result)
--Testcase 26:
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200 ORDER BY 1,2,3,4;

-- select log (builtin function, need to swap arguments, numeric cast, explain)
-- log_<base>(v) : postgresql (base, v), influxdb (v, base), mysql (base, v)
--Testcase 27:
EXPLAIN VERBOSE
SELECT value1, log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1 ORDER BY 1,2;

-- select log (builtin function, need to swap arguments, numeric cast, result)
--Testcase 28:
SELECT value1, log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1 ORDER BY 1,2;

-- select log (builtin function, need to swap arguments, float8, explain)
--Testcase 29:
EXPLAIN VERBOSE
SELECT value1, log(value1::numeric, 0.1) FROM s3 WHERE value1 != 1 ORDER BY 1,2;

-- select log (builtin function, need to swap arguments, float8, result)
--Testcase 30:
SELECT value1, log(value1::numeric, 0.1) FROM s3 WHERE value1 != 1 ORDER BY 1,2;

-- select log (builtin function, need to swap arguments, bigint, explain)
--Testcase 31:
EXPLAIN VERBOSE
SELECT value1, log(value2::numeric, 3) FROM s3 WHERE value1 != 1 ORDER BY 1,2;

-- select log (builtin function, need to swap arguments, bigint, result)
--Testcase 32:
SELECT value1, log(value2::numeric, 3) FROM s3 WHERE value1 != 1 ORDER BY 1,2;

-- select log (builtin function, need to swap arguments, mix type, explain)
--Testcase 33:
EXPLAIN VERBOSE
SELECT value1, log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1 ORDER BY 1,2;

-- select log (builtin function, need to swap arguments, mix type, result)
--Testcase 34:
SELECT value1, log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1 ORDER BY 1,2;

-- select log(v) -- built in function
-- log(v): postgreSQL base 10 logarithm
--Testcase 35:
EXPLAIN VERBOSE
SELECT log(value2) FROM s3 WHERE value1 != 1 ORDER BY 1;
--Testcase 36:
SELECT log(value2) FROM s3 WHERE value1 != 1 ORDER BY 1;

-- select log (builtin function, explain)
--Testcase 37:
EXPLAIN VERBOSE
SELECT log(value1), log(value2), log(0.5) FROM s3 ORDER BY 1,2,3;

-- select log (builtin function, result)
--Testcase 38:
SELECT log(value1), log(value2), log(0.5) FROM s3 ORDER BY 1,2,3;

-- select log (builtin function, not pushdown constraints, explain)
--Testcase 39:
EXPLAIN VERBOSE
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select log (builtin function, not pushdown constraints, result)
--Testcase 40:
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select log (builtin function, pushdown constraints, explain)
--Testcase 41:
EXPLAIN VERBOSE
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE value2 != 200;

-- select log (builtin function, pushdown constraints, result)
--Testcase 42:
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE value2 != 200;

-- select log (builtin function, log in constraints, explain)
--Testcase 43:
EXPLAIN VERBOSE
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE log(value1) != 1 ORDER BY 1,2,3;

-- select log (builtin function, log in constraints, result)
--Testcase 44:
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE log(value1) != 1 ORDER BY 1,2,3;

-- select log (builtin function, log in constraints, explain)
--Testcase 45:
EXPLAIN VERBOSE
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE log(5) > value1;

-- select log (builtin function, log in constraints, result)
--Testcase 46:
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE log(5) > value1;

-- select log as nest function with agg (pushdown, explain)
--Testcase 47:
EXPLAIN VERBOSE
SELECT sum(value3),log(sum(value2)) FROM s3;

-- select log as nest function with agg (pushdown, result)
--Testcase 48:
SELECT sum(value3),log(sum(value2)) FROM s3;

-- select log as nest with log2 (pushdown, explain)
--Testcase 49:
EXPLAIN VERBOSE
SELECT value1, log(log2(value1)),log(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select log as nest with log2 (pushdown, result)
--Testcase 50:
SELECT value1, log(log2(value1)),log(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select log with non pushdown func and explicit constant (explain)
--Testcase 51:
EXPLAIN VERBOSE
SELECT log(value2), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select log with non pushdown func and explicit constant (result)
--Testcase 52:
SELECT log(value2), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select log with order by (explain)
--Testcase 53:
EXPLAIN VERBOSE
SELECT value3, log(1-value3) FROM s3 ORDER BY log(1-value3);

-- select log with order by (result)
--Testcase 54:
SELECT value3, log(1-value3) FROM s3 ORDER BY log(1-value3);

-- select log with order by index (result)
--Testcase 55:
SELECT value3, log(1-value3) FROM s3 ORDER BY 2,1;

-- select log with order by index (result)
--Testcase 56:
SELECT value3, log(1-value3) FROM s3 ORDER BY 1,2;

-- select log with group by (explain)
--Testcase 57:
EXPLAIN VERBOSE
SELECT count(value1), log(1-value3) FROM s3 GROUP BY log(1-value3) ORDER BY 1,2;

-- select log with group by (result)
--Testcase 58:
SELECT count(value1), log(1-value3) FROM s3 GROUP BY log(1-value3) ORDER BY 1,2;

-- select log with group by index (result)
--Testcase 59:
SELECT value1, log(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select log with group by index (result)
--Testcase 60:
SELECT value1, log(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select log with group by having (explain)
--Testcase 61:
EXPLAIN VERBOSE
SELECT count(value1), log(1-value3) FROM s3 GROUP BY log(1-value3) HAVING log(avg(value1)) > 0 ORDER BY 1,2;

-- select log with group by having (result)
--Testcase 62:
SELECT count(value1), log(1-value3) FROM s3 GROUP BY log(1-value3) HAVING log(avg(value1)) > 0 ORDER BY 1,2;

-- select log with group by index having (result)
--Testcase 63:
SELECT value3, log(1-value3) FROM s3 GROUP BY 2,1 HAVING log(1-value3) < 0;

-- select log with group by index having (result)
--Testcase 64:
SELECT value3, log(1-value3) FROM s3 GROUP BY 1,2 HAVING value3 > 1;

-- select log and as
--Testcase 65:
SELECT log(value1) as log1 FROM s3 ORDER BY 1;

-- select abs as nest function with agg (pushdown, explain)
--Testcase 66:
EXPLAIN VERBOSE
SELECT sum(value3),abs(sum(value3)) FROM s3;

-- select abs as nest function with agg (pushdown, result)
--Testcase 67:
SELECT sum(value3),abs(sum(value3)) FROM s3;

-- select abs as nest with log2 (pushdown, explain)
--Testcase 68:
EXPLAIN VERBOSE
SELECT value1, abs(log2(value1)),abs(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select abs as nest with log2 (pushdown, result)
--Testcase 69:
SELECT value1, abs(log2(value1)),abs(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select abs with non pushdown func and explicit constant (explain)
--Testcase 70:
EXPLAIN VERBOSE
SELECT abs(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select abs with non pushdown func and explicit constant (result)
--Testcase 71:
SELECT abs(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select sqrt as nest function with agg and explicit constant (pushdown, explain)
--Testcase 72:
EXPLAIN VERBOSE
SELECT sqrt(count(value1)), pi(), 4.1 FROM s3 ORDER BY 1;

-- select sqrt as nest function with agg and explicit constant (pushdown, result)
--Testcase 73:
SELECT sqrt(count(value1)), pi(), 4.1 FROM s3 ORDER BY 1;

-- select sqrt as nest function with agg and explicit constant and tag (error, explain)
--Testcase 74:
EXPLAIN VERBOSE
SELECT sqrt(count(value1)), pi(), 4.1, tag1 FROM s3;

-- select abs with order by (explain)
--Testcase 75:
EXPLAIN VERBOSE
SELECT value3, abs(1-value3) FROM s3 ORDER BY abs(1-value3);

-- select abs with order by (result)
--Testcase 76:
SELECT value3, abs(1-value3) FROM s3 ORDER BY abs(1-value3);

-- select abs with order by index (result)
--Testcase 77:
SELECT value3, abs(1-value3) FROM s3 ORDER BY 2,1;

-- select abs with order by index (result)
--Testcase 78:
SELECT value3, abs(1-value3) FROM s3 ORDER BY 1,2;

-- select abs and as
--Testcase 79:
SELECT abs(value3) as abs1 FROM s3 ORDER BY 1;

-- select abs with arithmetic and tag in the middle (explain)
--Testcase 80:
EXPLAIN VERBOSE
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3 ORDER BY 1;

-- select abs with arithmetic and tag in the middle (result)
--Testcase 81:
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3 ORDER BY 1,2,3,4;

-- select with order by limit (explain)
--Testcase 82:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1;

-- select with order by limit (explain)
--Testcase 83:
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1;

-- select mixing with non pushdown func (all not pushdown, explain)
--Testcase 84:
EXPLAIN VERBOSE
SELECT abs(value1), sqrt(value2), cosd(id+40) FROM s3 ORDER BY 1,2,3;

-- select mixing with non pushdown func (result)
--Testcase 85:
SELECT abs(value1), sqrt(value2), cosd(id+40) FROM s3 ORDER BY 1,2,3;

-- select conv (stub function, int column, explain)
--Testcase 86:
EXPLAIN VERBOSE
SELECT conv(id, 10, 2), id FROM s3 WHERE value2 != 100 ORDER BY id, conv(id, 10, 2);

-- select conv (stub function, int column, result)
--Testcase 87:
SELECT conv(id, 10, 2), id FROM s3 WHERE value2 != 100 ORDER BY id, conv(id, 10, 2);

-- select conv (stub function, text column, explain)
--Testcase 88:
EXPLAIN VERBOSE
SELECT conv(str1, 18, 8), str1 FROM s3 WHERE value2 != 200;

-- select conv (stub function, text column, result)
--Testcase 89:
SELECT conv(str1, 18, 8), str1 FROM s3 WHERE value2 != 200;

-- select conv (stub function, const integer, explain)
--Testcase 90:
EXPLAIN VERBOSE
SELECT conv(15, 16, 3), tag1 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select conv (stub function, const integer, result)
--Testcase 91:
SELECT conv(15, 16, 3), tag1 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select conv (stub function, const text, explain)
--Testcase 92:
EXPLAIN VERBOSE
SELECT conv('6hE', 30, -9), str2 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select conv (stub function, const text, explain)
--Testcase 93:
SELECT conv('6hE', 30, -9), str2 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select conv (stub function, calculate, explain)
--Testcase 94:
EXPLAIN VERBOSE
SELECT conv(value2 + '10', 10, 10), value2 FROM s3 WHERE value2 != 50 ORDER BY 1,2;

-- select conv (stub function, calculate, explain)
--Testcase 95:
SELECT conv(value2 + '10', 10, 10), value2 FROM s3 WHERE value2 != 50 ORDER BY 1,2;

-- conv() in where clause
-- where conv (stub function, int column, explain)
--Testcase 96:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE conv(value2,10,20) = '50';

-- where conv (stub function, int column, result)
--Testcase 97:
SELECT * FROM s3 WHERE conv(value2,10,20) = '50';

-- where conv (stub function, int column, explain)
--Testcase 98:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE conv(value2,10,20) != str1 ORDER BY 1,2;

-- where conv (stub function, int column, result)
--Testcase 99:
SELECT * FROM s3 WHERE conv(value2,10,20) != str1 ORDER BY 1,2;

-- order by conv  (stub function, int column)
-- select conv (stub function, text column, explain)
--Testcase 100:
EXPLAIN VERBOSE
SELECT conv(str1, 18, 8), str1 FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select conv (stub function, text column, result)
--Testcase 101:
SELECT conv(str1, 18, 8), str1 FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select crc32 (stub function, int column, explain)
--Testcase 102:
EXPLAIN VERBOSE
SELECT crc32(id), id FROM s3 WHERE value2 != 100 ORDER BY id, crc32(id);

-- select crc32 (stub function, int column, result)
--Testcase 103:
SELECT crc32(id), id FROM s3 WHERE value2 != 100 ORDER BY id, crc32(id);

-- select crc32 (stub function, int column, explain)
--Testcase 104:
EXPLAIN VERBOSE
SELECT crc32(id), id FROM s3 WHERE value2 = 100 ORDER BY id, crc32(id);

-- select crc32 (stub function, int column, result)
--Testcase 105:
SELECT crc32(id), id FROM s3 WHERE value2 = 100 ORDER BY id, crc32(id);

-- select crc32 (stub function, text column, explain)
--Testcase 106:
EXPLAIN VERBOSE
SELECT crc32(str1), str1 FROM s3 WHERE value2 != 200;

-- select crc32 (stub function, text column, result)
--Testcase 107:
SELECT crc32(str1), str1 FROM s3 WHERE value2 != 200;

-- select crc32 (stub function, const integer, explain)
--Testcase 108:
EXPLAIN VERBOSE
SELECT crc32(15), tag1 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select crc32 (stub function, const integer, result)
--Testcase 109:
SELECT crc32(15), tag1 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select crc32 (stub function, const text, explain)
--Testcase 110:
EXPLAIN VERBOSE
SELECT crc32('6hE'), str2 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select crc32 (stub function, const text, explain)
--Testcase 111:
SELECT crc32('6hE'), str2 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select crc32 (stub function, calculate, explain)
--Testcase 112:
EXPLAIN VERBOSE
SELECT crc32(value2 + '10'), value2 FROM s3 WHERE value2 != 50 ORDER BY 2,1;

-- select crc32 (stub function, calculate, explain)
--Testcase 113:
SELECT crc32(value2 + '10'), value2 FROM s3 WHERE value2 != 50 ORDER BY 2,1;

-- select crc32 (builtin function, explain)
--Testcase 114:
EXPLAIN VERBOSE
SELECT value1, crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select crc32 (builtin function, result)
--Testcase 115:
SELECT value1, crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select crc32 (builtin function, not pushdown constraints, explain)
--Testcase 116:
EXPLAIN VERBOSE
SELECT crc32(value1), crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select crc32 (builtin function, not pushdown constraints, result)
--Testcase 117:
SELECT crc32(value1), crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select crc32 (builtin function, pushdown constraints, explain)
--Testcase 118:
EXPLAIN VERBOSE
SELECT crc32(value1), crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE value2 != 200;

-- select crc32 (builtin function, pushdown constraints, result)
--Testcase 119:
SELECT crc32(value1), crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE value2 != 200;

-- select crc32 (builtin function, crc32 in constraints, explain)
--Testcase 120:
EXPLAIN VERBOSE
SELECT value1, crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE crc32(value1) != 1 ORDER BY 1,2,3,4,5;

-- select crc32 (builtin function, crc32 in constraints, result)
--Testcase 121:
SELECT value1, crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE crc32(value1) != 1 ORDER BY 1,2,3,4,5;

-- select crc32 (builtin function, crc32 in constraints, explain)
--Testcase 122:
EXPLAIN VERBOSE
SELECT value1, crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE crc32(0.5) > value1 ORDER BY 1,2,3,4,5;

-- select crc32 (builtin function, crc32 in constraints, result)
--Testcase 123:
SELECT value1, crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE crc32(0.5) > value1 ORDER BY 1,2,3,4,5;

-- select crc32 as nest function with agg (not pushdown, explain)
--Testcase 124:
EXPLAIN VERBOSE
SELECT sum(value3),crc32(sum(value3)) FROM s3;

-- select crc32 as nest function with agg (not pushdown, error)
--Testcase 125:
SELECT sum(value3),crc32(sum(value3)) FROM s3;

-- select crc32 as nest with log2 (pushdown, explain)
--Testcase 126:
EXPLAIN VERBOSE
SELECT value1, crc32(log2(value1)),crc32(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select crc32 as nest with log2 (pushdown, result)
--Testcase 127:
SELECT value1, crc32(log2(value1)),crc32(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select crc32 with non pushdown func and explicit conscrc32t (explain)
--Testcase 128:
EXPLAIN VERBOSE
SELECT value1, crc32(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select crc32 with non pushdown func and explicit conscrc32t (result)
--Testcase 129:
SELECT value1, crc32(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select crc32 with order by (explain)
--Testcase 130:
EXPLAIN VERBOSE
SELECT value3, crc32(1-value3) FROM s3 ORDER BY crc32(1-value3);

-- select crc32 with order by (result)
--Testcase 131:
SELECT value3, crc32(1-value3) FROM s3 ORDER BY crc32(1-value3);

-- select crc32 with order by index (result)
--Testcase 132:
SELECT value3, crc32(1-value3) FROM s3 ORDER BY 2,1;

-- select crc32 with order by index (result)
--Testcase 133:
SELECT value3, crc32(1-value3) FROM s3 ORDER BY 1,2;

-- select crc32 with group by (explain)
--Testcase 134:
EXPLAIN VERBOSE
SELECT value1, crc32(1-value3) FROM s3 GROUP BY value1, crc32(1-value3) ORDER BY 1,2;

-- select crc32 with group by (result)
--Testcase 135:
SELECT value1, crc32(1-value3) FROM s3 GROUP BY value1,crc32(1-value3) ORDER BY 1,2;

-- select crc32 with group by index (result)
--Testcase 136:
SELECT value1, crc32(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select crc32 with group by index (result)
--Testcase 137:
SELECT value1, crc32(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select crc32 with group by having (explain)
--Testcase 138:
EXPLAIN VERBOSE
SELECT value1, crc32(1-value3) FROM s3 GROUP BY value1, crc32(1-value3) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select crc32 with group by having (result)
--Testcase 139:
SELECT value1, crc32(1-value3) FROM s3 GROUP BY value1, crc32(1-value3) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select crc32 with group by index having (result)
--Testcase 140:
SELECT value3, crc32(1-value3) FROM s3 GROUP BY 1,2 HAVING value3 > 1;

-- select crc32 and as
--Testcase 141:
SELECT value1, crc32(value3) as crc321 FROM s3 ORDER BY 1,2;

-- select log10 (builtin function, explain)
--Testcase 142:
EXPLAIN VERBOSE
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 ORDER BY 1,2,3;

-- select log10 (builtin function, result)
--Testcase 143:
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 ORDER BY 1,2,3;

-- select log10 (builtin function, not pushdown constraints, explain)
--Testcase 144:
EXPLAIN VERBOSE
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select log10 (builtin function, not pushdown constraints, result)
--Testcase 145:
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select log10 (builtin function, pushdown constraints, explain)
--Testcase 146:
EXPLAIN VERBOSE
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE value2 != 200;

-- select log10 (builtin function, pushdown constraints, result)
--Testcase 147:
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE value2 != 200;

-- select log10 (builtin function, log10 in constraints, explain)
--Testcase 148:
EXPLAIN VERBOSE
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE log10(value1) != 1 ORDER BY 1,2,3;

-- select log10 (builtin function, log10 in constraints, result)
--Testcase 149:
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE log10(value1) != 1 ORDER BY 1,2,3;

-- select log10 (builtin function, log10 in constraints, explain)
--Testcase 150:
EXPLAIN VERBOSE
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE log10(0.5) < value1 ORDER BY 1,2,3;

-- select log10 (builtin function, log10 in constraints, result)
--Testcase 151:
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE log10(0.5) < value1 ORDER BY 1,2,3;

-- select log10 as nest function with agg (pushdown, explain)
--Testcase 152:
EXPLAIN VERBOSE
SELECT sum(value3),log10(sum(value2)) FROM s3;

-- select log10 as nest function with agg (pushdown, result)
--Testcase 153:
SELECT sum(value3),log10(sum(value2)) FROM s3;

-- select log10 as nest with log2 (pushdown, explain)
--Testcase 154:
EXPLAIN VERBOSE
SELECT value1, log10(log2(value1)),log10(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select log10 as nest with log2 (pushdown, result)
--Testcase 155:
SELECT value1, log10(log2(value1)),log10(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select log10 with non pushdown func and explicit constant (explain)
--Testcase 156:
EXPLAIN VERBOSE
SELECT log10(value2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select log10 with non pushdown func and explicit constant (result)
--Testcase 157:
SELECT log10(value2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select log10 with order by (explain)
--Testcase 158:
EXPLAIN VERBOSE
SELECT value3, log10(1-value3) FROM s3 ORDER BY log10(1-value3);

-- select log10 with order by (result)
--Testcase 159:
SELECT value3, log10(1-value3) FROM s3 ORDER BY log10(1-value3);

-- select log10 with order by index (result)
--Testcase 160:
SELECT value3, log10(1-value3) FROM s3 ORDER BY 2,1;

-- select log10 with order by index (result)
--Testcase 161:
SELECT value3, log10(1-value3) FROM s3 ORDER BY 1,2;

-- select log10 with group by (explain)
--Testcase 162:
EXPLAIN VERBOSE
SELECT count(value1), log10(1-value1) FROM s3 GROUP BY log10(1-value1);

-- select log10 with group by (result)
--Testcase 163:
SELECT count(value1), log10(1-value3) FROM s3 GROUP BY log10(1-value3) ORDER BY 1,2;

-- select log10 with group by index (result)
--Testcase 164:
SELECT value1, log10(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select log10 with group by index (result)
--Testcase 165:
SELECT value1, log10(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select log10 with group by having (explain)
--Testcase 166:
EXPLAIN VERBOSE
SELECT count(value1), log10(1-value3) FROM s3 GROUP BY log10(1-value3) HAVING log10(avg(value1)) > 0 ORDER BY 1,2;

-- select log10 with group by having (result)
--Testcase 167:
SELECT count(value1), log10(1-value3) FROM s3 GROUP BY log10(1-value3) HAVING log10(avg(value1)) > 0 ORDER BY 1,2;

-- select log10 with group by index having (result)
--Testcase 168:
SELECT value3, log10(1-value3) FROM s3 GROUP BY 2,1 HAVING log10(1-value3) < 0;

-- select log10 with group by index having (result)
--Testcase 169:
SELECT value3, log10(1-value3) FROM s3 GROUP BY 1,2 HAVING value3 > 1;

-- select log10 and as
--Testcase 170:
SELECT value1, log10(value1) as log101 FROM s3 ORDER BY 1,2;

-- select log2 (builtin function, explain)
--Testcase 171:
EXPLAIN VERBOSE
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select log2 (builtin function, result)
--Testcase 172:
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select log2 (builtin function, not pushdown constraints, explain)
--Testcase 173:
EXPLAIN VERBOSE
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select log2 (builtin function, not pushdown constraints, result)
--Testcase 174:
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select log2 (builtin function, pushdown constraints, explain)
--Testcase 175:
EXPLAIN VERBOSE
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE value2 != 200;

-- select log2 (builtin function, pushdown constraints, result)
--Testcase 176:
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE value2 != 200;

-- select log2 (builtin function, log2 in constraints, explain)
--Testcase 177:
EXPLAIN VERBOSE
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE log2(value1) != 1 ORDER BY 1,2,3,4,5;

-- select log2 (builtin function, log2 in constraints, result)
--Testcase 178:
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE log2(value1) != 1 ORDER BY 1,2,3,4,5;

-- select log2 (builtin function, log2 in constraints, explain)
--Testcase 179:
EXPLAIN VERBOSE
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE log2(0.5) < value1 ORDER BY 1,2,3,4,5;

-- select log2 (builtin function, log2 in constraints, result)
--Testcase 180:
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE log2(0.5) < value1 ORDER BY 1,2,3,4,5;

-- select log2 as nest function with agg (not pushdown, explain)
--Testcase 181:
EXPLAIN VERBOSE
SELECT sum(value3),log2(sum(value3)) FROM s3;

-- select log2 as nest function with agg (not pushdown, error)
--Testcase 182:
SELECT sum(value3),log2(sum(value3)) FROM s3;

-- select log2 as nest with log2 (pushdown, explain)
--Testcase 183:
EXPLAIN VERBOSE
SELECT value1, log2(log2(value1)),log2(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select log2 as nest with log2 (pushdown, result)
--Testcase 184:
SELECT value1, log2(log2(value1)),log2(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select log2 with non pushdown func and explicit constant (explain)
--Testcase 185:
EXPLAIN VERBOSE
SELECT value1, log2(value3 + 1), pi(), 4.1 FROM s3 ORDER BY 1,2,3,4;

-- select log2 with non pushdown func and explicit constant (result)
--Testcase 186:
SELECT value1, log2(value3 + 1), pi(), 4.1 FROM s3 ORDER BY 1,2,3,4;

-- select log2 with order by (explain)
--Testcase 187:
EXPLAIN VERBOSE
SELECT value3, log2(1-value3) FROM s3 ORDER BY log2(1-value3);

-- select log2 with order by (result)
--Testcase 188:
SELECT value3, log2(1-value3) FROM s3 ORDER BY log2(1-value3);

-- select log2 with order by index (result)
--Testcase 189:
SELECT value3, log2(1-value3) FROM s3 ORDER BY 2,1;

-- select log2 with order by index (result)
--Testcase 190:
SELECT value3, log2(1-value3) FROM s3 ORDER BY 1,2;

-- select log2 with group by (explain)
--Testcase 191:
EXPLAIN VERBOSE
SELECT count(value1), log2(1-value3) FROM s3 GROUP BY log2(1-value3) ORDER BY 1,2;

-- select log2 with group by (result)
--Testcase 192:
SELECT count(value1), log2(1-value3) FROM s3 GROUP BY log2(1-value3) ORDER BY 1,2;

-- select log2 with group by index (result)
--Testcase 193:
SELECT value1, log2(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select log2 with group by index (result)
--Testcase 194:
SELECT value1, log2(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select log2 with group by having (explain)
--Testcase 195:
EXPLAIN VERBOSE
SELECT count(value1), log2(1-value3) FROM s3 GROUP BY log2(1-value3) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select log2 with group by having (result)
--Testcase 196:
SELECT count(value1), log2(1-value3) FROM s3 GROUP BY log2(1-value3) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select log2 with group by index having (result)
--Testcase 197:
SELECT value1, log2(1-value1) FROM s3 GROUP BY 1,2 HAVING value1 < 1 ORDER BY 1,2 DESC;

-- select log2 and as (return NULL with negative number)
--Testcase 198:
SELECT value1, value3 + 1, log2(value3 + 1) as log21 FROM s3 ORDER BY 1,2,3;

-- select pi (builtin function, explain)
--Testcase 199:
EXPLAIN VERBOSE
SELECT pi() FROM s3 WHERE value2 != 200 LIMIT 1;

-- select pi (builtin function, result)
--Testcase 200:
SELECT pi() FROM s3 WHERE value2 != 200 LIMIT 1;

-- where pi (builtin function)
--Testcase 201:
EXPLAIN VERBOSE
SELECT id FROM s3 WHERE pi() > id ORDER BY 1 LIMIT 1;
--Testcase 202:
SELECT id FROM s3 WHERE pi() > id ORDER BY 1 LIMIT 1;

-- select pi (stub function, explain)
--Testcase 203:
EXPLAIN VERBOSE
SELECT mysql_pi() FROM s3 WHERE value2 != 200 LIMIT 1;

-- select pi (stub function, result)
--Testcase 204:
SELECT mysql_pi() FROM s3 WHERE value2 != 200 LIMIT 1;

-- where pi (stub function)
--Testcase 205:
EXPLAIN VERBOSE
SELECT value1 FROM s3 WHERE mysql_pi() > value1 ORDER BY 1 LIMIT 1;
--Testcase 206:
SELECT value1 FROM s3 WHERE mysql_pi() > value1 ORDER BY 1 LIMIT 1;

-- where pi (stub function) order by
--Testcase 207:
EXPLAIN VERBOSE
SELECT value1 FROM s3 WHERE mysql_pi() > value1 ORDER BY 1;
--Testcase 208:
SELECT value1 FROM s3 WHERE mysql_pi() > value1 ORDER BY 1;

-- slect stub function, order by pi (stub function)
--Testcase 209:
EXPLAIN VERBOSE
SELECT mysql_pi(), log2(value1) FROM s3 ORDER BY 1,2;
--Testcase 210:
SELECT mysql_pi(), log2(value1) FROM s3 ORDER BY 1,2;

-- select pow (builtin function, explain)
--Testcase 211:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 ORDER BY 1,2,3,4;

-- select pow (builtin function, result)
--Testcase 212:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 ORDER BY 1,2,3,4;

-- select pow (builtin function, not pushdown constraints, explain)
--Testcase 213:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE to_hex(value2) != '64';

-- select pow (builtin function, not pushdown constraints, result)
--Testcase 214:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE to_hex(value2) != '64';

-- select pow (builtin function, pushdown constraints, explain)
--Testcase 215:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE value2 != 200;

-- select pow (builtin function, pushdown constraints, result)
--Testcase 216:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE value2 != 200;

-- select pow as nest function with agg (pushdown, explain)
--Testcase 217:
EXPLAIN VERBOSE
SELECT sum(value3),pow(sum(value3), 2) FROM s3;

-- select pow as nest function with agg (pushdown, result)
--Testcase 218:
SELECT sum(value3),pow(sum(value3), 2) FROM s3;

-- select pow as nest with log2 (pushdown, explain)
--Testcase 219:
EXPLAIN VERBOSE
SELECT value1, pow(log2(value1), 2),pow(log2(1/value1), 2) FROM s3 ORDER BY 1,2,3;

-- select pow as nest with log2 (pushdown, result)
--Testcase 220:
SELECT value1, pow(log2(value1), 2),pow(log2(1/value1), 2) FROM s3 ORDER BY 1,2,3;

-- select pow with non pushdown func and explicit constant (explain)
--Testcase 221:
EXPLAIN VERBOSE
SELECT pow(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select pow with non pushdown func and explicit constant (result)
--Testcase 222:
SELECT pow(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select pow with order by (explain)
--Testcase 223:
EXPLAIN VERBOSE
SELECT value3, pow(1-value3, 2) FROM s3 ORDER BY pow(1-value3, 2);

-- select pow with order by (result)
--Testcase 224:
SELECT value3, pow(1-value3, 2) FROM s3 ORDER BY pow(1-value3, 2);

-- select pow with order by index (result)
--Testcase 225:
EXPLAIN VERBOSE
SELECT value3, pow(1-value3, 2) FROM s3 ORDER BY 2,1;

-- select pow with order by index (result)
--Testcase 226:
SELECT value3, pow(1-value3, 2) FROM s3 ORDER BY 1,2;

-- select pow and as
--Testcase 227:
SELECT pow(value3, 2) as pow1 FROM s3 ORDER BY 1;

-- We only test rand with constant and column because it will be stable
-- select rand (stub function, rand with column, explain)
--Testcase 228:
EXPLAIN VERBOSE
SELECT id, rand(id), rand(3) FROM s3 WHERE value2 != 200;

-- select rand (stub function, rand with column, result)
--Testcase 229:
SELECT id, rand(id), rand(3) FROM s3 WHERE value2 != 200;

-- rand() in WHERE clause only EXPLAIN, execute will return different result
--Testcase 230:
EXPLAIN VERBOSE
SELECT id, rand(id), rand(3), rand() FROM s3 WHERE rand() > 0.5;

-- select rand (stub function, explain)
--Testcase 231:
EXPLAIN VERBOSE
SELECT value1, rand(value1), rand(value2), rand(value3), rand(value4) FROM s3 ORDER BY 1,2,3,4,5;

-- select rand (stub function, result)
--Testcase 232:
SELECT value1, rand(value1), rand(value2), rand(value3), rand(value4) FROM s3 ORDER BY 1,2,3,4,5;

-- select rand (stub function, not pushdown constraints, explain)
--Testcase 233:
EXPLAIN VERBOSE
SELECT rand(value1), rand(value2), rand(value3), rand(value4), rand(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select rand (stub function, not pushdown constraints, result)
--Testcase 234:
SELECT rand(value1), rand(value2), rand(value3), rand(value4), rand(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select rand (stub function, pushdown constraints, explain)
--Testcase 235:
EXPLAIN VERBOSE
SELECT rand(value1), rand(value2), rand(value3), rand(value4), rand(0.5) FROM s3 WHERE value2 != 200;

-- select rand (stub function, pushdown constraints, result)
--Testcase 236:
SELECT rand(value1), rand(value2), rand(value3), rand(value4), rand(0.5) FROM s3 WHERE value2 != 200;

-- select rand (stub function, rand in constraints, explain)
--Testcase 237:
EXPLAIN VERBOSE
SELECT value1, rand(value1), rand(value2), rand(value3), rand(value4) FROM s3 WHERE rand(value1) != 1 ORDER BY 1,2,3,4,5;

-- select rand (stub function, rand in constraints, result)
--Testcase 238:
SELECT value1, rand(value1), rand(value2), rand(value3), rand(value4) FROM s3 WHERE rand(value1) != 1 ORDER BY 1,2,3,4,5;

-- select rand (stub function, rand in constraints, explain)
--Testcase 239:
EXPLAIN VERBOSE
SELECT value1, rand(value1), rand(value2), rand(value3), rand(value4) FROM s3 WHERE rand(0.5) > value1 - 1 ORDER BY 1,2,3,4,5;

-- select rand (stub function, rand in constraints, result)
--Testcase 240:
SELECT value1, rand(value1), rand(value2), rand(value3), rand(value4) FROM s3 WHERE rand(0.5) > value1 - 1 ORDER BY 1,2,3,4,5;

-- select rand as nest function with agg (not pushdown, explain)
--Testcase 241:
EXPLAIN VERBOSE
SELECT sum(value3),rand(sum(value3)) FROM s3;

-- select rand as nest function with agg (not pushdown, error)
--Testcase 242:
SELECT sum(value3),rand(sum(value3)) FROM s3;

-- select rand as nest with log2 (pushdown, explain)
--Testcase 243:
EXPLAIN VERBOSE
SELECT value1, rand(log2(value1)),rand(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select rand as nest with log2 (pushdown, result)
--Testcase 244:
SELECT value1, rand(log2(value1)),rand(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select rand with non pushdown func and explicit constant (explain)
--Testcase 245:
EXPLAIN VERBOSE
SELECT value1, rand(value3), pi(), 4.1 FROM s3 ORDER BY 1,2,3;

-- select rand with non pushdown func and explicit constant (result)
--Testcase 246:
SELECT value1, rand(value3), pi(), 4.1 FROM s3 ORDER BY 1,2,3;

-- select rand with order by (explain)
--Testcase 247:
EXPLAIN VERBOSE
SELECT value3, rand(1-value3) FROM s3 ORDER BY rand(1-value3);

-- select rand with order by (result)
--Testcase 248:
SELECT value3, rand(1-value3) FROM s3 ORDER BY rand(1-value3);

-- select rand with order by index (result)
--Testcase 249:
SELECT value3, rand(1-value3) FROM s3 ORDER BY 2,1;

-- select rand with order by index (result)
--Testcase 250:
SELECT value3, rand(1-value3) FROM s3 ORDER BY 1,2;

-- select rand with group by (explain)
--Testcase 251:
EXPLAIN VERBOSE
SELECT value1, rand(1-value3) FROM s3 GROUP BY value1, rand(1-value3) ORDER BY 1,2;

-- select rand with group by (result)
--Testcase 252:
SELECT value1, rand(1-value3) FROM s3 GROUP BY value1, rand(1-value3) ORDER BY 1,2;

-- select rand with group by index (result)
--Testcase 253:
SELECT value1, rand(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select rand with group by index (result)
--Testcase 254:
SELECT value1, rand(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select rand with group by having (explain)
--Testcase 255:
EXPLAIN VERBOSE
SELECT value1, rand(1-value3) FROM s3 GROUP BY value1, rand(1-value3) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select rand with group by having (result)
--Testcase 256:
SELECT value1, rand(1-value3) FROM s3 GROUP BY value1, rand(1-value3) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select rand with group by index having (result)
--Testcase 257:
SELECT value1, rand(1-value1) FROM s3 GROUP BY 1,2 HAVING value1 < 1 ORDER BY 1,2;

-- select rand and as
--Testcase 258:
SELECT value1, rand(value3) as rand1 FROM s3 ORDER BY 1,2;

-- select truncate (stub function, explain)
--Testcase 259:
EXPLAIN VERBOSE
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 ORDER BY 1,2,3,4,5;

-- select truncate (stub function, result)
--Testcase 260:
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 ORDER BY 1,2,3,4,5;

-- select truncate (stub function, not pushdown constraints, explain)
--Testcase 261:
EXPLAIN VERBOSE
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select truncate (stub function, not pushdown constraints, result)
--Testcase 262:
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select truncate (stub function, pushdown constraints, explain)
--Testcase 263:
EXPLAIN VERBOSE
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE value2 != 200;

-- select truncate (stub function, pushdown constraints, result)
--Testcase 264:
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE value2 != 200;

-- select truncate (stub function, truncate in constraints, explain)
--Testcase 265:
EXPLAIN VERBOSE
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE truncate(value1, 2) != 1 ORDER BY 1,2,3,4,5;

-- select truncate (stub function, truncate in constraints, result)
--Testcase 266:
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE truncate(value1, 2) != 1 ORDER BY 1,2,3,4,5;

-- select truncate (stub function, truncate in constraints, explain)
--Testcase 267:
EXPLAIN VERBOSE
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE truncate(5, 2) > value1 ORDER BY 1,2,3,4,5;

-- select truncate (stub function, truncate in constraints, result)
--Testcase 268:
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE truncate(5, 2) > value1 ORDER BY 1,2,3,4,5;

-- select truncate as nest function with agg (not pushdown, explain)
--Testcase 269:
EXPLAIN VERBOSE
SELECT sum(value3),truncate(sum(value3), 2) FROM s3;

-- select truncate as nest function with agg (not pushdown, error)
--Testcase 270:
SELECT sum(value3),truncate(sum(value3), 2) FROM s3;

-- select truncate as nest with log2 (pushdown, explain)
--Testcase 271:
EXPLAIN VERBOSE
SELECT truncate(log2(value1), 2),truncate(log2(1/value1), 2) FROM s3 ORDER BY 1,2;

-- select truncate as nest with log2 (pushdown, result)
--Testcase 272:
SELECT truncate(log2(value1), 2),truncate(log2(1/value1), 2) FROM s3 ORDER BY 1,2;

-- select truncate with non pushdown func and explicit constant (explain)
--Testcase 273:
EXPLAIN VERBOSE
SELECT truncate(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select truncate with non pushdown func and explicit constant (result)
--Testcase 274:
SELECT truncate(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select truncate with order by (explain)
--Testcase 275:
EXPLAIN VERBOSE
SELECT value3, truncate(1-value3, 2) FROM s3 ORDER BY truncate(1-value3, 2);

-- select truncate with order by (result)
--Testcase 276:
SELECT value3, truncate(1-value3, 2) FROM s3 ORDER BY truncate(1-value3, 2);

-- select truncate with order by index (result)
--Testcase 277:
SELECT value3, truncate(1-value3, 2) FROM s3 ORDER BY 2,1;

-- select truncate with order by index (result)
--Testcase 278:
SELECT value3, truncate(1-value3, 2) FROM s3 ORDER BY 1,2;

-- select truncate with group by (explain)
--Testcase 279:
EXPLAIN VERBOSE
SELECT count(value1), truncate(1-value3, 2) FROM s3 GROUP BY truncate(1-value3, 2) ORDER BY 1,2;

-- select truncate with group by (result)
--Testcase 280:
SELECT count(value1), truncate(1-value3, 2) FROM s3 GROUP BY truncate(1-value3, 2) ORDER BY 1,2;

-- select truncate with group by index (result)
--Testcase 281:
SELECT value3, truncate(1-value3, 2) FROM s3 GROUP BY 2,1 ORDER BY 2,1;

-- select truncate with group by index (result)
--Testcase 282:
SELECT value3, truncate(1-value3, 2) FROM s3 GROUP BY 1,2 ORDER BY 2,1;

-- select truncate with group by having (explain)
--Testcase 283:
EXPLAIN VERBOSE
SELECT count(value1), truncate(1-value1, 2) FROM s3 GROUP BY truncate(1-value1, 2) HAVING avg(value1) > 0;

-- select truncate with group by having (result)
--Testcase 284:
SELECT count(value1), truncate(1-value3, 2) FROM s3 GROUP BY truncate(1-value3, 2) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select truncate with group by index having (result)
--Testcase 285:
SELECT value3, truncate(1-value3, 2) FROM s3 GROUP BY 2,1 HAVING truncate(1-value3, 2) > 0 ORDER BY 2,1;

-- select truncate with group by index having (result)
--Testcase 286:
SELECT value3, truncate(1-value3, 2) FROM s3 GROUP BY 1,2 HAVING value3 > 1;

-- select truncate and as
--Testcase 287:
SELECT truncate(value3, 2) as truncate1 FROM s3 ORDER BY 1 DESC;

-- select round (builtin function, explain)
--Testcase 288:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select round (builtin function, result)
--Testcase 289:
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select round (builtin function, not pushdown constraints, explain)
--Testcase 290:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select round (builtin function, not pushdown constraints, result)
--Testcase 291:
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select round (builtin function, pushdown constraints, explain)
--Testcase 292:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE value2 != 200;

-- select round (builtin function, pushdown constraints, result)
--Testcase 293:
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE value2 != 200;

-- select round (builtin function, round in constraints, explain)
--Testcase 294:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE round(value1) != 1 ORDER BY 1,2,3,4,5;

-- select round (builtin function, round in constraints, result)
--Testcase 295:
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE round(value1) != 1 ORDER BY 1,2,3,4,5;

-- select round (builtin function, round in constraints, explain)
--Testcase 296:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE round(0.5) > value1;

-- select round (builtin function, round in constraints, result)
--Testcase 297:
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE round(0.5) > value1;

-- select round as nest function with agg (pushdown, explain)
--Testcase 298:
EXPLAIN VERBOSE
SELECT sum(value3),round(sum(value3)) FROM s3;

-- select round as nest function with agg (pushdown, result)
--Testcase 299:
SELECT sum(value3),round(sum(value3)) FROM s3;

-- select round as nest with log2 (pushdown, explain)
--Testcase 300:
EXPLAIN VERBOSE
SELECT round(log2(value1)),round(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select round as nest with log2 (pushdown, result)
--Testcase 301:
SELECT round(log2(value1)),round(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select round with non pushdown func and explicit constant (explain)
--Testcase 302:
EXPLAIN VERBOSE
SELECT round(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select round with non pushdown func and explicit constant (result)
--Testcase 303:
SELECT round(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select round with order by (explain)
--Testcase 304:
EXPLAIN VERBOSE
SELECT value1, round(1-value3) FROM s3 ORDER BY round(1-value3);

-- select round with order by (result)
--Testcase 305:
SELECT value1, round(1-value3) FROM s3 ORDER BY round(1-value3);

-- select round with order by index (result)
--Testcase 306:
SELECT value1, round(1-value3) FROM s3 ORDER BY 2,1;

-- select round with order by index (result)
--Testcase 307:
SELECT value1, round(1-value3) FROM s3 ORDER BY 1,2;

-- select round with group by (explain)
--Testcase 308:
EXPLAIN VERBOSE
SELECT count(value1), round(1-value3) FROM s3 GROUP BY round(1-value3) ORDER BY 2,1;

-- select round with group by (result)
--Testcase 309:
SELECT count(value1), round(1-value3) FROM s3 GROUP BY round(1-value3) ORDER BY 2,1;

-- select round with group by index (result)
--Testcase 310:
SELECT value1, round(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select round with group by index (result)
--Testcase 311:
SELECT value1, round(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select round with group by having (explain)
--Testcase 312:
EXPLAIN VERBOSE
SELECT count(value1), round(1-value3) FROM s3 GROUP BY round(1-value3) HAVING round(avg(value1)) > 0 ORDER BY 2,1;

-- select round with group by having (result)
--Testcase 313:
SELECT count(value1), round(1-value3) FROM s3 GROUP BY round(1-value3) HAVING round(avg(value1)) > 0 ORDER BY 2,1;

-- select round with group by index having (result)
--Testcase 314:
SELECT value1, round(1-value3) FROM s3 GROUP BY 2,1 HAVING round(1-value3) > 0 ORDER BY 1,2;

-- select round with group by index having (result)
--Testcase 315:
SELECT value1, round(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select round and as
--Testcase 316:
SELECT round(value3) as round1 FROM s3 ORDER BY 1 DESC;

-- select acos (builtin function, explain)
--Testcase 317:
EXPLAIN VERBOSE
SELECT value1, acos(value3), acos(0.5) FROM s3 ORDER BY 1,2,3;

-- select acos (builtin function, result)
--Testcase 318:
SELECT value1, acos(value3), acos(0.5) FROM s3 ORDER BY 1,2,3;

-- select acos (builtin function, not pushdown constraints, explain)
--Testcase 319:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select acos (builtin function, not pushdown constraints, result)
--Testcase 320:
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select acos (builtin function, pushdown constraints, explain)
--Testcase 321:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE value2 != 200;

-- select acos (builtin function, pushdown constraints, result)
--Testcase 322:
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE value2 != 200;

-- select acos (builtin function, acos in constraints, explain)
--Testcase 323:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE acos(value1) != 1;

-- select acos (builtin function, acos in constraints, result)
--Testcase 324:
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE acos(value1) != 1;

-- select acos (builtin function, acos in constraints, explain)
--Testcase 325:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE acos(0.5) > value1;

-- select acos (builtin function, acos in constraints, result)
--Testcase 326:
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE acos(0.5) > value1;

-- select acos as nest function with agg (pushdown, explain)
--Testcase 327:
EXPLAIN VERBOSE
SELECT sum(value1),acos(sum(value1)) FROM s3 WHERE value2 != 200;

-- select acos as nest function with agg (pushdown, result)
--Testcase 328:
SELECT sum(value3),acos(sum(value1)) FROM s3 WHERE value2 != 200;

-- select acos as nest with log2 (pushdown, explain)
--Testcase 329:
EXPLAIN VERBOSE
SELECT value1, acos(log2(value1)),acos(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select acos as nest with log2 (pushdown, result)
--Testcase 330:
SELECT value1, acos(log2(value1)),acos(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select acos with non pushdown func and explicit constant (explain)
--Testcase 331:
EXPLAIN VERBOSE
SELECT acos(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select acos with non pushdown func and explicit constant (result)
--Testcase 332:
SELECT acos(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select acos with order by (explain)
--Testcase 333:
EXPLAIN VERBOSE
SELECT value1, acos(1-value1) FROM s3 ORDER BY value1, acos(1-value1);

-- select acos with order by (result)
--Testcase 334:
SELECT value1, acos(1-value1) FROM s3 ORDER BY value1, acos(1-value1);

-- select acos with order by index (result)
--Testcase 335:
SELECT value1, acos(1-value1) FROM s3 ORDER BY 2,1;

-- select acos with order by index (result)
--Testcase 336:
SELECT value1, acos(1-value1) FROM s3 ORDER BY 1,2;

-- select acos with group by (explain)
--Testcase 337:
EXPLAIN VERBOSE
SELECT count(value1), acos(1-value1) FROM s3 GROUP BY acos(1-value1) ORDER BY 1,2;

-- select acos with group by (result)
--Testcase 338:
SELECT count(value1), acos(1-value1) FROM s3 GROUP BY acos(1-value1) ORDER BY 1,2;

-- select acos with group by index (result)
--Testcase 339:
SELECT value1, acos(1-value1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select acos with group by index (result)
--Testcase 340:
SELECT value1, acos(1-value1) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select acos with group by having (explain)
--Testcase 341:
EXPLAIN VERBOSE
SELECT count(value1), acos(1-value1) FROM s3 GROUP BY acos(1-value1) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select acos with group by having (result)
--Testcase 342:
SELECT count(value1), acos(1-value1) FROM s3 GROUP BY acos(1-value1) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select acos with group by index having (result)
--Testcase 343:
SELECT value1, acos(1-value1) FROM s3 GROUP BY 2,1 HAVING acos(1-value1) > 0 ORDER BY 1,2;

-- select acos with group by index having (result)
--Testcase 344:
SELECT value1, acos(1-value1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select acos and as
--Testcase 345:
SELECT acos(value3) as acos1 FROM s3 ORDER BY 1;

-- select asin (builtin function, explain)
--Testcase 346:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 ORDER BY 1,2,3;

-- select asin (builtin function, result)
--Testcase 347:
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 ORDER BY 1,2,3;

-- select asin (builtin function, not pushdown constraints, explain)
--Testcase 348:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select asin (builtin function, not pushdown constraints, result)
--Testcase 349:
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select asin (builtin function, pushdown constraints, explain)
--Testcase 350:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE value2 != 200;

-- select asin (builtin function, pushdown constraints, result)
--Testcase 351:
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE value2 != 200;

-- select asin (builtin function, asin in constraints, explain)
--Testcase 352:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE asin(value1) != 1;

-- select asin (builtin function, asin in constraints, result)
--Testcase 353:
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE asin(value1) != 1;

-- select asin (builtin function, asin in constraints, explain)
--Testcase 354:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE asin(0.5) > value1;

-- select asin (builtin function, asin in constraints, result)
--Testcase 355:
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE asin(0.5) > value1;

-- select asin as nest function with agg (pushdown, explain)
--Testcase 356:
EXPLAIN VERBOSE
SELECT sum(value3),asin(sum(value1)) FROM s3 WHERE value2 != 200;

-- select asin as nest function with agg (pushdown, result)
--Testcase 357:
SELECT sum(value3),asin(sum(value1)) FROM s3 WHERE value2 != 200;

-- select asin as nest with log2 (pushdown, explain)
--Testcase 358:
EXPLAIN VERBOSE
SELECT value1, asin(log2(value1)),asin(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select asin as nest with log2 (pushdown, result)
--Testcase 359:
SELECT value1, asin(log2(value1)),asin(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select asin with non pushdown func and explicit constant (explain)
--Testcase 360:
EXPLAIN VERBOSE
SELECT value1, asin(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select asin with non pushdown func and explicit constant (result)
--Testcase 361:
SELECT value1, asin(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select asin with order by (explain)
--Testcase 362:
EXPLAIN VERBOSE
SELECT value1, asin(1-value1) FROM s3 ORDER BY asin(1-value1);

-- select asin with order by (result)
--Testcase 363:
SELECT value1, asin(1-value1) FROM s3 ORDER BY asin(1-value1);

-- select asin with order by index (result)
--Testcase 364:
SELECT value1, asin(1-value1) FROM s3 ORDER BY 2,1;

-- select asin with order by index (result)
--Testcase 365:
SELECT value1, asin(1-value1) FROM s3 ORDER BY 1,2;

-- select asin with group by (explain)
--Testcase 366:
EXPLAIN VERBOSE
SELECT value1, asin(1-value1) FROM s3 GROUP BY value1, asin(1-value1) ORDER BY 1,2;

-- select asin with group by (result)
--Testcase 367:
SELECT value1, asin(1-value1) FROM s3 GROUP BY value1, asin(1-value1) ORDER BY 1,2;

-- select asin with group by index (result)
--Testcase 368:
SELECT value1, asin(1-value1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select asin with group by index (result)
--Testcase 369:
SELECT value1, asin(1-value1) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select asin with group by having (explain)
--Testcase 370:
EXPLAIN VERBOSE
SELECT value1, asin(1-value1) FROM s3 GROUP BY value1, asin(1-value1) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select asin with group by having (result)
--Testcase 371:
SELECT value1, asin(1-value1) FROM s3 GROUP BY value1, asin(1-value1) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select asin with group by index having (result)
--Testcase 372:
SELECT value1, asin(1-value1) FROM s3 GROUP BY 2,1 HAVING asin(1-value1) > 0 ORDER BY 1,2;

-- select asin with group by index having (result)
--Testcase 373:
SELECT value1, asin(1-value1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select asin and as
--Testcase 374:
SELECT value1, asin(value3) as asin1 FROM s3 ORDER BY 1,2;

-- select atan (builtin function, explain)
--Testcase 375:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select atan (builtin function, result)
--Testcase 376:
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select atan (builtin function, not pushdown constraints, explain)
--Testcase 377:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select atan (builtin function, not pushdown constraints, result)
--Testcase 378:
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select atan (builtin function, pushdown constraints, explain)
--Testcase 379:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE value2 != 200;

-- select atan (builtin function, pushdown constraints, result)
--Testcase 380:
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE value2 != 200;

-- select atan (builtin function, atan in constraints, explain)
--Testcase 381:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE atan(value1) != 1 ORDER BY 1,2,3,4,5;

-- select atan (builtin function, atan in constraints, result)
--Testcase 382:
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE atan(value1) != 1 ORDER BY 1,2,3,4,5;

-- select atan (builtin function, atan in constraints, explain)
--Testcase 383:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE atan(0.5) > value1;

-- select atan (builtin function, atan in constraints, result)
--Testcase 384:
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE atan(0.5) > value1;

-- select atan as nest function with agg (pushdown, explain)
--Testcase 385:
EXPLAIN VERBOSE
SELECT sum(value3),atan(sum(value3)) FROM s3;

-- select atan as nest function with agg (pushdown, result)
--Testcase 386:
SELECT sum(value3),atan(sum(value3)) FROM s3;

-- select atan as nest with log2 (pushdown, explain)
--Testcase 387:
EXPLAIN VERBOSE
SELECT atan(log2(value1)),atan(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select atan as nest with log2 (pushdown, result)
--Testcase 388:
SELECT atan(log2(value1)),atan(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select atan with non pushdown func and explicit constant (explain)
--Testcase 389:
EXPLAIN VERBOSE
SELECT atan(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select atan with non pushdown func and explicit constant (result)
--Testcase 390:
SELECT atan(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select atan with order by (explain)
--Testcase 391:
EXPLAIN VERBOSE
SELECT value1, atan(1-value3) FROM s3 ORDER BY atan(1-value3);

-- select atan with order by (result)
--Testcase 392:
SELECT value1, atan(1-value3) FROM s3 ORDER BY atan(1-value3);

-- select atan with order by index (result)
--Testcase 393:
EXPLAIN VERBOSE
SELECT value1, atan(1-value3) FROM s3 ORDER BY 2,1;

-- select atan with order by index (result)
--Testcase 394:
SELECT value1, atan(1-value3) FROM s3 ORDER BY 1,2;

-- select atan with group by (explain)
--Testcase 395:
EXPLAIN VERBOSE
SELECT count(value1), atan(1-value3) FROM s3 GROUP BY atan(1-value3) ORDER BY 1,2;

-- select atan with group by (result)
--Testcase 396:
SELECT count(value1), atan(1-value3) FROM s3 GROUP BY atan(1-value3) ORDER BY 1,2;

-- select atan with group by index (result)
--Testcase 397:
SELECT value1, atan(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select atan with group by index (result)
--Testcase 398:
SELECT value1, atan(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select atan with group by having (explain)
--Testcase 399:
EXPLAIN VERBOSE
SELECT count(value1), atan(1-value3) FROM s3 GROUP BY atan(1-value3) HAVING atan(avg(value1)) > 0 ORDER BY 1,2;

-- select atan with group by having (result)
--Testcase 400:
SELECT count(value1), atan(1-value3) FROM s3 GROUP BY atan(1-value3) HAVING atan(avg(value1)) > 0 ORDER BY 1,2;

-- select atan with group by index having (result)
--Testcase 401:
SELECT value1, atan(1-value3) FROM s3 GROUP BY 2,1 HAVING atan(1-value3) > 0 ORDER BY 1,2;

-- select atan with group by index having (result)
--Testcase 402:
SELECT value1, atan(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select atan and as
--Testcase 403:
SELECT atan(value3) as atan1 FROM s3 ORDER BY 1 DESC;

-- select atan2 (builtin function, explain)
--Testcase 404:
EXPLAIN VERBOSE
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 ORDER BY 1,2,3,4,5;

-- select atan2 (builtin function, result)
--Testcase 405:
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 ORDER BY 1,2,3,4,5;

-- select atan2 (builtin function, not pushdown constraints, explain)
--Testcase 406:
EXPLAIN VERBOSE
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select atan2 (builtin function, not pushdown constraints, result)
--Testcase 407:
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select atan2 (builtin function, pushdown constraints, explain)
--Testcase 408:
EXPLAIN VERBOSE
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE value2 != 200;

-- select atan2 (builtin function, pushdown constraints, result)
--Testcase 409:
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE value2 != 200;

-- select atan2 (builtin function, atan2 in constraints, explain)
--Testcase 410:
EXPLAIN VERBOSE
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE atan2(value1, 2) != 1 ORDER BY 1,2,3,4,5;

-- select atan2 (builtin function, atan2 in constraints, result)
--Testcase 411:
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE atan2(value1, 2) != 1 ORDER BY 1,2,3,4,5;

-- select atan2 (builtin function, atan2 in constraints, explain)
--Testcase 412:
EXPLAIN VERBOSE
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE atan2(5, 2) > value1 ORDER BY 1,2,3,4,5;

-- select atan2 (builtin function, atan2 in constraints, result)
--Testcase 413:
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE atan2(5, 2) > value1 ORDER BY 1,2,3,4,5;

-- select atan2 as nest function with agg (pushdown, explain)
--Testcase 414:
EXPLAIN VERBOSE
SELECT sum(value3),atan2(sum(value3), 2) FROM s3;

-- select atan2 as nest function with agg (pushdown, result)
--Testcase 415:
SELECT sum(value3),atan2(sum(value3), 2) FROM s3;

-- select atan2 as nest with log2 (pushdown, explain)
--Testcase 416:
EXPLAIN VERBOSE
SELECT atan2(log2(value1), 2),atan2(log2(1/value1), 2) FROM s3 ORDER BY 1,2;

-- select atan2 as nest with log2 (pushdown, result)
--Testcase 417:
SELECT atan2(log2(value1), 2),atan2(log2(1/value1), 2) FROM s3 ORDER BY 1,2;

-- select atan2 with non pushdown func and atan2licit constant (explain)
--Testcase 418:
EXPLAIN VERBOSE
SELECT atan2(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select atan2 with non pushdown func and atan2licit constant (result)
--Testcase 419:
SELECT atan2(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select atan2 with order by (explain)
--Testcase 420:
EXPLAIN VERBOSE
SELECT value1, atan2(1-value3, 2) FROM s3 ORDER BY atan2(1-value3, 2);

-- select atan2 with order by (result)
--Testcase 421:
SELECT value1, atan2(1-value3, 2) FROM s3 ORDER BY atan2(1-value3, 2);

-- select atan2 with order by index (result)
--Testcase 422:
SELECT value1, atan2(1-value3, 2) FROM s3 ORDER BY 2,1;

-- select atan2 with order by index (result)
--Testcase 423:
SELECT value1, atan2(1-value3, 2) FROM s3 ORDER BY 1,2;

-- select atan2 with group by (explain)
--Testcase 424:
EXPLAIN VERBOSE
SELECT count(value1), atan2(1-value3, 2) FROM s3 GROUP BY atan2(1-value3, 2) ORDER BY 1,2;

-- select atan2 with group by (result)
--Testcase 425:
SELECT count(value1), atan2(1-value3, 2) FROM s3 GROUP BY atan2(1-value3, 2) ORDER BY 1,2;

-- select atan2 with group by index (result)
--Testcase 426:
SELECT value1, atan2(1-value3, 2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select atan2 with group by index (result)
--Testcase 427:
SELECT value1, atan2(1-value3, 2) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select atan2 with group by having (explain)
--Testcase 428:
EXPLAIN VERBOSE
SELECT count(value1), atan2(1-value3, 2) FROM s3 GROUP BY atan2(1-value3, 2) HAVING atan2(avg(value1), 2) > 0 ORDER BY 1,2;

-- select atan2 with group by having (result)
--Testcase 429:
SELECT count(value1), atan2(1-value3, 2) FROM s3 GROUP BY atan2(1-value3, 2) HAVING atan2(avg(value1), 2) > 0 ORDER BY 1,2;

-- select atan2 with group by index having (result)
--Testcase 430:
SELECT value1, atan2(1-value3, 2) FROM s3 GROUP BY 2,1 HAVING atan2(1-value3, 2) > 0 ORDER BY 1,2;

-- select atan2 with group by index having (result)
--Testcase 431:
SELECT value1, atan2(1-value3, 2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select atan2 and as
--Testcase 432:
SELECT atan2(value3, 2) as atan21 FROM s3 ORDER BY 1 DESC;

-- select atan (stub function, explain)
--Testcase 433:
EXPLAIN VERBOSE
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 ORDER BY 1,2,3,4,5;

-- select atan (stub function, result)
--Testcase 434:
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 ORDER BY 1,2,3,4,5;

-- select atan (stub function, not pushdown constraints, explain)
--Testcase 435:
EXPLAIN VERBOSE
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select atan (stub function, not pushdown constraints, result)
--Testcase 436:
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select atan (stub function, pushdown constraints, explain)
--Testcase 437:
EXPLAIN VERBOSE
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE value2 != 200;

-- select atan (stub function, pushdown constraints, result)
--Testcase 438:
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE value2 != 200;

-- select atan (stub function, atan in constraints, explain)
--Testcase 439:
EXPLAIN VERBOSE
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE atan(value1, 2) != 1 ORDER BY 1,2,3,4,5;

-- select atan (stub function, atan in constraints, result)
--Testcase 440:
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE atan(value1, 2) != 1 ORDER BY 1,2,3,4,5;

-- select atan (stub function, atan in constraints, explain)
--Testcase 441:
EXPLAIN VERBOSE
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE atan(5, 2) > value1 ORDER BY 1,2,3,4,5;

-- select atan (stub function, atan in constraints, result)
--Testcase 442:
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE atan(5, 2) > value1 ORDER BY 1,2,3,4,5;

-- select atan as nest function with agg (not pushdown, explain)
--Testcase 443:
EXPLAIN VERBOSE
SELECT sum(value3),atan(sum(value3), 2) FROM s3;

-- select atan as nest function with agg (not pushdown, error)
--Testcase 444:
SELECT sum(value3),atan(sum(value3), 2) FROM s3;

-- select atan as nest with log2 (pushdown, explain)
--Testcase 445:
EXPLAIN VERBOSE
SELECT atan(log2(value1), 2),atan(log2(1/value1), 2) FROM s3 ORDER BY 1,2;

-- select atan as nest with log2 (pushdown, result)
--Testcase 446:
SELECT atan(log2(value1), 2),atan(log2(1/value1), 2) FROM s3 ORDER BY 1,2;

-- select atan with non pushdown func and atanlicit constant (explain)
--Testcase 447:
EXPLAIN VERBOSE
SELECT atan(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select atan with non pushdown func and atanlicit constant (result)
--Testcase 448:
SELECT atan(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select atan with order by (explain)
--Testcase 449:
EXPLAIN VERBOSE
SELECT value1, atan(1-value3, 2) FROM s3 ORDER BY atan(1-value3, 2);

-- select atan with order by (result)
--Testcase 450:
SELECT value1, atan(1-value3, 2) FROM s3 ORDER BY atan(1-value3, 2);

-- select atan with order by index (result)
--Testcase 451:
SELECT value1, atan(1-value3, 2) FROM s3 ORDER BY 2,1;

-- select atan with order by index (result)
--Testcase 452:
SELECT value1, atan(1-value3, 2) FROM s3 ORDER BY 1,2;

-- select atan with group by (explain)
--Testcase 453:
EXPLAIN VERBOSE
SELECT count(value1), atan(1-value3, 2) FROM s3 GROUP BY atan(1-value3, 2) ORDER BY 1,2;

-- select atan with group by (result)
--Testcase 454:
SELECT count(value1), atan(1-value3, 2) FROM s3 GROUP BY atan(1-value3, 2) ORDER BY 1,2;

-- select atan with group by index (result)
--Testcase 455:
SELECT value1, atan(1-value3, 2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select atan with group by index (result)
--Testcase 456:
SELECT value1, atan(1-value3, 2) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select atan with group by having (explain)
--Testcase 457:
EXPLAIN VERBOSE
SELECT count(value1), atan(1-value3, 2) FROM s3 GROUP BY atan(1-value3, 2) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select atan with group by having (result)
--Testcase 458:
SELECT count(value1), atan(1-value3, 2) FROM s3 GROUP BY atan(1-value3, 2) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select atan with group by index having (result)
--Testcase 459:
SELECT value3, atan(1-value3, 2) FROM s3 GROUP BY 2,1 HAVING atan(1-value3, 2) > 0 ORDER BY 2,1;

-- select atan with group by index having (result)
--Testcase 460:
SELECT value1, atan(1-value3, 2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select atan and as
--Testcase 461:
SELECT atan(value3, 2) as atan1 FROM s3 ORDER BY 1 DESC;

-- select ceil (builtin function, explain)
--Testcase 462:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select ceil (builtin function, result)
--Testcase 463:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select ceil (builtin function, not pushdown constraints, explain)
--Testcase 464:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select ceil (builtin function, not pushdown constraints, result)
--Testcase 465:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select ceil (builtin function, pushdown constraints, explain)
--Testcase 466:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE value2 != 200;

-- select ceil (builtin function, pushdown constraints, result)
--Testcase 467:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE value2 != 200;

-- select ceil (builtin function, ceil in constraints, explain)
--Testcase 468:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE ceil(value1) != 1;

-- select ceil (builtin function, ceil in constraints, result)
--Testcase 469:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE ceil(value1) != 1;

-- select ceil (builtin function, ceil in constraints, explain)
--Testcase 470:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE ceil(0.5) > value1;

-- select ceil (builtin function, ceil in constraints, result)
--Testcase 471:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE ceil(0.5) > value1;

-- select ceil as nest function with agg (pushdown, explain)
--Testcase 472:
EXPLAIN VERBOSE
SELECT sum(value3),ceil(sum(value3)) FROM s3;

-- select ceil as nest function with agg (pushdown, result)
--Testcase 473:
SELECT sum(value3),ceil(sum(value3)) FROM s3;

-- select ceil as nest with log2 (pushdown, explain)
--Testcase 474:
EXPLAIN VERBOSE
SELECT ceil(log2(value1)),ceil(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select ceil as nest with log2 (pushdown, result)
--Testcase 475:
SELECT ceil(log2(value1)),ceil(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select ceil with non pushdown func and explicit constant (explain)
--Testcase 476:
EXPLAIN VERBOSE
SELECT ceil(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select ceil with non pushdown func and explicit constant (result)
--Testcase 477:
SELECT ceil(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select ceil with order by (explain)
--Testcase 478:
EXPLAIN VERBOSE
SELECT value1, ceil(1-value3) FROM s3 ORDER BY ceil(1-value3);

-- select ceil with order by (result)
--Testcase 479:
SELECT value1, ceil(1-value3) FROM s3 ORDER BY ceil(1-value3);

-- select ceil with order by index (result)
--Testcase 480:
SELECT value1, ceil(1-value3) FROM s3 ORDER BY 2,1;

-- select ceil with order by index (result)
--Testcase 481:
SELECT value1, ceil(1-value3) FROM s3 ORDER BY 1,2;

-- select ceil with group by (explain)
--Testcase 482:
EXPLAIN VERBOSE
SELECT value1, ceil(1-value3) FROM s3 GROUP BY value1, ceil(1-value3) ORDER BY 1,2;

-- select ceil with group by (result)
--Testcase 483:
SELECT value1, ceil(1-value3) FROM s3 GROUP BY value1, ceil(1-value3) ORDER BY 1,2;

-- select ceil with group by index (result)
--Testcase 484:
SELECT value1, ceil(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select ceil with group by index (result)
--Testcase 485:
SELECT value1, ceil(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select ceil with group by having (explain)
--Testcase 486:
EXPLAIN VERBOSE
SELECT value1, ceil(1-value3) FROM s3 GROUP BY value1, ceil(1-value3) HAVING ceil(avg(value1)) > 0 ORDER BY 1,2;

-- select ceil with group by having (result)
--Testcase 487:
SELECT value1, ceil(1-value3) FROM s3 GROUP BY value1, ceil(1-value3) HAVING ceil(avg(value1)) > 0 ORDER BY 1,2;

-- select ceil with group by index having (result)
--Testcase 488:
SELECT value1, ceil(1-value3) FROM s3 GROUP BY 2,1 HAVING ceil(1-value3) > 0 ORDER BY 1,2;

-- select ceil with group by index having (result)
--Testcase 489:
SELECT value1, ceil(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select ceil and as
--Testcase 490:
SELECT ceil(value3) as ceil1 FROM s3 ORDER BY 1 DESC;

-- select ceiling (builtin function, explain)
--Testcase 491:
EXPLAIN VERBOSE
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select ceiling (builtin function, result)
--Testcase 492:
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select ceiling (builtin function, not pushdown constraints, explain)
--Testcase 493:
EXPLAIN VERBOSE
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select ceiling (builtin function, not pushdown constraints, result)
--Testcase 494:
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select ceiling (builtin function, pushdown constraints, explain)
--Testcase 495:
EXPLAIN VERBOSE
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE value2 != 200;

-- select ceiling (builtin function, pushdown constraints, result)
--Testcase 496:
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE value2 != 200;

-- select ceiling (builtin function, ceiling in constraints, explain)
--Testcase 497:
EXPLAIN VERBOSE
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE ceiling(value1) != 1;

-- select ceiling (builtin function, ceiling in constraints, result)
--Testcase 498:
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE ceiling(value1) != 1;

-- select ceiling (builtin function, ceiling in constraints, explain)
--Testcase 499:
EXPLAIN VERBOSE
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE ceiling(0.5) > value1;

-- select ceiling (builtin function, ceiling in constraints, result)
--Testcase 500:
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE ceiling(0.5) > value1;

-- select ceiling as nest function with agg (pushdown, explain)
--Testcase 501:
EXPLAIN VERBOSE
SELECT sum(value3),ceiling(sum(value3)) FROM s3;

-- select ceiling as nest function with agg (pushdown, result)
--Testcase 502:
SELECT sum(value3),ceiling(sum(value3)) FROM s3;

-- select ceiling as nest with log2 (pushdown, explain)
--Testcase 503:
EXPLAIN VERBOSE
SELECT ceiling(log2(value1)),ceiling(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select ceiling as nest with log2 (pushdown, result)
--Testcase 504:
SELECT ceiling(log2(value1)),ceiling(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select ceiling with non pushdown func and explicit constant (explain)
--Testcase 505:
EXPLAIN VERBOSE
SELECT ceiling(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select ceiling with non pushdown func and explicit constant (result)
--Testcase 506:
SELECT ceiling(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select ceiling with order by (explain)
--Testcase 507:
EXPLAIN VERBOSE
SELECT value1, ceiling(1-value3) FROM s3 ORDER BY ceiling(1-value3);

-- select ceiling with order by (result)
--Testcase 508:
SELECT value1, ceiling(1-value3) FROM s3 ORDER BY ceiling(1-value3);

-- select ceiling with order by index (result)
--Testcase 509:
SELECT value1, ceiling(1-value3) FROM s3 ORDER BY 2,1;

-- select ceiling with order by index (result)
--Testcase 510:
SELECT value1, ceiling(1-value3) FROM s3 ORDER BY 1,2;

-- select ceiling with group by (explain)
--Testcase 511:
EXPLAIN VERBOSE
SELECT count(value1), ceiling(1-value3) FROM s3 GROUP BY ceiling(1-value3) ORDER BY 2,1;

-- select ceiling with group by (result)
--Testcase 512:
SELECT count(value1), ceiling(1-value3) FROM s3 GROUP BY ceiling(1-value3) ORDER BY 2,1;

-- select ceiling with group by index (result)
--Testcase 513:
SELECT value1, ceiling(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select ceiling with group by index (result)
--Testcase 514:
SELECT value1, ceiling(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select ceiling with group by having (explain)
--Testcase 515:
EXPLAIN VERBOSE
SELECT count(value1), ceiling(1-value3) FROM s3 GROUP BY ceiling(1-value3) HAVING ceiling(avg(value1)) > 0 ORDER BY 2,1;

-- select ceiling with group by having (result)
--Testcase 516:
SELECT count(value1), ceiling(1-value3) FROM s3 GROUP BY ceiling(1-value3) HAVING ceiling(avg(value1)) > 0 ORDER BY 2,1;

-- select ceiling with group by index having (result)
--Testcase 517:
SELECT value1, ceiling(1-value3) FROM s3 GROUP BY 2,1 HAVING ceiling(1-value3) > 0 ORDER BY 1,2;

-- select ceiling with group by index having (result)
--Testcase 518:
SELECT value1, ceiling(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select ceiling and as
--Testcase 519:
SELECT ceiling(value3) as ceiling1 FROM s3 ORDER BY 1 DESC;

-- select cos (builtin function, explain)
--Testcase 520:
EXPLAIN VERBOSE
SELECT value1, cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select cos (builtin function, result)
--Testcase 521:
SELECT value1, cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select cos (builtin function, not pushdown constraints, explain)
--Testcase 522:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select cos (builtin function, not pushdown constraints, result)
--Testcase 523:
SELECT cos(value1), cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select cos (builtin function, pushdown constraints, explain)
--Testcase 524:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE value2 != 200;

-- select cos (builtin function, pushdown constraints, result)
--Testcase 525:
SELECT cos(value1), cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE value2 != 200;

-- select cos (builtin function, cos in constraints, explain)
--Testcase 526:
EXPLAIN VERBOSE
SELECT value1, cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE cos(value1) != 1 ORDER BY 1,2,3,4,5;

-- select cos (builtin function, cos in constraints, result)
--Testcase 527:
SELECT value1, cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE cos(value1) != 1 ORDER BY 1,2,3,4,5;

-- select cos (builtin function, cos in constraints, explain)
--Testcase 528:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE cos(0.5) > value1;

-- select cos (builtin function, cos in constraints, result)
--Testcase 529:
SELECT cos(value1), cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE cos(0.5) > value1;

-- select cos as nest function with agg (pushdown, explain)
--Testcase 530:
EXPLAIN VERBOSE
SELECT sum(value3),cos(sum(value3)) FROM s3;

-- select cos as nest function with agg (pushdown, result)
--Testcase 531:
SELECT sum(value3),cos(sum(value3)) FROM s3;

-- select cos as nest with log2 (pushdown, explain)
--Testcase 532:
EXPLAIN VERBOSE
SELECT value1, cos(log2(value1)),cos(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select cos as nest with log2 (pushdown, result)
--Testcase 533:
SELECT value1, cos(log2(value1)),cos(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select cos with non pushdown func and explicit constant (explain)
--Testcase 534:
EXPLAIN VERBOSE
SELECT cos(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select cos with non pushdown func and explicit constant (result)
--Testcase 535:
SELECT cos(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select cos with order by (explain)
--Testcase 536:
EXPLAIN VERBOSE
SELECT value1, cos(1-value3) FROM s3 ORDER BY cos(1-value3);

-- select cos with order by (result)
--Testcase 537:
SELECT value1, cos(1-value3) FROM s3 ORDER BY cos(1-value3);

-- select cos with order by index (result)
--Testcase 538:
EXPLAIN VERBOSE
SELECT value1, cos(1-value3) FROM s3 ORDER BY 2,1;

-- select cos with order by index (result)
--Testcase 539:
SELECT value1, cos(1-value3) FROM s3 ORDER BY 1,2;

-- select cos with group by (explain)
--Testcase 540:
EXPLAIN VERBOSE
SELECT value1, cos(1-value3) FROM s3 GROUP BY value1, cos(1-value3) ORDER BY 1,2;

-- select cos with group by (result)
--Testcase 541:
SELECT value1, cos(1-value3) FROM s3 GROUP BY value1, cos(1-value3) ORDER BY 1,2;

-- select cos with group by index (result)
--Testcase 542:
SELECT value1, cos(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select cos with group by index (result)
--Testcase 543:
SELECT value1, cos(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select cos with group by having (explain)
--Testcase 544:
EXPLAIN VERBOSE
SELECT value1, cos(1-value3) FROM s3 GROUP BY value1, cos(1-value3) HAVING cos(avg(value1)) > 0 ORDER BY 1,2;

-- select cos with group by having (result)
--Testcase 545:
SELECT value1, cos(1-value3) FROM s3 GROUP BY value1, cos(1-value3) HAVING cos(avg(value1)) > 0 ORDER BY 1,2;

-- select cos with group by index having (result)
--Testcase 546:
SELECT value1, cos(1-value3) FROM s3 GROUP BY 2,1 HAVING cos(1-value3) > 0 ORDER BY 1,2;

-- select cos with group by index having (result)
--Testcase 547:
SELECT value1, cos(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select cos and as
--Testcase 548:
SELECT cos(value3) as cos1 FROM s3 ORDER BY 1 DESC;

-- select cot (builtin function, explain)
--Testcase 549:
EXPLAIN VERBOSE
SELECT value1, cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select cot (builtin function, result)
--Testcase 550:
SELECT value1, cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select cot (builtin function, not pushdown constraints, explain)
--Testcase 551:
EXPLAIN VERBOSE
SELECT cot(value1), cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select cot (builtin function, not pushdown constraints, result)
--Testcase 552:
SELECT cot(value1), cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select cot (builtin function, pushdown constraints, explain)
--Testcase 553:
EXPLAIN VERBOSE
SELECT cot(value1), cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE value2 != 200;

-- select cot (builtin function, pushdown constraints, result)
--Testcase 554:
SELECT cot(value1), cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE value2 != 200;

-- select cot (builtin function, cot in constraints, explain)
--Testcase 555:
EXPLAIN VERBOSE
SELECT value1, cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE cot(value1) != 1 ORDER BY 1,2,3,4,5;

-- select cot (builtin function, cot in constraints, result)
--Testcase 556:
SELECT value1, cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE cot(value1) != 1 ORDER BY 1,2,3,4,5;

-- select cot (builtin function, cot in constraints, explain)
--Testcase 557:
EXPLAIN VERBOSE
SELECT value1, cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE cot(0.5) > value1 ORDER BY 1,2,3,4,5;

-- select cot (builtin function, cot in constraints, result)
--Testcase 558:
SELECT value1, cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE cot(0.5) > value1 ORDER BY 1,2,3,4,5;

-- select cot as nest function with agg (pushdown, explain)
--Testcase 559:
EXPLAIN VERBOSE
SELECT sum(value3),cot(sum(value3)) FROM s3;

-- select cot as nest function with agg (pushdown, result)
--Testcase 560:
SELECT sum(value3),cot(sum(value3)) FROM s3;

-- select cot as nest with log2 (pushdown, explain)
--Testcase 561:
EXPLAIN VERBOSE
SELECT value1, cot(log2(value1)),cot(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select cot as nest with log2 (pushdown, result)
--Testcase 562:
SELECT value1, cot(log2(value1)),cot(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select cot with non pushdown func and explicit constant (explain)
--Testcase 563:
EXPLAIN VERBOSE
SELECT value1, cot(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select cot with non pushdown func and explicit constant (result)
--Testcase 564:
SELECT value1, cot(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select cot with order by (explain)
--Testcase 565:
EXPLAIN VERBOSE
SELECT value1, cot(1-value3) FROM s3 ORDER BY cot(1-value3);

-- select cot with order by (result)
--Testcase 566:
SELECT value1, cot(1-value3) FROM s3 ORDER BY cot(1-value3);

-- select cot with order by index (result)
--Testcase 567:
SELECT value1, cot(1-value3) FROM s3 ORDER BY 2,1;

-- select cot with order by index (result)
--Testcase 568:
SELECT value1, cot(1-value3) FROM s3 ORDER BY 1,2;

-- select cot with group by (explain)
--Testcase 569:
EXPLAIN VERBOSE
SELECT value1, cot(1-value3) FROM s3 GROUP BY value1, cot(1-value3) ORDER BY 1,2;

-- select cot with group by (result)
--Testcase 570:
SELECT value1, cot(1-value3) FROM s3 GROUP BY value1, cot(1-value3) ORDER BY 1,2;

-- select cot with group by index (result)
--Testcase 571:
SELECT value1, cot(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select cot with group by index (result)
--Testcase 572:
SELECT value1, cot(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select cot with group by having (explain)
--Testcase 573:
EXPLAIN VERBOSE
SELECT value1, cot(1-value3) FROM s3 GROUP BY value1, cot(1-value3) HAVING cot(avg(value1)) > 0 ORDER BY 1,2;

-- select cot with group by having (result)
--Testcase 574:
SELECT value1, cot(1-value3) FROM s3 GROUP BY value1, cot(1-value3) HAVING cot(avg(value1)) > 0 ORDER BY 1,2;

-- select cot with group by index having (result)
--Testcase 575:
SELECT value1, cot(1-value3) FROM s3 GROUP BY 2,1 HAVING cot(1-value3) > 0 ORDER BY 1,2;

-- select cot with group by index having (result)
--Testcase 576:
SELECT value1, cot(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select cot and as
--Testcase 577:
SELECT value1, cot(value3) as cot1 FROM s3 ORDER BY 1,2;

-- select degrees (builtin function, explain)
--Testcase 578:
EXPLAIN VERBOSE
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select degrees (builtin function, result)
--Testcase 579:
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select degrees (builtin function, not pushdown constraints, explain)
--Testcase 580:
EXPLAIN VERBOSE
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select degrees (builtin function, not pushdown constraints, result)
--Testcase 581:
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select degrees (builtin function, pushdown constraints, explain)
--Testcase 582:
EXPLAIN VERBOSE
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE value2 != 200;

-- select degrees (builtin function, pushdown constraints, result)
--Testcase 583:
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE value2 != 200;

-- select degrees (builtin function, degrees in constraints, explain)
--Testcase 584:
EXPLAIN VERBOSE
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE degrees(value1) != 1 ORDER BY 1,2,3,4,5;

-- select degrees (builtin function, degrees in constraints, result)
--Testcase 585:
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE degrees(value1) != 1 ORDER BY 1,2,3,4,5;

-- select degrees (builtin function, degrees in constraints, explain)
--Testcase 586:
EXPLAIN VERBOSE
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE degrees(0.5) > value1 ORDER BY 1,2,3,4,5;

-- select degrees (builtin function, degrees in constraints, result)
--Testcase 587:
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE degrees(0.5) > value1 ORDER BY 1,2,3,4,5;

-- select degrees as nest function with agg (pushdown, explain)
--Testcase 588:
EXPLAIN VERBOSE
SELECT sum(value3),degrees(sum(value3)) FROM s3;

-- select degrees as nest function with agg (pushdown, result)
--Testcase 589:
SELECT sum(value3),degrees(sum(value3)) FROM s3;

-- select degrees as nest with log2 (pushdown, explain)
--Testcase 590:
EXPLAIN VERBOSE
SELECT value1, degrees(log2(value1)),degrees(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select degrees as nest with log2 (pushdown, result)
--Testcase 591:
SELECT value1, degrees(log2(value1)),degrees(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select degrees with non pushdown func and explicit constant (explain)
--Testcase 592:
EXPLAIN VERBOSE
SELECT degrees(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select degrees with non pushdown func and explicit constant (result)
--Testcase 593:
SELECT degrees(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select degrees with order by (explain)
--Testcase 594:
EXPLAIN VERBOSE
SELECT value1, degrees(1-value3) FROM s3 ORDER BY degrees(1-value3);

-- select degrees with order by (result)
--Testcase 595:
SELECT value1, degrees(1-value3) FROM s3 ORDER BY degrees(1-value3);

-- select degrees with order by index (result)
--Testcase 596:
SELECT value1, degrees(1-value3) FROM s3 ORDER BY 2,1;

-- select degrees with order by index (result)
--Testcase 597:
SELECT value1, degrees(1-value3) FROM s3 ORDER BY 1,2;

-- select degrees with group by (explain)
--Testcase 598:
EXPLAIN VERBOSE
SELECT count(value1), degrees(1-value3) FROM s3 GROUP BY degrees(1-value3) ORDER BY 1,2;

-- select degrees with group by (result)
--Testcase 599:
SELECT count(value1), degrees(1-value3) FROM s3 GROUP BY degrees(1-value3) ORDER BY 1,2;

-- select degrees with group by index (result)
--Testcase 600:
SELECT value1, degrees(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select degrees with group by index (result)
--Testcase 601:
SELECT value1, degrees(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select degrees with group by having (explain)
--Testcase 602:
EXPLAIN VERBOSE
SELECT count(value1), degrees(1-value3) FROM s3 GROUP BY degrees(1-value3) HAVING degrees(avg(value1)) > 0 ORDER BY 1,2;

-- select degrees with group by having (result)
--Testcase 603:
SELECT count(value1), degrees(1-value3) FROM s3 GROUP BY degrees(1-value3) HAVING degrees(avg(value1)) > 0 ORDER BY 1,2;

-- select degrees with group by index having (result)
--Testcase 604:
SELECT value1, degrees(1-value3) FROM s3 GROUP BY 2,1 HAVING degrees(1-value3) > 0 ORDER BY 1,2;

-- select degrees with group by index having (result)
--Testcase 605:
SELECT value1, degrees(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select degrees and as
--Testcase 606:
SELECT degrees(value3) as degrees1 FROM s3 ORDER BY 1 DESC;

-- select div (builtin function, explain)
--Testcase 607:
EXPLAIN VERBOSE
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 ORDER BY 1,2,3,4,5;

-- select div (builtin function, result)
--Testcase 608:
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 ORDER BY 1,2,3,4,5;

-- select div (builtin function, not pushdown constraints, explain)
--Testcase 609:
EXPLAIN VERBOSE
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select div (builtin function, not pushdown constraints, result)
--Testcase 610:
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select div (builtin function, pushdown constraints, explain)
--Testcase 611:
EXPLAIN VERBOSE
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE value2 != 200;

-- select div (builtin function, pushdown constraints, result)
--Testcase 612:
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE value2 != 200;

-- select div (builtin function, div in constraints, explain)
--Testcase 613:
EXPLAIN VERBOSE
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE div(value1::numeric, 2) != 1 ORDER BY 1,2,3,4,5;

-- select div (builtin function, div in constraints, result)
--Testcase 614:
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE div(value1::numeric, 2) != 1 ORDER BY 1,2,3,4,5;

-- select div (builtin function, div in constraints, explain)
--Testcase 615:
EXPLAIN VERBOSE
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE div(5, 2) > value1 ORDER BY 1,2,3,4,5;

-- select div (builtin function, div in constraints, result)
--Testcase 616:
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE div(5, 2) > value1 ORDER BY 1,2,3,4,5;

-- select div as nest function with agg (pushdown, explain)
--Testcase 617:
EXPLAIN VERBOSE
SELECT sum(value3),div(sum(value3)::numeric, 2) FROM s3;

-- select div as nest function with agg (pushdown, error)
--Testcase 618:
SELECT sum(value3),div(sum(value3)::numeric, 2) FROM s3;

-- select div as nest with log2 (pushdown, explain)
--Testcase 619:
EXPLAIN VERBOSE
SELECT div(log2(value1)::numeric, 2),div(log2(1/value1)::numeric, 2) FROM s3 ORDER BY 1,2;

-- select div as nest with log2 (pushdown, result)
--Testcase 620:
SELECT div(log2(value1)::numeric, 2),div(log2(1/value1)::numeric, 2) FROM s3 ORDER BY 1,2;

-- select div with non pushdown func and explicit constant (explain)
--Testcase 621:
EXPLAIN VERBOSE
SELECT div(value3::numeric, 2), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select div with non pushdown func and explicit constant (result)
--Testcase 622:
SELECT div(value3::numeric, 2), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select div with order by (explain)
--Testcase 623:
EXPLAIN VERBOSE
SELECT value1, div((10-value1)::numeric, 2) FROM s3 ORDER BY value1, div((10-value1)::numeric, 2);

-- select div with order by (result)
--Testcase 624:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 ORDER BY value1, div((10-value1)::numeric, 2);

-- select div with order by index (result)
--Testcase 625:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 ORDER BY 2,1;

-- select div with order by index (result)
--Testcase 626:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 ORDER BY 1,2;

-- select div with group by (explain)
--Testcase 627:
EXPLAIN VERBOSE
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY value1, div((10-value1)::numeric, 2) ORDER BY 1,2;

-- select div with group by (result)
--Testcase 628:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY value1, div((10-value1)::numeric, 2) ORDER BY 1,2;

-- select div with group by index (result)
--Testcase 629:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select div with group by index (result)
--Testcase 630:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select div with group by having (explain)
--Testcase 631:
EXPLAIN VERBOSE
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY value1, div((10-value1)::numeric, 2) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select div with group by having (result)
--Testcase 632:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY value1, div((10-value1)::numeric, 2) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select div with group by index having (result)
--Testcase 633:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY 2,1 HAVING div((10-value1)::numeric, 2) > 0 ORDER BY 1,2;

-- select div with group by index having (result)
--Testcase 634:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select div and as
--Testcase 635:
SELECT div(value3::numeric, 2) as div1 FROM s3 ORDER BY 1 DESC;

-- select exp (builtin function, explain)
--Testcase 636:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select exp (builtin function, result)
--Testcase 637:
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select exp (builtin function, not pushdown constraints, explain)
--Testcase 638:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select exp (builtin function, not pushdown constraints, result)
--Testcase 639:
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select exp (builtin function, pushdown constraints, explain)
--Testcase 640:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE value2 != 200;

-- select exp (builtin function, pushdown constraints, result)
--Testcase 641:
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE value2 != 200;

-- select exp (builtin function, exp in constraints, explain)
--Testcase 642:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE exp(value1) != 1 ORDER BY 1,2,3,4,5;

-- select exp (builtin function, exp in constraints, result)
--Testcase 643:
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE exp(value1) != 1 ORDER BY 1,2,3,4,5;

-- select exp (builtin function, exp in constraints, explain)
--Testcase 644:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE exp(0.5) > value1 ORDER BY 1,2,3,4,5;

-- select exp (builtin function, exp in constraints, result)
--Testcase 645:
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE exp(0.5) > value1 ORDER BY 1,2,3,4,5;

-- select exp as nest function with agg (pushdown, explain)
--Testcase 646:
EXPLAIN VERBOSE
SELECT sum(value3),exp(sum(value3)) FROM s3;

-- select exp as nest function with agg (pushdown, result)
--Testcase 647:
SELECT sum(value3),exp(sum(value3)) FROM s3;

-- select exp as nest with log2 (pushdown, explain)
--Testcase 648:
EXPLAIN VERBOSE
SELECT exp(log2(value1)),exp(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select exp as nest with log2 (pushdown, result)
--Testcase 649:
SELECT exp(log2(value1)),exp(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select exp with non pushdown func and explicit constant (explain)
--Testcase 650:
EXPLAIN VERBOSE
SELECT exp(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select exp with non pushdown func and explicit constant (result)
--Testcase 651:
SELECT exp(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select exp with order by (explain)
--Testcase 652:
EXPLAIN VERBOSE
SELECT value1, exp(1-value3) FROM s3 ORDER BY exp(1-value3);

-- select exp with order by (result)
--Testcase 653:
SELECT value1, exp(1-value3) FROM s3 ORDER BY exp(1-value3);

-- select exp with order by index (result)
--Testcase 654:
SELECT value1, exp(1-value3) FROM s3 ORDER BY 2,1;

-- select exp with order by index (result)
--Testcase 655:
SELECT value1, exp(1-value3) FROM s3 ORDER BY 1,2;

-- select exp with group by (explain)
--Testcase 656:
EXPLAIN VERBOSE
SELECT count(value1), exp(1-value3) FROM s3 GROUP BY exp(1-value3) ORDER BY 1,2;

-- select exp with group by (result)
--Testcase 657:
SELECT count(value1), exp(1-value3) FROM s3 GROUP BY exp(1-value3) ORDER BY 1,2;

-- select exp with group by index (result)
--Testcase 658:
SELECT value1, exp(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select exp with group by index (result)
--Testcase 659:
SELECT value1, exp(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select exp with group by having (explain)
--Testcase 660:
EXPLAIN VERBOSE
SELECT count(value1), exp(1-value3) FROM s3 GROUP BY exp(1-value3) HAVING exp(avg(value1)) > 0 ORDER BY 1,2;

-- select exp with group by having (result)
--Testcase 661:
SELECT count(value1), exp(1-value3) FROM s3 GROUP BY exp(1-value3) HAVING exp(avg(value1)) > 0 ORDER BY 1,2;

-- select exp with group by index having (result)
--Testcase 662:
SELECT value1, exp(1-value3) FROM s3 GROUP BY 2,1 HAVING exp(1-value3) > 0 ORDER BY 1,2;

-- select exp with group by index having (result)
--Testcase 663:
SELECT value1, exp(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select exp and as
--Testcase 664:
SELECT exp(value3) as exp1 FROM s3 ORDER BY 1 DESC;

-- select floor (builtin function, explain)
--Testcase 665:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select floor (builtin function, result)
--Testcase 666:
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select floor (builtin function, not pushdown constraints, explain)
--Testcase 667:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE to_hex(value2) = '64';

-- select floor (builtin function, not pushdown constraints, result)
--Testcase 668:
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE to_hex(value2) = '64';

-- select floor (builtin function, pushdown constraints, explain)
--Testcase 669:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE value2 != 200;

-- select floor (builtin function, pushdown constraints, result)
--Testcase 670:
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE value2 != 200;

-- select floor (builtin function, floor in constraints, explain)
--Testcase 671:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE floor(value1) != 1 ORDER BY 1,2,3,4,5;

-- select floor (builtin function, floor in constraints, result)
--Testcase 672:
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE floor(value1) != 1 ORDER BY 1,2,3,4,5;

-- select floor (builtin function, floor in constraints, explain)
--Testcase 673:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE floor(1.5) > value1;

-- select floor (builtin function, floor in constraints, result)
--Testcase 674:
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE floor(1.5) > value1;

-- select floor as nest function with agg (pushdown, explain)
--Testcase 675:
EXPLAIN VERBOSE
SELECT sum(value3),floor(sum(value3)) FROM s3;

-- select floor as nest function with agg (pushdown, result)
--Testcase 676:
SELECT sum(value3),floor(sum(value3)) FROM s3;

-- select floor as nest with log2 (pushdown, explain)
--Testcase 677:
EXPLAIN VERBOSE
SELECT floor(log2(value1)),floor(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select floor as nest with log2 (pushdown, result)
--Testcase 678:
SELECT floor(log2(value1)),floor(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select floor with non pushdown func and explicit constant (explain)
--Testcase 679:
EXPLAIN VERBOSE
SELECT floor(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select floor with non pushdown func and explicit constant (result)
--Testcase 680:
SELECT floor(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select floor with order by (explain)
--Testcase 681:
EXPLAIN VERBOSE
SELECT value1, floor(10 - value1) FROM s3 ORDER BY floor(10 - value1);

-- select floor with order by (result)
--Testcase 682:
SELECT value1, floor(10 - value1) FROM s3 ORDER BY floor(10 - value1);

-- select floor with order by index (result)
--Testcase 683:
SELECT value1, floor(10 - value1) FROM s3 ORDER BY 2,1;

-- select floor with order by index (result)
--Testcase 684:
SELECT value1, floor(10 - value1) FROM s3 ORDER BY 1,2;

-- select floor with group by (explain)
--Testcase 685:
EXPLAIN VERBOSE
SELECT value1, floor(10 - value1) FROM s3 GROUP BY value1, floor(10 - value1) ORDER BY 1,2;

-- select floor with group by (result)
--Testcase 686:
SELECT value1, floor(10 - value1) FROM s3 GROUP BY value1, floor(10 - value1) ORDER BY 1,2;

-- select floor with group by index (result)
--Testcase 687:
SELECT value1, floor(10 - value1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select floor with group by index (result)
--Testcase 688:
SELECT value1, floor(10 - value1) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select floor with group by having (explain)
--Testcase 689:
EXPLAIN VERBOSE
SELECT value1, floor(10 - value1) FROM s3 GROUP BY value1, floor(10 - value1) HAVING floor(avg(value1)) > 0 ORDER BY 1,2;

-- select floor with group by having (result)
--Testcase 690:
SELECT value1, floor(10 - value1) FROM s3 GROUP BY value1, floor(10 - value1) HAVING floor(avg(value1)) > 0 ORDER BY 1,2;

-- select floor with group by index having (result)
--Testcase 691:
SELECT value1, floor(10 - value1) FROM s3 GROUP BY 2,1 HAVING floor(10 - value1) > 0 ORDER BY 1,2;

-- select floor with group by index having (result)
--Testcase 692:
SELECT value1, floor(10 - value1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select floor and as
--Testcase 693:
SELECT floor(value3) as floor1 FROM s3 ORDER BY 1 DESC;

-- select ln as nest function with agg (pushdown, explain)
--Testcase 694:
EXPLAIN VERBOSE
SELECT sum(value3),ln(sum(value1)) FROM s3;

-- select ln as nest function with agg (pushdown, result)
--Testcase 695:
SELECT sum(value3),ln(sum(value1)) FROM s3;

-- select ln as nest with log2 (pushdown, explain)
--Testcase 696:
EXPLAIN VERBOSE
SELECT value1, ln(log2(value1)),ln(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select ln as nest with log2 (pushdown, result)
--Testcase 697:
SELECT value1, ln(log2(value1)),ln(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select ln with non pushdown func and explicit constant (explain)
--Testcase 698:
EXPLAIN VERBOSE
SELECT ln(value2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select ln with non pushdown func and explicit constant (result)
--Testcase 699:
SELECT ln(value2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select ln with order by (explain)
--Testcase 700:
EXPLAIN VERBOSE
SELECT value1, ln(1-value3) FROM s3 ORDER BY ln(1-value3);

-- select ln with order by (result)
--Testcase 701:
SELECT value1, ln(1-value3) FROM s3 ORDER BY ln(1-value3);

-- select ln with order by index (result)
--Testcase 702:
SELECT value1, ln(1-value3) FROM s3 ORDER BY 2,1;

-- select ln with order by index (result)
--Testcase 703:
SELECT value1, ln(1-value3) FROM s3 ORDER BY 1,2;

-- select ln with group by (explain)
--Testcase 704:
EXPLAIN VERBOSE
SELECT count(value1), ln(1-value3) FROM s3 GROUP BY ln(1-value3) ORDER BY 1,2;

-- select ln with group by (result)
--Testcase 705:
SELECT count(value1), ln(1-value3) FROM s3 GROUP BY ln(1-value3) ORDER BY 1,2;

-- select ln with group by index (result)
--Testcase 706:
SELECT value1, ln(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select ln with group by index (result)
--Testcase 707:
SELECT value1, ln(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select ln with group by having (explain)
--Testcase 708:
EXPLAIN VERBOSE
SELECT count(value1), ln(1-value3) FROM s3 GROUP BY ln(1-value3) HAVING ln(avg(value1)) > 0 ORDER BY 1,2;

-- select ln with group by having (result)
--Testcase 709:
SELECT count(value1), ln(1-value3) FROM s3 GROUP BY ln(1-value3) HAVING ln(avg(value1)) > 0 ORDER BY 1,2;

-- select ln with group by index having (result)
--Testcase 710:
SELECT value1, ln(1-value3) FROM s3 GROUP BY 2,1 HAVING ln(1-value3) < 0;

-- select ln with group by index having (result)
--Testcase 711:
SELECT value1, ln(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select ln and as
--Testcase 712:
SELECT ln(value1) as ln1 FROM s3 ORDER BY 1;

-- select ln (builtin function, explain)
--Testcase 713:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 ORDER BY 1,2,3,4;

-- select ln (builtin function, result)
--Testcase 714:
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 ORDER BY 1,2,3,4;

-- select ln (builtin function, not pushdown constraints, explain)
--Testcase 715:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select ln (builtin function, not pushdown constraints, result)
--Testcase 716:
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select ln (builtin function, pushdown constraints, explain)
--Testcase 717:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE value2 != 200;

-- select ln (builtin function, pushdown constraints, result)
--Testcase 718:
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE value2 != 200;

-- select ln (builtin function, ln in constraints, explain)
--Testcase 719:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE ln(value1) != 1 ORDER BY 1,2,3,4;

-- select ln (builtin function, ln in constraints, result)
--Testcase 720:
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE ln(value1) != 1 ORDER BY 1,2,3,4;

-- select ln (builtin function, ln in constraints, explain)
--Testcase 721:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE ln(0.5) < value1 ORDER BY 1,2,3,4;

-- select ln (builtin function, ln in constraints, result)
--Testcase 722:
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE ln(0.5) < value1 ORDER BY 1,2,3,4;

-- select mod (builtin function, explain)
--Testcase 723:
EXPLAIN VERBOSE
SELECT value1, mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 ORDER BY 1,2,3,4,5,6;

-- select mod (builtin function, result)
--Testcase 724:
SELECT value1, mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 ORDER BY 1,2,3,4,5,6;

-- select mod (builtin function, not pushdown constraints, explain)
--Testcase 725:
EXPLAIN VERBOSE
SELECT mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select mod (builtin function, not pushdown constraints, result)
--Testcase 726:
SELECT mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select mod (builtin function, pushdown constraints, explain)
--Testcase 727:
EXPLAIN VERBOSE
SELECT mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE value2 != 200;

-- select mod (builtin function, pushdown constraints, result)
--Testcase 728:
SELECT mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE value2 != 200;

-- select mod (builtin function, mod in constraints, explain)
--Testcase 729:
EXPLAIN VERBOSE
SELECT value1, mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE mod(value1::numeric, 2) != 1 ORDER BY 1,2,3,4,5,6;

-- select mod (builtin function, mod in constraints, result)
--Testcase 730:
SELECT value1, mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE mod(value1::numeric, 2) != 1 ORDER BY 1,2,3,4,5,6;

-- select mod (builtin function, mod in constraints, explain)
--Testcase 731:
EXPLAIN VERBOSE
SELECT mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE mod(5, 2) > value1;

-- select mod (builtin function, mod in constraints, result)
--Testcase 732:
SELECT mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE mod(5, 2) > value1;

-- select mod as nest function with agg (pushdown, explain)
--Testcase 733:
EXPLAIN VERBOSE
SELECT sum(value3), mod(sum(value3)::numeric, 2) FROM s3;

-- select mod as nest function with agg (pushdown, error)
--Testcase 734:
SELECT sum(value3), mod(sum(value3)::numeric, 2) FROM s3;

-- select mod as nest with log2 (pushdown, explain)
--Testcase 735:
EXPLAIN VERBOSE
SELECT value1, mod(log2(value1)::numeric, 2), mod(log2(1/value1)::numeric, 2) FROM s3 ORDER BY 1,2,3;

-- select mod as nest with log2 (pushdown, result)
--Testcase 736:
SELECT value1, mod(log2(value1)::numeric, 2), mod(log2(1/value1)::numeric, 2) FROM s3 ORDER BY 1,2,3;

-- select mod with non pushdown func and explicit constant (explain)
--Testcase 737:
EXPLAIN VERBOSE
SELECT value1, mod(value3::numeric, 2), pi(), 4.1 FROM s3 ORDER BY 1,2,3;

-- select mod with non pushdown func and explicit constant (result)
--Testcase 738:
SELECT value1, mod(value3::numeric, 2), pi(), 4.1 FROM s3 ORDER BY 1,2,3;

-- select mod with order by (explain)
--Testcase 739:
EXPLAIN VERBOSE
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 ORDER BY mod((1-value3)::numeric, 2);

-- select mod with order by (result)
--Testcase 740:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 ORDER BY mod((1-value3)::numeric, 2);

-- select mod with order by index (result)
--Testcase 741:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 ORDER BY 2,1;

-- select mod with order by index (result)
--Testcase 742:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 ORDER BY 1,2;

-- select mod with group by (explain)
--Testcase 743:
EXPLAIN VERBOSE
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY value1, mod((1-value3)::numeric, 2) ORDER BY 1,2;

-- select mod with group by (result)
--Testcase 744:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY value1, mod((1-value3)::numeric, 2) ORDER BY 1,2;

-- select mod with group by index (result)
--Testcase 745:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select mod with group by index (result)
--Testcase 746:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select mod with group by having (explain)
--Testcase 747:
EXPLAIN VERBOSE
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY value1, mod((1-value3)::numeric, 2) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select mod with group by having (result)
--Testcase 748:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY value1, mod((1-value3)::numeric, 2) HAVING avg(value1) > 0 ORDER BY 1,2;

-- select mod with group by index having (result)
--Testcase 749:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select mod and as
--Testcase 750:
SELECT value1, mod(value3::numeric, 2) as mod1 FROM s3 ORDER BY 1,2;

-- select power (builtin function, explain)
--Testcase 751:
EXPLAIN VERBOSE
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 ORDER BY 1,2,3,4,5;

-- select power (builtin function, result)
--Testcase 752:
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 ORDER BY 1,2,3,4,5;

-- select power (builtin function, not pushdown constraints, explain)
--Testcase 753:
EXPLAIN VERBOSE
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select power (builtin function, not pushdown constraints, result)
--Testcase 754:
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select power (builtin function, pushdown constraints, explain)
--Testcase 755:
EXPLAIN VERBOSE
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE value2 != 200;

-- select power (builtin function, pushdown constraints, result)
--Testcase 756:
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE value2 != 200;

-- select power (builtin function, power in constraints, explain)
--Testcase 757:
EXPLAIN VERBOSE
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE power(value1, 2) != 1 ORDER BY 1,2,3,4,5;

-- select power (builtin function, power in constraints, result)
--Testcase 758:
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE power(value1, 2) != 1 ORDER BY 1,2,3,4,5;

-- select power (builtin function, power in constraints, explain)
--Testcase 759:
EXPLAIN VERBOSE
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE power(5, 2) > value1 ORDER BY 1,2,3,4,5;

-- select power (builtin function, power in constraints, result)
--Testcase 760:
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE power(5, 2) > value1 ORDER BY 1,2,3,4,5;

-- select power as nest function with agg (pushdown, explain)
--Testcase 761:
EXPLAIN VERBOSE
SELECT sum(value3),power(sum(value3), 2) FROM s3;

-- select power as nest function with agg (pushdown, result)
--Testcase 762:
SELECT sum(value3),power(sum(value3), 2) FROM s3;

-- select power as nest with log2 (pushdown, explain)
--Testcase 763:
EXPLAIN VERBOSE
SELECT value1, power(log2(value1), 2),power(log2(1/value1), 2) FROM s3 ORDER BY 1,2,3;

-- select power as nest with log2 (pushdown, result)
--Testcase 764:
SELECT value1, power(log2(value1), 2),power(log2(1/value1), 2) FROM s3 ORDER BY 1,2,3;

-- select power with non pushdown func and explicit constant (explain)
--Testcase 765:
EXPLAIN VERBOSE
SELECT power(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select power with non pushdown func and explicit constant (result)
--Testcase 766:
SELECT power(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select power with order by (explain)
--Testcase 767:
EXPLAIN VERBOSE
SELECT value1, power(1-value3, 2) FROM s3 ORDER BY power(1-value3, 2);

-- select power with order by (result)
--Testcase 768:
SELECT value1, power(1-value3, 2) FROM s3 ORDER BY power(1-value3, 2);

-- select power with order by index (result)
--Testcase 769:
SELECT value1, power(1-value3, 2) FROM s3 ORDER BY 2,1;

-- select power with order by index (result)
--Testcase 770:
SELECT value1, power(1-value3, 2) FROM s3 ORDER BY 1,2;

-- select power with group by (explain)
--Testcase 771:
EXPLAIN VERBOSE
SELECT count(value1), power(1-value3, 2) FROM s3 GROUP BY power(1-value3, 2) ORDER BY 2,1;

-- select power with group by (result)
--Testcase 772:
SELECT count(value1), power(1-value3, 2) FROM s3 GROUP BY power(1-value3, 2) ORDER BY 2,1;

-- select power with group by index (result)
--Testcase 773:
SELECT value1, power(1-value3, 2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select power with group by index (result)
--Testcase 774:
SELECT value1, power(1-value3, 2) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select power with group by having (explain)
--Testcase 775:
EXPLAIN VERBOSE
SELECT count(value1), power(1-value3, 2) FROM s3 GROUP BY power(1-value3, 2) HAVING power(avg(value1), 2) > 0 ORDER BY 1,2;

-- select power with group by having (result)
--Testcase 776:
SELECT count(value1), power(1-value3, 2) FROM s3 GROUP BY power(1-value3, 2) HAVING power(avg(value1), 2) > 0 ORDER BY 1,2;

-- select power with group by index having (result)
--Testcase 777:
SELECT value1, power(1-value3, 2) FROM s3 GROUP BY 2,1 HAVING power(1-value3, 2) > 0 ORDER BY 1,2;

-- select power with group by index having (result)
--Testcase 778:
SELECT value1, power(1-value3, 2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select power and as
--Testcase 779:
SELECT power(value3, 2) as power1 FROM s3 ORDER BY 1;

-- select radians (builtin function, explain)
--Testcase 780:
EXPLAIN VERBOSE
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select radians (builtin function, result)
--Testcase 781:
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select radians (builtin function, not pushdown constraints, explain)
--Testcase 782:
EXPLAIN VERBOSE
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select radians (builtin function, not pushdown constraints, result)
--Testcase 783:
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select radians (builtin function, pushdown constraints, explain)
--Testcase 784:
EXPLAIN VERBOSE
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE value2 != 200;

-- select radians (builtin function, pushdown constraints, result)
--Testcase 785:
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE value2 != 200;

-- select radians (builtin function, radians in constraints, explain)
--Testcase 786:
EXPLAIN VERBOSE
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE radians(value1) != 1 ORDER BY 1,2,3,4,5;

-- select radians (builtin function, radians in constraints, result)
--Testcase 787:
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE radians(value1) != 1 ORDER BY 1,2,3,4,5;

-- select radians (builtin function, radians in constraints, explain)
--Testcase 788:
EXPLAIN VERBOSE
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE radians(0.5) < value1 ORDER BY 1,2,3,4,5;

-- select radians (builtin function, radians in constraints, result)
--Testcase 789:
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE radians(0.5) < value1 ORDER BY 1,2,3,4,5;

-- select radians as nest function with agg (pushdown, explain)
--Testcase 790:
EXPLAIN VERBOSE
SELECT sum(value3),radians(sum(value3)) FROM s3;

-- select radians as nest function with agg (pushdown, result)
--Testcase 791:
SELECT sum(value3),radians(sum(value3)) FROM s3;

-- select radians as nest with log2 (pushdown, explain)
--Testcase 792:
EXPLAIN VERBOSE
SELECT radians(log2(value1)),radians(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select radians as nest with log2 (pushdown, result)
--Testcase 793:
SELECT radians(log2(value1)),radians(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select radians with non pushdown func and explicit constant (explain)
--Testcase 794:
EXPLAIN VERBOSE
SELECT radians(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select radians with non pushdown func and explicit constant (result)
--Testcase 795:
SELECT radians(value3), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select radians with order by (explain)
--Testcase 796:
EXPLAIN VERBOSE
SELECT value1, radians(1-value3) FROM s3 ORDER BY radians(1-value3);

-- select radians with order by (result)
--Testcase 797:
SELECT value1, radians(1-value3) FROM s3 ORDER BY radians(1-value3);

-- select radians with order by index (result)
--Testcase 798:
SELECT value1, radians(1-value3) FROM s3 ORDER BY 2,1;

-- select radians with order by index (result)
--Testcase 799:
SELECT value1, radians(1-value3) FROM s3 ORDER BY 1,2;

-- select radians with group by (explain)
--Testcase 800:
EXPLAIN VERBOSE
SELECT count(value1), radians(1-value3) FROM s3 GROUP BY radians(1-value3) ORDER BY 1,2;

-- select radians with group by (result)
--Testcase 801:
SELECT count(value1), radians(1-value3) FROM s3 GROUP BY radians(1-value3) ORDER BY 1,2;

-- select radians with group by index (result)
--Testcase 802:
SELECT value1, radians(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select radians with group by index (result)
--Testcase 803:
SELECT value1, radians(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select radians with group by having (explain)
--Testcase 804:
EXPLAIN VERBOSE
SELECT count(value1), radians(1-value3) FROM s3 GROUP BY radians(1-value3) HAVING radians(avg(value1)) > 0 ORDER BY 1,2;

-- select radians with group by having (result)
--Testcase 805:
SELECT count(value1), radians(1-value3) FROM s3 GROUP BY radians(1-value3) HAVING radians(avg(value1)) > 0 ORDER BY 1,2;

-- select radians with group by index having (result)
--Testcase 806:
SELECT value1, radians(1-value3) FROM s3 GROUP BY 2,1 HAVING radians(1-value3) > 0 ORDER BY 1,2;

-- select radians with group by index having (result)
--Testcase 807:
SELECT value1, radians(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select radians and as
--Testcase 808:
SELECT radians(value3) as radians1 FROM s3 ORDER BY 1 DESC;

-- select sign (builtin function, explain)
--Testcase 809:
EXPLAIN VERBOSE
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3;

-- select sign (builtin function, result)
--Testcase 810:
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3;

-- select sign (builtin function, not pushdown constraints, explain)
--Testcase 811:
EXPLAIN VERBOSE
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select sign (builtin function, not pushdown constraints, result)
--Testcase 812:
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select sign (builtin function, pushdown constraints, explain)
--Testcase 813:
EXPLAIN VERBOSE
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE value2 != 200;

-- select sign (builtin function, pushdown constraints, result)
--Testcase 814:
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE value2 != 200;

-- select sign (builtin function, sign in constraints, explain)
--Testcase 815:
EXPLAIN VERBOSE
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE sign(value1) != -1;

-- select sign (builtin function, sign in constraints, result)
--Testcase 816:
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE sign(value1) != -1;

-- select sign (builtin function, sign in constraints, explain)
--Testcase 817:
EXPLAIN VERBOSE
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE sign(0.5) > value1;

-- select sign (builtin function, sign in constraints, result)
--Testcase 818:
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE sign(0.5) > value1;

-- select sign as nest function with agg (pushdown, explain)
--Testcase 819:
EXPLAIN VERBOSE
SELECT sum(value3),sign(sum(value3)) FROM s3;

-- select sign as nest function with agg (pushdown, result)
--Testcase 820:
SELECT sum(value3),sign(sum(value3)) FROM s3;

-- select sign as nest with log2 (pushdown, explain)
--Testcase 821:
EXPLAIN VERBOSE
SELECT sign(log2(value1)),sign(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select sign as nest with log2 (pushdown, result)
--Testcase 822:
SELECT sign(log2(value1)),sign(log2(1/value1)) FROM s3 ORDER BY 1,2;

-- select sign with non pushdown func and explicit constant (explain)
--Testcase 823:
EXPLAIN VERBOSE
SELECT sign(value3), pi(), 4.1 FROM s3;

-- select sign with non pushdown func and explicit constant (result)
--Testcase 824:
SELECT sign(value3), pi(), 4.1 FROM s3;

-- select sign with order by (explain)
--Testcase 825:
EXPLAIN VERBOSE
SELECT value1, sign(1-value3) FROM s3 ORDER BY value1, sign(1-value3);

-- select sign with order by (result)
--Testcase 826:
SELECT value1, sign(1-value3) FROM s3 ORDER BY value1, sign(1-value3);

-- select sign with order by index (result)
--Testcase 827:
SELECT value1, sign(1-value3) FROM s3 ORDER BY 2,1;

-- select sign with order by index (result)
--Testcase 828:
SELECT value1, sign(1-value3) FROM s3 ORDER BY 1,2;

-- select sign with group by (explain)
--Testcase 829:
EXPLAIN VERBOSE
SELECT count(value1), sign(1-value3) FROM s3 GROUP BY sign(1-value3);

-- select sign with group by (result)
--Testcase 830:
SELECT count(value1), sign(1-value3) FROM s3 GROUP BY sign(1-value3);

-- select sign with group by index (result)
--Testcase 831:
SELECT value1, sign(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select sign with group by index (result)
--Testcase 832:
SELECT value1, sign(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select sign with group by having (explain)
--Testcase 833:
EXPLAIN VERBOSE
SELECT count(value1), sign(1-value3) FROM s3 GROUP BY sign(1-value3) HAVING sign(avg(value1)) > 0;

-- select sign with group by having (result)
--Testcase 834:
SELECT count(value1), sign(1-value3) FROM s3 GROUP BY sign(1-value3) HAVING sign(avg(value1)) > 0;

-- select sign with group by index having (result)
--Testcase 835:
SELECT value1, sign(1-value3) FROM s3 GROUP BY 2,1 HAVING sign(1-value3) > 0 ORDER BY 1,2;

-- select sign with group by index having (result)
--Testcase 836:
SELECT value1, sign(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select sign and as
--Testcase 837:
SELECT sign(value3) as sign1 FROM s3;

-- select sin (builtin function, explain)
--Testcase 838:
EXPLAIN VERBOSE
SELECT value1, sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select sin (builtin function, result)
--Testcase 839:
SELECT value1, sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select sin (builtin function, not pushdown constraints, explain)
--Testcase 840:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select sin (builtin function, not pushdown constraints, result)
--Testcase 841:
SELECT sin(value1), sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select sin (builtin function, pushdown constraints, explain)
--Testcase 842:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE value2 != 200;

-- select sin (builtin function, pushdown constraints, result)
--Testcase 843:
SELECT sin(value1), sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE value2 != 200;

-- select sin (builtin function, sin in constraints, explain)
--Testcase 844:
EXPLAIN VERBOSE
SELECT value1, sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE sin(value1) != 1 ORDER BY 1,2,3,4,5;

-- select sin (builtin function, sin in constraints, result)
--Testcase 845:
SELECT value1, sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE sin(value1) != 1 ORDER BY 1,2,3,4,5;

-- select sin (builtin function, sin in constraints, explain)
--Testcase 846:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE sin(0.5) > value1;

-- select sin (builtin function, sin in constraints, result)
--Testcase 847:
SELECT sin(value1), sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE sin(0.5) > value1;

-- select sin as nest function with agg (pushdown, explain)
--Testcase 848:
EXPLAIN VERBOSE
SELECT sum(value3),sin(sum(value3)) FROM s3;

-- select sin as nest function with agg (pushdown, result)
--Testcase 849:
SELECT sum(value3),sin(sum(value3)) FROM s3;

-- select sin as nest with log2 (pushdown, explain)
--Testcase 850:
EXPLAIN VERBOSE
SELECT value1, sin(log2(value1)),sin(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select sin as nest with log2 (pushdown, result)
--Testcase 851:
SELECT value1, sin(log2(value1)),sin(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select sin with non pushdown func and explicit constant (explain)
--Testcase 852:
EXPLAIN VERBOSE
SELECT value1, sin(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select sin with non pushdown func and explicit constant (result)
--Testcase 853:
SELECT value1, sin(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select sin with order by (explain)
--Testcase 854:
EXPLAIN VERBOSE
SELECT value1, sin(1-value3) FROM s3 ORDER BY sin(1-value3);

-- select sin with order by (result)
--Testcase 855:
SELECT value1, sin(1-value3) FROM s3 ORDER BY sin(1-value3);

-- select sin with order by index (result)
--Testcase 856:
SELECT value1, sin(1-value3) FROM s3 ORDER BY 2,1;

-- select sin with order by index (result)
--Testcase 857:
SELECT value1, sin(1-value3) FROM s3 ORDER BY 1,2;

-- select sin with group by (explain)
--Testcase 858:
EXPLAIN VERBOSE
SELECT value1, sin(1-value3) FROM s3 GROUP BY value1, sin(1-value3) ORDER BY 1,2;

-- select sin with group by (result)
--Testcase 859:
SELECT value1, sin(1-value3) FROM s3 GROUP BY value1, sin(1-value3) ORDER BY 1,2;

-- select sin with group by index (result)
--Testcase 860:
SELECT value1, sin(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select sin with group by index (result)
--Testcase 861:
SELECT value1, sin(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select sin with group by having (explain)
--Testcase 862:
EXPLAIN VERBOSE
SELECT value1, sin(1-value3) FROM s3 GROUP BY value1, sin(1-value3) HAVING sin(avg(value1)) > 0 ORDER BY 1,2;

-- select sin with group by having (result)
--Testcase 863:
SELECT value1, sin(1-value3) FROM s3 GROUP BY value1, sin(1-value3) HAVING sin(avg(value1)) > 0 ORDER BY 1,2;

-- select sin with group by index having (result)
--Testcase 864:
SELECT value1, sin(1-value3) FROM s3 GROUP BY 2,1 HAVING sin(1-value3) > 0 ORDER BY 1,2;

-- select sin with group by index having (result)
--Testcase 865:
SELECT value1, sin(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select sin and as
--Testcase 866:
SELECT value1, sin(value3) as sin1 FROM s3 ORDER BY 1,2;

-- select sqrt (builtin function, explain)
--Testcase 867:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 ORDER BY 1,2,3;

-- select sqrt (builtin function, result)
--Testcase 868:
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 ORDER BY 1,2,3;

-- select sqrt (builtin function, not pushdown constraints, explain)
--Testcase 869:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select sqrt (builtin function, not pushdown constraints, result)
--Testcase 870:
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select sqrt (builtin function, pushdown constraints, explain)
--Testcase 871:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE value2 != 200;

-- select sqrt (builtin function, pushdown constraints, result)
--Testcase 872:
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE value2 != 200;

-- select sqrt (builtin function, sqrt in constraints, explain)
--Testcase 873:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE sqrt(value1) != 1 ORDER BY 1,2,3;

-- select sqrt (builtin function, sqrt in constraints, result)
--Testcase 874:
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE sqrt(value1) != 1 ORDER BY 1,2,3;

-- select sqrt (builtin function, sqrt in constraints, explain)
--Testcase 875:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE sqrt(0.5) > value1;

-- select sqrt (builtin function, sqrt in constraints, result)
--Testcase 876:
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE sqrt(0.5) > value1;

-- select sqrt as nest function with agg (pushdown, explain)
--Testcase 877:
EXPLAIN VERBOSE
SELECT sum(value3),sqrt(sum(value1)) FROM s3;

-- select sqrt as nest function with agg (pushdown, result)
--Testcase 878:
SELECT sum(value3),sqrt(sum(value1)) FROM s3;

-- select sqrt as nest with log2 (pushdown, explain)
--Testcase 879:
EXPLAIN VERBOSE
SELECT value1, sqrt(log2(value1)),sqrt(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select sqrt as nest with log2 (pushdown, result)
--Testcase 880:
SELECT value1, sqrt(log2(value1)),sqrt(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select sqrt with non pushdown func and explicit constant (explain)
--Testcase 881:
EXPLAIN VERBOSE
SELECT sqrt(value2), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select sqrt with non pushdown func and explicit constant (result)
--Testcase 882:
SELECT sqrt(value2), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select sqrt with order by (explain)
--Testcase 883:
EXPLAIN VERBOSE
SELECT value1, sqrt(1-value3) FROM s3 ORDER BY sqrt(1-value3);

-- select sqrt with order by (result)
--Testcase 884:
SELECT value1, sqrt(1-value3) FROM s3 ORDER BY sqrt(1-value3);

-- select sqrt with order by index (result)
--Testcase 885:
SELECT value1, sqrt(1-value3) FROM s3 ORDER BY 2,1;

-- select sqrt with order by index (result)
--Testcase 886:
SELECT value1, sqrt(1-value3) FROM s3 ORDER BY 1,2;

-- select sqrt with group by (explain)
--Testcase 887:
EXPLAIN VERBOSE
SELECT count(value1), sqrt(1-value3) FROM s3 GROUP BY sqrt(1-value3) ORDER BY 1,2;

-- select sqrt with group by (result)
--Testcase 888:
SELECT count(value1), sqrt(1-value3) FROM s3 GROUP BY sqrt(1-value3) ORDER BY 1,2;

-- select sqrt with group by index (result)
--Testcase 889:
SELECT value1, sqrt(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select sqrt with group by index (result)
--Testcase 890:
SELECT value1, sqrt(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select sqrt with group by having (explain)
--Testcase 891:
EXPLAIN VERBOSE
SELECT count(value1), sqrt(1-value3) FROM s3 GROUP BY sqrt(1-value3) HAVING sqrt(avg(value1)) > 0 ORDER BY 1,2;

-- select sqrt with group by having (result)
--Testcase 892:
SELECT count(value1), sqrt(1-value3) FROM s3 GROUP BY sqrt(1-value3) HAVING sqrt(avg(value1)) > 0 ORDER BY 1,2;

-- select sqrt with group by index having (result)
--Testcase 893:
SELECT value1, sqrt(1-value3) FROM s3 GROUP BY 2,1 HAVING sqrt(1-value3) > 0 ORDER BY 1,2;

-- select sqrt with group by index having (result)
--Testcase 894:
SELECT value1, sqrt(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select sqrt and as (return null with negative number)
--Testcase 895:
SELECT value1, value3 + 1, sqrt(value1 + 1) as sqrt1 FROM s3 ORDER BY 1,2;

-- select tan (builtin function, explain)
--Testcase 896:
EXPLAIN VERBOSE
SELECT value1, tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select tan (builtin function, result)
--Testcase 897:
SELECT value1, tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 ORDER BY 1,2,3,4,5;

-- select tan (builtin function, not pushdown constraints, explain)
--Testcase 898:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select tan (builtin function, not pushdown constraints, result)
--Testcase 899:
SELECT tan(value1), tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select tan (builtin function, pushdown constraints, explain)
--Testcase 900:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE value2 != 200;

-- select tan (builtin function, pushdown constraints, result)
--Testcase 901:
SELECT tan(value1), tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE value2 != 200;

-- select tan (builtin function, tan in constraints, explain)
--Testcase 902:
EXPLAIN VERBOSE
SELECT value1, tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE tan(value1) != 1 ORDER BY 1,2,3,4,5;

-- select tan (builtin function, tan in constraints, result)
--Testcase 903:
SELECT value1, tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE tan(value1) != 1 ORDER BY 1,2,3,4,5;

-- select tan (builtin function, tan in constraints, explain)
--Testcase 904:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE tan(0.5) > value1;

-- select tan (builtin function, tan in constraints, result)
--Testcase 905:
SELECT tan(value1), tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE tan(0.5) > value1;

-- select tan as nest function with agg (pushdown, explain)
--Testcase 906:
EXPLAIN VERBOSE
SELECT sum(value3),tan(sum(value3)) FROM s3;

-- select tan as nest function with agg (pushdown, result)
--Testcase 907:
SELECT sum(value3),tan(sum(value3)) FROM s3;

-- select tan as nest with log2 (pushdown, explain)
--Testcase 908:
EXPLAIN VERBOSE
SELECT value1, tan(log2(value1)),tan(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select tan as nest with log2 (pushdown, result)
--Testcase 909:
SELECT value1, tan(log2(value1)),tan(log2(1/value1)) FROM s3 ORDER BY 1,2,3;

-- select tan with non pushdown func and explicit constant (explain)
--Testcase 910:
EXPLAIN VERBOSE
SELECT value1, tan(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select tan with non pushdown func and explicit constant (result)
--Testcase 911:
SELECT value1, tan(value3), pi(), 4.1 FROM s3 ORDER BY 1,2;

-- select tan with order by (explain)
--Testcase 912:
EXPLAIN VERBOSE
SELECT value1, tan(1-value3) FROM s3 ORDER BY tan(1-value3);

-- select tan with order by (result)
--Testcase 913:
SELECT value1, tan(1-value3) FROM s3 ORDER BY tan(1-value3);

-- select tan with order by index (result)
--Testcase 914:
SELECT value1, tan(1-value3) FROM s3 ORDER BY 2,1;

-- select tan with order by index (result)
--Testcase 915:
SELECT value1, tan(1-value3) FROM s3 ORDER BY 1,2;

-- select tan with group by (explain)
--Testcase 916:
EXPLAIN VERBOSE
SELECT value1, tan(1-value3) FROM s3 GROUP BY value1, tan(1-value3) ORDER BY 1,2;

-- select tan with group by (result)
--Testcase 917:
SELECT value1, tan(1-value3) FROM s3 GROUP BY value1, tan(1-value3) ORDER BY 1,2;

-- select tan with group by index (result)
--Testcase 918:
SELECT value1, tan(1-value3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select tan with group by index (result)
--Testcase 919:
SELECT value1, tan(1-value3) FROM s3 GROUP BY 1,2 ORDER BY 1,2;

-- select tan with group by having (explain)
--Testcase 920:
EXPLAIN VERBOSE
SELECT value1, tan(1-value3) FROM s3 GROUP BY value1, tan(1-value3) HAVING tan(avg(value1)) > 0 ORDER BY 1,2;

-- select tan with group by having (result)
--Testcase 921:
SELECT value1, tan(1-value3) FROM s3 GROUP BY value1, tan(1-value3) HAVING tan(avg(value1)) > 0 ORDER BY 1,2;

-- select tan with group by index having (result)
--Testcase 922:
SELECT value1, tan(1-value3) FROM s3 GROUP BY 2,1 HAVING tan(1-value3) > 0 ORDER BY 1,2;

-- select tan with group by index having (result)
--Testcase 923:
SELECT value1, tan(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

-- select tan and as
--Testcase 924:
SELECT value1, tan(value3) as tan1 FROM s3 ORDER BY 1,2;

-- round()
--Testcase 925:
EXPLAIN VERBOSE
SELECT round(value1), round(value3) FROM s3 ORDER BY 1,2;

--Testcase 926:
SELECT round(value1), round(value3) FROM s3 ORDER BY 1,2;

--Testcase 927:
EXPLAIN VERBOSE
SELECT round(value1), round(abs(value3)) FROM s3 ORDER BY 1,2;

--Testcase 928:
SELECT round(value1), round(abs(value3)) FROM s3 ORDER BY 1,2;

--Testcase 929:
EXPLAIN VERBOSE
SELECT round(abs(value2), 2) FROM s3 ORDER BY 1;

--Testcase 930:
SELECT round(abs(value2), 2) FROM s3 ORDER BY 1;

--Testcase 931:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE round(abs(value2), 2) = 100.00;

--Testcase 932:
SELECT * FROM s3 WHERE round(abs(value2), 2) = 100.00;

--Testcase 933:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE round(value1) = 1;

--Testcase 934:
SELECT * FROM s3 WHERE round(value1) = 1;

--Testcase 935:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE round(value3) = -1;

--Testcase 936:
SELECT * FROM s3 WHERE round(value3) = -1;

-- test for cast function:
-- convert()
-- select convert (stub function, explain)
--Testcase 937:
EXPLAIN VERBOSE
SELECT convert(value1, 'decimal(1)'), convert(value2, 'decimal(10, 2)'), convert(id, 'YEAR'), convert(value4, 'binary(1)')::bytea FROM s3;

-- select convert (stub function, result)
--Testcase 938:
SELECT * FROM (
SELECT convert(value1, 'decimal(1)'), convert(value2, 'decimal(10, 2)'), convert(id, 'YEAR'), convert(value4, 'binary(1)')::bytea FROM s3
) t ORDER BY 1, 2, 3, 4;

-- select convert (stub function, not pushdown constraints, explain)
--Testcase 939:
EXPLAIN VERBOSE
SELECT convert(value1, 'decimal(1)'), convert(value2, 'decimal(10, 2)'), convert(id, 'YEAR'), convert(value4, 'binary(1)')::bytea FROM s3 WHERE to_hex(value2) != '64';

-- select convert (stub function, not pushdown constraints, result)
--Testcase 940:
SELECT * FROM (
SELECT convert(value1, 'decimal(1)'), convert(value2, 'decimal(10, 2)'), convert(id, 'YEAR'), convert(value4, 'binary(1)')::bytea FROM s3 WHERE to_hex(value2) != '64'
) t ORDER BY 1, 2, 3, 4;

-- select convert (stub function, pushdown constraints, explain)
--Testcase 941:
EXPLAIN VERBOSE
SELECT convert(value1, 'decimal(1)'), convert(value2, 'decimal(10, 2)'), convert(id, 'YEAR'), convert(value4, 'binary(1)')::bytea FROM s3 WHERE value2 != 200;

-- select convert (stub function, pushdown constraints, result)
--Testcase 942:
SELECT * FROM (
SELECT convert(value1, 'decimal(1)'), convert(value2, 'decimal(10, 2)'), convert(id, 'YEAR'), convert(value4, 'binary(1)')::bytea FROM s3 WHERE value2 != 200
) t ORDER BY 1, 2, 3, 4;

-- select convert as nest function with agg (pushdown, explain)
--Testcase 943:
EXPLAIN VERBOSE
SELECT sum(id), convert(sum(id), 'YEAR') FROM s3;

-- select convert as nest function with agg (pushdown, result)
--Testcase 944:
SELECT sum(id), convert(sum(id), 'YEAR') FROM s3;

-- select convert as nest with log2 (pushdown, explain)
--Testcase 945:
EXPLAIN VERBOSE
SELECT convert(log2(value1), 'decimal(12,4)')::numeric, convert(log2(1/value1), 'decimal(12,4)')::numeric FROM s3;

-- select convert as nest with log2 (pushdown, result)
--Testcase 946:
SELECT * FROM (
SELECT convert(log2(value1), 'decimal(12,4)')::numeric, convert(log2(1/value1), 'decimal(12,4)')::numeric FROM s3
) t ORDER BY 1, 2;

-- select cast json_extract with type modifier (explain)
--Testcase 947:
EXPLAIN VERBOSE
SELECT convert(json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a'), 'datetime(3)')::timestamp, convert(json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a'), 'datetime(3)')::timestamptz, convert(json_extract('{"a": "12:10:20.123456"}', '$.a'), 'time(3)')::time, convert(json_extract('{"a": "12:10:20.123456"}', '$.a'), 'time(3)')::timetz FROM s3;

-- select cast json_extract with type modifier (result)
--Testcase 948:
SELECT * FROM (
SELECT convert(json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a'), 'datetime(3)')::timestamp, convert(json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a'), 'datetime(3)')::timestamptz, convert(json_extract('{"a": "12:10:20.123456"}', '$.a'), 'time(3)')::time, convert(json_extract('{"a": "12:10:20.123456"}', '$.a'), 'time(3)')::timetz FROM s3
) t ORDER BY 1, 2, 3, 4;
-- select cast json_extract with type modifier (explain)
--Testcase 949:
EXPLAIN VERBOSE
SELECT convert(json_extract('{"a": 100}', '$.a'), 'decimal(10,2)')::numeric, convert(json_extract('{"a": 10}', '$.a'), 'YEAR')::decimal, convert(json_unquote(json_extract('{"a": "1.123456"}', '$.a')), 'decimal(10, 3)')::numeric FROM s3;

-- select cast json_extract with type modifier (result)
--Testcase 950:
SELECT * FROM (
SELECT convert(json_extract('{"a": 100}', '$.a'), 'decimal(10,2)')::numeric, convert(json_extract('{"a": 10}', '$.a'), 'YEAR')::decimal, convert(json_unquote(json_extract('{"a": "1.123456"}', '$.a')), 'decimal(10, 3)')::numeric FROM s3
) t ORDER BY 1, 2, 3;

-- select convert with non pushdown func and explicit constant (explain)
--Testcase 951:
EXPLAIN VERBOSE
SELECT convert(id, 'YEAR'), pi(), 4.1 FROM s3;

-- select convert with non pushdown func and explicit constant (result)
--Testcase 952:
SELECT * FROM (
SELECT convert(id, 'YEAR'), pi(), 4.1 FROM s3
) t ORDER BY 1;

-- select convert with order by index (result)
--Testcase 953:
SELECT value1, convert(1.123456 - value1,'char(3)') FROM s3 order by 2,1;

-- select convert with order by index (result)
--Testcase 954:
SELECT value1, convert(1.123456 - value1,'char(3)') FROM s3 order by 1,2;

-- select convert and as
--Testcase 955:
SELECT * FROM (
SELECT convert(id, 'YEAR') as convert1 FROM s3
) t ORDER BY 1;

-- full text search table
-- text search (pushdown, explain)
--Testcase 956:
EXPLAIN VERBOSE
SELECT MATCH_AGAINST(content, 'success catches') AS score, content FROM ftextsearch WHERE MATCH_AGAINST(content, 'success catches','IN BOOLEAN MODE') != 0;

-- text search (pushdown, result)
--Testcase 957:
SELECT content FROM (
SELECT MATCH_AGAINST(content, 'success catches') AS score, content FROM ftextsearch WHERE MATCH_AGAINST(content, 'success catches','IN BOOLEAN MODE') != 0
) AS t ORDER BY 1;

-- ===============================================================================
-- test string functions
-- ===============================================================================

--
-- test ascii()
--
-- select ascii (stub function, explain)
--Testcase 958:
EXPLAIN VERBOSE
SELECT ascii(tag1), ascii(str1), ascii(str2) FROM s3 ORDER BY 1,2,3;
-- select ascii (stub function, result)
--Testcase 959:
SELECT ascii(tag1), ascii(str1), ascii(str2) FROM s3 ORDER BY 1,2,3;


-- select ascii (stub function, pushdown constraints, explain)
--Testcase 960:
EXPLAIN VERBOSE
SELECT ascii(tag1), ascii(str1), ascii(str2) FROM s3 WHERE value2 != 100;
-- select ascii (stub function, pushdown constraints, result)
--Testcase 961:
SELECT ascii(tag1), ascii(str1), ascii(str2) FROM s3 WHERE value2 != 100;

-- select ascii (stub function, ascii in constraints, explain)
--Testcase 962:
EXPLAIN VERBOSE
SELECT ascii(tag1), ascii(str1), ascii(str2) FROM s3 WHERE ascii(str1) <= 97 ORDER BY 1,2,3;
-- select ascii (stub function, ascii in constraints, explain)
--Testcase 963:
SELECT ascii(tag1), ascii(str1), ascii(str2) FROM s3 WHERE ascii(str1) <= 97 ORDER BY 1,2,3;

-- select ascii with non pushdown func and explicit constant (explain)
--Testcase 964:
EXPLAIN VERBOSE
SELECT ascii(str1), pi(), 4.1 FROM s3;
-- select ascii with non pushdown func and explicit constant (result)
--Testcase 965:
SELECT ascii(str1), pi(), 4.1 FROM s3;

-- select ascii with order by (explain)
--Testcase 966:
EXPLAIN VERBOSE
SELECT value1, ascii(str2) FROM s3 ORDER BY value1, ascii(str2);
-- select ascii with order by (result)
--Testcase 967:
SELECT value1, ascii(str2) FROM s3 ORDER BY value1, ascii(str2);

-- select ascii with order by index (result)
--Testcase 968:
SELECT value1, ascii(str2) FROM s3 ORDER BY 2,1;

-- select ascii with group by (explain)
--Testcase 969:
EXPLAIN VERBOSE
SELECT count(value1), ascii(str1) FROM s3 GROUP BY ascii(str1) ORDER BY 1,2;
-- select ascii with group by (result)
--Testcase 970:
SELECT count(value1), ascii(str1) FROM s3 GROUP BY ascii(str1) ORDER BY 1,2;

-- select ascii with group by index (result)
--Testcase 971:
SELECT value1, ascii(str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select ascii with group by having (explain)
--Testcase 972:
EXPLAIN VERBOSE
SELECT count(value1), ascii(str1) FROM s3 GROUP BY ascii(str1) HAVING ascii(str1) IS NOT NULL ORDER BY 1,2;
-- select ascii with group by having (explain)
--Testcase 973:
SELECT count(value1), ascii(str1) FROM s3 GROUP BY ascii(str1) HAVING ascii(str1) IS NOT NULL ORDER BY 1,2;

-- select ascii with group by index having (result)
--Testcase 974:
SELECT value1, ascii(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test bin()
--
-- select bin (stub function, explain)
--Testcase 975:
EXPLAIN VERBOSE
SELECT id, bin(id), bin(value2), bin(value4) FROM s3 ORDER BY 1,2,3,4;
-- select bin (stub function, result)
--Testcase 976:
SELECT id, bin(id), bin(value2), bin(value4) FROM s3 ORDER BY 1,2,3,4;

-- select bin (stub function, pushdown constraints, explain)
--Testcase 977:
EXPLAIN VERBOSE
SELECT bin(id), bin(value2) FROM s3 WHERE value2 != 200;
-- select bin (stub function, pushdown constraints, result)
--Testcase 978:
SELECT bin(id), bin(value2) FROM s3 WHERE value2 != 200;

-- select bin (stub function, bin in constraints, explain)
--Testcase 979:
EXPLAIN VERBOSE
SELECT bin(id), bin(value2) FROM s3 WHERE bin(value2) != '1100100';
-- select bin (stub function, bin in constraints, explain)
--Testcase 980:
SELECT bin(id), bin(value2) FROM s3 WHERE bin(value2) != '1100100';

--select bin as nest function with agg (explain)
--Testcase 981:
EXPLAIN VERBOSE
SELECT sum(id), bin(sum(value2)) FROM s3;
--select bin as nest function with agg (result)
--Testcase 982:
SELECT sum(id), bin(sum(value2)) FROM s3;

-- select bin with non pushdown func and explicit constant (explain)
--Testcase 983:
EXPLAIN VERBOSE
SELECT bin(value2), pi(), 4.1 FROM s3 ORDER BY 1;
-- select bin with non pushdown func and explicit constant (explain)
--Testcase 984:
SELECT bin(value2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select bin with order by (explain)
--Testcase 985:
EXPLAIN VERBOSE
SELECT id, bin(value2) FROM s3 ORDER BY id, bin(value2);
-- select bin with order by (result)
--Testcase 986:
SELECT id, bin(value2) FROM s3 ORDER BY id, bin(value2);

-- select bin with order by index (result)
--Testcase 987:
SELECT value1, bin(value2) FROM s3 ORDER BY 2,1;
-- select bin with order by index (result)
--Testcase 988:
SELECT value1, bin(value2) FROM s3 ORDER BY 1,2;

-- select bin with group by (explain)
--Testcase 989:
EXPLAIN VERBOSE
SELECT count(value1), bin(value2) FROM s3 GROUP BY bin(value2) ORDER BY 1,2;
-- select bin with group by (result)
--Testcase 990:
SELECT count(value1), bin(value2) FROM s3 GROUP BY bin(value2) ORDER BY 1,2;

-- select bin with group by index (result)
--Testcase 991:
SELECT value1, bin(value2) FROM s3 GROUP BY 2,1  ORDER BY 1,2;

-- select bin with group by having (explain)
--Testcase 992:
EXPLAIN VERBOSE
SELECT value1, bin(value2 - 1) FROM s3 GROUP BY 1, bin(value2 - 1) HAVING value1 > 1 ORDER BY 1,2;
-- select bin with group by having (result)
--Testcase 993:
SELECT value1, bin(value2 - 1) FROM s3 GROUP BY 1, bin(value2 - 1) HAVING value1 > 1 ORDER BY 1,2;

-- select bin with group by index having (result)
--Testcase 994:
SELECT value1, bin(value2 - 1) FROM s3 GROUP BY 1,2 HAVING value1 > 1  ORDER BY 1,2;

--
-- test bit_length()
--
-- select bit_length (stub function, explain)
--Testcase 995:
EXPLAIN VERBOSE
SELECT bit_length(tag1), bit_length(str1), bit_length(str2) FROM s3;
-- select bit_length (stub function, result)
--Testcase 996:
SELECT bit_length(tag1), bit_length(str1), bit_length(str2) FROM s3;

-- select bit_length (stub function, pushdown constraints, explain)
--Testcase 997:
EXPLAIN VERBOSE
SELECT bit_length(tag1), bit_length(str1), bit_length(str2) FROM s3 WHERE value2 != 100;
-- select bit_length (stub function, pushdown constraints, result)
--Testcase 998:
SELECT bit_length(tag1), bit_length(str1), bit_length(str2) FROM s3 WHERE value2 != 100;

-- select bit_length (stub function, bit_length in constraints, explain)
--Testcase 999:
EXPLAIN VERBOSE
SELECT bit_length(tag1), bit_length(str1), bit_length(str2) FROM s3 WHERE value2 != 200;
-- select bit_length (stub function, bit_length in constraints, explain)
--Testcase 1000:
SELECT bit_length(tag1), bit_length(str1), bit_length(str2) FROM s3 WHERE value2 != 200;

-- select bit_length with non pushdown func and explicit constant (explain)
--Testcase 1001:
EXPLAIN VERBOSE
SELECT bit_length(str1), pi(), 4.1 FROM s3;
-- select bit_length with non pushdown func and explicit constant (result)
--Testcase 1002:
SELECT bit_length(str1), pi(), 4.1 FROM s3;

-- select bit_length with order by (explain)
--Testcase 1003:
EXPLAIN VERBOSE
SELECT value1, bit_length(str2) FROM s3 ORDER BY value1, bit_length(str2);
-- select bit_length with order by (result)
--Testcase 1004:
SELECT value1, bit_length(str2) FROM s3 ORDER BY value1, bit_length(str2);

-- select bit_length with order by index (result)
--Testcase 1005:
SELECT value1, bit_length(str2) FROM s3 ORDER BY 2,1;

-- select bit_length with group by (explain)
--Testcase 1006:
EXPLAIN VERBOSE
SELECT count(value1), bit_length(str1) FROM s3 GROUP BY bit_length(str1) ORDER BY 1,2;
-- select bit_length with group by (result)
--Testcase 1007:
SELECT count(value1), bit_length(str1) FROM s3 GROUP BY bit_length(str1) ORDER BY 1,2;

-- select bit_length with group by index (result)
--Testcase 1008:
SELECT value1, bit_length(str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select bit_length with group by having (explain)
--Testcase 1009:
EXPLAIN VERBOSE
SELECT count(value1), bit_length(str1) FROM s3 GROUP BY bit_length(str1), str1 HAVING bit_length(str1) IS NOT NULL ORDER BY 1,2;
-- select bit_length with group by having (explain)
--Testcase 1010:
SELECT count(value1), bit_length(str1) FROM s3 GROUP BY bit_length(str1), str1 HAVING bit_length(str1) IS NOT NULL ORDER BY 1,2;

-- select bit_length with group by index having (result)
--Testcase 1011:
SELECT value1, bit_length(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test char()
--
-- select char (stub function, explain)
--Testcase 1012:
EXPLAIN VERBOSE
SELECT mysql_char(value2), mysql_char(value4) FROM s3 ORDER BY 2,1;
-- select char (stub function, result)
--Testcase 1013:
SELECT mysql_char(value2), mysql_char(value4) FROM s3 ORDER BY 2,1;

-- select char (stub function, not pushdown constraints, explain)
--Testcase 1014:
EXPLAIN VERBOSE
SELECT value1, mysql_char(value2) FROM s3 WHERE to_hex(value2) = '64';
-- select char (stub function, not pushdown constraints, result)
--Testcase 1015:
SELECT value1, mysql_char(value2) FROM s3 WHERE to_hex(value2) = '64';

-- select char (stub function, pushdown constraints, explain)
--Testcase 1016:
EXPLAIN VERBOSE
SELECT value1, mysql_char(value2) FROM s3 WHERE value2 != 200;
-- select char (stub function, pushdown constraints, result)
--Testcase 1017:
SELECT value1, mysql_char(value2) FROM s3 WHERE value2 != 200;

-- select char with non pushdown func and explicit constant (explain)
--Testcase 1018:
EXPLAIN VERBOSE
SELECT mysql_char(value2), pi(), 4.1 FROM s3 ORDER BY 1 DESC;
-- select char with non pushdown func and explicit constant (result)
--Testcase 1019:
SELECT mysql_char(value2), pi(), 4.1 FROM s3 ORDER BY 1 DESC;

-- select char with order by (explain)
--Testcase 1020:
EXPLAIN VERBOSE
SELECT value1, mysql_char(value2) FROM s3 ORDER BY value1, mysql_char(value2);
-- select char with order by (result)
--Testcase 1021:
SELECT value1, mysql_char(value2) FROM s3 ORDER BY value1, mysql_char(value2);

-- select char with order by index (result)
--Testcase 1022:
SELECT value1, mysql_char(value2) FROM s3 ORDER BY 1,2;

-- select char with group by (explain)
--Testcase 1023:
EXPLAIN VERBOSE
SELECT value1, mysql_char(value2) FROM s3 GROUP BY value1, mysql_char(value2) ORDER BY 1,2;
-- select char with group by (result)
--Testcase 1024:
SELECT value1, mysql_char(value2) FROM s3 GROUP BY value1, mysql_char(value2) ORDER BY 1,2;

-- select char with group by index (result)
--Testcase 1025:
SELECT value1, mysql_char(value2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select char with group by having (explain)
--Testcase 1026:
EXPLAIN VERBOSE
SELECT value1, mysql_char(value2) FROM s3 GROUP BY mysql_char(value2), value2, value1 HAVING mysql_char(value2) IS NOT NULL ORDER BY 1,2;
-- select char with group by having (result)
--Testcase 1027:
SELECT value1, mysql_char(value2) FROM s3 GROUP BY mysql_char(value2), value2, value1 HAVING mysql_char(value2) IS NOT NULL ORDER BY 1,2;

-- select char with group by index having (result)
--Testcase 1028:
SELECT value1, mysql_char(value2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test char_length()
--
-- select char_length (stub function, explain)
--Testcase 1029:
EXPLAIN VERBOSE
SELECT char_length(tag1), char_length(str1), char_length(str2) FROM s3;
-- select char_length (stub function, result)
--Testcase 1030:
SELECT char_length(tag1), char_length(str1), char_length(str2) FROM s3;

-- select char_length (stub function, not pushdown constraints, explain)
--Testcase 1031:
EXPLAIN VERBOSE
SELECT id, char_length(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select char_length (stub function, not pushdown constraints, explain)
--Testcase 1032:
SELECT id, char_length(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select char_length (stub function, char_length in constraints, explain)
--Testcase 1033:
EXPLAIN VERBOSE
SELECT id, char_length(str1) FROM s3 WHERE char_length(str1) > 0 ORDER BY 1,2;
-- select char_length (stub function, char_length in constraints, result)
--Testcase 1034:
SELECT id, char_length(str1) FROM s3 WHERE char_length(str1) > 0 ORDER BY 1,2;

-- select char_length with non pushdown func and explicit constant (explain)
--Testcase 1035:
EXPLAIN VERBOSE
SELECT char_length(str1), pi(), 4.1 FROM s3;
-- select char_length with non pushdown func and explicit constant (result)
--Testcase 1036:
SELECT char_length(str1), pi(), 4.1 FROM s3;

-- select char_length with order by (explain)
--Testcase 1037:
EXPLAIN VERBOSE
SELECT value1, char_length(str1) FROM s3 ORDER BY char_length(str1), 1 DESC;
-- select char_length with order by (result)
--Testcase 1038:
SELECT value1, char_length(str1) FROM s3 ORDER BY char_length(str1), 1 DESC;

-- select char_length with group by (explain)
--Testcase 1039:
EXPLAIN VERBOSE
SELECT count(value1), char_length(str1) FROM s3 GROUP BY char_length(str1) ORDER BY 1,2;
-- select char_length with group by (result)
--Testcase 1040:
SELECT count(value1), char_length(str1) FROM s3 GROUP BY char_length(str1) ORDER BY 1,2;

-- select char_length with group by index (result)
--Testcase 1041:
SELECT value1, char_length(str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select char_length with group by having (explain)
--Testcase 1042:
EXPLAIN VERBOSE
SELECT count(value1), char_length(str1) FROM s3 GROUP BY char_length(str1), str1 HAVING char_length(str1) > 0 ORDER BY 1,2;
-- select char_length with group by having (result)
--Testcase 1043:
SELECT count(value1), char_length(str1) FROM s3 GROUP BY char_length(str1), str1 HAVING char_length(str1) > 0 ORDER BY 1,2;

-- select char_length with group by index having (result)
--Testcase 1044:
SELECT value1, char_length(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test character_length()
--
-- select character_length (stub function, explain)
--Testcase 1045:
EXPLAIN VERBOSE
SELECT character_length(tag1), character_length(str1), character_length(str2) FROM s3;
-- select character_length (stub function, result)
--Testcase 1046:
SELECT character_length(tag1), character_length(str1), character_length(str2) FROM s3;

-- select character_length (stub function, not pushdown constraints, explain)
--Testcase 1047:
EXPLAIN VERBOSE
SELECT id, character_length(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select character_length (stub function, not pushdown constraints, explain)
--Testcase 1048:
SELECT id, character_length(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select character_length (stub function, character_length in constraints, explain)
--Testcase 1049:
EXPLAIN VERBOSE
SELECT id, character_length(str1) FROM s3 WHERE character_length(str1) > 0 ORDER BY 1,2;
-- select character_length (stub function, character_length in constraints, result)
--Testcase 1050:
SELECT id, character_length(str1) FROM s3 WHERE character_length(str1) > 0 ORDER BY 1,2;

-- select character_length with non pushdown func and explicit constant (explain)
--Testcase 1051:
EXPLAIN VERBOSE
SELECT character_length(str1), pi(), 4.1 FROM s3;
-- select character_length with non pushdown func and explicit constant (result)
--Testcase 1052:
SELECT character_length(str1), pi(), 4.1 FROM s3;

-- select character_length with order by (explain)
--Testcase 1053:
EXPLAIN VERBOSE
SELECT value1, character_length(str1) FROM s3 ORDER BY character_length(str1), 1 DESC;
-- select character_length with order by (result)
--Testcase 1054:
SELECT value1, character_length(str1) FROM s3 ORDER BY character_length(str1), 1 DESC;

-- select character_length with group by (explain)
--Testcase 1055:
EXPLAIN VERBOSE
SELECT count(value1), character_length(str1) FROM s3 GROUP BY character_length(str1) ORDER BY 1,2;
-- select character_length with group by (result)
--Testcase 1056:
SELECT count(value1), character_length(str1) FROM s3 GROUP BY character_length(str1) ORDER BY 1,2;

-- select character_length with group by index (result)
--Testcase 1057:
SELECT value1, character_length(str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select character_length with group by having (explain)
--Testcase 1058:
EXPLAIN VERBOSE
SELECT count(value1), character_length(str1) FROM s3 GROUP BY character_length(str1), str1 HAVING character_length(str1) > 0 ORDER BY 1,2;
-- select character_length with group by having (result)
--Testcase 1059:
SELECT count(value1), character_length(str1) FROM s3 GROUP BY character_length(str1), str1 HAVING character_length(str1) > 0 ORDER BY 1,2;

-- select character_length with group by index having (result)
--Testcase 1060:
SELECT value1, character_length(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test concat()
--
-- select concat (stub function, explain)
--Testcase 1061:
EXPLAIN VERBOSE
SELECT concat(id), concat(tag1), concat(value1), concat(value2), concat(str1) FROM s3 ORDER BY 1,2,3,4,5;
-- select concat (stub function, result)
--Testcase 1062:
SELECT concat(id), concat(tag1), concat(value1), concat(value2), concat(str1) FROM s3 ORDER BY 1,2,3,4,5;

-- select concat (stub function, pushdown constraints, explain)
--Testcase 1063:
EXPLAIN VERBOSE
SELECT id, concat(str1, str2) FROM s3 WHERE value2 != 100;
-- select concat (stub function, pushdown constraints, result)
--Testcase 1064:
SELECT id, concat(str1, str2) FROM s3 WHERE value2 != 100;

-- select concat (stub function, concat in constraints, explain)
--Testcase 1065:
EXPLAIN VERBOSE
SELECT id, concat(str1, str2) FROM s3 WHERE concat(str1, str2) != 'XYZ' ORDER BY 1,2;
-- select concat (stub function, concat in constraints, explain)
--Testcase 1066:
SELECT id, concat(str1, str2) FROM s3 WHERE concat(str1, str2) != 'XYZ' ORDER BY 1,2;

-- select concat as nest function with agg (pushdown, explain)
--Testcase 1067:
EXPLAIN VERBOSE
SELECT id, concat(sum(value1), str1) FROM s3 GROUP BY id, str1 ORDER BY 1,2;
-- select concat as nest function with agg (pushdown, result)
--Testcase 1068:
SELECT id, concat(sum(value1), str1) FROM s3 GROUP BY id, str1 ORDER BY 1,2;

-- select concat with non pushdown func and explicit constant (explain)
--Testcase 1069:
EXPLAIN VERBOSE
SELECT concat(str1, str2), pi(), 4.1 FROM s3;
-- select concat with non pushdown func and explicit constant (result)
--Testcase 1070:
SELECT concat(str1, str2), pi(), 4.1 FROM s3;

-- select concat with order by (explain)
--Testcase 1071:
EXPLAIN VERBOSE
SELECT value1, concat(value2, str2) FROM s3 ORDER BY value1, concat(value2, str2);
-- select concat with order by (result)
--Testcase 1072:
SELECT value1, concat(value2, str2) FROM s3 ORDER BY value1, concat(value2, str2);

-- select concat with order by index (result)
--Testcase 1073:
SELECT value1, concat(value2, str2) FROM s3 ORDER BY 2,1;

-- select concat with group by (explain)
--Testcase 1074:
EXPLAIN VERBOSE
SELECT count(value1), concat(str1, str2) FROM s3 GROUP BY concat(str1, str2) ORDER BY 1,2;
-- select concat with group by (result)
--Testcase 1075:
SELECT count(value1), concat(str1, str2) FROM s3 GROUP BY concat(str1, str2) ORDER BY 1,2;

-- select concat with group by index (result)
--Testcase 1076:
SELECT value1, concat(str1, str2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select concat with group by having (explain)
--Testcase 1077:
EXPLAIN VERBOSE
SELECT count(value1), concat(str1, str2) FROM s3 GROUP BY concat(str1, str2) HAVING concat(str1, str2) IS NOT NULL ORDER BY 1,2;
-- select concat with group by having (explain)
--Testcase 1078:
SELECT count(value1), concat(str1, str2) FROM s3 GROUP BY concat(str1, str2) HAVING concat(str1, str2) IS NOT NULL ORDER BY 1,2;

-- select concat with group by index having (result)
--Testcase 1079:
SELECT value1, concat(str1, str2, value1, value2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test concat_ws()
--
-- select concat_ws (stub function, explain)
--Testcase 1080:
EXPLAIN VERBOSE
SELECT concat_ws(',', str2, str1, tag1, value2) FROM s3 ORDER BY 1;
-- select concat_ws (stub function, explain)
--Testcase 1081:
SELECT concat_ws(',', str2, str1, tag1, value2) FROM s3 ORDER BY 1;

-- select concat_ws (stub function, not pushdown constraints, explain)
--Testcase 1082:
EXPLAIN VERBOSE
SELECT value1, concat_ws('.', str2, str1) FROM s3 WHERE to_hex(value2) = '64';
-- select concat_ws (stub function, not pushdown constraints, result)
--Testcase 1083:
SELECT value1, concat_ws('.', str2, str1) FROM s3 WHERE to_hex(value2) = '64';

-- select concat_ws (stub function, pushdown constraints, explain)
--Testcase 1084:
EXPLAIN VERBOSE
SELECT value1, concat_ws('.', str2, str1) FROM s3 WHERE value2 != 200;
-- select concat_ws (stub function, pushdown constraints, result)
--Testcase 1085:
SELECT value1, concat_ws('.', str2, str1) FROM s3 WHERE value2 != 200;

-- select concat_ws with non pushdown func and explicit constant (explain)
--Testcase 1086:
EXPLAIN VERBOSE
SELECT concat_ws('.', str2, str1), pi(), 4.1 FROM s3;
-- select concat_ws with non pushdown func and explicit constant (result)
--Testcase 1087:
SELECT concat_ws('.', str2, str1), pi(), 4.1 FROM s3;

-- select concat_ws with order by (explain)
--Testcase 1088:
EXPLAIN VERBOSE
SELECT value1, concat_ws('.', str2, str1) FROM s3 ORDER BY value1, concat_ws('.', str2, str1);
-- select concat_ws with order by (result)
--Testcase 1089:
SELECT value1, concat_ws('.', str2, str1) FROM s3 ORDER BY value1, concat_ws('.', str2, str1);

-- select concat_ws with order by index (result)
--Testcase 1090:
SELECT value1, concat_ws('.', str2, str1) FROM s3 ORDER BY 2,1;
-- select concat_ws with order by index (result)
--Testcase 1091:
SELECT value1, concat_ws('.', value1, value4) FROM s3 ORDER BY 1,2;

-- select concat_ws with group by (explain)
--Testcase 1092:
EXPLAIN VERBOSE
SELECT count(value1), concat_ws('.', str2, str1) FROM s3 GROUP BY concat_ws('.', str2, str1) ORDER BY 1,2;
-- select concat_ws with group by (result)
--Testcase 1093:
SELECT count(value1), concat_ws('.', str2, str1) FROM s3 GROUP BY concat_ws('.', str2, str1) ORDER BY 1,2;

-- select concat_ws with group by index (result)
--Testcase 1094:
SELECT value1, concat_ws('.', str2, str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select concat_ws with group by having (explain)
--Testcase 1095:
EXPLAIN VERBOSE
SELECT count(value1), concat_ws('.', str2, str1) FROM s3 GROUP BY concat_ws('.', str2, str1) HAVING concat_ws('.', str2, str1) IS NOT NULL ORDER BY 1,2;
-- select concat_ws with group by having (result)
--Testcase 1096:
SELECT count(value1), concat_ws('.', str2, str1) FROM s3 GROUP BY concat_ws('.', str2, str1) HAVING concat_ws('.', str2, str1) IS NOT NULL ORDER BY 1,2;

-- select concat_ws with group by index having (result)
--Testcase 1097:
SELECT value1, concat_ws('.', str2, str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test elt()
--
-- select elt (stub function, explain)
--Testcase 1098:
EXPLAIN VERBOSE
SELECT elt(1, str2, str1, tag1) FROM s3;
-- select elt (stub function, result)
--Testcase 1099:
SELECT elt(1, str2, str1, tag1) FROM s3;

-- select elt (stub function, not pushdown constraints, explain)
--Testcase 1100:
EXPLAIN VERBOSE
SELECT value1, elt(1, str2, str1) FROM s3 WHERE to_hex(value2) = '64';
-- select elt (stub function, not pushdown constraints, result)
--Testcase 1101:
SELECT value1, elt(1, str2, str1) FROM s3 WHERE to_hex(value2) = '64';

-- select elt (stub function, pushdown constraints, explain)
--Testcase 1102:
EXPLAIN VERBOSE
SELECT value1, elt(1, str2, str1) FROM s3 WHERE value2 != 200;
-- select elt (stub function, pushdown constraints, result)
--Testcase 1103:
SELECT value1, elt(1, str2, str1) FROM s3 WHERE value2 != 200;

-- select elt with non pushdown func and explicit constant (explain)
--Testcase 1104:
EXPLAIN VERBOSE
SELECT elt(1, str2, str1), pi(), 4.1 FROM s3;
-- select elt with non pushdown func and explicit constant (result)
--Testcase 1105:
SELECT elt(1, str2, str1), pi(), 4.1 FROM s3;

-- select elt with order by (explain)
--Testcase 1106:
EXPLAIN VERBOSE
SELECT value1, elt(1, str2, str1) FROM s3 ORDER BY value1, elt(1, str2, str1);
-- select elt with order by (result)
--Testcase 1107:
SELECT value1, elt(1, str2, str1) FROM s3 ORDER BY value1, elt(1, str2, str1);

-- select elt with order by index (result)
--Testcase 1108:
SELECT value1, elt(1, str2, str1) FROM s3 ORDER BY 2,1;
-- select elt with order by index (result)
--Testcase 1109:
SELECT value1, elt(1, str2, str1) FROM s3 ORDER BY 1,2;

-- select elt with group by (explain)
--Testcase 1110:
EXPLAIN VERBOSE
SELECT count(value1), elt(1, str2, str1) FROM s3 GROUP BY elt(1, str2, str1) ORDER BY 1,2;
-- select elt with group by (result)
--Testcase 1111:
SELECT count(value1), elt(1, str2, str1) FROM s3 GROUP BY elt(1, str2, str1) ORDER BY 1,2;

-- select elt with group by index (result)
--Testcase 1112:
SELECT value1, elt(1, str2, str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select elt with group by having (explain)
--Testcase 1113:
EXPLAIN VERBOSE
SELECT count(value1), elt(1, str2, str1) FROM s3 GROUP BY elt(1, str2, str1), str1, str2 HAVING elt(1, str2, str1) IS NOT NULL ORDER BY 1,2;
-- select elt with group by having (result)
--Testcase 1114:
SELECT count(value1), elt(1, str2, str1) FROM s3 GROUP BY elt(1, str2, str1), str1, str2 HAVING elt(1, str2, str1) IS NOT NULL ORDER BY 1,2;

-- select elt with group by index having (result)
--Testcase 1115:
SELECT value1, elt(1, str2, str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test export_set()
--
-- select export_set (stub function, explain)
--Testcase 1116:
EXPLAIN VERBOSE
SELECT export_set(5, str2, str1) FROM s3;
-- select export_set (stub function, result)
--Testcase 1117:
SELECT export_set(5, str2, str1) FROM s3;

--Testcase 1118:
EXPLAIN VERBOSE
SELECT export_set(5, str2, str1, ',') FROM s3;
-- select export_set (stub function, result)
--Testcase 1119:
SELECT export_set(5, str2, str1, ',') FROM s3;

-- select export_set (stub function, explain)
--Testcase 1120:
EXPLAIN VERBOSE
SELECT export_set(5, str2, str1, ',', 2) FROM s3;
-- select export_set (stub function, result)
--Testcase 1121:
SELECT export_set(5, str2, str1, ',', 2) FROM s3;

-- select export_set (stub function, not pushdown constraints, explain)
--Testcase 1122:
EXPLAIN VERBOSE
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 WHERE to_hex(value2) = '64';
-- select export_set (stub function, not pushdown constraints, result)
--Testcase 1123:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 WHERE to_hex(value2) = '64';

-- select export_set (stub function, pushdown constraints, explain)
--Testcase 1124:
EXPLAIN VERBOSE
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 WHERE value2 != 200;
-- select export_set (stub function, pushdown constraints, result)
--Testcase 1125:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 WHERE value2 != 200;

-- select export_set with non pushdown func and explicit constant (explain)
--Testcase 1126:
EXPLAIN VERBOSE
SELECT export_set(5, str2, str1, ',', 2), pi(), 4.1 FROM s3;
-- select export_set with non pushdown func and explicit constant (result)
--Testcase 1127:
SELECT export_set(5, str2, str1, ',', 2), pi(), 4.1 FROM s3;

-- select export_set with order by (explain)
--Testcase 1128:
EXPLAIN VERBOSE
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 ORDER BY value1, export_set(5, str2, str1, ',', 2);
-- select export_set with order by (result)
--Testcase 1129:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 ORDER BY value1, export_set(5, str2, str1, ',', 2);

-- select export_set with order by index (result)
--Testcase 1130:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 ORDER BY 2,1;
-- select export_set with order by index (result)
--Testcase 1131:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 ORDER BY 1,2;

-- select export_set with group by (explain)
--Testcase 1132:
EXPLAIN VERBOSE
SELECT count(value1), export_set(5, str2, str1, ',', 2) FROM s3 GROUP BY export_set(5, str2, str1, ',', 2) ORDER BY 1,2;
-- select export_set with group by (result)
--Testcase 1133:
SELECT count(value1), export_set(5, str2, str1, ',', 2) FROM s3 GROUP BY export_set(5, str2, str1, ',', 2) ORDER BY 1,2;

-- select export_set with group by index (result)
--Testcase 1134:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select export_set with group by having (explain)
--Testcase 1135:
EXPLAIN VERBOSE
SELECT count(value1), export_set(5, str2, str1, ',', 2) FROM s3 GROUP BY export_set(5, str2, str1, ',', 2), str1, str2 HAVING export_set(5, str2, str1, ',', 2) IS NOT NULL ORDER BY 1,2;
-- select export_set with group by having (result)
--Testcase 1136:
SELECT count(value1), export_set(5, str2, str1, ',', 2) FROM s3 GROUP BY export_set(5, str2, str1, ',', 2), str1, str2 HAVING export_set(5, str2, str1, ',', 2) IS NOT NULL ORDER BY 1,2;

-- select export_set with group by index having (result)
--Testcase 1137:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test field()
--
-- select field (stub function, explain)
--Testcase 1138:
EXPLAIN VERBOSE
SELECT field('---XYZ---', str2, str1) FROM s3;
-- select field (stub function, result)
--Testcase 1139:
SELECT field('---XYZ---', str2, str1) FROM s3;

-- select field (stub function, not pushdown constraints, explain)
--Testcase 1140:
EXPLAIN VERBOSE
SELECT value1, field('---XYZ---', str2, str1) FROM s3 WHERE to_hex(value2) = '64';
-- select field (stub function, not pushdown constraints, result)
--Testcase 1141:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 WHERE to_hex(value2) = '64';

-- select field (stub function, pushdown constraints, explain)
--Testcase 1142:
EXPLAIN VERBOSE
SELECT value1, field('---XYZ---', str2, str1) FROM s3 WHERE value2 != 200;
-- select field (stub function, pushdown constraints, result)
--Testcase 1143:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 WHERE value2 != 200;

-- select field with non pushdown func and explicit constant (explain)
--Testcase 1144:
EXPLAIN VERBOSE
SELECT field('---XYZ---', str2, str1), pi(), 4.1 FROM s3;
-- select field with non pushdown func and explicit constant (result)
--Testcase 1145:
SELECT field('---XYZ---', str2, str1), pi(), 4.1 FROM s3;

-- select field with order by (explain)
--Testcase 1146:
EXPLAIN VERBOSE
SELECT value1, field('---XYZ---', str2, str1) FROM s3 ORDER BY value1, field('---XYZ---', str2, str1);
-- select field with order by (result)
--Testcase 1147:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 ORDER BY value1, field('---XYZ---', str2, str1);

-- select field with order by index (result)
--Testcase 1148:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 ORDER BY 2,1;
-- select field with order by index (result)
--Testcase 1149:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 ORDER BY 1,2;

-- select field with group by (explain)
--Testcase 1150:
EXPLAIN VERBOSE
SELECT count(value1), field('---XYZ---', str2, str1) FROM s3 GROUP BY field('---XYZ---', str2, str1) ORDER BY 1,2;
-- select field with group by (result)
--Testcase 1151:
SELECT count(value1), field('---XYZ---', str2, str1) FROM s3 GROUP BY field('---XYZ---', str2, str1) ORDER BY 1,2;

-- select field with group by index (result)
--Testcase 1152:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select field with group by having (explain)
--Testcase 1153:
EXPLAIN VERBOSE
SELECT count(value1), field('---XYZ---', str2, str1) FROM s3 GROUP BY field('---XYZ---', str2, str1), str1, str2 HAVING field('---XYZ---', str2, str1) > 0 ORDER BY 1,2;
-- select field with group by having (result)
--Testcase 1154:
SELECT count(value1), field('---XYZ---', str2, str1) FROM s3 GROUP BY field('---XYZ---', str2, str1), str1, str2 HAVING field('---XYZ---', str2, str1) > 0 ORDER BY 1,2;

-- select field with group by index having (result)
--Testcase 1155:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test find_in_set()
--
-- select find_in_set (stub function, explain)
--Testcase 1156:
EXPLAIN VERBOSE
SELECT find_in_set('---XYZ---', str1) FROM s3;
-- select find_in_set (stub function, result)
--Testcase 1157:
SELECT find_in_set('---XYZ---', str1) FROM s3;

-- select find_in_set (stub function, not pushdown constraints, explain)
--Testcase 1158:
EXPLAIN VERBOSE
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 WHERE to_hex(value2) = '64';
-- select find_in_set (stub function, not pushdown constraints, result)
--Testcase 1159:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 WHERE to_hex(value2) = '64';

-- select find_in_set (stub function, pushdown constraints, explain)
--Testcase 1160:
EXPLAIN VERBOSE
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 WHERE value2 != 200;
-- select find_in_set (stub function, pushdown constraints, result)
--Testcase 1161:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 WHERE value2 != 200;

-- select find_in_set with non pushdown func and explicit constant (explain)
--Testcase 1162:
EXPLAIN VERBOSE
SELECT find_in_set('---XYZ---', str1), pi(), 4.1 FROM s3;
-- select find_in_set with non pushdown func and explicit constant (result)
--Testcase 1163:
SELECT find_in_set('---XYZ---', str1), pi(), 4.1 FROM s3;

-- select find_in_set with order by (explain)
--Testcase 1164:
EXPLAIN VERBOSE
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 ORDER BY value1, find_in_set('---XYZ---', str1);
-- select find_in_set with order by (result)
--Testcase 1165:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 ORDER BY value1, find_in_set('---XYZ---', str1);

-- select find_in_set with order by index (result)
--Testcase 1166:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 ORDER BY 2,1;
-- select find_in_set with order by index (result)
--Testcase 1167:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 ORDER BY 1,2;

-- select find_in_set with group by (explain)
--Testcase 1168:
EXPLAIN VERBOSE
SELECT count(value1), find_in_set('---XYZ---', str1) FROM s3 GROUP BY find_in_set('---XYZ---', str1) ORDER BY 1,2;
-- select find_in_set with group by (result)
--Testcase 1169:
SELECT count(value1), find_in_set('---XYZ---', str1) FROM s3 GROUP BY find_in_set('---XYZ---', str1) ORDER BY 1,2;

-- select find_in_set with group by index (result)
--Testcase 1170:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select find_in_set with group by having (explain)
--Testcase 1171:
EXPLAIN VERBOSE
SELECT count(value1), find_in_set('---XYZ---', str1) FROM s3 GROUP BY find_in_set('---XYZ---', str1), str1, str2 HAVING count(find_in_set('---XYZ---', str1)) IS NOT NULL ORDER BY 1,2;
-- select find_in_set with group by having (result)
--Testcase 1172:
SELECT count(value1), find_in_set('---XYZ---', str1) FROM s3 GROUP BY find_in_set('---XYZ---', str1), str1, str2 HAVING count(find_in_set('---XYZ---', str1)) IS NOT NULL ORDER BY 1,2;

-- select find_in_set with group by index having (result)
--Testcase 1173:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test mysql_format()
--
-- select mysql_format (stub function, explain)
--Testcase 1174:
EXPLAIN VERBOSE
SELECT mysql_format(value1, 4), mysql_format(value2, 4), mysql_format(value4, 4) FROM s3 ORDER BY 1,2,3;
-- select mysql_format (stub function, result)
--Testcase 1175:
SELECT mysql_format(value1, 4), mysql_format(value2, 4), mysql_format(value4, 4) FROM s3 ORDER BY 1,2,3;

-- select mysql_format (stub function, explain)
--Testcase 1176:
EXPLAIN VERBOSE
SELECT mysql_format(value1, 4, 'de_DE'), mysql_format(value2, 4, 'de_DE'), mysql_format(value4, 4, 'de_DE') FROM s3 ORDER BY 1,2,3;
-- select mysql_format (stub function, result)
--Testcase 1177:
SELECT mysql_format(value1, 4, 'de_DE'), mysql_format(value2, 4, 'de_DE'), mysql_format(value4, 4, 'de_DE') FROM s3 ORDER BY 1,2,3;

-- select mysql_format (stub function, not pushdown constraints, explain)
--Testcase 1178:
EXPLAIN VERBOSE
SELECT value1, mysql_format(value1, 4) FROM s3 WHERE to_hex(value2) = '64';
-- select mysql_format (stub function, not pushdown constraints, result)
--Testcase 1179:
SELECT value1, mysql_format(value1, 4) FROM s3 WHERE to_hex(value2) = '64';

-- select mysql_format (stub function, pushdown constraints, explain)
--Testcase 1180:
EXPLAIN VERBOSE
SELECT value1, mysql_format(value1, 4) FROM s3 WHERE value2 != 200;
-- select mysql_format (stub function, pushdown constraints, result)
--Testcase 1181:
SELECT value1, mysql_format(value1, 4) FROM s3 WHERE value2 != 200;

-- select mysql_format with non pushdown func and explicit constant (explain)
--Testcase 1182:
EXPLAIN VERBOSE
SELECT mysql_format(value1, 4), pi(), 4.1 FROM s3 ORDER BY 1;
-- select mysql_format with non pushdown func and explicit constant (result)
--Testcase 1183:
SELECT mysql_format(value1, 4), pi(), 4.1 FROM s3 ORDER BY 1;

-- select mysql_format with order by (explain)
--Testcase 1184:
EXPLAIN VERBOSE
SELECT value1, mysql_format(value1, 4) FROM s3 ORDER BY value1, mysql_format(value1, 4);
-- select mysql_format with order by (result)
--Testcase 1185:
SELECT value1, mysql_format(value1, 4) FROM s3 ORDER BY value1, mysql_format(value1, 4);

-- select mysql_format with order by index (result)
--Testcase 1186:
SELECT value1, mysql_format(value1, 4) FROM s3 ORDER BY 2,1;
-- select mysql_format with order by index (result)
--Testcase 1187:
SELECT value1, mysql_format(value1, 4) FROM s3 ORDER BY 1,2;

-- select mysql_format with group by (explain)
--Testcase 1188:
EXPLAIN VERBOSE
SELECT count(value1), mysql_format(value1, 4) FROM s3 GROUP BY mysql_format(value1, 4) ORDER BY 1,2;
-- select mysql_format with group by (result)
--Testcase 1189:
SELECT count(value1), mysql_format(value1, 4) FROM s3 GROUP BY mysql_format(value1, 4) ORDER BY 1,2;

-- select mysql_format with group by index (result)
--Testcase 1190:
SELECT value1, mysql_format(value1, 4) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select mysql_format with group by having (explain)
--Testcase 1191:
EXPLAIN VERBOSE
SELECT count(value1), mysql_format(value1, 4) FROM s3 GROUP BY mysql_format(value1, 4), value1 HAVING mysql_format(value1, 4) IS NOT NULL ORDER BY 1,2;
-- select mysql_format with group by having (result)
--Testcase 1192:
SELECT count(value1), mysql_format(value1, 4) FROM s3 GROUP BY mysql_format(value1, 4), value1 HAVING mysql_format(value1, 4) IS NOT NULL ORDER BY 1,2;

-- select mysql_format with group by index having (result)
--Testcase 1193:
SELECT value1, mysql_format(value1, 4) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test from_base64()
--
-- select from_base64 (stub function, explain)
--Testcase 1194:
EXPLAIN VERBOSE
SELECT from_base64(tag1), from_base64(str1), from_base64(str2) FROM s3;
-- select from_base64 (stub function, result)
--Testcase 1195:
SELECT from_base64(tag1), from_base64(str1), from_base64(str2) FROM s3;

-- select from_base64 (stub function, explain)
--Testcase 1196:
EXPLAIN VERBOSE
SELECT from_base64(to_base64(tag1)), from_base64(to_base64(str1)), from_base64(to_base64(str2)) FROM s3 ORDER BY 1,2,3;
-- select from_base64 (stub function, result)
--Testcase 1197:
SELECT from_base64(to_base64(tag1)), from_base64(to_base64(str1)), from_base64(to_base64(str2)) FROM s3 ORDER BY 1,2,3;

-- select from_base64 (stub function, not pushdown constraints, explain)
--Testcase 1198:
EXPLAIN VERBOSE
SELECT value1, from_base64(to_base64(str1)) FROM s3 WHERE to_hex(value2) = '64';
-- select from_base64 (stub function, not pushdown constraints, result)
--Testcase 1199:
SELECT value1, from_base64(to_base64(str1)) FROM s3 WHERE to_hex(value2) = '64';

-- select from_base64 (stub function, pushdown constraints, explain)
--Testcase 1200:
EXPLAIN VERBOSE
SELECT value1, from_base64(to_base64(str1)) FROM s3 WHERE value2 != 200;
-- select from_base64 (stub function, pushdown constraints, result)
--Testcase 1201:
SELECT value1, from_base64(to_base64(str1)) FROM s3 WHERE value2 != 200;

-- select from_base64 with non pushdown func and explicit constant (explain)
--Testcase 1202:
EXPLAIN VERBOSE
SELECT from_base64(to_base64(str1)), pi(), 4.1 FROM s3;
-- select from_base64 with non pushdown func and explicit constant (result)
--Testcase 1203:
SELECT from_base64(to_base64(str1)), pi(), 4.1 FROM s3;

-- select from_base64 with order by (explain)
--Testcase 1204:
EXPLAIN VERBOSE
SELECT value1, from_base64(to_base64(str1)) FROM s3 ORDER BY value1, from_base64(to_base64(str1));
-- select from_base64 with order by (result)
--Testcase 1205:
SELECT value1, from_base64(to_base64(str1)) FROM s3 ORDER BY value1, from_base64(to_base64(str1));

-- select from_base64 with order by index (result)
--Testcase 1206:
SELECT value1, from_base64(to_base64(str1)) FROM s3 ORDER BY 2,1;
-- select from_base64 with order by index (result)
--Testcase 1207:
SELECT value1, from_base64(to_base64(str1)) FROM s3 ORDER BY 1,2;

-- select from_base64 with group by (explain)
--Testcase 1208:
EXPLAIN VERBOSE
SELECT count(value1), from_base64(to_base64(str1)) FROM s3 GROUP BY from_base64(to_base64(str1)) ORDER BY 1,2;
-- select from_base64 with group by (result)
--Testcase 1209:
SELECT count(value1), from_base64(to_base64(str1)) FROM s3 GROUP BY from_base64(to_base64(str1)) ORDER BY 1,2;

-- select from_base64 with group by index (result)
--Testcase 1210:
SELECT value1, from_base64(to_base64(str1)) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select from_base64 with group by having (explain)
--Testcase 1211:
EXPLAIN VERBOSE
SELECT count(value1), from_base64(to_base64(str1)) FROM s3 GROUP BY from_base64(to_base64(str1)), str1 HAVING from_base64(to_base64(str1)) IS NOT NULL ORDER BY 1,2;
-- select from_base64 with group by having (result)
--Testcase 1212:
SELECT count(value1), from_base64(to_base64(str1)) FROM s3 GROUP BY from_base64(to_base64(str1)), str1 HAVING from_base64(to_base64(str1)) IS NOT NULL ORDER BY 1,2;

-- select from_base64 with group by index having (result)
--Testcase 1213:
SELECT value1, from_base64(to_base64(str1)) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test hex()
--
-- select hex (stub function, explain)
--Testcase 1214:
EXPLAIN VERBOSE
SELECT hex(tag1), hex(value2), hex(value4), hex(str1), hex(str2) FROM s3 ORDER BY 1,2,3,4,5;
-- select hex (stub function, result)
--Testcase 1215:
SELECT hex(tag1), hex(value2), hex(value4), hex(str1), hex(str2) FROM s3 ORDER BY 1,2,3,4,5;

-- select hex (stub function, not pushdown constraints, explain)
--Testcase 1216:
EXPLAIN VERBOSE
SELECT value1, hex(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select hex (stub function, not pushdown constraints, result)
--Testcase 1217:
SELECT value1, hex(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select hex (stub function, pushdown constraints, explain)
--Testcase 1218:
EXPLAIN VERBOSE
SELECT value1, hex(str1) FROM s3 WHERE value2 != 200;
-- select hex (stub function, pushdown constraints, result)
--Testcase 1219:
SELECT value1, hex(str1) FROM s3 WHERE value2 != 200;

-- select hex with non pushdown func and explicit constant (explain)
--Testcase 1220:
EXPLAIN VERBOSE
SELECT hex(str1), pi(), 4.1 FROM s3;
-- select hex with non pushdown func and explicit constant (result)
--Testcase 1221:
SELECT hex(str1), pi(), 4.1 FROM s3;

-- select hex with order by (explain)
--Testcase 1222:
EXPLAIN VERBOSE
SELECT value1, hex(str1) FROM s3 ORDER BY value1, hex(str1);
-- select hex with order by (result)
--Testcase 1223:
SELECT value1, hex(str1) FROM s3 ORDER BY value1, hex(str1);

-- select hex with order by index (result)
--Testcase 1224:
SELECT value1, hex(str1) FROM s3 ORDER BY 2,1;
-- select hex with order by index (result)
--Testcase 1225:
SELECT value1, hex(str1) FROM s3 ORDER BY 1,2;

-- select hex with group by (explain)
--Testcase 1226:
EXPLAIN VERBOSE
SELECT count(value1), hex(str1) FROM s3 GROUP BY hex(str1) ORDER BY 1,2;
-- select hex with group by (result)
--Testcase 1227:
SELECT count(value1), hex(str1) FROM s3 GROUP BY hex(str1) ORDER BY 1,2;

-- select hex with group by index (result)
--Testcase 1228:
SELECT value1, hex(str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select hex with group by having (explain)
--Testcase 1229:
EXPLAIN VERBOSE
SELECT count(value1), hex(str1) FROM s3 GROUP BY hex(str1), str1 HAVING hex(str1) IS NOT NULL ORDER BY 1,2;
-- select hex with group by having (result)
--Testcase 1230:
SELECT count(value1), hex(str1) FROM s3 GROUP BY hex(str1), str1 HAVING hex(str1) IS NOT NULL ORDER BY 1,2;

-- select hex with group by index having (result)
--Testcase 1231:
SELECT value1, hex(value4) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test insert()
--
-- select insert (stub function, explain)
--Testcase 1232:
EXPLAIN VERBOSE
SELECT insert(str1, 3, 4, str2) FROM s3;
-- select hex (stub function, result)
--Testcase 1233:
SELECT insert(str1, 3, 4, str2) FROM s3;

-- select insert (stub function, not pushdown constraints, explain)
--Testcase 1234:
EXPLAIN VERBOSE
SELECT value1, insert(str1, 3, 4, str2) FROM s3 WHERE to_hex(value2) = '64';
-- select insert (stub function, not pushdown constraints, result)
--Testcase 1235:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 WHERE to_hex(value2) = '64';

-- select insert (stub function, pushdown constraints, explain)
--Testcase 1236:
EXPLAIN VERBOSE
SELECT value1, insert(str1, 3, 4, str2) FROM s3 WHERE value2 != 200;
-- select insert (stub function, pushdown constraints, result)
--Testcase 1237:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 WHERE value2 != 200;

-- select insert with non pushdown func and explicit constant (explain)
--Testcase 1238:
EXPLAIN VERBOSE
SELECT insert(str1, 3, 4, str2), pi(), 4.1 FROM s3;
-- select insert with non pushdown func and explicit constant (result)
--Testcase 1239:
SELECT insert(str1, 3, 4, str2), pi(), 4.1 FROM s3;

-- select insert with order by (explain)
--Testcase 1240:
EXPLAIN VERBOSE
SELECT value1, insert(str1, 3, 4, str2) FROM s3 ORDER BY value1, insert(str1, 3, 4, str2);
-- select insert with order by (result)
--Testcase 1241:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 ORDER BY value1, insert(str1, 3, 4, str2);

-- select insert with order by index (result)
--Testcase 1242:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 ORDER BY 2,1;
-- select insert with order by index (result)
--Testcase 1243:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 ORDER BY 1,2;

-- select insert with group by (explain)
--Testcase 1244:
EXPLAIN VERBOSE
SELECT count(value1), insert(str1, 3, 4, str2) FROM s3 GROUP BY insert(str1, 3, 4, str2) ORDER BY 1,2;
-- select insert with group by (result)
--Testcase 1245:
SELECT count(value1), insert(str1, 3, 4, str2) FROM s3 GROUP BY insert(str1, 3, 4, str2) ORDER BY 1,2;

-- select insert with group by index (result)
--Testcase 1246:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select insert with group by having (explain)
--Testcase 1247:
EXPLAIN VERBOSE
SELECT count(value1), insert(str1, 3, 4, str2) FROM s3 GROUP BY insert(str1, 3, 4, str2), str1, str2 HAVING insert(str1, 3, 4, str2) IS NOT NULL ORDER BY 1,2;
-- select insert with group by having (result)
--Testcase 1248:
SELECT count(value1), insert(str1, 3, 4, str2) FROM s3 GROUP BY insert(str1, 3, 4, str2), str1, str2 HAVING insert(str1, 3, 4, str2) IS NOT NULL ORDER BY 1,2;

-- select insert with group by index having (result)
--Testcase 1249:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test instr()
--
-- select instr (stub function, explain)
--Testcase 1250:
EXPLAIN VERBOSE
SELECT instr(str1, str2) FROM s3;
-- select instr (stub function, result)
--Testcase 1251:
SELECT instr(str1, str2) FROM s3;

-- select instr (stub function, not pushdown constraints, explain)
--Testcase 1252:
EXPLAIN VERBOSE
SELECT value1, instr(str1, str2) FROM s3 WHERE to_hex(value2) = '64';
-- select instr (stub function, not pushdown constraints, result)
--Testcase 1253:
SELECT value1, instr(str1, str2) FROM s3 WHERE to_hex(value2) = '64';

-- select instr (stub function, pushdown constraints, explain)
--Testcase 1254:
EXPLAIN VERBOSE
SELECT value1, instr(str1, str2) FROM s3 WHERE value2 != 200;
-- select instr (stub function, pushdown constraints, result)
--Testcase 1255:
SELECT value1, instr(str1, str2) FROM s3 WHERE value2 != 200;

-- select instr with non pushdown func and explicit constant (explain)
--Testcase 1256:
EXPLAIN VERBOSE
SELECT instr(str1, str2), pi(), 4.1 FROM s3;
-- select instr with non pushdown func and explicit constant (result)
--Testcase 1257:
SELECT instr(str1, str2), pi(), 4.1 FROM s3;

-- select instr with order by (explain)
--Testcase 1258:
EXPLAIN VERBOSE
SELECT value1, instr(str1, str2) FROM s3 ORDER BY value1, instr(str1, str2);
-- select instr with order by (result)
--Testcase 1259:
SELECT value1, instr(str1, str2) FROM s3 ORDER BY value1, instr(str1, str2);

-- select instr with order by index (result)
--Testcase 1260:
SELECT value1, instr(str1, str2) FROM s3 ORDER BY 2,1;
-- select instr with order by index (result)
--Testcase 1261:
SELECT value1, instr(str1, str2) FROM s3 ORDER BY 1,2;

-- select instr with group by (explain)
--Testcase 1262:
EXPLAIN VERBOSE
SELECT count(value1), instr(str1, str2) FROM s3 GROUP BY instr(str1, str2) ORDER BY 1,2;
-- select instr with group by (result)
--Testcase 1263:
SELECT count(value1), instr(str1, str2) FROM s3 GROUP BY instr(str1, str2) ORDER BY 1,2;

-- select instr with group by index (result)
--Testcase 1264:
SELECT value1, instr(str1, str2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select instr with group by having (explain)
--Testcase 1265:
EXPLAIN VERBOSE
SELECT count(value1), instr(str1, str2) FROM s3 GROUP BY instr(str1, str2), str1, str2 HAVING instr(str1, str2) IS NOT NULL ORDER BY 1,2;
-- select instr with group by having (result)
--Testcase 1266:
SELECT count(value1), instr(str1, str2) FROM s3 GROUP BY instr(str1, str2), str1, str2 HAVING instr(str1, str2) IS NOT NULL ORDER BY 1,2;

-- select instr with group by index having (result)
--Testcase 1267:
SELECT value1, instr(str1, str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test lcase()
--
-- select lcase (stub function, explain)
--Testcase 1268:
EXPLAIN VERBOSE
SELECT lcase(tag1), lcase(str1), lcase(str2) FROM s3 ORDER BY 1,2,3;
-- select lcase (stub function, result)
--Testcase 1269:
SELECT lcase(tag1), lcase(str1), lcase(str2) FROM s3 ORDER BY 1,2,3;

-- select lcase (stub function, not pushdown constraints, explain)
--Testcase 1270:
EXPLAIN VERBOSE
SELECT value1, lcase(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select lcase (stub function, not pushdown constraints, result)
--Testcase 1271:
SELECT value1, lcase(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select lcase (stub function, pushdown constraints, explain)
--Testcase 1272:
EXPLAIN VERBOSE
SELECT value1, lcase(str1) FROM s3 WHERE value2 != 200;
-- select lcase (stub function, pushdown constraints, result)
--Testcase 1273:
SELECT value1, lcase(str1) FROM s3 WHERE value2 != 200;

-- select lcase with non pushdown func and explicit constant (explain)
--Testcase 1274:
EXPLAIN VERBOSE
SELECT lcase(str1), pi(), 4.1 FROM s3;
-- select lcase with non pushdown func and explicit constant (result)
--Testcase 1275:
SELECT lcase(str1), pi(), 4.1 FROM s3;

-- select lcase with order by (explain)
--Testcase 1276:
EXPLAIN VERBOSE
SELECT value1, lcase(str1) FROM s3 ORDER BY value1, lcase(str1);
-- select lcase with order by (result)
--Testcase 1277:
SELECT value1, lcase(str1) FROM s3 ORDER BY value1, lcase(str1);

-- select lcase with order by index (result)
--Testcase 1278:
SELECT value1, lcase(str1) FROM s3 ORDER BY 2,1;
-- select lcase with order by index (result)
--Testcase 1279:
SELECT value1, lcase(str1) FROM s3 ORDER BY 1,2;

-- select lcase with group by (explain)
--Testcase 1280:
EXPLAIN VERBOSE
SELECT count(value1), lcase(str1) FROM s3 GROUP BY lcase(str1) ORDER BY 1,2;
-- select lcase with group by (result)
--Testcase 1281:
SELECT count(value1), lcase(str1) FROM s3 GROUP BY lcase(str1) ORDER BY 1,2;

-- select lcase with group by index (result)
--Testcase 1282:
SELECT value1, lcase(str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select lcase with group by having (explain)
--Testcase 1283:
EXPLAIN VERBOSE
SELECT count(value1), lcase(str1) FROM s3 GROUP BY lcase(str1), str1 HAVING lcase(str1) IS NOT NULL ORDER BY 1,2;
-- select lcase with group by having (result)
--Testcase 1284:
SELECT count(value1), lcase(str1) FROM s3 GROUP BY lcase(str1), str1 HAVING lcase(str1) IS NOT NULL ORDER BY 1,2;

-- select lcase with group by index having (result)
--Testcase 1285:
SELECT value1, lcase(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test left()
--
-- select left (stub function, explain)
--Testcase 1286:
EXPLAIN VERBOSE
SELECT left(str1, 5), left(str2, 5) FROM s3;
-- select left (stub function, result)
--Testcase 1287:
SELECT left(str1, 5), left(str2, 5) FROM s3;

-- select left (stub function, not pushdown constraints, explain)
--Testcase 1288:
EXPLAIN VERBOSE
SELECT value1, left(str1, 5) FROM s3 WHERE to_hex(value2) = '64';
-- select left (stub function, not pushdown constraints, result)
--Testcase 1289:
SELECT value1, left(str1, 5) FROM s3 WHERE to_hex(value2) = '64';

-- select left (stub function, pushdown constraints, explain)
--Testcase 1290:
EXPLAIN VERBOSE
SELECT value1, left(str1, 5) FROM s3 WHERE value2 != 200;
-- select left (stub function, pushdown constraints, result)
--Testcase 1291:
SELECT value1, left(str1, 5) FROM s3 WHERE value2 != 200;

-- select left with non pushdown func and explicit constant (explain)
--Testcase 1292:
EXPLAIN VERBOSE
SELECT left(str1, 5), pi(), 4.1 FROM s3;
-- select left with non pushdown func and explicit constant (result)
--Testcase 1293:
SELECT left(str1, 5), pi(), 4.1 FROM s3;

-- select left with order by (explain)
--Testcase 1294:
EXPLAIN VERBOSE
SELECT value1, left(str1, 5) FROM s3 ORDER BY value1, left(str1, 5);
-- select left with order by (result)
--Testcase 1295:
SELECT value1, left(str1, 5) FROM s3 ORDER BY value1, left(str1, 5);

-- select left with order by index (result)
--Testcase 1296:
SELECT value1, left(str1, 5) FROM s3 ORDER BY 2,1;
-- select left with order by index (result)
--Testcase 1297:
SELECT value1, left(str1, 5) FROM s3 ORDER BY 1,2;

-- select left with group by (explain)
--Testcase 1298:
EXPLAIN VERBOSE
SELECT count(value1), left(str1, 5) FROM s3 GROUP BY left(str1, 5) ORDER BY 1,2;
-- select left with group by (result)
--Testcase 1299:
SELECT count(value1), left(str1, 5) FROM s3 GROUP BY left(str1, 5) ORDER BY 1,2;

-- select left with group by index (result)
--Testcase 1300:
SELECT value1, left(str1, 5) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select left with group by having (explain)
--Testcase 1301:
EXPLAIN VERBOSE
SELECT count(value1), left(str1, 5) FROM s3 GROUP BY left(str1, 5), str1 HAVING left(str1, 5) IS NOT NULL ORDER BY 1,2;
-- select left with group by having (result)
--Testcase 1302:
SELECT count(value1), left(str1, 5) FROM s3 GROUP BY left(str1, 5), str1 HAVING left(str1, 5) IS NOT NULL ORDER BY 1,2;

-- select left with group by index having (result)
--Testcase 1303:
SELECT value1, left(str1, 5) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test length()
--
-- select length (stub function, explain)
--Testcase 1304:
EXPLAIN VERBOSE
SELECT length(str1), length(str2) FROM s3;
-- select length (stub function, result)
--Testcase 1305:
SELECT length(str1), length(str2) FROM s3;

-- select length (stub function, not pushdown constraints, explain)
--Testcase 1306:
EXPLAIN VERBOSE
SELECT value1, length(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select length (stub function, not pushdown constraints, result)
--Testcase 1307:
SELECT value1, length(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select length (stub function, pushdown constraints, explain)
--Testcase 1308:
EXPLAIN VERBOSE
SELECT value1, length(str1) FROM s3 WHERE value2 != 200;
-- select length (stub function, pushdown constraints, result)
--Testcase 1309:
SELECT value1, length(str1) FROM s3 WHERE value2 != 200;

-- select length with non pushdown func and explicit constant (explain)
--Testcase 1310:
EXPLAIN VERBOSE
SELECT length(str1), pi(), 4.1 FROM s3;
-- select length with non pushdown func and explicit constant (result)
--Testcase 1311:
SELECT length(str1), pi(), 4.1 FROM s3;

-- select length with order by (explain)
--Testcase 1312:
EXPLAIN VERBOSE
SELECT value1, length(str1) FROM s3 ORDER BY value1, length(str1);
-- select length with order by (result)
--Testcase 1313:
SELECT value1, length(str1) FROM s3 ORDER BY value1, length(str1);

-- select length with order by index (result)
--Testcase 1314:
SELECT value1, length(str1) FROM s3 ORDER BY 2,1;
-- select length with order by index (result)
--Testcase 1315:
SELECT value1, length(str1) FROM s3 ORDER BY 1,2;

-- select length with group by (explain)
--Testcase 1316:
EXPLAIN VERBOSE
SELECT count(value1), length(str1) FROM s3 GROUP BY length(str1) ORDER BY 1,2;
-- select length with group by (result)
--Testcase 1317:
SELECT count(value1), length(str1) FROM s3 GROUP BY length(str1) ORDER BY 1,2;

-- select length with group by index (result)
--Testcase 1318:
SELECT value1, length(str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select length with group by having (explain)
--Testcase 1319:
EXPLAIN VERBOSE
SELECT count(value1), length(str1) FROM s3 GROUP BY length(str1), str1 HAVING length(str1) IS NOT NULL ORDER BY 1,2;
-- select length with group by having (result)
--Testcase 1320:
SELECT count(value1), length(str1) FROM s3 GROUP BY length(str1), str1 HAVING length(str1) IS NOT NULL ORDER BY 1,2;

-- select length with group by index having (result)
--Testcase 1321:
SELECT value1, length(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test locate()
--
-- select locate (stub function, explain)
--Testcase 1322:
EXPLAIN VERBOSE
SELECT locate(str1, str2), locate(str2, str1, 3) FROM s3;
-- select locate (stub function, result)
--Testcase 1323:
SELECT locate(str1, str2), locate(str2, str1, 3) FROM s3;

-- select locate (stub function, not pushdown constraints, explain)
--Testcase 1324:
EXPLAIN VERBOSE
SELECT value1, locate(str1, str2) FROM s3 WHERE to_hex(value2) = '64';
-- select locate (stub function, not pushdown constraints, result)
--Testcase 1325:
SELECT value1, locate(str1, str2) FROM s3 WHERE to_hex(value2) = '64';

-- select locate (stub function, pushdown constraints, explain)
--Testcase 1326:
EXPLAIN VERBOSE
SELECT value1, locate(str1, str2) FROM s3 WHERE value2 != 200;
-- select locate (stub function, pushdown constraints, result)
--Testcase 1327:
SELECT value1, locate(str1, str2) FROM s3 WHERE value2 != 200;

-- select locate with non pushdown func and explicit constant (explain)
--Testcase 1328:
EXPLAIN VERBOSE
SELECT locate(str1, str2), pi(), 4.1 FROM s3;
-- select locate with non pushdown func and explicit constant (result)
--Testcase 1329:
SELECT locate(str1, str2), pi(), 4.1 FROM s3;

-- select locate with order by (explain)
--Testcase 1330:
EXPLAIN VERBOSE
SELECT value1, locate(str1, str2) FROM s3 ORDER BY value1, locate(str1, str2);
-- select locate with order by (result)
--Testcase 1331:
SELECT value1, locate(str1, str2) FROM s3 ORDER BY value1, locate(str1, str2);

-- select locate with order by index (result)
--Testcase 1332:
SELECT value1, locate(str1, str2) FROM s3 ORDER BY 2,1;
-- select locate with order by index (result)
--Testcase 1333:
SELECT value1, locate(str1, str2) FROM s3 ORDER BY 1,2;

-- select locate with group by (explain)
--Testcase 1334:
EXPLAIN VERBOSE
SELECT count(value1), locate(str1, str2) FROM s3 GROUP BY locate(str1, str2) ORDER BY 1,2;
-- select locate with group by (result)
--Testcase 1335:
SELECT count(value1), locate(str1, str2) FROM s3 GROUP BY locate(str1, str2) ORDER BY 1,2;

-- select locate with group by index (result)
--Testcase 1336:
SELECT value1, locate(str1, str2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select locate with group by having (explain)
--Testcase 1337:
EXPLAIN VERBOSE
SELECT count(value1), locate(str1, str2) FROM s3 GROUP BY locate(str1, str2), str1, str2 HAVING locate(str1, str2) IS NOT NULL ORDER BY 1,2;
-- select locate with group by having (result)
--Testcase 1338:
SELECT count(value1), locate(str1, str2) FROM s3 GROUP BY locate(str1, str2), str1, str2 HAVING locate(str1, str2) IS NOT NULL ORDER BY 1,2;

-- select locate with group by index having (result)
--Testcase 1339:
SELECT value1, locate(str1, str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test lower()
--
-- select lower (stub function, explain)
--Testcase 1340:
EXPLAIN VERBOSE
SELECT lower(str1), lower(str2) FROM s3;
-- select lower (stub function, result)
--Testcase 1341:
SELECT lower(str1), lower(str2) FROM s3;

-- select lower (stub function, not pushdown constraints, explain)
--Testcase 1342:
EXPLAIN VERBOSE
SELECT value1, lower(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select lower (stub function, not pushdown constraints, result)
--Testcase 1343:
SELECT value1, lower(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select lower (stub function, pushdown constraints, explain)
--Testcase 1344:
EXPLAIN VERBOSE
SELECT value1, lower(str1) FROM s3 WHERE value2 != 200;
-- select lower (stub function, pushdown constraints, result)
--Testcase 1345:
SELECT value1, lower(str1) FROM s3 WHERE value2 != 200;

-- select lower with non pushdown func and explicit constant (explain)
--Testcase 1346:
EXPLAIN VERBOSE
SELECT lower(str1), pi(), 4.1 FROM s3;
-- select lower with non pushdown func and explicit constant (result)
--Testcase 1347:
SELECT lower(str1), pi(), 4.1 FROM s3;

-- select lower with order by (explain)
--Testcase 1348:
EXPLAIN VERBOSE
SELECT value1, lower(str1) FROM s3 ORDER BY value1, lower(str1);
-- select lower with order by (result)
--Testcase 1349:
SELECT value1, lower(str1) FROM s3 ORDER BY value1, lower(str1);

-- select lower with order by index (result)
--Testcase 1350:
SELECT value1, lower(str1) FROM s3 ORDER BY 2,1;
-- select lower with order by index (result)
--Testcase 1351:
SELECT value1, lower(str1) FROM s3 ORDER BY 1,2;

-- select lower with group by (explain)
--Testcase 1352:
EXPLAIN VERBOSE
SELECT count(value1), lower(str1) FROM s3 GROUP BY lower(str1) ORDER BY 1,2;
-- select lower with group by (result)
--Testcase 1353:
SELECT count(value1), lower(str1) FROM s3 GROUP BY lower(str1) ORDER BY 1,2;

-- select lower with group by index (result)
--Testcase 1354:
SELECT value1, lower(str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select lower with group by having (explain)
--Testcase 1355:
EXPLAIN VERBOSE
SELECT count(value1), lower(str1) FROM s3 GROUP BY lower(str1), str1 HAVING lower(str1) IS NOT NULL ORDER BY 1,2;
-- select lower with group by having (result)
--Testcase 1356:
SELECT count(value1), lower(str1) FROM s3 GROUP BY lower(str1), str1 HAVING lower(str1) IS NOT NULL ORDER BY 1,2;

-- select lower with group by index having (result)
--Testcase 1357:
SELECT value1, lower(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test lpad()
--
-- select lpad (stub function, explain)
--Testcase 1358:
EXPLAIN VERBOSE
SELECT lpad(str1, 4, 'ABCD'), lpad(str2, 4, 'ABCD') FROM s3;
-- select lpad (stub function, result)
--Testcase 1359:
SELECT lpad(str1, 4, 'ABCD'), lpad(str2, 4, 'ABCD') FROM s3;

-- select lpad (stub function, not pushdown constraints, explain)
--Testcase 1360:
EXPLAIN VERBOSE
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 WHERE to_hex(value2) = '64';
-- select lpad (stub function, not pushdown constraints, result)
--Testcase 1361:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 WHERE to_hex(value2) = '64';

-- select lpad (stub function, pushdown constraints, explain)
--Testcase 1362:
EXPLAIN VERBOSE
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 WHERE value2 != 200;
-- select lpad (stub function, pushdown constraints, result)
--Testcase 1363:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 WHERE value2 != 200;

-- select lpad with non pushdown func and explicit constant (explain)
--Testcase 1364:
EXPLAIN VERBOSE
SELECT lpad(str1, 4, 'ABCD'), pi(), 4.1 FROM s3;
-- select lpad with non pushdown func and explicit constant (result)
--Testcase 1365:
SELECT lpad(str1, 4, 'ABCD'), pi(), 4.1 FROM s3;

-- select lpad with order by (explain)
--Testcase 1366:
EXPLAIN VERBOSE
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 ORDER BY value1, lpad(str1, 4, 'ABCD');
-- select lpad with order by (result)
--Testcase 1367:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 ORDER BY value1, lpad(str1, 4, 'ABCD');

-- select lpad with order by index (result)
--Testcase 1368:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 ORDER BY 2,1;
-- select lpad with order by index (result)
--Testcase 1369:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 ORDER BY 1,2;

-- select lpad with group by (explain)
--Testcase 1370:
EXPLAIN VERBOSE
SELECT count(value1), lpad(str1, 4, 'ABCD') FROM s3 GROUP BY lpad(str1, 4, 'ABCD') ORDER BY 1,2;
-- select lpad with group by (result)
--Testcase 1371:
SELECT count(value1), lpad(str1, 4, 'ABCD') FROM s3 GROUP BY lpad(str1, 4, 'ABCD') ORDER BY 1,2;

-- select lpad with group by index (result)
--Testcase 1372:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select lpad with group by having (explain)
--Testcase 1373:
EXPLAIN VERBOSE
SELECT count(value1), lpad(str1, 4, 'ABCD') FROM s3 GROUP BY lpad(str1, 4, 'ABCD'), str1 HAVING lpad(str1, 4, 'ABCD') IS NOT NULL ORDER BY 1,2;
-- select lpad with group by having (result)
--Testcase 1374:
SELECT count(value1), lpad(str1, 4, 'ABCD') FROM s3 GROUP BY lpad(str1, 4, 'ABCD'), str1 HAVING lpad(str1, 4, 'ABCD') IS NOT NULL ORDER BY 1,2;

-- select lpad with group by index having (result)
--Testcase 1375:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test ltrim()
--
-- select ltrim (stub function, explain)
--Testcase 1376:
EXPLAIN VERBOSE
SELECT ltrim(str1), ltrim(str2, ' ') FROM s3;
-- select ltrim (stub function, result)
--Testcase 1377:
SELECT ltrim(str1), ltrim(str2, ' ') FROM s3;

-- select ltrim (stub function, not pushdown constraints, explain)
--Testcase 1378:
EXPLAIN VERBOSE
SELECT value1, ltrim(str1, '-') FROM s3 WHERE to_hex(value2) = '64';
-- select ltrim (stub function, not pushdown constraints, result)
--Testcase 1379:
SELECT value1, ltrim(str1, '-') FROM s3 WHERE to_hex(value2) = '64';

-- select ltrim (stub function, pushdown constraints, explain)
--Testcase 1380:
EXPLAIN VERBOSE
SELECT value1, ltrim(str1, '-') FROM s3 WHERE value2 != 200;
-- select ltrim (stub function, pushdown constraints, result)
--Testcase 1381:
SELECT value1, ltrim(str1, '-') FROM s3 WHERE value2 != 200;

-- select ltrim with non pushdown func and explicit constant (explain)
--Testcase 1382:
EXPLAIN VERBOSE
SELECT ltrim(str1, '-'), pi(), 4.1 FROM s3;
-- select ltrim with non pushdown func and explicit constant (result)
--Testcase 1383:
SELECT ltrim(str1, '-'), pi(), 4.1 FROM s3;

-- select ltrim with order by (explain)
--Testcase 1384:
EXPLAIN VERBOSE
SELECT value1, ltrim(str1, '-') FROM s3 ORDER BY value1, ltrim(str1, '-');
-- select ltrim with order by (result)
--Testcase 1385:
SELECT value1, ltrim(str1, '-') FROM s3 ORDER BY value1, ltrim(str1, '-');

-- select ltrim with order by index (result)
--Testcase 1386:
SELECT value1, ltrim(str1, '-') FROM s3 ORDER BY 2,1;
-- select ltrim with order by index (result)
--Testcase 1387:
SELECT value1, ltrim(str1, '-') FROM s3 ORDER BY 1,2;

-- select ltrim with group by (explain)
--Testcase 1388:
EXPLAIN VERBOSE
SELECT count(value1), ltrim(str1, '-') FROM s3 GROUP BY ltrim(str1, '-') ORDER BY 1,2;
-- select ltrim with group by (result)
--Testcase 1389:
SELECT count(value1), ltrim(str1, '-') FROM s3 GROUP BY ltrim(str1, '-') ORDER BY 1,2;

-- select ltrim with group by index (result)
--Testcase 1390:
SELECT value1, ltrim(str1, '-') FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select ltrim with group by having (explain)
--Testcase 1391:
EXPLAIN VERBOSE
SELECT count(value1), ltrim(str1, '-') FROM s3 GROUP BY ltrim(str1, '-'), str2 HAVING ltrim(str1, '-') IS NOT NULL ORDER BY 1,2;
-- select ltrim with group by having (result)
--Testcase 1392:
SELECT count(value1), ltrim(str1, '-') FROM s3 GROUP BY ltrim(str1, '-'), str2 HAVING ltrim(str1, '-') IS NOT NULL ORDER BY 1,2;

-- select ltrim with group by index having (result)
--Testcase 1393:
SELECT value1, ltrim(str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test make_set()
--
-- select make_set (stub function, explain)
--Testcase 1394:
EXPLAIN VERBOSE
SELECT make_set(1, str1, str2), make_set(1 | 4, str1, str2) FROM s3;
-- select make_set (stub function, result)
--Testcase 1395:
SELECT make_set(1, str1, str2), make_set(1 | 4, str1, str2) FROM s3;

-- select make_set (stub function, not pushdown constraints, explain)
--Testcase 1396:
EXPLAIN VERBOSE
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 WHERE to_hex(value2) = '64';
-- select make_set (stub function, not pushdown constraints, result)
--Testcase 1397:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 WHERE to_hex(value2) = '64';

-- select make_set (stub function, pushdown constraints, explain)
--Testcase 1398:
EXPLAIN VERBOSE
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 WHERE value2 != 200;
-- select make_set (stub function, pushdown constraints, result)
--Testcase 1399:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 WHERE value2 != 200;

-- select make_set with non pushdown func and explicit constant (explain)
--Testcase 1400:
EXPLAIN VERBOSE
SELECT make_set(1 | 4, str1, str2), pi(), 4.1 FROM s3;
-- select make_set with non pushdown func and explicit constant (result)
--Testcase 1401:
SELECT make_set(1 | 4, str1, str2), pi(), 4.1 FROM s3;

-- select make_set with order by (explain)
--Testcase 1402:
EXPLAIN VERBOSE
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 ORDER BY value1, make_set(1 | 4, str1, str2);
-- select make_set with order by (result)
--Testcase 1403:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 ORDER BY value1, make_set(1 | 4, str1, str2);

-- select make_set with order by index (result)
--Testcase 1404:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 ORDER BY 2,1;
-- select make_set with order by index (result)
--Testcase 1405:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 ORDER BY 1,2;

-- select make_set with group by (explain)
--Testcase 1406:
EXPLAIN VERBOSE
SELECT count(value1), make_set(1 | 4, str1, str2) FROM s3 GROUP BY make_set(1 | 4, str1, str2) ORDER BY 1,2;
-- select make_set with group by (result)
--Testcase 1407:
SELECT count(value1), make_set(1 | 4, str1, str2) FROM s3 GROUP BY make_set(1 | 4, str1, str2) ORDER BY 1,2;

-- select make_set with group by index (result)
--Testcase 1408:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select make_set with group by having (explain)
--Testcase 1409:
EXPLAIN VERBOSE
SELECT count(value1), make_set(1 | 4, str1, str2) FROM s3 GROUP BY make_set(1 | 4, str1, str2), str1, str2 HAVING make_set(1 | 4, str1, str2) IS NOT NULL ORDER BY 1,2;
-- select make_set with group by having (result)
--Testcase 1410:
SELECT count(value1), make_set(1 | 4, str1, str2) FROM s3 GROUP BY make_set(1 | 4, str1, str2), str1, str2 HAVING make_set(1 | 4, str1, str2) IS NOT NULL ORDER BY 1,2;

-- select make_set with group by index having (result)
--Testcase 1411:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test mid()
--
-- select mid (stub function, explain)
--Testcase 1412:
EXPLAIN VERBOSE
SELECT mid(str1, 2, 4), mid(str2, 2, 4) FROM s3;
-- select mid (stub function, result)
--Testcase 1413:
SELECT mid(str1, 2, 4), mid(str2, 2, 4) FROM s3;

-- select mid (stub function, not pushdown constraints, explain)
--Testcase 1414:
EXPLAIN VERBOSE
SELECT value1, mid(str2, 2, 4) FROM s3 WHERE to_hex(value2) = '64';
-- select mid (stub function, not pushdown constraints, result)
--Testcase 1415:
SELECT value1, mid(str2, 2, 4) FROM s3 WHERE to_hex(value2) = '64';

-- select mid (stub function, pushdown constraints, explain)
--Testcase 1416:
EXPLAIN VERBOSE
SELECT value1, mid(str2, 2, 4) FROM s3 WHERE value2 != 200;
-- select mid (stub function, pushdown constraints, result)
--Testcase 1417:
SELECT value1, mid(str2, 2, 4) FROM s3 WHERE value2 != 200;

-- select mid with non pushdown func and explicit constant (explain)
--Testcase 1418:
EXPLAIN VERBOSE
SELECT mid(str2, 2, 4), pi(), 4.1 FROM s3;
-- select mid with non pushdown func and explicit constant (result)
--Testcase 1419:
SELECT mid(str2, 2, 4), pi(), 4.1 FROM s3;

-- select mid with order by (explain)
--Testcase 1420:
EXPLAIN VERBOSE
SELECT value1, mid(str2, 2, 4) FROM s3 ORDER BY value1, mid(str2, 2, 4);
-- select mid with order by (result)
--Testcase 1421:
SELECT value1, mid(str2, 2, 4) FROM s3 ORDER BY value1, mid(str2, 2, 4);

-- select mid with order by index (result)
--Testcase 1422:
SELECT value1, mid(str2, 2, 4) FROM s3 ORDER BY 2,1;
-- select mid with order by index (result)
--Testcase 1423:
SELECT value1, mid(str2, 2, 4) FROM s3 ORDER BY 1,2;

-- select mid with group by (explain)
--Testcase 1424:
EXPLAIN VERBOSE
SELECT count(value1), mid(str2, 2, 4) FROM s3 GROUP BY mid(str2, 2, 4) ORDER BY 1,2;
-- select mid with group by (result)
--Testcase 1425:
SELECT count(value1), mid(str2, 2, 4) FROM s3 GROUP BY mid(str2, 2, 4) ORDER BY 1,2;

-- select mid with group by index (result)
--Testcase 1426:
SELECT value1, mid(str2, 2, 4) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select mid with group by having (explain)
--Testcase 1427:
EXPLAIN VERBOSE
SELECT count(value1), mid(str2, 2, 4) FROM s3 GROUP BY mid(str2, 2, 4), str2 HAVING mid(str2, 2, 4) IS NOT NULL ORDER BY 1,2;
-- select mid with group by having (result)
--Testcase 1428:
SELECT count(value1), mid(str2, 2, 4) FROM s3 GROUP BY mid(str2, 2, 4), str2 HAVING mid(str2, 2, 4) IS NOT NULL ORDER BY 1,2;

-- select mid with group by index having (result)
--Testcase 1429:
SELECT value1, mid(str2, 2, 4) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test oct()
--
-- select oct (stub function, explain)
--Testcase 1430:
EXPLAIN VERBOSE
SELECT oct(value2), oct(value4) FROM s3 ORDER BY 1,2;
-- select oct (stub function, result)
--Testcase 1431:
SELECT oct(value2), oct(value4) FROM s3 ORDER BY 1,2;

-- select oct (stub function, not pushdown constraints, explain)
--Testcase 1432:
EXPLAIN VERBOSE
SELECT value1, oct(value4) FROM s3 WHERE to_hex(value2) = '64';
-- select oct (stub function, not pushdown constraints, result)
--Testcase 1433:
SELECT value1, oct(value4) FROM s3 WHERE to_hex(value2) = '64';

-- select oct (stub function, pushdown constraints, explain)
--Testcase 1434:
EXPLAIN VERBOSE
SELECT value1, oct(value4) FROM s3 WHERE value2 != 200;
-- select oct (stub function, pushdown constraints, result)
--Testcase 1435:
SELECT value1, oct(value4) FROM s3 WHERE value2 != 200;

-- select oct with non pushdown func and explicit constant (explain)
--Testcase 1436:
EXPLAIN VERBOSE
SELECT oct(value4), pi(), 4.1 FROM s3 ORDER BY 1;
-- select oct with non pushdown func and explicit constant (result)
--Testcase 1437:
SELECT oct(value4), pi(), 4.1 FROM s3 ORDER BY 1;

-- select oct with order by (explain)
--Testcase 1438:
EXPLAIN VERBOSE
SELECT value1, oct(value4) FROM s3 ORDER BY oct(value4);
-- select oct with order by (result)
--Testcase 1439:
SELECT value1, oct(value4) FROM s3 ORDER BY oct(value4);

-- select oct with order by index (result)
--Testcase 1440:
SELECT value1, oct(value4) FROM s3 ORDER BY 2,1;
-- select oct with order by index (result)
--Testcase 1441:
SELECT value1, oct(value4) FROM s3 ORDER BY 1,2;

-- select oct with group by (explain)
--Testcase 1442:
EXPLAIN VERBOSE
SELECT count(value1), oct(value4) FROM s3 GROUP BY oct(value4) ORDER BY 1,2;
-- select oct with group by (result)
--Testcase 1443:
SELECT count(value1), oct(value4) FROM s3 GROUP BY oct(value4) ORDER BY 1,2;

-- select oct with group by index (result)
--Testcase 1444:
SELECT value1, oct(value4) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select oct with group by having (explain)
--Testcase 1445:
EXPLAIN VERBOSE
SELECT count(value1), oct(value4) FROM s3 GROUP BY oct(value4), value4 HAVING oct(value4) IS NOT NULL ORDER BY 1,2;
-- select oct with group by having (result)
--Testcase 1446:
SELECT count(value1), oct(value4) FROM s3 GROUP BY oct(value4), value4 HAVING oct(value4) IS NOT NULL ORDER BY 1,2;

-- select oct with group by index having (result)
--Testcase 1447:
SELECT value1, oct(value4) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test octet_length()
--
-- select octet_length (stub function, explain)
--Testcase 1448:
EXPLAIN VERBOSE
SELECT octet_length(str1), octet_length(str2) FROM s3;
-- select octet_length (stub function, result)
--Testcase 1449:
SELECT octet_length(str1), octet_length(str2) FROM s3;

-- select octet_length (stub function, not pushdown constraints, explain)
--Testcase 1450:
EXPLAIN VERBOSE
SELECT value1, octet_length(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select octet_length (stub function, not pushdown constraints, result)
--Testcase 1451:
SELECT value1, octet_length(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select octet_length (stub function, pushdown constraints, explain)
--Testcase 1452:
EXPLAIN VERBOSE
SELECT value1, octet_length(str1) FROM s3 WHERE value2 != 200;
-- select octet_length (stub function, pushdown constraints, result)
--Testcase 1453:
SELECT value1, octet_length(str1) FROM s3 WHERE value2 != 200;

-- select octet_length with non pushdown func and explicit constant (explain)
--Testcase 1454:
EXPLAIN VERBOSE
SELECT octet_length(str1), pi(), 4.1 FROM s3;
-- select octet_length with non pushdown func and explicit constant (result)
--Testcase 1455:
SELECT octet_length(str1), pi(), 4.1 FROM s3;

-- select octet_length with order by (explain)
--Testcase 1456:
EXPLAIN VERBOSE
SELECT value1, octet_length(str1) FROM s3 ORDER BY value1, octet_length(str1);
-- select octet_length with order by (result)
--Testcase 1457:
SELECT value1, octet_length(str1) FROM s3 ORDER BY value1, octet_length(str1);

-- select octet_length with order by index (result)
--Testcase 1458:
SELECT value1, octet_length(str1) FROM s3 ORDER BY 2,1;
-- select octet_length with order by index (result)
--Testcase 1459:
SELECT value1, octet_length(str1) FROM s3 ORDER BY 1,2;

-- select octet_length with group by (explain)
--Testcase 1460:
EXPLAIN VERBOSE
SELECT count(value1), octet_length(str1) FROM s3 GROUP BY octet_length(str1) ORDER BY 1,2;
-- select octet_length with group by (result)
--Testcase 1461:
SELECT count(value1), octet_length(str1) FROM s3 GROUP BY octet_length(str1) ORDER BY 1,2;

-- select octet_length with group by index (result)
--Testcase 1462:
SELECT value1, octet_length(str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select octet_length with group by having (explain)
--Testcase 1463:
EXPLAIN VERBOSE
SELECT count(value1), octet_length(str1) FROM s3 GROUP BY octet_length(str1), str1 HAVING octet_length(str1) IS NOT NULL ORDER BY 1,2;
-- select octet_length with group by having (result)
--Testcase 1464:
SELECT count(value1), octet_length(str1) FROM s3 GROUP BY octet_length(str1), str1 HAVING octet_length(str1) IS NOT NULL ORDER BY 1,2;

-- select octet_length with group by index having (result)
--Testcase 1465:
SELECT value1, octet_length(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test ord()
--
-- select ord (stub function, explain)
--Testcase 1466:
EXPLAIN VERBOSE
SELECT ord(value1), ord(value2), ord(value3), ord(value4), ord(str1), ord(str2) FROM s3 ORDER BY 1,2,3,4,5,6;
-- select ord (stub function, result)
--Testcase 1467:
SELECT ord(value1), ord(value2), ord(value3), ord(value4), ord(str1), ord(str2) FROM s3 ORDER BY 1,2,3,4,5,6;

-- select ord (stub function, not pushdown constraints, explain)
--Testcase 1468:
EXPLAIN VERBOSE
SELECT value1, ord(str2) FROM s3 WHERE to_hex(value2) = '64';
-- select ord (stub function, not pushdown constraints, result)
--Testcase 1469:
SELECT value1, ord(str2) FROM s3 WHERE to_hex(value2) = '64';

-- select ord (stub function, pushdown constraints, explain)
--Testcase 1470:
EXPLAIN VERBOSE
SELECT value1, ord(str2) FROM s3 WHERE value2 != 200;
-- select ord (stub function, pushdown constraints, result)
--Testcase 1471:
SELECT value1, ord(str2) FROM s3 WHERE value2 != 200;

-- select ord with non pushdown func and explicit constant (explain)
--Testcase 1472:
EXPLAIN VERBOSE
SELECT ord(str2), pi(), 4.1 FROM s3;
-- select ord with non pushdown func and explicit constant (result)
--Testcase 1473:
SELECT ord(str2), pi(), 4.1 FROM s3;

-- select ord with order by (explain)
--Testcase 1474:
EXPLAIN VERBOSE
SELECT value1, ord(str2) FROM s3 ORDER BY value1, ord(str2);
-- select ord with order by (result)
--Testcase 1475:
SELECT value1, ord(str2) FROM s3 ORDER BY value1, ord(str2);

-- select ord with order by index (result)
--Testcase 1476:
SELECT value1, ord(str2) FROM s3 ORDER BY 2,1;
-- select ord with order by index (result)
--Testcase 1477:
SELECT value1, ord(str2) FROM s3 ORDER BY 1,2;

-- select ord with group by (explain)
--Testcase 1478:
EXPLAIN VERBOSE
SELECT count(value1), ord(str2) FROM s3 GROUP BY ord(str2) ORDER BY 1,2;
-- select ord with group by (result)
--Testcase 1479:
SELECT count(value1), ord(str2) FROM s3 GROUP BY ord(str2) ORDER BY 1,2;

-- select ord with group by index (result)
--Testcase 1480:
SELECT value1, ord(str2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select ord with group by having (explain)
--Testcase 1481:
EXPLAIN VERBOSE
SELECT count(value1), ord(str2) FROM s3 GROUP BY ord(str2), str2 HAVING ord(str2) IS NOT NULL ORDER BY 1,2;
-- select ord with group by having (result)
--Testcase 1482:
SELECT count(value1), ord(str2) FROM s3 GROUP BY ord(str2), str2 HAVING ord(str2) IS NOT NULL ORDER BY 1,2;

-- select ord with group by index having (result)
--Testcase 1483:
SELECT value1, ord(str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test position()
--
-- select position (stub function, explain)
--Testcase 1484:
EXPLAIN VERBOSE
SELECT position('XYZ' IN str1), position('XYZ' IN str2) FROM s3;
-- select position (stub function, result)
--Testcase 1485:
SELECT position('XYZ' IN str1), position('XYZ' IN str2) FROM s3;

-- select position (stub function, not pushdown constraints, explain)
--Testcase 1486:
EXPLAIN VERBOSE
SELECT value1, position('XYZ' IN str1) FROM s3 WHERE to_hex(value2) = '64';
-- select position (stub function, not pushdown constraints, result)
--Testcase 1487:
SELECT value1, position('XYZ' IN str1) FROM s3 WHERE to_hex(value2) = '64';

-- select position (stub function, pushdown constraints, explain)
--Testcase 1488:
EXPLAIN VERBOSE
SELECT value1, position('XYZ' IN str1) FROM s3 WHERE value2 != 200;
-- select position (stub function, pushdown constraints, result)
--Testcase 1489:
SELECT value1, position('XYZ' IN str1) FROM s3 WHERE value2 != 200;

-- select position with non pushdown func and explicit constant (explain)
--Testcase 1490:
EXPLAIN VERBOSE
SELECT position('XYZ' IN str1), pi(), 4.1 FROM s3;
-- select position with non pushdown func and explicit constant (result)
--Testcase 1491:
SELECT position('XYZ' IN str1), pi(), 4.1 FROM s3;

-- select position with order by (explain)
--Testcase 1492:
EXPLAIN VERBOSE
SELECT value1, position('XYZ' IN str1) FROM s3 ORDER BY value1, position('XYZ' IN str1);
-- select position with order by (result)
--Testcase 1493:
SELECT value1, position('XYZ' IN str1) FROM s3 ORDER BY value1, position('XYZ' IN str1);

-- select position with order by index (result)
--Testcase 1494:
SELECT value1, position('XYZ' IN str1) FROM s3 ORDER BY 2,1;
-- select position with order by index (result)
--Testcase 1495:
SELECT value1, position('XYZ' IN str1) FROM s3 ORDER BY 1,2;

-- select position with group by (explain)
--Testcase 1496:
EXPLAIN VERBOSE
SELECT count(value1), position('XYZ' IN str1) FROM s3 GROUP BY position('XYZ' IN str1) ORDER BY 1,2;
-- select position with group by (result)
--Testcase 1497:
SELECT count(value1), position('XYZ' IN str1) FROM s3 GROUP BY position('XYZ' IN str1) ORDER BY 1,2;

-- select position with group by index (result)
--Testcase 1498:
SELECT value1, position('XYZ' IN str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select position with group by having (explain)
--Testcase 1499:
EXPLAIN VERBOSE
SELECT count(value1), position('XYZ' IN str1) FROM s3 GROUP BY position('XYZ' IN str1), str1 HAVING position('XYZ' IN str1) IS NOT NULL ORDER BY 1,2;
-- select position with group by having (result)
--Testcase 1500:
SELECT count(value1), position('XYZ' IN str1) FROM s3 GROUP BY position('XYZ' IN str1), str1 HAVING position('XYZ' IN str1) IS NOT NULL ORDER BY 1,2;

-- select position with group by index having (result)
--Testcase 1501:
SELECT value1, position('XYZ' IN str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test quote()
--
-- select quote (stub function, explain)
--Testcase 1502:
EXPLAIN VERBOSE
SELECT quote(str1), quote(str2) FROM s3;
-- select quote (stub function, result)
--Testcase 1503:
SELECT quote(str1), quote(str2) FROM s3;

-- select quote (stub function, not pushdown constraints, explain)
--Testcase 1504:
EXPLAIN VERBOSE
SELECT value1, quote(str2) FROM s3 WHERE to_hex(value2) = '64';
-- select quote (stub function, not pushdown constraints, result)
--Testcase 1505:
SELECT value1, quote(str2) FROM s3 WHERE to_hex(value2) = '64';

-- select quote (stub function, pushdown constraints, explain)
--Testcase 1506:
EXPLAIN VERBOSE
SELECT value1, quote(str2) FROM s3 WHERE value2 != 200;
-- select quote (stub function, pushdown constraints, result)
--Testcase 1507:
SELECT value1, quote(str2) FROM s3 WHERE value2 != 200;

-- select quote with non pushdown func and explicit constant (explain)
--Testcase 1508:
EXPLAIN VERBOSE
SELECT quote(str2), pi(), 4.1 FROM s3;
-- select quote with non pushdown func and explicit constant (result)
--Testcase 1509:
SELECT quote(str2), pi(), 4.1 FROM s3;

-- select quote with order by (explain)
--Testcase 1510:
EXPLAIN VERBOSE
SELECT value1, quote(str2) FROM s3 ORDER BY value1, quote(str2);
-- select quote with order by (result)
--Testcase 1511:
SELECT value1, quote(str2) FROM s3 ORDER BY value1, quote(str2);

-- select quote with order by index (result)
--Testcase 1512:
SELECT value1, quote(str2) FROM s3 ORDER BY 2,1;
-- select quote with order by index (result)
--Testcase 1513:
SELECT value1, quote(str2) FROM s3 ORDER BY 1,2;

-- select quote with group by (explain)
--Testcase 1514:
EXPLAIN VERBOSE
SELECT count(value1), quote(str2) FROM s3 GROUP BY quote(str2) ORDER BY 1,2;
-- select quote with group by (result)
--Testcase 1515:
SELECT count(value1), quote(str2) FROM s3 GROUP BY quote(str2) ORDER BY 1,2;

-- select quote with group by index (result)
--Testcase 1516:
SELECT value1, quote(str2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select quote with group by having (explain)
--Testcase 1517:
EXPLAIN VERBOSE
SELECT count(value1), quote(str2) FROM s3 GROUP BY quote(str2), str2 HAVING quote(str2) IS NOT NULL ORDER BY 1,2;
-- select quote with group by having (result)
--Testcase 1518:
SELECT count(value1), quote(str2) FROM s3 GROUP BY quote(str2), str2 HAVING quote(str2) IS NOT NULL ORDER BY 1,2;

-- select quote with group by index having (result)
--Testcase 1519:
SELECT value1, quote(str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test mysql_regexp_instr()
--
-- select mysql_regexp_instr (stub function, explain)
--Testcase 1520:
EXPLAIN VERBOSE
SELECT mysql_regexp_instr(str1, 'XY'), mysql_regexp_instr(str2, 'XYZ') FROM s3;
-- select mysql_regexp_instr (stub function, result)
--Testcase 1521:
SELECT mysql_regexp_instr(str1, 'XY'), mysql_regexp_instr(str2, 'XYZ') FROM s3;

-- select mysql_regexp_instr (stub function, explain)
--Testcase 1522:
EXPLAIN VERBOSE
SELECT mysql_regexp_instr(str1, 'XY', 3), mysql_regexp_instr(str2, 'XYZ', 3) FROM s3;
-- select mysql_regexp_instr (stub function, result)
--Testcase 1523:
SELECT mysql_regexp_instr(str1, 'XY', 3), mysql_regexp_instr(str2, 'XYZ', 3) FROM s3;

-- select mysql_regexp_instr (stub function, explain)
--Testcase 1524:
EXPLAIN VERBOSE
SELECT mysql_regexp_instr(str1, 'XY', 3, 0), mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3;
-- select mysql_regexp_instr (stub function, result)
--Testcase 1525:
SELECT mysql_regexp_instr(str1, 'XY', 3, 0), mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3;

-- select mysql_regexp_instr (stub function, explain)
--Testcase 1526:
EXPLAIN VERBOSE
SELECT mysql_regexp_instr(str1, 'XY', 3, 0, 1), mysql_regexp_instr(str2, 'XYZ', 3, 0, 1) FROM s3;
-- select mysql_regexp_instr (stub function, result)
--Testcase 1527:
SELECT mysql_regexp_instr(str1, 'XY', 3, 0, 1), mysql_regexp_instr(str2, 'XYZ', 3, 0, 1) FROM s3;

-- select mysql_regexp_instr (stub function, explain)
--Testcase 1528:
EXPLAIN VERBOSE
SELECT mysql_regexp_instr(str1, 'xy', 3, 0, 1, 'i'), mysql_regexp_instr(str2, 'xyz', 3, 0, 1, 'i') FROM s3;
-- select mysql_regexp_instr (stub function, result)
--Testcase 1529:
SELECT mysql_regexp_instr(str1, 'xy', 3, 0, 1, 'i'), mysql_regexp_instr(str2, 'xyz', 3, 0, 1, 'i') FROM s3;

-- select mysql_regexp_instr (stub function, not pushdown constraints, explain)
--Testcase 1530:
EXPLAIN VERBOSE
SELECT value1, mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 WHERE to_hex(value2) = '64';
-- select mysql_regexp_instr (stub function, not pushdown constraints, result)
--Testcase 1531:
SELECT value1, mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 WHERE to_hex(value2) = '64';

-- select mysql_regexp_instr (stub function, pushdown constraints, explain)
--Testcase 1532:
EXPLAIN VERBOSE
SELECT value1, mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 WHERE value2 != 200;
-- select mysql_regexp_instr (stub function, pushdown constraints, result)
--Testcase 1533:
SELECT value1, mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 WHERE value2 != 200;

-- select mysql_regexp_instr with non pushdown func and explicit constant (explain)
--Testcase 1534:
EXPLAIN VERBOSE
SELECT mysql_regexp_instr(str2, 'XYZ', 3, 0), pi(), 4.1 FROM s3;
-- select mysql_regexp_instr with non pushdown func and explicit constant (result)
--Testcase 1535:
SELECT mysql_regexp_instr(str2, 'XYZ', 3, 0), pi(), 4.1 FROM s3;

-- select mysql_regexp_instr with order by (explain)
--Testcase 1536:
EXPLAIN VERBOSE
SELECT value1, mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 ORDER BY value1, mysql_regexp_instr(str2, 'XYZ', 3, 0);
-- select mysql_regexp_instr with order by (result)
--Testcase 1537:
SELECT value1, mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 ORDER BY value1, mysql_regexp_instr(str2, 'XYZ', 3, 0);

-- select mysql_regexp_instr with order by index (result)
--Testcase 1538:
SELECT value1, mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 ORDER BY 2,1;
-- select mysql_regexp_instr with order by index (result)
--Testcase 1539:
SELECT value1, mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 ORDER BY 1,2;

-- select mysql_regexp_instr with group by (explain)
--Testcase 1540:
EXPLAIN VERBOSE
SELECT count(value1), mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 GROUP BY mysql_regexp_instr(str2, 'XYZ', 3, 0) ORDER BY 1,2;
-- select mysql_regexp_instr with group by (result)
--Testcase 1541:
SELECT count(value1), mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 GROUP BY mysql_regexp_instr(str2, 'XYZ', 3, 0) ORDER BY 1,2;

-- select mysql_regexp_instr with group by index (result)
--Testcase 1542:
SELECT value1, mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select mysql_regexp_instr with group by having (explain)
--Testcase 1543:
EXPLAIN VERBOSE
SELECT count(value1), mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 GROUP BY mysql_regexp_instr(str2, 'XYZ', 3, 0), str2 HAVING mysql_regexp_instr(str2, 'XYZ', 3, 0) IS NOT NULL ORDER BY 1,2;
-- select mysql_regexp_instr with group by having (result)
--Testcase 1544:
SELECT count(value1), mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 GROUP BY mysql_regexp_instr(str2, 'XYZ', 3, 0), str2 HAVING mysql_regexp_instr(str2, 'XYZ', 3, 0) IS NOT NULL ORDER BY 1,2;

-- select mysql_regexp_instr with group by index having (result)
--Testcase 1545:
SELECT value1, mysql_regexp_instr(str2, 'XYZ', 3, 0) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test mysql_regexp_like()
--
-- select mysql_regexp_like (stub function, explain)
--Testcase 1546:
EXPLAIN VERBOSE
SELECT mysql_regexp_instr(str1, 'XY'), mysql_regexp_instr(str2, 'XYZ') FROM s3;
-- select mysql_regexp_like (stub function, result)
--Testcase 1547:
SELECT mysql_regexp_instr(str1, 'XY'), mysql_regexp_instr(str2, 'XYZ') FROM s3;

-- select mysql_regexp_like (stub function, explain)
--Testcase 1548:
EXPLAIN VERBOSE
SELECT mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3;
-- select mysql_regexp_like (stub function, result)
--Testcase 1549:
SELECT mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3;

-- select mysql_regexp_like (stub function, not pushdown constraints, explain)
--Testcase 1550:
EXPLAIN VERBOSE
SELECT value1, mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 WHERE to_hex(value2) = '64';
-- select mysql_regexp_like (stub function, not pushdown constraints, result)
--Testcase 1551:
SELECT value1, mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 WHERE to_hex(value2) = '64';

-- select mysql_regexp_like (stub function, pushdown constraints, explain)
--Testcase 1552:
EXPLAIN VERBOSE
SELECT value1, mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 WHERE value2 != 200;
-- select mysql_regexp_like (stub function, pushdown constraints, result)
--Testcase 1553:
SELECT value1, mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 WHERE value2 != 200;

-- select mysql_regexp_like with non pushdown func and explicit constant (explain)
--Testcase 1554:
EXPLAIN VERBOSE
SELECT mysql_regexp_like('   XyZ   ', str2, 'i'), pi(), 4.1 FROM s3;
-- select mysql_regexp_like with non pushdown func and explicit constant (result)
--Testcase 1555:
SELECT mysql_regexp_like('   XyZ   ', str2, 'i'), pi(), 4.1 FROM s3;

-- select mysql_regexp_like with order by (explain)
--Testcase 1556:
EXPLAIN VERBOSE
SELECT value1, mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 ORDER BY value1, mysql_regexp_like('   XyZ   ', str2, 'i');
-- select mysql_regexp_like with order by (result)
--Testcase 1557:
SELECT value1, mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 ORDER BY value1, mysql_regexp_like('   XyZ   ', str2, 'i');

-- select mysql_regexp_like with order by index (result)
--Testcase 1558:
SELECT value1, mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 ORDER BY 2,1;
-- select mysql_regexp_like with order by index (result)
--Testcase 1559:
SELECT value1, mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 ORDER BY 1,2;

-- select mysql_regexp_like with group by (explain)
--Testcase 1560:
EXPLAIN VERBOSE
SELECT count(value1), mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 GROUP BY mysql_regexp_like('   XyZ   ', str2, 'i') ORDER BY 1,2;
-- select mysql_regexp_like with group by (result)
--Testcase 1561:
SELECT count(value1), mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 GROUP BY mysql_regexp_like('   XyZ   ', str2, 'i') ORDER BY 1,2;

-- select mysql_regexp_like with group by index (result)
--Testcase 1562:
SELECT value1, mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select mysql_regexp_like with group by having (explain)
--Testcase 1563:
EXPLAIN VERBOSE
SELECT count(value1), mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 GROUP BY mysql_regexp_like('   XyZ   ', str2, 'i'), str2 HAVING mysql_regexp_like('   XyZ   ', str2, 'i') > 0 ORDER BY 1,2;
-- select mysql_regexp_like with group by having (result)
--Testcase 1564:
SELECT count(value1), mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 GROUP BY mysql_regexp_like('   XyZ   ', str2, 'i'), str2 HAVING mysql_regexp_like('   XyZ   ', str2, 'i') > 0 ORDER BY 1,2;

-- select mysql_regexp_like with group by index having (result)
--Testcase 1565:
SELECT value1, mysql_regexp_like('   XyZ   ', str2, 'i') FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test mysql_regexp_replace()
--
-- select mysql_regexp_replace (stub function, explain)
--Testcase 1566:
EXPLAIN VERBOSE
SELECT mysql_regexp_replace(str1, 'X', 'x') FROM s3;
-- select mysql_regexp_replace (stub function, result)
--Testcase 1567:
SELECT mysql_regexp_replace(str1, 'X', 'x') FROM s3;

-- select mysql_regexp_replace (stub function, explain)
--Testcase 1568:
EXPLAIN VERBOSE
SELECT mysql_regexp_replace(str1, 'Y', 'y', 3) FROM s3;
-- select mysql_regexp_replace (stub function, result)
--Testcase 1569:
SELECT mysql_regexp_replace(str1, 'Y', 'y', 3) FROM s3;

-- select mysql_regexp_replace (stub function, explain)
--Testcase 1570:
EXPLAIN VERBOSE
SELECT mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3;
-- select mysql_regexp_replace (stub function, result)
--Testcase 1571:
SELECT mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3;

-- select mysql_regexp_replace (stub function, explain)
--Testcase 1572:
EXPLAIN VERBOSE
SELECT mysql_regexp_replace(str1, 'y', 'K', 3, 0, 'i') FROM s3;
-- select mysql_regexp_replace (stub function, result)
--Testcase 1573:
SELECT mysql_regexp_replace(str1, 'y', 'K', 3, 0, 'i') FROM s3;

-- select mysql_regexp_replace (stub function, explain)
--Testcase 1574:
EXPLAIN VERBOSE
SELECT mysql_regexp_replace(str1, 'y', NULL, 3, 3, 'i') FROM s3;
-- select mysql_regexp_replace (stub function, result)
--Testcase 1575:
SELECT mysql_regexp_replace(str1, 'y', NULL, 3, 3, 'i') FROM s3;

-- select mysql_regexp_replace (stub function, not pushdown constraints, explain)
--Testcase 1576:
EXPLAIN VERBOSE
SELECT value1, mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 WHERE to_hex(value2) = '64';
-- select mysql_regexp_replace (stub function, not pushdown constraints, result)
--Testcase 1577:
SELECT value1, mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 WHERE to_hex(value2) = '64';

-- select mysql_regexp_replace (stub function, pushdown constraints, explain)
--Testcase 1578:
EXPLAIN VERBOSE
SELECT value1, mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 WHERE value2 != 200;
-- select mysql_regexp_replace (stub function, pushdown constraints, result)
--Testcase 1579:
SELECT value1, mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 WHERE value2 != 200;

-- select mysql_regexp_replace with non pushdown func and explicit constant (explain)
--Testcase 1580:
EXPLAIN VERBOSE
SELECT mysql_regexp_replace(str1, 'Y', 'y', 3, 3), pi(), 4.1 FROM s3;
-- select mysql_regexp_replace with non pushdown func and explicit constant (result)
--Testcase 1581:
SELECT mysql_regexp_replace(str1, 'Y', 'y', 3, 3), pi(), 4.1 FROM s3;

-- select mysql_regexp_replace with order by (explain)
--Testcase 1582:
EXPLAIN VERBOSE
SELECT value1, mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 ORDER BY value1, mysql_regexp_replace(str1, 'Y', 'y', 3, 3);
-- select mysql_regexp_replace with order by (result)
--Testcase 1583:
SELECT value1, mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 ORDER BY value1, mysql_regexp_replace(str1, 'Y', 'y', 3, 3);

-- select mysql_regexp_replace with order by index (result)
--Testcase 1584:
SELECT value1, mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 ORDER BY 2,1;
-- select mysql_regexp_replace with order by index (result)
--Testcase 1585:
SELECT value1, mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 ORDER BY 1,2;

-- select mysql_regexp_replace with group by (explain)
--Testcase 1586:
EXPLAIN VERBOSE
SELECT count(value1), mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 GROUP BY mysql_regexp_replace(str1, 'Y', 'y', 3, 3) ORDER BY 1,2;
-- select mysql_regexp_replace with group by (result)
--Testcase 1587:
SELECT count(value1), mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 GROUP BY mysql_regexp_replace(str1, 'Y', 'y', 3, 3) ORDER BY 1,2;

-- select mysql_regexp_replace with group by index (result)
--Testcase 1588:
SELECT value1, mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select mysql_regexp_replace with group by having (explain)
--Testcase 1589:
EXPLAIN VERBOSE
SELECT count(value1), mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 GROUP BY mysql_regexp_replace(str1, 'Y', 'y', 3, 3), str1 HAVING mysql_regexp_replace(str1, 'Y', 'y', 3, 3) IS NOT NULL ORDER BY 1,2;
-- select mysql_regexp_replace with group by having (result)
--Testcase 1590:
SELECT count(value1), mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 GROUP BY mysql_regexp_replace(str1, 'Y', 'y', 3, 3), str1 HAVING mysql_regexp_replace(str1, 'Y', 'y', 3, 3) IS NOT NULL ORDER BY 1,2;

-- select mysql_regexp_replace with group by index having (result)
--Testcase 1591:
SELECT value1, mysql_regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test mysql_regexp_substr()
--
-- select mysql_regexp_substr (stub function, explain)
--Testcase 1592:
EXPLAIN VERBOSE
SELECT mysql_regexp_substr(str1, 'XYZ') FROM s3;
-- select mysql_regexp_substr (stub function, result)
--Testcase 1593:
SELECT mysql_regexp_substr(str1, 'XYZ') FROM s3;

-- select mysql_regexp_substr (stub function, explain)
--Testcase 1594:
EXPLAIN VERBOSE
SELECT mysql_regexp_substr(str1, 'XYZ', 3) FROM s3;
-- select mysql_regexp_substr (stub function, result)
--Testcase 1595:
SELECT mysql_regexp_substr(str1, 'XYZ', 3) FROM s3;

-- select mysql_regexp_substr (stub function, explain)
--Testcase 1596:
EXPLAIN VERBOSE
SELECT mysql_regexp_substr(str2, 'XYZ', 4, 0) FROM s3;
-- select mysql_regexp_substr (stub function, result)
--Testcase 1597:
SELECT mysql_regexp_substr(str2, 'XYZ', 4, 0) FROM s3;

-- select mysql_regexp_substr (stub function, explain)
--Testcase 1598:
EXPLAIN VERBOSE
SELECT mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3;
-- select mysql_regexp_substr (stub function, result)
--Testcase 1599:
SELECT mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3;

-- select mysql_regexp_substr (stub function, explain)
--Testcase 1600:
EXPLAIN VERBOSE
SELECT mysql_regexp_substr(str1, NULL, 4, 0, 'i') FROM s3;
-- select mysql_regexp_substr (stub function, result)
--Testcase 1601:
SELECT mysql_regexp_substr(str1, NULL, 4, 0, 'i') FROM s3;

-- select mysql_regexp_substr (stub function, not pushdown constraints, explain)
--Testcase 1602:
EXPLAIN VERBOSE
SELECT value1, mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 WHERE to_hex(value2) = '64';
-- select mysql_regexp_substr (stub function, not pushdown constraints, result)
--Testcase 1603:
SELECT value1, mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 WHERE to_hex(value2) = '64';

-- select mysql_regexp_substr (stub function, pushdown constraints, explain)
--Testcase 1604:
EXPLAIN VERBOSE
SELECT value1, mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 WHERE value2 != 200;
-- select mysql_regexp_substr (stub function, pushdown constraints, result)
--Testcase 1605:
SELECT value1, mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 WHERE value2 != 200;

-- select mysql_regexp_substr with non pushdown func and explicit constant (explain)
--Testcase 1606:
EXPLAIN VERBOSE
SELECT mysql_regexp_substr(str1, 'xyz', 4, 0, 'i'), pi(), 4.1 FROM s3;
-- select mysql_regexp_substr with non pushdown func and explicit constant (result)
--Testcase 1607:
SELECT mysql_regexp_substr(str1, 'xyz', 4, 0, 'i'), pi(), 4.1 FROM s3;

-- select mysql_regexp_substr with order by (explain)
--Testcase 1608:
EXPLAIN VERBOSE
SELECT value1, mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 ORDER BY value1, mysql_regexp_substr(str1, 'xyz', 4, 0, 'i');
-- select mysql_regexp_substr with order by (result)
--Testcase 1609:
SELECT value1, mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 ORDER BY value1, mysql_regexp_substr(str1, 'xyz', 4, 0, 'i');

-- select mysql_regexp_substr with order by index (result)
--Testcase 1610:
SELECT value1, mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 ORDER BY 2,1;
-- select mysql_regexp_substr with order by index (result)
--Testcase 1611:
SELECT value1, mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 ORDER BY 1,2;

-- select mysql_regexp_substr with group by (explain)
--Testcase 1612:
EXPLAIN VERBOSE
SELECT count(value1), mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 GROUP BY mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') ORDER BY 1,2;
-- select mysql_regexp_substr with group by (result)
--Testcase 1613:
SELECT count(value1), mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 GROUP BY mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') ORDER BY 1,2;

-- select mysql_regexp_substr with group by index (result)
--Testcase 1614:
SELECT value1, mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select mysql_regexp_substr with group by having (explain)
--Testcase 1615:
EXPLAIN VERBOSE
SELECT count(value1), mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 GROUP BY mysql_regexp_substr(str1, 'xyz', 4, 0, 'i'), str1 HAVING mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') IS NOT NULL ORDER BY 1,2;
-- select mysql_regexp_substr with group by having (result)
--Testcase 1616:
SELECT count(value1), mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 GROUP BY mysql_regexp_substr(str1, 'xyz', 4, 0, 'i'), str2 HAVING mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') IS NOT NULL ORDER BY 1,2;

-- select mysql_regexp_substr with group by index having (result)
--Testcase 1617:
SELECT value1, mysql_regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test repeat()
--
-- select repeat (stub function, explain)
--Testcase 1618:
EXPLAIN VERBOSE
SELECT repeat(str1, 3), repeat(str2, 3) FROM s3;
-- select repeat (stub function, result)
--Testcase 1619:
SELECT repeat(str1, 3), repeat(str2, 3) FROM s3;

-- select repeat (stub function, not pushdown constraints, explain)
--Testcase 1620:
EXPLAIN VERBOSE
SELECT value1, repeat(str1, 3) FROM s3 WHERE to_hex(value2) = '64';
-- select repeat (stub function, not pushdown constraints, result)
--Testcase 1621:
SELECT value1, repeat(str1, 3) FROM s3 WHERE to_hex(value2) = '64';

-- select repeat (stub function, pushdown constraints, explain)
--Testcase 1622:
EXPLAIN VERBOSE
SELECT value1, repeat(str1, 3) FROM s3 WHERE value2 != 200;
-- select repeat (stub function, pushdown constraints, result)
--Testcase 1623:
SELECT value1, repeat(str1, 3) FROM s3 WHERE value2 != 200;

-- select repeat with non pushdown func and explicit constant (explain)
--Testcase 1624:
EXPLAIN VERBOSE
SELECT repeat(str1, 3), pi(), 4.1 FROM s3;
-- select repeat with non pushdown func and explicit constant (result)
--Testcase 1625:
SELECT repeat(str1, 3), pi(), 4.1 FROM s3;

-- select repeat with order by (explain)
--Testcase 1626:
EXPLAIN VERBOSE
SELECT value1, repeat(str1, 3) FROM s3 ORDER BY value1, repeat(str1, 3);
-- select repeat with order by (result)
--Testcase 1627:
SELECT value1, repeat(str1, 3) FROM s3 ORDER BY value1, repeat(str1, 3);

-- select repeat with order by index (result)
--Testcase 1628:
SELECT value1, repeat(str1, 3) FROM s3 ORDER BY 2,1;
-- select repeat with order by index (result)
--Testcase 1629:
SELECT value1, repeat(str1, 3) FROM s3 ORDER BY 1,2;

-- select repeat with group by (explain)
--Testcase 1630:
EXPLAIN VERBOSE
SELECT count(value1), repeat(str1, 3) FROM s3 GROUP BY repeat(str1, 3) ORDER BY 1,2;
-- select repeat with group by (result)
--Testcase 1631:
SELECT count(value1), repeat(str1, 3) FROM s3 GROUP BY repeat(str1, 3) ORDER BY 1,2;

-- select repeat with group by index (result)
--Testcase 1632:
SELECT value1, repeat(str1, 3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select repeat with group by having (explain)
--Testcase 1633:
EXPLAIN VERBOSE
SELECT count(value1), repeat(str1, 3) FROM s3 GROUP BY repeat(str1, 3), str1 HAVING repeat(str1, 3) IS NOT NULL ORDER BY 1,2;
-- select repeat with group by having (result)
--Testcase 1634:
SELECT count(value1), repeat(str1, 3) FROM s3 GROUP BY repeat(str1, 3), str1 HAVING repeat(str1, 3) IS NOT NULL ORDER BY 1,2;

-- select repeat with group by index having (result)
--Testcase 1635:
SELECT value1, repeat(str1, 3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test replace()
--
-- select replace (stub function, explain)
--Testcase 1636:
EXPLAIN VERBOSE
SELECT replace(str1, 'XYZ', 'ABC'), replace(str2, 'XYZ', 'ABC') FROM s3;
-- select replace (stub function, result)
--Testcase 1637:
SELECT replace(str1, 'XYZ', 'ABC'), replace(str2, 'XYZ', 'ABC') FROM s3;

-- select replace (stub function, not pushdown constraints, explain)
--Testcase 1638:
EXPLAIN VERBOSE
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 WHERE to_hex(value2) = '64';
-- select replace (stub function, not pushdown constraints, result)
--Testcase 1639:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 WHERE to_hex(value2) = '64';

-- select replace (stub function, pushdown constraints, explain)
--Testcase 1640:
EXPLAIN VERBOSE
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 WHERE value2 != 200;
-- select replace (stub function, pushdown constraints, result)
--Testcase 1641:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 WHERE value2 != 200;

-- select replace with non pushdown func and explicit constant (explain)
--Testcase 1642:
EXPLAIN VERBOSE
SELECT replace(str1, 'XYZ', 'ABC'), pi(), 4.1 FROM s3;
-- select replace with non pushdown func and explicit constant (result)
--Testcase 1643:
SELECT replace(str1, 'XYZ', 'ABC'), pi(), 4.1 FROM s3;

-- select replace with order by (explain)
--Testcase 1644:
EXPLAIN VERBOSE
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 ORDER BY value1, replace(str1, 'XYZ', 'ABC');
-- select replace with order by (result)
--Testcase 1645:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 ORDER BY value1, replace(str1, 'XYZ', 'ABC');

-- select replace with order by index (result)
--Testcase 1646:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 ORDER BY 2,1;
-- select replace with order by index (result)
--Testcase 1647:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 ORDER BY 1,2;

-- select replace with group by (explain)
--Testcase 1648:
EXPLAIN VERBOSE
SELECT count(value1), replace(str1, 'XYZ', 'ABC') FROM s3 GROUP BY replace(str1, 'XYZ', 'ABC') ORDER BY 1,2;
-- select replace with group by (result)
--Testcase 1649:
SELECT count(value1), replace(str1, 'XYZ', 'ABC') FROM s3 GROUP BY replace(str1, 'XYZ', 'ABC') ORDER BY 1,2;

-- select replace with group by index (result)
--Testcase 1650:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select replace with group by having (explain)
--Testcase 1651:
EXPLAIN VERBOSE
SELECT count(value1), replace(str1, 'XYZ', 'ABC') FROM s3 GROUP BY replace(str1, 'XYZ', 'ABC'), str1 HAVING replace(str1, 'XYZ', 'ABC') IS NOT NULL ORDER BY 1,2;
-- select replace with group by having (result)
--Testcase 1652:
SELECT count(value1), replace(str1, 'XYZ', 'ABC') FROM s3 GROUP BY replace(str1, 'XYZ', 'ABC'), str1 HAVING replace(str1, 'XYZ', 'ABC') IS NOT NULL ORDER BY 1,2;

-- select replace with group by index having (result)
--Testcase 1653:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test reverse()
--
-- select reverse (stub function, explain)
--Testcase 1654:
EXPLAIN VERBOSE
SELECT reverse(str1), reverse(str2) FROM s3;
-- select reverse (stub function, result)
--Testcase 1655:
SELECT reverse(str1), reverse(str2) FROM s3;

-- select reverse (stub function, not pushdown constraints, explain)
--Testcase 1656:
EXPLAIN VERBOSE
SELECT value1, reverse(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select reverse (stub function, not pushdown constraints, result)
--Testcase 1657:
SELECT value1, reverse(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select reverse (stub function, pushdown constraints, explain)
--Testcase 1658:
EXPLAIN VERBOSE
SELECT value1, reverse(str1) FROM s3 WHERE value2 != 200;
-- select reverse (stub function, pushdown constraints, result)
--Testcase 1659:
SELECT value1, reverse(str1) FROM s3 WHERE value2 != 200;

-- select reverse with non pushdown func and explicit constant (explain)
--Testcase 1660:
EXPLAIN VERBOSE
SELECT reverse(str1), pi(), 4.1 FROM s3;
-- select reverse with non pushdown func and explicit constant (result)
--Testcase 1661:
SELECT reverse(str1), pi(), 4.1 FROM s3;

-- select reverse with order by (explain)
--Testcase 1662:
EXPLAIN VERBOSE
SELECT value1, reverse(str1) FROM s3 ORDER BY value1, reverse(str1);
-- select reverse with order by (result)
--Testcase 1663:
SELECT value1, reverse(str1) FROM s3 ORDER BY value1, reverse(str1);

-- select reverse with order by index (result)
--Testcase 1664:
SELECT value1, reverse(str1) FROM s3 ORDER BY 2,1;
-- select reverse with order by index (result)
--Testcase 1665:
SELECT value1, reverse(str1) FROM s3 ORDER BY 1,2;

-- select reverse with group by (explain)
--Testcase 1666:
EXPLAIN VERBOSE
SELECT count(value1), reverse(str1) FROM s3 GROUP BY reverse(str1) ORDER BY 1,2;
-- select reverse with group by (result)
--Testcase 1667:
SELECT count(value1), reverse(str1) FROM s3 GROUP BY reverse(str1) ORDER BY 1,2;

-- select reverse with group by index (result)
--Testcase 1668:
SELECT value1, reverse(str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select reverse with group by having (explain)
--Testcase 1669:
EXPLAIN VERBOSE
SELECT count(value1), reverse(str1) FROM s3 GROUP BY reverse(str1), str1 HAVING reverse(str1) IS NOT NULL ORDER BY 1,2;
-- select reverse with group by having (result)
--Testcase 1670:
SELECT count(value1), reverse(str1) FROM s3 GROUP BY reverse(str1), str1 HAVING reverse(str1) IS NOT NULL ORDER BY 1,2;

-- select reverse with group by index having (result)
--Testcase 1671:
SELECT value1, reverse(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test right()
--
-- select right (stub function, explain)
--Testcase 1672:
EXPLAIN VERBOSE
SELECT right(str1, 4), right(str2, 4) FROM s3;
-- select right (stub function, result)
--Testcase 1673:
SELECT right(str1, 4), right(str2, 4) FROM s3;

-- select right (stub function, not pushdown constraints, explain)
--Testcase 1674:
EXPLAIN VERBOSE
SELECT value1, right(str1, 6) FROM s3 WHERE to_hex(value2) = '64';
-- select right (stub function, not pushdown constraints, result)
--Testcase 1675:
SELECT value1, right(str1, 6) FROM s3 WHERE to_hex(value2) = '64';

-- select right (stub function, pushdown constraints, explain)
--Testcase 1676:
EXPLAIN VERBOSE
SELECT value1, right(str1, 6) FROM s3 WHERE value2 != 200;
-- select right (stub function, pushdown constraints, result)
--Testcase 1677:
SELECT value1, right(str1, 6) FROM s3 WHERE value2 != 200;

-- select right with non pushdown func and explicit constant (explain)
--Testcase 1678:
EXPLAIN VERBOSE
SELECT right(str1, 6), pi(), 4.1 FROM s3;
-- select right with non pushdown func and explicit constant (result)
--Testcase 1679:
SELECT right(str1, 6), pi(), 4.1 FROM s3;

-- select right with order by (explain)
--Testcase 1680:
EXPLAIN VERBOSE
SELECT value1, right(str1, 6) FROM s3 ORDER BY value1, right(str1, 6);
-- select right with order by (result)
--Testcase 1681:
SELECT value1, right(str1, 6) FROM s3 ORDER BY value1, right(str1, 6);

-- select right with order by index (result)
--Testcase 1682:
SELECT value1, right(str1, 6) FROM s3 ORDER BY 2,1;
-- select right with order by index (result)
--Testcase 1683:
SELECT value1, right(str1, 6) FROM s3 ORDER BY 1,2;

-- select right with group by (explain)
--Testcase 1684:
EXPLAIN VERBOSE
SELECT count(value1), right(str1, 6) FROM s3 GROUP BY right(str1, 6) ORDER BY 1,2;
-- select right with group by (result)
--Testcase 1685:
SELECT count(value1), right(str1, 6) FROM s3 GROUP BY right(str1, 6) ORDER BY 1,2;

-- select right with group by index (result)
--Testcase 1686:
SELECT value1, right(str1, 6) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select right with group by having (explain)
--Testcase 1687:
EXPLAIN VERBOSE
SELECT count(value1), right(str1, 6) FROM s3 GROUP BY right(str1, 6), str1 HAVING right(str1, 6) IS NOT NULL ORDER BY 1,2;
-- select right with group by having (result)
--Testcase 1688:
SELECT count(value1), right(str1, 6) FROM s3 GROUP BY right(str1, 6), str1 HAVING right(str1, 6) IS NOT NULL ORDER BY 1,2;

-- select right with group by index having (result)
--Testcase 1689:
SELECT value1, right(str1, 6) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test rpad()
--
-- select rpad (stub function, explain)
--Testcase 1690:
EXPLAIN VERBOSE
SELECT rpad(str1, 16, str2), rpad(str1, 4, str2) FROM s3;
-- select rpad (stub function, result)
--Testcase 1691:
SELECT rpad(str1, 16, str2), rpad(str1, 4, str2) FROM s3;

-- select rpad (stub function, not pushdown constraints, explain)
--Testcase 1692:
EXPLAIN VERBOSE
SELECT value1, rpad(str1, 16, str2) FROM s3 WHERE to_hex(value2) = '64';
-- select rpad (stub function, not pushdown constraints, result)
--Testcase 1693:
SELECT value1, rpad(str1, 16, str2) FROM s3 WHERE to_hex(value2) = '64';

-- select rpad (stub function, pushdown constraints, explain)
--Testcase 1694:
EXPLAIN VERBOSE
SELECT value1, rpad(str1, 16, str2) FROM s3 WHERE value2 != 200;
-- select rpad (stub function, pushdown constraints, result)
--Testcase 1695:
SELECT value1, rpad(str1, 16, str2) FROM s3 WHERE value2 != 200;

-- select rpad with non pushdown func and explicit constant (explain)
--Testcase 1696:
EXPLAIN VERBOSE
SELECT rpad(str1, 16, str2), pi(), 4.1 FROM s3;
-- select rpad with non pushdown func and explicit constant (result)
--Testcase 1697:
SELECT rpad(str1, 16, str2), pi(), 4.1 FROM s3;

-- select rpad with order by (explain)
--Testcase 1698:
EXPLAIN VERBOSE
SELECT value1, rpad(str1, 16, str2) FROM s3 ORDER BY value1, rpad(str1, 16, str2);
-- select rpad with order by (result)
--Testcase 1699:
SELECT value1, rpad(str1, 16, str2) FROM s3 ORDER BY value1, rpad(str1, 16, str2);

-- select rpad with order by index (result)
--Testcase 1700:
SELECT value1, rpad(str1, 16, str2) FROM s3 ORDER BY 2,1;
-- select rpad with order by index (result)
--Testcase 1701:
SELECT value1, rpad(str1, 16, str2) FROM s3 ORDER BY 1,2;

-- select rpad with group by (explain)
--Testcase 1702:
EXPLAIN VERBOSE
SELECT count(value1), rpad(str1, 16, str2) FROM s3 GROUP BY rpad(str1, 16, str2) ORDER BY 1,2;
-- select rpad with group by (result)
--Testcase 1703:
SELECT count(value1), rpad(str1, 16, str2) FROM s3 GROUP BY rpad(str1, 16, str2) ORDER BY 1,2;

-- select rpad with group by index (result)
--Testcase 1704:
SELECT value1, rpad(str1, 16, str2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select rpad with group by having (explain)
--Testcase 1705:
EXPLAIN VERBOSE
SELECT count(value1), rpad(str1, 16, str2) FROM s3 GROUP BY rpad(str1, 16, str2) HAVING rpad(str1, 16, str2) IS NOT NULL ORDER BY 1,2;
-- select rpad with group by having (result)
--Testcase 1706:
SELECT count(value1), rpad(str1, 16, str2) FROM s3 GROUP BY rpad(str1, 16, str2) HAVING rpad(str1, 16, str2) IS NOT NULL ORDER BY 1,2;

-- select rpad with group by index having (result)
--Testcase 1707:
SELECT value1, rpad(str1, 16, str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test rtrim()
--
-- select rtrim (stub function, explain)
--Testcase 1708:
EXPLAIN VERBOSE
SELECT rtrim(str1), rtrim(str2, ' ') FROM s3;
-- select rtrim (stub function, result)
--Testcase 1709:
SELECT rtrim(str1), rtrim(str2, ' ') FROM s3;

-- select rtrim (stub function, not pushdown constraints, explain)
--Testcase 1710:
EXPLAIN VERBOSE
SELECT value1, rtrim(str1, '-') FROM s3 WHERE to_hex(value2) = '64';
-- select rtrim (stub function, not pushdown constraints, result)
--Testcase 1711:
SELECT value1, rtrim(str1, '-') FROM s3 WHERE to_hex(value2) = '64';

-- select rtrim (stub function, pushdown constraints, explain)
--Testcase 1712:
EXPLAIN VERBOSE
SELECT value1, rtrim(str1, '-') FROM s3 WHERE value2 != 200;
-- select rtrim (stub function, pushdown constraints, result)
--Testcase 1713:
SELECT value1, rtrim(str1, '-') FROM s3 WHERE value2 != 200;

-- select rtrim with non pushdown func and explicit constant (explain)
--Testcase 1714:
EXPLAIN VERBOSE
SELECT rtrim(str1, '-'), pi(), 4.1 FROM s3;
-- select rtrim with non pushdown func and explicit constant (result)
--Testcase 1715:
SELECT rtrim(str1, '-'), pi(), 4.1 FROM s3;

-- select rtrim with order by (explain)
--Testcase 1716:
EXPLAIN VERBOSE
SELECT value1, rtrim(str1, '-') FROM s3 ORDER BY value1, rtrim(str1, '-');
-- select rtrim with order by (result)
--Testcase 1717:
SELECT value1, rtrim(str1, '-') FROM s3 ORDER BY value1, rtrim(str1, '-');

-- select rtrim with order by index (result)
--Testcase 1718:
SELECT value1, rtrim(str1, '-') FROM s3 ORDER BY 2,1;
-- select rtrim with order by index (result)
--Testcase 1719:
SELECT value1, rtrim(str1, '-') FROM s3 ORDER BY 1,2;

-- select rtrim with group by (explain)
--Testcase 1720:
EXPLAIN VERBOSE
SELECT count(value1), rtrim(str1, '-') FROM s3 GROUP BY rtrim(str1, '-') ORDER BY 1,2;
-- select rtrim with group by (result)
--Testcase 1721:
SELECT count(value1), rtrim(str1, '-') FROM s3 GROUP BY rtrim(str1, '-') ORDER BY 1,2;

-- select rtrim with group by index (result)
--Testcase 1722:
SELECT value1, rtrim(str2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select rtrim with group by having (explain)
--Testcase 1723:
EXPLAIN VERBOSE
SELECT count(value1), rtrim(str1, '-') FROM s3 GROUP BY rtrim(str1, '-') HAVING rtrim(str1, '-') IS NOT NULL ORDER BY 1,2;
-- select rtrim with group by having (result)
--Testcase 1724:
SELECT count(value1), rtrim(str1, '-') FROM s3 GROUP BY rtrim(str1, '-') HAVING rtrim(str1, '-') IS NOT NULL ORDER BY 1,2;

-- select rtrim with group by index having (result)
--Testcase 1725:
SELECT value1, rtrim(str1, '-') FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test space()
--
-- select space (stub function, explain)
--Testcase 1726:
EXPLAIN VERBOSE
SELECT space(value2), space(value4) FROM s3;
-- select space (stub function, result)
--Testcase 1727:
SELECT space(value2), space(value4) FROM s3;

-- select space (stub function, not pushdown constraints, explain)
--Testcase 1728:
EXPLAIN VERBOSE
SELECT value1, space(id) FROM s3 WHERE to_hex(value2) = '64';
-- select space (stub function, not pushdown constraints, result)
--Testcase 1729:
SELECT value1, space(id) FROM s3 WHERE to_hex(value2) = '64';

-- select space (stub function, pushdown constraints, explain)
--Testcase 1730:
EXPLAIN VERBOSE
SELECT value1, space(id) FROM s3 WHERE value2 != 200;
-- select space (stub function, pushdown constraints, result)
--Testcase 1731:
SELECT value1, space(id) FROM s3 WHERE value2 != 200;

-- select space as nest function with agg (pushdown, explain)
--Testcase 1732:
EXPLAIN VERBOSE
SELECT sum(value3), space(sum(id)) FROM s3;
-- select space as nest function with agg (pushdown, result)
--Testcase 1733:
SELECT sum(value3), space(sum(id)) FROM s3;

-- select space with non pushdown func and explicit constant (explain)
--Testcase 1734:
EXPLAIN VERBOSE
SELECT space(id), pi(), 4.1 FROM s3;
-- select space with non pushdown func and explicit constant (result)
--Testcase 1735:
SELECT space(id), pi(), 4.1 FROM s3;

-- select space with order by (explain)
--Testcase 1736:
EXPLAIN VERBOSE
SELECT value1, space(id) FROM s3 ORDER BY value1, space(id);
-- select space with order by (result)
--Testcase 1737:
SELECT value1, space(id) FROM s3 ORDER BY value1, space(id);

-- select space with order by index (result)
--Testcase 1738:
SELECT value1, space(id) FROM s3 ORDER BY 2,1;
-- select space with order by index (result)
--Testcase 1739:
SELECT value1, space(id) FROM s3 ORDER BY 1,2;

-- select space with group by (explain)
--Testcase 1740:
EXPLAIN VERBOSE
SELECT value1, space(id) FROM s3 GROUP BY value1, space(id) ORDER BY 1,2;
-- select space with group by (result)
--Testcase 1741:
SELECT value1, space(id) FROM s3 GROUP BY value1, space(id) ORDER BY 1,2;

-- select space with group by index (result)
--Testcase 1742:
SELECT value1, space(id) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select space with group by having (explain)
--Testcase 1743:
EXPLAIN VERBOSE
SELECT count(value1), space(id) FROM s3 GROUP BY space(id), id HAVING space(id) IS NOT NULL ORDER BY 1,2;
-- select space with group by having (result)
--Testcase 1744:
SELECT count(value1), space(id) FROM s3 GROUP BY space(id), id HAVING space(id) IS NOT NULL ORDER BY 1,2;

-- select space with group by index having (result)
--Testcase 1745:
SELECT value1, space(id) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test strcmp()
--
-- select strcmp (stub function, explain)
--Testcase 1746:
EXPLAIN VERBOSE
SELECT strcmp(str1, str2) FROM s3;
-- select strcmp (stub function, result)
--Testcase 1747:
SELECT strcmp(str1, str2) FROM s3;

-- select strcmp (stub function, not pushdown constraints, explain)
--Testcase 1748:
EXPLAIN VERBOSE
SELECT value1, strcmp(str1, str2) FROM s3 WHERE to_hex(value2) = '64';
-- select strcmp (stub function, not pushdown constraints, result)
--Testcase 1749:
SELECT value1, strcmp(str1, str2) FROM s3 WHERE to_hex(value2) = '64';

-- select strcmp (stub function, pushdown constraints, explain)
--Testcase 1750:
EXPLAIN VERBOSE
SELECT value1, strcmp(str1, str2) FROM s3 WHERE value2 != 200;
-- select strcmp (stub function, pushdown constraints, result)
--Testcase 1751:
SELECT value1, strcmp(str1, str2) FROM s3 WHERE value2 != 200;

-- select strcmp with non pushdown func and explicit constant (explain)
--Testcase 1752:
EXPLAIN VERBOSE
SELECT strcmp(str1, str2), pi(), 4.1 FROM s3;
-- select strcmp with non pushdown func and explicit constant (result)
--Testcase 1753:
SELECT strcmp(str1, str2), pi(), 4.1 FROM s3;

-- select strcmp with order by (explain)
--Testcase 1754:
EXPLAIN VERBOSE
SELECT value1, strcmp(str1, str2) FROM s3 ORDER BY value1, strcmp(str1, str2);
-- select strcmp with order by (result)
--Testcase 1755:
SELECT value1, strcmp(str1, str2) FROM s3 ORDER BY value1, strcmp(str1, str2);

-- select strcmp with order by index (result)
--Testcase 1756:
SELECT value1, strcmp(str1, str2) FROM s3 ORDER BY 2,1;
-- select strcmp with order by index (result)
--Testcase 1757:
SELECT value1, strcmp(str1, str2) FROM s3 ORDER BY 1,2;

-- select strcmp with group by (explain)
--Testcase 1758:
EXPLAIN VERBOSE
SELECT count(value1), strcmp(str1, str2) FROM s3 GROUP BY strcmp(str1, str2) ORDER BY 1,2;
-- select strcmp with group by (result)
--Testcase 1759:
SELECT count(value1), strcmp(str1, str2) FROM s3 GROUP BY strcmp(str1, str2) ORDER BY 1,2;

-- select strcmp with group by index (result)
--Testcase 1760:
SELECT value1, strcmp(str1, str2) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select strcmp with group by having (explain)
--Testcase 1761:
EXPLAIN VERBOSE
SELECT count(value1), strcmp(str1, str2) FROM s3 GROUP BY strcmp(str1, str2), str1, str2 HAVING strcmp(str1, str2) IS NOT NULL ORDER BY 1,2;
-- select strcmp with group by having (result)
--Testcase 1762:
SELECT count(value1), strcmp(str1, str2) FROM s3 GROUP BY strcmp(str1, str2), str1, str2 HAVING strcmp(str1, str2) IS NOT NULL ORDER BY 1,2;

-- select strcmp with group by index having (result)
--Testcase 1763:
SELECT value1, strcmp(str1, str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test substr()
--
-- select substr (stub function, explain)
--Testcase 1764:
EXPLAIN VERBOSE
SELECT substr(str1, 3), substr(str2, 3, 4) FROM s3;
-- select substr (stub function, result)
--Testcase 1765:
SELECT substr(str1, 3), substr(str2, 3, 4) FROM s3;

-- select substr (stub function, not pushdown constraints, explain)
--Testcase 1766:
EXPLAIN VERBOSE
SELECT value1, substr(str2, 3, 4) FROM s3 WHERE to_hex(value2) = '64';
-- select substr (stub function, not pushdown constraints, result)
--Testcase 1767:
SELECT value1, substr(str2, 3, 4) FROM s3 WHERE to_hex(value2) = '64';

-- select substr (stub function, pushdown constraints, explain)
--Testcase 1768:
EXPLAIN VERBOSE
SELECT value1, substr(str2, 3, 4) FROM s3 WHERE value2 != 200;
-- select substr (stub function, pushdown constraints, result)
--Testcase 1769:
SELECT value1, substr(str2, 3, 4) FROM s3 WHERE value2 != 200;

-- select substr with non pushdown func and explicit constant (explain)
--Testcase 1770:
EXPLAIN VERBOSE
SELECT substr(str2, 3, 4), pi(), 4.1 FROM s3;
-- select substr with non pushdown func and explicit constant (result)
--Testcase 1771:
SELECT substr(str2, 3, 4), pi(), 4.1 FROM s3;

-- select substr with order by (explain)
--Testcase 1772:
EXPLAIN VERBOSE
SELECT value1, substr(str2, 3, 4) FROM s3 ORDER BY value1, substr(str2, 3, 4);
-- select substr with order by (result)
--Testcase 1773:
SELECT value1, substr(str2, 3, 4) FROM s3 ORDER BY value1, substr(str2, 3, 4);

-- select substr with order by index (result)
--Testcase 1774:
SELECT value1, substr(str2, 3, 4) FROM s3 ORDER BY 2,1;
-- select substr with order by index (result)
--Testcase 1775:
SELECT value1, substr(str2, 3, 4) FROM s3 ORDER BY 1,2;

-- select substr with group by (explain)
--Testcase 1776:
EXPLAIN VERBOSE
SELECT count(value1), substr(str2, 3, 4) FROM s3 GROUP BY substr(str2, 3, 4) ORDER BY 1,2;
-- select substr with group by (result)
--Testcase 1777:
SELECT count(value1), substr(str2, 3, 4) FROM s3 GROUP BY substr(str2, 3, 4) ORDER BY 1,2;

-- select substr with group by index (result)
--Testcase 1778:
SELECT value1, substr(str2, 3, 4) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select substr with group by having (explain)
--Testcase 1779:
EXPLAIN VERBOSE
SELECT count(value1), substr(str2, 3, 4) FROM s3 GROUP BY substr(str2, 3, 4), str2 HAVING substr(str2, 3, 4) IS NOT NULL ORDER BY 1,2;
-- select substr with group by having (result)
--Testcase 1780:
SELECT count(value1), substr(str2, 3, 4) FROM s3 GROUP BY substr(str2, 3, 4), str2 HAVING substr(str2, 3, 4) IS NOT NULL ORDER BY 1,2;

-- select substr with group by index having (result)
--Testcase 1781:
SELECT value1, substr(str2, 3, 4) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test substring()
--
-- select substring (stub function, explain)
--Testcase 1782:
EXPLAIN VERBOSE
SELECT substring(str1, 3), substring(str2, 3, 4) FROM s3;
-- select substring (stub function, result)
--Testcase 1783:
SELECT substring(str1, 3), substring(str2, 3, 4) FROM s3;

-- select substring (stub function, explain)
--Testcase 1784:
EXPLAIN VERBOSE
SELECT substring(str1 FROM 3), substring(str2 FROM 3 FOR 4) FROM s3;
-- select substring (stub function, result)
--Testcase 1785:
SELECT substring(str1 FROM 3), substring(str2 FROM 3 FOR 4) FROM s3;

-- select substring (stub function, not pushdown constraints, explain)
--Testcase 1786:
EXPLAIN VERBOSE
SELECT value1, substring(str2, 3, 4) FROM s3 WHERE to_hex(value2) = '64';
-- select substring (stub function, not pushdown constraints, result)
--Testcase 1787:
SELECT value1, substring(str2, 3, 4) FROM s3 WHERE to_hex(value2) = '64';

-- select substring (stub function, pushdown constraints, explain)
--Testcase 1788:
EXPLAIN VERBOSE
SELECT value1, substring(str2 FROM 3 FOR 4) FROM s3 WHERE value2 != 200;
-- select substring (stub function, pushdown constraints, result)
--Testcase 1789:
SELECT value1, substring(str2 FROM 3 FOR 4) FROM s3 WHERE value2 != 200;

-- select substring with non pushdown func and explicit constant (explain)
--Testcase 1790:
EXPLAIN VERBOSE
SELECT substring(str2 FROM 3 FOR 4), pi(), 4.1 FROM s3;
-- select substring with non pushdown func and explicit constant (result)
--Testcase 1791:
SELECT substring(str2 FROM 3 FOR 4), pi(), 4.1 FROM s3;

-- select substring with order by (explain)
--Testcase 1792:
EXPLAIN VERBOSE
SELECT value1, substring(str2 FROM 3 FOR 4) FROM s3 ORDER BY value1, substring(str2 FROM 3 FOR 4);
-- select substring with order by (result)
--Testcase 1793:
SELECT value1, substring(str2 FROM 3 FOR 4) FROM s3 ORDER BY value1, substring(str2 FROM 3 FOR 4);

-- select substring with order by index (result)
--Testcase 1794:
SELECT value1, substring(str2 FROM 3 FOR 4) FROM s3 ORDER BY 2,1;
-- select substring with order by index (result)
--Testcase 1795:
SELECT value1, substring(str2 FROM 3 FOR 4) FROM s3 ORDER BY 1,2;

-- select substring with group by (explain)
--Testcase 1796:
EXPLAIN VERBOSE
SELECT count(value1), substring(str2, 3, 4) FROM s3 GROUP BY substring(str2, 3, 4) ORDER BY 1,2;
-- select substring with group by (result)
--Testcase 1797:
SELECT count(value1), substring(str2, 3, 4) FROM s3 GROUP BY substring(str2, 3, 4) ORDER BY 1,2;

-- select substring with group by index (result)
--Testcase 1798:
SELECT value1, substring(str2, 3, 4) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select substring with group by having (explain)
--Testcase 1799:
EXPLAIN VERBOSE
SELECT count(value1), substring(str2, 3, 4) FROM s3 GROUP BY substring(str2, 3, 4), str2 HAVING substring(str2, 3, 4) IS NOT NULL ORDER BY 1,2;
-- select substring with group by having (result)
--Testcase 1800:
SELECT count(value1), substring(str2, 3, 4) FROM s3 GROUP BY substring(str2, 3, 4), str2 HAVING substring(str2, 3, 4) IS NOT NULL ORDER BY 1,2;

-- select substring with group by index having (result)
--Testcase 1801:
SELECT value1, substring(str2, 3, 4) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test substring_index()
--
-- select substring_index (stub function, explain)
--Testcase 1802:
EXPLAIN VERBOSE
SELECT substring_index(str1, '-', 5), substring_index(str1, '-', -5) FROM s3;
-- select substring_index (stub function, result)
--Testcase 1803:
SELECT substring_index(str1, '-', 5), substring_index(str1, '-', -5) FROM s3;

-- select substring_index (stub function, not pushdown constraints, explain)
--Testcase 1804:
EXPLAIN VERBOSE
SELECT value1, substring_index(str1, '-', 5) FROM s3 WHERE to_hex(value2) = '64';
-- select substring_index (stub function, not pushdown constraints, result)
--Testcase 1805:
SELECT value1, substring_index(str1, '-', 5) FROM s3 WHERE to_hex(value2) = '64';

-- select substring_index (stub function, pushdown constraints, explain)
--Testcase 1806:
EXPLAIN VERBOSE
SELECT value1, substring_index(str1, '-', 5) FROM s3 WHERE value2 != 200;
-- select substring_index (stub function, pushdown constraints, result)
--Testcase 1807:
SELECT value1, substring_index(str1, '-', 5) FROM s3 WHERE value2 != 200;

-- select substring_index with non pushdown func and explicit constant (explain)
--Testcase 1808:
EXPLAIN VERBOSE
SELECT substring_index(str1, '-', 5), pi(), 4.1 FROM s3;
-- select substring_index with non pushdown func and explicit constant (result)
--Testcase 1809:
SELECT substring_index(str1, '-', 5), pi(), 4.1 FROM s3;

-- select substring_index with order by (explain)
--Testcase 1810:
EXPLAIN VERBOSE
SELECT value1, substring_index(str1, '-', 5) FROM s3 ORDER BY value1, substring_index(str1, '-', 5);
-- select substring_index with order by (result)
--Testcase 1811:
SELECT value1, substring_index(str1, '-', 5) FROM s3 ORDER BY value1, substring_index(str1, '-', 5);

-- select substring_index with order by index (result)
--Testcase 1812:
SELECT value1, substring_index(str1, '-', 5) FROM s3 ORDER BY 2,1;
-- select substring_index with order by index (result)
--Testcase 1813:
SELECT value1, substring_index(str1, '-', 5) FROM s3 ORDER BY 1,2;

-- select substring_index with group by (explain)
--Testcase 1814:
EXPLAIN VERBOSE
SELECT count(value1), substring_index(str1, '-', 5) FROM s3 GROUP BY substring_index(str1, '-', 5) ORDER BY 1,2;
-- select substring_index with group by (result)
--Testcase 1815:
SELECT count(value1), substring_index(str1, '-', 5) FROM s3 GROUP BY substring_index(str1, '-', 5) ORDER BY 1,2;

-- select substring_index with group by index (result)
--Testcase 1816:
SELECT value1, substring_index(str1, '-', 5) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select substring_index with group by having (explain)
--Testcase 1817:
EXPLAIN VERBOSE
SELECT count(value1), substring_index(str1, '-', 5) FROM s3 GROUP BY substring_index(str1, '-', 5), str1 HAVING substring_index(str1, '-', 5) IS NOT NULL ORDER BY 1,2;
-- select substring_index with group by having (result)
--Testcase 1818:
SELECT count(value1), substring_index(str1, '-', 5) FROM s3 GROUP BY substring_index(str1, '-', 5), str1 HAVING substring_index(str1, '-', 5) IS NOT NULL ORDER BY 1,2;

-- select substring_index with group by index having (result)
--Testcase 1819:
SELECT value1, substring_index(str1, '-', 5) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test to_base64()
--
-- select to_base64 (stub function, explain)
--Testcase 1820:
EXPLAIN VERBOSE
SELECT id, to_base64(tag1), to_base64(str1), to_base64(str2) FROM s3 ORDER BY 1,2,3,4;
-- select to_base64 (stub function, result)
--Testcase 1821:
SELECT id, to_base64(tag1), to_base64(str1), to_base64(str2) FROM s3 ORDER BY 1,2,3,4;

-- select to_base64 (stub function, not pushdown constraints, explain)
--Testcase 1822:
EXPLAIN VERBOSE
SELECT value1, to_base64(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select to_base64 (stub function, not pushdown constraints, result)
--Testcase 1823:
SELECT value1, to_base64(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select to_base64 (stub function, pushdown constraints, explain)
--Testcase 1824:
EXPLAIN VERBOSE
SELECT value1, to_base64(str1) FROM s3 WHERE value2 != 200;
-- select to_base64 (stub function, pushdown constraints, result)
--Testcase 1825:
SELECT value1, to_base64(str1) FROM s3 WHERE value2 != 200;

-- select to_base64 with non pushdown func and explicit constant (explain)
--Testcase 1826:
EXPLAIN VERBOSE
SELECT to_base64(str1), pi(), 4.1 FROM s3;
-- select to_base64 with non pushdown func and explicit constant (result)
--Testcase 1827:
SELECT to_base64(str1), pi(), 4.1 FROM s3;

-- select to_base64 with order by (explain)
--Testcase 1828:
EXPLAIN VERBOSE
SELECT value1, to_base64(str1) FROM s3 ORDER BY value1, to_base64(str1);
-- select to_base64 with order by (result)
--Testcase 1829:
SELECT value1, to_base64(str1) FROM s3 ORDER BY value1, to_base64(str1);

-- select to_base64 with order by index (result)
--Testcase 1830:
SELECT value1, to_base64(str1) FROM s3 ORDER BY 2,1;
-- select to_base64 with order by index (result)
--Testcase 1831:
SELECT value1, to_base64(str1) FROM s3 ORDER BY 2,1;

-- select to_base64 with group by (explain)
--Testcase 1832:
EXPLAIN VERBOSE
SELECT count(value1), to_base64(str1) FROM s3 GROUP BY to_base64(str1) ORDER BY 1,2;
-- select to_base64 with group by (result)
--Testcase 1833:
SELECT count(value1), to_base64(str1) FROM s3 GROUP BY to_base64(str1) ORDER BY 1,2;

-- select to_base64 with group by index (result)
--Testcase 1834:
SELECT value1, to_base64(str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select to_base64 with group by having (explain)
--Testcase 1835:
EXPLAIN VERBOSE
SELECT count(value1), to_base64(str1) FROM s3 GROUP BY to_base64(str1), str1 HAVING to_base64(str1) IS NOT NULL ORDER BY 1,2;
-- select to_base64 with group by having (result)
--Testcase 1836:
SELECT count(value1), to_base64(str1) FROM s3 GROUP BY to_base64(str1), str1 HAVING to_base64(str1) IS NOT NULL ORDER BY 1,2;

-- select to_base64 with group by index having (result)
--Testcase 1837:
SELECT value1, to_base64(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test trim()
--
-- select trim (stub function, explain)
--Testcase 1838:
EXPLAIN VERBOSE
SELECT trim(str1), trim(str2) FROM s3;
-- select trim (stub function, result)
--Testcase 1839:
SELECT trim(str1), trim(str2) FROM s3;

-- select trim (stub function, explain)
--Testcase 1840:
EXPLAIN VERBOSE
SELECT trim(LEADING '-' FROM str1), trim(LEADING ' ' FROM str2) FROM s3;
-- select trim (stub function, result)
--Testcase 1841:
SELECT trim(LEADING '-' FROM str1), trim(LEADING ' ' FROM str2) FROM s3;

-- select trim (stub function, explain)
--Testcase 1842:
EXPLAIN VERBOSE
SELECT trim(BOTH '-' FROM str1), trim(BOTH ' ' FROM str2) FROM s3;
-- select trim (stub function, result)
--Testcase 1843:
SELECT trim(BOTH '-' FROM str1), trim(BOTH ' ' FROM str2) FROM s3;

-- select trim (stub function, explain)
--Testcase 1844:
EXPLAIN VERBOSE
SELECT trim(TRAILING '-' FROM str1), trim(TRAILING ' ' FROM str2) FROM s3;
-- select trim (stub function, result)
--Testcase 1845:
SELECT trim(TRAILING '-' FROM str1), trim(TRAILING ' ' FROM str2) FROM s3;

-- select trim (stub function, explain)
--Testcase 1846:
EXPLAIN VERBOSE
SELECT trim('-' FROM str1), trim(' ' FROM str2) FROM s3;
-- select trim (stub function, result)
--Testcase 1847:
SELECT trim('-' FROM str1), trim(' ' FROM str2) FROM s3;

-- select trim (stub function, not pushdown constraints, explain)
--Testcase 1848:
EXPLAIN VERBOSE
SELECT value1, trim('-' FROM str1) FROM s3 WHERE to_hex(value2) = '64';
-- select trim (stub function, not pushdown constraints, result)
--Testcase 1849:
SELECT value1, trim('-' FROM str1) FROM s3 WHERE to_hex(value2) = '64';

-- select trim (stub function, pushdown constraints, explain)
--Testcase 1850:
EXPLAIN VERBOSE
SELECT value1, trim(TRAILING '-' FROM str1) FROM s3 WHERE value2 != 200;
-- select trim (stub function, pushdown constraints, result)
--Testcase 1851:
SELECT value1, trim(TRAILING '-' FROM str1) FROM s3 WHERE value2 != 200;

-- select trim with non pushdown func and explicit constant (explain)
--Testcase 1852:
EXPLAIN VERBOSE
SELECT trim(TRAILING '-' FROM str1), pi(), 4.1 FROM s3;
-- select trim with non pushdown func and explicit constant (result)
--Testcase 1853:
SELECT trim(TRAILING '-' FROM str1), pi(), 4.1 FROM s3;

-- select trim with order by (explain)
--Testcase 1854:
EXPLAIN VERBOSE
SELECT value1, trim(TRAILING '-' FROM str1) FROM s3 ORDER BY value1, trim(TRAILING '-' FROM str1);
-- select trim with order by (result)
--Testcase 1855:
SELECT value1, trim(TRAILING '-' FROM str1) FROM s3 ORDER BY value1, trim(TRAILING '-' FROM str1);

-- select trim with order by index (result)
--Testcase 1856:
SELECT value1, trim('-' FROM str1) FROM s3 ORDER BY 2,1;
-- select trim with order by index (result)
--Testcase 1857:
SELECT value1, trim('-' FROM str1) FROM s3 ORDER BY 1,2;

-- select trim with group by (explain)
--Testcase 1858:
EXPLAIN VERBOSE
SELECT count(value1), trim('-' FROM str1) FROM s3 GROUP BY trim('-' FROM str1) ORDER BY 1,2;
-- select trim with group by (result)
--Testcase 1859:
SELECT count(value1), trim('-' FROM str1) FROM s3 GROUP BY trim('-' FROM str1) ORDER BY 1,2;

-- select trim with group by index (result)
--Testcase 1860:
SELECT value1, trim('-' FROM str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select trim with group by having (explain)
--Testcase 1861:
EXPLAIN VERBOSE
SELECT count(value1), trim('-' FROM str1) FROM s3 GROUP BY trim('-' FROM str1) , str1 HAVING trim('-' FROM str1) IS NOT NULL ORDER BY 1,2;
-- select trim with group by having (result)
--Testcase 1862:
SELECT count(value1), trim('-' FROM str1) FROM s3 GROUP BY trim('-' FROM str1) , str1 HAVING trim('-' FROM str1) IS NOT NULL ORDER BY 1,2;

-- select trim with group by index having (result)
--Testcase 1863:
SELECT value1, trim('-' FROM str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test ucase()
--
-- select ucase (stub function, explain)
--Testcase 1864:
EXPLAIN VERBOSE
SELECT ucase(tag1) FROM s3 ORDER BY 1;
-- select ucase (stub function, result)
--Testcase 1865:
SELECT ucase(tag1) FROM s3 ORDER BY 1;

-- select ucase (stub function, not pushdown constraints, explain)
--Testcase 1866:
EXPLAIN VERBOSE
SELECT value1, ucase(tag1) FROM s3 WHERE to_hex(value2) = '64';
-- select ucase (stub function, not pushdown constraints, result)
--Testcase 1867:
SELECT value1, ucase(tag1) FROM s3 WHERE to_hex(value2) = '64';

-- select ucase (stub function, pushdown constraints, explain)
--Testcase 1868:
EXPLAIN VERBOSE
SELECT value1, ucase(tag1) FROM s3 WHERE value2 != 200;
-- select ucase (stub function, pushdown constraints, result)
--Testcase 1869:
SELECT value1, ucase(tag1) FROM s3 WHERE value2 != 200;

-- select ucase with non pushdown func and explicit constant (explain)
--Testcase 1870:
EXPLAIN VERBOSE
SELECT ucase(tag1), pi(), 4.1 FROM s3 ORDER BY 1;
-- select ucase with non pushdown func and explicit constant (result)
--Testcase 1871:
SELECT ucase(tag1), pi(), 4.1 FROM s3 ORDER BY 1;

-- select ucase with order by (explain)
--Testcase 1872:
EXPLAIN VERBOSE
SELECT value1, ucase(tag1) FROM s3 ORDER BY ucase(tag1);
-- select ucase with order by (result)
--Testcase 1873:
SELECT value1, ucase(tag1) FROM s3 ORDER BY ucase(tag1);

-- select ucase with order by index (result)
--Testcase 1874:
SELECT value1, ucase(tag1) FROM s3 ORDER BY 2,1;
-- select ucase with order by index (result)
--Testcase 1875:
SELECT value1, ucase(tag1) FROM s3 ORDER BY 1,2;

-- select ucase with group by (explain)
--Testcase 1876:
EXPLAIN VERBOSE
SELECT count(value1), ucase(tag1) FROM s3 GROUP BY ucase(tag1) ORDER BY 1,2;
-- select ucase with group by (result)
--Testcase 1877:
SELECT count(value1), ucase(tag1) FROM s3 GROUP BY ucase(tag1) ORDER BY 1,2;

-- select ucase with group by index (result)
--Testcase 1878:
SELECT value1, ucase(tag1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select ucase with group by having (explain)
--Testcase 1879:
EXPLAIN VERBOSE
SELECT count(value1), ucase(tag1) FROM s3 GROUP BY ucase(tag1), tag1 HAVING ucase(tag1) IS NOT NULL ORDER BY 1,2;
-- select ucase with group by having (result)
--Testcase 1880:
SELECT count(value1), ucase(tag1) FROM s3 GROUP BY ucase(tag1), tag1 HAVING ucase(tag1) IS NOT NULL ORDER BY 1,2;

-- select ucase with group by index having (result)
--Testcase 1881:
SELECT value1, ucase(tag1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test unhex()
--
-- select unhex (stub function, explain)
--Testcase 1882:
EXPLAIN VERBOSE
SELECT unhex(hex(str1)), unhex(hex(str2)) FROM s3;
-- select unhex (stub function, result)
--Testcase 1883:
SELECT unhex(hex(str1)), unhex(hex(str2)) FROM s3;

-- select unhex (stub function, not pushdown constraints, explain)
--Testcase 1884:
EXPLAIN VERBOSE
SELECT value1, unhex(hex(str2)) FROM s3 WHERE to_hex(value2) = '64';
-- select unhex (stub function, not pushdown constraints, result)
--Testcase 1885:
SELECT value1, unhex(hex(str2)) FROM s3 WHERE to_hex(value2) = '64';

-- select unhex (stub function, pushdown constraints, explain)
--Testcase 1886:
EXPLAIN VERBOSE
SELECT value1, unhex(hex(str2)) FROM s3 WHERE value2 != 200;
-- select unhex (stub function, pushdown constraints, result)
--Testcase 1887:
SELECT value1, unhex(hex(str2)) FROM s3 WHERE value2 != 200;

-- select unhex with non pushdown func and explicit constant (explain)
--Testcase 1888:
EXPLAIN VERBOSE
SELECT unhex(hex(str2)), pi(), 4.1 FROM s3;
-- select unhex with non pushdown func and explicit constant (result)
--Testcase 1889:
SELECT unhex(hex(str2)), pi(), 4.1 FROM s3;

-- select unhex with order by (explain)
--Testcase 1890:
EXPLAIN VERBOSE
SELECT value1, unhex(hex(str2)) FROM s3 ORDER BY value1, unhex(hex(str2));
-- select unhex with order by (result)
--Testcase 1891:
SELECT value1, unhex(hex(str2)) FROM s3 ORDER BY value1, unhex(hex(str2));

-- select unhex with order by index (result)
--Testcase 1892:
SELECT value1, unhex(hex(str2)) FROM s3 ORDER BY 2,1;
-- select unhex with order by index (result)
--Testcase 1893:
SELECT value1, unhex(hex(str2)) FROM s3 ORDER BY 1,2;

-- select unhex with group by (explain)
--Testcase 1894:
EXPLAIN VERBOSE
SELECT count(value1), unhex(hex(str2)) FROM s3 GROUP BY unhex(hex(str2)) ORDER BY 1,2;
-- select unhex with group by (result)
--Testcase 1895:
SELECT count(value1), unhex(hex(str2)) FROM s3 GROUP BY unhex(hex(str2)) ORDER BY 1,2;

-- select unhex with group by index (result)
--Testcase 1896:
SELECT value1, unhex(hex(str2)) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select unhex with group by having (explain)
--Testcase 1897:
EXPLAIN VERBOSE
SELECT count(value1), unhex(hex(str2)) FROM s3 GROUP BY unhex(hex(str2)), str2 HAVING unhex(hex(str2)) IS NOT NULL ORDER BY 1,2;
-- select unhex with group by having (result)
--Testcase 1898:
SELECT count(value1), unhex(hex(str2)) FROM s3 GROUP BY unhex(hex(str2)), str2 HAVING unhex(hex(str2)) IS NOT NULL ORDER BY 1,2;

-- select unhex with group by index having (result)
--Testcase 1899:
SELECT value1, unhex(hex(str2)) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test upper()
--
-- select upper (stub function, explain)
--Testcase 1900:
EXPLAIN VERBOSE
SELECT upper(tag1), upper(str1), upper(str2) FROM s3 ORDER BY 1,2,3;
-- select upper (stub function, result)
--Testcase 1901:
SELECT upper(tag1), upper(str1), upper(str2) FROM s3 ORDER BY 1,2,3;

-- select upper (stub function, not pushdown constraints, explain)
--Testcase 1902:
EXPLAIN VERBOSE
SELECT value1, upper(tag1) FROM s3 WHERE to_hex(value2) = '64';
-- select upper (stub function, not pushdown constraints, result)
--Testcase 1903:
SELECT value1, upper(tag1) FROM s3 WHERE to_hex(value2) = '64';

-- select upper (stub function, pushdown constraints, explain)
--Testcase 1904:
EXPLAIN VERBOSE
SELECT value1, upper(str1) FROM s3 WHERE value2 != 200;
-- select upper (stub function, pushdown constraints, result)
--Testcase 1905:
SELECT value1, upper(str1) FROM s3 WHERE value2 != 200;

-- select upper with non pushdown func and explicit constant (explain)
--Testcase 1906:
EXPLAIN VERBOSE
SELECT upper(str1), pi(), 4.1 FROM s3;
-- select ucase with non pushdown func and explicit constant (result)
--Testcase 1907:
SELECT upper(str1), pi(), 4.1 FROM s3;

-- select upper with order by (explain)
--Testcase 1908:
EXPLAIN VERBOSE
SELECT value1, upper(str1) FROM s3 ORDER BY value1, upper(str1);
-- select upper with order by (result)
--Testcase 1909:
SELECT value1, upper(str1) FROM s3 ORDER BY value1, upper(str1);

-- select upper with order by index (result)
--Testcase 1910:
SELECT value1, upper(str1) FROM s3 ORDER BY 2,1;
-- select upper with order by index (result)
--Testcase 1911:
SELECT value1, upper(str1) FROM s3 ORDER BY 1,2;

-- select upper with group by (explain)
--Testcase 1912:
EXPLAIN VERBOSE
SELECT count(value1), upper(str1) FROM s3 GROUP BY upper(str1) ORDER BY 1,2;
-- select upper with group by (result)
--Testcase 1913:
SELECT count(value1), upper(str1) FROM s3 GROUP BY upper(str1) ORDER BY 1,2;

-- select upper with group by index (result)
--Testcase 1914:
SELECT value1, upper(str1) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select upper with group by having (explain)
--Testcase 1915:
EXPLAIN VERBOSE
SELECT count(value1), upper(str1) FROM s3 GROUP BY upper(str1), tag1 HAVING upper(str1) IS NOT NULL ORDER BY 1,2;
-- select upper with group by having (result)
--Testcase 1916:
SELECT count(value1), upper(str1) FROM s3 GROUP BY upper(str1), tag1 HAVING upper(str1) IS NOT NULL ORDER BY 1,2;

-- select upper with group by index having (result)
--Testcase 1917:
SELECT value1, upper(tag1) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test weight_string()
--
-- select weight_string (stub function, explain)
--Testcase 1918:
EXPLAIN VERBOSE
SELECT weight_string('NULL') FROM s3;
-- select weight_string (stub function, result)
--Testcase 1919:
SELECT weight_string('NULL') FROM s3;

-- select weight_string (stub function, explain)
--Testcase 1920:
EXPLAIN VERBOSE
SELECT weight_string(str1), weight_string(str1, 'CHAR', 3), weight_string(str1, 'BINARY', 5) FROM s3;
-- select weight_string (stub function, result)
--Testcase 1921:
SELECT weight_string(str1), weight_string(str1, 'CHAR', 3), weight_string(str1, 'BINARY', 5) FROM s3;

-- select weight_string (stub function, not pushdown constraints, explain)
--Testcase 1922:
EXPLAIN VERBOSE
SELECT value1, weight_string(str1, 'CHAR', 3) FROM s3 WHERE to_hex(value2) = '64';
-- select weight_string (stub function, not pushdown constraints, result)
--Testcase 1923:
SELECT value1, weight_string(str1, 'CHAR', 3) FROM s3 WHERE to_hex(value2) = '64';

-- select weight_string (stub function, pushdown constraints, explain)
--Testcase 1924:
EXPLAIN VERBOSE
SELECT value1, weight_string(str1, 'BINARY', 5) FROM s3 WHERE value2 != 200;
-- select weight_string (stub function, pushdown constraints, result)
--Testcase 1925:
SELECT value1, weight_string(str1, 'BINARY', 5) FROM s3 WHERE value2 != 200;

-- select weight_string with non pushdown func and explicit constant (explain)
--Testcase 1926:
EXPLAIN VERBOSE
SELECT weight_string(str1, 'BINARY', 5), pi(), 4.1 FROM s3;
-- select weight_string with non pushdown func and explicit constant (result)
--Testcase 1927:
SELECT weight_string(str1, 'BINARY', 5), pi(), 4.1 FROM s3;

-- select weight_string with order by (explain)
--Testcase 1928:
EXPLAIN VERBOSE
SELECT value1, weight_string(str1, 'BINARY', 5) FROM s3 ORDER BY value1, weight_string(str1, 'BINARY', 5);
-- select weight_string with order by (result)
--Testcase 1929:
SELECT value1, weight_string(str1, 'BINARY', 5) FROM s3 ORDER BY value1, weight_string(str1, 'BINARY', 5);

-- select weight_string with order by index (result)
--Testcase 1930:
SELECT value1, weight_string(str1, 'CHAR', 3) FROM s3 ORDER BY 2,1;
-- select weight_string with order by index (result)
--Testcase 1931:
SELECT value1, weight_string(str1, 'CHAR', 3) FROM s3 ORDER BY 1,2;

-- select weight_string with group by (explain)
--Testcase 1932:
EXPLAIN VERBOSE
SELECT count(value1), weight_string(str1, 'CHAR', 3) FROM s3 GROUP BY weight_string(str1, 'CHAR', 3) ORDER BY 1,2;
-- select weight_string with group by (result)
--Testcase 1933:
SELECT count(value1), weight_string(str1, 'CHAR', 3) FROM s3 GROUP BY weight_string(str1, 'CHAR', 3) ORDER BY 1,2;

-- select weight_string with group by index (result)
--Testcase 1934:
SELECT value1, weight_string(str1, 'CHAR', 3) FROM s3 GROUP BY 2,1 ORDER BY 1,2;

-- select weight_string with group by having (explain)
--Testcase 1935:
EXPLAIN VERBOSE
SELECT count(value1), weight_string(str1, 'CHAR', 3) FROM s3 GROUP BY weight_string(str1, 'CHAR', 3), str1 HAVING weight_string(str1, 'CHAR', 3) IS NOT NULL ORDER BY 1,2;
-- select weight_string with group by having (result)
--Testcase 1936:
SELECT count(value1), weight_string(str1, 'CHAR', 3) FROM s3 GROUP BY weight_string(str1, 'CHAR', 3), str1 HAVING weight_string(str1, 'CHAR', 3) IS NOT NULL ORDER BY 1,2;

-- select weight_string with group by index having (result)
--Testcase 1937:
SELECT value1, weight_string(str1, 'CHAR', 3) FROM s3 GROUP BY 1,2 HAVING value1 > 1 ORDER BY 1,2;

--
-- test for date/time function
--

--Testcase 1938:
CREATE FOREIGN TABLE time_tbl (id int, c1 time without time zone, c2 date, c3 timestamp, __spd_url text) SERVER pgspider_core_svr;

--Testcase 1939:
CREATE FOREIGN TABLE time_tbl__pgspider_svr1__0 (id int, c1 time without time zone, c2 date, c3 timestamp, __spd_url text) SERVER pgspider_svr1 OPTIONS (table_name 'time_tbl1mysql');

--Testcase 1940:
CREATE FOREIGN TABLE time_tbl__pgspider_svr2__0 (id int, c1 time without time zone, c2 date, c3 timestamp, __spd_url text) SERVER pgspider_svr2 OPTIONS (table_name 'time_tbl2mysql');

-- ADDDATE()
-- select adddate (stub function, explain)
--Testcase 1941:
EXPLAIN VERBOSE
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl ORDER BY 1,2,3,4;

-- select adddate (stub function, result)
--Testcase 1942:
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl ORDER BY 1,2,3,4;

-- select adddate (stub function, not pushdown constraints, explain)
--Testcase 1943:
EXPLAIN VERBOSE
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select adddate (stub function, not pushdown constraints, result)
--Testcase 1944:
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select adddate (stub function, pushdown constraints, explain)
--Testcase 1945:
EXPLAIN VERBOSE
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select adddate (stub function, pushdown constraints, result)
--Testcase 1946:
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select adddate (stub function, adddate in constraints, explain)
--Testcase 1947:
EXPLAIN VERBOSE
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE adddate(c2, 31) != '2021-01-02' ORDER BY 1,2,3,4;

-- select adddate (stub function, adddate in constraints, result)
--Testcase 1948:
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE adddate(c2, 31) != '2021-01-02' ORDER BY 1,2,3,4;

-- select adddate (stub function, adddate in constraints, explain)
--Testcase 1949:
EXPLAIN VERBOSE
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE adddate('2021-01-02'::date, 31) > '2021-01-02' ORDER BY 1,2,3,4;

-- select adddate (stub function, adddate in constraints, result)
--Testcase 1950:
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE adddate('2021-01-02'::date, 31) > '2021-01-02' ORDER BY 1,2,3,4;

-- select adddate as nest function with agg (pushdown, explain)
--Testcase 1951:
EXPLAIN VERBOSE
SELECT max(id), adddate('2021-01-02'::date, max(id)) FROM time_tbl;

-- select adddate as nest function with agg (pushdown, result)
--Testcase 1952:
SELECT max(id), adddate('2021-01-02'::date, max(id)) FROM time_tbl;

-- select adddate as nest with stub (pushdown, explain)
--Testcase 1953:
EXPLAIN VERBOSE
SELECT adddate(makedate(2019, id), 31) FROM time_tbl ORDER BY 1;

-- select adddate as nest with stub (pushdown, result)
--Testcase 1954:
SELECT adddate(makedate(2019, id), 31) FROM time_tbl ORDER BY 1;

-- select adddate with non pushdown func and explicit constant (explain)
--Testcase 1955:
EXPLAIN VERBOSE
SELECT adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select adddate with non pushdown func and explicit constant (result)
--Testcase 1956:
SELECT adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select adddate with order by (explain)
--Testcase 1957:
EXPLAIN VERBOSE
SELECT id, adddate(c2, id + 5) FROM time_tbl order by id,adddate(c2, id + 5);

-- select adddate with order by (result)
--Testcase 1958:
SELECT id, adddate(c2, id + 5) FROM time_tbl order by id,adddate(c2, id + 5);

-- select adddate with order by index (explain)
--Testcase 1959:
EXPLAIN VERBOSE
SELECT id, adddate(c2, id + 5) FROM time_tbl order by 1,2;

-- select adddate with order by index (result)
--Testcase 1960:
SELECT id, adddate(c2, id + 5) FROM time_tbl order by 1,2;

-- select adddate with group by (explain)
--Testcase 1961:
EXPLAIN VERBOSE
SELECT count(id), adddate(c2, id + 5) FROM time_tbl group by adddate(c2, id + 5) ORDER BY 1,2;

-- select adddate with group by (result)
--Testcase 1962:
SELECT count(id), adddate(c2, id + 5) FROM time_tbl group by adddate(c2, id + 5) ORDER BY 1,2;

-- select adddate with group by index (result)
--Testcase 1963:
SELECT id, adddate(c2, id + 5) FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select adddate with group by index (result)
--Testcase 1964:
SELECT id, adddate(c2, id + 5) FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select adddate with group by having (explain)
--Testcase 1965:
EXPLAIN VERBOSE
SELECT count(id), adddate(c2, id + 5) FROM time_tbl group by adddate(c2, id + 5), id,c2 HAVING adddate(c2, id + 5) > '2000-01-02' ORDER BY 1,2;

-- select adddate with group by having (result)
--Testcase 1966:
SELECT count(id), adddate(c2, id + 5) FROM time_tbl group by adddate(c2, id + 5), id,c2 HAVING adddate(c2, id + 5) > '2000-01-02' ORDER BY 1,2;

-- select adddate with group by index having (result)
--Testcase 1967:
SELECT id, adddate(c2, id + 5), c2 FROM time_tbl group by 3,2,1 HAVING adddate(c2, id + 5) > '2000-01-02' ORDER BY 1,2;

-- select adddate with group by index having (result)
--Testcase 1968:
SELECT id, adddate(c2, id + 5), c2 FROM time_tbl group by 1,2,3 HAVING adddate(c2, id + 5) > '2000-01-02' ORDER BY 1,2;

-- select adddate and as
--Testcase 1969:
SELECT adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes') as adddate1 FROM time_tbl;


-- ADDTIME()
-- select addtime (stub function, explain)
--Testcase 1970:
EXPLAIN VERBOSE
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl ORDER BY 1,2,3,4;

-- select addtime (stub function, result)
--Testcase 1971:
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl ORDER BY 1,2,3,4;

-- select addtime (stub function, not pushdown constraints, explain)
--Testcase 1972:
EXPLAIN VERBOSE
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select addtime (stub function, not pushdown constraints, result)
--Testcase 1973:
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select addtime (stub function, pushdown constraints, explain)
--Testcase 1974:
EXPLAIN VERBOSE
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select addtime (stub function, pushdown constraints, result)
--Testcase 1975:
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select addtime (stub function, addtime in constraints, explain)
--Testcase 1976:
EXPLAIN VERBOSE
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE addtime(c3, '1 12:59:10') != '2000-01-01' ORDER BY 1,2,3,4;

-- select addtime (stub function, addtime in constraints, result)
--Testcase 1977:
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE addtime(c3, '1 12:59:10') != '2000-01-01' ORDER BY 1,2,3,4;

-- select addtime (stub function, addtime in constraints, explain)
--Testcase 1978:
EXPLAIN VERBOSE
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') > '1' ORDER BY 1,2,3,4;

-- select addtime (stub function, addtime in constraints, result)
--Testcase 1979:
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') > '1' ORDER BY 1,2,3,4;

-- select addtime with agg (pushdown, explain)
--Testcase 1980:
EXPLAIN VERBOSE
SELECT max(c1), addtime('2021-01-02'::date, max(c1)) FROM time_tbl;

-- select addtime as nest function with agg (pushdown, result)
--Testcase 1981:
SELECT max(c1), addtime('2021-01-02'::date, max(c1)) FROM time_tbl;

-- select addtime as nest with stub (pushdown, explain)
--Testcase 1982:
EXPLAIN VERBOSE
SELECT addtime(maketime(12, 15, 30), '1 12:59:10') FROM time_tbl;

-- select addtime as nest with stub (pushdown, result)
--Testcase 1983:
SELECT addtime(maketime(12, 15, 30), '1 12:59:10') FROM time_tbl;

-- select addtime with non pushdown func and explicit constant (explain)
--Testcase 1984:
EXPLAIN VERBOSE
SELECT addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl;

-- select addtime with non pushdown func and explicit constant (result)
--Testcase 1985:
SELECT addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl;

-- select addtime with order by (explain)
--Testcase 1986:
EXPLAIN VERBOSE
SELECT id, addtime(c1, c1 + '1 12:59:10') FROM time_tbl order by id,addtime(c1, c1 + '1 12:59:10');

-- select addtime with order by (result)
--Testcase 1987:
SELECT id, addtime(c1, c1 + '1 12:59:10') FROM time_tbl order by id,addtime(c1, c1 + '1 12:59:10');

-- select addtime with order by index (result)
--Testcase 1988:
SELECT id, addtime(c1, c1 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select addtime with order by index (result)
--Testcase 1989:
SELECT id, addtime(c1, c1 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select addtime with group by (explain)
--Testcase 1990:
EXPLAIN VERBOSE
SELECT count(id), addtime(c1, c1 + '1 12:59:10') FROM time_tbl group by addtime(c1, c1 + '1 12:59:10') ORDER BY 1,2;

-- select addtime with group by (result)
--Testcase 1991:
SELECT count(id), addtime(c1, c1 + '1 12:59:10') FROM time_tbl group by addtime(c1, c1 + '1 12:59:10') ORDER BY 1,2;

-- select addtime with group by index (result)
--Testcase 1992:
SELECT id, addtime(c1, c1 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select addtime with group by index (result)
--Testcase 1993:
SELECT id, addtime(c1, c1 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select addtime with group by having (explain)
--Testcase 1994:
EXPLAIN VERBOSE
SELECT count(id), addtime(c1, c1 + '1 12:59:10') FROM time_tbl group by addtime(c1, c1 + '1 12:59:10'), c1 HAVING addtime(c1, c1 + '1 12:59:10') > '1 12:59:10' ORDER BY 1,2;

-- select addtime with group by having (result)
--Testcase 1995:
SELECT count(id), addtime(c1, c1 + '1 12:59:10') FROM time_tbl group by addtime(c1, c1 + '1 12:59:10'), c1 HAVING addtime(c1, c1 + '1 12:59:10') > '1 12:59:10' ORDER BY 1,2;

-- select addtime and as
--Testcase 1996:
SELECT addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes') as addtime1 FROM time_tbl;


-- CONVERT_TZ
-- select convert_tz (stub function, explain)
--Testcase 1997:
EXPLAIN VERBOSE
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl ORDER BY 1,2,3,4;

-- select convert_tz (stub function, result)
--Testcase 1998:
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl ORDER BY 1,2,3,4;

-- select convert_tz (stub function, not pushdown constraints, explain)
--Testcase 1999:
EXPLAIN VERBOSE
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select convert_tz (stub function, not pushdown constraints, result)
--Testcase 2000:
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select convert_tz (stub function, pushdown constraints, explain)
--Testcase 2001:
EXPLAIN VERBOSE
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select convert_tz (stub function, pushdown constraints, result)
--Testcase 2002:
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select convert_tz (stub function, convert_tz in constraints, explain)
--Testcase 2003:
EXPLAIN VERBOSE
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE convert_tz(c3,'+00:00','+10:00') != '2000-01-01' ORDER BY 1,2,3,4;

-- select convert_tz (stub function, convert_tz in constraints, result)
--Testcase 2004:
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE convert_tz(c3,'+00:00','+10:00') != '2000-01-01' ORDER BY 1,2,3,4;

-- select convert_tz (stub function, convert_tz in constraints, explain)
--Testcase 2005:
EXPLAIN VERBOSE
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE convert_tz('2021-01-01 12:00:00','+00:00','+10:00') > '2000-01-01' ORDER BY 1,2,3,4;

-- select convert_tz (stub function, convert_tz in constraints, result)
--Testcase 2006:
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE convert_tz('2021-01-01 12:00:00','+00:00','+10:00') > '2000-01-01' ORDER BY 1,2,3,4;

-- select convert_tz with agg (pushdown, explain)
--Testcase 2007:
EXPLAIN VERBOSE
SELECT max(c3), convert_tz(max(c3), '+00:00','+10:00') FROM time_tbl;

-- select convert_tz as nest function with agg (pushdown, result)
--Testcase 2008:
SELECT max(c3), convert_tz(max(c3), '+00:00','+10:00') FROM time_tbl;

-- select convert_tz with non pushdown func and explicit constant (explain)
--Testcase 2009:
EXPLAIN VERBOSE
SELECT convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select convert_tz with non pushdown func and explicit constant (result)
--Testcase 2010:
SELECT convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select convert_tz with order by (explain)
--Testcase 2011:
EXPLAIN VERBOSE
SELECT id, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl order by id,convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00');

-- select convert_tz with order by (result)
--Testcase 2012:
SELECT id, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl order by id,convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00');

-- select convert_tz with order by index (result)
--Testcase 2013:
SELECT id, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl order by 2,1;

-- select convert_tz with order by index (result)
--Testcase 2014:
SELECT id, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl order by 1,2;

-- select convert_tz with group by (explain)
--Testcase 2015:
EXPLAIN VERBOSE
SELECT count(id), convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') ORDER BY 1,2;

-- select convert_tz with group by (result)
--Testcase 2016:
SELECT count(id), convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') ORDER BY 1,2;

-- select convert_tz with group by index (result)
--Testcase 2017:
SELECT id, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by 2,1;

-- select convert_tz with group by index (result)
--Testcase 2018:
SELECT id, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by 1,2;

-- select convert_tz with group by having (explain)
--Testcase 2019:
EXPLAIN VERBOSE
SELECT count(id), convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00'),id,c3 HAVING convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') > '2000-01-01 12:59:10' ORDER BY 1,2;

-- select convert_tz with group by having (result)
--Testcase 2020:
SELECT count(id), convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00'),id,c3 HAVING convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') > '2000-01-01 12:59:10' ORDER BY 1,2;

-- select convert_tz with group by index having (result)
--Testcase 2021:
SELECT id, c3, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by 3,2,1 HAVING convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') > '2000-01-01 12:59:10' ORDER BY 1,2;

-- select convert_tz and as
--Testcase 2022:
SELECT convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET') as convert_tz1 FROM time_tbl ORDER BY 1;

-- CURDATE()
-- curdate is mutable function, some executes will return different result
-- select curdate (stub function, explain)
--Testcase 2023:
EXPLAIN VERBOSE
SELECT curdate() FROM time_tbl;

-- select curdate (stub function, not pushdown constraints, explain)
--Testcase 2024:
EXPLAIN VERBOSE
SELECT curdate() FROM time_tbl WHERE to_hex(id) > '0';

-- select curdate (stub function, pushdown constraints, explain)
--Testcase 2025:
EXPLAIN VERBOSE
SELECT curdate() FROM time_tbl WHERE id = 1;

-- select curdate (stub function, curdate in constraints, explain)
--Testcase 2026:
EXPLAIN VERBOSE
SELECT curdate() FROM time_tbl WHERE curdate() > '2000-01-01';

-- curdate in constrains (stub function, explain)
--Testcase 2027:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE curdate() > '2000-01-01' ORDER BY 1;

-- curdate in constrains (stub function, result)
--Testcase 2028:
SELECT c1 FROM time_tbl WHERE curdate() > '2000-01-01' ORDER BY 1;

-- curdate as parameter of adddate(stub function, explain)
--Testcase 2029:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE adddate(curdate(), 31) > '2000-01-01' ORDER BY 1;

-- curdate as parameter of adddate(stub function, result)
--Testcase 2030:
SELECT c1 FROM time_tbl WHERE adddate(curdate(), 31) > '2000-01-01' ORDER BY 1;

-- select curdate and agg (pushdown, explain)
--Testcase 2031:
EXPLAIN VERBOSE
SELECT curdate(), sum(id) FROM time_tbl ORDER BY 1,2;

-- select curdate and log2 (pushdown, explain)
--Testcase 2032:
EXPLAIN VERBOSE
SELECT curdate(), log2(id) FROM time_tbl ORDER BY 1,2;

-- select curdate with non pushdown func and explicit constant (explain)
--Testcase 2033:
EXPLAIN VERBOSE
SELECT curdate(), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select curdate with order by (explain)
--Testcase 2034:
EXPLAIN VERBOSE
SELECT curdate(), c1 FROM time_tbl ORDER BY c1;

-- select curdate with order by index (explain)
--Testcase 2035:
EXPLAIN VERBOSE
SELECT curdate(), c1 FROM time_tbl ORDER BY 2;

-- curdate constraints with order by (explain)
--Testcase 2036:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE adddate(curdate(), 31) > '2000-01-01' ORDER BY c1;

-- curdate constraints with order by (result)
--Testcase 2037:
SELECT c1 FROM time_tbl WHERE adddate(curdate(), 31) > '2000-01-01' ORDER BY c1;

-- select curdate with group by (explain)
--Testcase 2038:
EXPLAIN VERBOSE
SELECT curdate(), c1 FROM time_tbl GROUP BY c1 ORDER BY 1,2;

-- select curdate with group by index (explain)
--Testcase 2039:
EXPLAIN VERBOSE
SELECT curdate(), c1 FROM time_tbl GROUP BY 2 ORDER BY 1,2;

-- select curdate with group by having (explain)
--Testcase 2040:
EXPLAIN VERBOSE
SELECT curdate(), c1 FROM time_tbl GROUP BY curdate(),c1 HAVING curdate() > '2000-01-01' ORDER BY 1,2;

-- select curdate with group by index having (explain)
--Testcase 2041:
EXPLAIN VERBOSE
SELECT curdate(), c1 FROM time_tbl GROUP BY 1,2 HAVING curdate() > '2000-01-01' ORDER BY 1,2;

-- curdate constraints with group by (explain)
--Testcase 2042:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE adddate(curdate(), 31) > '2000-01-01' GROUP BY c1 ORDER BY 1;

-- curdate constraints with group by (result)
--Testcase 2043:
SELECT c1 FROM time_tbl WHERE adddate(curdate(), 31) > '2000-01-01' GROUP BY c1 ORDER BY 1;

-- select curdate and as
--Testcase 2044:
EXPLAIN VERBOSE
SELECT curdate() as curdate1 FROM time_tbl ORDER BY 1;

-- CURRENT_DATE()
-- mysql_current_date is mutable function, some executes will return different result
-- select mysql_current_date (stub function, explain)
--Testcase 2045:
EXPLAIN VERBOSE
SELECT mysql_current_date() FROM time_tbl;

-- select mysql_current_date (stub function, not pushdown constraints, explain)
--Testcase 2046:
EXPLAIN VERBOSE
SELECT mysql_current_date() FROM time_tbl WHERE to_hex(id) > '0';

-- select mysql_current_date (stub function, pushdown constraints, explain)
--Testcase 2047:
EXPLAIN VERBOSE
SELECT mysql_current_date() FROM time_tbl WHERE id = 1;

-- select mysql_current_date (stub function, mysql_current_date in constraints, explain)
--Testcase 2048:
EXPLAIN VERBOSE
SELECT mysql_current_date() FROM time_tbl WHERE mysql_current_date() > '2000-01-01';

-- mysql_current_date in constrains (stub function, explain)
--Testcase 2049:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE mysql_current_date() > '2000-01-01' ORDER BY 1;

-- mysql_current_date in constrains (stub function, result)
--Testcase 2050:
SELECT c1 FROM time_tbl WHERE mysql_current_date() > '2000-01-01' ORDER BY 1;

-- mysql_current_date as parameter of adddate(stub function, explain)
--Testcase 2051:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE adddate(mysql_current_date(), 31) > '2000-01-01' ORDER BY 1;

-- mysql_current_date as parameter of adddate(stub function, result)
--Testcase 2052:
SELECT c1 FROM time_tbl WHERE adddate(mysql_current_date(), 31) > '2000-01-01' ORDER BY 1;

-- select mysql_current_date and agg (pushdown, explain)
--Testcase 2053:
EXPLAIN VERBOSE
SELECT mysql_current_date(), sum(id) FROM time_tbl ORDER BY 1,2;

-- select mysql_current_date and log2 (pushdown, explain)
--Testcase 2054:
EXPLAIN VERBOSE
SELECT mysql_current_date(), log2(id) FROM time_tbl ORDER BY 1,2;

-- select mysql_current_date with non pushdown func and explicit constant (explain)
--Testcase 2055:
EXPLAIN VERBOSE
SELECT mysql_current_date(), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select mysql_current_date with order by (explain)
--Testcase 2056:
EXPLAIN VERBOSE
SELECT mysql_current_date(), c1 FROM time_tbl ORDER BY c1;

-- select mysql_current_date with order by index (explain)
--Testcase 2057:
EXPLAIN VERBOSE
SELECT mysql_current_date(), c1 FROM time_tbl ORDER BY 2;

-- mysql_current_date constraints with order by (explain)
--Testcase 2058:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE adddate(mysql_current_date(), 31) > '2000-01-01' ORDER BY c1;

-- mysql_current_date constraints with order by (result)
--Testcase 2059:
SELECT c1 FROM time_tbl WHERE adddate(mysql_current_date(), 31) > '2000-01-01' ORDER BY c1;

-- select mysql_current_date with group by (explain)
--Testcase 2060:
EXPLAIN VERBOSE
SELECT mysql_current_date(), c1 FROM time_tbl GROUP BY c1;

-- select mysql_current_date with group by index (explain)
--Testcase 2061:
EXPLAIN VERBOSE
SELECT mysql_current_date(), c1 FROM time_tbl GROUP BY 2;

-- select mysql_current_date with group by having (explain)
--Testcase 2062:
EXPLAIN VERBOSE
SELECT mysql_current_date(), c1 FROM time_tbl GROUP BY mysql_current_date(), c1 HAVING mysql_current_date() > '2000-01-01';

-- select mysql_current_date with group by index having (explain)
--Testcase 2063:
EXPLAIN VERBOSE
SELECT mysql_current_date(), c1 FROM time_tbl GROUP BY 2,1 HAVING mysql_current_date() > '2000-01-01';

-- mysql_current_date constraints with group by (explain)
--Testcase 2064:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE adddate(mysql_current_date(), 31) > '2000-01-01' GROUP BY c1 ORDER BY 1;

-- mysql_current_date constraints with group by (result)
--Testcase 2065:
SELECT c1 FROM time_tbl WHERE adddate(mysql_current_date(), 31) > '2000-01-01' GROUP BY c1 ORDER BY 1;

-- select mysql_current_date and as
--Testcase 2066:
EXPLAIN VERBOSE
SELECT mysql_current_date() as mysql_current_date1 FROM time_tbl;


-- CURTIME()
-- curtime is mutable function, some executes will return different result
-- select curtime (stub function, explain)
--Testcase 2067:
EXPLAIN VERBOSE
SELECT curtime() FROM time_tbl;

-- select curtime (stub function, not pushdown constraints, explain)
--Testcase 2068:
EXPLAIN VERBOSE
SELECT curtime() FROM time_tbl WHERE to_hex(id) > '0';

-- select curtime (stub function, pushdown constraints, explain)
--Testcase 2069:
EXPLAIN VERBOSE
SELECT curtime() FROM time_tbl WHERE id = 1;

-- select curtime (stub function, curtime in constraints, explain)
--Testcase 2070:
EXPLAIN VERBOSE
SELECT curtime() FROM time_tbl WHERE curtime() > '00:00:00';

-- curtime in constrains (stub function, explain)
--Testcase 2071:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE curtime() > '00:00:00' ORDER BY 1;

-- curtime in constrains (stub function, result)
--Testcase 2072:
SELECT c1 FROM time_tbl WHERE curtime() > '00:00:00' ORDER BY 1;

-- curtime as parameter of addtime(stub function, explain)
--Testcase 2073:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(curtime(), '1 12:59:10') > '00:00:00' ORDER BY 1;

-- curtime as parameter of addtime(stub function, result)
--Testcase 2074:
SELECT c1 FROM time_tbl WHERE addtime(curtime(), '1 12:59:10') > '00:00:00' ORDER BY 1;

-- select curtime and agg (pushdown, explain)
--Testcase 2075:
EXPLAIN VERBOSE
SELECT curtime(), sum(id) FROM time_tbl ORDER BY 1,2;

-- select curtime and log2 (pushdown, explain)
--Testcase 2076:
EXPLAIN VERBOSE
SELECT curtime(), log2(id) FROM time_tbl ORDER BY 1,2;

-- select curtime with non pushdown func and explicit constant (explain)
--Testcase 2077:
EXPLAIN VERBOSE
SELECT curtime(), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select curtime with order by (explain)
--Testcase 2078:
EXPLAIN VERBOSE
SELECT curtime(), c1 FROM time_tbl ORDER BY c1;

-- select curtime with order by index (explain)
--Testcase 2079:
EXPLAIN VERBOSE
SELECT curtime(), c1 FROM time_tbl ORDER BY 2;

-- curtime constraints with order by (explain)
--Testcase 2080:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(curtime(), '1 12:59:10') > '00:00:00' ORDER BY c1;

-- curtime constraints with order by (result)
--Testcase 2081:
SELECT c1 FROM time_tbl WHERE addtime(curtime(), '1 12:59:10') > '00:00:00' ORDER BY c1;

-- select curtime with group by (explain)
--Testcase 2082:
EXPLAIN VERBOSE
SELECT curtime(), c1 FROM time_tbl GROUP BY c1 ORDER BY 1;

-- select curtime with group by index (explain)
--Testcase 2083:
EXPLAIN VERBOSE
SELECT curtime(), c1 FROM time_tbl GROUP BY 2 ORDER BY 1;

-- select curtime with group by having (explain)
--Testcase 2084:
EXPLAIN VERBOSE
SELECT curtime(), c1 FROM time_tbl GROUP BY curtime(),c1 HAVING curtime() > '00:00:00';

-- select curtime with group by index having (explain)
--Testcase 2085:
EXPLAIN VERBOSE
SELECT curtime(), c1 FROM time_tbl GROUP BY 2,1 HAVING curtime() > '00:00:00' ORDER BY 1,2;

-- curtime constraints with group by (explain)
--Testcase 2086:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(curtime(), '1 12:59:10') > '00:00:00' GROUP BY c1 ORDER BY 1;

-- curtime constraints with group by (result)
--Testcase 2087:
SELECT c1 FROM time_tbl WHERE addtime(curtime(), '1 12:59:10') > '00:00:00' GROUP BY c1 ORDER BY 1;

-- select curtime and as
--Testcase 2088:
EXPLAIN VERBOSE
SELECT curtime() as curtime1 FROM time_tbl ORDER BY 1;


-- CURRENT_TIME()
-- mysql_current_time is mutable function, some executes will return different result
-- select mysql_current_time (stub function, explain)
--Testcase 2089:
EXPLAIN VERBOSE
SELECT mysql_current_time() FROM time_tbl;

-- select mysql_current_time (stub function, not pushdown constraints, explain)
--Testcase 2090:
EXPLAIN VERBOSE
SELECT mysql_current_time() FROM time_tbl WHERE to_hex(id) > '0';

-- select mysql_current_time (stub function, pushdown constraints, explain)
--Testcase 2091:
EXPLAIN VERBOSE
SELECT mysql_current_time() FROM time_tbl WHERE id = 1;

-- select mysql_current_time (stub function, mysql_current_time in constraints, explain)
--Testcase 2092:
EXPLAIN VERBOSE
SELECT mysql_current_time() FROM time_tbl WHERE mysql_current_time() > '00:00:00';

-- mysql_current_time in constrains (stub function, explain)
--Testcase 2093:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE mysql_current_time() > '00:00:00' ORDER BY 1;

-- mysql_current_time in constrains (stub function, result)
--Testcase 2094:
SELECT c1 FROM time_tbl WHERE mysql_current_time() > '00:00:00' ORDER BY 1;

-- mysql_current_time as parameter of addtime(stub function, explain)
--Testcase 2095:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_time(), '1 12:59:10') > '00:00:00' ORDER BY 1;

-- mysql_current_time as parameter of addtime(stub function, result)
--Testcase 2096:
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_time(), '1 12:59:10') > '00:00:00' ORDER BY 1;

-- select mysql_current_time and agg (pushdown, explain)
--Testcase 2097:
EXPLAIN VERBOSE
SELECT mysql_current_time(), sum(id) FROM time_tbl ORDER BY 1,2;

-- select mysql_current_time and log2 (pushdown, explain)
--Testcase 2098:
EXPLAIN VERBOSE
SELECT mysql_current_time(), log2(id) FROM time_tbl ORDER BY 1,2;

-- select mysql_current_time with non pushdown func and explicit constant (explain)
--Testcase 2099:
EXPLAIN VERBOSE
SELECT mysql_current_time(), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select mysql_current_time with order by (explain)
--Testcase 2100:
EXPLAIN VERBOSE
SELECT mysql_current_time(), c1 FROM time_tbl ORDER BY c1;

-- select mysql_current_time with order by index (explain)
--Testcase 2101:
EXPLAIN VERBOSE
SELECT mysql_current_time(), c1 FROM time_tbl ORDER BY 2;

-- mysql_current_time constraints with order by (explain)
--Testcase 2102:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_time(), '1 12:59:10') > '00:00:00' ORDER BY c1;

-- mysql_current_time constraints with order by (result)
--Testcase 2103:
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_time(), '1 12:59:10') > '00:00:00' ORDER BY c1;

-- select mysql_current_time with group by (explain)
--Testcase 2104:
EXPLAIN VERBOSE
SELECT mysql_current_time(), c1 FROM time_tbl GROUP BY c1 ORDER BY 1,2;

-- select mysql_current_time with group by index (explain)
--Testcase 2105:
EXPLAIN VERBOSE
SELECT mysql_current_time(), c1 FROM time_tbl GROUP BY 2 ORDER BY 1,2;

-- select mysql_current_time with group by having (explain)
--Testcase 2106:
EXPLAIN VERBOSE
SELECT mysql_current_time(), c1 FROM time_tbl GROUP BY mysql_current_time(),c1 HAVING mysql_current_time() > '00:00:00' ORDER BY 1,2;

-- select mysql_current_time with group by index having (explain)
--Testcase 2107:
EXPLAIN VERBOSE
SELECT mysql_current_time(), c1 FROM time_tbl GROUP BY 2,1 HAVING mysql_current_time() > '00:00:00' ORDER BY 1,2;

-- mysql_current_time constraints with group by (explain)
--Testcase 2108:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_time(), '1 12:59:10') > '00:00:00' GROUP BY c1 ORDER BY 1;

-- mysql_current_time constraints with group by (result)
--Testcase 2109:
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_time(), '1 12:59:10') > '00:00:00' GROUP BY c1 ORDER BY 1;

-- select mysql_current_time and as
--Testcase 2110:
EXPLAIN VERBOSE
SELECT mysql_current_time() as mysql_current_time1 FROM time_tbl;


-- CURRENT_TIMESTAMP
-- mysql_current_timestamp is mutable function, some executes will return different result
-- select mysql_current_timestamp (stub function, explain)
--Testcase 2111:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp() FROM time_tbl;

-- select mysql_current_timestamp (stub function, not pushdown constraints, explain)
--Testcase 2112:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp() FROM time_tbl WHERE to_hex(id) > '0';

-- select mysql_current_timestamp (stub function, pushdown constraints, explain)
--Testcase 2113:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp() FROM time_tbl WHERE id = 1;

-- select mysql_current_timestamp (stub function, mysql_current_timestamp in constraints, explain)
--Testcase 2114:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp() FROM time_tbl WHERE mysql_current_timestamp() > '2000-01-01 00:00:00'::timestamp;

-- mysql_current_timestamp in constrains (stub function, explain)
--Testcase 2115:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE mysql_current_timestamp() > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- mysql_current_timestamp in constrains (stub function, result)
--Testcase 2116:
SELECT c1 FROM time_tbl WHERE mysql_current_timestamp() > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- mysql_current_timestamp as parameter of addtime(stub function, explain)
--Testcase 2117:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_timestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- mysql_current_timestamp as parameter of addtime(stub function, result)
--Testcase 2118:
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_timestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- select mysql_current_timestamp and agg (pushdown, explain)
--Testcase 2119:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), sum(id) FROM time_tbl ORDER BY 1,2;

-- select mysql_current_timestamp and log2 (pushdown, explain)
--Testcase 2120:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), log2(id) FROM time_tbl ORDER BY 1,2;

-- select mysql_current_timestamp with non pushdown func and explicit constant (explain)
--Testcase 2121:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select mysql_current_timestamp with order by (explain)
--Testcase 2122:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), c1 FROM time_tbl ORDER BY mysql_current_timestamp(),c1;

-- select mysql_current_timestamp with order by index (explain)
--Testcase 2123:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), c1 FROM time_tbl ORDER BY 1,2;

-- mysql_current_timestamp constraints with order by (explain)
--Testcase 2124:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_timestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- mysql_current_timestamp constraints with order by (result)
--Testcase 2125:
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_timestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- select mysql_current_timestamp with group by (explain)
--Testcase 2126:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), c1 FROM time_tbl GROUP BY c1 ORDER BY 1,2;

-- select mysql_current_timestamp with group by index (explain)
--Testcase 2127:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), c1 FROM time_tbl GROUP BY 2 ORDER BY 1,2;

-- select mysql_current_timestamp with group by having (explain)
--Testcase 2128:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), c1 FROM time_tbl GROUP BY mysql_current_timestamp(),c1 HAVING mysql_current_timestamp() > '2000-01-01 00:00:00'::timestamp ORDER BY 1,2;

-- select mysql_current_timestamp with group by index having (explain)
--Testcase 2129:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), c1 FROM time_tbl GROUP BY 2,1 HAVING mysql_current_timestamp() > '2000-01-01 00:00:00'::timestamp ORDER BY 1,2;

-- mysql_current_timestamp constraints with group by (explain)
--Testcase 2130:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_timestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1 ORDER BY 1;

-- mysql_current_timestamp constraints with group by (result)
--Testcase 2131:
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_timestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1 ORDER BY 1;

-- select mysql_current_timestamp and as
--Testcase 2132:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp() as mysql_current_timestamp1 FROM time_tbl ORDER BY 1;


-- DATE()
-- select date (stub function, explain)
--Testcase 2133:
EXPLAIN VERBOSE
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl ORDER BY 1,2,3,4;

-- select date (stub function, result)
--Testcase 2134:
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl ORDER BY 1,2,3,4;

-- select date (stub function, not pushdown constraints, explain)
--Testcase 2135:
EXPLAIN VERBOSE
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select date (stub function, not pushdown constraints, result)
--Testcase 2136:
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select date (stub function, pushdown constraints, explain)
--Testcase 2137:
EXPLAIN VERBOSE
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select date (stub function, pushdown constraints, result)
--Testcase 2138:
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select date (stub function, date in constraints, explain)
--Testcase 2139:
EXPLAIN VERBOSE
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE date(c3) != '2000-01-01' ORDER BY 1,2,3,4;

-- select date (stub function, date in constraints, result)
--Testcase 2140:
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE date(c3) != '2000-01-01' ORDER BY 1,2,3,4;

-- select date (stub function, date in constraints, explain)
--Testcase 2141:
EXPLAIN VERBOSE
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE date('2021-01-01 12:00:00') > '2000-01-01' ORDER BY 1,2,3,4;

-- select date (stub function, date in constraints, result)
--Testcase 2142:
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE date('2021-01-01 12:00:00') > '2000-01-01' ORDER BY 1,2,3,4;

-- select date with agg (pushdown, explain)
--Testcase 2143:
EXPLAIN VERBOSE
SELECT max(c3), date(max(c3)) FROM time_tbl;

-- select date as nest function with agg (pushdown, result)
--Testcase 2144:
SELECT max(c3), date(max(c3)) FROM time_tbl;

-- select date with non pushdown func and explicit constant (explain)
--Testcase 2145:
EXPLAIN VERBOSE
SELECT date(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select date with non pushdown func and explicit constant (result)
--Testcase 2146:
SELECT date(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select date with order by (explain)
--Testcase 2147:
EXPLAIN VERBOSE
SELECT id, date(c3 + '1 12:59:10') FROM time_tbl order by id,date(c3 + '1 12:59:10');

-- select date with order by (result)
--Testcase 2148:
SELECT id, date(c3 + '1 12:59:10') FROM time_tbl order by id,date(c3 + '1 12:59:10');

-- select date with order by index (result)
--Testcase 2149:
SELECT id, date(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select date with order by index (result)
--Testcase 2150:
SELECT id, date(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select date with group by (explain)
--Testcase 2151:
EXPLAIN VERBOSE
SELECT max(c3), date(c3 + '1 12:59:10') FROM time_tbl group by date(c3 + '1 12:59:10') ORDER BY 1,2;

-- select date with group by (result)
--Testcase 2152:
SELECT max(c3), date(c3 + '1 12:59:10') FROM time_tbl group by date(c3 + '1 12:59:10') ORDER BY 1,2;

-- select date with group by index (result)
--Testcase 2153:
SELECT id, date(c3 + '1 12:59:10') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select date with group by index (result)
--Testcase 2154:
SELECT id, date(c3 + '1 12:59:10') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select date with group by having (explain)
--Testcase 2155:
EXPLAIN VERBOSE
SELECT max(c3), date(c3 + '1 12:59:10') FROM time_tbl group by date(c3 + '1 12:59:10'), c3 HAVING date(c3) > '2000-01-01' ORDER BY 1,2;

-- select date with group by having (result)
--Testcase 2156:
SELECT max(c3), date(c3 + '1 12:59:10') FROM time_tbl group by date(c3 + '1 12:59:10'), c3 HAVING date(c3) > '2000-01-01' ORDER BY 1,2;

-- select date with group by index having (result)
--Testcase 2157:
SELECT id, date(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING date(c3 + '1 12:59:10') > '2000-01-01' ORDER BY 1,2;

-- select date with group by index having (result)
--Testcase 2158:
SELECT id, date(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING date(c3 + '1 12:59:10') > '2000-01-01' ORDER BY 1,2;

-- select date and as
--Testcase 2159:
SELECT date(date_sub(c3, '1 12:59:10')) as date1 FROM time_tbl ORDER BY 1;


-- DATE_ADD()
-- Postgres also supports date_add with different arguments (data types, number of argument)
-- Only support push down MySQL function (2 arguments, 1st argument has type timestamp without time zone).
-- Therefore, user needs to make sure to pass the 1st argument as timestamp (pass correct type directly or casting).
-- select date_add (stub function, explain)
--Testcase 2160:
EXPLAIN VERBOSE
SELECT date_add(c2::timestamp, '1 12:59:10'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval), date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval) FROM time_tbl ORDER BY 1,2,3,4;

-- select date_add (stub function, result)
--Testcase 2161:
SELECT date_add(c2::timestamp, '1 12:59:10'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval), date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval) FROM time_tbl ORDER BY 1,2,3,4;

-- select date_add (stub function, not pushdown constraints, explain)
--Testcase 2162:
EXPLAIN VERBOSE
SELECT date_add(c2::timestamp, '1 12:59:10'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval), date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select date_add (stub function, not pushdown constraints, result)
--Testcase 2163:
SELECT date_add(c2::timestamp, '1 12:59:10'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval), date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select date_add (stub function, pushdown constraints, explain)
--Testcase 2164:
EXPLAIN VERBOSE
SELECT date_add(c2::timestamp, '1 12:59:10'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval), date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval) FROM time_tbl WHERE id != 1 ORDER BY 1,2,3,4;

-- select date_add (stub function, pushdown constraints, result)
--Testcase 2165:
SELECT date_add(c2::timestamp, '1 12:59:10'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval), date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval) FROM time_tbl WHERE id != 1 ORDER BY 1,2,3,4;

-- select date_add (stub function, date_add in constraints, explain)
--Testcase 2166:
EXPLAIN VERBOSE
SELECT date_add(c2::timestamp, '1 12:59:10'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval), date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval) FROM time_tbl WHERE date_add(c2::timestamp, '1 12:59:10'::interval) != '2000-01-01' ORDER BY 1,2,3,4;

-- select date_add (stub function, date_add in constraints, result)
--Testcase 2167:
SELECT date_add(c2::timestamp, '1 12:59:10'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval), date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval) FROM time_tbl WHERE date_add(c2::timestamp, '1 12:59:10'::interval) != '2000-01-01' ORDER BY 1,2,3,4;

-- select date_add (stub function, date_add in constraints, explain)
--Testcase 2168:
EXPLAIN VERBOSE
SELECT date_add(c2::timestamp, '1 12:59:10'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval), date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval) FROM time_tbl WHERE date_add('2021-01-02'::timestamp, '1-2'::interval) > '2000-01-01' ORDER BY 1,2,3,4;

-- select date_add (stub function, date_add in constraints, result)
--Testcase 2169:
SELECT date_add(c2::timestamp, '1 12:59:10'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval), date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval), date_add('2021-01-02'::timestamp, '1-2'::interval) FROM time_tbl WHERE date_add('2021-01-02'::timestamp, '1-2'::interval) > '2000-01-01' ORDER BY 1,2,3,4;

-- select date_add with agg (pushdown, explain)
--Testcase 2170:
EXPLAIN VERBOSE
SELECT max(c3), date_add(max(c2)::timestamp, '1-2'::interval) FROM time_tbl;

-- select date_add as nest function with agg (pushdown, result)
--Testcase 2171:
SELECT max(c3), date_add(max(c2)::timestamp, '1-2'::interval) FROM time_tbl;

-- select date_add with non pushdown func and explicit constant (explain)
--Testcase 2172:
EXPLAIN VERBOSE
SELECT date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select date_add with non pushdown func and explicit constant (result)
--Testcase 2173:
SELECT date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select date_add with order by (explain)
--Testcase 2174:
EXPLAIN VERBOSE
SELECT id, date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) FROM time_tbl order by id,date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval);

-- select date_add with order by (result)
--Testcase 2175:
SELECT id, date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) FROM time_tbl order by id,date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval);

-- select date_add with order by index (result)
--Testcase 2176:
SELECT id, date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) FROM time_tbl order by 2,1;

-- select date_add with order by index (result)
--Testcase 2177:
SELECT id, date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) FROM time_tbl order by 1,2;

-- select date_add with group by (explain)
--Testcase 2178:
EXPLAIN VERBOSE
SELECT max(c3), date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) FROM time_tbl group by date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) ORDER BY 1;

-- select date_add with group by (result)
--Testcase 2179:
SELECT max(c3), date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) FROM time_tbl group by date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) ORDER BY 1;

-- select date_add with group by index (result)
--Testcase 2180:
SELECT id, date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) FROM time_tbl group by 2,1;

-- select date_add with group by index (result)
--Testcase 2181:
SELECT id, date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) FROM time_tbl group by 1,2;

-- select date_add with group by having (explain)
--Testcase 2182:
EXPLAIN VERBOSE
SELECT max(c3), date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval), c2 FROM time_tbl group by date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval), c3,c2 HAVING date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) > '2000-01-01' ORDER BY 1,2,3;

-- select date_add with group by having (result)
--Testcase 2183:
SELECT max(c3), date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval), c2 FROM time_tbl group by date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval), c3,c2 HAVING date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) > '2000-01-01' ORDER BY 1,2,3;

-- select date_add with group by index having (result)
--Testcase 2184:
SELECT c2, date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval), c3 FROM time_tbl group by 3, 2, 1 HAVING date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) > '2000-01-01' ORDER BY 1,2,3;

-- select date_add with group by index having (result)
--Testcase 2185:
SELECT c2, date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval), c3 FROM time_tbl group by 1, 2, 3 HAVING date_add((c2 + '1 d'::interval)::timestamp, '1-2'::interval) > '2000-01-01' ORDER BY 1,2,3;

-- select date_add and as
--Testcase 2186:
SELECT date_add(date_sub(c3, '1 12:59:10')::timestamp,  '1-2'::interval) as date_add1 FROM time_tbl ORDER BY 1;


-- DATE_FORMAT()
-- select date_format (stub function, explain)
--Testcase 2187:
EXPLAIN VERBOSE
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl ORDER BY 1,2,3,4;

-- select date_format (stub function, result)
--Testcase 2188:
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl ORDER BY 1,2,3,4;

-- select date_format (stub function, not pushdown constraints, explain)
--Testcase 2189:
EXPLAIN VERBOSE
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select date_format (stub function, not pushdown constraints, result)
--Testcase 2190:
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select date_format (stub function, pushdown constraints, explain)
--Testcase 2191:
EXPLAIN VERBOSE
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE id != 1 ORDER BY 1,2,3,4;

-- select date_format (stub function, pushdown constraints, result)
--Testcase 2192:
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE id != 1 ORDER BY 1,2,3,4;

-- select date_format (stub function, date_format in constraints, explain)
--Testcase 2193:
EXPLAIN VERBOSE
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE date_format(c3,'%H %k %I %r %T %S %w') NOT LIKE '2000-01-01' ORDER BY 1,2,3,4;

-- select date_format (stub function, date_format in constraints, result)
--Testcase 2194:
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE date_format(c3,'%H %k %I %r %T %S %w') NOT LIKE '2000-01-01' ORDER BY 1,2,3,4;

-- select date_format (stub function, date_format in constraints, explain)
--Testcase 2195:
EXPLAIN VERBOSE
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') IS NOT NULL ORDER BY 1,2,3,4;

-- select date_format (stub function, date_format in constraints, result)
--Testcase 2196:
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') IS NOT NULL ORDER BY 1,2,3,4;

-- select date_format with agg (pushdown, explain)
--Testcase 2197:
EXPLAIN VERBOSE
SELECT max(c3), date_format(max(c3), '%H %k %I %r %T %S %w') FROM time_tbl;

-- select date_format as nest function with agg (pushdown, result)
--Testcase 2198:
SELECT max(c3), date_format(max(c3), '%H %k %I %r %T %S %w') FROM time_tbl;

-- select date_format with non pushdown func and explicit constant (explain)
--Testcase 2199:
EXPLAIN VERBOSE
SELECT date_format(c2, '%X %V'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select date_format with non pushdown func and explicit constant (result)
--Testcase 2200:
SELECT date_format(c2, '%X %V'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select date_format with order by (explain)
--Testcase 2201:
EXPLAIN VERBOSE
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl order by id,date_format(c3 + '1 12:59:10', '%H:%i:%s');

-- select date_format with order by (result)
--Testcase 2202:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl order by id,date_format(c3 + '1 12:59:10', '%H:%i:%s');

-- select date_format with order by index (result)
--Testcase 2203:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl order by 2,1;

-- select date_format with order by index (result)
--Testcase 2204:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl order by 1,2;

-- select date_format with group by (explain)
--Testcase 2205:
EXPLAIN VERBOSE
SELECT max(c3), date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl group by date_format(c3 + '1 12:59:10', '%H:%i:%s') ORDER BY 1,2;

-- select date_format with group by (result)
--Testcase 2206:
SELECT max(c3), date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl group by date_format(c3 + '1 12:59:10', '%H:%i:%s') ORDER BY 1,2;

-- select date_format with group by index (result)
--Testcase 2207:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl group by 2,1;

-- select date_format with group by index (result)
--Testcase 2208:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl group by 1,2;

-- select date_format with group by having (explain)
--Testcase 2209:
EXPLAIN VERBOSE
SELECT max(c3), date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl group by date_format(c3 + '1 12:59:10', '%H:%i:%s'), c3 HAVING date_format(c3 + '1 12:59:10', '%H:%i:%s') > '2000-01-01' ORDER BY 1,2;

-- select date_format with group by having (result)
--Testcase 2210:
SELECT max(c3), date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl group by date_format(c3 + '1 12:59:10', '%H:%i:%s'), c3 HAVING date_format(c3 + '1 12:59:10', '%H:%i:%s') > '2000-01-01' ORDER BY 1,2;

-- select date_format with group by index having (result)
--Testcase 2211:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s'), c3 FROM time_tbl group by 3, 2, 1 HAVING date_format(c3 + '1 12:59:10', '%H:%i:%s') IS NOT NULL ORDER BY 1,2;

-- select date_format with group by index having (result)
--Testcase 2212:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s'), c3 FROM time_tbl group by 1, 2, 3 HAVING date_format(c3 + '1 12:59:10', '%H:%i:%s') IS NOT NULL ORDER BY 1,2;

-- select date_format and as
--Testcase 2213:
SELECT date_format(c2, '%X %V') as date_format1 FROM time_tbl ORDER BY 1;


-- DATE_SUB()
-- select date_sub (stub function, explain)
--Testcase 2214:
EXPLAIN VERBOSE
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl ORDER BY 1,2,3,4;

-- select date_sub (stub function, result)
--Testcase 2215:
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl ORDER BY 1,2,3,4;

-- select date_sub (stub function, not pushdown constraints, explain)
--Testcase 2216:
EXPLAIN VERBOSE
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select date_sub (stub function, not pushdown constraints, result)
--Testcase 2217:
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select date_sub (stub function, pushdown constraints, explain)
--Testcase 2218:
EXPLAIN VERBOSE
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE id != 1 ORDER BY 1,2,3,4;

-- select date_sub (stub function, pushdown constraints, result)
--Testcase 2219:
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE id != 1 ORDER BY 1,2,3,4;

-- select date_sub (stub function, date_sub in constraints, explain)
--Testcase 2220:
EXPLAIN VERBOSE
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE date_sub(c2, '1 12:59:10') != '2000-01-01' ORDER BY 1,2,3,4;

-- select date_sub (stub function, date_sub in constraints, result)
--Testcase 2221:
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE date_sub(c2, '1 12:59:10') != '2000-01-01' ORDER BY 1,2,3,4;

-- select date_sub (stub function, date_sub in constraints, explain)
--Testcase 2222:
EXPLAIN VERBOSE
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE date_sub('2021-01-01 12:00:00'::timestamp, '1-1') > '2000-01-01' ORDER BY 1,2,3,4;

-- select date_sub (stub function, date_sub in constraints, result)
--Testcase 2223:
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE date_sub('2021-01-01 12:00:00'::timestamp, '1-1') > '2000-01-01' ORDER BY 1,2,3,4;

-- select date_sub with agg (pushdown, explain)
--Testcase 2224:
EXPLAIN VERBOSE
SELECT max(c3), date_sub(max(c3), '1 12:59:10') FROM time_tbl;

-- select date_sub as nest function with agg (pushdown, result)
--Testcase 2225:
SELECT max(c3), date_sub(max(c3), '1 12:59:10') FROM time_tbl;

-- select date_sub with non pushdown func and explicit constant (explain)
--Testcase 2226:
EXPLAIN VERBOSE
SELECT date_sub(date_sub(c3, '1 12:59:10'), '1-1'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select date_sub with non pushdown func and explicit constant (result)
--Testcase 2227:
SELECT date_sub(date_sub(c3, '1 12:59:10'), '1-1'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select date_sub with order by (explain)
--Testcase 2228:
EXPLAIN VERBOSE
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl order by id,date_sub(c3 + '1 12:59:10', '1 12:59:10');

-- select date_sub with order by (result)
--Testcase 2229:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl order by id,date_sub(c3 + '1 12:59:10', '1 12:59:10');

-- select date_sub with order by index (result)
--Testcase 2230:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl order by 2,1;

-- select date_sub with order by index (result)
--Testcase 2231:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl order by 1,2;

-- select date_sub with group by (explain)
--Testcase 2232:
EXPLAIN VERBOSE
SELECT max(c3), date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl group by date_sub(c3 + '1 12:59:10', '1 12:59:10') ORDER BY 1,2;

-- select date_sub with group by (result)
--Testcase 2233:
SELECT max(c3), date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl group by date_sub(c3 + '1 12:59:10', '1 12:59:10') ORDER BY 1,2;

-- select date_sub with group by index (result)
--Testcase 2234:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl group by 2,1;

-- select date_sub with group by index (result)
--Testcase 2235:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl group by 1,2;

-- select date_sub with group by having (explain)
--Testcase 2236:
EXPLAIN VERBOSE
SELECT max(c3), date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl group by date_sub(c3 + '1 12:59:10', '1 12:59:10'), c3 HAVING date_sub(c3 + '1 12:59:10', '1 12:59:10') > '2000-01-01' ORDER BY 1,2;

-- select date_sub with group by having (result)
--Testcase 2237:
SELECT max(c3), date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl group by date_sub(c3 + '1 12:59:10', '1 12:59:10'), c3 HAVING date_sub(c3 + '1 12:59:10', '1 12:59:10') > '2000-01-01' ORDER BY 1,2;

-- select date_sub with group by index having (result)
--Testcase 2238:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING date_sub(c3 + '1 12:59:10', '1 12:59:10') > '2000-01-01' ORDER BY 1,2;

-- select date_sub with group by index having (result)
--Testcase 2239:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING date_sub(c3 + '1 12:59:10', '1 12:59:10') > '2000-01-01' ORDER BY 1,2;

-- select date_sub and as
--Testcase 2240:
SELECT date_sub(date_sub(c3, '1 12:59:10'), '1-1') as date_sub1 FROM time_tbl ORDER BY 1;

-- DATEDIFF()
-- select datediff (stub function, explain)
--Testcase 2241:
EXPLAIN VERBOSE
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl ORDER BY 1,2,3,4;

-- select datediff (stub function, result)
--Testcase 2242:
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl ORDER BY 1,2,3,4;

-- select datediff (stub function, not pushdown constraints, explain)
--Testcase 2243:
EXPLAIN VERBOSE
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select datediff (stub function, not pushdown constraints, result)
--Testcase 2244:
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select datediff (stub function, pushdown constraints, explain)
--Testcase 2245:
EXPLAIN VERBOSE
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select datediff (stub function, pushdown constraints, result)
--Testcase 2246:
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select datediff (stub function, datediff in constraints, explain)
--Testcase 2247:
EXPLAIN VERBOSE
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE datediff(c3, c2) != 0 ORDER BY 1,2,3,4;

-- select datediff (stub function, datediff in constraints, result)
--Testcase 2248:
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE datediff(c3, c2) != 0 ORDER BY 1,2,3,4;

-- select datediff (stub function, datediff in constraints, explain)
--Testcase 2249:
EXPLAIN VERBOSE
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') > 0 ORDER BY 1,2,3,4;

-- select datediff (stub function, datediff in constraints, result)
--Testcase 2250:
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') > 0 ORDER BY 1,2,3,4;

-- select datediff as nest function with agg (pushdown, explain)
--Testcase 2251:
EXPLAIN VERBOSE
SELECT max(c2), datediff('2021-01-02'::date, max(c2)) FROM time_tbl;

-- select datediff as nest function with agg (pushdown, result)
--Testcase 2252:
SELECT max(c2), datediff('2021-01-02'::date, max(c2)) FROM time_tbl;

-- select datediff as nest with stub (pushdown, explain)
--Testcase 2253:
EXPLAIN VERBOSE
SELECT datediff(makedate(2019, id), c2) FROM time_tbl ORDER BY 1;

-- select datediff as nest with stub (pushdown, result)
--Testcase 2254:
SELECT datediff(makedate(2019, id), c2) FROM time_tbl ORDER BY 1;

-- select datediff with non pushdown func and explicit constant (explain)
--Testcase 2255:
EXPLAIN VERBOSE
SELECT datediff(c2, '2007-12-31'::date), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select datediff with non pushdown func and explicit constant (result)
--Testcase 2256:
SELECT datediff(c2, '2007-12-31'::date), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select datediff with order by (explain)
--Testcase 2257:
EXPLAIN VERBOSE
SELECT id, datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl order by id,datediff(c3 + '1 12:59:10', c2 );

-- select datediff with order by (result)
--Testcase 2258:
SELECT id, datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl order by id,datediff(c3 + '1 12:59:10', c2 );

-- select datediff with order by index (result)
--Testcase 2259:
SELECT id, datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl order by 2,1;

-- select datediff with order by index (result)
--Testcase 2260:
SELECT id, datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl order by 1,2;

-- select datediff with group by (explain)
--Testcase 2261:
EXPLAIN VERBOSE
SELECT count(id), datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl group by datediff(c3 + '1 12:59:10', c2 ) ORDER BY 1,2;

-- select datediff with group by (result)
--Testcase 2262:
SELECT count(id), datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl group by datediff(c3 + '1 12:59:10', c2 ) ORDER BY 1,2;

-- select datediff with group by index (result)
--Testcase 2263:
SELECT id, datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl group by 2,1;

-- select datediff with group by index (result)
--Testcase 2264:
SELECT id, datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl group by 1,2;

-- select datediff with group by having (explain)
--Testcase 2265:
EXPLAIN VERBOSE
SELECT count(id), datediff(c3 + '1 12:59:10', c2 ), c2, c3 FROM time_tbl group by datediff(c3 + '1 12:59:10', c2 ), id,c2,c3 HAVING datediff(c3 + '1 12:59:10', c2 ) > 0 ORDER BY 1,2,3,4;

-- select datediff with group by having (result)
--Testcase 2266:
SELECT count(id), datediff(c3 + '1 12:59:10', c2 ), c2, c3 FROM time_tbl group by datediff(c3 + '1 12:59:10', c2 ), id,c2,c3 HAVING datediff(c3 + '1 12:59:10', c2 ) > 0 ORDER BY 1,2,3,4;

-- select datediff with group by index having (result)
--Testcase 2267:
SELECT id, datediff(c3 + '1 12:59:10', c2 ), c2, c3 FROM time_tbl group by 4,3,2,1 HAVING datediff(c3 + '1 12:59:10', c2 ) > 0 ORDER BY 1,2,3,4;

-- select datediff with group by index having (result)
--Testcase 2268:
SELECT id, datediff(c3 + '1 12:59:10', c2 ), c2, c3 FROM time_tbl group by 1,2,3,4 HAVING datediff(c3 + '1 12:59:10', c2 ) > 0 ORDER BY 1,2,3,4;

-- select datediff and as
--Testcase 2269:
SELECT datediff(c2, '2007-12-31'::date) as datediff1 FROM time_tbl ORDER BY 1;

-- YEARWEEK()
-- select yearweek (stub function, explain)
--Testcase 2270:
EXPLAIN VERBOSE
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select yearweek (stub function, result)
--Testcase 2271:
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select yearweek (stub function, not pushdown constraints, explain)
--Testcase 2272:
EXPLAIN VERBOSE
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select yearweek (stub function, not pushdown constraints, result)
--Testcase 2273:
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select yearweek (stub function, pushdown constraints, explain)
--Testcase 2274:
EXPLAIN VERBOSE
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select yearweek (stub function, pushdown constraints, result)
--Testcase 2275:
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select yearweek (stub function, yearweek in constraints, explain)
--Testcase 2276:
EXPLAIN VERBOSE
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE yearweek(c3) != yearweek('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select yearweek (stub function, yearweek in constraints, result)
--Testcase 2277:
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE yearweek(c3) != yearweek('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select yearweek (stub function, yearweek in constraints, explain)
--Testcase 2278:
EXPLAIN VERBOSE
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE yearweek('2021-01-01 12:00:00'::timestamp) > '1' ORDER BY 1,2,3,4;

-- select yearweek (stub function, yearweek in constraints, result)
--Testcase 2279:
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE yearweek('2021-01-01 12:00:00'::timestamp) > '1' ORDER BY 1,2,3,4;

-- select yearweek with agg (pushdown, explain)
--Testcase 2280:
EXPLAIN VERBOSE
SELECT max(c3), yearweek(max(c3)) FROM time_tbl;

-- select yearweek as nest function with agg (pushdown, result)
--Testcase 2281:
SELECT max(c3), yearweek(max(c3)) FROM time_tbl;

-- select yearweek with non pushdown func and explicit constant (explain)
--Testcase 2282:
EXPLAIN VERBOSE
SELECT yearweek(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select yearweek with non pushdown func and explicit constant (result)
--Testcase 2283:
SELECT yearweek(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select yearweek with order by (explain)
--Testcase 2284:
EXPLAIN VERBOSE
SELECT id, yearweek(c3 + '1 12:59:10') FROM time_tbl order by id,yearweek(c3 + '1 12:59:10');

-- select yearweek with order by (result)
--Testcase 2285:
SELECT id, yearweek(c3 + '1 12:59:10') FROM time_tbl order by id,yearweek(c3 + '1 12:59:10');

-- select yearweek with order by index (result)
--Testcase 2286:
SELECT id, yearweek(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select yearweek with order by index (result)
--Testcase 2287:
SELECT id, yearweek(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select yearweek with group by (explain)
--Testcase 2288:
EXPLAIN VERBOSE
SELECT max(c3), yearweek(c3 + '1 12:59:10') FROM time_tbl group by yearweek(c3 + '1 12:59:10') ORDER BY 1,2;

-- select yearweek with group by (result)
--Testcase 2289:
SELECT max(c3), yearweek(c3 + '1 12:59:10') FROM time_tbl group by yearweek(c3 + '1 12:59:10') ORDER BY 1,2;

-- select yearweek with group by index (result)
--Testcase 2290:
SELECT id, yearweek(c3 + '1 12:59:10') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select yearweek with group by index (result)
--Testcase 2291:
SELECT id, yearweek(c3 + '1 12:59:10') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select yearweek with group by having (explain)
--Testcase 2292:
EXPLAIN VERBOSE
SELECT max(c3), yearweek(c3 + '1 12:59:10') FROM time_tbl group by yearweek(c3 + '1 12:59:10'), c3 HAVING yearweek(c3 + '1 12:59:10') > 201010 ORDER BY 1,2;

-- select yearweek with group by having (result)
--Testcase 2293:
SELECT max(c3), yearweek(c3 + '1 12:59:10') FROM time_tbl group by yearweek(c3 + '1 12:59:10'), c3 HAVING yearweek(c3 + '1 12:59:10') > 201010 ORDER BY 1,2;

-- select yearweek with group by index having (result)
--Testcase 2294:
SELECT id, yearweek(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING yearweek(c3 + '1 12:59:10') > 201010 ORDER BY 1,2;

-- select yearweek with group by index having (result)
--Testcase 2295:
SELECT id, yearweek(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING yearweek(c3 + '1 12:59:10') > 201010 ORDER BY 1,2;

-- select yearweek and as
--Testcase 2296:
SELECT yearweek(date_sub(c3, '1 12:59:10')) as yearweek1 FROM time_tbl ORDER BY 1;



-- YEAR()
-- select year (stub function, explain)
--Testcase 2297:
EXPLAIN VERBOSE
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select year (stub function, result)
--Testcase 2298:
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select year (stub function, not pushdown constraints, explain)
--Testcase 2299:
EXPLAIN VERBOSE
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select year (stub function, not pushdown constraints, result)
--Testcase 2300:
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select year (stub function, pushdown constraints, explain)
--Testcase 2301:
EXPLAIN VERBOSE
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select year (stub function, pushdown constraints, result)
--Testcase 2302:
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select year (stub function, year in constraints, explain)
--Testcase 2303:
EXPLAIN VERBOSE
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE year(c3) != year('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select year (stub function, year in constraints, result)
--Testcase 2304:
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE year(c3) != year('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select year (stub function, year in constraints, explain)
--Testcase 2305:
EXPLAIN VERBOSE
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE year('2021-01-01 12:00:00'::timestamp) > '1' ORDER BY 1,2,3,4;

-- select year (stub function, year in constraints, result)
--Testcase 2306:
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE year('2021-01-01 12:00:00'::timestamp) > '1' ORDER BY 1,2,3,4;

-- select year with agg (pushdown, explain)
--Testcase 2307:
EXPLAIN VERBOSE
SELECT max(c3), year(max(c3)) FROM time_tbl;

-- select year as nest function with agg (pushdown, result)
--Testcase 2308:
SELECT max(c3), year(max(c3)) FROM time_tbl;

-- select year with non pushdown func and explicit constant (explain)
--Testcase 2309:
EXPLAIN VERBOSE
SELECT year(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select year with non pushdown func and explicit constant (result)
--Testcase 2310:
SELECT year(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select year with order by (explain)
--Testcase 2311:
EXPLAIN VERBOSE
SELECT id, year(c3 + '1 12:59:10') FROM time_tbl order by id,year(c3 + '1 12:59:10');

-- select year with order by (result)
--Testcase 2312:
SELECT id, year(c3 + '1 12:59:10') FROM time_tbl order by id,year(c3 + '1 12:59:10');

-- select year with order by index (result)
--Testcase 2313:
SELECT id, year(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select year with order by index (result)
--Testcase 2314:
SELECT id, year(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select year with group by (explain)
--Testcase 2315:
EXPLAIN VERBOSE
SELECT max(c3), year(c3 + '1 12:59:10') FROM time_tbl group by year(c3 + '1 12:59:10') ORDER BY 1,2;

-- select year with group by (result)
--Testcase 2316:
SELECT max(c3), year(c3 + '1 12:59:10') FROM time_tbl group by year(c3 + '1 12:59:10') ORDER BY 1,2;

-- select year with group by index (result)
--Testcase 2317:
SELECT id, year(c3 + '1 12:59:10') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select year with group by index (result)
--Testcase 2318:
SELECT id, year(c3 + '1 12:59:10') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select year with group by having (explain)
--Testcase 2319:
EXPLAIN VERBOSE
SELECT max(c3), year(c3 + '1 12:59:10') FROM time_tbl group by year(c3 + '1 12:59:10'), c3 HAVING year(c3 + '1 12:59:10') > 2000 ORDER BY 1,2;

-- select year with group by having (result)
--Testcase 2320:
SELECT max(c3), year(c3 + '1 12:59:10') FROM time_tbl group by year(c3 + '1 12:59:10'), c3 HAVING year(c3 + '1 12:59:10') > 2000 ORDER BY 1,2;

-- select year with group by index having (result)
--Testcase 2321:
SELECT id, year(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING year(c3 + '1 12:59:10') > 2000 ORDER BY 1,2;

-- select year with group by index having (result)
--Testcase 2322:
SELECT id, year(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING year(c3 + '1 12:59:10') > 2000 ORDER BY 1,2;

-- select year and as
--Testcase 2323:
SELECT year(date_sub(c3, '1 12:59:10')) as year1 FROM time_tbl ORDER BY 1;



-- WEEKFORYEAR()
-- select weekofyear (stub function, explain)
--Testcase 2324:
EXPLAIN VERBOSE
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select weekofyear (stub function, result)
--Testcase 2325:
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select weekofyear (stub function, not pushdown constraints, explain)
--Testcase 2326:
EXPLAIN VERBOSE
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select weekofyear (stub function, not pushdown constraints, result)
--Testcase 2327:
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select weekofyear (stub function, pushdown constraints, explain)
--Testcase 2328:
EXPLAIN VERBOSE
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select weekofyear (stub function, pushdown constraints, result)
--Testcase 2329:
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select weekofyear (stub function, weekofyear in constraints, explain)
--Testcase 2330:
EXPLAIN VERBOSE
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekofyear(c3) != weekofyear('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select weekofyear (stub function, weekofyear in constraints, result)
--Testcase 2331:
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekofyear(c3) != weekofyear('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select weekofyear (stub function, weekofyear in constraints, explain)
--Testcase 2332:
EXPLAIN VERBOSE
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekofyear('2021-01-01 12:00:00'::timestamp) > '1' ORDER BY 1,2,3,4;

-- select weekofyear (stub function, weekofyear in constraints, result)
--Testcase 2333:
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekofyear('2021-01-01 12:00:00'::timestamp) > '1' ORDER BY 1,2,3,4;

-- select weekofyear with agg (pushdown, explain)
--Testcase 2334:
EXPLAIN VERBOSE
SELECT max(c3), weekofyear(max(c3)) FROM time_tbl;

-- select weekofyear as nest function with agg (pushdown, result)
--Testcase 2335:
SELECT max(c3), weekofyear(max(c3)) FROM time_tbl;

-- select weekofyear with non pushdown func and explicit constant (explain)
--Testcase 2336:
EXPLAIN VERBOSE
SELECT weekofyear(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select weekofyear with non pushdown func and explicit constant (result)
--Testcase 2337:
SELECT weekofyear(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select weekofyear with order by (explain)
--Testcase 2338:
EXPLAIN VERBOSE
SELECT id, weekofyear(c3 + '1 12:59:10') FROM time_tbl order by id,weekofyear(c3 + '1 12:59:10');

-- select weekofyear with order by (result)
--Testcase 2339:
SELECT id, weekofyear(c3 + '1 12:59:10') FROM time_tbl order by id,weekofyear(c3 + '1 12:59:10');

-- select weekofyear with order by index (result)
--Testcase 2340:
SELECT id, weekofyear(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select weekofyear with order by index (result)
--Testcase 2341:
SELECT id, weekofyear(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select weekofyear with group by (explain)
--Testcase 2342:
EXPLAIN VERBOSE
SELECT max(c3), weekofyear(c3 + '1 12:59:10') FROM time_tbl group by weekofyear(c3 + '1 12:59:10') ORDER BY 1,2;

-- select weekofyear with group by (result)
--Testcase 2343:
SELECT max(c3), weekofyear(c3 + '1 12:59:10') FROM time_tbl group by weekofyear(c3 + '1 12:59:10') ORDER BY 1,2;

-- select weekofyear with group by index (result)
--Testcase 2344:
SELECT id, weekofyear(c3 + '1 12:59:10') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select weekofyear with group by index (result)
--Testcase 2345:
SELECT id, weekofyear(c3 + '1 12:59:10') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select weekofyear with group by having (explain)
--Testcase 2346:
EXPLAIN VERBOSE
SELECT max(c3), weekofyear(c3 + '1 12:59:10') FROM time_tbl group by weekofyear(c3 + '1 12:59:10'), c3 HAVING weekofyear(c3 + '1 12:59:10') > 0 ORDER BY 1,2;

-- select weekofyear with group by having (result)
--Testcase 2347:
SELECT max(c3), weekofyear(c3 + '1 12:59:10') FROM time_tbl group by weekofyear(c3 + '1 12:59:10'), c3 HAVING weekofyear(c3 + '1 12:59:10') > 0 ORDER BY 1,2;

-- select weekofyear with group by index having (result)
--Testcase 2348:
SELECT id, weekofyear(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING weekofyear(c3 + '1 12:59:10') > 0 ORDER BY 1,2,3;

-- select weekofyear with group by index having (result)
--Testcase 2349:
SELECT id, weekofyear(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING weekofyear(c3 + '1 12:59:10') > 0 ORDER BY 1,2,3;

-- select weekofyear and as
--Testcase 2350:
SELECT weekofyear(date_sub(c3, '1 12:59:10')) as weekofyear1 FROM time_tbl ORDER BY 1;


-- WEEKDAY()
-- select weekday (stub function, explain)
--Testcase 2351:
EXPLAIN VERBOSE
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select weekday (stub function, result)
--Testcase 2352:
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select weekday (stub function, not pushdown constraints, explain)
--Testcase 2353:
EXPLAIN VERBOSE
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select weekday (stub function, not pushdown constraints, result)
--Testcase 2354:
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select weekday (stub function, pushdown constraints, explain)
--Testcase 2355:
EXPLAIN VERBOSE
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select weekday (stub function, pushdown constraints, result)
--Testcase 2356:
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select weekday (stub function, weekday in constraints, explain)
--Testcase 2357:
EXPLAIN VERBOSE
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekday(c3) != weekday('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select weekday (stub function, weekday in constraints, result)
--Testcase 2358:
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekday(c3) != weekday('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select weekday (stub function, weekday in constraints, explain)
--Testcase 2359:
EXPLAIN VERBOSE
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekday('2021-01-01 12:00:00'::timestamp) > '1' ORDER BY 1,2,3,4;

-- select weekday (stub function, weekday in constraints, result)
--Testcase 2360:
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekday('2021-01-01 12:00:00'::timestamp) > '1' ORDER BY 1,2,3,4;

-- select weekday with agg (pushdown, explain)
--Testcase 2361:
EXPLAIN VERBOSE
SELECT max(c3), weekday(max(c3)) FROM time_tbl;

-- select weekday as nest function with agg (pushdown, result)
--Testcase 2362:
SELECT max(c3), weekday(max(c3)) FROM time_tbl;

-- select weekday with non pushdown func and explicit constant (explain)
--Testcase 2363:
EXPLAIN VERBOSE
SELECT weekday(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select weekday with non pushdown func and explicit constant (result)
--Testcase 2364:
SELECT weekday(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select weekday with order by (explain)
--Testcase 2365:
EXPLAIN VERBOSE
SELECT id, weekday(c3 + '1 12:59:10') FROM time_tbl order by id,weekday(c3 + '1 12:59:10');

-- select weekday with order by (result)
--Testcase 2366:
SELECT id, weekday(c3 + '1 12:59:10') FROM time_tbl order by id,weekday(c3 + '1 12:59:10');

-- select weekday with order by index (result)
--Testcase 2367:
SELECT id, weekday(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select weekday with order by index (result)
--Testcase 2368:
SELECT id, weekday(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select weekday with group by (explain)
--Testcase 2369:
EXPLAIN VERBOSE
SELECT max(c3), weekday(c3 + '1 12:59:10') FROM time_tbl group by weekday(c3 + '1 12:59:10') ORDER BY 1,2;

-- select weekday with group by (result)
--Testcase 2370:
SELECT max(c3), weekday(c3 + '1 12:59:10') FROM time_tbl group by weekday(c3 + '1 12:59:10') ORDER BY 1,2;

-- select weekday with group by index (result)
--Testcase 2371:
SELECT id, weekday(c3 + '1 12:59:10') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select weekday with group by index (result)
--Testcase 2372:
SELECT id, weekday(c3 + '1 12:59:10') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select weekday with group by having (explain)
--Testcase 2373:
EXPLAIN VERBOSE
SELECT max(c3), weekday(c3 + '1 12:59:10') FROM time_tbl group by weekday(c3 + '1 12:59:10'), c3 HAVING weekday(c3 + '1 12:59:10') > 0 ORDER BY 1,2;

-- select weekday with group by having (result)
--Testcase 2374:
SELECT max(c3), weekday(c3 + '1 12:59:10') FROM time_tbl group by weekday(c3 + '1 12:59:10'), c3 HAVING weekday(c3 + '1 12:59:10') > 0 ORDER BY 1,2;

-- select weekday with group by index having (result)
--Testcase 2375:
SELECT id, weekday(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING weekday(c3 + '1 12:59:10') > 0 ORDER BY 1,2;

-- select weekday with group by index having (result)
--Testcase 2376:
SELECT id, weekday(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING weekday(c3 + '1 12:59:10') > 0 ORDER BY 1,2;

-- select weekday and as
--Testcase 2377:
SELECT weekday(date_sub(c3, '1 12:59:10')) as weekday1 FROM time_tbl ORDER BY 1;



-- WEEK()
-- select week (stub function, explain)
--Testcase 2378:
EXPLAIN VERBOSE
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl ORDER BY 1,2,3,4,5;

-- select week (stub function, result)
--Testcase 2379:
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl ORDER BY 1,2,3,4,5;

-- select week (stub function, not pushdown constraints, explain)
--Testcase 2380:
EXPLAIN VERBOSE
SELECT week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select week (stub function, not pushdown constraints, result)
--Testcase 2381:
SELECT week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select week (stub function, pushdown constraints, explain)
--Testcase 2382:
EXPLAIN VERBOSE
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4,5;

-- select week (stub function, pushdown constraints, result)
--Testcase 2383:
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4,5;

-- select week (stub function, week in constraints, explain)
--Testcase 2384:
EXPLAIN VERBOSE
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE week(c2, 7) != week('2021-01-02'::timestamp, 1) ORDER BY 1,2,3,4,5;

-- select week (stub function, week in constraints, result)
--Testcase 2385:
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE week(c2, 7) != week('2021-01-02'::timestamp, 1) ORDER BY 1,2,3,4,5;

-- select week (stub function, week in constraints, explain)
--Testcase 2386:
EXPLAIN VERBOSE
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE week('2021-01-02'::date, 7) > week('2021-01-02'::timestamp, 1) ORDER BY 1,2,3,4,5;

-- select week (stub function, week in constraints, result)
--Testcase 2387:
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE week('2021-01-02'::date, 7) > week('2021-01-02'::timestamp, 1) ORDER BY 1,2,3,4,5;

-- select week as nest function with agg (pushdown, explain)
--Testcase 2388:
EXPLAIN VERBOSE
SELECT max(id), week('2021-01-02'::date, max(id)) FROM time_tbl;

-- select week as nest function with agg (pushdown, result)
--Testcase 2389:
SELECT max(id), week('2021-01-02'::date, max(id)) FROM time_tbl;

-- select week as nest with stub (pushdown, explain)
--Testcase 2390:
EXPLAIN VERBOSE
SELECT id, week(makedate(2019, id), 7) FROM time_tbl ORDER BY 1,2;

-- select week as nest with stub (pushdown, result)
--Testcase 2391:
SELECT id, week(makedate(2019, id), 7) FROM time_tbl ORDER BY 1,2;

-- select week with non pushdown func and explicit constant (explain)
--Testcase 2392:
EXPLAIN VERBOSE
SELECT week('2021-01-02'::date, 1), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select week with non pushdown func and explicit constant (result)
--Testcase 2393:
SELECT week('2021-01-02'::date, 1), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select week with order by (explain)
--Testcase 2394:
EXPLAIN VERBOSE
SELECT id, week(c2, id + 5) FROM time_tbl order by id,week(c2, id + 5);

-- select week with order by (result)
--Testcase 2395:
SELECT id, week(c2, id + 5) FROM time_tbl order by id,week(c2, id + 5);

-- select week with order by index (result)
--Testcase 2396:
SELECT id, week(c2, id + 5) FROM time_tbl order by 2,1;

-- select week with order by index (result)
--Testcase 2397:
SELECT id, week(c2, id + 5) FROM time_tbl order by 1,2;

-- select week with group by (explain)
--Testcase 2398:
EXPLAIN VERBOSE
SELECT id, week(c2, id + 5) FROM time_tbl group by id, week(c2, id + 5) ORDER BY 1,2;

-- select week with group by (result)
--Testcase 2399:
SELECT id, week(c2, id + 5) FROM time_tbl group by id, week(c2, id + 5) ORDER BY 1,2;

-- select week with group by index (result)
--Testcase 2400:
SELECT id, week(c2, id + 5) FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select week with group by index (result)
--Testcase 2401:
SELECT id, week(c2, id + 5) FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select week with group by having (explain)
--Testcase 2402:
EXPLAIN VERBOSE
SELECT count(id), week(c2, id + 5) FROM time_tbl group by week(c2, id + 5), id,c2 HAVING week(c2, id + 5) = 0 ORDER BY 1,2;

-- select week with group by having (result)
--Testcase 2403:
SELECT count(id), week(c2, id + 5) FROM time_tbl group by week(c2, id + 5), id,c2 HAVING week(c2, id + 5) = 0 ORDER BY 1,2;

-- select week with group by index having (result)
--Testcase 2404:
SELECT id, week(c2, id + 5), c2 FROM time_tbl group by 3,2,1 HAVING week(c2, id + 5) > 0 ORDER BY 1,2;

-- select week with group by index having (result)
--Testcase 2405:
SELECT id, week(c2, id + 5), c2 FROM time_tbl group by 1,2,3 HAVING id > 1 ORDER BY 1,2;

-- select week and as
--Testcase 2406:
SELECT week('2021-01-02'::date, 53) as week1 FROM time_tbl  ORDER BY 1;


-- UTC_TIMESTAMP()
-- select utc_timestamp (stub function, explain)
--Testcase 2407:
EXPLAIN VERBOSE
SELECT utc_timestamp() FROM time_tbl;

-- select utc_timestamp (stub function, not pushdown constraints, explain)
--Testcase 2408:
EXPLAIN VERBOSE
SELECT utc_timestamp() FROM time_tbl WHERE to_hex(id) > '0';

-- select utc_timestamp (stub function, pushdown constraints, explain)
--Testcase 2409:
EXPLAIN VERBOSE
SELECT utc_timestamp() FROM time_tbl WHERE id = 1;

-- select utc_timestamp (stub function, utc_timestamp in constraints, explain)
--Testcase 2410:
EXPLAIN VERBOSE
SELECT utc_timestamp() FROM time_tbl WHERE utc_timestamp() > '1997-10-14 00:00:00'::timestamp;

-- utc_timestamp in constrains (stub function, explain)
--Testcase 2411:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE utc_timestamp() > '1997-10-14 00:00:00'::timestamp ORDER BY 1;

-- utc_timestamp in constrains (stub function, result)
--Testcase 2412:
SELECT c1 FROM time_tbl WHERE utc_timestamp() > '1997-10-14 00:00:00'::timestamp ORDER BY 1;

-- utc_timestamp as parameter of addtime(stub function, explain)
--Testcase 2413:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(utc_timestamp(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY 1;

-- utc_timestamp as parameter of addtime(stub function, result)
--Testcase 2414:
SELECT c1 FROM time_tbl WHERE addtime(utc_timestamp(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY 1;

-- select utc_timestamp and agg (pushdown, explain)
--Testcase 2415:
EXPLAIN VERBOSE
SELECT utc_timestamp(), sum(id) FROM time_tbl ORDER BY 1,2;

-- select utc_timestamp and log2 (pushdown, explain)
--Testcase 2416:
EXPLAIN VERBOSE
SELECT utc_timestamp(), log2(id) FROM time_tbl ORDER BY 1,2;

-- select utc_timestamp with non pushdown func and explicit constant (explain)
--Testcase 2417:
EXPLAIN VERBOSE
SELECT utc_timestamp(), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select utc_timestamp with order by (explain)
--Testcase 2418:
EXPLAIN VERBOSE
SELECT utc_timestamp(), c1 FROM time_tbl ORDER BY c1;

-- select utc_timestamp with order by index (explain)
--Testcase 2419:
EXPLAIN VERBOSE
SELECT utc_timestamp(), c1 FROM time_tbl ORDER BY 2;

-- utc_timestamp constraints with order by (explain)
--Testcase 2420:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(utc_timestamp(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY c1;

-- utc_timestamp constraints with order by (result)
--Testcase 2421:
SELECT c1 FROM time_tbl WHERE addtime(utc_timestamp(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY c1;

-- select utc_timestamp with group by (explain)
--Testcase 2422:
EXPLAIN VERBOSE
SELECT utc_timestamp(), c1 FROM time_tbl GROUP BY c1 ORDER BY 1,2;

-- select utc_timestamp with group by index (explain)
--Testcase 2423:
EXPLAIN VERBOSE
SELECT utc_timestamp(), c1 FROM time_tbl GROUP BY 2 ORDER BY 1,2;

-- select utc_timestamp with group by having (explain)
--Testcase 2424:
EXPLAIN VERBOSE
SELECT utc_timestamp(), c1 FROM time_tbl GROUP BY utc_timestamp(),c1 HAVING utc_timestamp() > '1997-10-14 00:00:00'::timestamp ORDER BY 1,2;

-- select utc_timestamp with group by index having (explain)
--Testcase 2425:
EXPLAIN VERBOSE
SELECT utc_timestamp(), c1 FROM time_tbl GROUP BY 2,1 HAVING utc_timestamp() > '1997-10-14 00:00:00'::timestamp ORDER BY 1,2;

-- utc_timestamp constraints with group by (explain)
--Testcase 2426:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(utc_timestamp(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp GROUP BY c1 ORDER BY 1;

-- utc_timestamp constraints with group by (result)
--Testcase 2427:
SELECT c1 FROM time_tbl WHERE addtime(utc_timestamp(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp GROUP BY c1 ORDER BY 1;

-- select utc_timestamp and as
--Testcase 2428:
EXPLAIN VERBOSE
SELECT utc_timestamp() as utc_timestamp1 FROM time_tbl;



-- UTC_TIME()
-- select utc_time (stub function, explain)
--Testcase 2429:
EXPLAIN VERBOSE
SELECT utc_time() FROM time_tbl;

-- select utc_time (stub function, not pushdown constraints, explain)
--Testcase 2430:
EXPLAIN VERBOSE
SELECT utc_time() FROM time_tbl WHERE to_hex(id) > '0';

-- select utc_time (stub function, pushdown constraints, explain)
--Testcase 2431:
EXPLAIN VERBOSE
SELECT utc_time() FROM time_tbl WHERE id = 1;

-- select utc_time (stub function, utc_time in constraints, explain)
--Testcase 2432:
EXPLAIN VERBOSE
SELECT utc_time() FROM time_tbl WHERE utc_time() > '1997-10-14 00:00:00'::time;

-- utc_time in constrains (stub function, explain)
--Testcase 2433:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE utc_time() > '1997-10-14 00:00:00'::time ORDER BY 1;

-- utc_time in constrains (stub function, result)
--Testcase 2434:
SELECT c1 FROM time_tbl WHERE utc_time() > '1997-10-14 00:00:00'::time ORDER BY 1;

-- utc_time as parameter of second(stub function, explain)
--Testcase 2435:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE second(utc_time()) > 10 ORDER BY 1;

-- utc_time as parameter of second(stub function, result)
--Testcase 2436:
SELECT c1 FROM time_tbl WHERE (60-second(utc_time())) >= 0 ORDER BY c1;

-- select utc_time and agg (pushdown, explain)
--Testcase 2437:
EXPLAIN VERBOSE
SELECT utc_time(), sum(id) FROM time_tbl ORDER BY 1,2;

-- select utc_time and log2 (pushdown, explain)
--Testcase 2438:
EXPLAIN VERBOSE
SELECT utc_time(), log2(id) FROM time_tbl ORDER BY 1,2;

-- select utc_time with non pushdown func and explicit constant (explain)
--Testcase 2439:
EXPLAIN VERBOSE
SELECT utc_time(), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select utc_time with order by (explain)
--Testcase 2440:
EXPLAIN VERBOSE
SELECT utc_time(), c1 FROM time_tbl ORDER BY c1;

-- select utc_time with order by index (explain)
--Testcase 2441:
EXPLAIN VERBOSE
SELECT utc_time(), c1 FROM time_tbl ORDER BY 2;

-- utc_time constraints with order by (explain)
--Testcase 2442:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE second(utc_time()) > 10 ORDER BY c1;

-- utc_time constraints with order by (result)
--Testcase 2443:
SELECT c1 FROM time_tbl WHERE (60-second(utc_time())) >= 0 ORDER BY c1;

-- select utc_time with group by (explain)
--Testcase 2444:
EXPLAIN VERBOSE
SELECT utc_time(), c1 FROM time_tbl GROUP BY c1;

-- select utc_time with group by index (explain)
--Testcase 2445:
EXPLAIN VERBOSE
SELECT utc_time(), c1 FROM time_tbl GROUP BY 2;

-- select utc_time with group by having (explain)
--Testcase 2446:
EXPLAIN VERBOSE
SELECT utc_time(), c1 FROM time_tbl GROUP BY utc_time(),c1 HAVING utc_time() > '1997-10-14 00:00:00'::time ORDER BY 1,2;

-- select utc_time with group by index having (explain)
--Testcase 2447:
EXPLAIN VERBOSE
SELECT utc_time(), c1 FROM time_tbl GROUP BY 2,1 HAVING utc_time() > '1997-10-14 00:00:00'::time ORDER BY 1,2;

-- utc_time constraints with group by (explain)
--Testcase 2448:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE second(utc_time()) > 10 GROUP BY c1 ORDER BY 1;

-- utc_time constraints with group by (result)
--Testcase 2449:
SELECT c1 FROM time_tbl WHERE (60-second(utc_time())) >= 0 GROUP BY c1 ORDER BY 1;

-- select utc_time and as
--Testcase 2450:
EXPLAIN VERBOSE
SELECT utc_time() as utc_time1 FROM time_tbl;



-- UTC_DATE()
-- select utc_date (stub function, explain)
--Testcase 2451:
EXPLAIN VERBOSE
SELECT utc_date() FROM time_tbl;

-- select utc_date (stub function, not pushdown constraints, explain)
--Testcase 2452:
EXPLAIN VERBOSE
SELECT utc_date() FROM time_tbl WHERE to_hex(id) > '0';

-- select utc_date (stub function, pushdown constraints, explain)
--Testcase 2453:
EXPLAIN VERBOSE
SELECT utc_date() FROM time_tbl WHERE id = 1;

-- select utc_date (stub function, utc_date in constraints, explain)
--Testcase 2454:
EXPLAIN VERBOSE
SELECT utc_date() FROM time_tbl WHERE utc_date() > '1997-10-14 00:00:00'::date;

-- utc_date in constrains (stub function, explain)
--Testcase 2455:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE utc_date() > '1997-10-14 00:00:00'::date ORDER BY 1;

-- utc_date in constrains (stub function, result)
--Testcase 2456:
SELECT c1 FROM time_tbl WHERE utc_date() > '1997-10-14 00:00:00'::date ORDER BY 1;

-- utc_date as parameter of addtime(stub function, explain)
--Testcase 2457:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(utc_date(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::date ORDER BY 1;

-- utc_date as parameter of addtime(stub function, result)
--Testcase 2458:
SELECT c1 FROM time_tbl WHERE addtime(utc_date(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::date ORDER BY 1;

-- select utc_date and agg (pushdown, explain)
--Testcase 2459:
EXPLAIN VERBOSE
SELECT utc_date(), sum(id) FROM time_tbl ORDER BY 1,2;

-- select utc_date and log2 (pushdown, explain)
--Testcase 2460:
EXPLAIN VERBOSE
SELECT utc_date(), log2(id) FROM time_tbl ORDER BY 1,2;

-- select utc_date with non pushdown func and explicit constant (explain)
--Testcase 2461:
EXPLAIN VERBOSE
SELECT utc_date(), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select utc_date with order by (explain)
--Testcase 2462:
EXPLAIN VERBOSE
SELECT utc_date(), c1 FROM time_tbl ORDER BY c1;

-- select utc_date with order by index (explain)
--Testcase 2463:
EXPLAIN VERBOSE
SELECT utc_date(), c1 FROM time_tbl ORDER BY 2;

-- utc_date constraints with order by (explain)
--Testcase 2464:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(utc_date(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY c1;

-- utc_date constraints with order by (result)
--Testcase 2465:
SELECT c1 FROM time_tbl WHERE addtime(utc_date(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY c1;

-- select utc_date with group by (explain)
--Testcase 2466:
EXPLAIN VERBOSE
SELECT utc_date(), c1 FROM time_tbl GROUP BY c1 ORDER BY 1,2;

-- select utc_date with group by index (explain)
--Testcase 2467:
EXPLAIN VERBOSE
SELECT utc_date(), c1 FROM time_tbl GROUP BY 2 ORDER BY 1,2;

-- select utc_date with group by having (explain)
--Testcase 2468:
EXPLAIN VERBOSE
SELECT utc_date(), c1 FROM time_tbl GROUP BY utc_date(),c1 HAVING utc_date() > '1997-10-14 00:00:00'::timestamp ORDER BY 1,2;

-- select utc_date with group by index having (explain)
--Testcase 2469:
EXPLAIN VERBOSE
SELECT utc_date(), c1 FROM time_tbl GROUP BY 2,1 HAVING utc_date() > '1997-10-14 00:00:00'::timestamp ORDER BY 1,2;

-- utc_date constraints with group by (explain)
--Testcase 2470:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(utc_date(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp GROUP BY c1 ORDER BY 1;

-- utc_date constraints with group by (result)
--Testcase 2471:
SELECT c1 FROM time_tbl WHERE addtime(utc_date(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp GROUP BY c1 ORDER BY 1;

-- select utc_date and as
--Testcase 2472:
EXPLAIN VERBOSE
SELECT utc_date() as utc_date1 FROM time_tbl;



-- UNIX_TIMESTAMP()
-- select unix_timestamp (stub function, explain)
--Testcase 2473:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2) FROM time_tbl ORDER BY 1,2,3;

-- select unix_timestamp (stub function, not pushdown constraints, explain)
--Testcase 2474:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2) FROM time_tbl WHERE to_hex(id) > '0' ORDER BY 1,2,3;

-- select unix_timestamp (stub function, pushdown constraints, explain)
--Testcase 2475:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2) FROM time_tbl WHERE id = 1 ORDER BY 1,2,3;

-- select unix_timestamp (stub function, unix_timestamp in constraints, explain)
--Testcase 2476:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2) FROM time_tbl WHERE unix_timestamp() > unix_timestamp('1997-10-14 00:00:00'::timestamp) ORDER BY 1,2,3;

-- unix_timestamp in constrains (stub function, explain)
--Testcase 2477:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE unix_timestamp() > unix_timestamp('1997-10-14 00:00:00'::timestamp) ORDER BY 1;

-- unix_timestamp in constrains (stub function, result)
--Testcase 2478:
SELECT c1 FROM time_tbl WHERE unix_timestamp() > unix_timestamp('1997-10-14 00:00:00'::timestamp) ORDER BY 1;

-- select unix_timestamp and agg (pushdown, explain)
--Testcase 2479:
EXPLAIN VERBOSE
SELECT unix_timestamp(), sum(id) FROM time_tbl ORDER BY 1,2;

-- select unix_timestamp and log2 (pushdown, explain)
--Testcase 2480:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2), log2(id) FROM time_tbl ORDER BY 1,2,3,4;

-- select unix_timestamp with non pushdown func and explicit constant (explain)
--Testcase 2481:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2), to_hex(id), 4 FROM time_tbl ORDER BY 1,2,3,4;

-- select unix_timestamp with order by (explain)
--Testcase 2482:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2), c1 FROM time_tbl ORDER BY c1;

-- select unix_timestamp with order by index (explain)
--Testcase 2483:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2), c1 FROM time_tbl ORDER BY 4;

-- select unix_timestamp with group by (explain)
--Testcase 2484:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2), c1 FROM time_tbl GROUP BY c1,c2,c3 ORDER BY 1,2,3,4;

-- select unix_timestamp with group by index (explain)
--Testcase 2485:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2), c1 FROM time_tbl GROUP BY 1,2,3,4 ORDER BY 1,2,3,4;

-- select unix_timestamp with group by having (explain)
--Testcase 2486:
EXPLAIN VERBOSE
SELECT unix_timestamp(), c1 FROM time_tbl GROUP BY unix_timestamp(),c1 HAVING unix_timestamp() > 100000 ORDER BY 1,2;

-- select unix_timestamp with group by index having (explain)
--Testcase 2487:
EXPLAIN VERBOSE
SELECT unix_timestamp(), c1 FROM time_tbl GROUP BY 2,1 HAVING unix_timestamp() > 100000 ORDER BY 1,2;

-- select unix_timestamp and as
--Testcase 2488:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2) as unix_timestamp1 FROM time_tbl ORDER BY 1,2;


-- TO_SECONDS()
-- select to_seconds (stub function, explain)
--Testcase 2489:
EXPLAIN VERBOSE
SELECT to_seconds(id + 200719), to_seconds(c3), to_seconds(c2) FROM time_tbl ORDER BY 1,2,3;

-- select to_seconds (stub function, not pushdown constraints, explain)
--Testcase 2490:
EXPLAIN VERBOSE
SELECT to_seconds(id + 200719), to_seconds(c3), to_seconds(c2) FROM time_tbl WHERE to_hex(id) > '0' ORDER BY 1,2,3;

-- select to_seconds (stub function, pushdown constraints, explain)
--Testcase 2491:
EXPLAIN VERBOSE
SELECT to_seconds(id + 200719), to_seconds(c3), to_seconds(c2) FROM time_tbl WHERE id = 1 ORDER BY 1,2,3;

-- select to_seconds (stub function, to_seconds in constraints, explain)
--Testcase 2492:
EXPLAIN VERBOSE
SELECT to_seconds(id + 200719), to_seconds(c3), to_seconds(c2) FROM time_tbl WHERE to_seconds(id + 200719) > to_seconds('1997-10-14 00:00:00'::timestamp) ORDER BY 1,2,3;

-- to_seconds in constrains (stub function, explain)
--Testcase 2493:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE to_seconds(id + 200719) > to_seconds('1997-10-14 00:00:00'::timestamp) ORDER BY 1;

-- to_seconds in constrains (stub function, result)
--Testcase 2494:
SELECT c1 FROM time_tbl WHERE to_seconds(id + 200719) > to_seconds('1997-10-14 00:00:00'::timestamp) ORDER BY 1;

-- select to_seconds and agg (pushdown, explain)
--Testcase 2495:
EXPLAIN VERBOSE
SELECT to_seconds('1997-10-14 00:00:00'::timestamp), to_seconds('1997-10-14 00:00:00'::date), sum(id) FROM time_tbl ORDER BY 1,2,3;

-- select to_seconds and log2 (pushdown, explain)
--Testcase 2496:
EXPLAIN VERBOSE
SELECT to_seconds('1997-10-14 00:00:00'::timestamp), to_seconds(c3), to_seconds(c2), log2(id) FROM time_tbl ORDER BY 1,2,3;

-- select to_seconds with non pushdown func and explicit constant (explain)
--Testcase 2497:
EXPLAIN VERBOSE
SELECT to_seconds('1997-10-14 00:00:00'::timestamp), to_seconds(c3), to_seconds(c2), to_hex(id), 4 FROM time_tbl ORDER BY 1,2,3,4;

-- select to_seconds with order by (explain)
--Testcase 2498:
EXPLAIN VERBOSE
SELECT to_seconds(id + 200719), to_seconds(c3), to_seconds(c2), c1 FROM time_tbl ORDER BY c1;

-- select to_seconds with order by index (explain)
--Testcase 2499:
EXPLAIN VERBOSE
SELECT to_seconds(id + 200719), to_seconds(c3), to_seconds(c2), c1 FROM time_tbl ORDER BY 4;

-- to_seconds constraints with order by (explain)
--Testcase 2500:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE to_seconds('2020-10-14 00:00:00'::timestamp) > to_seconds('1997-10-14 00:00:00'::timestamp) ORDER BY c1;

-- to_seconds constraints with order by (result)
--Testcase 2501:
SELECT c1 FROM time_tbl WHERE to_seconds('2020-10-14 00:00:00'::timestamp) > to_seconds('1997-10-14 00:00:00'::timestamp) ORDER BY c1;

-- select to_seconds with group by (explain)
--Testcase 2502:
EXPLAIN VERBOSE
SELECT to_seconds(971014), to_seconds(c3), to_seconds(c2), c1 FROM time_tbl GROUP BY c1,c2,c3 ORDER BY 1,2,3,4;

-- select to_seconds with group by index (explain)
--Testcase 2503:
EXPLAIN VERBOSE
SELECT to_seconds(971014), to_seconds(c3), to_seconds(c2), c1 FROM time_tbl GROUP BY 1,2,3,4 ORDER BY 1,2,3,4;

-- select to_seconds with group by having (explain)
--Testcase 2504:
EXPLAIN VERBOSE
SELECT to_seconds(971014), c1 FROM time_tbl GROUP BY to_seconds(971014),c1 HAVING to_seconds(971014) > 100000 ORDER BY 1,2;

-- select to_seconds with group by index having (explain)
--Testcase 2505:
EXPLAIN VERBOSE
SELECT to_seconds(971014), c1 FROM time_tbl GROUP BY 2,1 HAVING to_seconds(971014) > 100000 ORDER BY 1,2;

-- select to_seconds and as
--Testcase 2506:
EXPLAIN VERBOSE
SELECT to_seconds(971014), to_seconds(c3), to_seconds(c2) as to_seconds1 FROM time_tbl ORDER BY 1,2,3;


-- TO_DAYS()
-- select to_days (stub function, explain)
--Testcase 2507:
EXPLAIN VERBOSE
SELECT to_days(id + 200719), to_days(c2) FROM time_tbl ORDER BY 1,2;

-- select to_days (stub function, not pushdown constraints, explain)
--Testcase 2508:
EXPLAIN VERBOSE
SELECT to_days(id + 200719), to_days(c2) FROM time_tbl WHERE to_hex(id) > '0' ORDER BY 1,2;

-- select to_days (stub function, pushdown constraints, explain)
--Testcase 2509:
EXPLAIN VERBOSE
SELECT to_days(id + 200719), to_days(c2) FROM time_tbl WHERE id = 1 ORDER BY 1,2;

-- select to_days (stub function, to_days in constraints, explain)
--Testcase 2510:
EXPLAIN VERBOSE
SELECT to_days(id + 200719), to_days(c2) FROM time_tbl WHERE to_days(id + 200719) > to_days('1997-10-14 00:00:00'::date) ORDER BY 1,2;

-- to_days in constrains (stub function, explain)
--Testcase 2511:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE to_days(id + 200719) > to_days('1997-10-14 00:00:00'::date) ORDER BY 1;

-- to_days in constrains (stub function, result)
--Testcase 2512:
SELECT c1 FROM time_tbl WHERE to_days(id + 200719) > to_days('1997-10-14 00:00:00'::date) ORDER BY 1;

-- select to_days and agg (pushdown, explain)
--Testcase 2513:
EXPLAIN VERBOSE
SELECT to_days('1997-10-14 00:00:00'::date), to_days('1997-10-14 00:00:00'::date), sum(id) FROM time_tbl ORDER BY 1,2;

-- select to_days and log2 (pushdown, explain)
--Testcase 2514:
EXPLAIN VERBOSE
SELECT to_days('1997-10-14 00:00:00'::date), to_days(c2), log2(id) FROM time_tbl ORDER BY 1,2;

-- select to_days with non pushdown func and explicit constant (explain)
--Testcase 2515:
EXPLAIN VERBOSE
SELECT to_days('1997-10-14 00:00:00'::date), to_days(c2), to_hex(id), 4 FROM time_tbl ORDER BY 1,2,3;

-- select to_days with order by (explain)
--Testcase 2516:
EXPLAIN VERBOSE
SELECT to_days(id + 200719), to_days(c2), c1 FROM time_tbl ORDER BY c1;

-- select to_days with order by index (explain)
--Testcase 2517:
EXPLAIN VERBOSE
SELECT to_days(id + 200719), to_days(c2), c1 FROM time_tbl ORDER BY 2;

-- to_days constraints with order by (explain)
--Testcase 2518:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE to_days('2020-10-14 00:00:00'::date) > to_days('1997-10-14 00:00:00'::date) ORDER BY c1;

-- to_days constraints with order by (result)
--Testcase 2519:
SELECT c1 FROM time_tbl WHERE to_days('2020-10-14 00:00:00'::date) > to_days('1997-10-14 00:00:00'::date) ORDER BY c1;

-- select to_days with group by (explain)
--Testcase 2520:
EXPLAIN VERBOSE
SELECT to_days(971014), to_days(c2), c1 FROM time_tbl GROUP BY c1,c2 ORDER BY 1,2,3;

-- select to_days with group by index (explain)
--Testcase 2521:
EXPLAIN VERBOSE
SELECT to_days(971014), to_days(c2), c1 FROM time_tbl GROUP BY 1,2,3 ORDER BY 1,2,3;

-- select to_days with group by having (explain)
--Testcase 2522:
EXPLAIN VERBOSE
SELECT to_days(971014), c1 FROM time_tbl GROUP BY c1,to_days(971014) HAVING to_days(971014) > 1000 ORDER BY 1,2;

-- select to_days with group by index having (explain)
--Testcase 2523:
EXPLAIN VERBOSE
SELECT to_days(971014), c1 FROM time_tbl GROUP BY 2,1 HAVING to_days(971014) > 1000 ORDER BY 1,2;

-- select to_days and as
--Testcase 2524:
EXPLAIN VERBOSE
SELECT to_days(971014), to_days(c2) as to_days1 FROM time_tbl ORDER BY 1,2;


-- TIMESTAMPDIFF()
-- select timestampdiff (stub function, explain)
--Testcase 2525:
EXPLAIN VERBOSE
SELECT timestampdiff('MINUTE', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('MONTH', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select timestampdiff (stub function, result)
--Testcase 2526:
SELECT timestampdiff('MINUTE', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('MONTH', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select timestampdiff (stub function, not pushdown constraints, explain)
--Testcase 2527:
EXPLAIN VERBOSE
SELECT timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select timestampdiff (stub function, not pushdown constraints, result)
--Testcase 2528:
SELECT timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select timestampdiff (stub function, pushdown constraints, explain)
--Testcase 2529:
EXPLAIN VERBOSE
SELECT timestampdiff('YEAR', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select timestampdiff (stub function, pushdown constraints, result)
--Testcase 2530:
SELECT timestampdiff('YEAR', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select timestampdiff (stub function, timestampdiff in constraints, explain)
--Testcase 2531:
EXPLAIN VERBOSE
SELECT timestampdiff('YEAR', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl WHERE timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) < 100 ORDER BY 1,2,3,4;

-- select timestampdiff (stub function, timestampdiff in constraints, result)
--Testcase 2532:
SELECT timestampdiff('YEAR', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl WHERE timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) < 100 ORDER BY 1,2,3,4;

-- select timestampdiff with agg (pushdown, explain)
--Testcase 2533:
EXPLAIN VERBOSE
SELECT max(c3), timestampdiff('DAY', max(c2), max(c3)), timestampdiff('MONTH', min(c2), min(c3)) FROM time_tbl;

-- select timestampdiff as nest function with agg (pushdown, result)
--Testcase 2534:
SELECT max(c3), timestampdiff('DAY', max(c2), max(c3)), timestampdiff('MONTH', min(c2), min(c3)) FROM time_tbl;

-- select timestampdiff with non pushdown func and explicit constant (explain)
--Testcase 2535:
EXPLAIN VERBOSE
SELECT timestampdiff('MONTH', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp), pi(), 4.1 FROM time_tbl ORDER BY 1,2,3,4;

-- select timestampdiff with non pushdown func and explicit constant (result)
--Testcase 2536:
SELECT timestampdiff('MONTH', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp), pi(), 4.1 FROM time_tbl ORDER BY 1,2,3,4;

-- select timestampdiff with order by (explain)
--Testcase 2537:
EXPLAIN VERBOSE
SELECT id, timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl order by id,timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp);

-- select timestampdiff with order by (result)
--Testcase 2538:
SELECT id, timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl order by id,timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp);

-- select timestampdiff with order by index (result)
--Testcase 2539:
SELECT id, timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl order by 5,4,3,2,1;

-- select timestampdiff with order by index (result)
--Testcase 2540:
SELECT id, timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl order by 1,2,3,4,5;

-- select timestampdiff with group by (explain)
--Testcase 2541:
EXPLAIN VERBOSE
SELECT max(c3), timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl group by timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) ORDER BY 1,2,3,4,5;

-- select timestampdiff with group by (result)
--Testcase 2542:
SELECT max(c3), timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl group by timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) ORDER BY 1,2,3,4,5;

-- select timestampdiff with group by index (result)
--Testcase 2543:
SELECT id, timestampdiff('DAY', '2021-01-01 12:00:00'::timestamp, '2080-01-01'::date), timestampdiff('DAY', '2019-01-01'::date, '2080-01-01 12:00:00'::timestamp) FROM time_tbl group by 3,2,1 ORDER BY 1,2,3;

-- select timestampdiff with group by index (result)
--Testcase 2544:
SELECT id, timestampdiff('DAY', '2021-01-01 12:00:00'::timestamp, '2080-01-01'::date), timestampdiff('DAY', '2019-01-01'::date, '2080-01-01 12:00:00'::timestamp) FROM time_tbl group by 1,2,3 ORDER BY 1,2,3;

-- select timestampdiff and as
--Testcase 2545:
SELECT timestampdiff('MINUTE', c2, c3) as timestampdiff1, timestampdiff('DAY', c3, c2) as timestampdiff2, timestampdiff('MONTH', c2, '2080-01-01'::date) as timestampdiff3, timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) as timestampdiff4 FROM time_tbl ORDER BY 1,2,3,4;



-- TIMESTAMPADD()
-- select timestampadd (stub function, explain)
--Testcase 2546:
EXPLAIN VERBOSE
SELECT timestampadd('MINUTE', 5, c3), timestampadd('DAY', 5, c2) FROM time_tbl ORDER BY 1,2;

-- select timestampadd (stub function, result)
--Testcase 2547:
SELECT timestampadd('MINUTE', 5, c3), timestampadd('DAY', 5, c2) FROM time_tbl ORDER BY 1,2;

-- select timestampadd (stub function, not pushdown constraints, explain)
--Testcase 2548:
EXPLAIN VERBOSE
SELECT timestampadd('MINUTE', 10, c3), timestampadd('YEAR', 5, c2) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select timestampadd (stub function, not pushdown constraints, result)
--Testcase 2549:
SELECT timestampadd('MINUTE', 10, c3), timestampadd('YEAR', 5, c2) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select timestampadd (stub function, pushdown constraints, explain)
--Testcase 2550:
EXPLAIN VERBOSE
SELECT timestampadd('MINUTE', 6, c3), timestampadd('YEAR', 5, c2) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select timestampadd (stub function, pushdown constraints, result)
--Testcase 2551:
SELECT timestampadd('MINUTE', 6, c3), timestampadd('YEAR', 5, c2) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select timestampadd (stub function, timestampadd in constraints, explain)
--Testcase 2552:
EXPLAIN VERBOSE
SELECT timestampadd('MINUTE', 6, c3), timestampadd('YEAR', 10, c2) FROM time_tbl WHERE timestampadd('YEAR', 1, c2) > '1997-01-01 12:00:00'::timestamp ORDER BY 1,2;

-- select timestampadd (stub function, timestampadd in constraints, result)
--Testcase 2553:
SELECT timestampadd('MINUTE', 6, c3), timestampadd('YEAR', 10, c2) FROM time_tbl WHERE timestampadd('YEAR', 1, c2) > '1997-01-01 12:00:00'::timestamp ORDER BY 1,2;

-- select timestampadd with agg (pushdown, explain)
--Testcase 2554:
EXPLAIN VERBOSE
SELECT max(c3), timestampadd('DAY', 2, max(c3)), timestampadd('MONTH', 2, min(c2)) FROM time_tbl;

-- select timestampadd as nest function with agg (pushdown, result)
--Testcase 2555:
SELECT max(c3), timestampadd('DAY', 2, max(c3)), timestampadd('MONTH', 2, min(c2)) FROM time_tbl;

-- select timestampadd with non pushdown func and explicit constant (explain)
--Testcase 2556:
EXPLAIN VERBOSE
SELECT timestampadd('MINUTE', 2, max(c3)), timestampadd('MONTH', 60, min(c2)), pi(), 4.1 FROM time_tbl ORDER BY 1,2;

-- select timestampadd with non pushdown func and explicit constant (result)
--Testcase 2557:
SELECT timestampadd('MINUTE', 2, max(c3)), timestampadd('MONTH', 60, min(c2)), pi(), 4.1 FROM time_tbl ORDER BY 1,2;

-- select timestampadd with order by (explain)
--Testcase 2558:
EXPLAIN VERBOSE
SELECT id, timestampadd('MINUTE', 60, c3), timestampadd('YEAR', 10, c2) FROM time_tbl order by id,timestampadd('MINUTE', 60, c3), timestampadd('YEAR', 10, c2);

-- select timestampadd with order by (result)
--Testcase 2559:
SELECT id, timestampadd('MINUTE', 60, c3), timestampadd('YEAR', 10, c2) FROM time_tbl order by id,timestampadd('MINUTE', 60, c3), timestampadd('YEAR', 10, c2);

-- select timestampadd with order by index (result)
--Testcase 2560:
SELECT id,timestampadd('MINUTE', 60, c3), timestampadd('YEAR', 10, c2) FROM time_tbl order by 3,2,1;

-- select timestampadd with order by index (result)
--Testcase 2561:
SELECT id, timestampadd('MINUTE', 60, c3), timestampadd('YEAR', 10, c2) FROM time_tbl order by 1,2,3;

-- select timestampadd with group by (explain)
--Testcase 2562:
EXPLAIN VERBOSE
SELECT max(c3), timestampadd('YEAR', 2, '1997-01-01 12:00:00'::timestamp), timestampadd('MONTH', 12, '1997-01-01'::date) FROM time_tbl group by timestampadd('YEAR', 2, '1997-01-01 12:00:00'::timestamp), timestampadd('MONTH', 12, '1997-01-01'::date) ORDER BY 1,2,3;

-- select timestampadd with group by (result)
--Testcase 2563:
SELECT max(c3), timestampadd('YEAR', 2, '1997-01-01 12:00:00'::timestamp), timestampadd('MONTH', 12, '1997-01-01'::date) FROM time_tbl group by timestampadd('YEAR', 2, '1997-01-01 12:00:00'::timestamp), timestampadd('MONTH', 12, '1997-01-01'::date) ORDER BY 1,2,3;

-- select timestampadd with group by index (result)
--Testcase 2564:
SELECT id, timestampadd('YEAR', 2, '1997-01-01 12:00:00'::timestamp), timestampadd('MONTH', 12, '1997-01-01'::date) FROM time_tbl group by 3,2,1 ORDER BY 1,2,3;

-- select timestampadd with group by index (result)
--Testcase 2565:
SELECT id, timestampadd('YEAR', 2, '1997-01-01 12:00:00'::timestamp), timestampadd('MONTH', 12, '1997-01-01'::date) FROM time_tbl group by 1,2,3 ORDER BY 1,2,3;

-- select timestampadd and as
--Testcase 2566:
SELECT timestampadd('MINUTE', 60, c2) as timestampadd1, timestampadd('MONTH', 12, '2080-01-01 12:01:00'::timestamp) as timestampadd2 FROM time_tbl ORDER BY 1,2;



-- TIMESTAMP()
-- select mysql_timestamp (stub function, explain)
--Testcase 2567:
EXPLAIN VERBOSE
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl ORDER BY 1,2,3;

-- select mysql_timestamp (stub function, result)
--Testcase 2568:
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl ORDER BY 1,2,3;

-- select mysql_timestamp (stub function, not pushdown constraints, explain)
--Testcase 2569:
EXPLAIN VERBOSE
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3;

-- select mysql_timestamp (stub function, not pushdown constraints, result)
--Testcase 2570:
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3;

-- select mysql_timestamp (stub function, pushdown constraints, explain)
--Testcase 2571:
EXPLAIN VERBOSE
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3;

-- select mysql_timestamp (stub function, pushdown constraints, result)
--Testcase 2572:
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3;

-- select mysql_timestamp (stub function, mysql_timestamp in constraints, explain)
--Testcase 2573:
EXPLAIN VERBOSE
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl WHERE mysql_timestamp(c3, '23:11:59.123456'::time) < '2080-01-01 12:00:00'::timestamp ORDER BY 1,2,3;

-- select mysql_timestamp (stub function, mysql_timestamp in constraints, result)
--Testcase 2574:
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl WHERE mysql_timestamp(c3, '23:11:59.123456'::time) < '2080-01-01 12:00:00'::timestamp ORDER BY 1,2,3;

-- select mysql_timestamp with agg (pushdown, explain)
--Testcase 2575:
EXPLAIN VERBOSE
SELECT max(c3), mysql_timestamp(max(c2)), mysql_timestamp(max(c3)), mysql_timestamp(max(c3), '11:12:12.112233'::time) FROM time_tbl;

-- select mysql_timestamp as nest function with agg (pushdown, result)
--Testcase 2576:
SELECT max(c3), mysql_timestamp(max(c2)), mysql_timestamp(max(c3)), mysql_timestamp(max(c3), '11:12:12.112233'::time) FROM time_tbl;

-- select mysql_timestamp with non pushdown func and explicit constant (explain)
--Testcase 2577:
EXPLAIN VERBOSE
SELECT mysql_timestamp(max(c2)), mysql_timestamp(max(c3)), mysql_timestamp(max(c3), '11:12:12.112233'::time), pi(), 4.1 FROM time_tbl ORDER BY 1,2,3;

-- select mysql_timestamp with non pushdown func and explicit constant (result)
--Testcase 2578:
SELECT mysql_timestamp(max(c2)), mysql_timestamp(max(c3)), mysql_timestamp(max(c3), '11:12:12.112233'::time), pi(), 4.1 FROM time_tbl ORDER BY 1,2,3;

-- select mysql_timestamp with order by (explain)
--Testcase 2579:
EXPLAIN VERBOSE
SELECT id, mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl order by id,mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1);

-- select mysql_timestamp with order by (result)
--Testcase 2580:
SELECT id, mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl order by id,mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1);

-- select mysql_timestamp with order by index (result)
--Testcase 2581:
SELECT id, mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl order by 4,3,2,1;

-- select mysql_timestamp with order by index (result)
--Testcase 2582:
SELECT id, mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl order by 1,2,3,4;

-- select mysql_timestamp with group by (explain)
--Testcase 2583:
EXPLAIN VERBOSE
SELECT max(c3), mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl group by mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) ORDER BY 1,2,3,4;

-- select mysql_timestamp with group by (result)
--Testcase 2584:
SELECT max(c3), mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl group by mysql_timestamp('2080-01-01 12:00:00'::date), c1, c2, c3 ORDER BY 1,2,3,4;

-- select mysql_timestamp with group by index (result)
--Testcase 2585:
SELECT id, mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl group by 4,3,2,1 ORDER BY 1,2,3,4;

-- select mysql_timestamp with group by index (result)
--Testcase 2586:
SELECT id, mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl group by 1,2,3,4 ORDER BY 1,2,3,4;

-- select mysql_timestamp with group by index having (result)
--Testcase 2587:
SELECT id, mysql_timestamp(c2), c2 FROM time_tbl group by 3, 2, 1 HAVING mysql_timestamp(c2) > '2019-01-01'::date ORDER BY 1,2,3;

-- select mysql_timestamp with group by index having (result)
--Testcase 2588:
SELECT id, mysql_timestamp(c2), c2 FROM time_tbl group by 1, 2, 3 HAVING mysql_timestamp(c2) > '2019-01-01'::date ORDER BY 1,2,3;

-- select mysql_timestamp and as
--Testcase 2589:
SELECT mysql_timestamp(c2) as mysql_timestamp1, mysql_timestamp(c3) as mysql_timestamp2,  mysql_timestamp(c3, c1) as mysql_timestamp3 FROM time_tbl ORDER BY 1,2,3;

-- TIMEDIFF()
-- select timediff (stub function, explain)
--Testcase 2590:
EXPLAIN VERBOSE
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2;

-- select timediff (stub function, result)
--Testcase 2591:
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2;

-- select timediff (stub function, not pushdown constraints, explain)
--Testcase 2592:
EXPLAIN VERBOSE
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select timediff (stub function, not pushdown constraints, result)
--Testcase 2593:
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select timediff (stub function, pushdown constraints, explain)
--Testcase 2594:
EXPLAIN VERBOSE
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select timediff (stub function, pushdown constraints, result)
--Testcase 2595:
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select timediff (stub function, timediff in constraints, explain)
--Testcase 2596:
EXPLAIN VERBOSE
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl WHERE timediff(c1, '23:11:59.123456'::time) > '1 day 01:00:00'::interval ORDER BY 1,2;

-- select timediff (stub function, timediff in constraints, result)
--Testcase 2597:
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl WHERE timediff(c1, '23:11:59.123456'::time) > '1 day 01:00:00'::interval ORDER BY 1,2;

-- select timediff with agg (pushdown, explain)
--Testcase 2598:
EXPLAIN VERBOSE
SELECT max(c3), timediff('12:12:12.051555'::time, max(c1)), timediff('1997-01-01 12:00:00'::timestamp, max(c3)) FROM time_tbl;

-- select timediff as nest function with agg (pushdown, result)
--Testcase 2599:
SELECT max(c3), timediff('12:12:12.051555'::time, max(c1)), timediff('1997-01-01 12:00:00'::timestamp, max(c3)) FROM time_tbl;

-- select timediff with non pushdown func and explicit constant (explain)
--Testcase 2600:
EXPLAIN VERBOSE
SELECT timediff('12:12:12.051555'::time, max(c1)), timediff('1997-01-01 12:00:00'::timestamp, max(c3)), pi(), 4.1 FROM time_tbl;

-- select timediff with non pushdown func and explicit constant (result)
--Testcase 2601:
SELECT timediff('12:12:12.051555'::time, max(c1)), timediff('1997-01-01 12:00:00'::timestamp, max(c3)), pi(), 4.1 FROM time_tbl;

-- select timediff with order by (explain)
--Testcase 2602:
EXPLAIN VERBOSE
SELECT id, timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl order by id,timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp);

-- select timediff with order by (result)
--Testcase 2603:
SELECT id, timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl order by id,timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp);

-- select timediff with order by index (result)
--Testcase 2604:
SELECT id, timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl order by 3,2,1;

-- select timediff with order by index (result)
--Testcase 2605:
SELECT id, timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl order by 1,2,3;

-- select timediff with group by (explain)
--Testcase 2606:
EXPLAIN VERBOSE
SELECT max(c3), timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl group by timediff('2080-01-01 12:00:00'::timestamp, c3), c1, c3 ORDER BY 1,2,3;

-- select timediff with group by (result)
--Testcase 2607:
SELECT max(c3), timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl group by timediff('2080-01-01 12:00:00'::timestamp, c3), c1, c3 ORDER BY 1,2,3;

-- select timediff with group by index (result)
--Testcase 2608:
SELECT id, timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl group by 3,2,1 ORDER BY 1,2,3;

-- select timediff with group by index (result)
--Testcase 2609:
SELECT id, timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl group by 1,2,3 ORDER BY 1,2,3;

-- select timediff with group by index having (result)
--Testcase 2610:
SELECT id, timediff(c1, '12:12:12.051555'::time), c1 FROM time_tbl group by 3, 2, 1 HAVING timediff(c1, '12:12:12.051555'::time) < '1 days'::interval ORDER BY 1,2,3;

-- select timediff with group by index having (result)
--Testcase 2611:
SELECT id, timediff(c1, '12:12:12.051555'::time), c1 FROM time_tbl group by 1, 2, 3 HAVING timediff(c1, '12:12:12.051555'::time) < '1 days'::interval ORDER BY 1,2,3;

-- select timediff and as
--Testcase 2612:
SELECT timediff(c1, '12:12:12.051555'::time) as timediff1, timediff(c3, '1997-01-01 12:00:00'::timestamp) as timediff2 FROM time_tbl ORDER BY 1,2;


-- TIME_TO_SEC()
-- select time_to_sec (stub function, explain)
--Testcase 2613:
EXPLAIN VERBOSE
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl ORDER BY 1,2,3;

-- select time_to_sec (stub function, result)
--Testcase 2614:
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl ORDER BY 1,2,3;

-- select time_to_sec (stub function, not pushdown constraints, explain)
--Testcase 2615:
EXPLAIN VERBOSE
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE to_hex(id) = '2' ORDER BY 1,2,3;

-- select time_to_sec (stub function, not pushdown constraints, result)
--Testcase 2616:
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE to_hex(id) = '2' ORDER BY 1,2,3;

-- select time_to_sec (stub function, pushdown constraints, explain)
--Testcase 2617:
EXPLAIN VERBOSE
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3;

-- select time_to_sec (stub function, pushdown constraints, result)
--Testcase 2618:
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3;

-- select time_to_sec (stub function, time_to_sec in constraints, explain)
--Testcase 2619:
EXPLAIN VERBOSE
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE time_to_sec(c1) != 12345 ORDER BY 1,2,3;

-- select time_to_sec (stub function, time_to_sec in constraints, result)
--Testcase 2620:
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE time_to_sec(c1) != 12345 ORDER BY 1,2,3;

-- select time_to_sec (stub function, time_to_sec in constraints, explain)
--Testcase 2621:
EXPLAIN VERBOSE
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE time_to_sec('06:05:04.030201'::time) > 1 ORDER BY 1,2,3;

-- select time_to_sec (stub function, time_to_sec in constraints, result)
--Testcase 2622:
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE time_to_sec('06:05:04.030201'::time) > 1 ORDER BY 1,2,3;

-- select time_to_sec with agg (pushdown, explain)
--Testcase 2623:
EXPLAIN VERBOSE
SELECT max(c3), time_to_sec(max(c1)) FROM time_tbl;

-- select time_to_sec as nest function with agg (pushdown, result)
--Testcase 2624:
SELECT max(c3), time_to_sec(max(c1)) FROM time_tbl;

-- select time_to_sec with non pushdown func and explicit constant (explain)
--Testcase 2625:
EXPLAIN VERBOSE
SELECT time_to_sec(mysql_time(c3)), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select time_to_sec with non pushdown func and explicit constant (result)
--Testcase 2626:
SELECT time_to_sec(mysql_time(c3)), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select time_to_sec with order by (explain)
--Testcase 2627:
EXPLAIN VERBOSE
SELECT id, time_to_sec(c1) FROM time_tbl order by id,time_to_sec(c1);

-- select time_to_sec with order by (result)
--Testcase 2628:
SELECT id, time_to_sec(c1) FROM time_tbl order by id,time_to_sec(c1);

-- select time_to_sec with order by index (result)
--Testcase 2629:
SELECT id, time_to_sec(c1) FROM time_tbl order by 2,1;

-- select time_to_sec with order by index (result)
--Testcase 2630:
SELECT id, time_to_sec(c1) FROM time_tbl order by 1,2;

-- select time_to_sec with group by (explain)
--Testcase 2631:
EXPLAIN VERBOSE
SELECT max(c3), time_to_sec(c1) FROM time_tbl group by c1, time_to_sec('06:05:04.030201'::time) ORDER BY 1,2;

-- select time_to_sec with group by (result)
--Testcase 2632:
SELECT max(c3), time_to_sec(c1) FROM time_tbl group by c1, time_to_sec('06:05:04.030201'::time) ORDER BY 1,2;

-- select time_to_sec with group by index (result)
--Testcase 2633:
SELECT id, time_to_sec(c1) FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select time_to_sec with group by index (result)
--Testcase 2634:
SELECT id, time_to_sec(c1) FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select time_to_sec with group by having (explain)
--Testcase 2635:
EXPLAIN VERBOSE
SELECT max(c3), time_to_sec(c1), c1 FROM time_tbl group by time_to_sec(c1), c3, c1 HAVING time_to_sec(c1) > 100 ORDER BY 1,2,3;

-- select time_to_sec with group by having (result)
--Testcase 2636:
SELECT max(c3), time_to_sec(c1), c1 FROM time_tbl group by time_to_sec(c1), c3, c1 HAVING time_to_sec(c1) > 100 ORDER BY 1,2,3;

-- select time_to_sec with group by index having (result)
--Testcase 2637:
SELECT id, time_to_sec(c1), c1 FROM time_tbl group by 3, 2, 1 HAVING time_to_sec(c1) > 100 ORDER BY 1,2,3;

-- select time_to_sec with group by index having (result)
--Testcase 2638:
SELECT id, time_to_sec(c1), c1 FROM time_tbl group by 1, 2, 3 HAVING time_to_sec(c1) > 100 ORDER BY 1,2,3;

-- select time_to_sec and as
--Testcase 2639:
SELECT time_to_sec(c1) as time_to_sec1 FROM time_tbl ORDER BY 1;


-- TIME_FORMAT()
-- select time_format (stub function, explain)
--Testcase 2640:
EXPLAIN VERBOSE
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl ORDER BY 1,2,3;

-- select time_format (stub function, result)
--Testcase 2641:
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl ORDER BY 1,2,3;

-- select time_format (stub function, not pushdown constraints, explain)
--Testcase 2642:
EXPLAIN VERBOSE
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE to_hex(id) = '2' ORDER BY 1,2,3;

-- select time_format (stub function, not pushdown constraints, result)
--Testcase 2643:
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE to_hex(id) = '2' ORDER BY 1,2,3;

-- select time_format (stub function, pushdown constraints, explain)
--Testcase 2644:
EXPLAIN VERBOSE
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE id != 200 ORDER BY 1,2,3;

-- select time_format (stub function, pushdown constraints, result)
--Testcase 2645:
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE id != 200 ORDER BY 1,2,3;

-- select time_format (stub function, time_format in constraints, explain)
--Testcase 2646:
EXPLAIN VERBOSE
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE time_format(c1, '%H %k %h %I %l') != '100 100 04 04 4' ORDER BY 1,2,3;

-- select time_format (stub function, time_format in constraints, result)
--Testcase 2647:
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE time_format(c1, '%H %k %h %I %l') != '100 100 04 04 4' ORDER BY 1,2,3;

-- select time_format (stub function, time_format in constraints, explain)
--Testcase 2648:
EXPLAIN VERBOSE
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE time_format(c1, '%H %k %h %I %l') = '12 12 12 12 12' ORDER BY 1,2,3;

-- select time_format (stub function, time_format in constraints, result)
--Testcase 2649:
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE time_format(c1, '%H %k %h %I %l') = '12 12 12 12 12' ORDER BY 1,2,3;

-- select time_format with agg (pushdown, explain)
--Testcase 2650:
EXPLAIN VERBOSE
SELECT max(c3), time_format(max(c1), '%H %k %h %I %l') FROM time_tbl;

-- select time_format as nest function with agg (pushdown, result)
--Testcase 2651:
SELECT max(c3), time_format(max(c1), '%H %k %h %I %l') FROM time_tbl;

-- select time_format with non pushdown func and explicit constant (explain)
--Testcase 2652:
EXPLAIN VERBOSE
SELECT time_format(mysql_time(c3), '%H %k %h %I %l'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select time_format with non pushdown func and explicit constant (result)
--Testcase 2653:
SELECT time_format(mysql_time(c3), '%H %k %h %I %l'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select time_format with order by (explain)
--Testcase 2654:
EXPLAIN VERBOSE
SELECT id, time_format(c1, '%H %k %h %I %l') FROM time_tbl order by id,time_format(c1, '%H %k %h %I %l');

-- select time_format with order by (result)
--Testcase 2655:
SELECT id, time_format(c1, '%H %k %h %I %l') FROM time_tbl order by id,time_format(c1, '%H %k %h %I %l');

-- select time_format with order by index (result)
--Testcase 2656:
SELECT id, time_format(c1, '%H %k %h %I %l') FROM time_tbl order by 2,1;

-- select time_format with order by index (result)
--Testcase 2657:
SELECT id, time_format(c1, '%H %k %h %I %l') FROM time_tbl order by 1,2;

-- select time_format with group by (explain)
--Testcase 2658:
EXPLAIN VERBOSE
SELECT max(c3), time_format(c1, '%H %k %h %I %l') FROM time_tbl group by c1, time_format('06:05:04.030201'::time, '%H %k %h %I %l') ORDER BY 1,2;

-- select time_format with group by (result)
--Testcase 2659:
SELECT max(c3), time_format(c1, '%H %k %h %I %l') FROM time_tbl group by c1, time_format('06:05:04.030201'::time, '%H %k %h %I %l') ORDER BY 1,2;

-- select time_format with group by index (result)
--Testcase 2660:
SELECT id, time_format(c1, '%H %k %h %I %l') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select time_format with group by index (result)
--Testcase 2661:
SELECT id, time_format(c1, '%H %k %h %I %l') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select time_format with group by having (explain)
--Testcase 2662:
EXPLAIN VERBOSE
SELECT max(c3), time_format(c1, '%H %k %h %I %l') FROM time_tbl group by time_format(c1, '%H %k %h %I %l'), c3, c1 HAVING time_format(c1, '%H %k %h %I %l') != '100 100 04 04 4' ORDER BY 1,2;

-- select time_format with group by having (result)
--Testcase 2663:
SELECT max(c3), time_format(c1, '%H %k %h %I %l') FROM time_tbl group by time_format(c1, '%H %k %h %I %l'), c3, c1 HAVING time_format(c1, '%H %k %h %I %l') != '100 100 04 04 4' ORDER BY 1,2;

-- select time_format with group by index having (result)
--Testcase 2664:
SELECT id, c1, time_format(c1, '%H %k %h %I %l'), c3 FROM time_tbl group by 4, 3, 2, 1 HAVING time_format(c1, '%H %k %h %I %l') != '100 100 04 04 4' ORDER BY 1,2,3,4;

-- select time_format with group by index having (result)
--Testcase 2665:
SELECT id, c1, time_format(c1, '%H %k %h %I %l'), c3 FROM time_tbl group by 1, 2, 3, 4 HAVING time_format(c1, '%H %k %h %I %l') != '100 100 04 04 4' ORDER BY 1,2,3,4;

-- select time_format and as
--Testcase 2666:
SELECT time_format(c1, '%H %k %h %I %l') as time_format1 FROM time_tbl ORDER BY 1;



-- TIME()
-- select mysql_time (stub function, explain)
--Testcase 2667:
EXPLAIN VERBOSE
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00') FROM time_tbl ORDER BY 1,2,3,4;

-- select mysql_time (stub function, result)
--Testcase 2668:
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00') FROM time_tbl ORDER BY 1,2,3,4;

-- select mysql_time (stub function, not pushdown constraints, explain)
--Testcase 2669:
EXPLAIN VERBOSE
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00') FROM time_tbl WHERE to_hex(id) = '0' ORDER BY 1,2,3,4;

-- select mysql_time (stub function, not pushdown constraints, result)
--Testcase 2670:
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00') FROM time_tbl WHERE to_hex(id) = '0' ORDER BY 1,2,3,4;

-- select mysql_time (stub function, pushdown constraints, explain)
--Testcase 2671:
EXPLAIN VERBOSE
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00') FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select mysql_time (stub function, pushdown constraints, result)
--Testcase 2672:
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00') FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select mysql_time (stub function, mysql_time in constraints, explain)
--Testcase 2673:
EXPLAIN VERBOSE
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE mysql_time(c3) != '06:05:04.030201'::time ORDER BY 1,2,3,4;

-- select mysql_time (stub function, mysql_time in constraints, result)
--Testcase 2674:
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE mysql_time(c3) != '06:05:04.030201'::time ORDER BY 1,2,3,4;

-- select mysql_time (stub function, mysql_time in constraints, explain)
--Testcase 2675:
EXPLAIN VERBOSE
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE mysql_time('2021-01-01 12:00:00'::timestamp) > '06:05:04.030201'::time ORDER BY 1,2,3,4;

-- select mysql_time (stub function, mysql_time in constraints, result)
--Testcase 2676:
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE mysql_time('2021-01-01 12:00:00'::timestamp) > '06:05:04.030201'::time ORDER BY 1,2,3,4;

-- select mysql_time with agg (pushdown, explain)
--Testcase 2677:
EXPLAIN VERBOSE
SELECT max(c3), mysql_time(max(c3)) FROM time_tbl;

-- select mysql_time as nest function with agg (pushdown, result)
--Testcase 2678:
SELECT max(c3), mysql_time(max(c3)) FROM time_tbl;

-- select mysql_time with non pushdown func and explicit constant (explain)
--Testcase 2679:
EXPLAIN VERBOSE
SELECT mysql_time(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select mysql_time with non pushdown func and explicit constant (result)
--Testcase 2680:
SELECT mysql_time(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select mysql_time with order by (explain)
--Testcase 2681:
EXPLAIN VERBOSE
SELECT id, mysql_time(c3 + '1 12:59:10') FROM time_tbl order by id,mysql_time(c3 + '1 12:59:10');

-- select mysql_time with order by (result)
--Testcase 2682:
SELECT id, mysql_time(c3 + '1 12:59:10') FROM time_tbl order by id,mysql_time(c3 + '1 12:59:10');

-- select mysql_time with order by index (result)
--Testcase 2683:
SELECT id, mysql_time(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select mysql_time with order by index (result)
--Testcase 2684:
SELECT id, mysql_time(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select mysql_time with group by (explain)
--Testcase 2685:
EXPLAIN VERBOSE
SELECT max(c3), mysql_time(c3 + '1 12:59:10') FROM time_tbl group by mysql_time(c3 + '1 12:59:10') ORDER BY 1,2;

-- select mysql_time with group by (result)
--Testcase 2686:
SELECT max(c3), mysql_time(c3 + '1 12:59:10') FROM time_tbl group by mysql_time(c3 + '1 12:59:10') ORDER BY 1,2;

-- select mysql_time with group by index (result)
--Testcase 2687:
SELECT id, mysql_time(c3 + '1 12:59:10') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select mysql_time with group by index (result)
--Testcase 2688:
SELECT id, mysql_time(c3 + '1 12:59:10') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select mysql_time with group by having (explain)
--Testcase 2689:
EXPLAIN VERBOSE
SELECT max(c3), mysql_time(c3 + '1 12:59:10') FROM time_tbl group by mysql_time(c3 + '1 12:59:10'), c3 HAVING mysql_time(c3 + '1 12:59:10') > '06:05:04.030201'::time ORDER BY 1,2;

-- select mysql_time with group by having (result)
--Testcase 2690:
SELECT max(c3), mysql_time(c3 + '1 12:59:10') FROM time_tbl group by mysql_time(c3 + '1 12:59:10'), c3 HAVING mysql_time(c3 + '1 12:59:10') > '06:05:04.030201'::time ORDER BY 1,2;

-- select mysql_time with group by index having (result)
--Testcase 2691:
SELECT id, mysql_time(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING mysql_time(c3 + '1 12:59:10') > '06:05:04.030201'::time ORDER BY 1,2,3;

-- select mysql_time with group by index having (result)
--Testcase 2692:
SELECT id, mysql_time(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING mysql_time(c3 + '1 12:59:10') > '06:05:04.030201'::time ORDER BY 1,2,3;

-- select mysql_time and as
--Testcase 2693:
SELECT mysql_time(date_sub(c3, '1 12:59:10')) as mysql_time1 FROM time_tbl ORDER BY 1;


-- SYSDATE()
-- select sysdate (stub function, explain)
--Testcase 2694:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()) FROM time_tbl;

-- select sysdate (stub function, result)
--Testcase 2695:
SELECT datediff(sysdate(), sysdate()) FROM time_tbl;

-- select sysdate (stub function, not pushdown constraints, explain)
--Testcase 2696:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()) FROM time_tbl WHERE to_hex(id) > '0';

-- select sysdate (stub function, not pushdown constraints, result)
--Testcase 2697:
SELECT datediff(sysdate(), sysdate()) FROM time_tbl WHERE to_hex(id) > '0';

-- select sysdate (stub function, pushdown constraints, explain)
--Testcase 2698:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()) FROM time_tbl WHERE id = 1;

-- select sysdate (stub function, pushdown constraints, result)
--Testcase 2699:
SELECT datediff(sysdate(), sysdate()) FROM time_tbl WHERE id = 1;

-- select sysdate (stub function, sysdate in constraints, explain)
--Testcase 2700:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()) FROM time_tbl WHERE sysdate() > '1997-10-14 00:00:00'::timestamp;

-- select sysdate (stub function, sysdate in constraints, result)
--Testcase 2701:
SELECT datediff(sysdate(), sysdate()) FROM time_tbl WHERE sysdate() > '1997-10-14 00:00:00'::timestamp;

-- sysdate in constrains (stub function, explain)
--Testcase 2702:
EXPLAIN VERBOSE
SELECT id, c1 FROM time_tbl WHERE sysdate() > '1997-10-14 00:00:00'::timestamp ORDER BY 1,2;

-- sysdate in constrains (stub function, result)
--Testcase 2703:
SELECT id, c1 FROM time_tbl WHERE sysdate() > '1997-10-14 00:00:00'::timestamp ORDER BY 1,2;

-- sysdate as parameter of addtime(stub function, explain)
--Testcase 2704:
EXPLAIN VERBOSE
SELECT id, c1 FROM time_tbl WHERE addtime(sysdate(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY 1,2;

-- sysdate as parameter of addtime(stub function, result)
--Testcase 2705:
SELECT id, c1 FROM time_tbl WHERE addtime(sysdate(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY 1,2;

-- select sysdate and agg (pushdown, explain)
--Testcase 2706:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()), sum(id) FROM time_tbl;

-- select sysdate and agg (pushdown, result)
--Testcase 2707:
SELECT datediff(sysdate(), sysdate()), sum(id) FROM time_tbl;

-- select sysdate and log2 (pushdown, explain)
--Testcase 2708:
EXPLAIN VERBOSE
SELECT id, datediff(sysdate(), sysdate()), log2(id) FROM time_tbl ORDER BY 1,2,3;

-- select sysdate and log2 (pushdown, result)
--Testcase 2709:
SELECT id, datediff(sysdate(), sysdate()), log2(id) FROM time_tbl ORDER BY 1,2,3;

-- select sysdate with non pushdown func and explicit constant (explain)
--Testcase 2710:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select sysdate with non pushdown func and explicit constant (result)
--SELECT datediff(sysdate(), sysdate()), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select sysdate with order by (explain)
--Testcase 2711:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()), c1 FROM time_tbl ORDER BY datediff(sysdate(), sysdate()),c1;

-- select sysdate with order by (result)
--Testcase 2712:
SELECT datediff(sysdate(), sysdate()), c1 FROM time_tbl ORDER BY datediff(sysdate(), sysdate()),c1;

-- select sysdate with order by index (explain)
--Testcase 2713:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()), c1 FROM time_tbl ORDER BY 1,2;

-- select sysdate with order by index (result)
--Testcase 2714:
SELECT datediff(sysdate(), sysdate()), c1 FROM time_tbl ORDER BY 1,2;

-- sysdate constraints with order by (explain)
--Testcase 2715:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(sysdate(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY c1;

-- sysdate constraints with order by (result)
--Testcase 2716:
SELECT c1 FROM time_tbl WHERE addtime(sysdate(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY c1;

-- select sysdate with group by (explain)
--Testcase 2717:
EXPLAIN VERBOSE
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY id,datediff(sysdate(), sysdate()),c1 ORDER BY 1,2,3;

-- select sysdate with group by (result)
--Testcase 2718:
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY id,datediff(sysdate(), sysdate()),c1 ORDER BY 1,2,3;

-- select sysdate with group by index (explain)
--Testcase 2719:
EXPLAIN VERBOSE
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY 1,2,3 ORDER BY 1,2,3;

-- select sysdate with group by index (result)
--Testcase 2720:
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY 1,2,3 ORDER BY 1,2,3;

-- select sysdate with group by having (explain)
--Testcase 2721:
EXPLAIN VERBOSE
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY datediff(sysdate(), sysdate()),c1,id HAVING datediff(sysdate(), sysdate()) >= 0 ORDER BY 1,2,3;

-- select sysdate with group by having (result)
--Testcase 2722:
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY datediff(sysdate(), sysdate()),c1,id HAVING datediff(sysdate(), sysdate()) >= 0 ORDER BY 1,2,3;

-- select sysdate with group by index having (explain)
--Testcase 2723:
EXPLAIN VERBOSE
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY 3,2,1 HAVING datediff(sysdate(), sysdate()) >= 0 ORDER BY 1,2,3;

-- select sysdate with group by index having (result)
--Testcase 2724:
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY 3,2,1 HAVING datediff(sysdate(), sysdate()) >= 0 ORDER BY 1,2,3;

-- sysdate constraints with group by (explain)
--Testcase 2725:
EXPLAIN VERBOSE
SELECT id, c1 FROM time_tbl WHERE addtime(sysdate(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp GROUP BY id,c1 ORDER BY 1,2;

-- sysdate constraints with group by (result)
--Testcase 2726:
SELECT id, c1 FROM time_tbl WHERE addtime(sysdate(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp GROUP BY id,c1 ORDER BY 1,2;

-- select sysdate and as (explain)
--Testcase 2727:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()) as sysdate1 FROM time_tbl;

-- select sysdate and as (result)
--Testcase 2728:
SELECT datediff(sysdate(), sysdate()) as sysdate1 FROM time_tbl;


-- SUBTIME()
-- select subtime (stub function, explain)
--Testcase 2729:
EXPLAIN VERBOSE
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl ORDER BY 1,2,3,4;

-- select subtime (stub function, result)
--Testcase 2730:
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl ORDER BY 1,2,3,4;

-- select subtime (stub function, not pushdown constraints, explain)
--Testcase 2731:
EXPLAIN VERBOSE
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select subtime (stub function, not pushdown constraints, result)
--Testcase 2732:
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select subtime (stub function, pushdown constraints, explain)
--Testcase 2733:
EXPLAIN VERBOSE
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select subtime (stub function, pushdown constraints, result)
--Testcase 2734:
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select subtime (stub function, subtime in constraints, explain)
--Testcase 2735:
EXPLAIN VERBOSE
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subtime(c3, '1 12:59:10') != '2000-01-01' ORDER BY 1,2,3,4;

-- select subtime (stub function, subtime in constraints, result)
--Testcase 2736:
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subtime(c3, '1 12:59:10') != '2000-01-01' ORDER BY 1,2,3,4;

-- select subtime (stub function, subtime in constraints, explain)
--Testcase 2737:
EXPLAIN VERBOSE
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') > '-902:00:49'::interval ORDER BY 1,2,3,4;

-- select subtime (stub function, subtime in constraints, result)
--Testcase 2738:
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') > '-902:00:49'::interval ORDER BY 1,2,3,4;

-- select subtime with agg (pushdown, explain)
--Testcase 2739:
EXPLAIN VERBOSE
SELECT max(c1), subtime(max(c1), '1 12:59:10'::interval) FROM time_tbl;

-- select subtime as nest function with agg (pushdown, result)
--Testcase 2740:
SELECT max(c1), subtime(max(c1), '1 12:59:10'::interval) FROM time_tbl;

-- select subtime as nest with stub (pushdown, explain)
--Testcase 2741:
EXPLAIN VERBOSE
SELECT subtime(mysql_timestamp(c2), '1 12:59:10'::interval) FROM time_tbl ORDER BY 1;

-- select subtime as nest with stub (pushdown, result)
--Testcase 2742:
SELECT subtime(mysql_timestamp(c2), '1 12:59:10'::interval) FROM time_tbl ORDER BY 1;

-- select subtime with non pushdown func and explicit constant (explain)
--Testcase 2743:
EXPLAIN VERBOSE
SELECT subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select subtime with non pushdown func and explicit constant (result)
--Testcase 2744:
SELECT subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl ORDER BY 1;


-- select subtime with order by (explain)
--Testcase 2745:
EXPLAIN VERBOSE
SELECT id, subtime(c1, c1 + '1 12:59:10') FROM time_tbl order by id,subtime(c1, c1 + '1 12:59:10');

-- select subtime with order by (result)
--Testcase 2746:
SELECT id, subtime(c1, c1 + '1 12:59:10') FROM time_tbl order by id,subtime(c1, c1 + '1 12:59:10');

-- select subtime with order by index (result)
--Testcase 2747:
SELECT id, subtime(c1, c1 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select subtime with order by index (result)
--Testcase 2748:
SELECT id, subtime(c1, c1 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select subtime with group by (explain)
--Testcase 2749:
EXPLAIN VERBOSE
SELECT count(id), subtime(c1, c1 + '1 12:59:10') FROM time_tbl group by subtime(c1, c1 + '1 12:59:10') ORDER BY 1,2;

-- select subtime with group by (result)
--Testcase 2750:
SELECT count(id), subtime(c1, c1 + '1 12:59:10') FROM time_tbl group by subtime(c1, c1 + '1 12:59:10') ORDER BY 1,2;

-- select subtime with group by index (result)
--Testcase 2751:
SELECT id, subtime(c1, c1 + '1 12:59:10') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select subtime with group by index (result)
--Testcase 2752:
SELECT id, subtime(c1, c1 + '1 12:59:10') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select subtime with group by having (explain)
--Testcase 2753:
EXPLAIN VERBOSE
SELECT count(id), subtime(c3, '1 12:59:10') FROM time_tbl group by subtime(c3, '1 12:59:10'), c3 HAVING subtime(c3, '1 12:59:10') < '2080-01-01'::timestamp ORDER BY 1,2;

-- select subtime with group by having (result)
--Testcase 2754:
SELECT count(id), subtime(c3, '1 12:59:10') FROM time_tbl group by subtime(c3, '1 12:59:10'), c3 HAVING subtime(c3, '1 12:59:10') < '2080-01-01'::timestamp ORDER BY 1,2;

-- select subtime and as
--Testcase 2755:
SELECT subtime(c3, '1 12:59:10') as subtime1, subtime(c3, INTERVAL '6 months 2 hours 30 minutes') as subtime2, subtime(timediff(c3, '2008-01-01 00:00:00.000001') , INTERVAL '6 months 2 hours 30 minutes') as subtime3, subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') as subtime4 FROM time_tbl ORDER BY 1,2,3,4;



-- SUBDATE()
-- select subdate (stub function, explain)
--Testcase 2756:
EXPLAIN VERBOSE
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl ORDER BY 1,2;

-- select subdate (stub function, result)
--Testcase 2757:
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl ORDER BY 1,2;

-- select subdate (stub function, not pushdown constraints, explain)
--Testcase 2758:
EXPLAIN VERBOSE
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select subdate (stub function, not pushdown constraints, result)
--Testcase 2759:
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select subdate (stub function, pushdown constraints, explain)
--Testcase 2760:
EXPLAIN VERBOSE
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE id != 0 ORDER BY 1,2;

-- select subdate (stub function, pushdown constraints, result)
--Testcase 2761:
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE id != 0 ORDER BY 1,2;

-- select subdate (stub function, subdate in constraints, explain)
--Testcase 2762:
EXPLAIN VERBOSE
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subdate(c3, '1 12:59:10') != '2000-01-01' ORDER BY 1,2;

-- select subdate (stub function, subdate in constraints, result)
--Testcase 2763:
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subdate(c3, '1 12:59:10') != '2000-01-01' ORDER BY 1,2;

-- select subdate (stub function, subdate in constraints, explain)
--Testcase 2764:
EXPLAIN VERBOSE
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subdate(c2, INTERVAL '6 months 2 hours 30 minutes') > '2008-01-01 00:00:00.000001'::timestamp ORDER BY 1,2;

-- select subdate (stub function, subdate in constraints, result)
--Testcase 2765:
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subdate(c2, INTERVAL '6 months 2 hours 30 minutes') > '2008-01-01 00:00:00.000001'::timestamp ORDER BY 1,2;

-- select subdate with agg (pushdown, explain)
--Testcase 2766:
EXPLAIN VERBOSE
SELECT max(c1), subdate(max(c3), '1 12:59:10'::interval) FROM time_tbl;

-- select subdate as nest function with agg (pushdown, result)
--Testcase 2767:
SELECT max(c1), subdate(max(c3), '1 12:59:10'::interval) FROM time_tbl;

-- select subdate as nest with stub (pushdown, explain)
--Testcase 2768:
EXPLAIN VERBOSE
SELECT subdate(adddate(c3, INTERVAL '6 months 2 hours 30 minutes'), '1 12:59:10'::interval) FROM time_tbl ORDER BY 1;

-- select subdate as nest with stub (pushdown, result)
--Testcase 2769:
SELECT subdate(adddate(c3, INTERVAL '6 months 2 hours 30 minutes'), '1 12:59:10'::interval) FROM time_tbl ORDER BY 1;

-- select subdate with non pushdown func and explicit constant (explain)
--Testcase 2770:
EXPLAIN VERBOSE
SELECT subdate(adddate(c3, INTERVAL '6 months 2 hours 30 minutes'), INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select subdate with non pushdown func and explicit constant (result)
--Testcase 2771:
SELECT subdate(adddate(c3, INTERVAL '6 months 2 hours 30 minutes'), INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select subdate with order by (explain)
--Testcase 2772:
EXPLAIN VERBOSE
SELECT id, subdate(c3, '1 12:59:10'::interval) FROM time_tbl order by id,subdate(c3, '1 12:59:10'::interval);

-- select subdate with order by (result)
--Testcase 2773:
SELECT id, subdate(c3, '1 12:59:10'::interval) FROM time_tbl order by id,subdate(c3, '1 12:59:10'::interval);

-- select subdate with order by index (result)
--Testcase 2774:
SELECT id, subdate(c3, '1 12:59:10'::interval) FROM time_tbl order by 2,1;

-- select subdate with order by index (result)
--Testcase 2775:
SELECT id, subdate(c3, '1 12:59:10'::interval) FROM time_tbl order by 1,2;

-- select subdate with group by (explain)
--Testcase 2776:
EXPLAIN VERBOSE
SELECT count(id), subdate(c3, '1 12:59:10'::interval) FROM time_tbl group by subdate(c3, '1 12:59:10'::interval) ORDER BY 1,2;

-- select subdate with group by (result)
--Testcase 2777:
SELECT count(id), subdate(c3, '1 12:59:10'::interval) FROM time_tbl group by subdate(c3, '1 12:59:10'::interval) ORDER BY 1,2;


-- select subdate with group by index (result)
--Testcase 2778:
SELECT id, subdate(c3, '1 12:59:10'::interval) FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select subdate with group by index (result)
--Testcase 2779:
SELECT id, subdate(c3, '1 12:59:10'::interval) FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select subdate with group by having (explain)
--Testcase 2780:
EXPLAIN VERBOSE
SELECT count(id), subdate(c3, '1 12:59:10') FROM time_tbl group by subdate(c3, '1 12:59:10'), c3 HAVING subdate(c3, '1 12:59:10') < '2080-01-01'::timestamp ORDER BY 1,2;

-- select subdate with group by having (result)
--Testcase 2781:
SELECT count(id), subdate(c3, '1 12:59:10') FROM time_tbl group by subdate(c3, '1 12:59:10'), c3 HAVING subdate(c3, '1 12:59:10') < '2080-01-01'::timestamp ORDER BY 1,2;

-- select subdate and as
--Testcase 2782:
SELECT subdate(c3, '1 12:59:10') as subdate1, subdate(c3, INTERVAL '6 months 2 hours 30 minutes') as subdate2 FROM time_tbl ORDER BY 1,2;

-- STR_TO_DATE()
-- select str_to_date (stub function, explain)
--Testcase 2783:
EXPLAIN VERBOSE
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl ORDER BY 1,2,3;
-- select str_to_date (stub function, explain)
--Testcase 2784:
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl ORDER BY 1,2,3;

-- select str_to_date (stub function, not pushdown constraints, explain)
--Testcase 2785:
EXPLAIN VERBOSE
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3;
-- select str_to_date (stub function, not pushdown constraints, result)
--Testcase 2786:
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3;

-- select str_to_date (stub function, pushdown constraints, explain)
--Testcase 2787:
EXPLAIN VERBOSE
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl WHERE id != 200 ORDER BY 1,2,3;
-- select str_to_date (stub function, pushdown constraints, result)
--Testcase 2788:
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl WHERE id != 200 ORDER BY 1,2,3;

-- select str_to_date (stub function, year in constraints, explain)
--Testcase 2789:
EXPLAIN VERBOSE
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl WHERE str_to_date(c1, '%H:%i:%s') > '02:00:00'::time ORDER BY 1,2,3;
-- select str_to_date (stub function, year in constraints, result)
--Testcase 2790:
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl WHERE str_to_date(c1, '%H:%i:%s') > '02:00:00'::time ORDER BY 1,2,3;

-- select str_to_date with agg (pushdown, explain)
--Testcase 2791:
EXPLAIN VERBOSE
SELECT max(c3), str_to_date(max(c1), '%H:%i:%s') FROM time_tbl;
-- select str_to_date as nest function with agg (pushdown, result)
--Testcase 2792:
SELECT max(c3), str_to_date(max(c1), '%H:%i:%s') FROM time_tbl;

-- select str_to_date with non pushdown func and explicit constant (explain)
--Testcase 2793:
EXPLAIN VERBOSE
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s'), pi(), 4.1 FROM time_tbl ORDER BY 1,2,3;
-- -- select str_to_date with non pushdown func and explicit constant (result)
--Testcase 2794:
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s'), pi(), 4.1 FROM time_tbl ORDER BY 1,2,3;

-- select str_to_date with order by (explain)
--Testcase 2795:
EXPLAIN VERBOSE
SELECT id, str_to_date(c1, '%H:%i:%s'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl order by id,str_to_date(c1, '%H:%i:%s'), str_to_date(c3, '%Y-%m-%d %H:%i:%s');
-- select str_to_date with order by (result)
--Testcase 2796:
SELECT id, str_to_date(c1, '%H:%i:%s'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl order by id,str_to_date(c1, '%H:%i:%s'), str_to_date(c3, '%Y-%m-%d %H:%i:%s');

-- select str_to_date with order by index (result)
--Testcase 2797:
SELECT id, str_to_date(c1, '%H:%i:%s'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl order by 3,2,1;
-- select str_to_date with order by index (result)
--Testcase 2798:
SELECT id, str_to_date(c1, '%H:%i:%s'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl order by 1,2,3;

-- select str_to_date with group by (explain)
--Testcase 2799:
EXPLAIN VERBOSE
SELECT max(c1), str_to_date(c1, '%H:%i:%s') FROM time_tbl group by str_to_date(c1, '%H:%i:%s') ORDER BY 1,2;
-- select str_to_date with group by (result)
--Testcase 2800:
SELECT max(c3), str_to_date(c1, '%H:%i:%s') FROM time_tbl group by str_to_date(c1, '%H:%i:%s') ORDER BY 1,2;

-- select str_to_date with group by index (result)
--Testcase 2801:
SELECT id, str_to_date(c1, '%H:%i:%s') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select str_to_date with group by index (result)
--Testcase 2802:
SELECT id, str_to_date(c1, '%H:%i:%s') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select str_to_date with group by having (explain)
--Testcase 2803:
EXPLAIN VERBOSE
SELECT max(c3), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl group by str_to_date(c3, '%Y-%m-%d %H:%i:%s'),c3 HAVING str_to_date(c3, '%Y-%m-%d %H:%i:%s') < '2021-01-03 13:00:00'::timestamp ORDER BY 1,2;
-- select str_to_date with group by having (result)
--Testcase 2804:
SELECT max(c3), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl group by str_to_date(c3, '%Y-%m-%d %H:%i:%s'),c3 HAVING str_to_date(c3, '%Y-%m-%d %H:%i:%s') < '2021-01-03 13:00:00'::timestamp ORDER BY 1,2;

-- select str_to_date with group by index having (result)
--Testcase 2805:
SELECT id, str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl group by 1, 2 HAVING id > 1 ORDER BY 1,2;

-- SECOND()
-- select second (stub function, explain)
--Testcase 2806:
EXPLAIN VERBOSE
SELECT second(c1), second(c3) FROM time_tbl ORDER BY 1,2;
--Testcase 2807:
SELECT second(c1), second(c3) FROM time_tbl ORDER BY 1,2;

-- select second (stub function, not pushdown constraints, explain)
--Testcase 2808:
EXPLAIN VERBOSE
SELECT second(c1), second(c3) FROM time_tbl WHERE to_hex(id) > '0' ORDER BY 1,2;
--Testcase 2809:
SELECT second(c1), second(c3) FROM time_tbl WHERE to_hex(id) > '0' ORDER BY 1,2;

-- select second (stub function, pushdown constraints, explain)
--Testcase 2810:
EXPLAIN VERBOSE
SELECT second(c1), second(c3) FROM time_tbl WHERE id = 1 ORDER BY 1,2;
--Testcase 2811:
SELECT second(c1), second(c3) FROM time_tbl WHERE id = 1 ORDER BY 1,2;

-- select second (stub function, second in constraints, explain)
--Testcase 2812:
EXPLAIN VERBOSE
SELECT second(c1), second(c3) FROM time_tbl WHERE second(c2) < second(c3) ORDER BY 1,2;
--Testcase 2813:
SELECT second(c1), second(c3) FROM time_tbl WHERE second(c2) < second(c3) ORDER BY 1,2;

-- second in constrains (stub function, explain)
--Testcase 2814:
EXPLAIN VERBOSE
SELECT second(c1), second(c3) FROM time_tbl WHERE second(c2) < id ORDER BY 1,2;

-- second in constrains (stub function, result)
--Testcase 2815:
SELECT second(c1), second(c3) FROM time_tbl WHERE second(c2) < id ORDER BY 1,2;

-- select second as nest function with agg (pushdown, explain)
--Testcase 2816:
EXPLAIN VERBOSE
SELECT max(c1), second(max(c3)) FROM time_tbl;

-- select second as nest function with agg (pushdown, result)
--Testcase 2817:
SELECT max(c1), second(max(c3)) FROM time_tbl;

-- select second and agg (pushdown, explain)
--Testcase 2818:
EXPLAIN VERBOSE
SELECT second('1997-10-14 00:01:01'::timestamp), second('00:01:59'::time), sum(id) FROM time_tbl ORDER BY 1,2,3;

-- select second and log2 (pushdown, explain)
--Testcase 2819:
EXPLAIN VERBOSE
SELECT second('1997-10-14 00:01:01'::timestamp), second('00:01:59'::time), log2(id) FROM time_tbl ORDER BY 1,2,3;

-- select second with non pushdown func and explicit constant (explain)
--Testcase 2820:
EXPLAIN VERBOSE
SELECT second('1997-10-14 00:00:00'::timestamp), second('00:01:59'::time), to_hex(id), 4 FROM time_tbl ORDER BY 1,2,3;

-- select second with order by (explain)
--Testcase 2821:
EXPLAIN VERBOSE
SELECT second(c1), second(c3), c1 FROM time_tbl ORDER BY 1,2,3;

-- select second with order by index (result)
--Testcase 2822:
SELECT second(c1), second(c3), c1 FROM time_tbl ORDER BY 1,2,3;

-- second constraints with order by (explain)
--Testcase 2823:
EXPLAIN VERBOSE
SELECT second(c1), second(c3) FROM time_tbl WHERE second('2020-10-14 00:39:05'::timestamp) > second('1997-10-14 00:00:00'::timestamp) ORDER BY second(c1), second(c3);

-- second constraints with order by (result)
--Testcase 2824:
SELECT second(c1), second(c3) FROM time_tbl WHERE second('2020-10-14 00:39:05'::timestamp) > second('1997-10-14 00:00:00'::timestamp) ORDER BY second(c1), second(c3);

-- select second with group by (explain)
--Testcase 2825:
EXPLAIN VERBOSE
SELECT second(c1), second(c3), c1 FROM time_tbl GROUP BY c1,c3 ORDER BY 1,2,3;

-- select second with group by index (explain)
--Testcase 2826:
EXPLAIN VERBOSE
SELECT second(c1), second(c3), c1 FROM time_tbl GROUP BY 1,2,3 ORDER BY 1,2,3;

-- select second with group by having (explain)
--Testcase 2827:
EXPLAIN VERBOSE
SELECT second(c1), c1 FROM time_tbl GROUP BY second(c1),c1 HAVING second(c1) > 1 ORDER BY 1,2;

-- select second with group by index having (result)
--Testcase 2828:
SELECT second(c1), c1 FROM time_tbl GROUP BY second(c1),c1 HAVING second(c1) > 1 ORDER BY 1,2;

-- select second and as
--Testcase 2829:
EXPLAIN VERBOSE
SELECT second(c1) as second1, second(c3) as second2 FROM time_tbl ORDER BY 1,2;



-- SEC_TO_TIME()
-- select sec_to_time (stub function, explain)
--Testcase 2830:
EXPLAIN VERBOSE
SELECT sec_to_time(id) FROM time_tbl ORDER BY 1;
--Testcase 2831:
SELECT sec_to_time(id) FROM time_tbl ORDER BY 1;

-- select sec_to_time (stub function, not pushdown constraints, explain)
--Testcase 2832:
EXPLAIN VERBOSE
SELECT sec_to_time(id) FROM time_tbl WHERE to_hex(id) > '0' ORDER BY 1;
--Testcase 2833:
SELECT sec_to_time(id) FROM time_tbl WHERE to_hex(id) > '0' ORDER BY 1;

-- select sec_to_time (stub function, pushdown constraints, explain)
--Testcase 2834:
EXPLAIN VERBOSE
SELECT sec_to_time(id) FROM time_tbl WHERE id = 1 ORDER BY 1;
--Testcase 2835:
SELECT sec_to_time(id) FROM time_tbl WHERE id = 1 ORDER BY 1;

-- select sec_to_time (stub function, sec_to_time in constraints, explain)
--Testcase 2836:
EXPLAIN VERBOSE
SELECT sec_to_time(id) FROM time_tbl WHERE sec_to_time(id) < c1 ORDER BY 1;
--Testcase 2837:
SELECT sec_to_time(id) FROM time_tbl WHERE sec_to_time(id) < c1 ORDER BY 1;

-- sec_to_time in constrains (stub function, explain)
--Testcase 2838:
EXPLAIN VERBOSE
SELECT sec_to_time(id) FROM time_tbl WHERE sec_to_time(id) < c1 ORDER BY 1;

-- sec_to_time in constrains (stub function, result)
--Testcase 2839:
SELECT sec_to_time(id) FROM time_tbl WHERE sec_to_time(id) < c1 ORDER BY 1;

-- select sec_to_time as nest function with agg (pushdown, explain)
--Testcase 2840:
EXPLAIN VERBOSE
SELECT max(c1), sec_to_time(max(id)) FROM time_tbl;

-- select sec_to_time as nest function with agg (pushdown, result)
--Testcase 2841:
SELECT max(c1), sec_to_time(max(id)) FROM time_tbl;

-- select sec_to_time and agg (pushdown, explain)
--Testcase 2842:
EXPLAIN VERBOSE
SELECT max(id), sec_to_time(max(id)) FROM time_tbl;

-- select sec_to_time and log2 (pushdown, explain)
--Testcase 2843:
EXPLAIN VERBOSE
SELECT sec_to_time(id), log2(id) FROM time_tbl;

-- select sec_to_time with non pushdown func and explicit constant (explain)
--Testcase 2844:
EXPLAIN VERBOSE
SELECT sec_to_time(id), to_hex(id), 4 FROM time_tbl;

-- select sec_to_time with order by (explain)
--Testcase 2845:
EXPLAIN VERBOSE
SELECT sec_to_time(id), c1 FROM time_tbl ORDER BY id,sec_to_time(id);

-- select sec_to_time with order by index (result)
--Testcase 2846:
SELECT sec_to_time(id), c1 FROM time_tbl ORDER BY 1,2;

-- sec_to_time constraints with order by (explain)
--Testcase 2847:
EXPLAIN VERBOSE
SELECT sec_to_time(id) FROM time_tbl WHERE sec_to_time(id) < c1 ORDER BY 1;

-- sec_to_time constraints with order by (result)
--Testcase 2848:
SELECT sec_to_time(id) FROM time_tbl WHERE sec_to_time(id) < c1 ORDER BY sec_to_time(id);

-- select sec_to_time with group by (explain)
--Testcase 2849:
EXPLAIN VERBOSE
SELECT sec_to_time(id), c1 FROM time_tbl GROUP BY id,c1 ORDER BY 1,2;

-- select sec_to_time with group by index (explain)
--Testcase 2850:
EXPLAIN VERBOSE
SELECT sec_to_time(id), c1 FROM time_tbl GROUP BY 1,2 ORDER BY 1,2;

-- select sec_to_time with group by having (explain)
--Testcase 2851:
EXPLAIN VERBOSE
SELECT sec_to_time(id), c1 FROM time_tbl GROUP BY sec_to_time(id), id, c1 HAVING sec_to_time(id) < c1 ORDER BY 1,2;

-- select sec_to_time with group by index having (result)
--Testcase 2852:
SELECT sec_to_time(id), c1 FROM time_tbl GROUP BY sec_to_time(id), id, c1 HAVING sec_to_time(id) < c1 ORDER BY 1,2;

-- select sec_to_time and as
--Testcase 2853:
EXPLAIN VERBOSE
SELECT sec_to_time(id) as sec_to_time1 FROM time_tbl ORDER BY 1;


-- QUARTER()
-- select quarter (stub function, explain)
--Testcase 2854:
EXPLAIN VERBOSE
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select quarter (stub function, result)
--Testcase 2855:
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select quarter (stub function, not pushdown constraints, explain)
--Testcase 2856:
EXPLAIN VERBOSE
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select quarter (stub function, not pushdown constraints, result)
--Testcase 2857:
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select quarter (stub function, pushdown constraints, explain)
--Testcase 2858:
EXPLAIN VERBOSE
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select quarter (stub function, pushdown constraints, result)
--Testcase 2859:
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select quarter (stub function, quarter in constraints, explain)
--Testcase 2860:
EXPLAIN VERBOSE
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE quarter(c3) = quarter('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select quarter (stub function, quarter in constraints, result)
--Testcase 2861:
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE quarter(c3) = quarter('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select quarter (stub function, quarter in constraints, explain)
--Testcase 2862:
EXPLAIN VERBOSE
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE quarter('2021-01-01 12:00:00'::timestamp) = '1' ORDER BY 1,2,3,4;

-- select quarter (stub function, quarter in constraints, result)
--Testcase 2863:
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE quarter('2021-01-01 12:00:00'::timestamp) = '1' ORDER BY 1,2,3,4;

-- select quarter with agg (pushdown, explain)
--Testcase 2864:
EXPLAIN VERBOSE
SELECT max(c3), quarter(max(c3)) FROM time_tbl;

-- select quarter as nest function with agg (pushdown, result)
--Testcase 2865:
SELECT max(c3), quarter(max(c3)) FROM time_tbl;

-- select quarter with non pushdown func and explicit constant (explain)
--Testcase 2866:
EXPLAIN VERBOSE
SELECT quarter(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select quarter with non pushdown func and explicit constant (result)
--Testcase 2867:
SELECT quarter(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select quarter with order by (explain)
--Testcase 2868:
EXPLAIN VERBOSE
SELECT id, quarter(c3 + '1 12:59:10') FROM time_tbl order by id,quarter(c3 + '1 12:59:10');

-- select quarter with order by (result)
--Testcase 2869:
SELECT id, quarter(c3 + '1 12:59:10') FROM time_tbl order by id,quarter(c3 + '1 12:59:10');

-- select quarter with order by index (result)
--Testcase 2870:
SELECT id, quarter(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select quarter with order by index (result)
--Testcase 2871:
SELECT id, quarter(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select quarter with group by (explain)
--Testcase 2872:
EXPLAIN VERBOSE
SELECT max(c3), quarter(c3 + '1 12:59:10') FROM time_tbl group by quarter(c3 + '1 12:59:10') ORDER BY 1,2;

-- select quarter with group by (result)
--Testcase 2873:
SELECT max(c3), quarter(c3 + '1 12:59:10') FROM time_tbl group by quarter(c3 + '1 12:59:10') ORDER BY 1,2;

-- select quarter with group by index (result)
--Testcase 2874:
SELECT id, quarter(c3 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select quarter with group by index (result)
--Testcase 2875:
SELECT id, quarter(c3 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select quarter with group by having (explain)
--Testcase 2876:
EXPLAIN VERBOSE
SELECT max(c3), quarter(c3 + '1 12:59:10') FROM time_tbl group by quarter(c3 + '1 12:59:10'), c3 HAVING quarter(c3 + '1 12:59:10') > '0' ORDER BY 1,2;

-- select quarter with group by having (result)
--Testcase 2877:
SELECT max(c3), quarter(c3 + '1 12:59:10') FROM time_tbl group by quarter(c3 + '1 12:59:10'), c3 HAVING quarter(c3 + '1 12:59:10') > '0' ORDER BY 1,2;

-- select quarter with group by index having (result)
--Testcase 2878:
SELECT id, quarter(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING quarter(c3 + '1 12:59:10') > '0' ORDER BY 1,2;

-- select quarter with group by index having (result)
--Testcase 2879:
SELECT id, quarter(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING quarter(c3 + '1 12:59:10') > '0' ORDER BY 1,2;

-- select quarter and as
--Testcase 2880:
SELECT quarter(date_sub(c3, '1 12:59:10')) as quarter1 FROM time_tbl ORDER BY 1;



-- PERIOD_DIFF()
-- select period_diff (stub function, explain)
--Testcase 2881:
EXPLAIN VERBOSE
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl ORDER BY 1;

-- select period_diff (stub function, result)
--Testcase 2882:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl ORDER BY 1;

-- select period_diff (stub function, not pushdown constraints, explain)
--Testcase 2883:
EXPLAIN VERBOSE
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1;

-- select period_diff (stub function, not pushdown constraints, result)
--Testcase 2884:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1;

-- select period_diff (stub function, pushdown constraints, explain)
--Testcase 2885:
EXPLAIN VERBOSE
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE id != 200 ORDER BY 1;

-- select period_diff (stub function, pushdown constraints, result)
--Testcase 2886:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE id != 200 ORDER BY 1;

-- select period_diff (stub function, period_diff in constraints, explain)
--Testcase 2887:
EXPLAIN VERBOSE
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE period_diff(mysql_extract('YEAR_MONTH', c3 ), 199710) > id ORDER BY 1;

-- select period_diff (stub function, period_diff in constraints, result)
--Testcase 2888:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE period_diff(mysql_extract('YEAR_MONTH', c3 ), 199710) > id ORDER BY 1;

-- select period_diff with agg (pushdown, explain)
--Testcase 2889:
EXPLAIN VERBOSE
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl ORDER BY 1;

-- select period_diff as nest function with agg (pushdown, result)
--Testcase 2890:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl ORDER BY 1;

-- select period_diff with non pushdown func and explicit constant (explain)
--Testcase 2891:
EXPLAIN VERBOSE
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select period_diff with non pushdown func and explicit constant (result)
--Testcase 2892:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select period_diff with order by (explain)
--Testcase 2893:
EXPLAIN VERBOSE
SELECT id, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by id,period_diff(mysql_extract('YEAR_MONTH', c3 ), 199710);

-- select period_diff with order by (result)
--Testcase 2894:
SELECT id, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by id,period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907);

-- select period_diff with order by index (result)
--Testcase 2895:
SELECT id, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by 2,1;

-- select period_diff with order by index (result)
--Testcase 2896:
SELECT id, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by 1,2;

-- select period_diff with group by index (result)
--Testcase 2897:
SELECT id, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select period_diff with group by index (result)
--Testcase 2898:
SELECT id, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select period_diff with group by having (explain)
--Testcase 2899:
EXPLAIN VERBOSE
SELECT max(c3), period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by  period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907),c3 HAVING period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0 ORDER BY 1,2;

-- select period_diff with group by having (result)
--Testcase 2900:
SELECT max(c3), period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by  period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907),c3 HAVING period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0 ORDER BY 1,2;

-- select period_diff with group by index having (result)
--Testcase 2901:
SELECT id, c3, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 3, 2, 1 HAVING period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0 ORDER BY 1,2,3;

-- select period_diff with group by index having (result)
--Testcase 2902:
SELECT id, c3, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 1, 2, 3 HAVING period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0 ORDER BY 1,2,3;

-- select period_diff and as
--Testcase 2903:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) as period_diff1 FROM time_tbl ORDER BY 1;



-- PERIOD_ADD()
-- select period_add (stub function, explain)
--Testcase 2904:
EXPLAIN VERBOSE
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl ORDER BY 1;

-- select period_add (stub function, result)
--Testcase 2905:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl ORDER BY 1;

-- select period_add (stub function, not pushdown constraints, explain)
--Testcase 2906:
EXPLAIN VERBOSE
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1;

-- select period_add (stub function, not pushdown constraints, result)
--Testcase 2907:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1;

-- select period_add (stub function, pushdown constraints, explain)
--Testcase 2908:
EXPLAIN VERBOSE
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE id != 200 ORDER BY 1;

-- select period_add (stub function, pushdown constraints, result)
--Testcase 2909:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE id != 200 ORDER BY 1;

-- select period_add (stub function, period_add in constraints, explain)
--Testcase 2910:
EXPLAIN VERBOSE
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE period_add(mysql_extract('YEAR_MONTH', c3 ), 199710) > id ORDER BY 1;

-- select period_add (stub function, period_add in constraints, result)
--Testcase 2911:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE period_add(mysql_extract('YEAR_MONTH', c3 ), 199710) > id ORDER BY 1;

-- select period_add with agg (pushdown, explain)
--Testcase 2912:
EXPLAIN VERBOSE
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl ORDER BY 1;

-- select period_add as nest function with agg (pushdown, result)
--Testcase 2913:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl ORDER BY 1;

-- select period_add with non pushdown func and explicit constant (explain)
--Testcase 2914:
EXPLAIN VERBOSE
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select period_add with non pushdown func and explicit constant (result)
--Testcase 2915:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select period_add with order by (explain)
--Testcase 2916:
EXPLAIN VERBOSE
SELECT id, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by id,period_add(mysql_extract('YEAR_MONTH', c3 ), 199710),id;

-- select period_add with order by (result)
--Testcase 2917:
SELECT id, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by id,period_add(mysql_extract('YEAR_MONTH', c3 ), 201907),id;

-- select period_add with order by index (result)
--Testcase 2918:
SELECT id, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by 2,1;

-- select period_add with order by index (result)
--Testcase 2919:
SELECT id, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by 1,2;

-- select period_add with group by index (result)
--Testcase 2920:
SELECT id, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 2,1 ORDER BY 1;

-- select period_add with group by index (result)
--Testcase 2921:
SELECT id, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 1,2 ORDER BY 1;

-- select period_add with group by having (explain)
--Testcase 2922:
EXPLAIN VERBOSE
SELECT max(c3), period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by period_add(mysql_extract('YEAR_MONTH', c3 ), 201907),c3 HAVING period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0 ORDER BY 1;

-- select period_add with group by having (result)
--Testcase 2923:
SELECT max(c3), period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by period_add(mysql_extract('YEAR_MONTH', c3 ), 201907),c3 HAVING period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0 ORDER BY 1;

-- select period_add with group by index having (result)
--Testcase 2924:
SELECT id, c3, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 3, 2, 1 HAVING period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0 ORDER BY 1,2,3;

-- select period_add with group by index having (result)
--Testcase 2925:
SELECT id, c3, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 1, 2, 3 HAVING period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0 ORDER BY 1,2,3;

-- select period_add and as
--Testcase 2926:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) as period_add1 FROM time_tbl ORDER BY 1;



-- NOW()
-- mysql_now is mutable function, some executes will return different result
-- select mysql_now (stub function, explain)
--Testcase 2927:
EXPLAIN VERBOSE
SELECT mysql_now() FROM time_tbl;

-- select mysql_now (stub function, not pushdown constraints, explain)
--Testcase 2928:
EXPLAIN VERBOSE
SELECT mysql_now() FROM time_tbl WHERE to_hex(id) > '0';

-- select mysql_now (stub function, pushdown constraints, explain)
--Testcase 2929:
EXPLAIN VERBOSE
SELECT mysql_now() FROM time_tbl WHERE id = 1;

-- select mysql_now (stub function, mysql_now in constraints, explain)
--Testcase 2930:
EXPLAIN VERBOSE
SELECT mysql_now() FROM time_tbl WHERE mysql_now() > '2000-01-01 00:00:00'::timestamp;

-- mysql_now in constrains (stub function, explain)
--Testcase 2931:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE mysql_now() > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- mysql_now in constrains (stub function, result)
--Testcase 2932:
SELECT c1 FROM time_tbl WHERE mysql_now() > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- mysql_now as parameter of addtime(stub function, explain)
--Testcase 2933:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_now(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- mysql_now as parameter of addtime(stub function, result)
--Testcase 2934:
SELECT c1 FROM time_tbl WHERE addtime(mysql_now(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- select mysql_now and agg (pushdown, explain)
--Testcase 2935:
EXPLAIN VERBOSE
SELECT mysql_now(), sum(id) FROM time_tbl ORDER BY 1,2;

-- select mysql_now and log2 (pushdown, explain)
--Testcase 2936:
EXPLAIN VERBOSE
SELECT mysql_now(), log2(id) FROM time_tbl ORDER BY 1,2;

-- select mysql_now with non pushdown func and explicit constant (explain)
--Testcase 2937:
EXPLAIN VERBOSE
SELECT mysql_now(), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select mysql_now with order by (explain)
--Testcase 2938:
EXPLAIN VERBOSE
SELECT mysql_now(), c1 FROM time_tbl ORDER BY c1;

-- select mysql_now with order by index (explain)
--Testcase 2939:
EXPLAIN VERBOSE
SELECT mysql_now(), c1 FROM time_tbl ORDER BY 2;

-- mysql_now constraints with order by (explain)
--Testcase 2940:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_now(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- mysql_now constraints with order by (result)
--Testcase 2941:
SELECT c1 FROM time_tbl WHERE addtime(mysql_now(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- select mysql_now with group by (explain)
--Testcase 2942:
EXPLAIN VERBOSE
SELECT mysql_now(), c1 FROM time_tbl GROUP BY c1 ORDER BY 1,2;

-- select mysql_now with group by index (explain)
--Testcase 2943:
EXPLAIN VERBOSE
SELECT mysql_now(), c1 FROM time_tbl GROUP BY 2 ORDER BY 1,2;

-- select mysql_now with group by having (explain)
--Testcase 2944:
EXPLAIN VERBOSE
SELECT mysql_now(), c1 FROM time_tbl GROUP BY mysql_now(),c1 HAVING mysql_now() > '2000-01-01 00:00:00'::timestamp ORDER BY 1,2;

-- select mysql_now with group by index having (explain)
--Testcase 2945:
EXPLAIN VERBOSE
SELECT mysql_now(), c1 FROM time_tbl GROUP BY 2,1 HAVING mysql_now() > '2000-01-01 00:00:00'::timestamp ORDER BY 1,2;

-- mysql_now constraints with group by (explain)
--Testcase 2946:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_now(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1 ORDER BY 1;

-- mysql_now constraints with group by (result)
--Testcase 2947:
SELECT c1 FROM time_tbl WHERE addtime(mysql_now(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1 ORDER BY 1;

-- select mysql_now and as
--Testcase 2948:
EXPLAIN VERBOSE
SELECT mysql_now() as mysql_now1 FROM time_tbl;



-- MONTHNAME()
-- select monthname (stub function, explain)
--Testcase 2949:
EXPLAIN VERBOSE
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select monthname (stub function, result)
--Testcase 2950:
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select monthname (stub function, not pushdown constraints, explain)
--Testcase 2951:
EXPLAIN VERBOSE
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select monthname (stub function, not pushdown constraints, result)
--Testcase 2952:
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select monthname (stub function, pushdown constraints, explain)
--Testcase 2953:
EXPLAIN VERBOSE
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select monthname (stub function, pushdown constraints, result)
--Testcase 2954:
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select monthname (stub function, monthname in constraints, explain)
--Testcase 2955:
EXPLAIN VERBOSE
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE monthname(c3) = monthname('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select monthname (stub function, monthname in constraints, result)
--Testcase 2956:
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE monthname(c3) = monthname('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select monthname (stub function, monthname in constraints, explain)
--Testcase 2957:
EXPLAIN VERBOSE
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE monthname('2021-01-01 12:00:00'::timestamp) = 'January' ORDER BY 1,2,3,4;

-- select monthname (stub function, monthname in constraints, result)
--Testcase 2958:
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE monthname('2021-01-01 12:00:00'::timestamp) = 'January' ORDER BY 1,2,3,4;

-- select monthname with agg (pushdown, explain)
--Testcase 2959:
EXPLAIN VERBOSE
SELECT max(c3), monthname(max(c3)) FROM time_tbl;

-- select monthname as nest function with agg (pushdown, result)
--Testcase 2960:
SELECT max(c3), monthname(max(c3)) FROM time_tbl;

-- select monthname with non pushdown func and explicit constant (explain)
--Testcase 2961:
EXPLAIN VERBOSE
SELECT monthname(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select monthname with non pushdown func and explicit constant (result)
--Testcase 2962:
SELECT monthname(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select monthname with order by (explain)
--Testcase 2963:
EXPLAIN VERBOSE
SELECT id, monthname(c3 + '1 12:59:10') FROM time_tbl order by id,monthname(c3 + '1 12:59:10');

-- select monthname with order by (result)
--Testcase 2964:
SELECT id, monthname(c3 + '1 12:59:10') FROM time_tbl order by id,monthname(c3 + '1 12:59:10');

-- select monthname with order by index (result)
--Testcase 2965:
SELECT id, monthname(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select monthname with order by index (result)
--Testcase 2966:
SELECT id, monthname(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select monthname with group by (explain)
--Testcase 2967:
EXPLAIN VERBOSE
SELECT max(c3), monthname(c3 + '1 12:59:10') FROM time_tbl group by monthname(c3 + '1 12:59:10') ORDER BY 1,2;

-- select monthname with group by (result)
--Testcase 2968:
SELECT max(c3), monthname(c3 + '1 12:59:10') FROM time_tbl group by monthname(c3 + '1 12:59:10') ORDER BY 1,2;

-- select monthname with group by index (result)
--Testcase 2969:
SELECT id, monthname(c3 + '1 12:59:10') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select monthname with group by index (result)
--Testcase 2970:
SELECT id, monthname(c3 + '1 12:59:10') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select monthname with group by having (explain)
--Testcase 2971:
EXPLAIN VERBOSE
SELECT max(c3), monthname(c3 + '1 12:59:10') FROM time_tbl group by monthname(c3 + '1 12:59:10'), c3 HAVING monthname(c3 + '1 12:59:10') = 'January' ORDER BY 1,2;

-- select monthname with group by having (result)
--Testcase 2972:
SELECT max(c3), monthname(c3 + '1 12:59:10') FROM time_tbl group by monthname(c3 + '1 12:59:10'), c3 HAVING monthname(c3 + '1 12:59:10') = 'January' ORDER BY 1,2;

-- select monthname with group by index having (result)
--Testcase 2973:
SELECT id, monthname(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING monthname(c3 + '1 12:59:10') = 'January' ORDER BY 1,2;

-- select monthname with group by index having (result)
--Testcase 2974:
SELECT id, monthname(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING monthname(c3 + '1 12:59:10') = 'January' ORDER BY 1,2;

-- select monthname and as
--Testcase 2975:
SELECT monthname(date_sub(c3, '1 12:59:10')) as monthname1 FROM time_tbl ORDER BY 1;



-- MONTH()
-- select month (stub function, explain)
--Testcase 2976:
EXPLAIN VERBOSE
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select month (stub function, result)
--Testcase 2977:
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select month (stub function, not pushdown constraints, explain)
--Testcase 2978:
EXPLAIN VERBOSE
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select month (stub function, not pushdown constraints, result)
--Testcase 2979:
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select month (stub function, pushdown constraints, explain)
--Testcase 2980:
EXPLAIN VERBOSE
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select month (stub function, pushdown constraints, result)
--Testcase 2981:
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select month (stub function, month in constraints, explain)
--Testcase 2982:
EXPLAIN VERBOSE
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE month(c3) = month('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select month (stub function, month in constraints, result)
--Testcase 2983:
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE month(c3) = month('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select month (stub function, month in constraints, explain)
--Testcase 2984:
EXPLAIN VERBOSE
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE month('2021-01-01 12:00:00'::timestamp) = '1' ORDER BY 1,2,3,4;

-- select month (stub function, month in constraints, result)
--Testcase 2985:
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE month('2021-01-01 12:00:00'::timestamp) = '1' ORDER BY 1,2,3,4;

-- select month with agg (pushdown, explain)
--Testcase 2986:
EXPLAIN VERBOSE
SELECT max(c3), month(max(c3)) FROM time_tbl;

-- select month as nest function with agg (pushdown, result)
--Testcase 2987:
SELECT max(c3), month(max(c3)) FROM time_tbl;

-- select month with non pushdown func and explicit constant (explain)
--Testcase 2988:
EXPLAIN VERBOSE
SELECT month(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select month with non pushdown func and explicit constant (result)
--Testcase 2989:
SELECT month(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select month with order by (explain)
--Testcase 2990:
EXPLAIN VERBOSE
SELECT id, month(c3 + '1 12:59:10') FROM time_tbl order by id,month(c3 + '1 12:59:10'),id;

-- select month with order by (result)
--Testcase 2991:
SELECT id, month(c3 + '1 12:59:10') FROM time_tbl order by id,month(c3 + '1 12:59:10'),id;

-- select month with order by index (result)
--Testcase 2992:
SELECT id, month(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select month with order by index (result)
--Testcase 2993:
SELECT id, month(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select month with group by (explain)
--Testcase 2994:
EXPLAIN VERBOSE
SELECT max(c3), month(c3 + '1 12:59:10') FROM time_tbl group by month(c3 + '1 12:59:10') ORDER BY 1,2;

-- select month with group by (result)
--Testcase 2995:
SELECT max(c3), month(c3 + '1 12:59:10') FROM time_tbl group by month(c3 + '1 12:59:10') ORDER BY 1,2;

-- select month with group by index (result)
--Testcase 2996:
SELECT id, month(c3 + '1 12:59:10') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select month with group by index (result)
--Testcase 2997:
SELECT id, month(c3 + '1 12:59:10') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select month with group by having (explain)
--Testcase 2998:
EXPLAIN VERBOSE
SELECT max(c3), month(c3 + '1 12:59:10') FROM time_tbl group by month(c3 + '1 12:59:10'), c3 HAVING month(c3 + '1 12:59:10') < 12 ORDER BY 1,2;

-- select month with group by having (result)
--Testcase 2999:
SELECT max(c3), month(c3 + '1 12:59:10') FROM time_tbl group by month(c3 + '1 12:59:10'), c3 HAVING month(c3 + '1 12:59:10') < 12 ORDER BY 1,2;

-- select month with group by index having (result)
--Testcase 3000:
SELECT id, month(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING month(c3 + '1 12:59:10') < 12 ORDER BY 1,2;

-- select month with group by index having (result)
--Testcase 3001:
SELECT id, month(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING month(c3 + '1 12:59:10') < 12 ORDER BY 1,2;

-- select month and as
--Testcase 3002:
SELECT month(date_sub(c3, '1 12:59:10')) as month1 FROM time_tbl ORDER BY 1;



-- MINUTE()
-- select minute (stub function, explain)
--Testcase 3003:
EXPLAIN VERBOSE
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select minute (stub function, result)
--Testcase 3004:
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select minute (stub function, not pushdown constraints, explain)
--Testcase 3005:
EXPLAIN VERBOSE
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select minute (stub function, not pushdown constraints, result)
--Testcase 3006:
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select minute (stub function, pushdown constraints, explain)
--Testcase 3007:
EXPLAIN VERBOSE
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select minute (stub function, pushdown constraints, result)
--Testcase 3008:
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select minute (stub function, minute in constraints, explain)
--Testcase 3009:
EXPLAIN VERBOSE
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE minute(c3) > minute('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select minute (stub function, minute in constraints, result)
--Testcase 3010:
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE minute(c3) > minute('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select minute (stub function, minute in constraints, explain)
--Testcase 3011:
EXPLAIN VERBOSE
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE minute('2021-01-01 12:00:00'::timestamp) < 1 ORDER BY 1,2,3,4;

-- select minute (stub function, minute in constraints, result)
--Testcase 3012:
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE minute('2021-01-01 12:00:00'::timestamp) < 1 ORDER BY 1,2,3,4;

-- select minute with agg (pushdown, explain)
--Testcase 3013:
EXPLAIN VERBOSE
SELECT max(c3), minute(max(c3)) FROM time_tbl;

-- select minute as nest function with agg (pushdown, result)
--Testcase 3014:
SELECT max(c3), minute(max(c3)) FROM time_tbl;

-- select minute with non pushdown func and explicit constant (explain)
--Testcase 3015:
EXPLAIN VERBOSE
SELECT minute(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select minute with non pushdown func and explicit constant (result)
--Testcase 3016:
SELECT minute(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select minute with order by (explain)
--Testcase 3017:
EXPLAIN VERBOSE
SELECT id, minute(c3 + '1 12:59:10') FROM time_tbl order by id,minute(c3 + '1 12:59:10');

-- select minute with order by (result)
--Testcase 3018:
SELECT id, minute(c3 + '1 12:59:10') FROM time_tbl order by id,minute(c3 + '1 12:59:10');

-- select minute with order by index (result)
--Testcase 3019:
SELECT id, minute(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select minute with order by index (result)
--Testcase 3020:
SELECT id, minute(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select minute with group by (explain)
--Testcase 3021:
EXPLAIN VERBOSE
SELECT max(c3), minute(c3 + '1 12:59:10') FROM time_tbl group by minute(c3 + '1 12:59:10') ORDER BY 1,2;

-- select minute with group by (result)
--Testcase 3022:
SELECT max(c3), minute(c3 + '1 12:59:10') FROM time_tbl group by minute(c3 + '1 12:59:10') ORDER BY 1,2;

-- select minute with group by index (result)
--Testcase 3023:
SELECT id, minute(c3 + '1 12:59:10') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select minute with group by index (result)
--Testcase 3024:
SELECT id, minute(c3 + '1 12:59:10') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select minute with group by having (explain)
--Testcase 3025:
EXPLAIN VERBOSE
SELECT max(c3), minute(c3 + '1 12:59:10') FROM time_tbl group by minute(c3 + '1 12:59:10'), c3 HAVING minute(c3 + '1 12:59:10') < 60 ORDER BY 1,2;

-- select minute with group by having (result)
--Testcase 3026:
SELECT max(c3), minute(c3 + '1 12:59:10') FROM time_tbl group by minute(c3 + '1 12:59:10'), c3 HAVING minute(c3 + '1 12:59:10') < 60 ORDER BY 1,2;

-- select minute with group by index having (result)
--Testcase 3027:
SELECT id, minute(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING minute(c3 + '1 12:59:10') < 60 ORDER BY 1,2;

-- select minute with group by index having (result)
--Testcase 3028:
SELECT id, minute(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING minute(c3 + '1 12:59:10') < 60 ORDER BY 1,2;

-- select minute and as
--Testcase 3029:
SELECT minute(date_sub(c3, '1 12:59:10')) as minute1 FROM time_tbl ORDER BY 1;



-- MICROSECOND()
-- select microsecond (stub function, explain)
--Testcase 3030:
EXPLAIN VERBOSE
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select microsecond (stub function, result)
--Testcase 3031:
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select microsecond (stub function, not pushdown constraints, explain)
--Testcase 3032:
EXPLAIN VERBOSE
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select microsecond (stub function, not pushdown constraints, result)
--Testcase 3033:
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select microsecond (stub function, pushdown constraints, explain)
--Testcase 3034:
EXPLAIN VERBOSE
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select microsecond (stub function, pushdown constraints, result)
--Testcase 3035:
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select microsecond (stub function, microsecond in constraints, explain)
--Testcase 3036:
EXPLAIN VERBOSE
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE microsecond(c3) = microsecond('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select microsecond (stub function, microsecond in constraints, result)
--Testcase 3037:
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE microsecond(c3) = microsecond('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select microsecond (stub function, microsecond in constraints, explain)
--Testcase 3038:
EXPLAIN VERBOSE
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE microsecond('2021-01-01 12:00:00'::timestamp) = '0' ORDER BY 1,2,3,4;

-- select microsecond (stub function, microsecond in constraints, result)
--Testcase 3039:
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE microsecond('2021-01-01 12:00:00'::timestamp) = '0' ORDER BY 1,2,3,4;

-- select microsecond with agg (pushdown, explain)
--Testcase 3040:
EXPLAIN VERBOSE
SELECT max(c3), microsecond(max(c3)) FROM time_tbl;

-- select microsecond as nest function with agg (pushdown, result)
--Testcase 3041:
SELECT max(c3), microsecond(max(c3)) FROM time_tbl;

-- select microsecond with non pushdown func and explicit constant (explain)
--Testcase 3042:
EXPLAIN VERBOSE
SELECT microsecond(date_sub(c3, '1 12:59:10.999')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select microsecond with non pushdown func and explicit constant (result)
--Testcase 3043:
SELECT microsecond(date_sub(c3, '1 12:59:10.999')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select microsecond with order by (explain)
--Testcase 3044:
EXPLAIN VERBOSE
SELECT id, microsecond(c3 + '1 12:59:10.999') FROM time_tbl order by id,microsecond(c3 + '1 12:59:10.999');

-- select microsecond with order by (result)
--Testcase 3045:
SELECT id, microsecond(c3 + '1 12:59:10.999') FROM time_tbl order by id,microsecond(c3 + '1 12:59:10.999');

-- select microsecond with order by index (result)
--Testcase 3046:
SELECT id, microsecond(c3 + '1 12:59:10.999') FROM time_tbl order by 2,1;

-- select microsecond with order by index (result)
--Testcase 3047:
SELECT id, microsecond(c3 + '1 12:59:10.999') FROM time_tbl order by 1,2;

-- select microsecond with group by (explain)
--Testcase 3048:
EXPLAIN VERBOSE
SELECT max(c3), microsecond(c3 + '1 12:59:10.999') FROM time_tbl group by microsecond(c3 + '1 12:59:10.999') ORDER BY 1,2;

-- select microsecond with group by (result)
--Testcase 3049:
SELECT max(c3), microsecond(c3 + '1 12:59:10.999') FROM time_tbl group by microsecond(c3 + '1 12:59:10.999') ORDER BY 1,2;

-- select microsecond with group by index (result)
--Testcase 3050:
SELECT id, microsecond(c3 + '1 12:59:10.999') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select microsecond with group by index (result)
--Testcase 3051:
SELECT id, microsecond(c3 + '1 12:59:10.999') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select microsecond with group by having (explain)
--Testcase 3052:
EXPLAIN VERBOSE
SELECT max(c3), microsecond(c3 + '1 12:59:10.999') FROM time_tbl group by microsecond(c3 + '1 12:59:10.999'), c3 HAVING microsecond(c3 + '1 12:59:10.999') > 1000 ORDER BY 1,2;

-- select microsecond with group by having (result)
--Testcase 3053:
SELECT max(c3), microsecond(c3 + '1 12:59:10.999') FROM time_tbl group by microsecond(c3 + '1 12:59:10.999'), c3 HAVING microsecond(c3 + '1 12:59:10.999') > 1000 ORDER BY 1,2;

-- select microsecond with group by index having (result)
--Testcase 3054:
SELECT id, microsecond(c3 + '1 12:59:10.999'), c3 FROM time_tbl group by 3, 2, 1 HAVING microsecond(c3 + '1 12:59:10.999') > 1000 ORDER BY 1,2;

-- select microsecond with group by index having (result)
--Testcase 3055:
SELECT id, microsecond(c3 + '1 12:59:10.999'), c3 FROM time_tbl group by 1, 2, 3 HAVING microsecond(c3 + '1 12:59:10.999') > 1000 ORDER BY 1,2;

-- select microsecond and as
--Testcase 3056:
SELECT microsecond(date_sub(c3, '1 12:59:10.999')) as microsecond1 FROM time_tbl ORDER BY 1;



-- MAKETIME()
-- select maketime (stub function, explain)
--Testcase 3057:
EXPLAIN VERBOSE
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl ORDER BY 1;

-- select maketime (stub function, result)
--Testcase 3058:
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl ORDER BY 1;

-- select maketime (stub function, not pushdown constraints, explain)
--Testcase 3059:
EXPLAIN VERBOSE
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1;

-- select maketime (stub function, not pushdown constraints, result)
--Testcase 3060:
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1;

-- select maketime (stub function, pushdown constraints, explain)
--Testcase 3061:
EXPLAIN VERBOSE
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl WHERE id != 200 ORDER BY 1;

-- select maketime (stub function, pushdown constraints, result)
--Testcase 3062:
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl WHERE id != 200 ORDER BY 1;

-- select maketime (stub function, maketime in constraints, explain)
--Testcase 3063:
EXPLAIN VERBOSE
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl WHERE maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) > '12:59:10'::time ORDER BY 1;

-- select maketime (stub function, maketime in constraints, result)
--Testcase 3064:
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl WHERE maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) > '12:59:10'::time ORDER BY 1;
-- select maketime with agg (pushdown, explain)
--Testcase 3065:
EXPLAIN VERBOSE
SELECT max(c3), maketime(18, 15, 30) FROM time_tbl ORDER BY 1,2;

-- select maketime as nest function with agg (pushdown, result)
--Testcase 3066:
SELECT max(c3), maketime(18, 15, 30) FROM time_tbl ORDER BY 1,2;

-- select maketime with non pushdown func and explicit constant (explain)
--Testcase 3067:
EXPLAIN VERBOSE
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select maketime with non pushdown func and explicit constant (result)
--Testcase 3068:
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select maketime with order by (explain)
--Testcase 3069:
EXPLAIN VERBOSE
SELECT id, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl order by id,maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30);

-- select maketime with order by (result)
--Testcase 3070:
SELECT id, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl order by id,maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30);

-- select maketime with order by index (result)
--Testcase 3071:
SELECT id, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl order by 2,1;

-- select maketime with order by index (result)
--Testcase 3072:
SELECT id, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl order by 1,2;

-- select maketime with group by (explain)
--Testcase 3073:
EXPLAIN VERBOSE
SELECT max(c3), maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl group by maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30), c3 ORDER BY 1,2;

-- select maketime with group by (result)
--Testcase 3074:
SELECT max(c3), maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl group by maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30), c3 ORDER BY 1,2;

-- select maketime with group by index (result)
--Testcase 3075:
SELECT id, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select maketime with group by index (result)
--Testcase 3076:
SELECT id, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select maketime with group by index having (result)
--Testcase 3077:
SELECT id, c3, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl group by 3, 2, 1 HAVING maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) > '12:00:00'::time ORDER BY 1,2,3;

-- select maketime with group by index having (result)
--Testcase 3078:
SELECT id, c3, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl group by 1, 2, 3 HAVING maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) > '12:00:00'::time ORDER BY 1,2,3;

-- select maketime and as
--Testcase 3079:
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) as maketime1 FROM time_tbl ORDER BY 1;



-- MAKEDATE()
-- select makedate (stub function, explain)
--Testcase 3080:
EXPLAIN VERBOSE
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl ORDER BY 1;

-- select makedate (stub function, result)
--Testcase 3081:
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl ORDER BY 1;

-- select makedate (stub function, not pushdown constraints, explain)
--Testcase 3082:
EXPLAIN VERBOSE
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1;

-- select makedate (stub function, not pushdown constraints, result)
--Testcase 3083:
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1;

-- select makedate (stub function, pushdown constraints, explain)
--Testcase 3084:
EXPLAIN VERBOSE
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl WHERE id != 200 ORDER BY 1;

-- select makedate (stub function, pushdown constraints, result)
--Testcase 3085:
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl WHERE id != 200 ORDER BY 1;

-- select makedate (stub function, makedate in constraints, explain)
--Testcase 3086:
EXPLAIN VERBOSE
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl WHERE makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) < '2021-01-02'::date ORDER BY 1;

-- select makedate (stub function, makedate in constraints, result)
--Testcase 3087:
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl WHERE makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) < '2021-01-02'::date ORDER BY 1;
-- select makedate with agg (pushdown, explain)
--Testcase 3088:
EXPLAIN VERBOSE
SELECT max(c3), makedate(18, 90) FROM time_tbl;

-- select makedate as nest function with agg (pushdown, result)
--Testcase 3089:
SELECT max(c3), makedate(18, 90) FROM time_tbl;

-- select makedate with non pushdown func and explicit constant (explain)
--Testcase 3090:
EXPLAIN VERBOSE
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select makedate with non pushdown func and explicit constant (result)
--Testcase 3091:
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select makedate with order by (explain)
--Testcase 3092:
EXPLAIN VERBOSE
SELECT id, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl order by id,makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90);

-- select makedate with order by (result)
--Testcase 3093:
SELECT id, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl order by id,makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90);

-- select makedate with order by index (result)
--Testcase 3094:
SELECT id, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl order by 2,1;

-- select makedate with order by index (result)
--Testcase 3095:
SELECT id, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl order by 1,2;

-- select makedate with group by (explain)
--Testcase 3096:
EXPLAIN VERBOSE
SELECT max(c3), makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl group by makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90), c3 ORDER BY 1,2;

-- select makedate with group by (result)
--Testcase 3097:
SELECT max(c3), makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl group by makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90), c3 ORDER BY 1,2;

-- select makedate with group by index (result)
--Testcase 3098:
SELECT id, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select makedate with group by index (result)
--Testcase 3099:
SELECT id, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select makedate with group by index having (result)
--Testcase 3100:
SELECT id, c3, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl group by 3, 2, 1 HAVING makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) > '2008-03-31'::date ORDER BY 1,2,3;

-- select makedate with group by index having (result)
--Testcase 3101:
SELECT id, c3, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl group by 1, 2, 3 HAVING makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) > '2008-03-31'::date ORDER BY 1,2,3;

-- select makedate and as
--Testcase 3102:
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) as makedate1 FROM time_tbl ORDER BY 1;



-- LOCALTIMESTAMP, LOCALTIMESTAMP()
-- mysql_localtimestamp is mutable function, some executes will return different result
-- select mysql_localtimestamp (stub function, explain)
--Testcase 3103:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp() FROM time_tbl;

-- select mysql_localtimestamp (stub function, not pushdown constraints, explain)
--Testcase 3104:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp() FROM time_tbl WHERE to_hex(id) > '0';

-- select mysql_localtimestamp (stub function, pushdown constraints, explain)
--Testcase 3105:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp() FROM time_tbl WHERE id = 1;

-- select mysql_localtimestamp (stub function, mysql_localtimestamp in constraints, explain)
--Testcase 3106:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp() FROM time_tbl WHERE mysql_localtimestamp() > '2000-01-01 00:00:00'::timestamp;

-- mysql_localtimestamp in constrains (stub function, explain)
--Testcase 3107:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE mysql_localtimestamp() > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- mysql_localtimestamp in constrains (stub function, result)
--Testcase 3108:
SELECT c1 FROM time_tbl WHERE mysql_localtimestamp() > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- mysql_localtimestamp as parameter of addtime(stub function, explain)
--Testcase 3109:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtimestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- mysql_localtimestamp as parameter of addtime(stub function, result)
--Testcase 3110:
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtimestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- select mysql_localtimestamp and agg (pushdown, explain)
--Testcase 3111:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), sum(id) FROM time_tbl;

-- select mysql_localtimestamp and log2 (pushdown, explain)
--Testcase 3112:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), log2(id) FROM time_tbl;

-- select mysql_localtimestamp with non pushdown func and explicit constant (explain)
--Testcase 3113:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), to_hex(id), 4 FROM time_tbl;

-- select mysql_localtimestamp with order by (explain)
--Testcase 3114:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), c1 FROM time_tbl ORDER BY c1;

-- select mysql_localtimestamp with order by index (explain)
--Testcase 3115:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), c1 FROM time_tbl ORDER BY 2;

-- mysql_localtimestamp constraints with order by (explain)
--Testcase 3116:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtimestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- mysql_localtimestamp constraints with order by (result)
--Testcase 3117:
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtimestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- select mysql_localtimestamp with group by (explain)
--Testcase 3118:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), c1 FROM time_tbl GROUP BY c1 ORDER BY 1,2;

-- select mysql_localtimestamp with group by index (explain)
--Testcase 3119:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), c1 FROM time_tbl GROUP BY 2 ORDER BY 1,2;

-- select mysql_localtimestamp with group by having (explain)
--Testcase 3120:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), c1 FROM time_tbl GROUP BY mysql_localtimestamp(),c1 HAVING mysql_localtimestamp() > '2000-01-01 00:00:00'::timestamp ORDER BY 1,2;

-- select mysql_localtimestamp with group by index having (explain)
--Testcase 3121:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), c1 FROM time_tbl GROUP BY 2,1 HAVING mysql_localtimestamp() > '2000-01-01 00:00:00'::timestamp ORDER BY 1,2;

-- mysql_localtimestamp constraints with group by (explain)
--Testcase 3122:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtimestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1 ORDER BY 1;

-- mysql_localtimestamp constraints with group by (result)
--Testcase 3123:
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtimestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1 ORDER BY 1;

-- select mysql_localtimestamp and as
--Testcase 3124:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp() as mysql_localtimestamp1 FROM time_tbl ORDER BY 1;



-- LOCALTIME(), LOCALTIME
-- mysql_localtime is mutable function, some executes will return different result
-- select mysql_localtime (stub function, explain)
--Testcase 3125:
EXPLAIN VERBOSE
SELECT mysql_localtime() FROM time_tbl;

-- select mysql_localtime (stub function, not pushdown constraints, explain)
--Testcase 3126:
EXPLAIN VERBOSE
SELECT mysql_localtime() FROM time_tbl WHERE to_hex(id) > '0';

-- select mysql_localtime (stub function, pushdown constraints, explain)
--Testcase 3127:
EXPLAIN VERBOSE
SELECT mysql_localtime() FROM time_tbl WHERE id = 1;

-- select mysql_localtime (stub function, mysql_localtime in constraints, explain)
--Testcase 3128:
EXPLAIN VERBOSE
SELECT mysql_localtime() FROM time_tbl WHERE mysql_localtime() > '2000-01-01 00:00:00'::timestamp;

-- mysql_localtime in constrains (stub function, explain)
--Testcase 3129:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE mysql_localtime() > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- mysql_localtime in constrains (stub function, result)
--Testcase 3130:
SELECT c1 FROM time_tbl WHERE mysql_localtime() > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- mysql_localtime as parameter of addtime(stub function, explain)
--Testcase 3131:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtime(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- mysql_localtime as parameter of addtime(stub function, result)
--Testcase 3132:
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtime(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY 1;

-- select mysql_localtime and agg (pushdown, explain)
--Testcase 3133:
EXPLAIN VERBOSE
SELECT mysql_localtime(), sum(id) FROM time_tbl;

-- select mysql_localtime and log2 (pushdown, explain)
--Testcase 3134:
EXPLAIN VERBOSE
SELECT mysql_localtime(), log2(id) FROM time_tbl;

-- select mysql_localtime with non pushdown func and explicit constant (explain)
--Testcase 3135:
EXPLAIN VERBOSE
SELECT mysql_localtime(), to_hex(id), 4 FROM time_tbl;

-- select mysql_localtime with order by (explain)
--Testcase 3136:
EXPLAIN VERBOSE
SELECT mysql_localtime(), c1 FROM time_tbl ORDER BY c1;

-- select mysql_localtime with order by index (explain)
--Testcase 3137:
EXPLAIN VERBOSE
SELECT mysql_localtime(), c1 FROM time_tbl ORDER BY 2;

-- mysql_localtime constraints with order by (explain)
--Testcase 3138:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtime(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- mysql_localtime constraints with order by (result)
--Testcase 3139:
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtime(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- select mysql_localtime with group by (explain)
--Testcase 3140:
EXPLAIN VERBOSE
SELECT mysql_localtime(), c1 FROM time_tbl GROUP BY c1 ORDER BY 1,2;

-- select mysql_localtime with group by index (explain)
--Testcase 3141:
EXPLAIN VERBOSE
SELECT mysql_localtime(), c1 FROM time_tbl GROUP BY 2 ORDER BY 1,2;

-- select mysql_localtime with group by having (explain)
--Testcase 3142:
EXPLAIN VERBOSE
SELECT mysql_localtime(), c1 FROM time_tbl GROUP BY mysql_localtime(),c1 HAVING mysql_localtime() > '2000-01-01 00:00:00'::timestamp ORDER BY 1,2;

-- select mysql_localtime with group by index having (explain)
--Testcase 3143:
EXPLAIN VERBOSE
SELECT mysql_localtime(), c1 FROM time_tbl GROUP BY 2,1 HAVING mysql_localtime() > '2000-01-01 00:00:00'::timestamp ORDER BY 1,2;

-- mysql_localtime constraints with group by (explain)
--Testcase 3144:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtime(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1 ORDER BY 1;

-- mysql_localtime constraints with group by (result)
--Testcase 3145:
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtime(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1 ORDER BY 1;

-- select mysql_localtime and as
--Testcase 3146:
EXPLAIN VERBOSE
SELECT mysql_localtime() as mysql_localtime1 FROM time_tbl ORDER BY 1;



-- LAST_DAY()
-- select last_day (stub function, explain)
--Testcase 3147:
EXPLAIN VERBOSE
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select last_day (stub function, result)
--Testcase 3148:
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3,4;

-- select last_day (stub function, not pushdown constraints, explain)
--Testcase 3149:
EXPLAIN VERBOSE
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select last_day (stub function, not pushdown constraints, result)
--Testcase 3150:
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select last_day (stub function, pushdown constraints, explain)
--Testcase 3151:
EXPLAIN VERBOSE
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select last_day (stub function, pushdown constraints, result)
--Testcase 3152:
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select last_day (stub function, last_day in constraints, explain)
--Testcase 3153:
EXPLAIN VERBOSE
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE last_day(c3) > last_day('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select last_day (stub function, last_day in constraints, result)
--Testcase 3154:
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE last_day(c3) > last_day('2000-01-01'::timestamp) ORDER BY 1,2,3,4;

-- select last_day (stub function, last_day in constraints, explain)
--Testcase 3155:
EXPLAIN VERBOSE
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE last_day('2021-01-01 12:00:00'::timestamp) = '2021-01-31' ORDER BY 1,2,3,4;

-- select last_day (stub function, last_day in constraints, result)
--Testcase 3156:
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE last_day('2021-01-01 12:00:00'::timestamp) = '2021-01-31' ORDER BY 1,2,3,4;

-- select last_day with agg (pushdown, explain)
--Testcase 3157:
EXPLAIN VERBOSE
SELECT max(c3), last_day(max(c3)) FROM time_tbl;

-- select last_day as nest function with agg (pushdown, result)
--Testcase 3158:
SELECT max(c3), last_day(max(c3)) FROM time_tbl;

-- select last_day with non pushdown func and explicit constant (explain)
--Testcase 3159:
EXPLAIN VERBOSE
SELECT last_day(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select last_day with non pushdown func and explicit constant (result)
--Testcase 3160:
SELECT last_day(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select last_day with order by (explain)
--Testcase 3161:
EXPLAIN VERBOSE
SELECT id, last_day(c3 + '1 12:59:10') FROM time_tbl order by id,last_day(c3 + '1 12:59:10');

-- select last_day with order by (result)
--Testcase 3162:
SELECT id, last_day(c3 + '1 12:59:10') FROM time_tbl order by id,last_day(c3 + '1 12:59:10');

-- select last_day with order by index (result)
--Testcase 3163:
SELECT id, last_day(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select last_day with order by index (result)
--Testcase 3164:
SELECT id, last_day(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select last_day with group by (explain)
--Testcase 3165:
EXPLAIN VERBOSE
SELECT max(c3), last_day(c3 + '1 12:59:10') FROM time_tbl group by last_day(c3 + '1 12:59:10') ORDER BY 1,2;

-- select last_day with group by (result)
--Testcase 3166:
SELECT max(c3), last_day(c3 + '1 12:59:10') FROM time_tbl group by last_day(c3 + '1 12:59:10') ORDER BY 1,2;

-- select last_day with group by index (result)
--Testcase 3167:
SELECT id, last_day(c3 + '1 12:59:10') FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select last_day with group by index (result)
--Testcase 3168:
SELECT id, last_day(c3 + '1 12:59:10') FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select last_day with group by having (explain)
--Testcase 3169:
EXPLAIN VERBOSE
SELECT max(c3), last_day(c3 + '1 12:59:10') FROM time_tbl group by last_day(c3 + '1 12:59:10'), c3 HAVING last_day(c3 + '1 12:59:10') > '2001-01-31'::date ORDER BY 1,2;

-- select last_day with group by having (result)
--Testcase 3170:
SELECT max(c3), last_day(c3 + '1 12:59:10') FROM time_tbl group by last_day(c3 + '1 12:59:10'), c3 HAVING last_day(c3 + '1 12:59:10') > '2001-01-31'::date ORDER BY 1,2;

-- select last_day with group by index having (result)
--Testcase 3171:
SELECT id, last_day(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING last_day(c3 + '1 12:59:10') > '2001-01-31'::date ORDER BY 1,2,3;

-- select last_day with group by index having (result)
--Testcase 3172:
SELECT id, last_day(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING last_day(c3 + '1 12:59:10') > '2001-01-31'::date ORDER BY 1,2,3;

-- select last_day and as
--Testcase 3173:
SELECT last_day(date_sub(c3, '1 12:59:10')) as last_day1 FROM time_tbl ORDER BY 1;



-- HOUR()
-- select hour (stub function, explain)
--Testcase 3174:
EXPLAIN VERBOSE
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl ORDER BY 1,2;

-- select hour (stub function, result)
--Testcase 3175:
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl ORDER BY 1,2;

-- select hour (stub function, not pushdown constraints, explain)
--Testcase 3176:
EXPLAIN VERBOSE
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select hour (stub function, not pushdown constraints, result)
--Testcase 3177:
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select hour (stub function, pushdown constraints, explain)
--Testcase 3178:
EXPLAIN VERBOSE
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select hour (stub function, pushdown constraints, result)
--Testcase 3179:
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select hour (stub function, hour in constraints, explain)
--Testcase 3180:
EXPLAIN VERBOSE
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE hour(c1) = 12 ORDER BY 1,2;

-- select hour (stub function, hour in constraints, result)
--Testcase 3181:
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE hour(c1) = 12 ORDER BY 1,2;

-- select hour (stub function, hour in constraints, explain)
--Testcase 3182:
EXPLAIN VERBOSE
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE hour('22:00:00'::time) > '12' ORDER BY 1,2;

-- select hour (stub function, hour in constraints, result)
--Testcase 3183:
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE hour('22:00:00'::time) > '12' ORDER BY 1,2;

-- select hour with agg (pushdown, explain)
--Testcase 3184:
EXPLAIN VERBOSE
SELECT max(c1), hour(max(c1)) FROM time_tbl;

-- select hour as nest function with agg (pushdown, result)
--Testcase 3185:
SELECT max(c1), hour(max(c1)) FROM time_tbl;

-- select hour with non pushdown func and explicit constant (explain)
--Testcase 3186:
EXPLAIN VERBOSE
SELECT hour(maketime(18, 15, 30)), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select hour with non pushdown func and explicit constant (result)
--Testcase 3187:
SELECT hour(maketime(18, 15, 30)), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select hour with order by (explain)
--Testcase 3188:
EXPLAIN VERBOSE
SELECT id, hour(c1), hour('23:00:00'::time) FROM time_tbl order by id,hour(c1), hour('23:00:00'::time);

-- select hour with order by (result)
--Testcase 3189:
SELECT id, hour(c1), hour('23:00:00'::time) FROM time_tbl order by id,hour(c1), hour('23:00:00'::time);

-- select hour with order by index (result)
--Testcase 3190:
SELECT id, hour(c1), hour('23:00:00'::time) FROM time_tbl order by 3,2,1;

-- select hour with order by index (result)
--Testcase 3191:
SELECT id, hour(c1), hour('23:00:00'::time) FROM time_tbl order by 1,2,3;

-- select hour with group by (explain)
--Testcase 3192:
EXPLAIN VERBOSE
SELECT max(c3), hour('23:00:00'::time) FROM time_tbl group by hour('05:00:00'::time) ORDER BY 1,2;

-- select hour with group by (result)
--Testcase 3193:
SELECT max(c3), hour('23:00:00'::time) FROM time_tbl group by hour('05:00:00'::time) ORDER BY 1,2;

-- select hour with group by index (result)
--Testcase 3194:
SELECT id, hour(c1), hour('23:00:00'::time) FROM time_tbl group by 3,2,1 ORDER BY 1,2,3;

-- select hour with group by index (result)
--Testcase 3195:
SELECT id, hour(c1), hour('23:00:00'::time) FROM time_tbl group by 1,2,3 ORDER BY 1,2,3;

-- select hour with group by having (explain)
--Testcase 3196:
EXPLAIN VERBOSE
SELECT max(c3), hour(c1), hour('23:00:00'::time) FROM time_tbl group by hour(c1),hour('23:00:00'::time), c1,c3 HAVING hour(c1) < 24 ORDER BY 1,2,3;

-- select hour with group by having (result)
--Testcase 3197:
SELECT max(c3), hour(c1), hour('23:00:00'::time) FROM time_tbl group by hour(c1),hour('23:00:00'::time), c1,c3 HAVING hour(c1) < 24 ORDER BY 1,2,3;

-- select hour with group by index having (result)
--Testcase 3198:
SELECT id, c1, hour(c1), hour('23:00:00'::time) FROM time_tbl group by 4, 3, 2, 1 HAVING hour(c1) < 24 ORDER BY 1,2,3,4;

-- select hour with group by index having (result)
--Testcase 3199:
SELECT id, c1, hour(c1), hour('23:00:00'::time) FROM time_tbl group by 1, 2, 3, 4 HAVING hour(c1) < 24 ORDER BY 1,2,3,4;

-- select hour and as
--Testcase 3200:
SELECT hour(c1) as hour1, hour('23:00:00'::time) as hour2 FROM time_tbl ORDER BY 1,2;

-- GET_FORMAT()
-- Returns a format string. This function is useful in combination with the DATE_FORMAT() and the STR_TO_DATE() functions.

-- select get_format (stub function, explain)
--Testcase 3201:
EXPLAIN VERBOSE
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl ORDER BY 1,2,3,4;

-- select get_format (stub function, result)
--Testcase 3202:
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl ORDER BY 1,2,3,4;

-- select get_format (stub function, not pushdown constraints, explain)
--Testcase 3203:
EXPLAIN VERBOSE
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select get_format (stub function, not pushdown constraints, result)
--Testcase 3204:
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3,4;

-- select get_format (stub function, pushdown constraints, explain)
--Testcase 3205:
EXPLAIN VERBOSE
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select get_format (stub function, pushdown constraints, result)
--Testcase 3206:
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE id != 0 ORDER BY 1,2,3,4;

-- select get_format (stub function, get_format in constraints, explain)
--Testcase 3207:
EXPLAIN VERBOSE
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE get_format('date', 'usa') IS NOT NULL ORDER BY 1,2,3,4;

-- select get_format (stub function, get_format in constraints, result)
--Testcase 3208:
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE get_format('date', 'usa') IS NOT NULL ORDER BY 1,2,3,4;

-- select get_format (stub function, get_format in constraints, explain)
--Testcase 3209:
EXPLAIN VERBOSE
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE date_format(c3, get_format('datetime', 'jis')) IS NOT NULL ORDER BY 1,2,3,4;

-- select get_format (stub function, get_format in constraints, result)
--Testcase 3210:
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE date_format(c3, get_format('datetime', 'jis')) IS NOT NULL ORDER BY 1,2,3,4;

-- select get_format as nest function with agg (pushdown, explain)
--Testcase 3211:
EXPLAIN VERBOSE
SELECT max(c2), date_format(max(c3), get_format('datetime', 'jis')) FROM time_tbl;

-- select get_format as nest function with agg (pushdown, result)
--Testcase 3212:
SELECT max(c2), date_format(max(c3), get_format('datetime', 'jis')) FROM time_tbl;

-- select get_format with non pushdown func and explicit constant (explain)
--Testcase 3213:
EXPLAIN VERBOSE
SELECT get_format('datetime', 'jis'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select get_format with non pushdown func and explicit constant (result)
--Testcase 3214:
SELECT get_format('datetime', 'jis'), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select get_format with order by (explain)
--Testcase 3215:
EXPLAIN VERBOSE
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl order by id,date_format(c3 + '1 12:59:10', get_format('datetime', 'jis'));

-- select get_format with order by (result)
--Testcase 3216:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl order by id,date_format(c3 + '1 12:59:10', get_format('datetime', 'jis'));

-- select get_format with order by index (result)
--Testcase 3217:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl order by 2,1;

-- select get_format with order by index (result)
--Testcase 3218:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl order by 1,2;

-- select get_format with group by (explain)
--Testcase 3219:
EXPLAIN VERBOSE
SELECT count(id), date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl group by date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) ORDER BY 1,2;

-- select get_format with group by (result)
--Testcase 3220:
SELECT count(id), date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl group by date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) ORDER BY 1,2;

-- select get_format with group by index (result)
--Testcase 3221:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl group by 2,1 ORDER BY 1,2;

-- select get_format with group by index (result)
--Testcase 3222:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl group by 1,2 ORDER BY 1,2;

-- select get_format with group by index having (result)
--Testcase 3223:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')), c3 FROM time_tbl group by 3,2,1 HAVING date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) > '2000-01-02' ORDER BY 1,2,3;

-- select get_format with group by index having (result)
--Testcase 3224:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')), c3 FROM time_tbl group by 1,2,3 HAVING date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) > '2000-01-02' ORDER BY 1,2,3;

-- select get_format and as
--Testcase 3225:
SELECT get_format('datetime', 'jis') as get_format1 FROM time_tbl ORDER BY 1;

-- FROM_UNIXTIME()
-- select from_unixtime (stub function, explain)
--Testcase 3226:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl ORDER BY 1,2;

-- select from_unixtime (stub function, result)
--Testcase 3227:
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl ORDER BY 1,2;

-- select from_unixtime (stub function, not pushdown constraints, explain)
--Testcase 3228:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE to_hex(id) > '0' ORDER BY 1,2;

-- select from_unixtime (stub function, not pushdown constraints, result)
--Testcase 3229:
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE to_hex(id) > '0' ORDER BY 1,2;

-- select from_unixtime (stub function, pushdown constraints, explain)
--Testcase 3230:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE id = 1 ORDER BY 1,2;

-- select from_unixtime (stub function, pushdown constraints, result)
--Testcase 3231:
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE id = 1 ORDER BY 1,2;

-- select from_unixtime (stub function, from_unixtime in constraints, explain)
--Testcase 3232:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE from_unixtime(id + 1447430881) > from_unixtime(1447430881) ORDER BY 1,2;

-- select from_unixtime (stub function, from_unixtime in constraints, result)
--Testcase 3233:
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE from_unixtime(id + 1447430881) > from_unixtime(1447430881) ORDER BY 1,2;

-- select from_unixtime and agg (pushdown, explain)
--Testcase 3234:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), sum(id) FROM time_tbl ORDER BY 1,2;

-- select from_unixtime and log2 (pushdown, result)
--Testcase 3235:
SELECT from_unixtime(1447430881), log2(id) FROM time_tbl ORDER BY 1,2;

-- select from_unixtime with non pushdown func and explicit constant (explain)
--Testcase 3236:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select from_unixtime with order by (explain)
--Testcase 3237:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x'), c1 FROM time_tbl ORDER BY from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x');

-- select from_unixtime with order by index (explain)
--Testcase 3238:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x'), c1 FROM time_tbl ORDER BY 1,2,3;

-- from_unixtime constraints with order by (explain)
--Testcase 3239:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE from_unixtime(id + 1447430881) > from_unixtime(1447430881) ORDER BY from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x');

-- from_unixtime constraints with order by (result)
--Testcase 3240:
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE from_unixtime(id + 1447430881) > from_unixtime(1447430881) ORDER BY from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x');

-- select from_unixtime with group by (explain)
--Testcase 3241:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x'), c1 FROM time_tbl GROUP BY c1,id ORDER BY 1,2,3;

-- select from_unixtime with group by index (explain)
--Testcase 3242:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x'), c1 FROM time_tbl GROUP BY 1,2,3 ORDER BY 1,2,3;

-- select from_unixtime with group by index having (explain)
--Testcase 3243:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x'), c1 FROM time_tbl GROUP BY 1,2,3 HAVING from_unixtime(1447430881) = '2015-11-13 16:08:01' ORDER BY 1,2,3;

-- select from_unixtime with group by index having (result)
--Testcase 3244:
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x'), c1 FROM time_tbl GROUP BY 1,2,3 HAVING from_unixtime(1447430881) = '2015-11-13 16:08:01' ORDER BY 1,2,3;

-- select from_unixtime and as
--Testcase 3245:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881) as from_unixtime1, from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') as from_unixtime2 FROM time_tbl ORDER BY 1,2;



-- FROM_DAYS()
-- select from_days (stub function, explain)
--Testcase 3246:
EXPLAIN VERBOSE
SELECT from_days(id + 200719) FROM time_tbl ORDER BY 1;

-- select from_days (stub function, result)
--Testcase 3247:
SELECT from_days(id + 200719) FROM time_tbl ORDER BY 1;

-- select from_days (stub function, not pushdown constraints, explain)
--Testcase 3248:
EXPLAIN VERBOSE
SELECT from_days(id + 200719) FROM time_tbl WHERE to_hex(id) > '0' ORDER BY 1;

-- select from_days (stub function, not pushdown constraints, result)
--Testcase 3249:
SELECT from_days(id + 200719) FROM time_tbl WHERE to_hex(id) > '0' ORDER BY 1;

-- select from_days (stub function, pushdown constraints, explain)
--Testcase 3250:
EXPLAIN VERBOSE
SELECT from_days(id + 200719) FROM time_tbl WHERE id = 1 ORDER BY 1;

-- select from_days (stub function, pushdown constraints, result)
--Testcase 3251:
SELECT from_days(id + 200719) FROM time_tbl WHERE id = 1 ORDER BY 1;

-- from_days in constrains (stub function, explain)
--Testcase 3252:
EXPLAIN VERBOSE
SELECT from_days(id + 200719) FROM time_tbl WHERE from_days(id + 200719) > from_days(day('2001-01-01'::date)) ORDER BY 1;

-- from_days in constrains (stub function, result)
--Testcase 3253:
SELECT from_days(id + 200719) FROM time_tbl WHERE from_days(id + 200719) > from_days(day('2001-01-01'::date)) ORDER BY 1;

-- select from_days and agg (pushdown, explain)
--Testcase 3254:
EXPLAIN VERBOSE
SELECT from_days(max(id) + 200719), sum(id) FROM time_tbl;

-- select from_days and agg (pushdown, result)
--Testcase 3255:
SELECT from_days(max(id) + 200719), sum(id) FROM time_tbl;

-- select from_days and log2 (pushdown, explain)
--Testcase 3256:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), log2(id) FROM time_tbl ORDER BY 1,2;

-- select from_days and log2 (pushdown, result)
--Testcase 3257:
SELECT from_days(id + 200719), log2(id) FROM time_tbl ORDER BY 1,2;

-- select from_days with non pushdown func and explicit constant (explain)
--Testcase 3258:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), to_hex(id), 4 FROM time_tbl ORDER BY 1,2;

-- select from_days with order by (explain)
--Testcase 3259:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), c1 FROM time_tbl ORDER BY c1,from_days(id + 200719);

-- select from_days with order by index (explain)
--Testcase 3260:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), c1 FROM time_tbl ORDER BY 1,2;

-- from_days constraints with order by (explain)
--Testcase 3261:
EXPLAIN VERBOSE
SELECT from_days(id + 200719) FROM time_tbl WHERE from_days(id + 200719) > from_days(day('2001-01-01'::date)) ORDER BY from_days(id + 200719);

-- from_days constraints with order by (result)
--Testcase 3262:
SELECT from_days(id + 200719) FROM time_tbl WHERE from_days(id + 200719) > from_days(day('2001-01-01'::date)) ORDER BY from_days(id + 200719);

-- select from_days with group by (explain)
--Testcase 3263:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), c1 FROM time_tbl GROUP BY c1,id ORDER BY 1,2;

-- select from_days with group by index (explain)
--Testcase 3264:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), c1 FROM time_tbl GROUP BY 1,2 ORDER BY 1,2;

-- select from_days with group by having (explain)
--Testcase 3265:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), c1 FROM time_tbl GROUP BY from_days(id + 200719),c1,id HAVING from_days(id + 200719) > '0549-07-21' ORDER BY 1,2;

-- select from_days with group by index having (result)
--Testcase 3266:
SELECT id, from_days(id + 200719), c1 FROM time_tbl GROUP BY 1,2,3 HAVING from_days(id + 200719) > '0549-07-21' ORDER BY 1,2;

-- select from_days and as
--Testcase 3267:
EXPLAIN VERBOSE
SELECT from_days(id + 200719) as from_days1 FROM time_tbl ORDER BY 1;



-- EXTRACT()
-- select mysql_extract (stub function, explain)
--Testcase 3268:
EXPLAIN VERBOSE
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl ORDER BY 1,2,3;

-- select mysql_extract (stub function, result)
--Testcase 3269:
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl ORDER BY 1,2,3;

-- select mysql_extract (stub function, not pushdown constraints, explain)
--Testcase 3270:
EXPLAIN VERBOSE
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3;

-- select mysql_extract (stub function, not pushdown constraints, result)
--Testcase 3271:
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3;

-- select mysql_extract (stub function, pushdown constraints, explain)
--Testcase 3272:
EXPLAIN VERBOSE
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3;

-- select mysql_extract (stub function, pushdown constraints, result)
--Testcase 3273:
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3;

-- select mysql_extract (stub function, mysql_extract in constraints, explain)
--Testcase 3274:
EXPLAIN VERBOSE
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE mysql_extract('YEAR_MONTH', c3 ) != mysql_extract('YEAR_MONTH', '2000-01-01'::timestamp) ORDER BY 1,2,3;

-- select mysql_extract (stub function, mysql_extract in constraints, result)
--Testcase 3275:
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE mysql_extract('YEAR_MONTH', c3 ) != mysql_extract('YEAR_MONTH', '2000-01-01'::timestamp) ORDER BY 1,2,3;

-- select mysql_extract (stub function, mysql_extract in constraints, explain)
--Testcase 3276:
EXPLAIN VERBOSE
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE mysql_extract('YEAR_MONTH', c3 ) > '1' ORDER BY 1,2,3;

-- select mysql_extract (stub function, mysql_extract in constraints, result)
--Testcase 3277:
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE mysql_extract('YEAR_MONTH', c3 ) > '1' ORDER BY 1,2,3;

-- select mysql_extract with agg (pushdown, explain)
--Testcase 3278:
EXPLAIN VERBOSE
SELECT max(c3), mysql_extract('YEAR', max(c3)) FROM time_tbl;

-- select mysql_extract as nest function with agg (pushdown, result)
--Testcase 3279:
SELECT max(c3), mysql_extract('YEAR', max(c3)) FROM time_tbl;

-- select mysql_extract with non pushdown func and explicit constant (explain)
--Testcase 3280:
EXPLAIN VERBOSE
SELECT mysql_extract('YEAR', date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select mysql_extract with non pushdown func and explicit constant (result)
--Testcase 3281:
SELECT mysql_extract('YEAR', date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl ORDER BY 1;

-- select mysql_extract with order by (explain)
--Testcase 3282:
EXPLAIN VERBOSE
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl order by id,mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3);

-- select mysql_extract with order by (result)
--Testcase 3283:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl order by id,mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3);

-- select mysql_extract with order by index (result)
--Testcase 3284:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl order by 4,3,2,1;

-- select mysql_extract with order by index (result)
--Testcase 3285:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl order by 1,2,3,4;

-- select mysql_extract with group by (explain)
--Testcase 3286:
EXPLAIN VERBOSE
SELECT max(c3), mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl group by mysql_extract('DAY_MINUTE', c3),c2 ORDER BY 1,2,3,4;

-- select mysql_extract with group by (result)
--Testcase 3287:
SELECT max(c3), mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl group by mysql_extract('DAY_MINUTE', c3),c2 ORDER BY 1,2,3,4;

-- select mysql_extract with group by index (result)
--Testcase 3288:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl group by 4,3,2,1 ORDER BY 1,2,3,4;

-- select mysql_extract with group by index (result)
--Testcase 3289:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl group by 1,2,3,4 ORDER BY 1,2,3,4;

-- select mysql_extract with group by index having (result)
--Testcase 3290:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3), c2 FROM time_tbl group by 5, 4, 3, 2, 1 HAVING mysql_extract('YEAR', c2) > 2000 ORDER BY 1,2,3,4,5;

-- select mysql_extract with group by index having (result)
--Testcase 3291:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3), c2 FROM time_tbl group by 1, 2, 3, 4, 5 HAVING mysql_extract('YEAR', c2) > 2000 ORDER BY 1,2,3,4,5;

-- select mysql_extract and as
--Testcase 3292:
SELECT mysql_extract('YEAR', c2) as mysql_extract1, mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp) as mysql_extract2, mysql_extract('DAY_MINUTE', c3) as mysql_extract3 FROM time_tbl ORDER BY 1,2,3;


-- DAYOFYEAR()
-- select dayofyear (stub function, explain)
--Testcase 3293:
EXPLAIN VERBOSE
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl ORDER BY 1,2;

-- select dayofyear (stub function, result)
--Testcase 3294:
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl ORDER BY 1,2;

-- select dayofyear (stub function, not pushdown constraints, explain)
--Testcase 3295:
EXPLAIN VERBOSE
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select dayofyear (stub function, not pushdown constraints, result)
--Testcase 3296:
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select dayofyear (stub function, pushdown constraints, explain)
--Testcase 3297:
EXPLAIN VERBOSE
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select dayofyear (stub function, pushdown constraints, result)
--Testcase 3298:
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select dayofyear (stub function, dayofyear in constraints, explain)
--Testcase 3299:
EXPLAIN VERBOSE
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE dayofyear(c2) != dayofyear('2000-01-01'::date) ORDER BY 1,2;

-- select dayofyear (stub function, dayofyear in constraints, result)
--Testcase 3300:
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE dayofyear(c2) != dayofyear('2000-01-01'::date) ORDER BY 1,2;

-- select dayofyear (stub function, dayofyear in constraints, explain)
--Testcase 3301:
EXPLAIN VERBOSE
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE dayofyear('2021-01-01 12:00:00'::date) > 0 ORDER BY 1,2;

-- select dayofyear (stub function, dayofyear in constraints, result)
--Testcase 3302:
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE dayofyear('2021-01-01 12:00:00'::date) > 0 ORDER BY 1,2;

-- select dayofyear with agg (pushdown, explain)
--Testcase 3303:
EXPLAIN VERBOSE
SELECT max(c2), dayofyear(max(c2)) FROM time_tbl;

-- select dayofyear as nest function with agg (pushdown, result)
--Testcase 3304:
SELECT max(c2), dayofyear(max(c2)) FROM time_tbl;

-- select dayofyear with non pushdown func and explicit constant (explain)
--Testcase 3305:
EXPLAIN VERBOSE
SELECT dayofyear(c2), dayofyear('2021-01-01'::date), pi(), 4.1 FROM time_tbl ORDER BY 1,2;

-- select dayofyear with non pushdown func and explicit constant (result)
--Testcase 3306:
SELECT dayofyear(c2), dayofyear('2021-01-01'::date), pi(), 4.1 FROM time_tbl ORDER BY 1,2;

-- select dayofyear with order by (explain)
--Testcase 3307:
EXPLAIN VERBOSE
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl order by id,dayofyear(c2), dayofyear('2021-01-01'::date);

-- select dayofyear with order by (result)
--Testcase 3308:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl order by id,dayofyear(c2), dayofyear('2021-01-01'::date);

-- select dayofyear with order by index (result)
--Testcase 3309:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl order by 3,2,1;

-- select dayofyear with order by index (result)
--Testcase 3310:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl order by 1,2,3;

-- select dayofyear with group by (explain)
--Testcase 3311:
EXPLAIN VERBOSE
SELECT max(c3), dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl group by dayofyear(c2) ORDER BY 1,2,3;

-- select dayofyear with group by (result)
--Testcase 3312:
SELECT max(c3), dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl group by dayofyear(c2) ORDER BY 1,2,3;

-- select dayofyear with group by index (result)
--Testcase 3313:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl group by 3,2,1 ORDER BY 1,2,3;

-- select dayofyear with group by index (result)
--Testcase 3314:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl group by 1,2,3 ORDER BY 1,2,3;

-- select dayofyear with group by index having (result)
--Testcase 3315:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date), c2 FROM time_tbl group by 4, 3, 2, 1 HAVING dayofyear(c2) > 0 ORDER BY 1,2,3;

-- select dayofyear with group by index having (result)
--Testcase 3316:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date), c2 FROM time_tbl group by 1, 2, 3, 4 HAVING dayofyear(c2) > 0 ORDER BY 1,2,3;

-- select dayofyear and as
--Testcase 3317:
SELECT dayofyear(c2) as dayofyear1, dayofyear('2021-01-01'::date) as dayofyear2 FROM time_tbl ORDER BY 1,2;



-- DAYOFWEEK()
-- select dayofweek (stub function, explain)
--Testcase 3318:
EXPLAIN VERBOSE
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl ORDER BY 1,2;

-- select dayofweek (stub function, result)
--Testcase 3319:
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl ORDER BY 1,2;

-- select dayofweek (stub function, not pushdown constraints, explain)
--Testcase 3320:
EXPLAIN VERBOSE
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select dayofweek (stub function, not pushdown constraints, result)
--Testcase 3321:
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select dayofweek (stub function, pushdown constraints, explain)
--Testcase 3322:
EXPLAIN VERBOSE
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select dayofweek (stub function, pushdown constraints, result)
--Testcase 3323:
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select dayofweek (stub function, dayofweek in constraints, explain)
--Testcase 3324:
EXPLAIN VERBOSE
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE dayofweek(c2) != dayofweek('2000-01-01'::date) ORDER BY 1,2;

-- select dayofweek (stub function, dayofweek in constraints, result)
--Testcase 3325:
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE dayofweek(c2) != dayofweek('2000-01-01'::date) ORDER BY 1,2;

-- select dayofweek (stub function, dayofweek in constraints, explain)
--Testcase 3326:
EXPLAIN VERBOSE
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE dayofweek('2021-01-01 12:00:00'::date) > 0 ORDER BY 1,2;

-- select dayofweek (stub function, dayofweek in constraints, result)
--Testcase 3327:
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE dayofweek('2021-01-01 12:00:00'::date) > 0 ORDER BY 1,2;

-- select dayofweek with agg (pushdown, explain)
--Testcase 3328:
EXPLAIN VERBOSE
SELECT max(c2), dayofweek(max(c2)) FROM time_tbl;

-- select dayofweek as nest function with agg (pushdown, result)
--Testcase 3329:
SELECT max(c2), dayofweek(max(c2)) FROM time_tbl;

-- select dayofweek with non pushdown func and explicit constant (explain)
--Testcase 3330:
EXPLAIN VERBOSE
SELECT dayofweek(c2), dayofweek('2021-01-01'::date), pi(), 4.1 FROM time_tbl ORDER BY 1,2;

-- select dayofweek with non pushdown func and explicit constant (result)
--Testcase 3331:
SELECT dayofweek(c2), dayofweek('2021-01-01'::date), pi(), 4.1 FROM time_tbl ORDER BY 1,2;

-- select dayofweek with order by (explain)
--Testcase 3332:
EXPLAIN VERBOSE
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl order by id,dayofweek(c2), dayofweek('2021-01-01'::date);

-- select dayofweek with order by (result)
--Testcase 3333:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl order by id,dayofweek(c2), dayofweek('2021-01-01'::date);

-- select dayofweek with order by index (result)
--Testcase 3334:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl order by 3,2,1;

-- select dayofweek with order by index (result)
--Testcase 3335:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl order by 1,2,3;

-- select dayofweek with group by (explain)
--Testcase 3336:
EXPLAIN VERBOSE
SELECT max(c3), dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl group by dayofweek(c2) ORDER BY 1,2,3;

-- select dayofweek with group by (result)
--Testcase 3337:
SELECT max(c3), dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl group by dayofweek(c2) ORDER BY 1,2,3;

-- select dayofweek with group by index (result)
--Testcase 3338:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl group by 3,2,1 ORDER BY 1,2,3;

-- select dayofweek with group by index (result)
--Testcase 3339:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl group by 1,2,3 ORDER BY 1,2,3;

-- select dayofweek with group by index having (result)
--Testcase 3340:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date), c2 FROM time_tbl group by 4, 3, 2, 1 HAVING dayofweek(c2) > 0 ORDER BY 1,2,3,4;

-- select dayofweek with group by index having (result)
--Testcase 3341:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date), c2 FROM time_tbl group by 1, 2, 3, 4 HAVING dayofweek(c2) > 0 ORDER BY 1,2,3,4;

-- select dayofweek and as
--Testcase 3342:
SELECT dayofweek(c2) as dayofweek1, dayofweek('2021-01-01'::date) as dayofweek2 FROM time_tbl ORDER BY 1,2;



-- DAYOFMONTH()
-- select dayofmonth (stub function, explain)
--Testcase 3343:
EXPLAIN VERBOSE
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl ORDER BY 1,2;

-- select dayofmonth (stub function, result)
--Testcase 3344:
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl ORDER BY 1,2;

-- select dayofmonth (stub function, not pushdown constraints, explain)
--Testcase 3345:
EXPLAIN VERBOSE
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select dayofmonth (stub function, not pushdown constraints, result)
--Testcase 3346:
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select dayofmonth (stub function, pushdown constraints, explain)
--Testcase 3347:
EXPLAIN VERBOSE
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select dayofmonth (stub function, pushdown constraints, result)
--Testcase 3348:
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select dayofmonth (stub function, dayofmonth in constraints, explain)
--Testcase 3349:
EXPLAIN VERBOSE
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE dayofmonth(c2) != dayofmonth('2000-01-01'::date) ORDER BY 1,2;

-- select dayofmonth (stub function, dayofmonth in constraints, result)
--Testcase 3350:
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE dayofmonth(c2) != dayofmonth('2000-01-01'::date) ORDER BY 1,2;

-- select dayofmonth (stub function, dayofmonth in constraints, explain)
--Testcase 3351:
EXPLAIN VERBOSE
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE dayofmonth('2021-01-01 12:00:00'::date) > 0 ORDER BY 1,2;

-- select dayofmonth (stub function, dayofmonth in constraints, result)
--Testcase 3352:
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE dayofmonth('2021-01-01 12:00:00'::date) > 0 ORDER BY 1,2;

-- select dayofmonth with agg (pushdown, explain)
--Testcase 3353:
EXPLAIN VERBOSE
SELECT max(c2), dayofmonth(max(c2)) FROM time_tbl;

-- select dayofmonth as nest function with agg (pushdown, result)
--Testcase 3354:
SELECT max(c2), dayofmonth(max(c2)) FROM time_tbl;

-- select dayofmonth with non pushdown func and explicit constant (explain)
--Testcase 3355:
EXPLAIN VERBOSE
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date), pi(), 4.1 FROM time_tbl ORDER BY 1,2;

-- select dayofmonth with non pushdown func and explicit constant (result)
--Testcase 3356:
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date), pi(), 4.1 FROM time_tbl ORDER BY 1,2;

-- select dayofmonth with order by (explain)
--Testcase 3357:
EXPLAIN VERBOSE
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl order by id,dayofmonth(c2), dayofmonth('2021-01-01'::date);

-- select dayofmonth with order by (result)
--Testcase 3358:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl order by id,dayofmonth(c2), dayofmonth('2021-01-01'::date);

-- select dayofmonth with order by index (result)
--Testcase 3359:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl order by 3,2,1;

-- select dayofmonth with order by index (result)
--Testcase 3360:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl order by 1,2,3;

-- select dayofmonth with group by (explain)
--Testcase 3361:
EXPLAIN VERBOSE
SELECT max(c3), dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl group by dayofmonth(c2) ORDER BY 1,2,3;

-- select dayofmonth with group by (result)
--Testcase 3362:
SELECT max(c3), dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl group by dayofmonth(c2) ORDER BY 1,2,3;

-- select dayofmonth with group by index (result)
--Testcase 3363:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl group by 3,2,1 ORDER BY 1,2,3;

-- select dayofmonth with group by index (result)
--Testcase 3364:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl group by 1,2,3 ORDER BY 1,2,3;

-- select dayofmonth with group by index having (result)
--Testcase 3365:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date), c2 FROM time_tbl group by 4, 3, 2, 1 HAVING dayofmonth(c2) > 0 ORDER BY 1,2,3,4;

-- select dayofmonth with group by index having (result)
--Testcase 3366:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date), c2 FROM time_tbl group by 1, 2, 3, 4 HAVING dayofmonth(c2) > 0 ORDER BY 1,2,3,4;

-- select dayofmonth and as
--Testcase 3367:
SELECT dayofmonth(c2) as dayofmonth1, dayofmonth('2021-01-01'::date) as dayofmonth2 FROM time_tbl ORDER BY 1,2;



-- DAYNAME()
-- select dayname (stub function, explain)
--Testcase 3368:
EXPLAIN VERBOSE
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl ORDER BY 1,2;

-- select dayname (stub function, result)
--Testcase 3369:
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl ORDER BY 1,2;

-- select dayname (stub function, not pushdown constraints, explain)
--Testcase 3370:
EXPLAIN VERBOSE
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select dayname (stub function, not pushdown constraints, result)
--Testcase 3371:
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2;

-- select dayname (stub function, pushdown constraints, explain)
--Testcase 3372:
EXPLAIN VERBOSE
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select dayname (stub function, pushdown constraints, result)
--Testcase 3373:
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE id != 200 ORDER BY 1,2;

-- select dayname (stub function, dayname in constraints, explain)
--Testcase 3374:
EXPLAIN VERBOSE
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE dayname(c2) != dayname('2000-01-01'::date) ORDER BY 1,2;

-- select dayname (stub function, dayname in constraints, result)
--Testcase 3375:
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE dayname(c2) != dayname('2000-01-01'::date) ORDER BY 1,2;

-- select dayname (stub function, dayname in constraints, explain)
--Testcase 3376:
EXPLAIN VERBOSE
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE dayname('2021-01-01 12:00:00'::date) = 'Friday' ORDER BY 1,2;

-- select dayname (stub function, dayname in constraints, result)
--Testcase 3377:
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE dayname('2021-01-01 12:00:00'::date) > 'Friday' ORDER BY 1,2;

-- select dayname with agg (pushdown, explain)
--Testcase 3378:
EXPLAIN VERBOSE
SELECT max(c2), dayname(max(c2)) FROM time_tbl;

-- select dayname as nest function with agg (pushdown, result)
--Testcase 3379:
SELECT max(c2), dayname(max(c2)) FROM time_tbl;

-- select dayname with non pushdown func and explicit constant (explain)
--Testcase 3380:
EXPLAIN VERBOSE
SELECT dayname(c2), dayname('2021-01-01'::date), pi(), 4.1 FROM time_tbl ORDER BY 1,2;

-- select dayname with non pushdown func and explicit constant (result)
--Testcase 3381:
SELECT dayname(c2), dayname('2021-01-01'::date), pi(), 4.1 FROM time_tbl ORDER BY 1,2;

-- select dayname with order by (explain)
--Testcase 3382:
EXPLAIN VERBOSE
SELECT id, dayname(c2), dayname('2021-01-01'::date) FROM time_tbl order by id,dayname(c2), dayname('2021-01-01'::date);

-- select dayname with order by (result)
--Testcase 3383:
SELECT id, dayname(c2), dayname('2021-01-01'::date) FROM time_tbl order by id,dayname(c2), dayname('2021-01-01'::date);

-- select dayname with order by index (result)
--Testcase 3384:
SELECT id, dayname(c2), dayname('2021-01-01'::date) FROM time_tbl order by 3,2,1;

-- select dayname with order by index (result)
--Testcase 3385:
SELECT id, dayname(c2), dayname('2021-01-01'::date) FROM time_tbl order by 1,2,3;

-- select dayname with group by (explain)
--Testcase 3386:
EXPLAIN VERBOSE
SELECT max(c3), dayname(c2), dayname('2021-01-01'::date) FROM time_tbl group by dayname(c2) ORDER BY 1,2,3;

-- select dayname with group by (result)
--Testcase 3387:
SELECT max(c3), dayname(c2), dayname('2021-01-01'::date) FROM time_tbl group by dayname(c2) ORDER BY 1,2,3;

-- select dayname with group by index (result)
--Testcase 3388:
SELECT id, dayname(c2), dayname('2021-01-01'::date) FROM time_tbl group by 3,2,1 ORDER BY 1,2,3;

-- select dayname with group by index (result)
--Testcase 3389:
SELECT id, dayname(c2), dayname('2021-01-01'::date) FROM time_tbl group by 1,2,3 ORDER BY 1,2,3;

-- select dayname with group by index having (result)
--Testcase 3390:
SELECT id, dayname(c2), dayname('2021-01-01'::date), c2 FROM time_tbl group by 4, 3, 2, 1 HAVING dayname(c2) = 'Friday' ORDER BY 1,2,3,4;

-- select dayname with group by index having (result)
--Testcase 3391:
SELECT id, dayname(c2), dayname('2021-01-01'::date), c2 FROM time_tbl group by 1, 2, 3, 4 HAVING dayname(c2) > 'Friday' ORDER BY 1,2,3;

-- select dayname and as
--Testcase 3392:
SELECT dayname(c2) as dayname1, dayname('2021-01-01'::date) as dayname2 FROM time_tbl ORDER BY 1,2;



-- DAY()
-- select day (stub function, explain)
--Testcase 3393:
EXPLAIN VERBOSE
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3;

-- select day (stub function, result)
--Testcase 3394:
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl ORDER BY 1,2,3;

-- select day (stub function, not pushdown constraints, explain)
--Testcase 3395:
EXPLAIN VERBOSE
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3;

-- select day (stub function, not pushdown constraints, result)
--Testcase 3396:
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1' ORDER BY 1,2,3;

-- select day (stub function, pushdown constraints, explain)
--Testcase 3397:
EXPLAIN VERBOSE
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select day (stub function, pushdown constraints, result)
--Testcase 3398:
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE id != 200 ORDER BY 1,2,3,4;

-- select day (stub function, day in constraints, explain)
--Testcase 3399:
EXPLAIN VERBOSE
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE day(c2) != day('2000-01-01'::date) ORDER BY 1,2,3,4;

-- select day (stub function, day in constraints, result)
--Testcase 3400:
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE day(c2) != day('2000-01-01'::date) ORDER BY 1,2,3,4;

-- select day (stub function, day in constraints, explain)
--Testcase 3401:
EXPLAIN VERBOSE
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE day('2021-01-01 12:00:00'::date) > 0 ORDER BY 1,2,3,4;

-- select day (stub function, day in constraints, result)
--Testcase 3402:
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE day('2021-01-01 12:00:00'::date) > 0 ORDER BY 1,2,3,4;

-- select day with agg (pushdown, explain)
--Testcase 3403:
EXPLAIN VERBOSE
SELECT max(c2), day(max(c2)) FROM time_tbl;

-- select day as nest function with agg (pushdown, result)
--Testcase 3404:
SELECT max(c2), day(max(c2)) FROM time_tbl;

-- select day with non pushdown func and explicit constant (explain)
--Testcase 3405:
EXPLAIN VERBOSE
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp), pi(), 4.1 FROM time_tbl ORDER BY 1,2,3,4;

-- select day with non pushdown func and explicit constant (result)
--Testcase 3406:
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp), pi(), 4.1 FROM time_tbl ORDER BY 1,2,3,4;

-- select day with order by (explain)
--Testcase 3407:
EXPLAIN VERBOSE
SELECT id, day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl order by id,day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp);

-- select day with order by (result)
--Testcase 3408:
SELECT id, day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl order by id,day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp);

-- select day with order by index (result)
--Testcase 3409:
SELECT id, day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl order by 5,4,3,2,1;

-- select day with order by index (result)
--Testcase 3410:
SELECT id, day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl order by 1,2,3,4,5;

-- select day with group by (explain)
--Testcase 3411:
EXPLAIN VERBOSE
SELECT max(c3), day(c2), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl group by day(c2), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) ORDER BY 1,2,3,4;

-- select day with group by (result)
--Testcase 3412:
SELECT max(c3), day(c2), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl group by day(c2) ORDER BY 1,2,3,4;

-- select day with group by index (result)
--Testcase 3413:
SELECT id, day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl group by 5,4,3,2,1 ORDER BY 1,2,3,4,5;

-- select day with group by index (result)
--Testcase 3414:
SELECT id, day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl group by 1,2,3,4,5 ORDER BY 1,2,3,4,5;

-- select day with group by index having (result)
--Testcase 3415:
SELECT id, day(c2), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp), c2 FROM time_tbl group by 5,4,3,2,1 HAVING day(c2) > 0 ORDER BY 1,2,3,4,5;

-- select day with group by index having (result)
--Testcase 3416:
SELECT id, day(c2), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp), c2 FROM time_tbl group by 1,2,3,4,5 HAVING day(c2) > 0 ORDER BY 1,2,3,4,5;

-- select day and as
--Testcase 3417:
SELECT day(c2) as day1, day(c3) as day2, day('2021-01-01'::date) as day3, day('1997-01-31 12:00:00'::timestamp) as day4 FROM time_tbl ORDER BY 1,2,3,4;

-- ============================================================================
-- Stub aggregate function for mysql fdw
-- ============================================================================

--Testcase 3418:
CREATE FOREIGN TABLE s7a (id int, tag1 text, value1 float, value2 int, value3 float, value4 int, value5 bit(16), str1 text, str2 text, __spd_url text) SERVER pgspider_core_svr;
--Testcase 3419:
CREATE FOREIGN TABLE s7a__pgspider_svr1__0 (id int, tag1 text, value1 float, value2 int, value3 float, value4 int, value5 bit varying (16), str1 text, str2 text, __spd_url text) SERVER pgspider_svr1 OPTIONS (table_name 's7a1mysql');
--Testcase 3420:
CREATE FOREIGN TABLE s7a__pgspider_svr2__0 (id int, tag1 text, value1 float, value2 int, value3 float, value4 int, value5 bit varying (16), str1 text, str2 text, __spd_url text) SERVER pgspider_svr2 OPTIONS (table_name 's7a2mysql');

--Testcase 3421:
\d s7a;
--Testcase 3422:
SELECT * FROM s7a ORDER BY id;
-- ===================================================================
-- test BIT_XOR()
-- ===================================================================
-- select bit_xor (explain)
--Testcase 3423:
EXPLAIN VERBOSE
SELECT bit_xor(id), bit_xor(tag1), bit_xor(value1), bit_xor(value2), bit_xor(value3), bit_xor(value4), bit_xor(value5), bit_xor(str1) FROM s7a;
-- select bit_xor (result)
--Testcase 3424:
SELECT bit_xor(id), bit_xor(tag1), bit_xor(value1), bit_xor(value2), bit_xor(value3), bit_xor(value4), bit_xor(value5), bit_xor(str1) FROM s7a;

-- select bit_xor with group by (explain)
--Testcase 3425:
EXPLAIN VERBOSE
SELECT tag1, bit_xor(value5) FROM s7a GROUP BY tag1;
-- select bit_xor with group by (result)
--Testcase 3426:
SELECT tag1, bit_xor(value5) FROM s7a GROUP BY tag1;

-- select bit_xor with group by having (explain)
--Testcase 3427:
EXPLAIN VERBOSE
SELECT id, bit_xor(value5) FROM s7a GROUP BY id, str1 HAVING bit_xor(value5) > 0::bit;
-- select bit_xor with group by having (result)
--Testcase 3428:
SELECT id, bit_xor(value5) FROM s7a GROUP BY id, str1 HAVING bit_xor(value5) > 0::bit;

-- ===================================================================
-- test GROUP_CONCAT()
-- ===================================================================
-- select group_concat (explain)
--Testcase 3429:
EXPLAIN VERBOSE
SELECT group_concat(id), group_concat(tag1), group_concat(value1), group_concat(value2), group_concat(value3), group_concat(str2) FROM s7a;
-- select group_concat (result)
--Testcase 3430:
SELECT group_concat(id), group_concat(tag1), group_concat(value1), group_concat(value2), group_concat(value3), group_concat(str2) FROM s7a;

-- select group_concat (explain)
--Testcase 3431:
EXPLAIN VERBOSE
SELECT group_concat(value1 + 1) FROM s7a;
-- select group_concat with group by (result)
--Testcase 3432:
SELECT group_concat(value1 + 1) FROM s7a;

-- select group_concat with stub function (explain)
--Testcase 3433:
EXPLAIN VERBOSE
SELECT tag1, group_concat(sqrt(value1)) FROM s7a GROUP BY tag1;
-- select group_concat with stub function (result)
--Testcase 3434:
SELECT tag1, group_concat(sqrt(value1)) FROM s7a GROUP BY tag1;

-- select group_concat with group by (explain)
--Testcase 3435:
EXPLAIN VERBOSE
SELECT id, group_concat(value3) FROM s7a GROUP BY 1;
-- select group_concat with group by(explain)
--Testcase 3436:
SELECT id, group_concat(value3) FROM s7a GROUP BY 1;

-- select group_concat with group by having (explain)
--Testcase 3437:
EXPLAIN VERBOSE
SELECT id, group_concat(value3) FROM s7a GROUP BY 1, value1 HAVING group_concat(value3) IS NOT NULL;
-- select group_concat with group by having (result)
--Testcase 3438:
SELECT id, group_concat(value3) FROM s7a GROUP BY 1, value1 HAVING group_concat(value3) IS NOT NULL;

-- select group_concat with group by having (explain)
--Testcase 3439:
EXPLAIN VERBOSE
SELECT id, group_concat(value3) FROM s7a GROUP BY 1, value1 HAVING group_concat(value3 + 1) IS NOT NULL;
-- select group_concat with group by having (result)
--Testcase 3440:
SELECT id, group_concat(value3) FROM s7a GROUP BY 1, value1 HAVING group_concat(value3 + 1) IS NOT NULL;

-- select group_concat with group by having (explain)
--Testcase 3441:
EXPLAIN VERBOSE
SELECT id, group_concat(value3) FROM s7a GROUP BY 1, value1 HAVING group_concat(abs(value3)) IS NOT NULL;
-- select group_concat with group by having (result)
--Testcase 3442:
SELECT id, group_concat(value3) FROM s7a GROUP BY 1, value1 HAVING group_concat(abs(value3)) IS NOT NULL;

-- select group_concat with multiple argument by ROW() expression.
--Testcase 3443:
EXPLAIN VERBOSE
SELECT group_concat((id, tag1, value2, str1, value5)) FROM s7a;
--Testcase 3444:
SELECT group_concat((id, tag1, value2, str1, value5)) FROM s7a;

-- select group_concat with multiple argument by ROW() expression and GROUP BY
--Testcase 3445:
EXPLAIN VERBOSE
SELECT group_concat((id, tag1, value2, str1, value5)) FROM s7a GROUP BY value2;
--Testcase 3446:
SELECT group_concat((id, tag1, value2, str1, value5)) FROM s7a GROUP BY value2;

-- select group_concat with single argument
--Testcase 3447:
EXPLAIN VERBOSE
SELECT group_concat(value1 ORDER By value1) FROM s7a;
--Testcase 3448:
SELECT group_concat(value1 ORDER By value1) FROM s7a;

-- select group_concat with single argument and ORDER BY
--Testcase 3449:
EXPLAIN VERBOSE
SELECT group_concat(value1 ORDER By value1 ASC) FROM s7a;
--Testcase 3450:
SELECT group_concat(value1 ORDER By value1 ASC) FROM s7a;

-- select group_concat with single argument and ORDER BY
--Testcase 3451:
EXPLAIN VERBOSE
SELECT group_concat(value1 ORDER By value1 DESC) FROM s7a;
--Testcase 3452:
SELECT group_concat(value1 ORDER By value1 DESC) FROM s7a;

-- ===================================================================
-- test GROUP_CONCAT(DISTINCT) - PGSPIDER push down in single node only
-- ===================================================================
-- select group_concat(DISTINCT) (explain)
--Testcase 3453:
EXPLAIN VERBOSE
SELECT group_concat(DISTINCT id), group_concat(DISTINCT tag1), group_concat(DISTINCT value1), group_concat(DISTINCT value2), group_concat(DISTINCT value3), group_concat(DISTINCT value5), group_concat(DISTINCT str2) FROM s7a;
-- select group_concat(DISTINCT) (result)
--Testcase 3454:
SELECT group_concat(DISTINCT id), group_concat(DISTINCT tag1), group_concat(DISTINCT value1), group_concat(DISTINCT value2), group_concat(DISTINCT value3), group_concat(DISTINCT value5), group_concat(DISTINCT str2) FROM s7a;

-- select group_concat(DISTINCT) (explain)
--Testcase 3455:
EXPLAIN VERBOSE
SELECT group_concat(DISTINCT (value1 + 1)) FROM s7a;
-- select group_concat(DISTINCT) (result)
--Testcase 3456:
SELECT group_concat(DISTINCT (value1 + 1)) FROM s7a;

-- select group_concat(DISTINCT) with group by (explain)
--Testcase 3457:
EXPLAIN VERBOSE
SELECT value2, group_concat(DISTINCT value3) FROM s7a GROUP BY value2;
-- select group_concat(DISTINCT) with group by (result)
--Testcase 3458:
SELECT value2, group_concat(DISTINCT value3) FROM s7a GROUP BY value2;

-- select group_concat(DISTINCT) multiple argument (T_Row expr)
--Testcase 3459:
EXPLAIN VERBOSE
SELECT group_concat(DISTINCT (id, tag1, value2, str1, value5)) FROM s7a;
--Testcase 3460:
SELECT group_concat(DISTINCT (id, tag1, value2, str1, value5)) FROM s7a;

-- select group_concat(DISTINCT) multiple argument (T_Row expr)
--Testcase 3461:
EXPLAIN VERBOSE
SELECT group_concat(DISTINCT (tag1, value2)) FROM s7a;
--Testcase 3462:
SELECT group_concat(DISTINCT (tag1, value2)) FROM s7a;

-- select group_concat(DISTINCT) multiple argument with group by (result)
--Testcase 3463:
SELECT value2, group_concat(DISTINCT (tag1, value3, value2)) FROM s7a GROUP BY value2;
--Testcase 3464:
SELECT value2, group_concat(DISTINCT (tag1, value3, value2)) FROM s7a GROUP BY value2;

-- select group_concat(DISTINCT) with stub function (explain)
--Testcase 3465:
EXPLAIN VERBOSE
SELECT id, group_concat(DISTINCT mysql_sqrt(value1)) FROM s7a GROUP BY id;
-- select group_concat(DISTINCT) with stub function (result)
--Testcase 3466:
SELECT id, group_concat(DISTINCT mysql_sqrt(value1)) FROM s7a GROUP BY id;

-- select group_concat(DISTINCT) with group by having (explain)
--Testcase 3467:
EXPLAIN VERBOSE
SELECT id, group_concat(DISTINCT value3) FROM s7a GROUP BY 1, value1 HAVING group_concat(DISTINCT value3) IS NOT NULL;
-- select group_concat(DISTINCT) with group by having (result)
--Testcase 3468:
SELECT id, group_concat(DISTINCT value3) FROM s7a GROUP BY 1, value1 HAVING group_concat(DISTINCT value3) IS NOT NULL;

-- select group_concat(DISTINCT) with group by having (explain)
--Testcase 3469:
EXPLAIN VERBOSE
SELECT id, group_concat(DISTINCT value3) FROM s7a GROUP BY 1, value1 HAVING group_concat(DISTINCT (value3 + 1)) IS NOT NULL;
-- select group_concat(DISTINCT) with group by having (result)
--Testcase 3470:
SELECT id, group_concat(DISTINCT value3) FROM s7a GROUP BY 1, value1 HAVING group_concat(DISTINCT (value3 + 1)) IS NOT NULL;

-- select group_concat(DISTINCT) with group by having (explain)
--Testcase 3471:
EXPLAIN VERBOSE
SELECT id, group_concat(DISTINCT value3) FROM s7a GROUP BY 1, value1 HAVING group_concat(DISTINCT abs(value3)) IS NOT NULL;
-- select group_concat(DISTINCT) with group by having (result)
--Testcase 3472:
SELECT id, group_concat(DISTINCT value3) FROM s7a GROUP BY 1, value1 HAVING group_concat(DISTINCT abs(value3)) IS NOT NULL;

-- ===================================================================
-- test COUNT()
-- ===================================================================
-- select count(*)
--Testcase 3473:
EXPLAIN VERBOSE
SELECT COUNT(*) FROM s7a;
--Testcase 3474:
SELECT COUNT(*) FROM s7a;

-- select COUNT(expr)
--Testcase 3475:
EXPLAIN VERBOSE
SELECT COUNT(tag1) FROM s7a;
--Testcase 3476:
SELECT COUNT(tag1) FROM s7a;

-- select COUNT(expr)
--Testcase 3477:
EXPLAIN VERBOSE
SELECT COUNT(tag1) FROM s7a GROUP BY tag1;
--Testcase 3478:
SELECT COUNT(tag1) FROM s7a GROUP BY tag1;

-- select COUNT(DISTINCT expr,[expr...]) PGSPIDER do not push down this case
--Testcase 3479:
EXPLAIN VERBOSE
SELECT COUNT(DISTINCT tag1) FROM s7a;
--Testcase 3480:
SELECT COUNT(DISTINCT tag1) FROM s7a GROUP BY tag1;

-- select COUNT(DISTINCT expr,[expr...]) PGSPIDER do not push down this case
--Testcase 3481:
EXPLAIN VERBOSE
SELECT COUNT(DISTINCT (id, tag1, value2, str1, value5)) FROM s7a;
--Testcase 3482:
SELECT COUNT(DISTINCT (id, tag1, value2, str1, value5)) FROM s7a;

-- select COUNT(DISTINCT expr,[expr...]) PGSPIDER do not push down this case
--Testcase 3483:
EXPLAIN VERBOSE
SELECT COUNT(DISTINCT (tag1, value2)) FROM s7a;
--Testcase 3484:
SELECT COUNT(DISTINCT (tag1, value2)) FROM s7a;


-- ===================================================================
-- test JSON_ARRAYAGG() PGSPIDER push down in single node only
-- ===================================================================
-- select json_agg (explain)
--Testcase 3485:
EXPLAIN VERBOSE
SELECT id, json_agg(id), json_agg(tag1), json_agg(value1), json_agg(value2), json_agg(value3), json_agg(value5), json_agg(str1) FROM s7a GROUP BY id ORDER BY id;
-- select json_agg (result)
--Testcase 3486:
SELECT id, json_agg(id), json_agg(tag1), json_agg(value1), json_agg(value2), json_agg(value3), json_agg(value5), json_agg(str1) FROM s7a GROUP BY id ORDER BY id;

-- select json_agg with group by (explain)
--Testcase 3487:
EXPLAIN VERBOSE
SELECT tag1, json_agg(value3) FROM s7a GROUP BY tag1;
-- select json_agg with group by (result)
--Testcase 3488:
SELECT tag1, json_agg(value3) FROM s7a GROUP BY tag1;

-- select json_agg with group by (explain)
--Testcase 3489:
EXPLAIN VERBOSE
SELECT tag1, json_agg(value3 + 1) FROM s7a GROUP BY tag1;
-- select json_agg with group by (result)
--Testcase 3490:
SELECT tag1, json_agg(value3 + 1) FROM s7a GROUP BY tag1;

-- select json_agg with stub function (explain)
--Testcase 3491:
EXPLAIN VERBOSE
SELECT tag1, json_agg(abs(value3)) FROM s7a GROUP BY tag1;
-- select json_agg with stub function (result)
--Testcase 3492:
SELECT tag1, json_agg(abs(value3)) FROM s7a GROUP BY tag1;

-- select json_agg with group by having (explain)
--Testcase 3493:
EXPLAIN VERBOSE
SELECT tag1, json_agg(value3) FROM s7a GROUP BY 1, value1 HAVING json_agg(value3) IS NOT NULL;
-- select json_agg with group by having (result)
--Testcase 3494:
SELECT tag1, json_agg(value3) FROM s7a GROUP BY 1, value1 HAVING json_agg(value3) IS NOT NULL;

-- select json_agg with group by having (explain)
--Testcase 3495:
EXPLAIN VERBOSE
SELECT tag1, json_agg(value3 + 1) FROM s7a GROUP BY 1, value1 HAVING json_agg(value3 + 1) IS NOT NULL;
-- select json_agg with group by having (result)
--Testcase 3496:
SELECT tag1, json_agg(value3 + 1) FROM s7a GROUP BY 1, value1 HAVING json_agg(value3 + 1) IS NOT NULL;

-- select json_agg with group by having (explain)
--Testcase 3497:
EXPLAIN VERBOSE
SELECT tag1, json_agg(abs(value3)) FROM s7a GROUP BY 1, value1 HAVING json_agg(abs(value3)) IS NOT NULL;
-- select json_agg with group by having (result)
--Testcase 3498:
SELECT tag1, json_agg(abs(value3)) FROM s7a GROUP BY 1, value1 HAVING json_agg(abs(value3)) IS NOT NULL;

-- ===================================================================
-- test JSON_OBJECTAGG() PGSPIDER push down in single node only
-- ===================================================================
-- select json_objectagg (explain)
--Testcase 3499:
EXPLAIN VERBOSE
SELECT id, json_object_agg(tag1, str1), json_object_agg(id, value4) FROM s7a GROUP BY id ORDER BY id;
-- select json_objectagg (result)
--Testcase 3500:
SELECT id, json_object_agg(tag1, str1), json_object_agg(id, value4) FROM s7a GROUP BY id ORDER BY id;

-- select json_objectagg with group by (explain)
--Testcase 3501:
EXPLAIN VERBOSE
SELECT id, json_object_agg(tag1, str1) FROM s7a GROUP BY id;
-- select json_objectagg with group by (result)
--Testcase 3502:
SELECT id, json_object_agg(tag1, str1) FROM s7a GROUP BY id;

-- select json_objectagg with group by (explain)
--Testcase 3503:
EXPLAIN VERBOSE
SELECT id, json_object_agg(tag1, value2 + 1) FROM s7a GROUP BY id;
-- select json_objectagg with group by (result)
--Testcase 3504:
SELECT id, json_object_agg(tag1, value2 + 1) FROM s7a GROUP BY id;

-- select json_objectagg with stub function (explain)
--Testcase 3505:
EXPLAIN VERBOSE
SELECT id, json_object_agg(tag1, abs(value2)) FROM s7a GROUP BY id;
-- select json_objectagg with stub function (result)
--Testcase 3506:
SELECT id, json_object_agg(tag1, abs(value2)) FROM s7a GROUP BY id;

-- select json_objectagg with group by having (explain)
--Testcase 3507:
EXPLAIN VERBOSE
SELECT id, json_object_agg(tag1, str1) FROM s7a GROUP BY 1, value1 HAVING json_object_agg(tag1, str1) IS NOT NULL;
-- select json_objectagg with group by having (result)
--Testcase 3508:
SELECT id, json_object_agg(tag1, str1) FROM s7a GROUP BY 1, value1 HAVING json_object_agg(tag1, str1) IS NOT NULL;

-- select json_objectagg with group by having (explain)
--Testcase 3509:
EXPLAIN VERBOSE
SELECT id, json_object_agg(tag1, str1) FROM s7a GROUP BY 1, value1 HAVING json_object_agg(tag1, abs(value2 + 1)) IS NOT NULL;
-- select json_objectagg with group by having (result)
--Testcase 3510:
SELECT id, json_object_agg(tag1, str1) FROM s7a GROUP BY 1, value1 HAVING json_object_agg(tag1, abs(value2 + 1)) IS NOT NULL;

-- ===================================================================
-- test STD()
-- ===================================================================
-- select std (explain)
--Testcase 3511:
EXPLAIN VERBOSE
SELECT std(id), std(tag1), std(value1), std(value2), std(value3), std(str1) FROM s7a;
-- select std (result)
--Testcase 3512:
SELECT std(id), std(tag1), std(value1), std(value2), std(value3), std(str1) FROM s7a;

-- select std with group by (explain)
--Testcase 3513:
EXPLAIN VERBOSE
SELECT tag1, std(value4) FROM s7a GROUP BY tag1;
-- select std with group by (result)
--Testcase 3514:
SELECT tag1, std(value4) FROM s7a GROUP BY tag1;

-- select std with group by (explain)
--Testcase 3515:
EXPLAIN VERBOSE
SELECT tag1, std(value4 + 1) FROM s7a GROUP BY tag1;
-- select std with group by (result)
--Testcase 3516:
SELECT tag1, std(value4 + 1) FROM s7a GROUP BY tag1;

-- select std with stub function (explain)
--Testcase 3517:
EXPLAIN VERBOSE
SELECT tag1, std(abs(value4 + 1)) FROM s7a GROUP BY tag1;
-- select std with stub function (result)
--Testcase 3518:
SELECT tag1, std(abs(value4 + 1)) FROM s7a GROUP BY tag1;

-- select std with group by having (explain)
--Testcase 3519:
EXPLAIN VERBOSE
SELECT tag1, std(value4) FROM s7a GROUP BY tag1 HAVING  std(value4) > 0;
-- select std with group by having (result)
--Testcase 3520:
SELECT tag1, std(value4) FROM s7a GROUP BY tag1 HAVING  std(value4) > 0;

-- select std with group by having (explain)
--Testcase 3521:
EXPLAIN VERBOSE
SELECT tag1, std(value4) FROM s7a GROUP BY tag1 HAVING std(abs(value4 + 1)) = 0;
-- select std with group by having (result)
--Testcase 3522:
SELECT tag1, std(value4) FROM s7a GROUP BY tag1 HAVING std(abs(value4 + 1)) = 0;

-- test for JSON function
--Testcase 3523:
CREATE FOREIGN TABLE s8 (id int, c1 json, c2 int, c3 text, __spd_url text) SERVER pgspider_core_svr;
--Testcase 3524:
CREATE FOREIGN TABLE s9 (id int, c1 json, __spd_url text) SERVER pgspider_core_svr;

--Testcase 3525:
CREATE FOREIGN TABLE s8__pgspider_svr1__0 (id int, c1 json, c2 int, c3 text, __spd_url text) SERVER pgspider_svr1 OPTIONS (table_name 's81mysql');
--Testcase 3526:
CREATE FOREIGN TABLE s8__pgspider_svr2__0 (id int, c1 json, c2 int, c3 text, __spd_url text) SERVER pgspider_svr2 OPTIONS (table_name 's82mysql');

--Testcase 3527:
CREATE FOREIGN TABLE s9__pgspider_svr1__0 (id int, c1 json, __spd_url text) SERVER pgspider_svr1 OPTIONS (table_name 's91mysql');
--Testcase 3528:
CREATE FOREIGN TABLE s9__pgspider_svr2__0 (id int, c1 json, __spd_url text) SERVER pgspider_svr2 OPTIONS (table_name 's92mysql');

--Testcase 3529:
SELECT * FROM s9 ORDER BY 1;
--Testcase 3530:
SELECT * FROM s8 ORDER BY 1;

-- select json_build_array (builtin function, explain)
--Testcase 3531:
EXPLAIN VERBOSE
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, 1), json_build_array(c1, 'a'), json_build_array(c1, mysql_pi()) FROM s8;

-- select json_build_array (builtin function, result)
--Testcase 3532:
SELECT * FROM (
SELECT id, json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, 1), json_build_array(c1, 'a'), json_build_array(c1, mysql_pi()) FROM s8
) AS t ORDER BY 1;

-- select json_build_array (builtin function, not pushdown constraints, explain)
--Testcase 3533:
EXPLAIN VERBOSE
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, NULL), json_build_array(c1, TRUE), json_build_array(c1, mysql_pi()) FROM s8 WHERE to_hex(id) = '1';

-- select json_build_array (builtin function, not pushdown constraints, result)
--Testcase 3534:
SELECT * FROM (
SELECT id, json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, NULL), json_build_array(c1, TRUE), json_build_array(c1, mysql_pi()) FROM s8 WHERE to_hex(id) = '1'
) AS t ORDER BY 1;

-- select json_build_array (builtin function, pushdown constraints, explain)
--Testcase 3535:
EXPLAIN VERBOSE
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, 1), json_build_array(c1, 'a'), json_build_array(c1, '[true, false]'::json) FROM s8 WHERE id = 1;

-- select json_build_array (builtin function, pushdown constraints, result)
--Testcase 3536:
SELECT * FROM (
SELECT id, json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, 1), json_build_array(c1, 'a'), json_build_array(c1, '[true, false]'::json) FROM s8 WHERE id = 1
) AS t ORDER BY 1;

-- select json_build_array (builtin function, builtin in constraints, explain)
--Testcase 3537:
EXPLAIN VERBOSE
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, NULL), json_build_array(c1, TRUE), json_build_array(c1, '[true, false]') FROM s8 WHERE json_length(json_build_array(c1, c2)) > 1;

-- select json_build_array (builtin function, builtin in constraints, result)
--Testcase 3538:
SELECT * FROM (
SELECT id, json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, NULL), json_build_array(c1, TRUE), json_build_array(c1, '[true, false]') FROM s8 WHERE json_length(json_build_array(c1, c2)) > 1
) AS t ORDER BY 1;

-- select json_build_array (builtin function, builtin in constraints, explain)
--Testcase 3539:
EXPLAIN VERBOSE
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, 1), json_build_array(c1, 'a'), json_build_array(c1, mysql_pi()) FROM s8 WHERE json_length(json_build_array(c1, c2)) > id;

-- select json_build_array (builtin function, builtin in constraints, result)
--Testcase 3540:
SELECT * FROM (
SELECT id, json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, 1), json_build_array(c1, 'a'), json_build_array(c1, mysql_pi()) FROM s8 WHERE json_length(json_build_array(c1, c2)) > id
) AS t ORDER BY 1;

-- select json_build_array as nest function with agg (not pushdown, explain)
--Testcase 3541:
EXPLAIN VERBOSE
SELECT sum(id),json_build_array('["a", ["b", "c"], "d"]',  sum(id)) FROM s8;

-- select json_build_array as nest function with agg (not pushdown, result)
--Testcase 3542:
SELECT sum(id),json_build_array('["a", ["b", "c"], "d"]',  sum(id)) FROM s8;

-- select json_build_array with non pushdown func and explicit constant (explain)
--Testcase 3543:
EXPLAIN VERBOSE
SELECT json_build_array(c1, c2), pi(), 4.1 FROM s8;

-- select json_build_array with non pushdown func and explicit constant (result)
--Testcase 3544:
SELECT * FROM (
SELECT id, json_build_array(c1, c2), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_build_array with order by (explain)
--Testcase 3545:
EXPLAIN VERBOSE
SELECT json_length(json_build_array(c1, c2)) FROM s8 ORDER BY 1;

-- select json_build_array with order by (result)
--Testcase 3546:
SELECT json_length(json_build_array(c1, c2)) FROM s8 ORDER BY 1;

-- select json_build_array with group by (explain)
--Testcase 3547:
EXPLAIN VERBOSE
SELECT json_length(json_build_array('["a", ["b", "c"], "d"]',  id)) FROM s8 GROUP BY 1;

-- select json_build_array with group by (result)
--Testcase 3548:
SELECT * FROM (
SELECT id, json_length(json_build_array('["a", ["b", "c"], "d"]',  id)) FROM s8 GROUP BY 1, 2
) AS t ORDER BY 1;

-- select json_build_array with group by having (explain)
--Testcase 3549:
EXPLAIN VERBOSE
SELECT id, json_length(json_build_array('["a", ["b", "c"], "d"]',  c2)), c2 FROM s8 GROUP BY 1, 2, 3 HAVING count(c2) > 1;

-- select json_build_array with group by having (result)
--Testcase 3550:
SELECT * FROM (
SELECT id, json_length(json_build_array('["a", ["b", "c"], "d"]',  c2)), c2 FROM s8 GROUP BY 1, 2, 3 HAVING count(c2) > 1
) AS t ORDER BY 1;

-- select json_build_array and as
--Testcase 3551:
SELECT * FROM (
SELECT id, json_build_array(c1, c2) AS json_build_array1 FROM s8
) AS t ORDER BY 1;

-- json_array_append
-- select json_array_append (stub function, explain)
--Testcase 3552:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8;

-- select json_array_append (stub function, result)
--Testcase 3553:
SELECT * FROM (
SELECT id, json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8
) AS t ORDER BY 1;

-- select json_array_append (stub function, not pushdown constraints, explain)
--Testcase 3554:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_array_append (stub function, not pushdown constraints, result)
--Testcase 3555:
SELECT * FROM (
SELECT id, json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], pi()') FROM s8 WHERE to_hex(id) = '1'
) AS t ORDER BY 1;

-- select json_array_append (stub function, pushdown constraints, explain)
--Testcase 3556:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_array_append (stub function, pushdown constraints, result)
--Testcase 3557:
SELECT * FROM (
SELECT id, json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1
) AS t ORDER BY 1;

-- select json_array_append (stub function, stub in constraints, explain)
--Testcase 3558:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_array_append (stub function, stub in constraints, result)
--Testcase 3559:
SELECT * FROM (
SELECT id, json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], "[true, false]"') FROM s8 WHERE log2(id) > 1
) AS t ORDER BY 1;

-- select json_array_append (stub function, stub in constraints, explain)
--Testcase 3560:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8 WHERE json_depth(json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()')) > 0;

-- select json_array_append (stub function, stub in constraints, result)
--Testcase 3561:
SELECT * FROM (
SELECT id, json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8 WHERE json_depth(json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()')) > 0
) AS t ORDER BY 1;

-- json_array_append with 1 arg explain
--Testcase 3562:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2') FROM s8;

-- json_array_append with 1 arg result
--Testcase 3563:
SELECT * FROM (
SELECT id, json_array_append(c1, '$[1], c2') FROM s8
) AS t ORDER BY 1;

-- json_array_append with 2 args explain
--Testcase 3564:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3') FROM s8;

-- json_array_append with 2 args result
--Testcase 3565:
SELECT * FROM (
SELECT id, json_array_append(c1, '$[1], c2', '$[1], c3') FROM s8
) AS t ORDER BY 1;

-- json_array_append with 3 args explain
--Testcase 3566:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1') FROM s8;

-- json_array_append with 3 args result
--Testcase 3567:
SELECT * FROM (
SELECT id, json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1') FROM s8
) AS t ORDER BY 1;

-- json_array_append with 4 args explain
--Testcase 3568:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"') FROM s8;

-- json_array_append with 4 args result
--Testcase 3569:
SELECT * FROM (
SELECT id, json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"') FROM s8
) AS t ORDER BY 1;

-- json_array_append with 5 args explain
--Testcase 3570:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8;

-- json_array_append with 5 args result
--Testcase 3571:
SELECT * FROM (
SELECT id, json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8
) AS t ORDER BY 1;

-- select json_array_append as nest function with agg (not pushdown, explain)
--Testcase 3572:
EXPLAIN VERBOSE
SELECT sum(id),json_array_append('["a", ["b", "c"], "d"]', '$[1], sum(id)') FROM s8;

-- select json_array_append as nest function with agg (not pushdown, result, error)
--Testcase 3573:
SELECT sum(id),json_array_append('["a", ["b", "c"], "d"]', '$[1], sum(id)') FROM s8;

-- select json_array_append as nest function with json_build_array (pushdown, explain)
--Testcase 3574:
EXPLAIN VERBOSE
SELECT json_array_append(json_build_array('["a", ["b", "c"], "d"]', c1), '$[1], log2(id)') FROM s8;

-- select json_array_append as nest function with json_build_array (pushdown, result)
--Testcase 3575:
SELECT * FROM (
SELECT id, json_array_append(json_build_array('["a", ["b", "c"], "d"]', c1), '$[1], log2(id)') FROM s8
) AS t ORDER BY 1;

-- select json_array_append with non pushdown func and explicit constant (explain)
--Testcase 3576:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2'), pi(), 4.1 FROM s8;

-- select json_array_append with non pushdown func and explicit constant (result)
--Testcase 3577:
SELECT * FROM (
SELECT id, json_array_append(c1, '$[1], c2'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_array_append with order by (explain)
--Testcase 3578:
EXPLAIN VERBOSE
SELECT json_length(json_array_append(c1, '$[1], c2')) FROM s8 ORDER BY 1;

-- select json_array_append with order by (result)
--Testcase 3579:
SELECT json_length(json_array_append(c1, '$[1], c2')) FROM s8 ORDER BY 1;

-- select json_array_append with group by (explain)
--Testcase 3580:
EXPLAIN VERBOSE
SELECT json_length(json_array_append('["a", ["b", "c"], "d"]', '$[1], id')) FROM s8 GROUP BY 1;

-- select json_array_append with group by (result)
--Testcase 3581:
SELECT * FROM (
SELECT id, json_length(json_array_append('["a", ["b", "c"], "d"]', '$[1], id')) FROM s8 GROUP BY 1, 2
) AS t ORDER BY 1;

-- select json_array_append with group by having (explain)
--Testcase 3582:
EXPLAIN VERBOSE
SELECT json_depth(json_array_append('["a", ["b", "c"], "d"]', '$[1], c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_array_append with group by having (result)
--Testcase 3583:
SELECT * FROM (
SELECT id, json_depth(json_array_append('["a", ["b", "c"], "d"]', '$[1], c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1
) AS t ORDER BY 1;

-- select json_array_append and as
--Testcase 3584:
SELECT * FROM (
SELECT id, json_array_append(c1, '$[1], c2') AS json_array_append1 FROM s8
) AS t ORDER BY 1;

-- json_array_insert

-- select json_array_insert (stub function, explain)
--Testcase 3585:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8;

-- select json_array_insert (stub function, result)
--Testcase 3586:
SELECT * FROM (
SELECT id, json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8
) AS t ORDER BY 1;

-- select json_array_insert (stub function, not pushdown constraints, explain)
--Testcase 3587:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_array_insert (stub function, not pushdown constraints, result)
--Testcase 3588:
SELECT * FROM (
SELECT id, json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], pi()') FROM s8 WHERE to_hex(id) = '1'
) AS t ORDER BY 1;

-- select json_array_insert (stub function, pushdown constraints, explain)
--Testcase 3589:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_array_insert (stub function, pushdown constraints, result)
--Testcase 3590:
SELECT * FROM (
SELECT id, json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1
) AS t ORDER BY 1;

-- select json_array_insert (stub function, stub in constraints, explain)
--Testcase 3591:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_array_insert (stub function, stub in constraints, result)
--Testcase 3592:
SELECT * FROM (
SELECT id, json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], "[true, false]"') FROM s8 WHERE log2(id) > 1
) AS t ORDER BY 1;

-- select json_array_insert (stub function, stub in constraints, explain)
--Testcase 3593:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8 WHERE json_depth(json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()')) > 0;

-- select json_array_insert (stub function, stub in constraints, result)
--Testcase 3594:
SELECT * FROM (
SELECT id, json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8 WHERE json_depth(json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()')) > 0
) AS t ORDER BY 1;

-- json_array_insert with 1 arg explain
--Testcase 3595:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2') FROM s8;

-- json_array_insert with 1 arg result
--Testcase 3596:
SELECT * FROM (
SELECT id, json_array_insert(c1, '$[1], c2') FROM s8
) AS t ORDER BY 1;

-- json_array_insert with 2 args explain
--Testcase 3597:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3') FROM s8;

-- json_array_insert with 2 args result
--Testcase 3598:
SELECT * FROM (
SELECT id, json_array_insert(c1, '$[1], c2', '$[1], c3') FROM s8
) AS t ORDER BY 1;

-- json_array_insert with 3 args explain
--Testcase 3599:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1') FROM s8;

-- json_array_insert with 3 args result
--Testcase 3600:
SELECT * FROM (
SELECT id, json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1') FROM s8
) AS t ORDER BY 1;

-- json_array_insert with 4 args explain
--Testcase 3601:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"') FROM s8;

-- json_array_insert with 4 args result
--Testcase 3602:
SELECT * FROM (
SELECT id, json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"') FROM s8
) AS t ORDER BY 1;

-- json_array_insert with 5 args explain
--Testcase 3603:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8;

-- json_array_insert with 5 args result
--Testcase 3604:
SELECT * FROM (
SELECT id, json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8
) AS t ORDER BY 1;

-- select json_array_insert as nest function with agg (not pushdown, explain)
--Testcase 3605:
EXPLAIN VERBOSE
SELECT sum(id),json_array_insert('["a", ["b", "c"], "d"]', '$[1], sum(id)') FROM s8;

-- select json_array_insert as nest function with agg (not pushdown, result, error)
--Testcase 3606:
SELECT sum(id),json_array_insert('["a", ["b", "c"], "d"]', '$[1], sum(id)') FROM s8;

-- select json_array_insert as nest function with json_build_array (pushdown, explain)
--Testcase 3607:
EXPLAIN VERBOSE
SELECT json_array_insert(json_build_array('["a", ["b", "c"], "d"]', c1), '$[1], log2(id)') FROM s8;

-- select json_array_insert as nest function with json_build_array (pushdown, result)
--Testcase 3608:
SELECT * FROM (
SELECT id, json_array_insert(json_build_array('["a", ["b", "c"], "d"]', c1), '$[1], log2(id)') FROM s8
) AS t ORDER BY 1;

-- select json_array_insert with non pushdown func and explicit constant (explain)
--Testcase 3609:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2'), pi(), 4.1 FROM s8;

-- select json_array_insert with non pushdown func and explicit constant (result)
--Testcase 3610:
SELECT * FROM (
SELECT id, json_array_insert(c1, '$[1], c2'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_array_insert with order by (explain)
--Testcase 3611:
EXPLAIN VERBOSE
SELECT json_length(json_array_insert(c1, '$[1], c2')) FROM s8 ORDER BY 1;

-- select json_array_insert with order by (result)
--Testcase 3612:
SELECT json_length(json_array_insert(c1, '$[1], c2')) FROM s8 ORDER BY 1;

-- select json_array_insert with group by (explain)
--Testcase 3613:
EXPLAIN VERBOSE
SELECT id, json_length(json_array_insert('["a", ["b", "c"], "d"]', '$[1], id')) FROM s8 GROUP BY 1, 2;

-- select json_array_insert with group by (result)
--Testcase 3614:
SELECT * FROM (
SELECT id, json_length(json_array_insert('["a", ["b", "c"], "d"]', '$[1], id')) FROM s8 GROUP BY 1, 2
) AS t ORDER BY 1;

-- select json_array_insert with group by having (explain)
--Testcase 3615:
EXPLAIN VERBOSE
SELECT json_depth(json_array_insert('["a", ["b", "c"], "d"]', '$[1], c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_array_insert with group by having (result)
--Testcase 3616:
SELECT * FROM (
SELECT id, json_depth(json_array_insert('["a", ["b", "c"], "d"]', '$[1], c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1
) AS t ORDER BY 1;

-- select json_array_insert and as
--Testcase 3617:
SELECT * FROM (
SELECT id, json_array_insert(c1, '$[1], c2') AS json_array_insert1 FROM s8
) AS t ORDER BY 1;

-- select  json_contains (stub function, explain)
--Testcase 3618:
EXPLAIN VERBOSE
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8;

-- select  json_contains (stub function, result)
--Testcase 3619:
SELECT * FROM (
SELECT id, json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8
) AS t ORDER BY 1;

-- select  json_contains (stub function, not pushdown constraints, explain)
--Testcase 3620:
EXPLAIN VERBOSE
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE to_hex(id) = '2';

-- select  json_contains (stub function, not pushdown constraints, result)
--Testcase 3621:
SELECT * FROM (
SELECT id, json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select  json_contains (stub function, pushdown constraints, explain)
--Testcase 3622:
EXPLAIN VERBOSE
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE id != 0;

-- select  json_contains (stub function, pushdown constraints, result)
--Testcase 3623:
SELECT * FROM (
SELECT id, json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select  json_contains (stub function, json_contains in constraints, explain)
--Testcase 3624:
EXPLAIN VERBOSE
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE json_contains(c1, '1', '$.a') != 1;

-- select  json_contains (stub function, json_contains in constraints, result)
--Testcase 3625:
SELECT * FROM (
SELECT id, json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE json_contains(c1, '1', '$.a') != 1
) AS t ORDER BY 1;

-- select  json_contains (stub function, json_contains in constraints, explain)
--Testcase 3626:
EXPLAIN VERBOSE
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') = 1;

-- select  json_contains (stub function, json_contains in constraints, result)
--Testcase 3627:
SELECT * FROM (
SELECT id, json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') = 1
) AS t ORDER BY 1;

-- select json_contains as nest function with agg (not pushdown, explain)
--Testcase 3628:
EXPLAIN VERBOSE
SELECT sum(id),json_contains('{"a": 1, "b": 2, "c": {"d": 4}}', '1') FROM s8;

-- select json_contains as nest function with agg (not pushdown, result, error)
--Testcase 3629:
SELECT sum(id),json_contains('{"a": 1, "b": 2, "c": {"d": 4}}', '1') FROM s8;

-- select json_contains with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3630:
EXPLAIN VERBOSE
SELECT json_contains(c1, c1, '$.a'), pi(), 4.1 FROM s8;

-- select json_contains with non pushdown func and explicit constant (result)
--Testcase 3631:
SELECT * FROM (
SELECT id, json_contains(c1, c1, '$.a'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_contains with order by index (result)
--Testcase 3632:
SELECT id,  json_contains(c1, '1', '$.a') FROM s8 ORDER BY 2, 1;

-- select json_contains with order by index (result)
--Testcase 3633:
SELECT id,  json_contains(c1, '1', '$.a') FROM s8 ORDER BY 1, 2;

-- select json_contains with group by (EXPLAIN)
--Testcase 3634:
EXPLAIN VERBOSE
SELECT count(id), json_contains(c1, '1', '$.a') FROM s8 group by json_contains(c1, '1', '$.a');

-- select json_contains with group by (result)
--Testcase 3635:
SELECT * FROM (
SELECT count(id), json_contains(c1, '1', '$.a') FROM s8 group by json_contains(c1, '1', '$.a')
) AS t ORDER BY 1;

-- select json_contains with group by index (result)
--Testcase 3636:
SELECT id,  json_contains(c1, '1', '$.a') FROM s8 group by 2, 1;

-- select json_contains with group by index (result)
--Testcase 3637:
SELECT * FROM (
SELECT id,  json_contains(c1, '1', '$.a') FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_contains with group by having (EXPLAIN)
--Testcase 3638:
EXPLAIN VERBOSE
SELECT count(c2), json_contains(c1, '1', '$.a') FROM s8 group by json_contains(c1, '1', '$.a') HAVING count(c2) > 0;

-- select json_contains with group by having (result)
--Testcase 3639:
SELECT * FROM (
SELECT count(c2), json_contains(c1, '1', '$.a') FROM s8 group by json_contains(c1, '1', '$.a') HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_contains with group by index having (result)
--Testcase 3640:
SELECT * FROM (
SELECT c2,  json_contains(c1, '1', '$.a') FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_contains with group by index having (result)
--Testcase 3641:
SELECT * FROM (
SELECT c2,  json_contains(c1, '1', '$.a') FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_contains and as
--Testcase 3642:
SELECT * FROM (
SELECT id, json_contains(c1, c1, '$.a') as json_contains1 FROM s8
) AS t ORDER BY 1;

-- select json_contains_path (builtin function, explain)
--Testcase 3643:
EXPLAIN VERBOSE
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8;

-- select json_contains_path (builtin function, result)
--Testcase 3644:
SELECT * FROM (
SELECT id, json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8
) AS t ORDER BY 1;

-- select json_contains_path (builtin function, not pushdown constraints, explain)
--Testcase 3645:
EXPLAIN VERBOSE
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE to_hex(id) = '2';

-- select json_contains_path (builtin function, not pushdown constraints, result)
--Testcase 3646:
SELECT * FROM (
SELECT id, json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_contains_path (builtin function, pushdown constraints, explain)
--Testcase 3647:
EXPLAIN VERBOSE
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE id != 0;

-- select json_contains_path (builtin function, pushdown constraints, result)
--Testcase 3648:
SELECT * FROM (
SELECT id, json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_contains_path (builtin function, json_contains_path in constraints, explain)
--Testcase 3649:
EXPLAIN VERBOSE
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE json_contains_path(c1, 'one', '$.a', '$.e') != 0;

-- select json_contains_path (builtin function, json_contains_path in constraints, result)
--Testcase 3650:
SELECT * FROM (
SELECT id, json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE json_contains_path(c1, 'one', '$.a', '$.e') != 0
) AS t ORDER BY 1;

-- select json_contains_path (builtin function, json_contains_path in constraints, explain)
--Testcase 3651:
EXPLAIN VERBOSE
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') = 1;

-- select json_contains_path (builtin function, json_contains_path in constraints, result)
--Testcase 3652:
SELECT * FROM (
SELECT id, json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') = 1
) AS t ORDER BY 1;

-- select json_contains_path as nest function with agg (not pushdown, explain)
--Testcase 3653:
EXPLAIN VERBOSE
SELECT sum(id),json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8;

-- select json_contains_path as nest function with agg (not pushdown, result, error)
--Testcase 3654:
SELECT sum(id),json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8;

-- select json_contains_path with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3655:
EXPLAIN VERBOSE
SELECT json_contains_path(c1, 'all', '$.a'), pi(), 4.1 FROM s8;

-- select json_contains_path with non pushdown func and explicit constant (result)
--Testcase 3656:
SELECT * FROM (
SELECT id, json_contains_path(c1, 'all', '$.a'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_contains_path with order by index (result)
--Testcase 3657:
SELECT id,  json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 ORDER BY 2, 1;

-- select json_contains_path with order by index (result)
--Testcase 3658:
SELECT id,  json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 ORDER BY 1, 2;

-- select json_contains_path with group by (EXPLAIN)
--Testcase 3659:
EXPLAIN VERBOSE
SELECT count(id), json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by json_contains_path(c1, 'one', '$.a', '$.e');

-- select json_contains_path with group by (result)
--Testcase 3660:
SELECT * FROM (
SELECT count(id), json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by json_contains_path(c1, 'one', '$.a', '$.e')
) AS t ORDER BY 1;

-- select json_contains_path with group by index (result)
--Testcase 3661:
SELECT * FROM (
SELECT id,  json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_contains_path with group by index (result)
--Testcase 3662:
SELECT * FROM (
SELECT id,  json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_contains_path with group by having (EXPLAIN)
--Testcase 3663:
EXPLAIN VERBOSE
SELECT count(c2), json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by json_contains_path(c1, 'one', '$.a', '$.e') HAVING count(c2) > 0;

-- select json_contains_path with group by having (result)
--Testcase 3664:
SELECT * FROM (
SELECT count(c2), json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by json_contains_path(c1, 'one', '$.a', '$.e') HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_contains_path with group by index having (result)
--Testcase 3665:
SELECT * FROM (
SELECT c2,  json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_contains_path with group by index having (result)
--Testcase 3666:
SELECT * FROM (
SELECT c2,  json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_contains_path and as
--Testcase 3667:
SELECT * FROM (
SELECT id, json_contains_path(c1, 'all', '$.a.d') as json_contains_path1 FROM s8
) AS t ORDER BY 1;

-- select json_depth (builtin function, explain)
--Testcase 3668:
EXPLAIN VERBOSE
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8;

-- select json_depth (builtin function, result)
--Testcase 3669:
SELECT * FROM (
SELECT id, json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8
) AS t ORDER BY 1;

-- select json_depth (builtin function, not pushdown constraints, explain)
--Testcase 3670:
EXPLAIN VERBOSE
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE to_hex(id) = '2';

-- select json_depth (builtin function, not pushdown constraints, result)
--Testcase 3671:
SELECT * FROM (
SELECT id, json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_depth (builtin function, pushdown constraints, explain)
--Testcase 3672:
EXPLAIN VERBOSE
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE id != 0;

-- select json_depth (builtin function, pushdown constraints, result)
--Testcase 3673:
SELECT * FROM (
SELECT id, json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_depth (builtin function, json_depth in constraints, explain)
--Testcase 3674:
EXPLAIN VERBOSE
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE json_depth(c1) != 1;

-- select json_depth (builtin function, json_depth in constraints, result)
--Testcase 3675:
SELECT * FROM (
SELECT id, json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE json_depth(c1) != 1
) AS t ORDER BY 1;

-- select json_depth (builtin function, json_depth in constraints, explain)
--Testcase 3676:
EXPLAIN VERBOSE
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE json_depth('true') = 1;

-- select json_depth (builtin function, json_depth in constraints, result)
--Testcase 3677:
SELECT * FROM (
SELECT id, json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE json_depth('true') = 1
) AS t ORDER BY 1;

-- select json_depth with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3678:
EXPLAIN VERBOSE
SELECT json_depth('[10, {"a": 20}]'), pi(), 4.1 FROM s8;

-- select json_depth with non pushdown func and explicit constant (result)
--Testcase 3679:
SELECT * FROM (
SELECT id, json_depth('[10, {"a": 20}]'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_depth with order by index (result)
--Testcase 3680:
SELECT id,  json_depth(c1) FROM s8 ORDER BY 2, 1;

-- select json_depth with order by index (result)
--Testcase 3681:
SELECT id,  json_depth(c1) FROM s8 ORDER BY 1, 2;

-- select json_depth with group by (EXPLAIN)
--Testcase 3682:
EXPLAIN VERBOSE
SELECT count(id), json_depth(c1) FROM s8 group by json_depth(c1);

-- select json_depth with group by (result)
--Testcase 3683:
SELECT * FROM (
SELECT count(id), json_depth(c1) FROM s8 group by json_depth(c1)
) AS t ORDER BY 1;

-- select json_depth with group by index (result)
--Testcase 3684:
SELECT * FROM (
SELECT id,  json_depth(c1) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_depth with group by index (result)
--Testcase 3685:
SELECT * FROM (
SELECT id,  json_depth(c1) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_depth with group by having (EXPLAIN)
--Testcase 3686:
EXPLAIN VERBOSE
SELECT count(c2), json_depth(c1) FROM s8 group by json_depth(c1) HAVING count(c2) > 0;

-- select json_depth with group by having (result)
--Testcase 3687:
SELECT * FROM (
SELECT count(c2), json_depth(c1) FROM s8 group by json_depth(c1) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_depth with group by index having (result)
--Testcase 3688:
SELECT * FROM (
SELECT c2,  json_depth(c1) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_depth with group by index having (result)
--Testcase 3689:
SELECT * FROM (
SELECT c2,  json_depth(c1) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_depth and as
--Testcase 3690:
SELECT * FROM (
SELECT id, json_depth('[10, {"a": 20}]') as json_depth1 FROM s8
) AS t ORDER BY 1;

-- select json_extract (builtin function, explain)
--Testcase 3691:
EXPLAIN VERBOSE
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8;

-- select json_extract (builtin function, result)
--Testcase 3692:
SELECT * FROM (
SELECT id, json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8
) AS t ORDER BY 1;

-- select json_extract (builtin function, not pushdown constraints, explain)
--Testcase 3693:
EXPLAIN VERBOSE
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE to_hex(id) = '2';

-- select json_extract (builtin function, not pushdown constraints, result)
--Testcase 3694:
SELECT * FROM (
SELECT id, json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_extract (builtin function, pushdown constraints, explain)
--Testcase 3695:
EXPLAIN VERBOSE
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE id != 0;

-- select json_extract (builtin function, pushdown constraints, result)
--Testcase 3696:
SELECT * FROM (
SELECT id, json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_extract (builtin function, json_extract in constraints, explain)
--Testcase 3697:
EXPLAIN VERBOSE
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE json_extract(c1, '$[1]')::numeric != 1;

-- select json_extract (builtin function, json_extract in constraints, result)
--Testcase 3698:
SELECT * FROM (
SELECT id, json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE json_extract(c1, '$[1]')::numeric != 1
) AS t ORDER BY 1;

-- select json_extract (builtin function, json_extract in constraints, explain)
--Testcase 3699:
EXPLAIN VERBOSE
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE json_extract('{"id": 1, "b": {"c": 30}}', '$.id')::numeric = 1;

-- select json_extract (builtin function, json_extract in constraints, result)
--Testcase 3700:
SELECT * FROM (
SELECT id, json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE json_extract('{"id": 1, "b": {"c": 30}}', '$.id')::numeric = 1
) AS t ORDER BY 1;

-- select json_extract as nest function with agg (not pushdown, explain)
--Testcase 3701:
EXPLAIN VERBOSE
SELECT sum(id),json_extract(json_build_array('{"id": 1, "b": {"c": 30}}', sum(id)), '$.id') FROM s8;

-- select json_extract as nest function with agg (not pushdown, result, error)
--Testcase 3702:
SELECT sum(id),json_extract(json_build_array('{"id": 1, "b": {"c": 30}}', sum(id)), '$.id') FROM s8;

-- select json_extract with abnormal cast
--SELECT json_extract(c1, '$.a')::int FROM s8;  -- should fail

-- select json_extract with normal cast
--Testcase 3703:
SELECT * FROM (
SELECT id, json_extract('{"a": "2000-01-01"}', '$.a')::timestamp, json_extract('{"a": "2000-01-01"}', '$.a')::date , json_extract('{"a": 1234}', '$.a')::bigint, json_extract('{"a": "b"}', '$.a')::text FROM s8
) AS t ORDER BY 1;

-- select json_extract with normal cast
--Testcase 3704:
SELECT json_extract('{"a": "2000-01-01"}', '$.a')::timestamptz, json_extract('{"a": "12:10:20.123456"}', '$.a')::time , json_extract('{"a": "12:10:20.123456"}', '$.a')::timetz FROM s8;

-- select json_extract with type modifier (explain)
--Testcase 3705:
EXPLAIN VERBOSE
SELECT json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamp(3), json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamptz(3), json_extract('{"a": "12:10:20.123456"}', '$.a')::time(3), json_extract('{"a": "12:10:20.123456"}', '$.a')::timetz(3) FROM s8;

-- select json_extract with type modifier (result)
--Testcase 3706:
SELECT * FROM (
SELECT json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamp(3), json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamptz(3), json_extract('{"a": "12:10:20.123456"}', '$.a')::time(3), json_extract('{"a": "12:10:20.123456"}', '$.a')::timetz(3) FROM s8
) AS t ORDER BY 1, 2, 3, 4;

-- select json_extract with type modifier (explain)
--Testcase 3707:
EXPLAIN VERBOSE
SELECT json_extract('{"a": 100}', '$.a')::numeric(10, 2), json_extract('{"a": 100}', '$.a')::decimal(10, 2), json_unquote(json_extract('{"a": "1.123456"}', '$.a'))::numeric(10, 3) FROM s8;

-- select json_extract with type modifier (result)
--Testcase 3708:
SELECT * FROM (
SELECT json_extract('{"a": 100}', '$.a')::numeric(10, 2), json_extract('{"a": 100}', '$.a')::decimal(10, 2), json_unquote(json_extract('{"a": "1.123456"}', '$.a'))::numeric(10, 3) FROM s8
) AS t ORDER BY 1, 2, 3;

-- select json_extract with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3709:
EXPLAIN VERBOSE
SELECT json_extract(c1, '$.a'), pi(), 4.1 FROM s8;

-- select json_extract with non pushdown func and explicit constant (result)
--Testcase 3710:
SELECT * FROM (
SELECT id, json_extract(c1, '$.a'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_extract with order by index (result)
--Testcase 3711:
SELECT id,  json_extract(c1, '$[1]') FROM s8 ORDER BY 2, 1;

-- select json_extract with order by index (result)
--Testcase 3712:
SELECT id,  json_extract(c1, '$[1]') FROM s8 ORDER BY 1, 2;

-- select json_extract with group by (EXPLAIN)
--Testcase 3713:
EXPLAIN VERBOSE
SELECT count(id), json_extract(c1, '$[1]') FROM s8 group by json_extract(c1, '$[1]');

-- select json_extract with group by (result)
--Testcase 3714:
SELECT * FROM (
SELECT count(id), json_extract(c1, '$[1]') FROM s8 group by json_extract(c1, '$[1]')
) AS t ORDER BY 1;

-- select json_extract with group by index (result)
--Testcase 3715:
SELECT * FROM (
SELECT id,  json_extract(c1, '$[1]') FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_extract with group by index (result)
--Testcase 3716:
SELECT * FROM (
SELECT id,  json_extract(c1, '$[1]') FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_extract with group by having (EXPLAIN)
--Testcase 3717:
EXPLAIN VERBOSE
SELECT count(c2), json_extract(c1, '$[1]') FROM s8 group by json_extract(c1, '$[1]') HAVING count(c2) > 0;

-- select json_extract with group by having (result)
--Testcase 3718:
SELECT * FROM (
SELECT count(c2), json_extract(c1, '$[1]') FROM s8 group by json_extract(c1, '$[1]') HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_extract with group by index having (result)
--Testcase 3719:
SELECT * FROM (
SELECT c2,  json_extract(c1, '$[1]') FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_extract with group by index having (result)
--Testcase 3720:
SELECT * FROM (
SELECT c2,  json_extract(c1, '$[1]') FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_extract and as
--Testcase 3721:
SELECT * FROM (
SELECT id, json_extract(c1, '$.a') as json_extract1 FROM s8
) AS t ORDER BY 1;

-- JSON_INSERT()
-- select json_insert (stub function, explain)
--Testcase 3722:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- select json_insert (stub function, result)
--Testcase 3723:
SELECT * FROM (
SELECT id, json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8
) AS t ORDER BY 1;

-- select json_insert (stub function, not pushdown constraints, explain)
--Testcase 3724:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_insert (stub function, not pushdown constraints, result)
--Testcase 3725:
SELECT * FROM (
SELECT id, json_insert(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, pi()') FROM s8 WHERE to_hex(id) = '1'
) AS t ORDER BY 1;

-- select json_insert (stub function, pushdown constraints, explain)
--Testcase 3726:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_insert (stub function, pushdown constraints, result)
--Testcase 3727:
SELECT * FROM (
SELECT id, json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1
) AS t ORDER BY 1;

-- select json_insert (stub function, stub in constraints, explain)
--Testcase 3728:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_insert (stub function, stub in constraints, result)
--Testcase 3729:
SELECT * FROM (
SELECT id, json_insert(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, "[true, false]"') FROM s8 WHERE log2(id) > 1
) AS t ORDER BY 1;

-- select json_insert (stub function, stub in constraints, explain)
--Testcase 3730:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8 WHERE json_depth(json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()')) > 0;

-- select json_insert (stub function, stub in constraints, result)
--Testcase 3731:
SELECT * FROM (
SELECT id, json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8 WHERE json_depth(json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()')) > 0
) AS t ORDER BY 1;

-- json_insert with 1 arg explain
--Testcase 3732:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2') FROM s8;

-- json_insert with 1 arg result
--Testcase 3733:
SELECT * FROM (
SELECT id, json_insert(c1, '$.a, c2') FROM s8
) AS t ORDER BY 1;

-- json_insert with 2 args explain
--Testcase 3734:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3') FROM s8;

-- json_insert with 2 args result
--Testcase 3735:
SELECT * FROM (
SELECT id, json_insert(c1, '$.a, c2', '$.b, c3') FROM s8
) AS t ORDER BY 1;

-- json_insert with 3 args explain
--Testcase 3736:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1') FROM s8;

-- json_insert with 3 args result
--Testcase 3737:
SELECT * FROM (
SELECT id, json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1') FROM s8
) AS t ORDER BY 1;

-- json_insert with 4 args explain
--Testcase 3738:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"') FROM s8;

-- json_insert with 4 args result
--Testcase 3739:
SELECT * FROM (
SELECT id, json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"') FROM s8
) AS t ORDER BY 1;

-- json_insert with 5 args explain
--Testcase 3740:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- json_insert with 5 args result
--Testcase 3741:
SELECT * FROM (
SELECT id, json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8
) AS t ORDER BY 1;

-- select json_insert as nest function with agg (not pushdown, explain)
--Testcase 3742:
EXPLAIN VERBOSE
SELECT sum(id),json_insert('["a", ["b", "c"], "d"]', '$, sum(id)') FROM s8;

-- select json_insert as nest function with agg (not pushdown, result, error)
--Testcase 3743:
SELECT sum(id),json_insert('["a", ["b", "c"], "d"]', '$, sum(id)') FROM s8;

-- select json_insert as nest function with json_build_array (pushdown, explain)
--Testcase 3744:
EXPLAIN VERBOSE
SELECT json_insert(json_build_array('["a", ["b", "c"], "d"]', c1), '$, log2(id)') FROM s8;

-- select json_insert as nest function with json_build_array (pushdown, result)
--Testcase 3745:
SELECT * FROM (
SELECT id, json_insert(json_build_array('["a", ["b", "c"], "d"]', c1), '$, log2(id)') FROM s8
) AS t ORDER BY 1;

-- select json_insert with non pushdown func and explicit constant (explain)
--Testcase 3746:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2'), pi(), 4.1 FROM s8;

-- select json_insert with non pushdown func and explicit constant (result)
--Testcase 3747:
SELECT * FROM (
SELECT id, json_insert(c1, '$.a, c2'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_insert with order by (explain)
--Testcase 3748:
EXPLAIN VERBOSE
SELECT json_length(json_insert(c1, '$.a, c2')) FROM s8 ORDER BY 1;

-- select json_insert with order by (result)
--Testcase 3749:
SELECT json_length(json_insert(c1, '$.a, c2')) FROM s8 ORDER BY 1;

-- select json_insert with group by (explain)
--Testcase 3750:
EXPLAIN VERBOSE
SELECT json_length(json_insert('["a", ["b", "c"], "d"]', '$, id')) FROM s8 GROUP BY 1;

-- select json_insert with group by (result)
--Testcase 3751:
SELECT * FROM (
SELECT id, json_length(json_insert('["a", ["b", "c"], "d"]', '$, id')) FROM s8 GROUP BY id, 2
) AS t ORDER BY 1;

-- select json_insert with group by having (explain)
--Testcase 3752:
EXPLAIN VERBOSE
SELECT json_depth(json_insert('["a", ["b", "c"], "d"]', '$, c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_insert with group by having (result)
--Testcase 3753:
SELECT * FROM (
SELECT id, json_depth(json_insert('["a", ["b", "c"], "d"]', '$, c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1
) AS t ORDER BY 1;

-- select json_insert and as
--Testcase 3754:
SELECT * FROM (
SELECT id, json_insert(c1, '$.a, c2') AS json_insert1 FROM s8
) AS t ORDER BY 1;

-- JSON_KEYS()
-- select json_keys (builtin function, explain)
--Testcase 3755:
EXPLAIN VERBOSE
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.a') FROM s8;

-- select json_keys (builtin function, result)
--Testcase 3756:
SELECT * FROM (
SELECT id, json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.a') FROM s8
) AS t ORDER BY 1;

-- select json_keys (builtin function, not pushdown constraints, explain)
--Testcase 3757:
EXPLAIN VERBOSE
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.a') FROM s8 WHERE to_hex(id) = '2';

-- select json_keys (builtin function, not pushdown constraints, result)
--Testcase 3758:
SELECT * FROM (
SELECT id, json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.a') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_keys (builtin function, pushdown constraints, explain)
--Testcase 3759:
EXPLAIN VERBOSE
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.a') FROM s8 WHERE id != 0;

-- select json_keys (builtin function, pushdown constraints, result)
--Testcase 3760:
SELECT * FROM (
SELECT id, json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.a') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_keys (builtin function, json_keys in constraints, explain)
--Testcase 3761:
EXPLAIN VERBOSE
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.b') FROM s8 WHERE json_length(json_keys(c1)) != 1;

-- select json_keys (builtin function, json_keys in constraints, result)
--Testcase 3762:
SELECT * FROM (
SELECT id, json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.b') FROM s8 WHERE json_length(json_keys(c1)) != 1
) AS t ORDER BY 1;

-- select json_keys (builtin function, json_keys in constraints, explain)
--Testcase 3763:
EXPLAIN VERBOSE
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.b') FROM s8 WHERE json_length(json_keys('{"a": 1, "b": {"c": 30}}', '$.b')) = 1;

-- select json_keys (builtin function, json_keys in constraints, result)
--Testcase 3764:
SELECT * FROM (
SELECT id, json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.b') FROM s8 WHERE json_length(json_keys('{"a": 1, "b": {"c": 30}}', '$.b')) = 1
) AS t ORDER BY 1;

-- select json_keys as nest function with agg (not pushdown, explain)
--Testcase 3765:
EXPLAIN VERBOSE
SELECT sum(id),json_keys('{"a": 1, "b": {"c": 30}}', '$.b') FROM s8;

-- select json_keys as nest function with agg (not pushdown, result, error)
--Testcase 3766:
SELECT sum(id),json_keys('{"a": 1, "b": {"c": 30}}', '$.b') FROM s8;

-- select json_keys with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3767:
EXPLAIN VERBOSE
SELECT json_keys(json_build_object('a', c3)), pi(), 4.1 FROM s8;

-- select json_keys with non pushdown func and explicit constant (result)
--Testcase 3768:
SELECT * FROM (
SELECT id, json_keys(json_build_object('a', c3)), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_keys with order by index (result)
--Testcase 3769:
SELECT id,  json_length(json_keys(c1)) FROM s8 ORDER BY 2, 1;

-- select json_keys with order by index (result)
--Testcase 3770:
SELECT id,  json_length(json_keys(c1)) FROM s8 ORDER BY 1, 2;

-- select json_keys with group by (EXPLAIN)
--Testcase 3771:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_keys(c1)) FROM s8 group by json_length(json_keys(c1));

-- select json_keys with group by (result)
--Testcase 3772:
SELECT * FROM (
SELECT count(id), json_length(json_keys(c1)) FROM s8 group by json_length(json_keys(c1))
) AS t ORDER BY 1;

-- select json_keys with group by index (result)
--Testcase 3773:
SELECT * FROM (
SELECT id,  json_length(json_keys(c1)) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_keys with group by index (result)
--Testcase 3774:
SELECT * FROM (
SELECT id,  json_length(json_keys(c1)) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_keys with group by having (EXPLAIN)
--Testcase 3775:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_keys(c1)) FROM s8 group by json_length(json_keys(c1)) HAVING count(c2) > 0;

-- select json_keys with group by having (result)
--Testcase 3776:
SELECT * FROM (
SELECT count(c2), json_length(json_keys(c1)) FROM s8 group by json_length(json_keys(c1)) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_keys with group by index having (result)
--Testcase 3777:
SELECT * FROM (
SELECT c2,  json_length(json_keys(c1)) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_keys with group by index having (result)
--Testcase 3778:
SELECT * FROM (
SELECT c2,  json_length(json_keys(c1)) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_keys and as
--Testcase 3779:
SELECT * FROM (
SELECT id, json_keys(json_build_object('a', c3)) as json_keys1 FROM s8
) AS t ORDER BY 1;

-- select json_length (builtin function, explain)
--Testcase 3780:
EXPLAIN VERBOSE
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_length (builtin function, result)
--Testcase 3781:
SELECT * FROM (
SELECT id, json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8
) AS t ORDER BY 1;

-- select json_length (builtin function, not pushdown constraints, explain)
--Testcase 3782:
EXPLAIN VERBOSE
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE to_hex(id) = '2';

-- select json_length (builtin function, not pushdown constraints, result)
--Testcase 3783:
SELECT * FROM (
SELECT id, json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_length (builtin function, pushdown constraints, explain)
--Testcase 3784:
EXPLAIN VERBOSE
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE id != 0;

-- select json_length (builtin function, pushdown constraints, result)
--Testcase 3785:
SELECT * FROM (
SELECT id, json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_length (builtin function, json_length in constraints, explain)
--Testcase 3786:
EXPLAIN VERBOSE
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_length(c1) != 1;

-- select json_length (builtin function, json_length in constraints, result)
--Testcase 3787:
SELECT * FROM (
SELECT id, json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_length(c1) != 1
) AS t ORDER BY 1;

-- select json_length (builtin function, json_length in constraints, explain)
--Testcase 3788:
EXPLAIN VERBOSE
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_length('{"a": 1, "b": {"c": 30}}') = 2;

-- select json_length (builtin function, json_length in constraints, result)
--Testcase 3789:
SELECT * FROM (
SELECT id, json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_length('{"a": 1, "b": {"c": 30}}') = 2
) AS t ORDER BY 1;

-- select json_length as nest function with agg (not pushdown, explain)
--Testcase 3790:
EXPLAIN VERBOSE
SELECT sum(id),json_length('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_length as nest function with agg (not pushdown, result, error)
--Testcase 3791:
SELECT sum(id),json_length('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_length with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3792:
EXPLAIN VERBOSE
SELECT json_length(json_build_array(c1, 'a', c2)), pi(), 4.1 FROM s8;

-- select json_length with non pushdown func and explicit constant (result)
--Testcase 3793:
SELECT * FROM (
SELECT id, json_length(json_build_array(c1, 'a', c2)), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_length with order by index (result)
--Testcase 3794:
SELECT id, json_length(c1) FROM s8 ORDER BY 2, 1;

-- select json_length with order by index (result)
--Testcase 3795:
SELECT id, json_length(c1) FROM s8 ORDER BY 1, 2;

-- select json_length with group by (EXPLAIN)
--Testcase 3796:
EXPLAIN VERBOSE
SELECT count(id), json_length(c1) FROM s8 group by json_length(c1);

-- select json_length with group by (result)
--Testcase 3797:
SELECT * FROM (
SELECT count(id), json_length(c1) FROM s8 group by json_length(c1)
) AS t ORDER BY 1;

-- select json_length with group by index (result)
--Testcase 3798:
SELECT * FROM (
SELECT id, json_length(c1) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_length with group by index (result)
--Testcase 3799:
SELECT * FROM (
SELECT id, json_length(c1) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_length with group by having (EXPLAIN)
--Testcase 3800:
EXPLAIN VERBOSE
SELECT count(c2), json_length(c1) FROM s8 group by json_length(c1) HAVING count(c2) > 0;

-- select json_length with group by having (result)
--Testcase 3801:
SELECT * FROM (
SELECT count(c2), json_length(c1) FROM s8 group by json_length(c1) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_length with group by index having (result)
--Testcase 3802:
SELECT * FROM (
SELECT c2, json_length(c1) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_length with group by index having (result)
--Testcase 3803:
SELECT * FROM (
SELECT c2, json_length(c1) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_length and as
--Testcase 3804:
SELECT * FROM (
SELECT id, json_length(json_build_array(c1, 'a', c2)) as json_length1 FROM s8
) AS t ORDER BY 1;

-- select json_merge (builtin function, explain)
--Testcase 3805:
EXPLAIN VERBOSE
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8;

-- select json_merge (builtin function, result)
--Testcase 3806:
SELECT * FROM (
SELECT id, json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8
) AS t ORDER BY 1;

-- select json_merge (builtin function, not pushdown constraints, explain)
--Testcase 3807:
EXPLAIN VERBOSE
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE to_hex(id) = '2';

-- select json_merge (builtin function, not pushdown constraints, result)
--Testcase 3808:
SELECT * FROM (
SELECT id, json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_merge (builtin function, pushdown constraints, explain)
--Testcase 3809:
EXPLAIN VERBOSE
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE id != 0;

-- select json_merge (builtin function, pushdown constraints, result)
--Testcase 3810:
SELECT * FROM (
SELECT id, json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_merge (builtin function, json_merge in constraints, explain)
--Testcase 3811:
EXPLAIN VERBOSE
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge(c1, '[1, 2]')) != 1;

-- select json_merge (builtin function, json_merge in constraints, result)
--Testcase 3812:
SELECT * FROM (
SELECT id, json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge(c1, '[1, 2]')) != 1
) AS t ORDER BY 1;

-- select json_merge (builtin function, json_merge in constraints, explain)
--Testcase 3813:
EXPLAIN VERBOSE
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge('[1, 2]', '[true, false]')) = 4;

-- select json_merge (builtin function, json_merge in constraints, result)
--Testcase 3814:
SELECT * FROM (
SELECT id, json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge('[1, 2]', '[true, false]')) = 4
) AS t ORDER BY 1;

-- select json_merge as nest function with agg (not pushdown, explain)
--Testcase 3815:
EXPLAIN VERBOSE
SELECT sum(id),json_merge('[1, 2]', '[true, false]') FROM s8;

-- select json_merge as nest function with agg (not pushdown, result, error)
--Testcase 3816:
SELECT sum(id),json_merge('[1, 2]', '[true, false]') FROM s8;

-- select json_merge with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3817:
EXPLAIN VERBOSE
SELECT json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), pi(), 4.1 FROM s8;

-- select json_merge with non pushdown func and explicit constant (result)
--Testcase 3818:
SELECT * FROM (
SELECT id, json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_merge with order by index (result)
--Testcase 3819:
SELECT id, json_length(json_merge(c1, '[1, 2]')) FROM s8 ORDER BY 2, 1;

-- select json_merge with order by index (result)
--Testcase 3820:
SELECT id, json_length(json_merge(c1, '[1, 2]')) FROM s8 ORDER BY 1, 2;

-- select json_merge with group by (EXPLAIN)
--Testcase 3821:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_merge(c1, '[1, 2]')) FROM s8 group by json_length(json_merge(c1, '[1, 2]'));

-- select json_merge with group by (result)
--Testcase 3822:
SELECT * FROM (
SELECT count(id), json_length(json_merge(c1, '[1, 2]')) FROM s8 group by json_length(json_merge(c1, '[1, 2]'))
) AS t ORDER BY 1;

-- select json_merge with group by index (result)
--Testcase 3823:
SELECT * FROM (
SELECT id, json_length(json_merge(c1, '[1, 2]')) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_merge with group by index (result)
--Testcase 3824:
SELECT * FROM (
SELECT id, json_length(json_merge(c1, '[1, 2]')) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_merge with group by having (EXPLAIN)
--Testcase 3825:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_merge(c1, '[1, 2]')) FROM s8 group by json_length(json_merge(c1, '[1, 2]')) HAVING count(c2) > 0;

-- select json_merge with group by having (result)
--Testcase 3826:
SELECT * FROM (
SELECT count(c2), json_length(json_merge(c1, '[1, 2]')) FROM s8 group by json_length(json_merge(c1, '[1, 2]')) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_merge with group by index having (result)
--Testcase 3827:
SELECT * FROM (
SELECT c2, json_length(json_merge(c1, '[1, 2]')) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_merge with group by index having (result)
--Testcase 3828:
SELECT * FROM (
SELECT c2, json_length(json_merge(c1, '[1, 2]')) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_merge and as
--Testcase 3829:
SELECT * FROM (
SELECT id, json_merge(json_build_array(c1, '[1, 2]'), '[true, false]') as json_merge1 FROM s8
) AS t ORDER BY 1;

-- select json_merge_patch (builtin function, explain)
--Testcase 3830:
EXPLAIN VERBOSE
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_patch (builtin function, result)
--Testcase 3831:
SELECT * FROM (
SELECT id, json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8
) AS t ORDER BY 1;

-- select json_merge_patch (builtin function, not pushdown constraints, explain)
--Testcase 3832:
EXPLAIN VERBOSE
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE to_hex(id) = '2';

-- select json_merge_patch (builtin function, not pushdown constraints, result)
--Testcase 3833:
SELECT * FROM (
SELECT id, json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_merge_patch (builtin function, pushdown constraints, explain)
--Testcase 3834:
EXPLAIN VERBOSE
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE id != 0;

-- select json_merge_patch (builtin function, pushdown constraints, result)
--Testcase 3835:
SELECT * FROM (
SELECT id, json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_merge_patch (builtin function, json_merge_patch in constraints, explain)
--Testcase 3836:
EXPLAIN VERBOSE
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_patch(c1, '[1, 2]')) != 1;

-- select json_merge_patch (builtin function, json_merge_patch in constraints, result)
--Testcase 3837:
SELECT * FROM (
SELECT id, json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_patch(c1, '[1, 2]')) != 1
) AS t ORDER BY 1;

-- select json_merge_patch (builtin function, json_merge_patch in constraints, explain)
--Testcase 3838:
EXPLAIN VERBOSE
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_patch('[1, 2]', '[true, false]')) = 2;

-- select json_merge_patch (builtin function, json_merge_patch in constraints, result)
--Testcase 3839:
SELECT * FROM (
SELECT id, json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_patch('[1, 2]', '[true, false]')) = 2
) AS t ORDER BY 1;

-- select json_merge_patch as nest function with agg (not pushdown, explain)
--Testcase 3840:
EXPLAIN VERBOSE
SELECT sum(id),json_merge_patch('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_patch as nest function with agg (not pushdown, result, error)
--Testcase 3841:
SELECT sum(id),json_merge_patch('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_patch with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3842:
EXPLAIN VERBOSE
SELECT json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), pi(), 4.1 FROM s8;

-- select json_merge_patch with non pushdown func and explicit constant (result)
--Testcase 3843:
SELECT * FROM (
SELECT id, json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_merge_patch with order by index (result)
--Testcase 3844:
SELECT id, json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 ORDER BY 2, 1;

-- select json_merge_patch with order by index (result)
--Testcase 3845:
SELECT id, json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 ORDER BY 1, 2;

-- select json_merge_patch with group by (EXPLAIN)
--Testcase 3846:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_patch(c1, '[1, 2]'));

-- select json_merge_patch with group by (result)
--Testcase 3847:
SELECT * FROM (
SELECT count(id), json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_patch(c1, '[1, 2]'))
) AS t ORDER BY 1;

-- select json_merge_patch with group by index (result)
--Testcase 3848:
SELECT * FROM (
SELECT id, json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_merge_patch with group by index (result)
--Testcase 3849:
SELECT * FROM (
SELECT id, json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_merge_patch with group by having (EXPLAIN)
--Testcase 3850:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_patch(c1, '[1, 2]')) HAVING count(c2) > 0;

-- select json_merge_patch with group by having (result)
--Testcase 3851:
SELECT * FROM (
SELECT count(c2), json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_patch(c1, '[1, 2]')) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_merge_patch with group by index having (result)
--Testcase 3852:
SELECT * FROM (
SELECT c2, json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_merge_patch with group by index having (result)
--Testcase 3853:
SELECT * FROM (
SELECT c2, json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_merge_patch and as
--Testcase 3854:
SELECT * FROM (
SELECT id, json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]') as json_merge_patch1 FROM s8
) AS t ORDER BY 1;

-- select json_merge_preserve (builtin function, explain)
--Testcase 3855:
EXPLAIN VERBOSE
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_preserve (builtin function, result)
--Testcase 3856:
SELECT * FROM (
SELECT id, json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8
) AS t ORDER BY 1;

-- select json_merge_preserve (builtin function, not pushdown constraints, explain)
--Testcase 3857:
EXPLAIN VERBOSE
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE to_hex(id) = '2';

-- select json_merge_preserve (builtin function, not pushdown constraints, result)
--Testcase 3858:
SELECT * FROM (
SELECT id, json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_merge_preserve (builtin function, pushdown constraints, explain)
--Testcase 3859:
EXPLAIN VERBOSE
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE id != 0;

-- select json_merge_preserve (builtin function, pushdown constraints, result)
--Testcase 3860:
SELECT * FROM (
SELECT id, json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_merge_preserve (builtin function, json_merge_preserve in constraints, explain)
--Testcase 3861:
EXPLAIN VERBOSE
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_preserve(c1, '[1, 2]')) != 1;

-- select json_merge_preserve (builtin function, json_merge_preserve in constraints, result)
--Testcase 3862:
SELECT * FROM (
SELECT id, json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_preserve(c1, '[1, 2]')) != 1
) AS t ORDER BY 1;

-- select json_merge_preserve (builtin function, json_merge_preserve in constraints, explain)
--Testcase 3863:
EXPLAIN VERBOSE
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_preserve('[1, 2]', '[true, false]')) = 4;

-- select json_merge_preserve (builtin function, json_merge_preserve in constraints, result)
--Testcase 3864:
SELECT * FROM (
SELECT id, json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_preserve('[1, 2]', '[true, false]')) = 4
) AS t ORDER BY 1;

-- select json_merge_preserve as nest function with agg (not pushdown, explain)
--Testcase 3865:
EXPLAIN VERBOSE
SELECT sum(id),json_merge_preserve('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_preserve as nest function with agg (not pushdown, result, error)
--Testcase 3866:
SELECT sum(id),json_merge_preserve('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_preserve with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3867:
EXPLAIN VERBOSE
SELECT json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), pi(), 4.1 FROM s8;

-- select json_merge_preserve with non pushdown func and explicit constant (result)
--Testcase 3868:
SELECT * FROM (
SELECT id, json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_merge_preserve with order by index (result)
--Testcase 3869:
SELECT id, json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 ORDER BY 2, 1;

-- select json_merge_preserve with order by index (result)
--Testcase 3870:
SELECT id, json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 ORDER BY 1, 2;

-- select json_merge_preserve with group by (EXPLAIN)
--Testcase 3871:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_preserve(c1, '[1, 2]'));

-- select json_merge_preserve with group by (result)
--Testcase 3872:
SELECT * FROM (
SELECT count(id), json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_preserve(c1, '[1, 2]'))
) AS t ORDER BY 1;

-- select json_merge_preserve with group by index (result)
--Testcase 3873:
SELECT * FROM (
SELECT id, json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_merge_preserve with group by index (result)
--Testcase 3874:
SELECT * FROM (
SELECT id, json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_merge_preserve with group by having (EXPLAIN)
--Testcase 3875:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_preserve(c1, '[1, 2]')) HAVING count(c2) > 0;

-- select json_merge_preserve with group by having (result)
--Testcase 3876:
SELECT * FROM (
SELECT count(c2), json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_preserve(c1, '[1, 2]')) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_merge_preserve with group by index having (result)
--Testcase 3877:
SELECT * FROM (
SELECT c2, json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_merge_preserve with group by index having (result)
--Testcase 3878:
SELECT * FROM (
SELECT c2, json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_merge_preserve and as
--Testcase 3879:
SELECT * FROM (
SELECT id, json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]') as json_merge_preserve1 FROM s8
) AS t ORDER BY 1;

-- json_build_object --> json_object in mysql
-- select json_build_object (builtin function, explain)
--Testcase 3880:
EXPLAIN VERBOSE
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8;

-- select json_build_object (builtin function, result)
--Testcase 3881:
SELECT * FROM (
SELECT id, json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8
) AS t ORDER BY 1;

-- select json_build_object (builtin function, not pushdown constraints, explain)
--Testcase 3882:
EXPLAIN VERBOSE
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE to_hex(id) = '1';

-- select json_build_object (builtin function, not pushdown constraints, result)
--Testcase 3883:
SELECT * FROM (
SELECT id, json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE to_hex(id) = '1'
) AS t ORDER BY 1;

-- select json_build_object (builtin function, pushdown constraints, explain)
--Testcase 3884:
EXPLAIN VERBOSE
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE id = 1;

-- select json_build_object (builtin function, pushdown constraints, result)
--Testcase 3885:
SELECT * FROM (
SELECT id, json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE id = 1
) AS t ORDER BY 1;

-- select json_build_object (builtin function, stub in constraints, explain)
--Testcase 3886:
EXPLAIN VERBOSE
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE log2(id) > 1;

-- select json_build_object (builtin function, stub in constraints, result)
--Testcase 3887:
SELECT * FROM (
SELECT id, json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE log2(id) > 1
) AS t ORDER BY 1;

-- select json_build_object (builtin function, stub in constraints, explain)
--Testcase 3888:
EXPLAIN VERBOSE
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE json_depth(json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE)) > 0;

-- select json_build_object (builtin function, stub in constraints, result)
--Testcase 3889:
SELECT * FROM (
SELECT id, json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE json_depth(json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE)) > 0
) AS t ORDER BY 1;

-- select json_build_object as nest function with agg (not pushdown, explain)
--Testcase 3890:
EXPLAIN VERBOSE
SELECT sum(id),json_build_object('sum', sum(id)) FROM s8;

-- select json_build_object as nest function with agg (not pushdown, result)
--Testcase 3891:
SELECT sum(id),json_build_object('sum', sum(id)) FROM s8;

-- select json_build_object as nest function with stub (pushdown, explain)
--Testcase 3892:
EXPLAIN VERBOSE
SELECT json_build_object('json_val', '{"a": 100}'::json, 'stub_log2', log2(id)) FROM s8;

-- select json_build_object as nest function with stub (pushdown, result)
--Testcase 3893:
SELECT * FROM (
SELECT id, json_build_object('json_val', '{"a": 100}'::json, 'stub_log2', log2(id)) FROM s8
) AS t ORDER BY 1;

-- select json_build_object with non pushdown func and explicit constant (explain)
--Testcase 3894:
EXPLAIN VERBOSE
SELECT json_build_object('val1', '100'), cosd(id), 4.1 FROM s8;

-- select json_build_object with non pushdown func and explicit constant (result)
--Testcase 3895:
SELECT * FROM (
SELECT id, json_build_object('val1', '100'), cosd(id), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_build_object with order by (explain)
--Testcase 3896:
EXPLAIN VERBOSE
SELECT json_length(json_build_object(c1, '$[1], c2')) FROM s8 ORDER BY 1;

-- select json_build_object with order by (result)
--Testcase 3897:
SELECT json_length(json_build_object(c1, '$[1], c2')) FROM s8 ORDER BY 1;

-- select json_build_object with group by (explain)
--Testcase 3898:
EXPLAIN VERBOSE
SELECT json_length(json_build_object('a', c1, 'b', c2, 'c', c3)) FROM s8 GROUP BY 1;

-- select json_build_object with group by (result)
--Testcase 3899:
SELECT * FROM (
SELECT id, json_length(json_build_object('a', c1, 'b', c2, 'c', c3)) FROM s8 GROUP BY 1, 2
) AS t ORDER BY 1;

-- select json_build_object with group by having (explain)
--Testcase 3900:
EXPLAIN VERBOSE
SELECT id, json_depth(json_build_object('a', 1)) FROM s8 GROUP BY 1 HAVING count(c2) > 1;

-- select json_build_object with group by having (result)
--Testcase 3901:
SELECT * FROM (
SELECT id, json_depth(json_build_object('a', 1)) FROM s8 GROUP BY 1 HAVING count(c2) > 1
) AS t ORDER BY 1;

-- select json_build_object and as
--Testcase 3902:
SELECT * FROM (
SELECT id, json_build_object('a', c1, 'b', c2, 'c', c3) AS json_build_object1 FROM s8
) AS t ORDER BY 1;

-- select json_overlaps (builtin function, explain)
--Testcase 3903:
EXPLAIN VERBOSE
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8;

-- select json_overlaps (builtin function, result)
--Testcase 3904:
SELECT * FROM (
SELECT id, json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8
) AS t ORDER BY 1;

-- select json_overlaps (builtin function, not pushdown constraints, explain)
--Testcase 3905:
EXPLAIN VERBOSE
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE to_hex(id) = '2';

-- select json_overlaps (builtin function, not pushdown constraints, result)
--Testcase 3906:
SELECT * FROM (
SELECT id, json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_overlaps (builtin function, pushdown constraints, explain)
--Testcase 3907:
EXPLAIN VERBOSE
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE id != 0;

-- select json_overlaps (builtin function, pushdown constraints, result)
--Testcase 3908:
SELECT * FROM (
SELECT id, json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_overlaps (builtin function, json_overlaps in constraints, explain)
--Testcase 3909:
EXPLAIN VERBOSE
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE json_overlaps(c1, '[[1, 2], [3, 4], 5]') != 1;

-- select json_overlaps (builtin function, json_overlaps in constraints, result)
--Testcase 3910:
SELECT * FROM (
SELECT id, json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE json_overlaps(c1, '[[1, 2], [3, 4], 5]') != 1
) AS t ORDER BY 1;

-- select json_overlaps (builtin function, json_overlaps in constraints, explain)
--Testcase 3911:
EXPLAIN VERBOSE
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE json_overlaps('[1,3,5,7]', '[2,5,7]') = 1;

-- select json_overlaps (builtin function, json_overlaps in constraints, result)
--Testcase 3912:
SELECT * FROM (
SELECT id, json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE json_overlaps('[1,3,5,7]', '[2,5,7]') = 1
) AS t ORDER BY 1;

-- select json_overlaps with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3913:
EXPLAIN VERBOSE
SELECT json_overlaps(c1, c1), pi(), 4.1 FROM s8;

-- select json_overlaps with non pushdown func and explicit constant (result)
--Testcase 3914:
SELECT * FROM (
SELECT id, json_overlaps(c1, c1), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_overlaps with order by index (result)
--Testcase 3915:
SELECT id,  json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 ORDER BY 2, 1;

-- select json_overlaps with order by index (result)
--Testcase 3916:
SELECT id,  json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 ORDER BY 1, 2;

-- select json_overlaps with group by (EXPLAIN)
--Testcase 3917:
EXPLAIN VERBOSE
SELECT count(id), json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by json_overlaps(c1, '[[1, 2], [3, 4], 5]');

-- select json_overlaps with group by (result)
--Testcase 3918:
SELECT * FROM (
SELECT count(id), json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by json_overlaps(c1, '[[1, 2], [3, 4], 5]')
) AS t ORDER BY 1;

-- select json_overlaps with group by index (result)
--Testcase 3919:
SELECT * FROM (
SELECT id,  json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_overlaps with group by index (result)
--Testcase 3920:
SELECT * FROM (
SELECT id,  json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_overlaps with group by having (EXPLAIN)
--Testcase 3921:
EXPLAIN VERBOSE
SELECT count(c2), json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by json_overlaps(c1, '[[1, 2], [3, 4], 5]') HAVING count(c2) > 0;

-- select json_overlaps with group by having (result)
--Testcase 3922:
SELECT * FROM (
SELECT count(c2), json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by json_overlaps(c1, '[[1, 2], [3, 4], 5]') HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_overlaps with group by index having (result)
--Testcase 3923:
SELECT * FROM (
SELECT c2,  json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_overlaps with group by index having (result)
--Testcase 3924:
SELECT * FROM (
SELECT c2,  json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_overlaps and as
--Testcase 3925:
SELECT * FROM (
SELECT id, json_overlaps(c1, c1) as json_overlaps1 FROM s8
) AS t ORDER BY 1;

-- select json_pretty (builtin function, explain)
--Testcase 3926:
EXPLAIN VERBOSE
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8;

-- select json_pretty (builtin function, result)
--Testcase 3927:
SELECT * FROM (
SELECT id, json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8
) AS t ORDER BY 1;

-- select json_pretty (builtin function, not pushdown constraints, explain)
--Testcase 3928:
EXPLAIN VERBOSE
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE to_hex(id) = '2';

-- select json_pretty (builtin function, not pushdown constraints, result)
--Testcase 3929:
SELECT * FROM (
SELECT id, json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_pretty (builtin function, pushdown constraints, explain)
--Testcase 3930:
EXPLAIN VERBOSE
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE id != 0;

-- select json_pretty (builtin function, pushdown constraints, result)
--Testcase 3931:
SELECT * FROM (
SELECT id, json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_pretty (builtin function, json_pretty in constraints, explain)
--Testcase 3932:
EXPLAIN VERBOSE
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE json_length(json_pretty(c1)) != 1;

-- select json_pretty (builtin function, json_pretty in constraints, result)
--Testcase 3933:
SELECT * FROM (
SELECT id, json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE json_length(json_pretty(c1)) != 1
) AS t ORDER BY 1;

-- select json_pretty (builtin function, json_pretty in constraints, explain)
--Testcase 3934:
EXPLAIN VERBOSE
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE json_length( json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]')) = 8;

-- select json_pretty (builtin function, json_pretty in constraints, result)
--Testcase 3935:
SELECT * FROM (
SELECT id, json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE json_length( json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]')) = 8
) AS t ORDER BY 1;

-- select json_pretty as nest function with agg (not pushdown, explain)
--Testcase 3936:
EXPLAIN VERBOSE
SELECT sum(id), json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8;

-- select json_pretty as nest function with agg (not pushdown, result, error)
--Testcase 3937:
SELECT sum(id), json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8;

-- select json_pretty with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3938:
EXPLAIN VERBOSE
SELECT json_pretty('[1,3,5]'), pi(), 4.1 FROM s8;

-- select json_pretty with non pushdown func and explicit constant (result)
--Testcase 3939:
SELECT * FROM (
SELECT id, json_pretty('[1,3,5]'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_pretty with order by index (result)
--Testcase 3940:
SELECT id, json_length(json_pretty(c1)) FROM s8 ORDER BY 2, 1;

-- select json_pretty with order by index (result)
--Testcase 3941:
SELECT id, json_length(json_pretty(c1)) FROM s8 ORDER BY 1, 2;

-- select json_pretty with group by (EXPLAIN)
--Testcase 3942:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_pretty(c1)) FROM s8 group by json_length(json_pretty(c1));

-- select json_pretty with group by (result)
--Testcase 3943:
SELECT * FROM (
SELECT count(id), json_length(json_pretty(c1)) FROM s8 group by json_length(json_pretty(c1))
) AS t ORDER BY 1;

-- select json_pretty with group by index (result)
--Testcase 3944:
SELECT * FROM (
SELECT id, json_length(json_pretty(c1)) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_pretty with group by index (result)
--Testcase 3945:
SELECT * FROM (
SELECT id, json_length(json_pretty(c1)) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_pretty with group by having (EXPLAIN)
--Testcase 3946:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_pretty(c1)) FROM s8 group by json_length(json_pretty(c1)) HAVING count(c2) > 0;

-- select json_pretty with group by having (result)
--Testcase 3947:
SELECT * FROM (
SELECT count(c2), json_length(json_pretty(c1)) FROM s8 group by json_length(json_pretty(c1)) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_pretty with group by index having (result)
--Testcase 3948:
SELECT * FROM (
SELECT c2, json_length(json_pretty(c1)) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_pretty with group by index having (result)
--Testcase 3949:
SELECT * FROM (
SELECT c2, json_length(json_pretty(c1)) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_pretty and as
--Testcase 3950:
SELECT * FROM (
SELECT id, json_pretty('[1,3,5]') as json_pretty1 FROM s8
) AS t ORDER BY 1;

-- select json_quote (builtin function, explain)
--Testcase 3951:
EXPLAIN VERBOSE
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8;

-- select json_quote (builtin function, result)
--Testcase 3952:
SELECT * FROM (
SELECT id, json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8
) AS t ORDER BY 1;

-- select json_quote (builtin function, not pushdown constraints, explain)
--Testcase 3953:
EXPLAIN VERBOSE
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE to_hex(id) = '2';

-- select json_quote (builtin function, not pushdown constraints, result)
--Testcase 3954:
SELECT * FROM (
SELECT id, json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_quote (builtin function, pushdown constraints, explain)
--Testcase 3955:
EXPLAIN VERBOSE
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE id != 0;

-- select json_quote (builtin function, pushdown constraints, result)
--Testcase 3956:
SELECT * FROM (
SELECT id, json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_quote (builtin function, json_quote in constraints, explain)
--Testcase 3957:
EXPLAIN VERBOSE
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE json_length(json_quote(c3)) != 0;

-- select json_quote (builtin function, json_quote in constraints, result)
--Testcase 3958:
SELECT * FROM (
SELECT id, json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE json_length(json_quote(c3)) != 0
) AS t ORDER BY 1;

-- select json_quote (builtin function, json_quote in constraints, explain)
--Testcase 3959:
EXPLAIN VERBOSE
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE json_length(json_quote('[1, 2, 3]')) = 1;

-- select json_quote (builtin function, json_quote in constraints, result)
--Testcase 3960:
SELECT * FROM (
SELECT id, json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE json_length(json_quote('[1, 2, 3]')) = 1
) AS t ORDER BY 1;

-- select json_quote as nest function with agg (not pushdown, explain)
--Testcase 3961:
EXPLAIN VERBOSE
SELECT sum(id), json_quote('[1, 2, 3]') FROM s8;

-- select json_quote as nest function with agg (not pushdown, result, error)
--Testcase 3962:
SELECT sum(id), json_quote('[1, 2, 3]') FROM s8;

-- select json_quote with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3963:
EXPLAIN VERBOSE
SELECT json_quote('null'), pi(), 4.1 FROM s8;

-- select json_quote with non pushdown func and explicit constant (result)
--Testcase 3964:
SELECT * FROM (
SELECT id, json_quote('null'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_quote with order by index (result)
--Testcase 3965:
SELECT id,  json_length(json_quote(c3)) FROM s8 ORDER BY 2, 1;

-- select json_quote with order by index (result)
--Testcase 3966:
SELECT id,  json_length(json_quote(c3)) FROM s8 ORDER BY 1, 2;

-- select json_quote with group by (EXPLAIN)
--Testcase 3967:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_quote(c3)) FROM s8 group by json_length(json_quote(c3));

-- select json_quote with group by (result)
--Testcase 3968:
SELECT * FROM (
SELECT count(id), json_length(json_quote(c3)) FROM s8 group by json_length(json_quote(c3))
) AS t ORDER BY 1;

-- select json_quote with group by index (result)
--Testcase 3969:
SELECT * FROM (
SELECT id,  json_length(json_quote(c3)) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_quote with group by index (result)
--Testcase 3970:
SELECT * FROM (
SELECT id,  json_length(json_quote(c3)) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_quote with group by having (EXPLAIN)
--Testcase 3971:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_quote(c3)) FROM s8 group by json_length(json_quote(c3)) HAVING count(c2) > 0;

-- select json_quote with group by having (result)
--Testcase 3972:
SELECT * FROM (
SELECT count(c2), json_length(json_quote(c3)) FROM s8 group by json_length(json_quote(c3)) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_quote with group by index having (result)
--Testcase 3973:
SELECT * FROM (
SELECT c2,  json_length(json_quote(c3)) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_quote with group by index having (result)
--Testcase 3974:
SELECT * FROM (
SELECT c2,  json_length(json_quote(c3)) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_quote and as
--Testcase 3975:
SELECT * FROM (
SELECT id, json_quote('null') as json_quote1 FROM s8
) AS t ORDER BY 1;

-- select json_remove (builtin function, explain)
--Testcase 3976:
EXPLAIN VERBOSE
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'),json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8;

-- select json_remove (builtin function, result)
--Testcase 3977:
SELECT * FROM (
SELECT id, json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8
) AS t ORDER BY 1;

-- select json_remove (builtin function, not pushdown constraints, explain)
--Testcase 3978:
EXPLAIN VERBOSE
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE to_hex(id) = '2';

-- select json_remove (builtin function, not pushdown constraints, result)
--Testcase 3979:
SELECT * FROM (
SELECT id, json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_remove (builtin function, pushdown constraints, explain)
--Testcase 3980:
EXPLAIN VERBOSE
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE id != 0;

-- select json_remove (builtin function, pushdown constraints, result)
--Testcase 3981:
SELECT * FROM (
SELECT id, json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_remove (builtin function, json_remove in constraints, explain)
--Testcase 3982:
EXPLAIN VERBOSE
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE json_length(json_remove(c1, '$[1]')) != 1;

-- select json_remove (builtin function, json_remove in constraints, result)
--Testcase 3983:
SELECT * FROM (
SELECT id, json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE json_length(json_remove(c1, '$[1]')) != 1
) AS t ORDER BY 1;

-- select json_remove (builtin function, json_remove in constraints, explain)
--Testcase 3984:
EXPLAIN VERBOSE
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE json_length(json_remove('{ "a": 1, "b": [2, 3]}', '$.a')) = 1;

-- select json_remove (builtin function, json_remove in constraints, result)
--Testcase 3985:
SELECT * FROM (
SELECT id, json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE json_length(json_remove('{ "a": 1, "b": [2, 3]}', '$.a')) = 1
) AS t ORDER BY 1;

-- select json_remove as nest function with agg (not pushdown, explain)
--Testcase 3986:
EXPLAIN VERBOSE
SELECT sum(id), json_remove('{ "a": 1, "b": [2, 3]}', '$.a') FROM s8;

-- select json_remove as nest function with agg (not pushdown, result, error)
--Testcase 3987:
SELECT sum(id), json_remove('{ "a": 1, "b": [2, 3]}', '$.a') FROM s8;

-- select json_remove with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3988:
EXPLAIN VERBOSE
SELECT json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), pi(), 4.1 FROM s8;

-- select json_remove with non pushdown func and explicit constant (result)
--Testcase 3989:
SELECT * FROM (
SELECT id, json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_remove with order by index (result)
--Testcase 3990:
SELECT id,  json_length(json_remove(c1, '$[1]')) FROM s8 ORDER BY 2, 1;

-- select json_remove with order by index (result)
--Testcase 3991:
SELECT id,  json_length(json_remove(c1, '$[1]')) FROM s8 ORDER BY 1, 2;

-- select json_remove with group by (EXPLAIN)
--Testcase 3992:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_remove(c1, '$[1]')) FROM s8 group by json_length(json_remove(c1, '$[1]'));

-- select json_remove with group by (result)
--Testcase 3993:
SELECT * FROM (
SELECT count(id), json_length(json_remove(c1, '$[1]')) FROM s8 group by json_length(json_remove(c1, '$[1]'))
) AS t ORDER BY 1;

-- select json_remove with group by index (result)
--Testcase 3994:
SELECT * FROM (
SELECT id,  json_length(json_remove(c1, '$[1]')) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_remove with group by index (result)
--Testcase 3995:
SELECT * FROM (
SELECT id,  json_length(json_remove(c1, '$[1]')) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_remove with group by having (EXPLAIN)
--Testcase 3996:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_remove(c1, '$[1]')) FROM s8 group by json_length(json_remove(c1, '$[1]')) HAVING count(c2) > 0;

-- select json_remove with group by having (result)
--Testcase 3997:
SELECT * FROM (
SELECT count(c2), json_length(json_remove(c1, '$[1]')) FROM s8 group by json_length(json_remove(c1, '$[1]')) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_remove with group by index having (result)
--Testcase 3998:
SELECT * FROM (
SELECT c2,  json_length(json_remove(c1, '$[1]')) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_remove with group by index having (result)
--Testcase 3999:
SELECT * FROM (
SELECT c2,  json_length(json_remove(c1, '$[1]')) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_remove and as
--Testcase 4000:
SELECT * FROM (
SELECT id, json_remove(json_build_array(c1, '1'), '$[1]', '$[2]') as json_remove1 FROM s8
) AS t ORDER BY 1;

-- select json_replace (stub function, explain)
--Testcase 4001:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- select json_replace (stub function, result)
--Testcase 4002:
SELECT * FROM (
SELECT id, json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8
) AS t ORDER BY 1;

-- select json_replace (stub function, not pushdown constraints, explain)
--Testcase 4003:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_replace (stub function, not pushdown constraints, result)
--Testcase 4004:
SELECT * FROM (
SELECT id, json_replace(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, pi()') FROM s8 WHERE to_hex(id) = '1'
) AS t ORDER BY 1;

-- select json_replace (stub function, pushdown constraints, explain)
--Testcase 4005:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_replace (stub function, pushdown constraints, result)
--Testcase 4006:
SELECT * FROM (
SELECT id, json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1
) AS t ORDER BY 1;

-- select json_replace (stub function, stub in constraints, explain)
--Testcase 4007:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_replace (stub function, stub in constraints, result)
--Testcase 4008:
SELECT * FROM (
SELECT id, json_replace(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, "[true, false]"') FROM s8 WHERE log2(id) > 1
) AS t ORDER BY 1;

-- select json_replace (stub function, stub in constraints, explain)
--Testcase 4009:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8 WHERE json_depth(json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()')) > 0;

-- select json_replace (stub function, stub in constraints, result)
--Testcase 4010:
SELECT * FROM (
SELECT id, json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8 WHERE json_depth(json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()')) > 0
) AS t ORDER BY 1;

-- json_replace with 1 arg explain
--Testcase 4011:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2') FROM s8;

-- json_replace with 1 arg result
--Testcase 4012:
SELECT * FROM (
SELECT id, json_replace(c1, '$.a, c2') FROM s8
) AS t ORDER BY 1;

-- json_replace with 2 args explain
--Testcase 4013:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3') FROM s8;

-- json_replace with 2 args result
--Testcase 4014:
SELECT * FROM (
SELECT id, json_replace(c1, '$.a, c2', '$.b, c3') FROM s8
) AS t ORDER BY 1;

-- json_replace with 3 args explain
--Testcase 4015:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1') FROM s8;

-- json_replace with 3 args result
--Testcase 4016:
SELECT * FROM (
SELECT id, json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1') FROM s8
) AS t ORDER BY 1;

-- json_replace with 4 args explain
--Testcase 4017:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"') FROM s8;

-- json_replace with 4 args result
--Testcase 4018:
SELECT * FROM (
SELECT id, json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"') FROM s8
) AS t ORDER BY 1;

-- json_replace with 5 args explain
--Testcase 4019:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- json_replace with 5 args result
--Testcase 4020:
SELECT * FROM (
SELECT id, json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8
) AS t ORDER BY 1;

-- select json_replace as nest function with agg (not pushdown, explain)
--Testcase 4021:
EXPLAIN VERBOSE
SELECT sum(id),json_replace('["a", ["b", "c"], "d"]', '$, sum(id)') FROM s8;

-- select json_replace as nest function with agg (not pushdown, result, error)
--Testcase 4022:
SELECT sum(id),json_replace('["a", ["b", "c"], "d"]', '$, sum(id)') FROM s8;

-- select json_replace as nest function with json_build_array (pushdown, explain)
--Testcase 4023:
EXPLAIN VERBOSE
SELECT json_replace(json_build_array('["a", ["b", "c"], "d"]', c1), '$, log2(id)') FROM s8;

-- select json_replace as nest function with json_build_array (pushdown, result)
--Testcase 4024:
SELECT * FROM (
SELECT id, json_replace(json_build_array('["a", ["b", "c"], "d"]', c1), '$, log2(id)') FROM s8
) AS t ORDER BY 1;

-- select json_replace with non pushdown func and explicit constant (explain)
--Testcase 4025:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2'), pi(), 4.1 FROM s8;

-- select json_replace with non pushdown func and explicit constant (result)
--Testcase 4026:
SELECT * FROM (
SELECT id, json_replace(c1, '$.a, c2'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_replace with order by (explain)
--Testcase 4027:
EXPLAIN VERBOSE
SELECT json_length(json_replace(c1, '$.a, c2')) FROM s8 ORDER BY 1;

-- select json_replace with order by (result)
--Testcase 4028:
SELECT json_length(json_replace(c1, '$.a, c2')) FROM s8 ORDER BY 1;

-- select json_replace with group by (explain)
--Testcase 4029:
EXPLAIN VERBOSE
SELECT id, json_length(json_replace('["a", ["b", "c"], "d"]', '$, id')) FROM s8 GROUP BY 1 , 2;

-- select json_replace with group by (result)
--Testcase 4030:
SELECT * FROM (
SELECT id, json_length(json_replace('["a", ["b", "c"], "d"]', '$, id')) FROM s8 GROUP BY 1, 2
) AS t ORDER BY 1;

-- select json_replace with group by having (explain)
--Testcase 4031:
EXPLAIN VERBOSE
SELECT json_depth(json_replace('["a", ["b", "c"], "d"]', '$, c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_replace with group by having (result)
--Testcase 4032:
SELECT * FROM (
SELECT id, json_depth(json_replace('["a", ["b", "c"], "d"]', '$, c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1
) AS t ORDER BY 1;

-- select json_replace and as
--Testcase 4033:
SELECT * FROM (
SELECT id, json_replace(c1, '$.a, c2') AS json_replace1 FROM s8
) AS t ORDER BY 1;

-- select json_schema_valid (builtin function, explain)
--Testcase 4034:
EXPLAIN VERBOSE
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_valid (builtin function, result)
--Testcase 4035:
SELECT * FROM (
SELECT id, json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9
) AS t ORDER BY 1;

-- select json_schema_valid (builtin function, not pushdown constraints, explain)
--Testcase 4036:
EXPLAIN VERBOSE
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE to_hex(id) = '1';

-- select json_schema_valid (builtin function, not pushdown constraints, result)
--Testcase 4037:
SELECT * FROM (
SELECT id, json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE to_hex(id) = '1'
) AS t ORDER BY 1;

-- select json_schema_valid (builtin function, pushdown constraints, explain)
--Testcase 4038:
EXPLAIN VERBOSE
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE id != 0;

-- select json_schema_valid (builtin function, pushdown constraints, result)
--Testcase 4039:
SELECT * FROM (
SELECT id, json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE id != 0
) AS t ORDER BY 1;

-- select json_schema_valid (builtin function, json_schema_valid in constraints, explain)
--Testcase 4040:
EXPLAIN VERBOSE
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) != 0;

-- select json_schema_valid (builtin function, json_schema_valid in constraints, result)
--Testcase 4041:
SELECT * FROM (
SELECT id, json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) != 0
) AS t ORDER BY 1;

-- select json_schema_valid (builtin function, json_schema_valid in constraints, explain)
--Testcase 4042:
EXPLAIN VERBOSE
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) = 1;

-- select json_schema_valid (builtin function, json_schema_valid in constraints, result)
--Testcase 4043:
SELECT * FROM (
SELECT id, json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) = 1
) AS t ORDER BY 1;

-- select json_schema_valid as nest function with agg (not pushdown, explain)
--Testcase 4044:
EXPLAIN VERBOSE
SELECT sum(id),json_schema_valid(json_build_object('latitude', sum(id), 'longitude', avg(id)), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_valid as nest function with agg (not pushdown, result, error)
--Testcase 4045:
SELECT sum(id),json_schema_valid(json_build_object('latitude', sum(id), 'longitude', avg(id)), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_valid with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4046:
EXPLAIN VERBOSE
SELECT json_schema_valid(c1, json_quote('null')), pi(), 4.1 FROM s9;

-- select json_schema_valid with non pushdown func and explicit constant (result)
--Testcase 4047:
SELECT * FROM (
SELECT id, json_schema_valid(c1, json_quote('null')), pi(), 4.1 FROM s9
) AS t ORDER BY 1;

-- select json_schema_valid with order by index (result)
--Testcase 4048:
SELECT id,  json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 order by 2, 1;

-- select json_schema_valid with order by index (result)
--Testcase 4049:
SELECT id,  json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 order by 1, 2;

-- select json_schema_valid with group by (EXPLAIN)
--Testcase 4050:
EXPLAIN VERBOSE
SELECT count(id), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json);

-- select json_schema_valid with group by (result)
--Testcase 4051:
SELECT * FROM (
SELECT count(id), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json)
) AS t ORDER BY 1;

-- select json_schema_valid with group by index (result)
--Testcase 4052:
SELECT * FROM (
SELECT id,  json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by 2, 1
) AS t ORDER BY 1;

-- select json_schema_valid with group by index (result)
--Testcase 4053:
SELECT * FROM (
SELECT id,  json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by 1, 2
) AS t ORDER BY 1;

-- select json_schema_valid with group by having (EXPLAIN)
--Testcase 4054:
EXPLAIN VERBOSE
SELECT count(id), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) HAVING count(id) > 0;

-- select json_schema_valid with group by having (result)
--Testcase 4055:
SELECT * FROM (
SELECT count(id), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) HAVING count(id) > 0
) AS t ORDER BY 1;

-- select json_schema_valid with group by index having (result)
--Testcase 4056:
SELECT * FROM (
SELECT id,  json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by 2, 1 HAVING count(id) > 0
) AS t ORDER BY 1;

-- select json_schema_valid with group by index having (result)
--Testcase 4057:
SELECT * FROM (
SELECT id,  json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by 1, 2 HAVING count(id) > 0
) AS t ORDER BY 1;

-- select json_schema_valid and as
--Testcase 4058:
SELECT * FROM (
SELECT id, json_schema_valid(c1, json_quote('null')) as json_schema_valid1 FROM s9
) AS t ORDER BY 1;

-- select json_schema_validation_report (builtin function, explain)
--Testcase 4059:
EXPLAIN VERBOSE
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_validation_report (builtin function, result)
--Testcase 4060:
SELECT * FROM (
SELECT id, json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9
) AS t ORDER BY 1;

-- select json_schema_validation_report (builtin function, not pushdown constraints, explain)
--Testcase 4061:
EXPLAIN VERBOSE
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE to_hex(id) = '1';

-- select json_schema_validation_report (builtin function, not pushdown constraints, result)
--Testcase 4062:
SELECT * FROM (
SELECT id, json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE to_hex(id) = '1'
) AS t ORDER BY 1;

-- select json_schema_validation_report (builtin function, pushdown constraints, explain)
--Testcase 4063:
EXPLAIN VERBOSE
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE id != 0;

-- select json_schema_validation_report (builtin function, pushdown constraints, result)
--Testcase 4064:
SELECT * FROM (
SELECT id, json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE id != 0
) AS t ORDER BY 1;

-- select json_schema_validation_report (builtin function, json_schema_validation_report in constraints, explain)
--Testcase 4065:
EXPLAIN VERBOSE
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) != 0;

-- select json_schema_validation_report (builtin function, json_schema_validation_report in constraints, result)
--Testcase 4066:
SELECT * FROM (
SELECT id, json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) != 0
) AS t ORDER BY 1;

-- select json_schema_validation_report (builtin function, json_schema_validation_report in constraints, explain)
--Testcase 4067:
EXPLAIN VERBOSE
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_length(json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json)) = 1;

-- select json_schema_validation_report (builtin function, json_schema_validation_report in constraints, result)
--Testcase 4068:
SELECT * FROM (
SELECT id, json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_length(json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json)) = 1
) AS t ORDER BY 1;

-- select json_schema_validation_report as nest function with agg (not pushdown, explain)
--Testcase 4069:
EXPLAIN VERBOSE
SELECT sum(id),json_schema_validation_report(json_build_object('latitude', 63, 'longitude', sum(id)), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_validation_report as nest function with agg (not pushdown, result, error)
--Testcase 4070:
SELECT sum(id),json_schema_validation_report(json_build_object('latitude', 63, 'longitude', sum(id)), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_validation_report with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4071:
EXPLAIN VERBOSE
SELECT json_schema_validation_report(c1, json_quote('null')), pi(), 4.1 FROM s9;

-- select json_schema_validation_report with non pushdown func and explicit constant (result)
--Testcase 4072:
SELECT * FROM (
SELECT id, json_schema_validation_report(c1, json_quote('null')), pi(), 4.1 FROM s9
) AS t ORDER BY 1;

-- select json_schema_validation_report with order by index (result)
--Testcase 4073:
SELECT id,  json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 order by 2, 1;

-- select json_schema_validation_report with order by index (result)
--Testcase 4074:
SELECT id,  json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 order by 1, 2;

-- select json_schema_validation_report with group by (EXPLAIN)
--Testcase 4075:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'));

-- select json_schema_validation_report with group by (result)
--Testcase 4076:
SELECT * FROM (
SELECT count(id), json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'))
) AS t ORDER BY 1;

-- select json_schema_validation_report with group by index (result)
--Testcase 4077:
SELECT * FROM (
SELECT id,  json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by 2, 1
) AS t ORDER BY 1;

-- select json_schema_validation_report with group by index (result)
--Testcase 4078:
SELECT * FROM (
SELECT id,  json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by 1, 2
) AS t ORDER BY 1;

-- select json_schema_validation_report with group by having (EXPLAIN)
--Testcase 4079:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) HAVING count(id) > 0;

-- select json_schema_validation_report with group by having (result)
--Testcase 4080:
SELECT * FROM (
SELECT count(id), json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) HAVING count(id) > 0
) AS t ORDER BY 1;

-- select json_schema_validation_report with group by index having (result)
--Testcase 4081:
SELECT * FROM (
SELECT id,  json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by 2, 1 HAVING count(id) > 0
) AS t ORDER BY 1;

-- select json_schema_validation_report with group by index having (result)
--Testcase 4082:
SELECT * FROM (
SELECT id,  json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by 1, 2 HAVING count(id) > 0
) AS t ORDER BY 1;

-- select json_schema_validation_report and as
--Testcase 4083:
SELECT * FROM (
SELECT id, json_schema_validation_report(c1, json_quote('null')) as json_schema_validation_report1 FROM s9
) AS t ORDER BY 1;

-- select json_search (builtin function, explain)
--Testcase 4084:
EXPLAIN VERBOSE
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8;

-- select json_search (builtin function, result)
--Testcase 4085:
SELECT * FROM (
SELECT id, json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8
) AS t ORDER BY 1;

-- select json_search (builtin function, not pushdown constraints, explain)
--Testcase 4086:
EXPLAIN VERBOSE
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 WHERE to_hex(id) = '2';

-- select json_search (builtin function, not pushdown constraints, result)
--Testcase 4087:
SELECT * FROM (
SELECT id, json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_search (builtin function, pushdown constraints, explain)
--Testcase 4088:
EXPLAIN VERBOSE
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 WHERE id != 0;

-- select json_search (builtin function, pushdown constraints, result)
--Testcase 4089:
SELECT * FROM (
SELECT id, json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_search (builtin function, json_search in constraints, explain)
--Testcase 4090:
EXPLAIN VERBOSE
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 WHERE json_search(c1, 'one', 'abc') NOT LIKE '$';

-- select json_search (builtin function, json_search in constraints, result)
--Testcase 4091:
SELECT * FROM (
SELECT id, json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 WHERE json_search(c1, 'one', 'abc') NOT LIKE '$'
) AS t ORDER BY 1;

-- select json_search (builtin function, json_search in constraints, explain)
--Testcase 4092:
EXPLAIN VERBOSE
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 where json_search('[1,3,5,7]', 'one', '[2,5,7]') IS NULL;

-- select json_search (builtin function, json_search in constraints, result)
--Testcase 4093:
SELECT * FROM (
SELECT id, json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 where json_search('[1,3,5,7]', 'one', '[2,5,7]') IS NULL
) AS t ORDER BY 1;

-- select json_search as nest function with agg (not pushdown, explain)
--Testcase 4094:
EXPLAIN VERBOSE
SELECT sum(id),json_search(json_build_array('{"a":1,"b":10,"d":10}', sum(id)), 'all', 'a') FROM s8;

-- select json_search as nest function with agg (not pushdown, result, error)
--Testcase 4095:
SELECT sum(id),json_search(json_build_array('{"a":1,"b":10,"d":10}', sum(id)), 'all', 'a') FROM s8;

-- select json_search with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4096:
EXPLAIN VERBOSE
SELECT json_search(c1, 'one', '%a%'), pi(), 4.1 FROM s8;

-- select json_search with non pushdown func and explicit constant (result)
--Testcase 4097:
SELECT * FROM (
SELECT id, json_search(c1, 'one', '%a%'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_search with order by index (result)
--Testcase 4098:
SELECT id, json_search(c1, 'one', 'abc') FROM s8 ORDER BY 2, 1;

-- select json_search with order by index (result)
--Testcase 4099:
SELECT id, json_search(c1, 'one', 'abc') FROM s8 ORDER BY 1, 2;

-- select json_search with group by (EXPLAIN)
--Testcase 4100:
EXPLAIN VERBOSE
SELECT count(id), json_search(c1, 'one', 'abc') FROM s8 group by json_search(c1, 'one', 'abc');

-- select json_search with group by (result)
--Testcase 4101:
SELECT * FROM (
SELECT count(id), json_search(c1, 'one', 'abc') FROM s8 group by json_search(c1, 'one', 'abc')
) AS t ORDER BY 1;

-- select json_search with group by index (result)
--Testcase 4102:
SELECT * FROM (
SELECT id, json_search(c1, 'one', 'abc') FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_search with group by index (result)
--Testcase 4103:
SELECT * FROM (
SELECT id, json_search(c1, 'one', 'abc') FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_search with group by having (EXPLAIN)
--Testcase 4104:
EXPLAIN VERBOSE
SELECT count(c2), json_search(c1, 'one', 'abc') FROM s8 group by json_search(c1, 'one', 'abc') HAVING count(c2) > 0;

-- select json_search with group by having (result)
--Testcase 4105:
SELECT * FROM (
SELECT count(c2), json_search(c1, 'one', 'abc') FROM s8 group by json_search(c1, 'one', 'abc') HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_search with group by index having (result)
--Testcase 4106:
SELECT * FROM (
SELECT c2, json_search(c1, 'one', 'abc') FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_search with group by index having (result)
--Testcase 4107:
SELECT * FROM (
SELECT c2, json_search(c1, 'one', 'abc') FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_search and as
--Testcase 4108:
SELECT * FROM (
SELECT id, json_search(c1, 'one', '%a%') as json_search1 FROM s8
) AS t ORDER BY 1;

-- JSON_SET()
-- select json_set (stub function, explain)
--Testcase 4109:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- select json_set (stub function, result)
--Testcase 4110:
SELECT * FROM (
SELECT id, json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8
) AS t ORDER BY 1;

-- select json_set (stub function, not pushdown constraints, explain)
--Testcase 4111:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_set (stub function, not pushdown constraints, result)
--Testcase 4112:
SELECT * FROM (
SELECT id, json_set(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, pi()') FROM s8 WHERE to_hex(id) = '1'
) AS t ORDER BY 1;

-- select json_set (stub function, pushdown constraints, explain)
--Testcase 4113:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_set (stub function, pushdown constraints, result)
--Testcase 4114:
SELECT * FROM (
SELECT id, json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1
) AS t ORDER BY 1;

-- select json_set (stub function, stub in constraints, explain)
--Testcase 4115:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_set (stub function, stub in constraints, result)
--Testcase 4116:
SELECT * FROM (
SELECT id, json_set(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, "[true, false]"') FROM s8 WHERE log2(id) > 1
) AS t ORDER BY 1;

-- select json_set (stub function, stub in constraints, explain)
--Testcase 4117:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8 WHERE json_depth(json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()')) > 0;

-- select json_set (stub function, stub in constraints, result)
--Testcase 4118:
SELECT * FROM (
SELECT id, json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8 WHERE json_depth(json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()')) > 0
) AS t ORDER BY 1;

-- json_set with 1 arg explain
--Testcase 4119:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2') FROM s8;

-- json_set with 1 arg result
--Testcase 4120:
SELECT * FROM (
SELECT id, json_set(c1, '$.a, c2') FROM s8
) AS t ORDER BY 1;

-- json_set with 2 args explain
--Testcase 4121:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3') FROM s8;

-- json_set with 2 args result
--Testcase 4122:
SELECT * FROM (
SELECT id, json_set(c1, '$.a, c2', '$.b, c3') FROM s8
) AS t ORDER BY 1;

-- json_set with 3 args explain
--Testcase 4123:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1') FROM s8;

-- json_set with 3 args result
--Testcase 4124:
SELECT * FROM (
SELECT id, json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1') FROM s8
) AS t ORDER BY 1;

-- json_set with 4 args explain
--Testcase 4125:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"') FROM s8;

-- json_set with 4 args result
--Testcase 4126:
SELECT * FROM (
SELECT id, json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"') FROM s8
) AS t ORDER BY 1;

-- json_set with 5 args explain
--Testcase 4127:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- json_set with 5 args result
--Testcase 4128:
SELECT * FROM (
SELECT id, json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8
) AS t ORDER BY 1;

-- select json_set as nest function with agg (not pushdown, explain)
--Testcase 4129:
EXPLAIN VERBOSE
SELECT sum(id),json_set('["a", ["b", "c"], "d"]', '$, sum(id)') FROM s8;

-- select json_set as nest function with agg (not pushdown, result, error)
--Testcase 4130:
SELECT sum(id),json_set('["a", ["b", "c"], "d"]', '$, sum(id)') FROM s8;

-- select json_set as nest function with json_build_array (pushdown, explain)
--Testcase 4131:
EXPLAIN VERBOSE
SELECT json_set(json_build_array('["a", ["b", "c"], "d"]', c1), '$, log2(id)') FROM s8;

-- select json_set as nest function with json_build_array (pushdown, result)
--Testcase 4132:
SELECT * FROM (
SELECT id, json_set(json_build_array('["a", ["b", "c"], "d"]', c1), '$, log2(id)') FROM s8
) AS t ORDER BY 1;

-- select json_set with non pushdown func and explicit constant (explain)
--Testcase 4133:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2'), pi(), 4.1 FROM s8;

-- select json_set with non pushdown func and explicit constant (result)
--Testcase 4134:
SELECT * FROM (
SELECT id, json_set(c1, '$.a, c2'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_set with order by (explain)
--Testcase 4135:
EXPLAIN VERBOSE
SELECT json_length(json_set(c1, '$.a, c2')) FROM s8 ORDER BY 1;

-- select json_set with order by (result)
--Testcase 4136:
SELECT json_length(json_set(c1, '$.a, c2')) FROM s8 ORDER BY 1;

-- select json_set with group by (explain)
--Testcase 4137:
EXPLAIN VERBOSE
SELECT id, json_length(json_set('["a", ["b", "c"], "d"]', '$, id')) FROM s8 GROUP BY 1, 2;

-- select json_set with group by (result)
--Testcase 4138:
SELECT * FROM (
SELECT id, json_length(json_set('["a", ["b", "c"], "d"]', '$, id')) FROM s8 GROUP BY 1, 2
) AS t ORDER BY 1;

-- select json_set with group by having (explain)
--Testcase 4139:
EXPLAIN VERBOSE
SELECT json_depth(json_set('["a", ["b", "c"], "d"]', '$, c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_set with group by having (result)
--Testcase 4140:
SELECT * FROM (
SELECT id, json_depth(json_set('["a", ["b", "c"], "d"]', '$, c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1
) AS t ORDER BY 1;

-- select json_set and as
--Testcase 4141:
SELECT * FROM (
SELECT id, json_set(c1, '$.a, c2') AS json_set1 FROM s8
) AS t ORDER BY 1;

-- json_storage_free()
-- insert new value for test json_storage_free()
--Testcase 4142:
CREATE EXTENSION mysql_fdw;
--Testcase 4143:
CREATE SERVER mysql_svr FOREIGN DATA WRAPPER mysql_fdw;
--Testcase 4144:
CREATE USER MAPPING FOR CURRENT_USER SERVER mysql_svr OPTIONS(username 'root', password 'Mysql_1234');
--Testcase 4145:
CREATE FOREIGN TABLE s81_mysql_svr (id int, c1 json, c2 int, c3 text) SERVER mysql_svr OPTIONS(dbname 'test', table_name 's81');
--Testcase 4146:
INSERT INTO s81_mysql_svr VALUES (6, '{"a": 10, "b": "wxyz", "c": "[true, false]"}', 1, 'Text');

-- select json_storage_free (stub function, explain)
--Testcase 4147:
EXPLAIN VERBOSE
SELECT json_storage_free(c1), json_storage_free('{"a": 10, "b": "wxyz", "c": "[true, false]"}') FROM s8 WHERE id = 6;

-- select json_storage_free (stub function, result)
--Testcase 4148:
SELECT json_storage_free(c1), json_storage_free('{"a": 10, "b": "wxyz", "c": "[true, false]"}') FROM s8 WHERE id = 6;

-- update new value for json value of table s8
--Testcase 4149:
UPDATE s81_mysql_svr SET c1 = json_set(c1, '$.a, 10', '$.b, "wx"') WHERE id = 6;

-- select json_storage_free (stub function, explain)
--Testcase 4150:
EXPLAIN VERBOSE
SELECT json_storage_free(c1), json_storage_free('{"a": 10, "b": "wxyz", "c": "[true, false]"}') FROM s8 WHERE id = 6;

-- select json_storage_free (stub function, result)
--Testcase 4151:
SELECT json_storage_free(c1), json_storage_free('{"a": 10, "b": "wxyz", "c": "[true, false]"}') FROM s8 WHERE id = 6;

-- revert change
--Testcase 4152:
DELETE FROM s81_mysql_svr WHERE id = 6;
--Testcase 4153:
DROP FOREIGN TABLE s81_mysql_svr;
--Testcase 4154:
DROP USER MAPPING FOR CURRENT_USER SERVER mysql_svr;
--Testcase 4155:
DROP SERVER mysql_svr;
--Testcase 4156:
DROP EXTENSION mysql_fdw;

-- json_storage_size()
-- select json_storage_size (builtin function, explain)
--Testcase 4157:
EXPLAIN VERBOSE
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_storage_size (builtin function, result)
--Testcase 4158:
SELECT * FROM (
SELECT id, json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8
) AS t ORDER BY 1;

-- select json_storage_size (builtin function, not pushdown constraints, explain)
--Testcase 4159:
EXPLAIN VERBOSE
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE to_hex(id) = '2';

-- select json_storage_size (builtin function, not pushdown constraints, result)
--Testcase 4160:
SELECT * FROM (
SELECT id, json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_storage_size (builtin function, pushdown constraints, explain)
--Testcase 4161:
EXPLAIN VERBOSE
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE id != 0;

-- select json_storage_size (builtin function, pushdown constraints, result)
--Testcase 4162:
SELECT * FROM (
SELECT id, json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_storage_size (builtin function, json_storage_size in constraints, explain)
--Testcase 4163:
EXPLAIN VERBOSE
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_storage_size(c1) != 1;

-- select json_storage_size (builtin function, json_storage_size in constraints, result)
--Testcase 4164:
SELECT * FROM (
SELECT id, json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_storage_size(c1) != 1
) AS t ORDER BY 1;

-- select json_storage_size (builtin function, json_storage_size in constraints, explain)
--Testcase 4165:
EXPLAIN VERBOSE
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_storage_size('{"a": 1, "b": {"c": 30}}') = 33;

-- select json_storage_size (builtin function, json_storage_size in constraints, result)
--Testcase 4166:
SELECT * FROM (
SELECT id, json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_storage_size('{"a": 1, "b": {"c": 30}}') = 33
) AS t ORDER BY 1;

-- select json_storage_size as nest function with agg (not pushdown, explain)
--Testcase 4167:
EXPLAIN VERBOSE
SELECT sum(id),json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_storage_size as nest function with agg (not pushdown, result, error)
--Testcase 4168:
SELECT sum(id),json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_storage_size with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4169:
EXPLAIN VERBOSE
SELECT json_storage_size(json_build_array(c1, 'a', c2)), pi(), 4.1 FROM s8;

-- select json_storage_size with non pushdown func and explicit constant (result)
--Testcase 4170:
SELECT * FROM (
SELECT id, json_storage_size(json_build_array(c1, 'a', c2)), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_storage_size with order by (EXPLAIN)
--Testcase 4171:
EXPLAIN VERBOSE
SELECT id, json_storage_size(c1) FROM s8 ORDER BY json_storage_size(c1);

-- select json_storage_size with order by (result)
--Testcase 4172:
SELECT id, json_storage_size(c1) FROM s8 ORDER BY json_storage_size(c1);

-- select json_storage_size with order by index (result)
--Testcase 4173:
SELECT id, json_storage_size(c1) FROM s8 ORDER BY 2, 1;

-- select json_storage_size with order by index (result)
--Testcase 4174:
SELECT id, json_storage_size(c1) FROM s8 ORDER BY 1, 2;

-- select json_storage_size with group by (EXPLAIN)
--Testcase 4175:
EXPLAIN VERBOSE
SELECT count(id), json_storage_size(c1) FROM s8 group by json_storage_size(c1);

-- select json_storage_size with group by (result)
--Testcase 4176:
SELECT * FROM (
SELECT count(id), json_storage_size(c1) FROM s8 group by json_storage_size(c1)
) AS t ORDER BY 1;

-- select json_storage_size with group by index (result)
--Testcase 4177:
SELECT * FROM (
SELECT id, json_storage_size(c1) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_storage_size with group by index (result)
--Testcase 4178:
SELECT * FROM (
SELECT id, json_storage_size(c1) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_storage_size with group by having (EXPLAIN)
--Testcase 4179:
EXPLAIN VERBOSE
SELECT count(c2), json_storage_size(c1) FROM s8 group by json_storage_size(c1) HAVING count(c2) > 0;

-- select json_storage_size with group by having (result)
--Testcase 4180:
SELECT * FROM (
SELECT count(c2), json_storage_size(c1) FROM s8 group by json_storage_size(c1) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_storage_size with group by index having (result)
--Testcase 4181:
SELECT * FROM (
SELECT c2, json_storage_size(c1) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_storage_size with group by index having (result)
--Testcase 4182:
SELECT * FROM (
SELECT c2, json_storage_size(c1) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_storage_size and as
--Testcase 4183:
SELECT * FROM (
SELECT id, json_storage_size(json_build_array(c1, 'a', c2)) as json_storage_size1 FROM s8
) AS t ORDER BY 1;

-- mysql_json_table
-- select mysql_json_table (explain)
--Testcase 4184:
EXPLAIN VERBOSE
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', '_type text PATH "$.type"', '_schema text PATH "$.$schema"', '_required json PATH "$.required"', '_properties json PATH "$.properties"', '_description text PATH "$.description"'],
       ARRAY['id', '_type', '_schema', '_required', '_properties', '_description'])
       FROM s9;

-- select mysql_json_table (result)
--Testcase 4185:
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', '_type text PATH "$.type"', '_schema text PATH "$.$schema"', '_required json PATH "$.required"', '_properties json PATH "$.properties"', '_description text PATH "$.description"'],
       ARRAY['id', '_type', '_schema', '_required', '_properties', '_description'])
       FROM s9 ORDER BY 1;

--Testcase 4186:
CREATE TABLE loc_tbl (
  id text,
  _type text,
  _schema text,
  _required json,
  _properties json,
  _description text
);
-- select mysql_json_table (result, access record)
--Testcase 4187:
SELECT * FROM (
  SELECT (mysql_json_table(c1,'$',
          ARRAY['id VARCHAR(100) PATH "$.id"', '_type text PATH "$.type"', '_schema text PATH "$.$schema"', '_required json PATH "$.required"', '_properties json PATH "$.properties"', '_description text PATH "$.description"'],
          ARRAY['id', '_type', '_schema', '_required', '_properties', '_description'])::loc_tbl).*
          FROM s9
) t ORDER BY _required::text;

--Testcase 4188:
DROP TABLE loc_tbl;

-- select mysql_json_table (pushed down constraints, explain)
--Testcase 4189:
EXPLAIN VERBOSE
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', '_type text PATH "$.type"', '_schema text PATH "$.$schema"', '_required json PATH "$.required"', '_properties json PATH "$.properties"', '_description text PATH "$.description"'],
       ARRAY['id', '_type', '_schema', '_required', '_properties', '_description'])
       FROM s9 WHERE json_depth(c1) > 1;

-- select mysql_json_table (pushed down constraints, result)
--Testcase 4190:
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', '_type text PATH "$.type"', '_schema text PATH "$.$schema"', '_required json PATH "$.required"', '_properties json PATH "$.properties"', '_description text PATH "$.description"'],
       ARRAY['id', '_type', '_schema', '_required', '_properties', '_description'])
       FROM s9 WHERE json_depth(c1) > 1 ORDER BY 1;

--Testcase 4191:
CREATE TABLE loc_tbl (
  id text,
  _type text,
  _schema text,
  _required json,
  _properties json,
  _description text
);
-- select mysql_json_table (pushed down constraints, result, access record)
--Testcase 4192:
SELECT id, _type FROM (
  SELECT (mysql_json_table(c1,'$',
          ARRAY['id VARCHAR(100) PATH "$.id"', '_type text PATH "$.type"', '_schema text PATH "$.$schema"', '_required json PATH "$.required"', '_properties json PATH "$.properties"', '_description text PATH "$.description"'],
          ARRAY['id', '_type', '_schema', '_required', '_properties', '_description'])::loc_tbl).*
          FROM s9 WHERE json_depth(c1) > 1
) t;

--Testcase 4193:
DROP TABLE loc_tbl;

-- mysql_json_table with nested path (explain)
--Testcase 4194:
EXPLAIN VERBOSE
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', 'NESTED PATH "$.properties.*" COLUMNS(maximum int PATH "$.maximum", minimum int PATH "$.minimum")'],
       ARRAY['id', 'maximum', 'minimum']), c1
       FROM s9;

-- mysql_json_table with nested path (value)
--Testcase 4195:
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', 'NESTED PATH "$.properties.*" COLUMNS(maximum int PATH "$.maximum", minimum int PATH "$.minimum")'],
       ARRAY['id', 'maximum', 'minimum']), c1
       FROM s9 ORDER BY 1;

--Testcase 4196:
CREATE TABLE loc_tbl (
  id text,
  maximum int,
  minimum int
);

-- mysql_json_table with nested path (value, access record)
--Testcase 4197:
SELECT (t1::loc_tbl).*, c1 FROM (
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', 'NESTED PATH "$.properties.*" COLUMNS(maximum int PATH "$.maximum", minimum int PATH "$.minimum")'],
       ARRAY['id', 'maximum', 'minimum']) AS t1, c1
       FROM s9
) t ORDER BY 1, 2;
--Testcase 4198:
DROP TABLE loc_tbl;

-- select mysql_json_table constant argument (explain)
--Testcase 4199:
EXPLAIN VERBOSE
SELECT id, mysql_json_table('[{"x":2,"y":"8"},{"x":"3","y":"7"},{"x":"4","y":6}]','$[*]',
       ARRAY['xval VARCHAR(100) PATH "$.x"', ' yval VARCHAR(100) PATH "$.y"'],
       ARRAY['xval', 'yval'])
       FROM s9 WHERE id = 0;

-- select mysql_json_table constant argument (result)
--Testcase 4200:
SELECT id, mysql_json_table('[{"x":2,"y":"8"},{"x":"3","y":"7"},{"x":"4","y":6}]','$[*]',
       ARRAY['xval VARCHAR(100) PATH "$.x"', ' yval VARCHAR(100) PATH "$.y"'],
       ARRAY['xval', 'yval'])
       FROM s9 WHERE id = 0;

--Testcase 4201:
CREATE TABLE loc_tbl (
  xval int,
  yval int
);
-- select mysql_json_table constant argument (result)
--Testcase 4202:
SELECT (t1::loc_tbl).*, id FROM (
SELECT id, mysql_json_table('[{"x":2,"y":"8"},{"x":"3","y":"7"},{"x":"4","y":6}]','$[*]',
       ARRAY['xval VARCHAR(100) PATH "$.x"', ' yval VARCHAR(100) PATH "$.y"'],
       ARRAY['xval', 'yval']) AS t1, c1
       FROM s9 WHERE id = 0
) t;

--Testcase 4203:
DROP TABLE loc_tbl;

-- JSON_TYPE()
-- select json_type (builtin function, explain)
--Testcase 4204:
EXPLAIN VERBOSE
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8;

-- select json_type (builtin function, result)
--Testcase 4205:
SELECT * FROM (
SELECT id, json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8
) AS t ORDER BY 1;

-- select json_type (builtin function, not pushdown constraints, explain)
--Testcase 4206:
EXPLAIN VERBOSE
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 WHERE to_hex(id) = '2';

-- select json_type (builtin function, not pushdown constraints, result)
--Testcase 4207:
SELECT * FROM (
SELECT id, json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_type (builtin function, pushdown constraints, explain)
--Testcase 4208:
EXPLAIN VERBOSE
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 WHERE id != 0;

-- select json_type (builtin function, pushdown constraints, result)
--Testcase 4209:
SELECT * FROM (
SELECT id, json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_type (builtin function, json_type in constraints, explain)
--Testcase 4210:
EXPLAIN VERBOSE
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 WHERE json_type(c1) NOT LIKE '$';

-- select json_type (builtin function, json_type in constraints, result)
--Testcase 4211:
SELECT * FROM (
SELECT id, json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 WHERE json_type(c1) NOT LIKE '$'
) AS t ORDER BY 1;

-- select json_type (builtin function, json_type in constraints, explain)
--Testcase 4212:
EXPLAIN VERBOSE
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 where json_type('[1,3,5,7]') LIKE 'ARRAY';

-- select json_type (builtin function, json_type in constraints, result)
--Testcase 4213:
SELECT * FROM (
SELECT id, json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 where json_type('[1,3,5,7]') LIKE 'ARRAY'
) AS t ORDER BY 1;

-- select json_type as nest function with agg (not pushdown, explain)
--Testcase 4214:
EXPLAIN VERBOSE
SELECT sum(id),json_type(json_build_object('a', '1', 'b',sum(id))) FROM s8;

-- select json_type as nest function with agg (not pushdown, result, error)
--Testcase 4215:
SELECT sum(id),json_type(json_build_object('a', '1', 'b',sum(id))) FROM s8;

-- select json_type with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4216:
EXPLAIN VERBOSE
SELECT json_type(json_build_object('a', '1', 'b', c2)), pi(), 4.1 FROM s8;

-- select json_type with non pushdown func and explicit constant (result)
--Testcase 4217:
SELECT * FROM (
SELECT id, json_type(json_build_object('a', '1', 'b', c2)), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_type with order by index (result)
--Testcase 4218:
SELECT id, json_type(c1) FROM s8 ORDER BY 2, 1;

-- select json_type with order by index (result)
--Testcase 4219:
SELECT id, json_type(c1) FROM s8 ORDER BY 1, 2;

-- select json_type with group by (EXPLAIN)
--Testcase 4220:
EXPLAIN VERBOSE
SELECT count(id), json_type(c1) FROM s8 group by json_type(c1);

-- select json_type with group by (result)
--Testcase 4221:
SELECT * FROM (
SELECT count(id), json_type(c1) FROM s8 group by json_type(c1)
) AS t ORDER BY 1;

-- select json_type with group by index (result)
--Testcase 4222:
SELECT * FROM (
SELECT id, json_type(c1) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_type with group by index (result)
--Testcase 4223:
SELECT * FROM (
SELECT id, json_type(c1) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_type with group by having (EXPLAIN)
--Testcase 4224:
EXPLAIN VERBOSE
SELECT count(c2), json_type(c1) FROM s8 group by json_type(c1) HAVING count(c2) > 0;

-- select json_type with group by having (result)
--Testcase 4225:
SELECT * FROM (
SELECT count(c2), json_type(c1) FROM s8 group by json_type(c1) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_type with group by index having (result)
--Testcase 4226:
SELECT * FROM (
SELECT c2, json_type(c1) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_type with group by index having (result)
--Testcase 4227:
SELECT * FROM (
SELECT c2, json_type(c1) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_type and as
--Testcase 4228:
SELECT * FROM (
SELECT id, json_type(json_build_object('a', '1', 'b', c2)) as json_type1 FROM s8
) AS t ORDER BY 1;

-- select json_unquote (builtin function, explain)
--Testcase 4229:
EXPLAIN VERBOSE
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8;

-- select json_unquote (builtin function, result)
--Testcase 4230:
SELECT * FROM (
SELECT id, json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8
) AS t ORDER BY 1;

-- select json_unquote (builtin function, not pushdown constraints, explain)
--Testcase 4231:
EXPLAIN VERBOSE
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE to_hex(id) = '2';

-- select json_unquote (builtin function, not pushdown constraints, result)
--Testcase 4232:
SELECT * FROM (
SELECT id, json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_unquote (builtin function, pushdown constraints, explain)
--Testcase 4233:
EXPLAIN VERBOSE
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE id != 0;

-- select json_unquote (builtin function, pushdown constraints, result)
--Testcase 4234:
SELECT * FROM (
SELECT id, json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_unquote (builtin function, json_unquote in constraints, explain)
--Testcase 4235:
EXPLAIN VERBOSE
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE json_unquote(c3) NOT LIKE 'text';

-- select json_unquote (builtin function, json_unquote in constraints, result)
--Testcase 4236:
SELECT * FROM (
SELECT id, json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE json_unquote(c3) NOT LIKE 'text'
) AS t ORDER BY 1;

-- select json_unquote (builtin function, json_unquote in constraints, explain)
--Testcase 4237:
EXPLAIN VERBOSE
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE json_unquote('[1, 2, 3]') LIKE '[1, 2, 3]';

-- select json_unquote (builtin function, json_unquote in constraints, result)
--Testcase 4238:
SELECT * FROM (
SELECT id, json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE json_unquote('[1, 2, 3]') LIKE '[1, 2, 3]'
) AS t ORDER BY 1;

-- select json_unquote as nest function with agg (not pushdown, explain)
--Testcase 4239:
EXPLAIN VERBOSE
SELECT sum(id), json_unquote('[1, 2, 3]') FROM s8;

-- select json_unquote as nest function with agg (not pushdown, result, error)
--Testcase 4240:
SELECT sum(id), json_unquote('[1, 2, 3]') FROM s8;

-- select json_unquote with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4241:
EXPLAIN VERBOSE
SELECT json_unquote('null'), pi(), 4.1 FROM s8;

-- select json_unquote with non pushdown func and explicit constant (result)
--Testcase 4242:
SELECT * FROM (
SELECT id, json_unquote('null'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_unquote with order by (EXPLAIN)
--Testcase 4243:
EXPLAIN VERBOSE
SELECT id,  json_unquote(c3) FROM s8 ORDER BY json_unquote(c3);

-- select json_unquote with order by (result)
--Testcase 4244:
SELECT id,  json_unquote(c3) FROM s8 ORDER BY json_unquote(c3);

-- select json_unquote with order by index (result)
--Testcase 4245:
SELECT id,  json_unquote(c3) FROM s8 ORDER BY 2, 1;

-- select json_unquote with order by index (result)
--Testcase 4246:
SELECT id,  json_unquote(c3) FROM s8 ORDER BY 1, 2;

-- select json_unquote with group by (EXPLAIN)
--Testcase 4247:
EXPLAIN VERBOSE
SELECT count(id), json_unquote(c3) FROM s8 group by json_unquote(c3);

-- select json_unquote with group by (result)
--Testcase 4248:
SELECT * FROM (
SELECT count(id), json_unquote(c3) FROM s8 group by json_unquote(c3)
) AS t ORDER BY 1;

-- select json_unquote with group by index (result)
--Testcase 4249:
SELECT * FROM (
SELECT id,  json_unquote(c3) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_unquote with group by index (result)
--Testcase 4250:
SELECT * FROM (
SELECT id,  json_unquote(c3) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_unquote with group by having (EXPLAIN)
--Testcase 4251:
EXPLAIN VERBOSE
SELECT count(c2), json_unquote(c3) FROM s8 group by json_unquote(c3) HAVING count(c2) > 0;

-- select json_unquote with group by having (result)
--Testcase 4252:
SELECT * FROM (
SELECT count(c2), json_unquote(c3) FROM s8 group by json_unquote(c3) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_unquote with group by index having (result)
--Testcase 4253:
SELECT * FROM (
SELECT c2,  json_unquote(c3) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_unquote with group by index having (result)
--Testcase 4254:
SELECT * FROM (
SELECT c2,  json_unquote(c3) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_unquote and as
--Testcase 4255:
SELECT * FROM (
SELECT id, json_unquote('null') as json_unquote1 FROM s8
) AS t ORDER BY 1;

-- select json_valid (builtin function, explain)
--Testcase 4256:
EXPLAIN VERBOSE
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_valid (builtin function, result)
--Testcase 4257:
SELECT * FROM (
SELECT id, json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8
) AS t ORDER BY 1;

-- select json_valid (builtin function, not pushdown constraints, explain)
--Testcase 4258:
EXPLAIN VERBOSE
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE to_hex(id) = '2';

-- select json_valid (builtin function, not pushdown constraints, result)
--Testcase 4259:
SELECT * FROM (
SELECT id, json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select json_valid (builtin function, pushdown constraints, explain)
--Testcase 4260:
EXPLAIN VERBOSE
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE id != 0;

-- select json_valid (builtin function, pushdown constraints, result)
--Testcase 4261:
SELECT * FROM (
SELECT id, json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select json_valid (builtin function, json_valid in constraints, explain)
--Testcase 4262:
EXPLAIN VERBOSE
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_valid(c1) != 0;

-- select json_valid (builtin function, json_valid in constraints, result)
--Testcase 4263:
SELECT * FROM (
SELECT id, json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_valid(c1) != 0
) AS t ORDER BY 1;

-- select json_valid (builtin function, json_valid in constraints, explain)
--Testcase 4264:
EXPLAIN VERBOSE
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_valid('{"a": 1, "b": {"c": 30}}') = 1;

-- select json_valid (builtin function, json_valid in constraints, result)
--Testcase 4265:
SELECT * FROM (
SELECT id, json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_valid('{"a": 1, "b": {"c": 30}}') = 1
) AS t ORDER BY 1;

-- select json_valid as nest function with agg (not pushdown, explain)
--Testcase 4266:
EXPLAIN VERBOSE
SELECT sum(id),json_valid('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_valid as nest function with agg (not pushdown, result, error)
--Testcase 4267:
SELECT sum(id),json_valid('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_valid with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4268:
EXPLAIN VERBOSE
SELECT json_valid(json_build_array(c1, 'a', c2)), pi(), 4.1 FROM s8;

-- select json_valid with non pushdown func and explicit constant (result)
--Testcase 4269:
SELECT * FROM (
SELECT id, json_valid(json_build_array(c1, 'a', c2)), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select json_valid with order by index (result)
--Testcase 4270:
SELECT id, json_valid(c1) FROM s8 ORDER BY 2, 1;

-- select json_valid with order by index (result)
--Testcase 4271:
SELECT id, json_valid(c1) FROM s8 ORDER BY 1, 2;

-- select json_valid with group by (EXPLAIN)
--Testcase 4272:
EXPLAIN VERBOSE
SELECT count(id), json_valid(c1) FROM s8 group by json_valid(c1);

-- select json_valid with group by (result)
--Testcase 4273:
SELECT * FROM (
SELECT count(id), json_valid(c1) FROM s8 group by json_valid(c1)
) AS t ORDER BY 1;

-- select json_valid with group by index (result)
--Testcase 4274:
SELECT * FROM (
SELECT id, json_valid(c1) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select json_valid with group by index (result)
--Testcase 4275:
SELECT * FROM (
SELECT id, json_valid(c1) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select json_valid with group by having (EXPLAIN)
--Testcase 4276:
EXPLAIN VERBOSE
SELECT count(c2), json_valid(c1) FROM s8 group by json_valid(c1) HAVING count(c2) > 0;

-- select json_valid with group by having (result)
--Testcase 4277:
SELECT * FROM (
SELECT count(c2), json_valid(c1) FROM s8 group by json_valid(c1) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_valid with group by index having (result)
--Testcase 4278:
SELECT * FROM (
SELECT c2, json_valid(c1) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_valid with group by index having (result)
--Testcase 4279:
SELECT * FROM (
SELECT c2, json_valid(c1) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select json_valid and as
--Testcase 4280:
SELECT * FROM (
SELECT id, json_valid(json_build_array(c1, 'a', c2)) as json_valid1 FROM s8
) AS t ORDER BY 1;

-- select mysql_json_value (stub function, explain)
--Testcase 4281:
EXPLAIN VERBOSE
SELECT mysql_json_value(c1, '$.a'), mysql_json_value(c1, '$[1]'), mysql_json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8;

-- select mysql_json_value (stub function, result)
--Testcase 4282:
SELECT * FROM (
SELECT id, mysql_json_value(c1, '$.a'), mysql_json_value(c1, '$[1]'), mysql_json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8
) AS t ORDER BY 1;

-- select mysql_json_value (stub function, not pushdown constraints, explain)
--Testcase 4283:
EXPLAIN VERBOSE
SELECT mysql_json_value(c1, '$.a'), mysql_json_value(c1, '$[1]'), mysql_json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE to_hex(id) = '2';

-- select mysql_json_value (stub function, not pushdown constraints, result)
--Testcase 4284:
SELECT * FROM (
SELECT id, mysql_json_value(c1, '$.a'), mysql_json_value(c1, '$[1]'), mysql_json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select mysql_json_value (stub function, pushdown constraints, explain)
--Testcase 4285:
EXPLAIN VERBOSE
SELECT mysql_json_value(c1, '$.a'), mysql_json_value(c1, '$[1]'), mysql_json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE id != 0;

-- select mysql_json_value (stub function, pushdown constraints, result)
--Testcase 4286:
SELECT * FROM (
SELECT id, mysql_json_value(c1, '$.a'), mysql_json_value(c1, '$[1]'), mysql_json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select mysql_json_value (stub function, mysql_json_value in constraints, explain)
--Testcase 4287:
EXPLAIN VERBOSE
SELECT mysql_json_value(c1, '$.a'), mysql_json_value(c1, '$[1]'), mysql_json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE mysql_json_value(c1, '$.a', 'default 0 on empty')::int > 1;

-- select mysql_json_value (stub function, mysql_json_value in constraints, result)
--Testcase 4288:
SELECT * FROM (
SELECT id, mysql_json_value(c1, '$.a'), mysql_json_value(c1, '$[1]'), mysql_json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE mysql_json_value(c1, '$.a', 'default 0 on empty')::int > 1
) AS t ORDER BY 1;

-- select mysql_json_value (stub function, mysql_json_value in constraints, explain)
--Testcase 4289:
EXPLAIN VERBOSE
SELECT mysql_json_value(c1, '$.a'), mysql_json_value(c1, '$[1]'), mysql_json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE mysql_json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 2)')::decimal = 49.95;

-- select mysql_json_value (stub function, mysql_json_value in constraints, result)
--Testcase 4290:
SELECT * FROM (
SELECT id, mysql_json_value(c1, '$.a'), mysql_json_value(c1, '$[1]'), mysql_json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE mysql_json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 2)')::decimal = 49.95
) AS t ORDER BY 1;

-- select mysql_json_value (stub function, abnormal cast, explain)
--Testcase 4291:
EXPLAIN VERBOSE
SELECT mysql_json_value(c1, '$.a')::date FROM s8;

-- select mysql_json_value (stub function, abnormal cast, result)
--SELECT mysql_json_value(c1, '$.a')::date FROM s8; -- should fail

-- select mysql_json_value (stub function, abnormal cast, explain)
--Testcase 4292:
EXPLAIN VERBOSE
SELECT mysql_json_value(c1, '$.a', 'returning date')::date FROM s8;

-- select mysql_json_value (stub function, abnormal cast, result)
--Testcase 4293:
SELECT mysql_json_value(c1, '$.a', 'returning date')::date FROM s8; --empty result

-- select mysql_json_value (stub function, abnormal cast, explain)
--Testcase 4294:
EXPLAIN VERBOSE
SELECT mysql_json_value(c1, '$.a', 'returning date', 'error on error')::date FROM s8;

-- select mysql_json_value (stub function, abnormal cast, result)
--SELECT mysql_json_value(c1, '$.a', 'returning date', 'error on error')::date FROM s8; -- should fail

-- select mysql_json_value with normal cast
--Testcase 4295:
SELECT mysql_json_value('{"a": "2000-01-01"}', '$.a')::timestamp, mysql_json_value('{"a": "2000-01-01"}', '$.a')::date , mysql_json_value('{"a": 1234}', '$.a')::bigint, mysql_json_value('{"a": "b"}', '$.a')::text FROM s8;

-- select mysql_json_value with normal cast
--Testcase 4296:
SELECT mysql_json_value('{"a": "2000-01-01"}', '$.a')::timestamptz, mysql_json_value('{"a": "12:10:20.123456"}', '$.a')::time , mysql_json_value('{"a": "12:10:20.123456"}', '$.a')::timetz FROM s8;

-- select mysql_json_value with type modifier (explain)
--Testcase 4297:
EXPLAIN VERBOSE
SELECT mysql_json_value('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamp(3), mysql_json_value('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamptz(3), mysql_json_value('{"a": "12:10:20.123456"}', '$.a')::time(3), mysql_json_value('{"a": "12:10:20.123456"}', '$.a')::timetz(3) FROM s8;

-- select mysql_json_value with type modifier (result)
--Testcase 4298:
SELECT mysql_json_value('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamp(3), mysql_json_value('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamptz(3), mysql_json_value('{"a": "12:10:20.123456"}', '$.a')::time(3), mysql_json_value('{"a": "12:10:20.123456"}', '$.a')::timetz(3) FROM s8;

-- select mysql_json_value with type modifier (explain)
--Testcase 4299:
EXPLAIN VERBOSE
SELECT mysql_json_value('{"a": 100}', '$.a')::numeric(10, 2), mysql_json_value('{"a": 100}', '$.a')::decimal(10, 2), json_unquote(mysql_json_value('{"a": "1.123456"}', '$.a'))::numeric(10, 3) FROM s8;

-- select mysql_json_value with type modifier (result)
--Testcase 4300:
SELECT mysql_json_value('{"a": 100}', '$.a')::numeric(10, 2), mysql_json_value('{"a": 100}', '$.a')::decimal(10, 2), json_unquote(mysql_json_value('{"a": "1.123456"}', '$.a'))::numeric(10, 3) FROM s8;

-- select mysql_json_value as nest function with agg (not pushdown, explain)
--Testcase 4301:
EXPLAIN VERBOSE
SELECT sum(id), mysql_json_value(json_build_object('item', 'shoe', 'price', sum(id)), '$.price')::int FROM s8;

-- select mysql_json_value as nest function with agg (not pushdown, result, error)
--Testcase 4302:
SELECT sum(id), mysql_json_value(json_build_object('item', 'shoe', 'price', sum(id)), '$.price')::int FROM s8;

-- select mysql_json_value with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4303:
EXPLAIN VERBOSE
SELECT mysql_json_value(c1, '$[1]'), pi(), 4.1 FROM s8;

-- select mysql_json_value with non pushdown func and explicit constant (result)
--Testcase 4304:
SELECT * FROM (
SELECT id, mysql_json_value(c1, '$[1]'), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select mysql_json_value with order by index (result)
--Testcase 4305:
SELECT id, mysql_json_value(c1, '$.a') FROM s8 ORDER BY 2, 1;

-- select mysql_json_value with order by index (result)
--Testcase 4306:
SELECT id, mysql_json_value(c1, '$.a') FROM s8 ORDER BY 1, 2;

-- select mysql_json_value with group by (EXPLAIN)
--Testcase 4307:
EXPLAIN VERBOSE
SELECT count(id), mysql_json_value(c1, '$.a') FROM s8 group by mysql_json_value(c1, '$.a');

-- select mysql_json_value with group by (result)
--Testcase 4308:
SELECT * FROM (
SELECT count(id), mysql_json_value(c1, '$.a') FROM s8 group by mysql_json_value(c1, '$.a')
) AS t ORDER BY 1;

-- select mysql_json_value with group by index (result)
--Testcase 4309:
SELECT * FROM (
SELECT id, mysql_json_value(c1, '$.a') FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select mysql_json_value with group by index (result)
--Testcase 4310:
SELECT * FROM (
SELECT id, mysql_json_value(c1, '$.a') FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select mysql_json_value with group by having (EXPLAIN)
--Testcase 4311:
EXPLAIN VERBOSE
SELECT count(c2), mysql_json_value(c1, '$.a') FROM s8 group by mysql_json_value(c1, '$.a') HAVING count(c2) > 0;

-- select mysql_json_value with group by having (result)
--Testcase 4312:
SELECT * FROM (
SELECT count(c2), mysql_json_value(c1, '$.a') FROM s8 group by mysql_json_value(c1, '$.a') HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select mysql_json_value with group by index having (result)
--Testcase 4313:
SELECT * FROM (
SELECT c2, mysql_json_value(c1, '$.a') FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select mysql_json_value with group by index having (result)
--Testcase 4314:
SELECT * FROM (
SELECT c2, mysql_json_value(c1, '$.a') FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select mysql_json_value and as
--Testcase 4315:
SELECT * FROM (
SELECT id, mysql_json_value(c1, '$[1]') as mysql_json_value1 FROM s8
) AS t ORDER BY 1;

-- select member_of (builtin function, explain)
--Testcase 4316:
EXPLAIN VERBOSE
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8;

-- select member_of (builtin function, result)
--Testcase 4317:
SELECT * FROM (
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8
) AS t ORDER BY 1;

-- select member_of (builtin function, not pushdown constraints, explain)
--Testcase 4318:
EXPLAIN VERBOSE
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE to_hex(id) = '2';

-- select member_of (builtin function, not pushdown constraints, result)
--Testcase 4319:
SELECT * FROM (
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE to_hex(id) = '2'
) AS t ORDER BY 1;

-- select member_of (builtin function, pushdown constraints, explain)
--Testcase 4320:
EXPLAIN VERBOSE
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE id != 0;

-- select member_of (builtin function, pushdown constraints, result)
--Testcase 4321:
SELECT * FROM (
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE id != 0
) AS t ORDER BY 1;

-- select member_of (builtin function, member_of in constraints, explain)
--Testcase 4322:
EXPLAIN VERBOSE
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE member_of(5, c1) != 0;

-- select member_of (builtin function, member_of in constraints, result)
--Testcase 4323:
SELECT * FROM (
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE member_of(5, c1) != 0
) AS t ORDER BY 1;

-- select member_of (builtin function, member_of in constraints, explain)
--Testcase 4324:
EXPLAIN VERBOSE
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE member_of(json_build_object('item', 'shoes', 'price', '49.95'), '{"item": "shoes", "price": "49.95"}') = 1;

-- select member_of (builtin function, member_of in constraints, result)
--Testcase 4325:
SELECT * FROM (
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE member_of(json_build_object('item', 'shoes', 'price', '49.95'), '{"item": "shoes", "price": "49.95"}') = 1
) AS t ORDER BY 1;

-- select member_of as nest function with agg (not pushdown, explain)
--Testcase 4326:
EXPLAIN VERBOSE
SELECT sum(id), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8;

-- select member_of as nest function with agg (not pushdown, result, error)
--Testcase 4327:
SELECT sum(id), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8;

-- select member_of with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4328:
EXPLAIN VERBOSE
SELECT member_of('ab'::text, c1), member_of('[3,4]'::json, c1), pi(), 4.1 FROM s8;

-- select member_of with non pushdown func and explicit constant (result)
--Testcase 4329:
SELECT * FROM (
SELECT id, member_of('ab'::text, c1), member_of('[3,4]'::json, c1), pi(), 4.1 FROM s8
) AS t ORDER BY 1;

-- select member_of with order by index (result)
--Testcase 4330:
SELECT id, member_of(5, c1) FROM s8 ORDER BY 2, 1;

-- select member_of with order by index (result)
--Testcase 4331:
SELECT id, member_of(5, c1) FROM s8 ORDER BY 1, 2;

-- select member_of with group by (EXPLAIN)
--Testcase 4332:
EXPLAIN VERBOSE
SELECT count(id), member_of(5, c1) FROM s8 group by member_of(5, c1);

-- select member_of with group by (result)
--Testcase 4333:
SELECT * FROM (
SELECT count(id), member_of(5, c1) FROM s8 group by member_of(5, c1)
) AS t ORDER BY 1;

-- select member_of with group by index (result)
--Testcase 4334:
SELECT * FROM (
SELECT id, member_of(5, c1) FROM s8 group by 2, 1
) AS t ORDER BY 1;

-- select member_of with group by index (result)
--Testcase 4335:
SELECT * FROM (
SELECT id, member_of(5, c1) FROM s8 group by 1, 2
) AS t ORDER BY 1;

-- select member_of with group by having (EXPLAIN)
--Testcase 4336:
EXPLAIN VERBOSE
SELECT count(c2), member_of(5, c1) FROM s8 group by member_of(5, c1) HAVING count(c2) > 0;

-- select member_of with group by having (result)
--Testcase 4337:
SELECT * FROM (
SELECT count(c2), member_of(5, c1) FROM s8 group by member_of(5, c1) HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select member_of with group by index having (result)
--Testcase 4338:
SELECT * FROM (
SELECT c2, member_of(5, c1) FROM s8 group by 2, 1 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select member_of with group by index having (result)
--Testcase 4339:
SELECT * FROM (
SELECT c2, member_of(5, c1) FROM s8 group by 1, 2 HAVING count(c2) > 0
) AS t ORDER BY 1;

-- select member_of and as
--Testcase 4340:
SELECT * FROM (
SELECT member_of('ab'::text, c1), member_of('[3,4]'::json, c1) as member_of1 FROM s8
) AS t ORDER BY 1, 2;

--Drop all foreign tables
--Testcase 4341:
DROP FOREIGN TABLE ftextsearch__pgspider_svr1__0;
--Testcase 4342:
DROP FOREIGN TABLE s3__pgspider_svr1__0;
--Testcase 4343:
DROP FOREIGN TABLE time_tbl__pgspider_svr1__0;
--Testcase 4344:
DROP FOREIGN TABLE s7a__pgspider_svr1__0;
--Testcase 4345:
DROP FOREIGN TABLE s8__pgspider_svr1__0;
--Testcase 4346:
DROP FOREIGN TABLE s9__pgspider_svr1__0;
--Testcase 4347:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_svr1;
--Testcase 4348:
DROP SERVER pgspider_svr1;

--Testcase 4349:
DROP FOREIGN TABLE ftextsearch__pgspider_svr2__0;
--Testcase 4350:
DROP FOREIGN TABLE s3__pgspider_svr2__0;
--Testcase 4351:
DROP FOREIGN TABLE time_tbl__pgspider_svr2__0;
--Testcase 4352:
DROP FOREIGN TABLE s8__pgspider_svr2__0;
--Testcase 4353:
DROP FOREIGN TABLE s9__pgspider_svr2__0;
--Testcase 4354:
DROP FOREIGN TABLE s7a__pgspider_svr2__0;
--Testcase 4355:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_svr2;
--Testcase 4356:
DROP SERVER pgspider_svr2;

--Testcase 4357:
DROP EXTENSION pgspider_fdw;

--Testcase 4358:
DROP FOREIGN TABLE ftextsearch;
--Testcase 4359:
DROP FOREIGN TABLE s3;
--Testcase 4360:
DROP FOREIGN TABLE time_tbl;
--Testcase 4361:
DROP FOREIGN TABLE s8;
--Testcase 4362:
DROP FOREIGN TABLE s9;
--Testcase 4363:
DROP FOREIGN TABLE s7a;

--Testcase 4364:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_core_svr;
--Testcase 4365:
DROP SERVER pgspider_core_svr;
--Testcase 4366:
DROP EXTENSION pgspider_core_fdw;
