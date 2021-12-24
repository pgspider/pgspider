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
-- Data source: influxdb

--Testcase 6:
CREATE FOREIGN TABLE s3 (time timestamp with time zone, tag1 text, value1 float8, value2 bigint, value3 float8, value4 bigint, __spd_url text) SERVER pgspider_core_svr;

--Testcase 7:
CREATE EXTENSION pgspider_fdw;
--Testcase 8:
CREATE SERVER pgspider_svr FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (host '127.0.0.1', port '5433', dbname 'postgres');
--Testcase 9:
CREATE USER MAPPING FOR CURRENT_USER SERVER pgspider_svr;
--Testcase 10:
CREATE FOREIGN TABLE s3__pgspider_svr__0 (time timestamp with time zone, tag1 text, value1 float8, value2 bigint, value3 float8, value4 bigint, __spd_url text) SERVER pgspider_svr OPTIONS (table_name 's31influx');

--Testcase 11:
CREATE EXTENSION influxdb_fdw;
--Testcase 12:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'selectfunc_db', host 'http://localhost', port '8086');
--Testcase 13:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user 'user', password 'pass');
--Testcase 14:
CREATE FOREIGN TABLE s3__influxdb_svr__0 (time timestamp with time zone, tag1 text, value1 float8, value2 bigint, value3 float8, value4 bigint) SERVER influxdb_svr OPTIONS (table 's32', tags 'tag1');

-- s3 (value1,3 as float8, value2,4 as bigint)
--Testcase 15:
\d s3;
--Testcase 16:
SELECT * FROM s3 ORDER BY 1,2,3,4,5,6,7;

-- select float8() (not pushdown, remove float8, explain)
--Testcase 17:
EXPLAIN VERBOSE
SELECT float8(value1), float8(value2), float8(value3), float8(value4) FROM s3 ORDER BY 1;

-- select float8() (not pushdown, remove float8, result)
--Testcase 18:
SELECT * FROM (
SELECT float8(value1), float8(value2), float8(value3), float8(value4) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select sqrt (builtin function, explain)
--Testcase 19:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2) FROM s3 ORDER BY 1;

-- select sqrt (buitin function, result)
--Testcase 20:
SELECT * FROM (
SELECT sqrt(value1), sqrt(value2) FROM s3
) AS t ORDER BY 1,2;

-- select sqrt (builtin function, not pushdown constraints, explain)
--Testcase 21:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select sqrt (builtin function, not pushdown constraints, result)
--Testcase 22:
SELECT * FROM (
SELECT sqrt(value1), sqrt(value2) FROM s3 WHERE to_hex(value2) != '64'
) AS t ORDER BY 1,2;

-- select sqrt (builtin function, pushdown constraints, explain)
--Testcase 23:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select sqrt (builtin function, pushdown constraints, result)
--Testcase 24:
SELECT * FROM (
SELECT sqrt(value1), sqrt(value2) FROM s3 WHERE value2 != 200
) AS t ORDER BY 1,2;

-- select sqrt(*) (stub function, explain)
--Testcase 25:
EXPLAIN VERBOSE
SELECT sqrt_all() from s3 ORDER BY 1;

-- select sqrt(*) (stub function, result)
--Testcase 26:
SELECT * FROM (
SELECT sqrt_all() from s3
) AS t ORDER BY 1;

-- select sqrt(*) (stub function and group by tag only) (explain)
--Testcase 27:
EXPLAIN VERBOSE
SELECT sqrt_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select sqrt(*) (stub function and group by tag only) (result)
--Testcase 28:
SELECT sqrt_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select abs (builtin function, explain)
--Testcase 29:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 ORDER BY 1;

-- ABS() returns negative values if integer (https://github.com/influxdata/influxdb/issues/10261)
-- select abs (buitin function, result)
--Testcase 30:
SELECT * FROM (
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select abs (builtin function, not pushdown constraints, explain)
--Testcase 31:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select abs (builtin function, not pushdown constraints, result)
--Testcase 32:
SELECT * FROM (
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64'
) AS t ORDER BY 1,2,3,4;

-- select abs (builtin function, pushdown constraints, explain)
--Testcase 33:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select abs (builtin function, pushdown constraints, result)
--Testcase 34:
SELECT * FROM (
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200
) AS t ORDER BY 1,2,3,4;

-- select log (builtin function, need to swap arguments, numeric cast, explain)
-- log_<base>(v) : postgresql (base, v), influxdb (v, base)
--Testcase 35:
EXPLAIN VERBOSE
SELECT log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1 ORDER BY 1;

-- select log (builtin function, need to swap arguments, numeric cast, result)
--Testcase 36:
SELECT * FROM (
SELECT log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1
) AS t ORDER BY 1;

-- select log (builtin function, need to swap arguments, float8, explain)
--Testcase 37:
EXPLAIN VERBOSE
SELECT log(value1::numeric, 0.1) FROM s3 WHERE value1 != 1 ORDER BY 1;

-- select log (builtin function, need to swap arguments, float8, result)
--Testcase 38:
SELECT * FROM (
SELECT log(value1::numeric, 0.1) FROM s3 WHERE value1 != 1
) AS t ORDER BY 1;

-- select log (builtin function, need to swap arguments, bigint, explain)
--Testcase 39:
EXPLAIN VERBOSE
SELECT log(value2::numeric, 3) FROM s3 WHERE value1 != 1 ORDER BY 1;

-- select log (builtin function, need to swap arguments, bigint, result)
--Testcase 40:
SELECT * FROM (
SELECT log(value2::numeric, 3) FROM s3 WHERE value1 != 1
) AS t ORDER BY 1;

-- select log (builtin function, need to swap arguments, mix type, explain)
--Testcase 41:
EXPLAIN VERBOSE
SELECT log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1 ORDER BY 1;

-- select log (builtin function, need to swap arguments, mix type, result)
--Testcase 42:
SELECT * FROM (
SELECT log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1
) AS t ORDER BY 1;

-- select log(*) (stub function, explain)
--Testcase 43:
EXPLAIN VERBOSE
SELECT log_all(50) FROM s3 ORDER BY 1;

-- select log(*) (stub function, result)
--Testcase 44:
SELECT * FROM (
SELECT log_all(50) FROM s3
) AS t ORDER BY 1;

-- select log(*) (stub function, explain)
--Testcase 45:
EXPLAIN VERBOSE
SELECT log_all(70.5) FROM s3 ORDER BY 1;

-- select log(*) (stub function, result)
--Testcase 46:
SELECT * FROM (
SELECT log_all(70.5) FROM s3
) AS t ORDER BY 1;

-- select log(*) (stub function and group by tag only) (explain)
--Testcase 47:
EXPLAIN VERBOSE
SELECT log_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select log(*) (stub function and group by tag only) (result)
--Testcase 48:
SELECT log_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 49:
SELECT ln_all(),log10_all(),log_all(50) FROM s3 ORDER BY 1;

-- select log2 (stub function, explain)
--Testcase 50:
EXPLAIN VERBOSE
SELECT log2(value1),log2(value2) FROM s3;

-- select log2 (stub function, result)
--Testcase 51:
SELECT * FROM (
SELECT log2(value1),log2(value2) FROM s3
) AS t ORDER BY 1,2;

-- select log2(*) (stub function, explain)
--Testcase 52:
EXPLAIN VERBOSE
SELECT log2_all() from s3 ORDER BY 1;

-- select log2(*) (stub function, result)
--Testcase 53:
SELECT * FROM (
SELECT log2_all() from s3
) AS t ORDER BY 1;

-- select log2(*) (stub function and group by tag only) (explain)
--Testcase 54:
EXPLAIN VERBOSE
SELECT log2_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select log2(*) (stub function and group by tag only) (result)
--Testcase 55:
SELECT log2_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select log10 (stub function, explain)
--Testcase 56:
EXPLAIN VERBOSE
SELECT log10(value1),log10(value2) FROM s3 ORDER BY 1;

-- select log10 (stub function, result)
--Testcase 57:
SELECT * FROM (
SELECT log10(value1),log10(value2) FROM s3
) AS t ORDER BY 1,2;

-- select log10(*) (stub function, explain)
--Testcase 58:
EXPLAIN VERBOSE
SELECT log10_all() from s3 ORDER BY 1;

-- select log10(*) (stub function, result)
--Testcase 59:
SELECT * FROM (
SELECT log10_all() from s3
) AS t ORDER BY 1;

-- select log10(*) (stub function and group by tag only) (explain)
--Testcase 60:
EXPLAIN VERBOSE
SELECT log10_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select log10(*) (stub function and group by tag only) (result)
--Testcase 61:
SELECT log10_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 62:
SELECT log2_all(), log10_all() FROM s3 ORDER BY 1;

-- select spread (stub agg function, explain)
--Testcase 63:
EXPLAIN VERBOSE
SELECT spread(value1),spread(value2),spread(value3),spread(value4) FROM s3 ORDER BY 1;

-- select spread (stub agg function, result)
--Testcase 64:
SELECT * FROM (
SELECT spread(value1),spread(value2),spread(value3),spread(value4) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select spread (stub agg function, raise exception if not expected type)
--Testcase 65:
SELECT * FROM (
SELECT spread(value1::numeric),spread(value2::numeric),spread(value3::numeric),spread(value4::numeric) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select abs as nest function with agg (pushdown, explain)
--Testcase 66:
EXPLAIN VERBOSE
SELECT sum(value3),abs(sum(value3)) FROM s3 ORDER BY 1;

-- select abs as nest function with agg (pushdown, result)
--Testcase 67:
SELECT * FROM (
SELECT sum(value3),abs(sum(value3)) FROM s3
) AS t ORDER BY 1,2;

-- select abs as nest with log2 (pushdown, explain)
--Testcase 68:
EXPLAIN VERBOSE
SELECT abs(log2(value1)),abs(log2(1/value1)) FROM s3;

-- select abs as nest with log2 (pushdown, result)
--Testcase 69:
SELECT * FROM (
SELECT abs(log2(value1)),abs(log2(1/value1)) FROM s3
) AS t ORDER BY 1,2;

-- select abs with non pushdown func and explicit constant (explain)
--Testcase 70:
EXPLAIN VERBOSE
SELECT abs(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select abs with non pushdown func and explicit constant (result)
--Testcase 71:
SELECT * FROM (
SELECT abs(value3), pi(), 4.1 FROM s3
) AS t ORDER BY 1,2,3;

-- select sqrt as nest function with agg and explicit constant (pushdown, explain)
--Testcase 72:
EXPLAIN VERBOSE
SELECT sqrt(count(value1)), pi(), 4.1 FROM s3 ORDER BY 1;

-- select sqrt as nest function with agg and explicit constant (pushdown, result)
--Testcase 73:
SELECT * FROM (
SELECT sqrt(count(value1)), pi(), 4.1 FROM s3
) AS t ORDER BY 1,2,3;

-- select sqrt as nest function with agg and explicit constant and tag (error, explain)
--Testcase 74:
EXPLAIN VERBOSE
SELECT sqrt(count(value1)), pi(), 4.1, tag1 FROM s3 ORDER BY 1;

-- select spread (stub agg function and group by influx_time() and tag) (explain)
--Testcase 75:
EXPLAIN VERBOSE
SELECT spread("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select spread (stub agg function and group by influx_time() and tag) (result)
--Testcase 76:
SELECT * FROM (
SELECT spread("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1
) AS t ORDER BY 1,2,3;

-- select spread (stub agg function and group by tag only) (result)
--Testcase 77:
SELECT * FROM (
SELECT tag1,spread("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1
) AS t ORDER BY 1,2;

-- select spread (stub agg function and other aggs) (result)
--Testcase 78:
SELECT sum("value1"),spread("value1"),count("value1") FROM s3 ORDER BY 1;

-- select abs with order by (explain)
--Testcase 79:
EXPLAIN VERBOSE
SELECT value1, abs(1-value1) FROM s3 ORDER BY abs(1-value1);

-- select abs with order by (result)
--Testcase 80:
SELECT value1, abs(1-value1) FROM s3 ORDER BY abs(1-value1);

-- select abs with order by index (result)
--Testcase 81:
SELECT value1, abs(1-value1) FROM s3 ORDER BY 2,1;

-- select abs with order by index (result)
--Testcase 82:
SELECT value1, abs(1-value1) FROM s3 ORDER BY 1,2;

-- select abs and as
--Testcase 83:
SELECT * FROM (
SELECT abs(value3) as abs1 FROM s3
) AS t ORDER BY 1;

-- select abs(*) (stub function, explain)
--Testcase 84:
EXPLAIN VERBOSE
SELECT abs_all() from s3 ORDER BY 1;

-- select abs(*) (stub function, result)
--Testcase 85:
SELECT * FROM (
SELECT abs_all() from s3
) AS t ORDER BY 1;

-- select abs(*) (stub function and group by tag only) (explain)
--Testcase 86:
EXPLAIN VERBOSE
SELECT abs_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select abs(*) (stub function and group by tag only) (result)
--Testcase 87:
SELECT abs_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select abs(*) (stub function, expose data, explain)
--Testcase 88:
EXPLAIN VERBOSE
SELECT (abs_all()::s3).* from s3 ORDER BY 1;

-- select abs(*) (stub function, expose data, result)
--Testcase 89:
SELECT * FROM (
SELECT (abs_all()::s3).* from s3
) AS t ORDER BY 1;

-- select spread over join query (explain)
--Testcase 90:
EXPLAIN VERBOSE
SELECT spread(t1.value1), spread(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select spread over join query (result, stub call error)
--Testcase 91:
SELECT spread(t1.value1), spread(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select spread with having (explain)
--Testcase 92:
EXPLAIN VERBOSE
SELECT spread(value1) FROM s3 HAVING spread(value1) > 100 ORDER BY 1;

-- select spread with having (result, not pushdown, stub call error)
--Testcase 93:
SELECT spread(value1) FROM s3 HAVING spread(value1) > 100 ORDER BY 1;

-- select spread(*) (stub agg function, explain)
--Testcase 94:
EXPLAIN VERBOSE
SELECT spread_all(*) from s3 ORDER BY 1;

-- select spread(*) (stub agg function, result)
--Testcase 95:
SELECT spread_all(*) from s3 ORDER BY 1;

-- select spread(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 96:
EXPLAIN VERBOSE
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select spread(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 97:
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select spread(*) (stub agg function and group by tag only) (explain)
--Testcase 98:
EXPLAIN VERBOSE
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select spread(*) (stub agg function and group by tag only) (result)
--Testcase 99:
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select spread(*) (stub agg function, expose data, explain)
--Testcase 100:
EXPLAIN VERBOSE
SELECT (spread_all(*)::s3).* from s3 ORDER BY 1;

-- select spread(*) (stub agg function, expose data, result)
--Testcase 101:
SELECT (spread_all(*)::s3).* from s3 ORDER BY 1;

-- select spread(regex) (stub agg function, explain)
--Testcase 102:
EXPLAIN VERBOSE
SELECT spread('/value[1,4]/') from s3 ORDER BY 1;

-- select spread(regex) (stub agg function, result)
--Testcase 103:
SELECT spread('/value[1,4]/') from s3 ORDER BY 1;

-- select spread(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 104:
EXPLAIN VERBOSE
SELECT spread('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select spread(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 105:
SELECT spread('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select spread(regex) (stub agg function and group by tag only) (explain)
--Testcase 106:
EXPLAIN VERBOSE
SELECT spread('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select spread(regex) (stub agg function and group by tag only) (result)
--Testcase 107:
SELECT spread('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select spread(regex) (stub agg function, expose data, explain)
--Testcase 108:
EXPLAIN VERBOSE
SELECT (spread('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select spread(regex) (stub agg function, expose data, result)
--Testcase 109:
SELECT (spread('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select abs with arithmetic and tag in the middle (explain)
--Testcase 110:
EXPLAIN VERBOSE
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3 ORDER BY 1;

-- select abs with arithmetic and tag in the middle (result)
--Testcase 111:
SELECT * FROM (
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select with order by limit (explain)
--Testcase 112:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3);

-- select with order by limit (result)
--Testcase 113:
SELECT * FROM (
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3)
) AS t ORDER BY 1,2,3;

-- select mixing with non pushdown func (all not pushdown, explain)
--Testcase 114:
EXPLAIN VERBOSE
SELECT abs(value1), sqrt(value2), upper(tag1) FROM s3 ORDER BY 1;

-- select mixing with non pushdown func (result)
--Testcase 115:
SELECT * FROM (
SELECT abs(value1), sqrt(value2), upper(tag1) FROM s3
) AS t ORDER BY 1,2,3;

-- nested function in where clause (explain)
--Testcase 116:
EXPLAIN VERBOSE
SELECT sqrt(abs(value3)),min(value1) FROM s3 GROUP BY value3 HAVING sqrt(abs(value3)) > 0 ORDER BY 1,2;

-- nested function in where clause (result)
--Testcase 117:
SELECT sqrt(abs(value3)),min(value1) FROM s3 GROUP BY value3 HAVING sqrt(abs(value3)) > 0 ORDER BY 1,2;

--Testcase 118:
EXPLAIN VERBOSE
SELECT first(time, value1), first(time, value2), first(time, value3), first(time, value4) FROM s3 ORDER BY 1;

--Testcase 119:
SELECT first(time, value1), first(time, value2), first(time, value3), first(time, value4) FROM s3 ORDER BY 1;

-- select first(*) (stub agg function, explain)
--Testcase 120:
EXPLAIN VERBOSE
SELECT first_all(*) from s3 ORDER BY 1;

-- select first(*) (stub agg function, result)
--Testcase 121:
SELECT * FROM (
SELECT first_all(*) from s3
) AS t ORDER BY 1;

-- select first(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 122:
EXPLAIN VERBOSE
SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select first(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 123:
SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- -- select first(*) (stub agg function and group by tag only) (explain)
-- -- EXPLAIN VERBOSE
-- SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- -- select first(*) (stub agg function and group by tag only) (result)
-- -- SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select first(*) (stub agg function, expose data, explain)
--Testcase 124:
EXPLAIN VERBOSE
SELECT (first_all(*)::s3).* from s3 ORDER BY 1;

-- select first(*) (stub agg function, expose data, result)
--Testcase 125:
SELECT * FROM (
SELECT (first_all(*)::s3).* from s3
) AS t ORDER BY 1;

-- select first(regex) (stub function, explain)
--Testcase 126:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/') from s3 ORDER BY 1;

-- select first(regex) (stub function, explain)
--Testcase 127:
SELECT first('/value[1,4]/') from s3 ORDER BY 1;

-- select multiple regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 128:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/'), first('/^v.*/') from s3 ORDER BY 1;

-- select multiple regex functions (do not push down, raise warning and stub error) (result)
--Testcase 129:
SELECT first('/value[1,4]/'), first('/^v.*/') from s3 ORDER BY 1;

-- select first(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 130:
EXPLAIN VERBOSE
SELECT first('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select first(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 131:
SELECT first('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- -- select first(regex) (stub agg function and group by tag only) (explain)
-- -- EXPLAIN VERBOSE
-- SELECT first('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- -- select first(regex) (stub agg function and group by tag only) (result)
-- -- SELECT first('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select first(regex) (stub agg function, expose data, explain)
--Testcase 132:
EXPLAIN VERBOSE
SELECT (first('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select first(regex) (stub agg function, expose data, result)
--Testcase 133:
SELECT * FROM (
SELECT (first('/value[1,4]/')::s3).* from s3
) AS t ORDER BY 1;

--Testcase 134:
EXPLAIN VERBOSE
SELECT last(time, value1), last(time, value2), last(time, value3), last(time, value4) FROM s3 ORDER BY 1;

--Testcase 135:
SELECT last(time, value1), last(time, value2), last(time, value3), last(time, value4) FROM s3 ORDER BY 1;

-- select last(*) (stub agg function, explain)
--Testcase 136:
EXPLAIN VERBOSE
SELECT last_all(*) from s3 ORDER BY 1;

-- select last(*) (stub agg function, result)
--Testcase 137:
SELECT * FROM (
SELECT last_all(*) from s3
) AS t ORDER BY 1;

-- select last(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 138:
EXPLAIN VERBOSE
SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select last(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 139:
SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- -- select last(*) (stub agg function and group by tag only) (explain)
-- -- EXPLAIN VERBOSE
-- SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- -- select last(*) (stub agg function and group by tag only) (result)
-- -- SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select last(*) (stub agg function, expose data, explain)
--Testcase 140:
EXPLAIN VERBOSE
SELECT (last_all(*)::s3).* from s3 ORDER BY 1;

-- select last(*) (stub agg function, expose data, result)
--Testcase 141:
SELECT * FROM (
SELECT (last_all(*)::s3).* from s3
) AS t ORDER BY 1;

-- select last(regex) (stub function, explain)
--Testcase 142:
EXPLAIN VERBOSE
SELECT last('/value[1,4]/') from s3 ORDER BY 1;

-- select last(regex) (stub function, result)
--Testcase 143:
SELECT last('/value[1,4]/') from s3 ORDER BY 1;

-- select multiple regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 144:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/'), first('/^v.*/') from s3 ORDER BY 1;

-- select multiple regex functions (do not push down, raise warning and stub error) (result)
--Testcase 145:
SELECT first('/value[1,4]/'), first('/^v.*/') from s3 ORDER BY 1;

-- select last(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 146:
EXPLAIN VERBOSE
SELECT last('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select last(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 147:
SELECT last('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- -- select last(regex) (stub agg function and group by tag only) (explain)
-- -- EXPLAIN VERBOSE
-- SELECT last('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- -- select last(regex) (stub agg function and group by tag only) (result)
-- -- SELECT last('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select last(regex) (stub agg function, expose data, explain)
--Testcase 148:
EXPLAIN VERBOSE
SELECT (last('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select last(regex) (stub agg function, expose data, result)
--Testcase 149:
SELECT * FROM (
SELECT (last('/value[1,4]/')::s3).* from s3
) AS t ORDER BY 1;

--Testcase 150:
EXPLAIN VERBOSE
SELECT sample(value2, 3) FROM s3 WHERE value2 < 200 ORDER BY 1;
--Testcase 151:
SELECT sample(value2, 3) FROM s3 WHERE value2 < 200 ORDER BY 1;

--Testcase 152:
EXPLAIN VERBOSE
SELECT sample(value2, 1) FROM s3 WHERE time >= to_timestamp(0) AND time <= to_timestamp(5) GROUP BY influx_time(time, interval '3s') ORDER BY 1;

--Testcase 153:
SELECT sample(value2, 1) FROM s3 WHERE time >= to_timestamp(0) AND time <= to_timestamp(5) GROUP BY influx_time(time, interval '3s') ORDER BY 1;

-- select sample(*, int) (stub agg function, explain)
--Testcase 154:
EXPLAIN VERBOSE
SELECT sample_all(50) from s3 ORDER BY 1;

-- select sample(*, int) (stub agg function, result)
--Testcase 155:
SELECT * FROM (
SELECT sample_all(50) from s3
) AS t ORDER BY 1;

-- select sample(*, int) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 156:
EXPLAIN VERBOSE
SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select sample(*, int) (stub agg function and group by influx_time() and tag) (result)
--Testcase 157:
SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- -- select sample(*, int) (stub agg function and group by tag only) (explain)
-- -- EXPLAIN VERBOSE
-- SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- -- select sample(*, int) (stub agg function and group by tag only) (result)
-- -- SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select sample(*, int) (stub agg function, expose data, explain)
--Testcase 158:
EXPLAIN VERBOSE
SELECT (sample_all(50)::s3).* from s3 ORDER BY 1;

-- select sample(*, int) (stub agg function, expose data, result)
--Testcase 159:
SELECT * FROM (
SELECT (sample_all(50)::s3).* from s3
) AS t ORDER BY 1;

-- select sample(regex) (stub agg function, explain)
--Testcase 160:
EXPLAIN VERBOSE
SELECT sample('/value[1,4]/', 50) from s3 ORDER BY 1;

-- select sample(regex) (stub agg function, result)
--Testcase 161:
SELECT sample('/value[1,4]/', 50) from s3 ORDER BY 1;

-- select sample(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 162:
EXPLAIN VERBOSE
SELECT sample('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select sample(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 163:
SELECT sample('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- -- select sample(regex) (stub agg function and group by tag only) (explain)
-- -- EXPLAIN VERBOSE
-- SELECT sample('/value[1,4]/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- -- select sample(regex) (stub agg function and group by tag only) (result)
-- -- SELECT sample('/value[1,4]/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select sample(regex) (stub agg function, expose data, explain)
--Testcase 164:
EXPLAIN VERBOSE
SELECT (sample('/value[1,4]/', 50)::s3).* from s3 ORDER BY 1;

-- select sample(regex) (stub agg function, expose data, result)
--Testcase 165:
SELECT * FROM (
SELECT (sample('/value[1,4]/', 50)::s3).* from s3
) AS t ORDER BY 1;

--Testcase 166:
EXPLAIN VERBOSE
SELECT cumulative_sum(value1),cumulative_sum(value2),cumulative_sum(value3),cumulative_sum(value4) FROM s3 ORDER BY 1;

--Testcase 167:
SELECT cumulative_sum(value1),cumulative_sum(value2),cumulative_sum(value3),cumulative_sum(value4) FROM s3 ORDER BY 1;

-- select cumulative_sum(*) (stub function, explain)
--Testcase 168:
EXPLAIN VERBOSE
SELECT cumulative_sum_all() from s3 ORDER BY 1;

-- select cumulative_sum(*) (stub function, result)
--Testcase 169:
SELECT * FROM (
SELECT cumulative_sum_all() from s3
) AS t ORDER BY 1;

-- select cumulative_sum(regex) (stub function, result)
--Testcase 170:
SELECT cumulative_sum('/value[1,4]/') from s3 ORDER BY 1;

-- select cumulative_sum(regex) (stub function, result)
--Testcase 171:
SELECT cumulative_sum('/value[1,4]/') from s3 ORDER BY 1;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (result)
--Testcase 172:
EXPLAIN VERBOSE
SELECT cumulative_sum_all(), cumulative_sum('/value[1,4]/') from s3 ORDER BY 1;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (result)
--Testcase 173:
SELECT cumulative_sum_all(), cumulative_sum('/value[1,4]/') from s3 ORDER BY 1;

-- select cumulative_sum(*) (stub function and group by tag only) (explain)
--Testcase 174:
EXPLAIN VERBOSE
SELECT cumulative_sum_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select cumulative_sum(*) (stub function and group by tag only) (result)
--Testcase 175:
SELECT cumulative_sum_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;
-- select cumulative_sum(regex) (stub function and group by tag only) (explain)
--Testcase 176:
EXPLAIN VERBOSE
SELECT cumulative_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select cumulative_sum(regex) (stub function and group by tag only) (result)
--Testcase 177:
SELECT cumulative_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select cumulative_sum(*), cumulative_sum(regex) (stub function, expose data, explain)
--Testcase 178:
EXPLAIN VERBOSE
SELECT (cumulative_sum_all()::s3).*, (cumulative_sum('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select cumulative_sum(*), cumulative_sum(regex) (stub function, expose data, result)
--Testcase 179:
SELECT (cumulative_sum_all()::s3).*, (cumulative_sum('/value[1,4]/')::s3).* from s3 ORDER BY 1;

--Testcase 180:
EXPLAIN VERBOSE
SELECT derivative(value1),derivative(value2),derivative(value3),derivative(value4) FROM s3 ORDER BY 1;

--Testcase 181:
SELECT * FROM (
SELECT derivative(value1),derivative(value2),derivative(value3),derivative(value4) FROM s3
) as t ORDER BY 1, 2, 3, 4;

--Testcase 182:
EXPLAIN VERBOSE
SELECT derivative(value1, interval '0.5s'),derivative(value2, interval '0.2s'),derivative(value3, interval '0.1s'),derivative(value4, interval '2s') FROM s3 ORDER BY 1;

--Testcase 183:
SELECT derivative(value1, interval '0.5s'),derivative(value2, interval '0.2s'),derivative(value3, interval '0.1s'),derivative(value4, interval '2s') FROM s3 ORDER BY 1;

-- select derivative(*) (stub function, explain)
--Testcase 184:
EXPLAIN VERBOSE
SELECT derivative_all() from s3 ORDER BY 1;

-- select derivative(*) (stub function, result)
--Testcase 185:
SELECT * FROM (
SELECT derivative_all() from s3
) as t ORDER BY 1;

-- select derivative(regex) (stub function, explain)
--Testcase 186:
EXPLAIN VERBOSE
SELECT derivative('/value[1,4]/') from s3 ORDER BY 1;

-- select derivative(regex) (stub function, result)
--Testcase 187:
SELECT derivative('/value[1,4]/') from s3 ORDER BY 1;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 188:
EXPLAIN VERBOSE
SELECT derivative_all(), derivative('/value[1,4]/') from s3 ORDER BY 1;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 189:
SELECT derivative_all(), derivative('/value[1,4]/') from s3 ORDER BY 1;

-- select derivative(*) (stub function and group by tag only) (explain)
--Testcase 190:
EXPLAIN VERBOSE
SELECT derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select derivative(*) (stub function and group by tag only) (result)
--Testcase 191:
SELECT derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select derivative(regex) (stub function and group by tag only) (explain)
--Testcase 192:
EXPLAIN VERBOSE
SELECT derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select derivative(regex) (stub function and group by tag only) (result)
--Testcase 193:
SELECT derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select derivative(*) (stub function, expose data, explain)
--Testcase 194:
EXPLAIN VERBOSE
SELECT (derivative_all()::s3).* from s3 ORDER BY 1;

-- select derivative(*) (stub function, expose data, result)
--Testcase 195:
SELECT * FROM (
SELECT (derivative_all()::s3).* from s3
) as t ORDER BY 1;

-- select derivative(regex) (stub function, expose data, explain)
--Testcase 196:
EXPLAIN VERBOSE
SELECT (derivative('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select derivative(regex) (stub function, expose data, result)
--Testcase 197:
SELECT * FROM (
SELECT (derivative('/value[1,4]/')::s3).* from s3
) as t ORDER BY 1;

--Testcase 198:
EXPLAIN VERBOSE
SELECT non_negative_derivative(value1),non_negative_derivative(value2),non_negative_derivative(value3),non_negative_derivative(value4) FROM s3 ORDER BY 1;

--Testcase 199:
SELECT * FROM (
SELECT non_negative_derivative(value1),non_negative_derivative(value2),non_negative_derivative(value3),non_negative_derivative(value4) FROM s3
) as t ORDER BY 1, 2, 3, 4;

--Testcase 200:
EXPLAIN VERBOSE
SELECT non_negative_derivative(value1, interval '0.5s'),non_negative_derivative(value2, interval '0.2s'),non_negative_derivative(value3, interval '0.1s'),non_negative_derivative(value4, interval '2s') FROM s3 ORDER BY 1;

--Testcase 201:
SELECT non_negative_derivative(value1, interval '0.5s'),non_negative_derivative(value2, interval '0.2s'),non_negative_derivative(value3, interval '0.1s'),non_negative_derivative(value4, interval '2s') FROM s3 ORDER BY 1;

-- select non_negative_derivative(*) (stub function, explain)
--Testcase 202:
EXPLAIN VERBOSE
SELECT non_negative_derivative_all() from s3 ORDER BY 1;

-- select non_negative_derivative(*) (stub function, result)
--Testcase 203:
SELECT * FROM (
SELECT non_negative_derivative_all() from s3
) as t ORDER BY 1;

-- select non_negative_derivative(regex) (stub function, explain)
--Testcase 204:
EXPLAIN VERBOSE
SELECT non_negative_derivative('/value[1,4]/') from s3 ORDER BY 1;

-- select non_negative_derivative(regex) (stub function, result)
--Testcase 205:
SELECT non_negative_derivative('/value[1,4]/') from s3 ORDER BY 1;

-- select non_negative_derivative(*) (stub function and group by tag only) (explain)
--Testcase 206:
EXPLAIN VERBOSE
SELECT non_negative_derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_derivative(*) (stub function and group by tag only) (result)
--Testcase 207:
SELECT non_negative_derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_derivative(regex) (stub function and group by tag only) (explain)
--Testcase 208:
EXPLAIN VERBOSE
SELECT non_negative_derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_derivative(regex) (stub function and group by tag only) (result)
--Testcase 209:
SELECT non_negative_derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_derivative(*) (stub function, expose data, explain)
--Testcase 210:
EXPLAIN VERBOSE
SELECT (non_negative_derivative_all()::s3).* from s3 ORDER BY 1;

-- select non_negative_derivative(*) (stub function, expose data, result)
--Testcase 211:
SELECT * FROM (
SELECT (non_negative_derivative_all()::s3).* from s3
) as t ORDER BY 1;

-- select non_negative_derivative(regex) (stub function, expose data, explain)
--Testcase 212:
EXPLAIN VERBOSE
SELECT (non_negative_derivative('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select non_negative_derivative(regex) (stub function, expose data, result)
--Testcase 213:
SELECT * FROM (
SELECT (non_negative_derivative('/value[1,4]/')::s3).* from s3
) as t ORDER BY 1;

--Testcase 214:
EXPLAIN VERBOSE
SELECT difference(value1),difference(value2),difference(value3),difference(value4) FROM s3 ORDER BY 1;

--Testcase 215:
SELECT difference(value1),difference(value2),difference(value3),difference(value4) FROM s3 ORDER BY 1;

-- select difference(*) (stub function, explain)
--Testcase 216:
EXPLAIN VERBOSE
SELECT difference_all() from s3 ORDER BY 1;

-- select difference(*) (stub function, result)
--Testcase 217:
SELECT * FROM (
SELECT difference_all() from s3
) as t ORDER BY 1;

-- select difference(regex) (stub function, explain)
--Testcase 218:
EXPLAIN VERBOSE
SELECT difference('/value[1,4]/') from s3 ORDER BY 1;

-- select difference(regex) (stub function, result)
--Testcase 219:
SELECT difference('/value[1,4]/') from s3 ORDER BY 1;

-- select difference(*) (stub function and group by tag only) (explain)
--Testcase 220:
EXPLAIN VERBOSE
SELECT difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select difference(*) (stub function and group by tag only) (result)
--Testcase 221:
 SELECT difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select difference(regex) (stub function and group by tag only) (explain)
--Testcase 222:
EXPLAIN VERBOSE
SELECT difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select difference(regex) (stub function and group by tag only) (result)
--Testcase 223:
SELECT difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select difference(*) (stub function, expose data, explain)
--Testcase 224:
EXPLAIN VERBOSE
SELECT (difference_all()::s3).* from s3 ORDER BY 1;

-- select difference(*) (stub function, expose data, result)
--Testcase 225:
SELECT * FROM (
SELECT (difference_all()::s3).* from s3
) as t ORDER BY 1;

-- select difference(regex) (stub function, expose data, explain)
--Testcase 226:
EXPLAIN VERBOSE
SELECT (difference('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select difference(regex) (stub function, expose data, result)
--Testcase 227:
SELECT * FROM (
SELECT (difference('/value[1,4]/')::s3).* from s3
) as t ORDER BY 1;

--Testcase 228:
EXPLAIN VERBOSE
SELECT non_negative_difference(value1),non_negative_difference(value2),non_negative_difference(value3),non_negative_difference(value4) FROM s3 ORDER BY 1;

--Testcase 229:
SELECT non_negative_difference(value1),non_negative_difference(value2),non_negative_difference(value3),non_negative_difference(value4) FROM s3 ORDER BY 1;

-- select non_negative_difference(*) (stub function, explain)
--Testcase 230:
EXPLAIN VERBOSE
SELECT non_negative_difference_all() from s3 ORDER BY 1;

-- select non_negative_difference(*) (stub function, result)
--Testcase 231:
SELECT * FROM (
SELECT non_negative_difference_all() from s3
) as t ORDER BY 1;

-- select non_negative_difference(regex) (stub function, explain)
--Testcase 232:
EXPLAIN VERBOSE
SELECT non_negative_difference('/value[1,4]/') from s3 ORDER BY 1;

-- select non_negative_difference(*), non_negative_difference(regex) (stub function, result)
--Testcase 233:
SELECT non_negative_difference('/value[1,4]/') from s3 ORDER BY 1;

-- select non_negative_difference(*) (stub function and group by tag only) (explain)
--Testcase 234:
EXPLAIN VERBOSE
SELECT non_negative_difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;
-- select non_negative_difference(*) (stub function and group by tag only) (result)
--Testcase 235:
SELECT non_negative_difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;
-- select non_negative_difference(regex) (stub function and group by tag only) (explain)
--Testcase 236:
EXPLAIN VERBOSE
SELECT non_negative_difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;
-- select non_negative_difference(regex) (stub function and group by tag only) (result)
--Testcase 237:
SELECT non_negative_difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_difference(*) (stub function, expose data, explain)
--Testcase 238:
EXPLAIN VERBOSE
SELECT (non_negative_difference_all()::s3).* from s3 ORDER BY 1;

-- select non_negative_difference(*) (stub function, expose data, result)
--Testcase 239:
SELECT * FROM (
SELECT (non_negative_difference_all()::s3).* from s3
) as t ORDER BY 1;

-- select non_negative_difference(regex) (stub function, expose data, explain)
--Testcase 240:
EXPLAIN VERBOSE
SELECT (non_negative_difference('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select non_negative_difference(regex) (stub function, expose data, result)
--Testcase 241:
SELECT * FROM (
SELECT (non_negative_difference('/value[1,4]/')::s3).* from s3
) as t ORDER BY 1;

--Testcase 242:
EXPLAIN VERBOSE
SELECT elapsed(value1),elapsed(value2),elapsed(value3),elapsed(value4) FROM s3 ORDER BY 1;

--Testcase 243:
SELECT elapsed(value1),elapsed(value2),elapsed(value3),elapsed(value4) FROM s3 ORDER BY 1;

--Testcase 244:
EXPLAIN VERBOSE
SELECT elapsed(value1, interval '0.5s'),elapsed(value2, interval '0.2s'),elapsed(value3, interval '0.1s'),elapsed(value4, interval '2s') FROM s3 ORDER BY 1;

--Testcase 245:
SELECT elapsed(value1, interval '0.5s'),elapsed(value2, interval '0.2s'),elapsed(value3, interval '0.1s'),elapsed(value4, interval '2s') FROM s3 ORDER BY 1;

-- select elapsed(*) (stub function, explain)
--Testcase 246:
EXPLAIN VERBOSE
SELECT elapsed_all() from s3 ORDER BY 1;

-- select elapsed(*) (stub function, result)
--Testcase 247:
SELECT * FROM (
SELECT elapsed_all() from s3
) as t ORDER BY 1;

-- select elapsed(regex) (stub function, explain)
--Testcase 248:
EXPLAIN VERBOSE
SELECT elapsed('/value[1,4]/') from s3 ORDER BY 1;

-- select elapsed(regex) (stub function, result)
--Testcase 249:
SELECT elapsed('/value[1,4]/') from s3 ORDER BY 1;

-- select elapsed(*) (stub function and group by tag only) (explain)
--Testcase 250:
EXPLAIN VERBOSE
SELECT elapsed_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;
-- select elapsed(*) (stub function and group by tag only) (result)
--Testcase 251:
SELECT elapsed_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;
-- select elapsed(regex) (stub function and group by tag only) (explain)
--Testcase 252:
EXPLAIN VERBOSE
SELECT elapsed('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;
-- select elapsed(regex) (stub function and group by tag only) (result)
--Testcase 253:
SELECT elapsed('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select elapsed(*) (stub function, expose data, explain)
--Testcase 254:
EXPLAIN VERBOSE
SELECT (elapsed_all()::s3).* from s3 ORDER BY 1;

-- select elapsed(*) (stub function, expose data, result)
--Testcase 255:
SELECT * FROM (
SELECT (elapsed_all()::s3).* from s3
) as t ORDER BY 1;

-- select elapsed(regex) (stub function, expose data, explain)
--Testcase 256:
EXPLAIN VERBOSE
SELECT (elapsed('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select elapsed(regex) (stub function, expose data, result)
--Testcase 257:
SELECT * FROM (
SELECT (elapsed('/value[1,4]/')::s3).* from s3
) as t ORDER BY 1;

--Testcase 258:
EXPLAIN VERBOSE
SELECT moving_average(value1, 2),moving_average(value2, 2),moving_average(value3, 2),moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 259:
SELECT moving_average(value1, 2),moving_average(value2, 2),moving_average(value3, 2),moving_average(value4, 2) FROM s3 ORDER BY 1;

-- select moving_average(*) (stub function, explain)
--Testcase 260:
EXPLAIN VERBOSE
SELECT moving_average_all(2) from s3 ORDER BY 1;

-- select moving_average(*) (stub function, result)
--Testcase 261:
SELECT * FROM (
SELECT moving_average_all(2) from s3
) as t ORDER BY 1;

-- select moving_average(regex) (stub function, explain)
--Testcase 262:
EXPLAIN VERBOSE
SELECT moving_average('/value[1,4]/', 2) from s3 ORDER BY 1;

-- select moving_average(regex) (stub function, result)
--Testcase 263:
SELECT moving_average('/value[1,4]/', 2) from s3 ORDER BY 1;

-- select moving_average(*) (stub function and group by tag only) (explain)
--Testcase 264:
EXPLAIN VERBOSE
SELECT moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select moving_average(*) (stub function and group by tag only) (result)
--Testcase 265:
SELECT moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 266:
EXPLAIN VERBOSE
SELECT moving_average('/value[1,4]/', 2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select moving_average(regex) (stub function and group by tag only) (result)
--Testcase 267:
SELECT moving_average('/value[1,4]/', 2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select moving_average(*) (stub function, expose data, explain)
--Testcase 268:
EXPLAIN VERBOSE
SELECT (moving_average_all(2)::s3).* from s3 ORDER BY 1;

-- select moving_average(*) (stub function, expose data, result)
--Testcase 269:
SELECT * FROM (
SELECT (moving_average_all(2)::s3).* from s3
) as t ORDER BY 1;

-- select moving_average(regex) (stub function, expose data, explain)
--Testcase 270:
EXPLAIN VERBOSE
SELECT (moving_average('/value[1,4]/', 2)::s3).* from s3 ORDER BY 1;

-- select moving_average(regex) (stub function, expose data, result)
--Testcase 271:
SELECT * FROM (
SELECT (moving_average('/value[1,4]/', 2)::s3).* from s3
) as t ORDER BY 1;

--Testcase 272:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator(value1, 2),chande_momentum_oscillator(value2, 2),chande_momentum_oscillator(value3, 2),chande_momentum_oscillator(value4, 2) FROM s3 ORDER BY 1;

--Testcase 273:
SELECT chande_momentum_oscillator(value1, 2),chande_momentum_oscillator(value2, 2),chande_momentum_oscillator(value3, 2),chande_momentum_oscillator(value4, 2) FROM s3 ORDER BY 1;

--Testcase 274:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator(value1, 2, 2),chande_momentum_oscillator(value2, 2, 2),chande_momentum_oscillator(value3, 2, 2),chande_momentum_oscillator(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 275:
SELECT chande_momentum_oscillator(value1, 2, 2),chande_momentum_oscillator(value2, 2, 2),chande_momentum_oscillator(value3, 2, 2),chande_momentum_oscillator(value4, 2, 2) FROM s3 ORDER BY 1;

-- select chande_momentum_oscillator(*) (stub function, explain)
--Testcase 276:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator_all(2) from s3 ORDER BY 1;

-- select chande_momentum_oscillator(*) (stub function, result)
--Testcase 277:
SELECT * FROM (
SELECT chande_momentum_oscillator_all(2) from s3
) as t ORDER BY 1;

-- select chande_momentum_oscillator(regex) (stub function, explain)
--Testcase 278:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator('/value[1,4]/',2) from s3 ORDER BY 1;

-- select chande_momentum_oscillator(regex) (stub function, result)
--Testcase 279:
SELECT chande_momentum_oscillator('/value[1,4]/',2) from s3 ORDER BY 1;

-- select chande_momentum_oscillator(*) (stub function and group by tag only) (explain)
--Testcase 280:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select chande_momentum_oscillator(*) (stub function and group by tag only) (result)
--Testcase 281:
SELECT chande_momentum_oscillator_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select chande_momentum_oscillator(regex) (stub function and group by tag only) (explain)
--Testcase 282:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select chande_momentum_oscillator(regex) (stub function and group by tag only) (result)
--Testcase 283:
SELECT chande_momentum_oscillator('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select chande_momentum_oscillator(*) (stub function, expose data, explain)
--Testcase 284:
EXPLAIN VERBOSE
SELECT (chande_momentum_oscillator_all(2)::s3).* from s3 ORDER BY 1;

-- select chande_momentum_oscillator(*) (stub function, expose data, result)
--Testcase 285:
SELECT * FROM (
SELECT (chande_momentum_oscillator_all(2)::s3).* from s3
) as t ORDER BY 1;

-- select chande_momentum_oscillator(regex) (stub function, expose data, explain)
--Testcase 286:
EXPLAIN VERBOSE
SELECT (chande_momentum_oscillator('/value[1,4]/',2)::s3).* from s3 ORDER BY 1;

-- select chande_momentum_oscillator(regex) (stub function, expose data, result)
--Testcase 287:
SELECT * FROM (
SELECT (chande_momentum_oscillator('/value[1,4]/',2)::s3).* from s3
) as t ORDER BY 1;

--Testcase 288:
EXPLAIN VERBOSE
SELECT exponential_moving_average(value1, 2),exponential_moving_average(value2, 2),exponential_moving_average(value3, 2),exponential_moving_average(value4, 2) FROM s3 ORDER BY 1, 2, 3, 4;

--Testcase 289:
SELECT exponential_moving_average(value1, 2),exponential_moving_average(value2, 2),exponential_moving_average(value3, 2),exponential_moving_average(value4, 2) FROM s3 ORDER BY 1, 2, 3, 4;

--Testcase 290:
EXPLAIN VERBOSE
SELECT exponential_moving_average(value1, 2, 2),exponential_moving_average(value2, 2, 2),exponential_moving_average(value3, 2, 2),exponential_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 291:
SELECT exponential_moving_average(value1, 2, 2),exponential_moving_average(value2, 2, 2),exponential_moving_average(value3, 2, 2),exponential_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

-- select exponential_moving_average(*) (stub function, explain)
--Testcase 292:
EXPLAIN VERBOSE
SELECT exponential_moving_average_all(2) from s3 ORDER BY 1;

-- select exponential_moving_average(*) (stub function, result)
--Testcase 293:
SELECT * FROM (
SELECT exponential_moving_average_all(2) from s3
) as t ORDER BY 1;

-- select exponential_moving_average(regex) (stub function, explain)
--Testcase 294:
EXPLAIN VERBOSE
SELECT exponential_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select exponential_moving_average(regex) (stub function, result)
--Testcase 295:
SELECT exponential_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select exponential_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 296:
EXPLAIN VERBOSE
SELECT exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select exponential_moving_average(*) (stub function and group by tag only) (result)
--Testcase 297:
SELECT exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select exponential_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 298:
EXPLAIN VERBOSE
SELECT exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select exponential_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 299:
SELECT exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

--Testcase 300:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average(value1, 2),double_exponential_moving_average(value2, 2),double_exponential_moving_average(value3, 2),double_exponential_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 301:
SELECT double_exponential_moving_average(value1, 2),double_exponential_moving_average(value2, 2),double_exponential_moving_average(value3, 2),double_exponential_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 302:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average(value1, 2, 2),double_exponential_moving_average(value2, 2, 2),double_exponential_moving_average(value3, 2, 2),double_exponential_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 303:
SELECT double_exponential_moving_average(value1, 2, 2),double_exponential_moving_average(value2, 2, 2),double_exponential_moving_average(value3, 2, 2),double_exponential_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

-- select double_exponential_moving_average(*) (stub function, explain)
--Testcase 304:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average_all(2) from s3 ORDER BY 1;

-- select double_exponential_moving_average(*) (stub function, result)
--Testcase 305:
SELECT * FROM (
SELECT double_exponential_moving_average_all(2) from s3
) as t ORDER BY 1;

-- select double_exponential_moving_average(regex) (stub function, explain)
--Testcase 306:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select double_exponential_moving_average(regex) (stub function, result)
--Testcase 307:
SELECT double_exponential_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select double_exponential_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 308:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select double_exponential_moving_average(*) (stub function and group by tag only) (result)
--Testcase 309:
SELECT double_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select double_exponential_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 310:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select double_exponential_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 311:
SELECT double_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

--Testcase 312:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio(value1, 2),kaufmans_efficiency_ratio(value2, 2),kaufmans_efficiency_ratio(value3, 2),kaufmans_efficiency_ratio(value4, 2) FROM s3 ORDER BY 1;

--Testcase 313:
SELECT kaufmans_efficiency_ratio(value1, 2),kaufmans_efficiency_ratio(value2, 2),kaufmans_efficiency_ratio(value3, 2),kaufmans_efficiency_ratio(value4, 2) FROM s3 ORDER BY 1;

--Testcase 314:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio(value1, 2, 2),kaufmans_efficiency_ratio(value2, 2, 2),kaufmans_efficiency_ratio(value3, 2, 2),kaufmans_efficiency_ratio(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 315:
SELECT kaufmans_efficiency_ratio(value1, 2, 2),kaufmans_efficiency_ratio(value2, 2, 2),kaufmans_efficiency_ratio(value3, 2, 2),kaufmans_efficiency_ratio(value4, 2, 2) FROM s3 ORDER BY 1;

-- select kaufmans_efficiency_ratio(*) (stub function, explain)
--Testcase 316:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio_all(2) from s3 ORDER BY 1;

-- select kaufmans_efficiency_ratio(*) (stub function, result)
--Testcase 317:
SELECT * FROM (
SELECT kaufmans_efficiency_ratio_all(2) from s3
) as t ORDER BY 1;

-- select kaufmans_efficiency_ratio(regex) (stub function, explain)
--Testcase 318:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) from s3 ORDER BY 1;

-- select kaufmans_efficiency_ratio(regex) (stub function, result)
--Testcase 319:
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) from s3 ORDER BY 1;

-- select kaufmans_efficiency_ratio(*) (stub function and group by tag only) (explain)
--Testcase 320:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_efficiency_ratio(*) (stub function and group by tag only) (result)
--Testcase 321:
SELECT kaufmans_efficiency_ratio_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_efficiency_ratio(regex) (stub function and group by tag only) (explain)
--Testcase 322:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_efficiency_ratio(regex) (stub function and group by tag only) (result)
--Testcase 323:
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_efficiency_ratio(*) (stub function, expose data, explain)
--Testcase 324:
EXPLAIN VERBOSE
SELECT (kaufmans_efficiency_ratio_all(2)::s3).* from s3 ORDER BY 1;

-- select kaufmans_efficiency_ratio(*) (stub function, expose data, result)
--Testcase 325:
SELECT * FROM (
SELECT (kaufmans_efficiency_ratio_all(2)::s3).* from s3
) as t ORDER BY 1;

-- select kaufmans_efficiency_ratio(regex) (stub function, expose data, explain)
--Testcase 326:
EXPLAIN VERBOSE
SELECT (kaufmans_efficiency_ratio('/value[1,4]/',2)::s3).* from s3 ORDER BY 1;

-- select kaufmans_efficiency_ratio(regex) (stub function, expose data, result)
--Testcase 327:
SELECT * FROM (
SELECT (kaufmans_efficiency_ratio('/value[1,4]/',2)::s3).* from s3
) as t ORDER BY 1;

--Testcase 328:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average(value1, 2),kaufmans_adaptive_moving_average(value2, 2),kaufmans_adaptive_moving_average(value3, 2),kaufmans_adaptive_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 329:
SELECT kaufmans_adaptive_moving_average(value1, 2),kaufmans_adaptive_moving_average(value2, 2),kaufmans_adaptive_moving_average(value3, 2),kaufmans_adaptive_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 330:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average(value1, 2, 2),kaufmans_adaptive_moving_average(value2, 2, 2),kaufmans_adaptive_moving_average(value3, 2, 2),kaufmans_adaptive_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 331:
SELECT kaufmans_adaptive_moving_average(value1, 2, 2),kaufmans_adaptive_moving_average(value2, 2, 2),kaufmans_adaptive_moving_average(value3, 2, 2),kaufmans_adaptive_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(*) (stub function, explain)
--Testcase 332:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average_all(2) from s3 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(*) (stub function, result)
--Testcase 333:
SELECT * FROM (
SELECT kaufmans_adaptive_moving_average_all(2) from s3
) as t ORDER BY 1;

-- select kaufmans_adaptive_moving_average(regex) (stub function, explain)
--Testcase 334:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(regex) (stub function, result)
--Testcase 335:
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 336:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(*) (stub function and group by tag only) (result)
--Testcase 337:
SELECT kaufmans_adaptive_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 338:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 339:
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

--Testcase 340:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average(value1, 2),triple_exponential_moving_average(value2, 2),triple_exponential_moving_average(value3, 2),triple_exponential_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 341:
SELECT triple_exponential_moving_average(value1, 2),triple_exponential_moving_average(value2, 2),triple_exponential_moving_average(value3, 2),triple_exponential_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 342:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average(value1, 2, 2),triple_exponential_moving_average(value2, 2, 2),triple_exponential_moving_average(value3, 2, 2),triple_exponential_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 343:
SELECT triple_exponential_moving_average(value1, 2, 2),triple_exponential_moving_average(value2, 2, 2),triple_exponential_moving_average(value3, 2, 2),triple_exponential_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

-- select triple_exponential_moving_average(*) (stub function, explain)
--Testcase 344:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average_all(2) from s3 ORDER BY 1;

-- select triple_exponential_moving_average(*) (stub function, result)
--Testcase 345:
SELECT * FROM (
SELECT triple_exponential_moving_average_all(2) from s3
) as t ORDER BY 1;

-- select triple_exponential_moving_average(regex) (stub function, explain)
--Testcase 346:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select triple_exponential_moving_average(regex) (stub function, result)
--Testcase 347:
SELECT triple_exponential_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select triple_exponential_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 348:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select triple_exponential_moving_average(*) (stub function and group by tag only) (result)
--Testcase 349:
SELECT triple_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select triple_exponential_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 350:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select triple_exponential_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 351:
SELECT triple_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

--Testcase 352:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative(value1, 2),triple_exponential_derivative(value2, 2),triple_exponential_derivative(value3, 2),triple_exponential_derivative(value4, 2) FROM s3 ORDER BY 1;

--Testcase 353:
SELECT triple_exponential_derivative(value1, 2),triple_exponential_derivative(value2, 2),triple_exponential_derivative(value3, 2),triple_exponential_derivative(value4, 2) FROM s3 ORDER BY 1;

--Testcase 354:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative(value1, 2, 2),triple_exponential_derivative(value2, 2, 2),triple_exponential_derivative(value3, 2, 2),triple_exponential_derivative(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 355:
SELECT triple_exponential_derivative(value1, 2, 2),triple_exponential_derivative(value2, 2, 2),triple_exponential_derivative(value3, 2, 2),triple_exponential_derivative(value4, 2, 2) FROM s3 ORDER BY 1;

-- select triple_exponential_derivative(*) (stub function, explain)
--Testcase 356:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative_all(2) from s3 ORDER BY 1;

-- select triple_exponential_derivative(*) (stub function, result)
--Testcase 357:
SELECT * FROM (
SELECT triple_exponential_derivative_all(2) from s3
) as t ORDER BY 1;

-- select triple_exponential_derivative(regex) (stub function, explain)
--Testcase 358:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative('/value[1,4]/',2) from s3 ORDER BY 1;

-- select triple_exponential_derivative(regex) (stub function, result)
--Testcase 359:
SELECT triple_exponential_derivative('/value[1,4]/',2) from s3 ORDER BY 1;

-- select triple_exponential_derivative(*) (stub function and group by tag only) (explain)
--Testcase 360:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select triple_exponential_derivative(*) (stub function and group by tag only) (result)
--Testcase 361:
SELECT triple_exponential_derivative_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select triple_exponential_derivative(regex) (stub function and group by tag only) (explain)
--Testcase 362:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select triple_exponential_derivative(regex) (stub function and group by tag only) (result)
--Testcase 363:
SELECT triple_exponential_derivative('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

--Testcase 364:
EXPLAIN VERBOSE
SELECT relative_strength_index(value1, 2),relative_strength_index(value2, 2),relative_strength_index(value3, 2),relative_strength_index(value4, 2) FROM s3 ORDER BY 1;

--Testcase 365:
SELECT relative_strength_index(value1, 2),relative_strength_index(value2, 2),relative_strength_index(value3, 2),relative_strength_index(value4, 2) FROM s3 ORDER BY 1;

--Testcase 366:
EXPLAIN VERBOSE
SELECT relative_strength_index(value1, 2, 2),relative_strength_index(value2, 2, 2),relative_strength_index(value3, 2, 2),relative_strength_index(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 367:
SELECT relative_strength_index(value1, 2, 2),relative_strength_index(value2, 2, 2),relative_strength_index(value3, 2, 2),relative_strength_index(value4, 2, 2) FROM s3 ORDER BY 1;

-- select relative_strength_index(*) (stub function, explain)
--Testcase 368:
EXPLAIN VERBOSE
SELECT relative_strength_index_all(2) from s3 ORDER BY 1;

-- select relative_strength_index(*) (stub function, result)
--Testcase 369:
SELECT * FROM (
SELECT relative_strength_index_all(2) from s3
) as t ORDER BY 1;

-- select relative_strength_index(regex) (stub function, explain)
--Testcase 370:
EXPLAIN VERBOSE
SELECT relative_strength_index('/value[1,4]/',2) from s3 ORDER BY 1;

-- select relative_strength_index(regex) (stub function, result)
--Testcase 371:
SELECT relative_strength_index('/value[1,4]/',2) from s3 ORDER BY 1;

-- select relative_strength_index(*) (stub function and group by tag only) (explain)
--Testcase 372:
EXPLAIN VERBOSE
SELECT relative_strength_index_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select relative_strength_index(*) (stub function and group by tag only) (result)
--Testcase 373:
SELECT relative_strength_index_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select relative_strength_index(regex) (stub function and group by tag only) (explain)
--Testcase 374:
EXPLAIN VERBOSE
SELECT relative_strength_index('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select relative_strength_index(regex) (stub function and group by tag only) (result)
--Testcase 375:
SELECT relative_strength_index('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select relative_strength_index(*) (stub function, expose data, explain)
--Testcase 376:
EXPLAIN VERBOSE
SELECT (relative_strength_index_all(2)::s3).* from s3 ORDER BY 1;

-- select relative_strength_index(*) (stub function, expose data, result)
--Testcase 377:
SELECT * FROM (
SELECT (relative_strength_index_all(2)::s3).* from s3
) as t ORDER BY 1;

-- select relative_strength_index(regex) (stub function, expose data, explain)
--Testcase 378:
EXPLAIN VERBOSE
SELECT (relative_strength_index('/value[1,4]/',2)::s3).* from s3 ORDER BY 1;

-- select relative_strength_index(regex) (stub function, expose data, result)
--Testcase 379:
SELECT * FROM (
SELECT (relative_strength_index('/value[1,4]/',2)::s3).* from s3
) as t ORDER BY 1;

-- select integral (stub agg function, explain)
--Testcase 380:
EXPLAIN VERBOSE
SELECT integral(value1),integral(value2),integral(value3),integral(value4) FROM s3 ORDER BY 1;

-- select integral (stub agg function, result)
--Testcase 381:
SELECT integral(value1),integral(value2),integral(value3),integral(value4) FROM s3 ORDER BY 1;

--Testcase 382:
EXPLAIN VERBOSE
SELECT integral(value1, interval '1s'),integral(value2, interval '1s'),integral(value3, interval '1s'),integral(value4, interval '1s') FROM s3 ORDER BY 1;

-- select integral (stub agg function, result)
--Testcase 383:
SELECT integral(value1, interval '1s'),integral(value2, interval '1s'),integral(value3, interval '1s'),integral(value4, interval '1s') FROM s3 ORDER BY 1;

-- select integral (stub agg function, raise exception if not expected type)
--SELECT integral(value1::numeric),integral(value2::numeric),integral(value3::numeric),integral(value4::numeric) FROM s3 ORDER BY 1;

-- select integral (stub agg function and group by influx_time() and tag) (explain)
--Testcase 384:
EXPLAIN VERBOSE
SELECT integral("value1"),influx_time(time, interval '1s'),tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral (stub agg function and group by influx_time() and tag) (result)
--Testcase 385:
SELECT integral("value1"),influx_time(time, interval '1s'),tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral (stub agg function and group by influx_time() and tag) (explain)
--Testcase 386:
EXPLAIN VERBOSE
SELECT integral("value1", interval '1s'),influx_time(time, interval '1s'),tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral (stub agg function and group by influx_time() and tag) (result)
--Testcase 387:
SELECT integral("value1", interval '1s'),influx_time(time, interval '1s'),tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral (stub agg function and group by tag only) (result)
--Testcase 388:
SELECT tag1,integral("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select integral (stub agg function and other aggs) (result)
--Testcase 389:
SELECT sum("value1"),integral("value1"),count("value1") FROM s3 ORDER BY 1;

-- select integral (stub agg function and group by tag only) (result)
--Testcase 390:
SELECT tag1,integral("value1", interval '1s') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select integral (stub agg function and other aggs) (result)
--Testcase 391:
SELECT sum("value1"),integral("value1", interval '1s'),count("value1") FROM s3 ORDER BY 1;

-- select integral over join query (explain)
--Testcase 392:
EXPLAIN VERBOSE
SELECT integral(t1.value1), integral(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select integral over join query (result, stub call error)
--Testcase 393:
SELECT integral(t1.value1), integral(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select integral over join query (explain)
--Testcase 394:
EXPLAIN VERBOSE
SELECT integral(t1.value1, interval '1s'), integral(t2.value1, interval '1s') FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select integral over join query (result, stub call error)
--Testcase 395:
SELECT integral(t1.value1, interval '1s'), integral(t2.value1, interval '1s') FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select integral with having (explain)
--Testcase 396:
EXPLAIN VERBOSE
SELECT integral(value1) FROM s3 HAVING integral(value1) > 100 ORDER BY 1;

-- select integral with having (explain, not pushdown, stub call error)
--Testcase 397:
SELECT integral(value1) FROM s3 HAVING integral(value1) > 100 ORDER BY 1;

-- select integral with having (explain)
--Testcase 398:
EXPLAIN VERBOSE
SELECT integral(value1, interval '1s') FROM s3 HAVING integral(value1, interval '1s') > 100 ORDER BY 1;

-- select integral with having (explain, not pushdown, stub call error)
--Testcase 399:
SELECT integral(value1, interval '1s') FROM s3 HAVING integral(value1, interval '1s') > 100 ORDER BY 1;

-- select integral(*) (stub agg function, explain)
--Testcase 400:
EXPLAIN VERBOSE
SELECT integral_all(*) from s3 ORDER BY 1;

-- select integral(*) (stub agg function, result)
--Testcase 401:
SELECT integral_all(*) from s3 ORDER BY 1;

-- select integral(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 402:
EXPLAIN VERBOSE
SELECT integral_all(*) FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 403:
SELECT integral_all(*) FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral(*) (stub agg function and group by tag only) (explain)
--Testcase 404:
EXPLAIN VERBOSE
SELECT integral_all(*) FROM s3 WHERE value1 > 0.3 GROUP BY tag1 ORDER BY 1;

-- select integral(*) (stub agg function and group by tag only) (result)
--Testcase 405:
SELECT integral_all(*) FROM s3 WHERE value1 > 0.3 GROUP BY tag1 ORDER BY 1;

-- select integral(*) (stub agg function, expose data, explain)
--Testcase 406:
EXPLAIN VERBOSE
SELECT (integral_all(*)::s3).* from s3 ORDER BY 1;

-- select integral(*) (stub agg function, expose data, result)
--Testcase 407:
SELECT (integral_all(*)::s3).* from s3 ORDER BY 1;

-- select integral(regex) (stub agg function, explain)
--Testcase 408:
EXPLAIN VERBOSE
SELECT integral('/value[1,4]/') from s3 ORDER BY 1;

-- select integral(regex) (stub agg function, result)
--Testcase 409:
SELECT integral('/value[1,4]/') from s3 ORDER BY 1;

-- select integral(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 410:
EXPLAIN VERBOSE
SELECT integral('/^v.*/') FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 411:
SELECT integral('/^v.*/') FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral(regex) (stub agg function and group by tag only) (explain)
--Testcase 412:
EXPLAIN VERBOSE
SELECT integral('/value[1,4]/') FROM s3 WHERE value1 > 0.3 GROUP BY tag1 ORDER BY 1;

-- select integral(regex) (stub agg function and group by tag only) (result)
--Testcase 413:
SELECT integral('/value[1,4]/') FROM s3 WHERE value1 > 0.3 GROUP BY tag1 ORDER BY 1;

-- select integral(regex) (stub agg function, expose data, explain)
--Testcase 414:
EXPLAIN VERBOSE
SELECT (integral('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select integral(regex) (stub agg function, expose data, result)
--Testcase 415:
SELECT (integral('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select mean (stub agg function, explain)
--Testcase 416:
EXPLAIN VERBOSE
SELECT mean(value1),mean(value2),mean(value3),mean(value4) FROM s3 ORDER BY 1;

-- select mean (stub agg function, result)
--Testcase 417:
SELECT mean(value1),mean(value2),mean(value3),mean(value4) FROM s3 ORDER BY 1;

-- select mean (stub agg function, raise exception if not expected type)
--SELECT mean(value1::numeric),mean(value2::numeric),mean(value3::numeric),mean(value4::numeric) FROM s3 ORDER BY 1;

-- select mean (stub agg function and group by influx_time() and tag) (explain)
--Testcase 418:
EXPLAIN VERBOSE
SELECT mean("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select mean (stub agg function and group by influx_time() and tag) (result)
--Testcase 419:
SELECT mean("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select mean (stub agg function and group by tag only) (result)
--Testcase 420:
SELECT tag1,mean("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select mean (stub agg function and other aggs) (result)
--Testcase 421:
SELECT sum("value1"),mean("value1"),count("value1") FROM s3 ORDER BY 1;

-- select mean over join query (explain)
--Testcase 422:
EXPLAIN VERBOSE
SELECT mean(t1.value1), mean(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select mean over join query (result, stub call error)
--Testcase 423:
SELECT mean(t1.value1), mean(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select mean with having (explain)
--Testcase 424:
EXPLAIN VERBOSE
SELECT mean(value1) FROM s3 HAVING mean(value1) > 100 ORDER BY 1;

-- select mean with having (explain, not pushdown, stub call error)
--Testcase 425:
SELECT mean(value1) FROM s3 HAVING mean(value1) > 100 ORDER BY 1;

-- select mean(*) (stub agg function, explain)
--Testcase 426:
EXPLAIN VERBOSE
SELECT mean_all(*) from s3 ORDER BY 1;

-- select mean(*) (stub agg function, result)
--Testcase 427:
SELECT mean_all(*) from s3 ORDER BY 1;

-- select mean(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 428:
EXPLAIN VERBOSE
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select mean(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 429:
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select mean(*) (stub agg function and group by tag only) (explain)
--Testcase 430:
EXPLAIN VERBOSE
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select mean(*) (stub agg function and group by tag only) (result)
--Testcase 431:
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select mean(*) (stub agg function, expose data, explain)
--Testcase 432:
EXPLAIN VERBOSE
SELECT (mean_all(*)::s3).* from s3 ORDER BY 1;

-- select mean(*) (stub agg function, expose data, result)
--Testcase 433:
SELECT (mean_all(*)::s3).* from s3 ORDER BY 1;

-- select mean(regex) (stub agg function, explain)
--Testcase 434:
EXPLAIN VERBOSE
SELECT mean('/value[1,4]/') from s3 ORDER BY 1;

-- select mean(regex) (stub agg function, result)
--Testcase 435:
SELECT mean('/value[1,4]/') from s3 ORDER BY 1;

-- select mean(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 436:
EXPLAIN VERBOSE
SELECT mean('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select mean(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 437:
SELECT mean('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select mean(regex) (stub agg function and group by tag only) (explain)
--Testcase 438:
EXPLAIN VERBOSE
SELECT mean('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select mean(regex) (stub agg function and group by tag only) (result)
--Testcase 439:
SELECT mean('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select mean(regex) (stub agg function, expose data, explain)
--Testcase 440:
EXPLAIN VERBOSE
SELECT (mean('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select mean(regex) (stub agg function, expose data, result)
--Testcase 441:
SELECT (mean('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select median (stub agg function, explain)
--Testcase 442:
EXPLAIN VERBOSE
SELECT median(value1),median(value2),median(value3),median(value4) FROM s3 ORDER BY 1;

-- select median (stub agg function, result)
--Testcase 443:
SELECT median(value1),median(value2),median(value3),median(value4) FROM s3 ORDER BY 1;

-- select median (stub agg function, raise exception if not expected type)
--SELECT median(value1::numeric),median(value2::numeric),median(value3::numeric),median(value4::numeric) FROM s3 ORDER BY 1;

-- select median (stub agg function and group by influx_time() and tag) (explain)
--Testcase 444:
EXPLAIN VERBOSE
SELECT median("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select median (stub agg function and group by influx_time() and tag) (result)
--Testcase 445:
SELECT median("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select median (stub agg function and group by tag only) (result)
--Testcase 446:
SELECT tag1,median("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select median (stub agg function and other aggs) (result)
--Testcase 447:
SELECT sum("value1"),median("value1"),count("value1") FROM s3 ORDER BY 1;

-- select median over join query (explain)
--Testcase 448:
EXPLAIN VERBOSE
SELECT median(t1.value1), median(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select median over join query (result, stub call error)
--Testcase 449:
SELECT median(t1.value1), median(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select median with having (explain)
--Testcase 450:
EXPLAIN VERBOSE
SELECT median(value1) FROM s3 HAVING median(value1) > 100 ORDER BY 1;

-- select median with having (explain, not pushdown, stub call error)
--Testcase 451:
SELECT median(value1) FROM s3 HAVING median(value1) > 100 ORDER BY 1;

-- select median(*) (stub agg function, explain)
--Testcase 452:
EXPLAIN VERBOSE
SELECT median_all(*) from s3 ORDER BY 1;

-- select median(*) (stub agg function, result)
--Testcase 453:
SELECT median_all(*) from s3 ORDER BY 1;

-- select median(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 454:
EXPLAIN VERBOSE
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select median(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 455:
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select median(*) (stub agg function and group by tag only) (explain)
--Testcase 456:
EXPLAIN VERBOSE
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select median(*) (stub agg function and group by tag only) (result)
--Testcase 457:
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select median(*) (stub agg function, expose data, explain)
--Testcase 458:
EXPLAIN VERBOSE
SELECT (median_all(*)::s3).* from s3 ORDER BY 1;

-- select median(*) (stub agg function, expose data, result)
--Testcase 459:
SELECT (median_all(*)::s3).* from s3 ORDER BY 1;

-- select median(regex) (stub agg function, explain)
--Testcase 460:
EXPLAIN VERBOSE
SELECT median('/^v.*/') from s3 ORDER BY 1;

-- select median(regex) (stub agg function, result)
--Testcase 461:
SELECT  median('/^v.*/') from s3 ORDER BY 1;

-- select median(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 462:
EXPLAIN VERBOSE
SELECT median('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select median(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 463:
SELECT median('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select median(regex) (stub agg function and group by tag only) (explain)
--Testcase 464:
EXPLAIN VERBOSE
SELECT median('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select median(regex) (stub agg function and group by tag only) (result)
--Testcase 465:
SELECT median('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select median(regex) (stub agg function, expose data, explain)
--Testcase 466:
EXPLAIN VERBOSE
SELECT (median('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select median(regex) (stub agg function, expose data, result)
--Testcase 467:
SELECT (median('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select influx_mode (stub agg function, explain)
--Testcase 468:
EXPLAIN VERBOSE
SELECT influx_mode(value1),influx_mode(value2),influx_mode(value3),influx_mode(value4) FROM s3 ORDER BY 1;

-- select influx_mode (stub agg function, result)
--Testcase 469:
SELECT influx_mode(value1),influx_mode(value2),influx_mode(value3),influx_mode(value4) FROM s3 ORDER BY 1;

-- select influx_mode (stub agg function, raise exception if not expected type)
--SELECT influx_mode(value1::numeric),influx_mode(value2::numeric),influx_mode(value3::numeric),influx_mode(value4::numeric) FROM s3 ORDER BY 1;

-- select influx_mode (stub agg function and group by influx_time() and tag) (explain)
--Testcase 470:
EXPLAIN VERBOSE
SELECT influx_mode("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_mode (stub agg function and group by influx_time() and tag) (result)
--Testcase 471:
SELECT influx_mode("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_mode (stub agg function and group by tag only) (result)
--Testcase 472:
SELECT tag1,influx_mode("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_mode (stub agg function and other aggs) (result)
--Testcase 473:
SELECT sum("value1"),influx_mode("value1"),count("value1") FROM s3 ORDER BY 1;

-- select influx_mode over join query (explain)
--Testcase 474:
EXPLAIN VERBOSE
SELECT influx_mode(t1.value1), influx_mode(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select influx_mode over join query (result, stub call error)
--Testcase 475:
SELECT influx_mode(t1.value1), influx_mode(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select influx_mode with having (explain)
--Testcase 476:
EXPLAIN VERBOSE
SELECT influx_mode(value1) FROM s3 HAVING influx_mode(value1) > 100 ORDER BY 1;

-- select influx_mode with having (explain, not pushdown, stub call error)
--Testcase 477:
SELECT influx_mode(value1) FROM s3 HAVING influx_mode(value1) > 100 ORDER BY 1;

-- select influx_mode(*) (stub agg function, explain)
--Testcase 478:
EXPLAIN VERBOSE
SELECT influx_mode_all(*) from s3 ORDER BY 1;

-- select influx_mode(*) (stub agg function, result)
--Testcase 479:
SELECT influx_mode_all(*) from s3 ORDER BY 1;

-- select influx_mode(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 480:
EXPLAIN VERBOSE
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_mode(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 481:
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_mode(*) (stub agg function and group by tag only) (explain)
--Testcase 482:
EXPLAIN VERBOSE
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_mode(*) (stub agg function and group by tag only) (result)
--Testcase 483:
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_mode(*) (stub agg function, expose data, explain)
--Testcase 484:
EXPLAIN VERBOSE
SELECT (influx_mode_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_mode(*) (stub agg function, expose data, result)
--Testcase 485:
SELECT (influx_mode_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_mode(regex) (stub function, explain)
--Testcase 486:
EXPLAIN VERBOSE
SELECT influx_mode('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_mode(regex) (stub function, result)
--Testcase 487:
SELECT influx_mode('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_mode(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 488:
EXPLAIN VERBOSE
SELECT influx_mode('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_mode(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 489:
SELECT influx_mode('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_mode(regex) (stub agg function and group by tag only) (explain)
--Testcase 490:
EXPLAIN VERBOSE
SELECT influx_mode('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_mode(regex) (stub agg function and group by tag only) (result)
--Testcase 491:
SELECT influx_mode('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_mode(regex) (stub agg function, expose data, explain)
--Testcase 492:
EXPLAIN VERBOSE
SELECT (influx_mode('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select influx_mode(regex) (stub agg function, expose data, result)
--Testcase 493:
SELECT (influx_mode('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select stddev (agg function, explain)
--Testcase 494:
EXPLAIN VERBOSE
SELECT stddev(value1),stddev(value2),stddev(value3),stddev(value4) FROM s3 ORDER BY 1;

-- select stddev (agg function, result)
--Testcase 495:
SELECT stddev(value1),stddev(value2),stddev(value3),stddev(value4) FROM s3 ORDER BY 1;

-- select stddev (agg function and group by influx_time() and tag) (explain)
--Testcase 496:
EXPLAIN VERBOSE
SELECT stddev("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select stddev (agg function and group by influx_time() and tag) (result)
--Testcase 497:
SELECT stddev("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select stddev (agg function and group by tag only) (result)
--Testcase 498:
SELECT tag1,stddev("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select stddev (agg function and other aggs) (result)
--Testcase 499:
SELECT sum("value1"),stddev("value1"),count("value1") FROM s3 ORDER BY 1;

-- select stddev(*) (stub agg function, explain)
--Testcase 500:
EXPLAIN VERBOSE
SELECT stddev_all(*) from s3 ORDER BY 1;

-- select stddev(*) (stub agg function, result)
--Testcase 501:
SELECT stddev_all(*) from s3 ORDER BY 1;

-- select stddev(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 502:
EXPLAIN VERBOSE
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select stddev(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 503:
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select stddev(*) (stub agg function and group by tag only) (explain)
--Testcase 504:
EXPLAIN VERBOSE
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select stddev(*) (stub agg function and group by tag only) (result)
--Testcase 505:
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select stddev(regex) (stub function, explain)
--Testcase 506:
EXPLAIN VERBOSE
SELECT stddev('/value[1,4]/') from s3 ORDER BY 1;

-- select stddev(regex) (stub function, result)
--Testcase 507:
SELECT stddev('/value[1,4]/') from s3 ORDER BY 1;

-- select stddev(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 508:
EXPLAIN VERBOSE
SELECT stddev('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select stddev(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 509:
SELECT stddev('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select stddev(regex) (stub agg function and group by tag only) (explain)
--Testcase 510:
EXPLAIN VERBOSE
SELECT stddev('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select stddev(regex) (stub agg function and group by tag only) (result)
--Testcase 511:
SELECT stddev('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_sum(*) (stub agg function, explain)
--Testcase 512:
EXPLAIN VERBOSE
SELECT influx_sum_all(*) from s3 ORDER BY 1;

-- select influx_sum(*) (stub agg function, result)
--Testcase 513:
SELECT influx_sum_all(*) from s3 ORDER BY 1;

-- select influx_sum(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 514:
EXPLAIN VERBOSE
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_sum(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 515:
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_sum(*) (stub agg function and group by tag only) (explain)
--Testcase 516:
EXPLAIN VERBOSE
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_sum(*) (stub agg function and group by tag only) (result)
--Testcase 517:
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_sum(*) (stub agg function, expose data, explain)
--Testcase 518:
EXPLAIN VERBOSE
SELECT (influx_sum_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_sum(*) (stub agg function, expose data, result)
--Testcase 519:
SELECT (influx_sum_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_sum(regex) (stub function, explain)
--Testcase 520:
EXPLAIN VERBOSE
SELECT influx_sum('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_sum(regex) (stub function, result)
--Testcase 521:
SELECT influx_sum('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_sum(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 522:
EXPLAIN VERBOSE
SELECT influx_sum('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_sum(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 523:
SELECT influx_sum('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_sum(regex) (stub agg function and group by tag only) (explain)
--Testcase 524:
EXPLAIN VERBOSE
SELECT influx_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_sum(regex) (stub agg function and group by tag only) (result)
--Testcase 525:
SELECT influx_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_sum(regex) (stub agg function, expose data, explain)
--Testcase 526:
EXPLAIN VERBOSE
SELECT (influx_sum('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select influx_sum(regex) (stub agg function, expose data, result)
--Testcase 527:
SELECT (influx_sum('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- selector function bottom() (explain)
--Testcase 528:
EXPLAIN VERBOSE
SELECT bottom(value1, 1) FROM s3 ORDER BY 1;

-- selector function bottom() (result)
--Testcase 529:
SELECT bottom(value1, 1) FROM s3 ORDER BY 1;

-- selector function bottom() cannot be combined with other functions(explain)
--Testcase 530:
EXPLAIN VERBOSE
SELECT bottom(value1, 1), bottom(value2, 1), bottom(value3, 1), bottom(value4, 1) FROM s3 ORDER BY 1;

-- selector function bottom() cannot be combined with other functions(result)
--Testcase 531:
SELECT bottom(value1, 1), bottom(value2, 1), bottom(value3, 1), bottom(value4, 1) FROM s3 ORDER BY 1;

-- select influx_max(*) (stub agg function, explain)
--Testcase 532:
EXPLAIN VERBOSE
SELECT influx_max_all(*) from s3 ORDER BY 1;

-- select influx_max(*) (stub agg function, result)
--Testcase 533:
SELECT influx_max_all(*) from s3 ORDER BY 1;

-- select influx_max(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 534:
EXPLAIN VERBOSE
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_max(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 535:
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_max(*) (stub agg function and group by tag only) (explain)
--Testcase 536:
EXPLAIN VERBOSE
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_max(*) (stub agg function and group by tag only) (result)
--Testcase 537:
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_max(*) (stub agg function, expose data, explain)
--Testcase 538:
EXPLAIN VERBOSE
SELECT (influx_max_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_max(*) (stub agg function, expose data, result)
--Testcase 539:
SELECT (influx_max_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_max(regex) (stub function, explain)
--Testcase 540:
EXPLAIN VERBOSE
SELECT influx_max('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_max(regex) (stub function, result)
--Testcase 541:
SELECT influx_max('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_max(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 542:
EXPLAIN VERBOSE
SELECT influx_max('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_max(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 543:
SELECT influx_max('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_max(regex) (stub agg function and group by tag only) (explain)
--Testcase 544:
EXPLAIN VERBOSE
SELECT influx_max('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_max(regex) (stub agg function and group by tag only) (result)
--Testcase 545:
SELECT influx_max('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_max(regex) (stub agg function, expose data, explain)
--Testcase 546:
EXPLAIN VERBOSE
SELECT (influx_max('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select influx_max(regex) (stub agg function, expose data, result)
--Testcase 547:
SELECT (influx_max('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select influx_min(*) (stub agg function, explain)
--Testcase 548:
EXPLAIN VERBOSE
SELECT influx_min_all(*) from s3 ORDER BY 1;

-- select influx_min(*) (stub agg function, result)
--Testcase 549:
SELECT influx_min_all(*) from s3 ORDER BY 1;

-- select influx_min(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 550:
EXPLAIN VERBOSE
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_min(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 551:
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_min(*) (stub agg function and group by tag only) (explain)
--Testcase 552:
EXPLAIN VERBOSE
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_min(*) (stub agg function and group by tag only) (result)
--Testcase 553:
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_min(*) (stub agg function, expose data, explain)
--Testcase 554:
EXPLAIN VERBOSE
SELECT (influx_min_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_min(*) (stub agg function, expose data, result)
--Testcase 555:
SELECT (influx_min_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_min(regex) (stub function, explain)
--Testcase 556:
EXPLAIN VERBOSE
SELECT influx_min('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_min(regex) (stub function, result)
--Testcase 557:
SELECT influx_min('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_min(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 558:
EXPLAIN VERBOSE
SELECT influx_min('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_min(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 559:
SELECT influx_min('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_min(regex) (stub agg function and group by tag only) (explain)
--Testcase 560:
EXPLAIN VERBOSE
SELECT influx_min('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_min(regex) (stub agg function and group by tag only) (result)
--Testcase 561:
SELECT influx_min('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_min(regex) (stub agg function, expose data, explain)
--Testcase 562:
EXPLAIN VERBOSE
SELECT (influx_min('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select influx_min(regex) (stub agg function, expose data, result)
--Testcase 563:
SELECT (influx_min('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- selector function percentile() (explain)
--Testcase 564:
EXPLAIN VERBOSE
SELECT percentile(value1, 50), percentile(value2, 60), percentile(value3, 25), percentile(value4, 33) FROM s3 ORDER BY 1;

-- selector function percentile() (result)
--Testcase 565:
SELECT * FROM (
SELECT percentile(value1, 50), percentile(value2, 60), percentile(value3, 25), percentile(value4, 33) FROM s3
) as t ORDER BY 1, 2, 3, 4;

-- selector function percentile() (explain)
--Testcase 566:
EXPLAIN VERBOSE
SELECT percentile(value1, 1.5), percentile(value2, 6.7), percentile(value3, 20.5), percentile(value4, 75.2) FROM s3 ORDER BY 3;

-- selector function percentile() (result)
--Testcase 567:
SELECT percentile(value1, 1.5), percentile(value2, 6.7), percentile(value3, 20.5), percentile(value4, 75.2) FROM s3 ORDER BY 3;

-- select percentile(*, int) (stub function, explain)
--Testcase 568:
EXPLAIN VERBOSE
SELECT percentile_all(50) from s3 ORDER BY 1;

-- select percentile(*, int) (stub function, result)
--Testcase 569:
SELECT * FROM (
SELECT percentile_all(50) from s3
) as t ORDER BY 1;

-- select percentile(*, float8) (stub function, explain)
--Testcase 570:
EXPLAIN VERBOSE
SELECT percentile_all(70.5) from s3 ORDER BY 1;

-- select percentile(*, float8) (stub function, result)
--Testcase 571:
SELECT percentile_all(70.5) from s3 ORDER BY 1;

-- select percentile(*, int) (stub function and group by influx_time() and tag) (explain)
--Testcase 572:
EXPLAIN VERBOSE
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select percentile(*, int) (stub function and group by influx_time() and tag) (result)
--Testcase 573:
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select percentile(*, float8) (stub function and group by influx_time() and tag) (explain)
--Testcase 574:
EXPLAIN VERBOSE
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select percentile(*, float8) (stub function and group by influx_time() and tag) (result)
--Testcase 575:
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select percentile(*, int) (stub function and group by tag only) (explain)
--Testcase 576:
EXPLAIN VERBOSE
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select percentile(*, int) (stub function and group by tag only) (result)
--Testcase 577:
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select percentile(*, float8) (stub function and group by tag only) (explain)
--Testcase 578:
EXPLAIN VERBOSE
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select percentile(*, float8) (stub function and group by tag only) (result)
--Testcase 579:
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select percentile(*, int) (stub function, expose data, explain)
--Testcase 580:
EXPLAIN VERBOSE
SELECT (percentile_all(50)::s3).* from s3 ORDER BY 1, 2, 3, 4;

-- select percentile(*, int) (stub function, expose data, result)
--Testcase 581:
SELECT * FROM (
SELECT (percentile_all(50)::s3).* from s3
) as t ORDER BY 1, 2, 3, 4;

-- select percentile(*, int) (stub function, expose data, explain)
--Testcase 582:
EXPLAIN VERBOSE
SELECT (percentile_all(70.5)::s3).* from s3 ORDER BY 1, 2, 3, 4;

-- select percentile(*, int) (stub function, expose data, result)
--Testcase 583:
SELECT * FROM (
SELECT (percentile_all(70.5)::s3).* from s3
) as t ORDER BY 1, 2, 3, 4;

-- select percentile(regex) (stub function, explain)
--Testcase 584:
EXPLAIN VERBOSE
SELECT percentile('/value[1,4]/', 50) from s3 ORDER BY 1;

-- select percentile(regex) (stub function, result)
--Testcase 585:
SELECT percentile('/value[1,4]/', 50) from s3 ORDER BY 1;

-- select percentile(regex) (stub function and group by influx_time() and tag) (explain)
--Testcase 586:
EXPLAIN VERBOSE
SELECT percentile('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select percentile(regex) (stub function and group by influx_time() and tag) (result)
--Testcase 587:
SELECT percentile('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select percentile(regex) (stub function and group by tag only) (explain)
--Testcase 588:
EXPLAIN VERBOSE
SELECT percentile('/value[1,4]/', 70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select percentile(regex) (stub function and group by tag only) (result)
--Testcase 589:
SELECT percentile('/value[1,4]/', 70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select percentile(regex) (stub function, expose data, explain)
--Testcase 590:
EXPLAIN VERBOSE
SELECT (percentile('/value[1,4]/', 50)::s3).* from s3 ORDER BY 1, 2, 3;

-- select percentile(regex) (stub function, expose data, result)
--Testcase 591:
SELECT * FROM (
SELECT (percentile('/value[1,4]/', 50)::s3).* from s3
) as t ORDER BY 1, 2, 3;

-- select percentile(regex) (stub function, expose data, explain)
--Testcase 592:
EXPLAIN VERBOSE
SELECT (percentile('/value[1,4]/', 70.5)::s3).* from s3 ORDER BY 1, 2, 3;

-- select percentile(regex) (stub function, expose data, result)
--Testcase 593:
SELECT * FROM (
SELECT (percentile('/value[1,4]/', 70.5)::s3).* from s3
) as t ORDER BY 1, 2, 3;

-- selector function top(field_key,N) (explain)
--Testcase 594:
EXPLAIN VERBOSE
SELECT top(value1, 1) FROM s3 ORDER BY 1;

-- selector function top(field_key,N) (result)
--Testcase 595:
SELECT top(value1, 1) FROM s3 ORDER BY 1;

-- selector function top(field_key,tag_key(s),N) (explain)
--Testcase 596:
EXPLAIN VERBOSE
SELECT top(value1, tag1, 1) FROM s3 ORDER BY 1;

-- selector function top(field_key,tag_key(s),N) (result)
--Testcase 597:
SELECT top(value1, tag1, 1) FROM s3 ORDER BY 1;

-- selector function top() cannot be combined with other functions(explain)
--Testcase 598:
EXPLAIN VERBOSE
SELECT top(value1, 1), top(value2, 1), top(value3, 1), top(value4, 1) FROM s3 ORDER BY 1;

-- selector function top() cannot be combined with other functions(result)
--Testcase 599:
SELECT top(value1, 1), top(value2, 1), top(value3, 1), top(value4, 1) FROM s3 ORDER BY 1;

-- select acos (builtin function, explain)
--Testcase 600:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 ORDER BY 1;

-- select acos (builtin function, result)
--Testcase 601:
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 ORDER BY 1;

-- select acos (builtin function, not pushdown constraints, explain)
--Testcase 602:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 WHERE to_hex(value2) = '64' ORDER BY 1;

-- select acos (builtin function, not pushdown constraints, result)
--Testcase 603:
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 WHERE to_hex(value2) = '64' ORDER BY 1;

-- select acos (builtin function, pushdown constraints, explain)
--Testcase 604:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select acos (builtin function, pushdown constraints, result)
--Testcase 605:
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select acos as nest function with (pushdown, explain)
--Testcase 606:
EXPLAIN VERBOSE
SELECT sum(value3),acos(sum(value3)) FROM s3 ORDER BY 1;

-- select acos as nest function with (pushdown, result)
--Testcase 607:
SELECT sum(value3),acos(sum(value3)) FROM s3 ORDER BY 1;

-- select acos as nest with log2 (pushdown, explain)
--Testcase 608:
EXPLAIN VERBOSE
SELECT acos(log2(value1)),acos(log2(1/value1)) FROM s3;

-- select acos as nest with log2 (pushdown, result)
--Testcase 609:
SELECT * FROM (
SELECT acos(log2(value1)),acos(log2(1/value1)) FROM s3
) as t ORDER BY 1, 2;

-- select acos with non pushdown func and explicit constant (explain)
--Testcase 610:
EXPLAIN VERBOSE
SELECT acos(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select acos with non pushdown func and explicit constant (result)
--Testcase 611:
SELECT * FROM (
SELECT acos(value3), pi(), 4.1 FROM s3
) as t ORDER BY 1;

-- select acos with order by (explain)
--Testcase 612:
EXPLAIN VERBOSE
SELECT value1, acos(1-value1) FROM s3 ORDER BY acos(1-value1);

-- select acos with order by (result)
--Testcase 613:
SELECT value1, acos(1-value1) FROM s3 ORDER BY acos(1-value1);

-- select acos with order by index (result)
--Testcase 614:
SELECT value1, acos(1-value1) FROM s3 ORDER BY 2,1;

-- select acos with order by index (result)
--Testcase 615:
SELECT value1, acos(1-value1) FROM s3 ORDER BY 1,2;

-- select acos and as
--Testcase 616:
SELECT acos(value3) as acos1 FROM s3 ORDER BY 1;

-- select acos(*) (stub function, explain)
--Testcase 617:
EXPLAIN VERBOSE
SELECT acos_all() from s3 ORDER BY 1;

-- select acos(*) (stub function, result)
--Testcase 618:
SELECT * FROM (
SELECT acos_all() from s3
) as t ORDER BY 1;

-- select acos(*) (stub function and group by tag only) (explain)
--Testcase 619:
EXPLAIN VERBOSE
SELECT acos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select acos(*) (stub function and group by tag only) (result)
--Testcase 620:
SELECT acos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select acos(*) (stub function, expose data, explain)
--Testcase 621:
EXPLAIN VERBOSE
SELECT (acos_all()::s3).* from s3 ORDER BY 1;

-- select acos(*) (stub function, expose data, result)
--Testcase 622:
SELECT * FROM (
SELECT (acos_all()::s3).* from s3
) as t ORDER BY 1;

-- select asin (builtin function, explain)
--Testcase 623:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 ORDER BY 1;

-- select asin (builtin function, result)
--Testcase 624:
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 ORDER BY 1;

-- select asin (builtin function, not pushdown constraints, explain)
--Testcase 625:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 WHERE to_hex(value2) = '64' ORDER BY 1;

-- select asin (builtin function, not pushdown constraints, result)
--Testcase 626:
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 WHERE to_hex(value2) = '64' ORDER BY 1;

-- select asin (builtin function, pushdown constraints, explain)
--Testcase 627:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select asin (builtin function, pushdown constraints, result)
--Testcase 628:
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select asin as nest function with (pushdown, explain)
--Testcase 629:
EXPLAIN VERBOSE
SELECT sum(value3),asin(sum(value3)) FROM s3 ORDER BY 1;

-- select asin as nest function with (pushdown, result)
--Testcase 630:
SELECT sum(value3),asin(sum(value3)) FROM s3 ORDER BY 1;

-- select asin as nest with log2 (pushdown, explain)
--Testcase 631:
EXPLAIN VERBOSE
SELECT asin(log2(value1)),asin(log2(1/value1)) FROM s3;

-- select asin as nest with log2 (pushdown, result)
--Testcase 632:
SELECT * FROM (
SELECT asin(log2(value1)),asin(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select asin with non pushdown func and explicit constant (explain)
--Testcase 633:
EXPLAIN VERBOSE
SELECT asin(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select asin with non pushdown func and explicit constant (result)
--Testcase 634:
SELECT asin(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select asin with order by (explain)
--Testcase 635:
EXPLAIN VERBOSE
SELECT value1, asin(1-value1) FROM s3 ORDER BY asin(1-value1);

-- select asin with order by (result)
--Testcase 636:
SELECT value1, asin(1-value1) FROM s3 ORDER BY asin(1-value1);

-- select asin with order by index (result)
--Testcase 637:
SELECT value1, asin(1-value1) FROM s3 ORDER BY 2,1;

-- select asin with order by index (result)
--Testcase 638:
SELECT value1, asin(1-value1) FROM s3 ORDER BY 1,2;

-- select asin and as
--Testcase 639:
SELECT asin(value3) as asin1 FROM s3 ORDER BY 1;

-- select asin(*) (stub function, explain)
--Testcase 640:
EXPLAIN VERBOSE
SELECT asin_all() from s3 ORDER BY 1;

-- select asin(*) (stub function, result)
--Testcase 641:
SELECT * FROM (
SELECT asin_all() from s3
) as t ORDER BY 1;

-- select asin(*) (stub function and group by tag only) (explain)
--Testcase 642:
EXPLAIN VERBOSE
SELECT asin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select asin(*) (stub function and group by tag only) (result)
--Testcase 643:
SELECT asin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select asin(*) (stub function, expose data, explain)
--Testcase 644:
EXPLAIN VERBOSE
SELECT (asin_all()::s3).* from s3 ORDER BY 1;

-- select asin(*) (stub function, expose data, result)
--Testcase 645:
SELECT * FROM (
SELECT (asin_all()::s3).* from s3
) as t ORDER BY 1;

-- select atan (builtin function, explain)
--Testcase 646:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 ORDER BY 1;

-- select atan (builtin function, result)
--Testcase 647:
SELECT * FROM (
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3
) as t ORDER BY 1;

-- select atan (builtin function, not pushdown constraints, explain)
--Testcase 648:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select atan (builtin function, not pushdown constraints, result)
--Testcase 649:
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select atan (builtin function, pushdown constraints, explain)
--Testcase 650:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select atan (builtin function, pushdown constraints, result)
--Testcase 651:
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select atan as nest function with agg (pushdown, explain)
--Testcase 652:
EXPLAIN VERBOSE
SELECT sum(value3),atan(sum(value3)) FROM s3 ORDER BY 1;

-- select atan as nest function with agg (pushdown, result)
--Testcase 653:
SELECT sum(value3),atan(sum(value3)) FROM s3 ORDER BY 1;

-- select atan as nest with log2 (pushdown, explain)
--Testcase 654:
EXPLAIN VERBOSE
SELECT atan(log2(value1)),atan(log2(1/value1)) FROM s3;

-- select atan as nest with log2 (pushdown, result)
--Testcase 655:
SELECT * FROM (
SELECT atan(log2(value1)),atan(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select atan with non pushdown func and explicit constant (explain)
--Testcase 656:
EXPLAIN VERBOSE
SELECT atan(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select atan with non pushdown func and explicit constant (result)
--Testcase 657:
SELECT atan(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select atan with order by (explain)
--Testcase 658:
EXPLAIN VERBOSE
SELECT value1, atan(1-value1) FROM s3 ORDER BY atan(1-value1);

-- select atan with order by (result)
--Testcase 659:
SELECT value1, atan(1-value1) FROM s3 ORDER BY atan(1-value1);

-- select atan with order by index (result)
--Testcase 660:
SELECT value1, atan(1-value1) FROM s3 ORDER BY 2,1;

-- select atan with order by index (result)
--Testcase 661:
SELECT value1, atan(1-value1) FROM s3 ORDER BY 1,2;

-- select atan and as
--Testcase 662:
SELECT * FROM (
SELECT atan(value3) as atan1 FROM s3
) as t ORDER BY 1;

-- select atan(*) (stub function, explain)
--Testcase 663:
EXPLAIN VERBOSE
SELECT atan_all() from s3 ORDER BY 1;

-- select atan(*) (stub function, result)
--Testcase 664:
SELECT * FROM (
SELECT atan_all() from s3
) as t ORDER BY 1;

-- select atan(*) (stub function and group by tag only) (explain)
--Testcase 665:
EXPLAIN VERBOSE
SELECT atan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select atan(*) (stub function and group by tag only) (result)
--Testcase 666:
SELECT atan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select atan(*) (stub function, expose data, explain)
--Testcase 667:
EXPLAIN VERBOSE
SELECT (atan_all()::s3).* from s3 ORDER BY 1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 668:
SELECT asin_all(), acos_all(), atan_all() FROM s3 ORDER BY 1;

-- select atan2 (builtin function, explain)
--Testcase 669:
EXPLAIN VERBOSE
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 ORDER BY 1;

-- select atan2 (builtin function, result)
--Testcase 670:
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 ORDER BY 1;

-- select atan2 (builtin function, not pushdown constraints, explain)
--Testcase 671:
EXPLAIN VERBOSE
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select atan2 (builtin function, not pushdown constraints, result)
--Testcase 672:
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select atan2 (builtin function, pushdown constraints, explain)
--Testcase 673:
EXPLAIN VERBOSE
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select atan2 (builtin function, pushdown constraints, result)
--Testcase 674:
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select atan2 as nest function with agg (pushdown, explain)
--Testcase 675:
EXPLAIN VERBOSE
SELECT sum(value3), sum(value4),atan2(sum(value3), sum(value3)) FROM s3 ORDER BY 1;

-- select atan2 as nest function with agg (pushdown, result)
--Testcase 676:
SELECT sum(value3), sum(value4),atan2(sum(value3), sum(value3)) FROM s3 ORDER BY 1;

-- select atan2 as nest with log2 (pushdown, explain)
--Testcase 677:
EXPLAIN VERBOSE
SELECT atan2(log2(value1), log2(value1)),atan2(log2(1/value1), log2(1/value1)) FROM s3;

-- select atan2 as nest with log2 (pushdown, result)
--Testcase 678:
SELECT * FROM (
SELECT atan2(log2(value1), log2(value1)),atan2(log2(1/value1), log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select atan2 with non pushdown func and explicit constant (explain)
--Testcase 679:
EXPLAIN VERBOSE
SELECT atan2(value3, value4), pi(), 4.1 FROM s3 ORDER BY 1;

-- select atan2 with non pushdown func and explicit constant (result)
--Testcase 680:
SELECT atan2(value3, value4), pi(), 4.1 FROM s3 ORDER BY 1;

-- select atan2 with order by (explain)
--Testcase 681:
EXPLAIN VERBOSE
SELECT value1, atan2(1-value1, 1-value2) FROM s3 ORDER BY atan2(1-value1, 1-value2);

-- select atan2 with order by (result)
--Testcase 682:
SELECT value1, atan2(1-value1, 1-value2) FROM s3 ORDER BY atan2(1-value1, 1-value2);

-- select atan2 with order by index (result)
--Testcase 683:
SELECT value1, atan2(1-value1, 1-value2) FROM s3 ORDER BY 2,1;

-- select atan2 with order by index (result)
--Testcase 684:
SELECT value1, atan2(1-value1, 1-value2) FROM s3 ORDER BY 1,2;

-- select atan2 and as
--Testcase 685:
SELECT atan2(value3, value4) as atan21 FROM s3 ORDER BY 1;

-- select atan2(*) (stub function, explain)
--Testcase 686:
EXPLAIN VERBOSE
SELECT atan2_all(value1) from s3 ORDER BY 1;

-- select atan2(*) (stub function, result)
--Testcase 687:
SELECT * FROM (
SELECT atan2_all(value1) from s3
) as t ORDER BY 1;

-- select ceil (builtin function, explain)
--Testcase 688:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 ORDER BY 1;

-- select ceil (builtin function, result)
--Testcase 689:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 ORDER BY 1;

-- select ceil (builtin function, not pushdown constraints, explain)
--Testcase 690:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select ceil (builtin function, not pushdown constraints, result)
--Testcase 691:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select ceil (builtin function, pushdown constraints, explain)
--Testcase 692:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select ceil (builtin function, pushdown constraints, result)
--Testcase 693:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select ceil as nest function with agg (pushdown, explain)
--Testcase 694:
EXPLAIN VERBOSE
SELECT sum(value3),ceil(sum(value3)) FROM s3 ORDER BY 1;

-- select ceil as nest function with agg (pushdown, result)
--Testcase 695:
SELECT sum(value3),ceil(sum(value3)) FROM s3 ORDER BY 1;

-- select ceil as nest with log2 (pushdown, explain)
--Testcase 696:
EXPLAIN VERBOSE
SELECT ceil(log2(value1)),ceil(log2(1/value1)) FROM s3;

-- select ceil as nest with log2 (pushdown, result)
--Testcase 697:
SELECT * FROM (
SELECT ceil(log2(value1)),ceil(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select ceil with non pushdown func and explicit constant (explain)
--Testcase 698:
EXPLAIN VERBOSE
SELECT ceil(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select ceil with non pushdown func and explicit constant (result)
--Testcase 699:
SELECT * FROM (
SELECT ceil(value3), pi(), 4.1 FROM s3
) as t ORDER BY 1;

-- select ceil with order by (explain)
--Testcase 700:
EXPLAIN VERBOSE
SELECT value1, ceil(1-value1) FROM s3 ORDER BY ceil(1-value1);

-- select ceil with order by (result)
--Testcase 701:
SELECT value1, ceil(1-value1) FROM s3 ORDER BY ceil(1-value1);

-- select ceil with order by index (result)
--Testcase 702:
SELECT value1, ceil(1-value1) FROM s3 ORDER BY 2,1;

-- select ceil with order by index (result)
--Testcase 703:
SELECT value1, ceil(1-value1) FROM s3 ORDER BY 1,2;

-- select ceil and as
--Testcase 704:
SELECT * FROM (
SELECT ceil(value3) as ceil1 FROM s3
) as t ORDER BY 1;

-- select ceil(*) (stub function, explain)
--Testcase 705:
EXPLAIN VERBOSE
SELECT ceil_all() from s3 ORDER BY 1;

-- select ceil(*) (stub function, result)
--Testcase 706:
SELECT * FROM (
SELECT ceil_all() from s3
) as t ORDER BY 1;

-- select ceil(*) (stub function and group by tag only) (explain)
--Testcase 707:
EXPLAIN VERBOSE
SELECT ceil_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select ceil(*) (stub function and group by tag only) (result)
--Testcase 708:
SELECT ceil_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select ceil(*) (stub function, expose data, explain)
--Testcase 709:
EXPLAIN VERBOSE
SELECT (ceil_all()::s3).* from s3 ORDER BY 1;

-- select ceil(*) (stub function, expose data, result)
--Testcase 710:
SELECT * FROM (
SELECT (ceil_all()::s3).* from s3
) as t ORDER BY 1;

-- select cos (builtin function, explain)
--Testcase 711:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 ORDER BY 1;

-- select cos (builtin function, result)
--Testcase 712:
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 ORDER BY 1;

-- select cos (builtin function, not pushdown constraints, explain)
--Testcase 713:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select cos (builtin function, not pushdown constraints, result)
--Testcase 714:
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select cos (builtin function, pushdown constraints, explain)
--Testcase 715:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select cos (builtin function, pushdown constraints, result)
--Testcase 716:
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select cos as nest function with agg (pushdown, explain)
--Testcase 717:
EXPLAIN VERBOSE
SELECT sum(value3),cos(sum(value3)) FROM s3 ORDER BY 1;

-- select cos as nest function with agg (pushdown, result)
--Testcase 718:
SELECT sum(value3),cos(sum(value3)) FROM s3 ORDER BY 1;

-- select cos as nest with log2 (pushdown, explain)
--Testcase 719:
EXPLAIN VERBOSE
SELECT cos(log2(value1)),cos(log2(1/value1)) FROM s3;

-- select cos as nest with log2 (pushdown, result)
--Testcase 720:
SELECT * FROM (
SELECT cos(log2(value1)),cos(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select cos with non pushdown func and explicit constant (explain)
--Testcase 721:
EXPLAIN VERBOSE
SELECT cos(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select cos with non pushdown func and explicit constant (result)
--Testcase 722:
SELECT cos(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select cos with order by (explain)
--Testcase 723:
EXPLAIN VERBOSE
SELECT value1, cos(1-value1) FROM s3 ORDER BY cos(1-value1);

-- select cos with order by (result)
--Testcase 724:
SELECT value1, cos(1-value1) FROM s3 ORDER BY cos(1-value1);

-- select cos with order by index (result)
--Testcase 725:
SELECT value1, cos(1-value1) FROM s3 ORDER BY 2,1;

-- select cos with order by index (result)
--Testcase 726:
SELECT value1, cos(1-value1) FROM s3 ORDER BY 1,2;

-- select cos and as
--Testcase 727:
SELECT cos(value3) as cos1 FROM s3 ORDER BY 1;

-- select cos(*) (stub function, explain)
--Testcase 728:
EXPLAIN VERBOSE
SELECT cos_all() from s3 ORDER BY 1;

-- select cos(*) (stub function, result)
--Testcase 729:
SELECT * FROM (
SELECT cos_all() from s3
) as t ORDER BY 1;

-- select cos(*) (stub function and group by tag only) (explain)
--Testcase 730:
EXPLAIN VERBOSE
SELECT cos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select cos(*) (stub function and group by tag only) (result)
--Testcase 731:
SELECT cos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select exp (builtin function, explain)
--Testcase 732:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 ORDER BY 1;

-- select exp (builtin function, result)
--Testcase 733:
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 ORDER BY 1;

-- select exp (builtin function, not pushdown constraints, explain)
--Testcase 734:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select exp (builtin function, not pushdown constraints, result)
--Testcase 735:
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select exp (builtin function, pushdown constraints, explain)
--Testcase 736:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select exp (builtin function, pushdown constraints, result)
--Testcase 737:
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select exp as nest function with agg (pushdown, explain)
--Testcase 738:
EXPLAIN VERBOSE
SELECT sum(value3),exp(sum(value3)) FROM s3 ORDER BY 1;

-- select exp as nest function with agg (pushdown, result)
--Testcase 739:
SELECT sum(value3),exp(sum(value3)) FROM s3 ORDER BY 1;

-- select exp as nest with log2 (pushdown, explain)
--Testcase 740:
EXPLAIN VERBOSE
SELECT exp(log2(value1)),exp(log2(1/value1)) FROM s3;

-- select exp as nest with log2 (pushdown, result)
--Testcase 741:
SELECT * FROM (
SELECT exp(log2(value1)),exp(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select exp with non pushdown func and explicit constant (explain)
--Testcase 742:
EXPLAIN VERBOSE
SELECT exp(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select exp with non pushdown func and explicit constant (result)
--Testcase 743:
SELECT exp(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select exp with order by (explain)
--Testcase 744:
EXPLAIN VERBOSE
SELECT value1, exp(1-value1) FROM s3 ORDER BY exp(1-value1);

-- select exp with order by (result)
--Testcase 745:
SELECT value1, exp(1-value1) FROM s3 ORDER BY exp(1-value1);

-- select exp with order by index (result)
--Testcase 746:
SELECT value1, exp(1-value1) FROM s3 ORDER BY 2,1;

-- select exp with order by index (result)
--Testcase 747:
SELECT value1, exp(1-value1) FROM s3 ORDER BY 1,2;

-- select exp and as
--Testcase 748:
SELECT exp(value3) as exp1 FROM s3 ORDER BY 1;

-- select exp(*) (stub function, explain)
--Testcase 749:
EXPLAIN VERBOSE
SELECT exp_all() from s3 ORDER BY 1;

-- select exp(*) (stub function, result)
--Testcase 750:
SELECT * FROM (
SELECT exp_all() from s3
) as t ORDER BY 1;

-- select exp(*) (stub function and group by tag only) (explain)
--Testcase 751:
EXPLAIN VERBOSE
SELECT exp_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select exp(*) (stub function and group by tag only) (result)
--Testcase 752:
SELECT exp_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 753:
SELECT ceil_all(), cos_all(), exp_all() FROM s3 ORDER BY 1;

-- select floor (builtin function, explain)
--Testcase 754:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 ORDER BY 1;

-- select floor (builtin function, result)
--Testcase 755:
SELECT * FROM (
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3
) as t ORDER BY 1, 2, 3, 4;

-- select floor (builtin function, not pushdown constraints, explain)
--Testcase 756:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select floor (builtin function, not pushdown constraints, result)
--Testcase 757:
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select floor (builtin function, pushdown constraints, explain)
--Testcase 758:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select floor (builtin function, pushdown constraints, result)
--Testcase 759:
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select floor as nest function with agg (pushdown, explain)
--Testcase 760:
EXPLAIN VERBOSE
SELECT sum(value3),floor(sum(value3)) FROM s3 ORDER BY 1;

-- select floor as nest function with agg (pushdown, result)
--Testcase 761:
SELECT sum(value3),floor(sum(value3)) FROM s3 ORDER BY 1;

-- select floor as nest with log2 (pushdown, explain)
--Testcase 762:
EXPLAIN VERBOSE
SELECT floor(log2(value1)),floor(log2(1/value1)) FROM s3;

-- select floor as nest with log2 (pushdown, result)
--Testcase 763:
SELECT * FROM (
SELECT floor(log2(value1)),floor(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select floor with non pushdown func and explicit constant (explain)
--Testcase 764:
EXPLAIN VERBOSE
SELECT floor(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select floor with non pushdown func and explicit constant (result)
--Testcase 765:
SELECT * FROM (
SELECT floor(value3), pi(), 4.1 FROM s3
) as t ORDER BY 1;

-- select floor with order by (explain)
--Testcase 766:
EXPLAIN VERBOSE
SELECT value1, floor(1-value1) FROM s3 ORDER BY floor(1-value1);

-- select floor with order by (result)
--Testcase 767:
SELECT value1, floor(1-value1) FROM s3 ORDER BY floor(1-value1);

-- select floor with order by index (result)
--Testcase 768:
SELECT value1, floor(1-value1) FROM s3 ORDER BY 2,1;

-- select floor with order by index (result)
--Testcase 769:
SELECT value1, floor(1-value1) FROM s3 ORDER BY 1,2;

-- select floor and as
--Testcase 770:
SELECT floor(value3) as floor1 FROM s3 ORDER BY 1;

-- select floor(*) (stub function, explain)
--Testcase 771:
EXPLAIN VERBOSE
SELECT floor_all() from s3 ORDER BY 1;

-- select floor(*) (stub function, result)
--Testcase 772:
SELECT * FROM (
SELECT floor_all() from s3
) as t ORDER BY 1;

-- select floor(*) (stub function and group by tag only) (explain)
--Testcase 773:
EXPLAIN VERBOSE
SELECT floor_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select floor(*) (stub function and group by tag only) (result)
--Testcase 774:
SELECT floor_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select floor(*) (stub function, expose data, explain)
--Testcase 775:
EXPLAIN VERBOSE
SELECT (floor_all()::s3).* from s3 ORDER BY 1;

-- select floor(*) (stub function, expose data, result)
--Testcase 776:
SELECT * FROM (
SELECT (floor_all()::s3).* from s3
) as t ORDER BY 1;

-- select ln (builtin function, explain)
--Testcase 777:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 ORDER BY 1;

-- select ln (builtin function, result)
--Testcase 778:
SELECT * FROM (
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3
) as t ORDER BY 1, 2, 3, 4;

-- select ln (builtin function, not pushdown constraints, explain)
--Testcase 779:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select ln (builtin function, not pushdown constraints, result)
--Testcase 780:
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select ln (builtin function, pushdown constraints, explain)
--Testcase 781:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select ln (builtin function, pushdown constraints, result)
--Testcase 782:
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select ln as nest function with agg (pushdown, explain)
--Testcase 783:
EXPLAIN VERBOSE
SELECT sum(value3),ln(sum(value3)) FROM s3 ORDER BY 1;

-- select ln as nest function with agg (pushdown, result)
--Testcase 784:
SELECT sum(value3),ln(sum(value3)) FROM s3 ORDER BY 1;

-- select ln as nest with log2 (pushdown, explain)
--Testcase 785:
EXPLAIN VERBOSE
SELECT ln(log2(value1)),ln(log2(1/value1)) FROM s3;

-- select ln as nest with log2 (pushdown, result)
--Testcase 786:
SELECT * FROM (
SELECT ln(log2(value1)),ln(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select ln with non pushdown func and explicit constant (explain)
--Testcase 787:
EXPLAIN VERBOSE
SELECT ln(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select ln with non pushdown func and explicit constant (result)
--Testcase 788:
SELECT ln(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select ln with order by (explain)
--Testcase 789:
EXPLAIN VERBOSE
SELECT value1, ln(1-value1) FROM s3 ORDER BY ln(1-value1);

-- select ln with order by (result)
--Testcase 790:
SELECT value1, ln(1-value1) FROM s3 ORDER BY ln(1-value1);

-- select ln with order by index (result)
--Testcase 791:
SELECT value1, ln(1-value1) FROM s3 ORDER BY 2,1;

-- select ln with order by index (result)
--Testcase 792:
SELECT value1, ln(1-value1) FROM s3 ORDER BY 1,2;

-- select ln and as
--Testcase 793:
SELECT ln(value1) as ln1 FROM s3 ORDER BY 1;

-- select ln(*) (stub function, explain)
--Testcase 794:
EXPLAIN VERBOSE
SELECT ln_all() from s3 ORDER BY 1;

-- select ln(*) (stub function, result)
--Testcase 795:
SELECT * FROM (
SELECT ln_all() from s3
) as t ORDER BY 1;

-- select ln(*) (stub function and group by tag only) (explain)
--Testcase 796:
EXPLAIN VERBOSE
SELECT ln_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select ln(*) (stub function and group by tag only) (result)
--Testcase 797:
SELECT ln_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 798:
SELECT ln_all(), floor_all() FROM s3 ORDER BY 1;

-- select pow (builtin function, explain)
--Testcase 799:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 ORDER BY 1;

-- select pow (builtin function, result)
--Testcase 800:
SELECT * FROM (
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3
) as t ORDER BY 1, 2, 3, 4;

-- select pow (builtin function, not pushdown constraints, explain)
--Testcase 801:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select pow (builtin function, not pushdown constraints, result)
--Testcase 802:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select pow (builtin function, pushdown constraints, explain)
--Testcase 803:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select pow (builtin function, pushdown constraints, result)
--Testcase 804:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select pow as nest function with agg (pushdown, explain)
--Testcase 805:
EXPLAIN VERBOSE
SELECT sum(value3),pow(sum(value3), 2) FROM s3 ORDER BY 1;

-- select pow as nest function with agg (pushdown, result)
--Testcase 806:
SELECT sum(value3),pow(sum(value3), 2) FROM s3 ORDER BY 1;

-- select pow as nest with log2 (pushdown, explain)
--Testcase 807:
EXPLAIN VERBOSE
SELECT pow(log2(value1), 2),pow(log2(1/value1), 2) FROM s3;

-- select pow as nest with log2 (pushdown, result)
--Testcase 808:
SELECT * FROM (
SELECT pow(log2(value1), 2),pow(log2(1/value1), 2) FROM s3
) as t ORDER BY 1;

-- select pow with non pushdown func and explicit constant (explain)
--Testcase 809:
EXPLAIN VERBOSE
SELECT pow(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select pow with non pushdown func and explicit constant (result)
--Testcase 810:
SELECT pow(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select pow with order by (explain)
--Testcase 811:
EXPLAIN VERBOSE
SELECT value1, pow(1-value1, 2) FROM s3 ORDER BY pow(1-value1, 2);

-- select pow with order by (result)
--Testcase 812:
SELECT value1, pow(1-value1, 2) FROM s3 ORDER BY pow(1-value1, 2);

-- select pow with order by index (result)
--Testcase 813:
SELECT value1, pow(1-value1, 2) FROM s3 ORDER BY 2,1;

-- select pow with order by index (result)
--Testcase 814:
SELECT value1, pow(1-value1, 2) FROM s3 ORDER BY 1,2;

-- select pow and as
--Testcase 815:
SELECT * FROM (
SELECT pow(value3, 2) as pow1 FROM s3
) as t ORDER BY 1;

-- select pow_all(2) (stub function, explain)
--Testcase 816:
EXPLAIN VERBOSE
SELECT pow_all(2) from s3 ORDER BY 1;

-- select pow_all(2) (stub function, result)
--Testcase 817:
SELECT * FROM (
SELECT pow_all(2) from s3
) as t ORDER BY 1;

-- select pow_all(2) (stub function and group by tag only) (explain)
--Testcase 818:
EXPLAIN VERBOSE
SELECT pow_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select pow_all(2) (stub function and group by tag only) (result)
--Testcase 819:
SELECT pow_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select pow_all(2) (stub function, expose data, explain)
--Testcase 820:
EXPLAIN VERBOSE
SELECT (pow_all(2)::s3).* from s3 ORDER BY 1;

-- select pow_all(2) (stub function, expose data, result)
--Testcase 821:
SELECT * FROM (
SELECT (pow_all(2)::s3).* from s3
) as t ORDER BY 1;

-- select round (builtin function, explain)
--Testcase 822:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 ORDER BY 1;

-- select round (builtin function, result)
--Testcase 823:
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 ORDER BY 1;

-- select round (builtin function, not pushdown constraints, explain)
--Testcase 824:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select round (builtin function, not pushdown constraints, result)
--Testcase 825:
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select round (builtin function, pushdown constraints, explain)
--Testcase 826:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select round (builtin function, pushdown constraints, result)
--Testcase 827:
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select round as nest function with agg (pushdown, explain)
--Testcase 828:
EXPLAIN VERBOSE
SELECT sum(value3),round(sum(value3)) FROM s3 ORDER BY 1;

-- select round as nest function with agg (pushdown, result)
--Testcase 829:
SELECT sum(value3),round(sum(value3)) FROM s3 ORDER BY 1;

-- select round as nest with log2 (pushdown, explain)
--Testcase 830:
EXPLAIN VERBOSE
SELECT round(log2(value1)),round(log2(1/value1)) FROM s3;

-- select round as nest with log2 (pushdown, result)
--Testcase 831:
SELECT * FROM (
SELECT round(log2(value1)),round(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select round with non pushdown func and roundlicit constant (explain)
--Testcase 832:
EXPLAIN VERBOSE
SELECT round(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select round with non pushdown func and roundlicit constant (result)
--Testcase 833:
SELECT round(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select round with order by (explain)
--Testcase 834:
EXPLAIN VERBOSE
SELECT value1, round(1-value1) FROM s3 ORDER BY round(1-value1);

-- select round with order by (result)
--Testcase 835:
SELECT value1, round(1-value1) FROM s3 ORDER BY round(1-value1);

-- select round with order by index (result)
--Testcase 836:
SELECT value1, round(1-value1) FROM s3 ORDER BY 2,1;

-- select round with order by index (result)
--Testcase 837:
SELECT value1, round(1-value1) FROM s3 ORDER BY 1,2;

-- select round and as
--Testcase 838:
SELECT round(value3) as round1 FROM s3 ORDER BY 1;

-- select round(*) (stub function, explain)
--Testcase 839:
EXPLAIN VERBOSE
SELECT round_all() from s3 ORDER BY 1;

-- select round(*) (stub function, result)
--Testcase 840:
SELECT * FROM (
SELECT round_all() from s3
) as t ORDER BY 1;

-- select round(*) (stub function and group by tag only) (explain)
--Testcase 841:
EXPLAIN VERBOSE
SELECT round_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select round(*) (stub function and group by tag only) (result)
--Testcase 842:
SELECT round_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select round(*) (stub function, expose data, explain)
--Testcase 843:
EXPLAIN VERBOSE
SELECT (round_all()::s3).* from s3 ORDER BY 1;

-- select round(*) (stub function, expose data, result)
--Testcase 844:
SELECT * FROM (
SELECT (round_all()::s3).* from s3
) as t ORDER BY 1;

-- select sin (builtin function, explain)
--Testcase 845:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 ORDER BY 1;

-- select sin (builtin function, result)
--Testcase 846:
SELECT * FROM (
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3
) as t ORDER BY 1, 2, 3, 4;

-- select sin (builtin function, not pushdown constraints, explain)
--Testcase 847:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select sin (builtin function, not pushdown constraints, result)
--Testcase 848:
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select sin (builtin function, pushdown constraints, explain)
--Testcase 849:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select sin (builtin function, pushdown constraints, result)
--Testcase 850:
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select sin as nest function with agg (pushdown, explain)
--Testcase 851:
EXPLAIN VERBOSE
SELECT sum(value3),sin(sum(value3)) FROM s3 ORDER BY 1;

-- select sin as nest function with agg (pushdown, result)
--Testcase 852:
SELECT sum(value3),sin(sum(value3)) FROM s3 ORDER BY 1;

-- select sin as nest with log2 (pushdown, explain)
--Testcase 853:
EXPLAIN VERBOSE
SELECT sin(log2(value1)),sin(log2(1/value1)) FROM s3;

-- select sin as nest with log2 (pushdown, result)
--Testcase 854:
SELECT * FROM (
SELECT sin(log2(value1)),sin(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select sin with non pushdown func and explicit constant (explain)
--Testcase 855:
EXPLAIN VERBOSE
SELECT sin(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select sin with non pushdown func and explicit constant (result)
--Testcase 856:
SELECT sin(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select sin with order by (explain)
--Testcase 857:
EXPLAIN VERBOSE
SELECT value1, sin(1-value1) FROM s3 ORDER BY sin(1-value1);

-- select sin with order by (result)
--Testcase 858:
SELECT value1, sin(1-value1) FROM s3 ORDER BY sin(1-value1);

-- select sin with order by index (result)
--Testcase 859:
SELECT value1, sin(1-value1) FROM s3 ORDER BY 2,1;

-- select sin with order by index (result)
--Testcase 860:
SELECT value1, sin(1-value1) FROM s3 ORDER BY 1,2;

-- select sin and as
--Testcase 861:
SELECT sin(value3) as sin1 FROM s3 ORDER BY 1;

-- select sin(*) (stub function, explain)
--Testcase 862:
EXPLAIN VERBOSE
SELECT sin_all() from s3 ORDER BY 1;

-- select sin(*) (stub function, result)
--Testcase 863:
SELECT * FROM (
SELECT sin_all() from s3
) as t ORDER BY 1;

-- select sin(*) (stub function and group by tag only) (explain)
--Testcase 864:
EXPLAIN VERBOSE
SELECT sin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select sin(*) (stub function and group by tag only) (result)
--Testcase 865:
SELECT sin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select tan (builtin function, explain)
--Testcase 866:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 ORDER BY 1;

-- select tan (builtin function, result)
--Testcase 867:
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 ORDER BY 1;

-- select tan (builtin function, not pushdown constraints, explain)
--Testcase 868:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select tan (builtin function, not pushdown constraints, result)
--Testcase 869:
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select tan (builtin function, pushdown constraints, explain)
--Testcase 870:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select tan (builtin function, pushdown constraints, result)
--Testcase 871:
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select tan as nest function with agg (pushdown, explain)
--Testcase 872:
EXPLAIN VERBOSE
SELECT sum(value3),tan(sum(value3)) FROM s3 ORDER BY 1;

-- select tan as nest function with agg (pushdown, result)
--Testcase 873:
SELECT sum(value3),tan(sum(value3)) FROM s3 ORDER BY 1;

-- select tan as nest with log2 (pushdown, explain)
--Testcase 874:
EXPLAIN VERBOSE
SELECT tan(log2(value1)),tan(log2(1/value1)) FROM s3;

-- select tan as nest with log2 (pushdown, result)
--Testcase 875:
SELECT * FROM (
SELECT tan(log2(value1)),tan(log2(1/value1)) FROM s3
) as t ORDER BY 1, 2;

-- select tan with non pushdown func and tanlicit constant (explain)
--Testcase 876:
EXPLAIN VERBOSE
SELECT tan(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select tan with non pushdown func and tanlicit constant (result)
--Testcase 877:
SELECT tan(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select tan with order by (explain)
--Testcase 878:
EXPLAIN VERBOSE
SELECT value1, tan(1-value1) FROM s3 ORDER BY tan(1-value1);

-- select tan with order by (result)
--Testcase 879:
SELECT value1, tan(1-value1) FROM s3 ORDER BY tan(1-value1);

-- select tan with order by index (result)
--Testcase 880:
SELECT value1, tan(1-value1) FROM s3 ORDER BY 2,1;

-- select tan with order by index (result)
--Testcase 881:
SELECT value1, tan(1-value1) FROM s3 ORDER BY 1,2;

-- select tan and as
--Testcase 882:
SELECT tan(value3) as tan1 FROM s3 ORDER BY 1;

-- select tan(*) (stub function, explain)
--Testcase 883:
EXPLAIN VERBOSE
SELECT tan_all() from s3 ORDER BY 1;

-- select tan(*) (stub function, result)
--Testcase 884:
SELECT * FROM (
SELECT tan_all() from s3
) as t ORDER BY 1;

-- select tan(*) (stub function and group by tag only) (explain)
--Testcase 885:
EXPLAIN VERBOSE
SELECT tan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select tan(*) (stub function and group by tag only) (result)
--Testcase 886:
SELECT tan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 887:
SELECT sin_all(), round_all(), tan_all() FROM s3 ORDER BY 1;

-- select predictors function holt_winters() (explain)
--Testcase 888:
EXPLAIN VERBOSE
SELECT holt_winters(min(value1), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s') ORDER BY 1;

-- select predictors function holt_winters() (result)
--Testcase 889:
SELECT holt_winters(min(value1), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s') ORDER BY 1;

-- select predictors function holt_winters_with_fit() (explain)
--Testcase 890:
EXPLAIN VERBOSE
SELECT holt_winters_with_fit(min(value1), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s') ORDER BY 1;

-- select predictors function holt_winters_with_fit() (result)
--Testcase 891:
SELECT holt_winters_with_fit(min(value1), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s') ORDER BY 1;

-- select count(*) function of InfluxDB (stub agg function, explain)
--Testcase 892:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 ORDER BY 1;

-- select count(*) function of InfluxDB (stub agg function, result)
--Testcase 893:
SELECT influx_count_all(*) FROM s3 ORDER BY 1;

-- select count(*) function of InfluxDB (stub agg function and group by influx_time() and tag) (explain)
--Testcase 894:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select count(*) function of InfluxDB (stub agg function and group by influx_time() and tag) (result)
--Testcase 895:
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select count(*) function of InfluxDB (stub agg function and group by tag only) (explain)
--Testcase 896:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select count(*) function of InfluxDB (stub agg function and group by tag only) (result)
--Testcase 897:
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select count(*) function of InfluxDB over join query (explain)
--Testcase 898:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select count(*) function of InfluxDB over join query (result, stub call error)
--Testcase 899:
SELECT influx_count_all(*) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select distinct (stub agg function, explain)
--Testcase 900:
EXPLAIN VERBOSE
SELECT influx_distinct(value1) FROM s3 ORDER BY 1;

-- select distinct (stub agg function, result)
--Testcase 901:
SELECT influx_distinct(value1) FROM s3 ORDER BY 1;

-- select distinct (stub agg function and group by influx_time() and tag) (explain)
--Testcase 902:
EXPLAIN VERBOSE
SELECT influx_distinct(value1), influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select distinct (stub agg function and group by influx_time() and tag) (result)
--Testcase 903:
SELECT influx_distinct(value1), influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select distinct (stub agg function and group by tag only) (explain)
--Testcase 904:
EXPLAIN VERBOSE
SELECT influx_distinct(value2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select distinct (stub agg function and group by tag only) (result)
--Testcase 905:
SELECT influx_distinct(value2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select distinct over join query (explain)
--Testcase 906:
EXPLAIN VERBOSE
SELECT influx_distinct(t1.value2) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select distinct over join query (result, stub call error)
--Testcase 907:
SELECT influx_distinct(t1.value2) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select distinct with having (explain)
--Testcase 908:
EXPLAIN VERBOSE
SELECT influx_distinct(value2) FROM s3 HAVING influx_distinct(value2) > 100 ORDER BY 1;

-- select distinct with having (result, not pushdown, stub call error)
--Testcase 909:
SELECT influx_distinct(value2) FROM s3 HAVING influx_distinct(value2) > 100 ORDER BY 1;

--Drop all foreign tables
--Testcase 910:
DROP FOREIGN TABLE s3__influxdb_svr__0;
--Testcase 911:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 912:
DROP SERVER influxdb_svr;
--Testcase 913:
DROP EXTENSION influxdb_fdw;

--Testcase 914:
DROP FOREIGN TABLE s3__pgspider_svr__0;
--Testcase 915:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_svr;
--Testcase 916:
DROP SERVER pgspider_svr;
--Testcase 917:
DROP EXTENSION pgspider_fdw;

--Testcase 918:
DROP FOREIGN TABLE s3;
--Testcase 919:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_core_svr;
--Testcase 920:
DROP SERVER pgspider_core_svr;
--Testcase 921:
DROP EXTENSION pgspider_core_fdw;
