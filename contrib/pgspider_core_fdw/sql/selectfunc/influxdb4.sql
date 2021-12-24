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
-- Data source: influxdb

--Testcase 6:
CREATE FOREIGN TABLE s3 (time timestamp with time zone, tag1 text, value1 float8, value2 bigint, value3 float8, value4 bigint, __spd_url text) SERVER pgspider_core_svr;
--Testcase 7:
CREATE EXTENSION pgspider_fdw;
--Testcase 8:
CREATE SERVER pgspider_svr1 FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (host '127.0.0.1', port '5433', dbname 'postgres');
--Testcase 9:
CREATE USER MAPPING FOR CURRENT_USER SERVER pgspider_svr1;
--Testcase 10:
CREATE FOREIGN TABLE s3__pgspider_svr1__0 (time timestamp with time zone, tag1 text, value1 float8, value2 bigint, value3 float8, value4 bigint, __spd_url text) SERVER pgspider_svr1 OPTIONS (table_name 's31influx');

--Testcase 11:
CREATE SERVER pgspider_svr2 FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (host '127.0.0.1', port '5434', dbname 'postgres');
--Testcase 12:
CREATE USER MAPPING FOR CURRENT_USER SERVER pgspider_svr2;
--Testcase 13:
CREATE FOREIGN TABLE s3__pgspider_svr2__0 (time timestamp with time zone, tag1 text, value1 float8, value2 bigint, value3 float8, value4 bigint, __spd_url text) SERVER pgspider_svr2 OPTIONS (table_name 's32influx');

-- s3 (value1,3 as float8, value2,4 as bigint)
--Testcase 14:
\d s3;
--Testcase 15:
SELECT * FROM s3 ORDER BY 1,2,3,4,5,6,7;

-- select float8() (not pushdown, remove float8, explain)
--Testcase 16:
EXPLAIN VERBOSE
SELECT float8(value1), float8(value2), float8(value3), float8(value4) FROM s3 ORDER BY 1,2,3,4;

-- select float8() (not pushdown, remove float8, result)
--Testcase 17:
SELECT * FROM (
SELECT float8(value1), float8(value2), float8(value3), float8(value4) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select sqrt (builtin function, explain)
--Testcase 18:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2) FROM s3 ORDER BY 1,2;

-- select sqrt (buitin function, result)
--Testcase 19:
SELECT * FROM (
SELECT sqrt(value1), sqrt(value2) FROM s3
) AS t ORDER BY 1,2;

-- select sqrt (builtin function, not pushdown constraints, explain)
--Testcase 20:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1,2;

-- select sqrt (builtin function, not pushdown constraints, result)
--Testcase 21:
SELECT * FROM (
SELECT sqrt(value1), sqrt(value2) FROM s3 WHERE to_hex(value2) != '64'
) AS t ORDER BY 1,2;

-- select sqrt (builtin function, pushdown constraints, explain)
--Testcase 22:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2) FROM s3 WHERE value2 != 200 ORDER BY 1,2;

-- select sqrt (builtin function, pushdown constraints, result)
--Testcase 23:
SELECT * FROM (
SELECT sqrt(value1), sqrt(value2) FROM s3 WHERE value2 != 200
) AS t ORDER BY 1,2;

-- select sqrt(*) (stub function, explain)
--Testcase 24:
EXPLAIN VERBOSE
SELECT sqrt_all() from s3 ORDER BY 1;

-- select sqrt(*) (stub function, result)
--Testcase 25:
SELECT * FROM (
SELECT sqrt_all() from s3
) AS t ORDER BY 1;

-- select sqrt(*) (stub function and group by tag only) (explain)
--Testcase 26:
EXPLAIN VERBOSE
SELECT sqrt_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select sqrt(*) (stub function and group by tag only) (result)
--Testcase 27:
SELECT sqrt_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select abs (builtin function, explain)
--Testcase 28:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 ORDER BY 1,2,3,4;

-- ABS() returns negative values if integer (https://github.com/influxdata/influxdb/issues/10261)
-- select abs (buitin function, result)
--Testcase 29:
SELECT * FROM (
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select abs (builtin function, not pushdown constraints, explain)
--Testcase 30:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1,2,3,4;

-- select abs (builtin function, not pushdown constraints, result)
--Testcase 31:
SELECT * FROM (
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64'
) AS t ORDER BY 1,2,3,4;

-- select abs (builtin function, pushdown constraints, explain)
--Testcase 32:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200 ORDER BY 1,2,3,4;

-- select abs (builtin function, pushdown constraints, result)
--Testcase 33:
SELECT * FROM (
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200
) AS t ORDER BY 1,2,3,4;

-- select log (builtin function, need to swap arguments, numeric cast, explain)
-- log_<base>(v) : postgresql (base, v), influxdb (v, base)
--Testcase 34:
EXPLAIN VERBOSE
SELECT log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1 ORDER BY 1;

-- select log (builtin function, need to swap arguments, numeric cast, result)
--Testcase 35:
SELECT * FROM (
SELECT log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1
) AS t ORDER BY 1;

-- select log (builtin function, need to swap arguments, float8, explain)
--Testcase 36:
EXPLAIN VERBOSE
SELECT log(value1::numeric, 0.1) FROM s3 WHERE value1 != 1 ORDER BY 1;

-- select log (builtin function, need to swap arguments, float8, result)
--Testcase 37:
SELECT * FROM (
SELECT log(value1::numeric, 0.1) FROM s3 WHERE value1 != 1
) AS t ORDER BY 1;

-- select log (builtin function, need to swap arguments, bigint, explain)
--Testcase 38:
EXPLAIN VERBOSE
SELECT log(value2::numeric, 3) FROM s3 WHERE value1 != 1 ORDER BY 1;

-- select log (builtin function, need to swap arguments, bigint, result)
--Testcase 39:
SELECT * FROM (
SELECT log(value2::numeric, 3) FROM s3 WHERE value1 != 1
) AS t ORDER BY 1;

-- select log (builtin function, need to swap arguments, mix type, explain)
--Testcase 40:
EXPLAIN VERBOSE
SELECT log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1 ORDER BY 1;

-- select log (builtin function, need to swap arguments, mix type, result)
--Testcase 41:
SELECT * FROM (
SELECT log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1
) AS t ORDER BY 1;

-- select log(*) (stub function, explain)
--Testcase 42:
EXPLAIN VERBOSE
SELECT log_all(50) FROM s3 ORDER BY 1;

-- select log(*) (stub function, result)
--Testcase 43:
SELECT * FROM (
SELECT log_all(50) FROM s3
) AS t ORDER BY 1;

-- select log(*) (stub function, explain)
--Testcase 44:
EXPLAIN VERBOSE
SELECT log_all(70.5) FROM s3 ORDER BY 1;

-- select log(*) (stub function, result)
--Testcase 45:
SELECT * FROM (
SELECT log_all(70.5) FROM s3
) AS t ORDER BY 1;

-- select log(*) (stub function and group by tag only) (explain)
--Testcase 46:
EXPLAIN VERBOSE
SELECT log_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select log(*) (stub function and group by tag only) (result)
--Testcase 47:
SELECT log_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--SELECT ln_all(),log10_all(),log_all(50) FROM s3 ORDER BY 1;

-- select log2 (stub function, explain)
--Testcase 48:
EXPLAIN VERBOSE
SELECT log2(value1),log2(value2) FROM s3;

-- select log2 (stub function, result)
--Testcase 49:
SELECT * FROM (
SELECT log2(value1),log2(value2) FROM s3
) AS t ORDER BY 1,2;

-- select log2(*) (stub function, explain)
--Testcase 50:
EXPLAIN VERBOSE
SELECT log2_all() from s3 ORDER BY 1;

-- select log2(*) (stub function, result)
--Testcase 51:
SELECT * FROM (
SELECT log2_all() from s3
) AS t ORDER BY 1;

-- select log2(*) (stub function and group by tag only) (explain)
--Testcase 52:
EXPLAIN VERBOSE
SELECT log2_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select log2(*) (stub function and group by tag only) (result)
--Testcase 53:
SELECT log2_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select log10 (stub function, explain)
--Testcase 54:
EXPLAIN VERBOSE
SELECT log10(value1), log10(value2) FROM s3 ORDER BY 1, 2;

-- select log10 (stub function, result)
--Testcase 55:
SELECT * FROM (
SELECT log10(value1), log10(value2) FROM s3
) AS t ORDER BY 1, 2;

-- select log10(*) (stub function, explain)
--Testcase 56:
EXPLAIN VERBOSE
SELECT log10_all() from s3 ORDER BY 1;

-- select log10(*) (stub function, result)
--Testcase 57:
SELECT * FROM (
SELECT log10_all() from s3
) AS t ORDER BY 1;

-- select log10(*) (stub function and group by tag only) (explain)
--Testcase 58:
EXPLAIN VERBOSE
SELECT log10_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select log10(*) (stub function and group by tag only) (result)
--Testcase 59:
SELECT log10_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--SELECT log2_all(), log10_all() FROM s3 ORDER BY 1;

-- select spread (stub agg function, explain)
--Testcase 60:
EXPLAIN VERBOSE
SELECT spread(value1),spread(value2),spread(value3),spread(value4) FROM s3 ORDER BY 1;

-- select spread (stub agg function, result)
--Testcase 61:
SELECT * FROM (
SELECT spread(value1),spread(value2),spread(value3),spread(value4) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select spread (stub agg function, raise exception if not expected type)
--Testcase 62:
SELECT * FROM (
SELECT spread(value1::numeric),spread(value2::numeric),spread(value3::numeric),spread(value4::numeric) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select abs as nest function with agg (pushdown, explain)
--Testcase 63:
EXPLAIN VERBOSE
SELECT sum(value3),abs(sum(value3)) FROM s3 ORDER BY 1;

-- select abs as nest function with agg (pushdown, result)
--Testcase 64:
SELECT * FROM (
SELECT sum(value3),abs(sum(value3)) FROM s3
) AS t ORDER BY 1,2;

-- select abs as nest with log2 (pushdown, explain)
--Testcase 65:
EXPLAIN VERBOSE
SELECT abs(log2(value1)),abs(log2(1/value1)) FROM s3;

-- select abs as nest with log2 (pushdown, result)
--Testcase 66:
SELECT * FROM (
SELECT abs(log2(value1)),abs(log2(1/value1)) FROM s3
) AS t ORDER BY 1,2;

-- select abs with non pushdown func and explicit constant (explain)
--Testcase 67:
EXPLAIN VERBOSE
SELECT abs(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select abs with non pushdown func and explicit constant (result)
--Testcase 68:
SELECT * FROM (
SELECT abs(value3), pi(), 4.1 FROM s3
) AS t ORDER BY 1,2,3;

-- select sqrt as nest function with agg and explicit constant (pushdown, explain)
--Testcase 69:
EXPLAIN VERBOSE
SELECT sqrt(count(value1)), pi(), 4.1 FROM s3 ORDER BY 1;

-- select sqrt as nest function with agg and explicit constant (pushdown, result)
--Testcase 70:
SELECT * FROM (
SELECT sqrt(count(value1)), pi(), 4.1 FROM s3
) AS t ORDER BY 1,2,3;

-- select sqrt as nest function with agg and explicit constant and tag (error, explain)
--Testcase 71:
EXPLAIN VERBOSE
SELECT sqrt(count(value1)), pi(), 4.1, tag1 FROM s3 ORDER BY 1;

-- select spread (stub agg function and group by influx_time() and tag) (explain)
--Testcase 72:
EXPLAIN VERBOSE
SELECT spread("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select spread (stub agg function and group by influx_time() and tag) (result)
--Testcase 73:
SELECT * FROM (
SELECT spread("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1
) AS t ORDER BY 1,2,3;

-- select spread (stub agg function and group by tag only) (result)
--Testcase 74:
SELECT * FROM (
SELECT tag1,spread("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1
) AS t ORDER BY 1,2;

-- select spread (stub agg function and other aggs) (result)
--Testcase 75:
SELECT sum("value1"),spread("value1"),count("value1") FROM s3 ORDER BY 1;

-- select abs with order by (explain)
--Testcase 76:
EXPLAIN VERBOSE
SELECT value1, abs(1-value1) FROM s3 ORDER BY abs(1-value1);

-- select abs with order by (result)
--Testcase 77:
SELECT value1, abs(1-value1) FROM s3 ORDER BY abs(1-value1);

-- select abs with order by index (result)
--Testcase 78:
SELECT value1, abs(1-value1) FROM s3 ORDER BY 2,1;

-- select abs with order by index (result)
--Testcase 79:
SELECT value1, abs(1-value1) FROM s3 ORDER BY 1,2;

-- select abs and as
--Testcase 80:
SELECT * FROM (
SELECT abs(value3) as abs1 FROM s3
) AS t ORDER BY 1;

-- select abs(*) (stub function, explain)
--Testcase 81:
EXPLAIN VERBOSE
SELECT abs_all() from s3 ORDER BY 1;

-- select abs(*) (stub function, result)
--Testcase 82:
SELECT * FROM (
SELECT abs_all() from s3
) AS t ORDER BY 1;

-- select abs(*) (stub function and group by tag only) (explain)
--Testcase 83:
EXPLAIN VERBOSE
SELECT abs_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select abs(*) (stub function and group by tag only) (result)
--Testcase 84:
SELECT abs_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select abs(*) (stub function, expose data, explain)
--Testcase 85:
EXPLAIN VERBOSE
SELECT (abs_all()::s3).* from s3 ORDER BY 1;

-- select abs(*) (stub function, expose data, result)
--Testcase 86:
SELECT * FROM (
SELECT (abs_all()::s3).* from s3
) AS t ORDER BY 1;

-- select spread over join query (explain)
--Testcase 87:
EXPLAIN VERBOSE
SELECT spread(t1.value1), spread(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select spread over join query (result, stub call error)
--Testcase 88:
SELECT spread(t1.value1), spread(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select spread with having (explain)
--Testcase 89:
EXPLAIN VERBOSE
SELECT spread(value1) FROM s3 HAVING spread(value1) > 100 ORDER BY 1;

-- select spread with having (result, not pushdown, stub call error)
--Testcase 90:
SELECT spread(value1) FROM s3 HAVING spread(value1) > 100 ORDER BY 1;

-- select spread(*) (stub agg function, explain)
--Testcase 91:
EXPLAIN VERBOSE
SELECT spread_all(*) from s3 ORDER BY 1;

-- select spread(*) (stub agg function, result)
--Testcase 92:
SELECT spread_all(*) from s3 ORDER BY 1;

-- select spread(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 93:
EXPLAIN VERBOSE
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select spread(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 94:
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select spread(*) (stub agg function and group by tag only) (explain)
--Testcase 95:
EXPLAIN VERBOSE
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select spread(*) (stub agg function and group by tag only) (result)
--Testcase 96:
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select spread(*) (stub agg function, expose data, explain)
--Testcase 97:
EXPLAIN VERBOSE
SELECT (spread_all(*)::s3).* from s3 ORDER BY 1;

-- select spread(*) (stub agg function, expose data, result)
--Testcase 98:
SELECT (spread_all(*)::s3).* from s3 ORDER BY 1;

-- select spread(regex) (stub agg function, explain)
--Testcase 99:
EXPLAIN VERBOSE
SELECT spread('/value[1,4]/') from s3 ORDER BY 1;

-- select spread(regex) (stub agg function, result)
--Testcase 100:
SELECT spread('/value[1,4]/') from s3 ORDER BY 1;

-- select spread(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 101:
EXPLAIN VERBOSE
SELECT spread('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select spread(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 102:
SELECT spread('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select spread(regex) (stub agg function and group by tag only) (explain)
--Testcase 103:
EXPLAIN VERBOSE
SELECT spread('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select spread(regex) (stub agg function and group by tag only) (result)
--Testcase 104:
SELECT spread('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select spread(regex) (stub agg function, expose data, explain)
--Testcase 105:
EXPLAIN VERBOSE
SELECT (spread('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select spread(regex) (stub agg function, expose data, result)
--Testcase 106:
SELECT (spread('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select abs with arithmetic and tag in the middle (explain)
--Testcase 107:
EXPLAIN VERBOSE
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3 ORDER BY 1;

-- select abs with arithmetic and tag in the middle (result)
--Testcase 108:
SELECT * FROM (
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3
) AS t ORDER BY 1,2,3,4;

-- select with order by limit (explain)
--Testcase 109:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1;

-- select with order by limit (result)
--Testcase 110:
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1;

-- select mixing with non pushdown func (all not pushdown, explain)
--Testcase 111:
EXPLAIN VERBOSE
SELECT abs(value1), sqrt(value2), upper(tag1) FROM s3 ORDER BY 1;

-- select mixing with non pushdown func (result)
--Testcase 112:
SELECT * FROM (
SELECT abs(value1), sqrt(value2), upper(tag1) FROM s3
) AS t ORDER BY 1,2,3;

-- nested function in where clause (explain)
--Testcase 113:
EXPLAIN VERBOSE
SELECT sqrt(abs(value3)),min(value1) FROM s3 GROUP BY value3 HAVING sqrt(abs(value3)) > 0 ORDER BY 1,2;

-- nested function in where clause (result)
--Testcase 114:
SELECT sqrt(abs(value3)),min(value1) FROM s3 GROUP BY value3 HAVING sqrt(abs(value3)) > 0 ORDER BY 1,2;

--Testcase 115:
EXPLAIN VERBOSE
SELECT first(time, value1), first(time, value2), first(time, value3), first(time, value4) FROM s3 ORDER BY 1;

--Testcase 116:
SELECT first(time, value1), first(time, value2), first(time, value3), first(time, value4) FROM s3 ORDER BY 1;

-- select first(*) (stub agg function, explain)
--Testcase 117:
EXPLAIN VERBOSE
SELECT first_all(*) from s3 ORDER BY 1;

-- select first(*) (stub agg function, result)
--Testcase 118:
SELECT * FROM (
SELECT first_all(*) from s3
) AS t ORDER BY 1;

-- select first(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 119:
EXPLAIN VERBOSE
SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select first(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 120:
SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- -- select first(*) (stub agg function and group by tag only) (explain)
-- -- EXPLAIN VERBOSE
-- SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- -- select first(*) (stub agg function and group by tag only) (result)
-- -- SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select first(*) (stub agg function, expose data, explain)
--Testcase 121:
EXPLAIN VERBOSE
SELECT (first_all(*)::s3).* from s3 ORDER BY 1;

-- select first(*) (stub agg function, expose data, result)
--Testcase 122:
SELECT * FROM (
SELECT (first_all(*)::s3).* from s3
) AS t ORDER BY 1;

-- select first(regex) (stub function, explain)
--Testcase 123:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/') from s3 ORDER BY 1;

-- select first(regex) (stub function, explain)
--Testcase 124:
SELECT first('/value[1,4]/') from s3 ORDER BY 1;

-- select multiple regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 125:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/'), first('/^v.*/') from s3 ORDER BY 1;

-- select multiple regex functions (do not push down, raise warning and stub error) (result)
--Testcase 126:
SELECT first('/value[1,4]/'), first('/^v.*/') from s3 ORDER BY 1;

-- select first(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 127:
EXPLAIN VERBOSE
SELECT first('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select first(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 128:
SELECT first('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- -- select first(regex) (stub agg function and group by tag only) (explain)
-- -- EXPLAIN VERBOSE
-- SELECT first('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- -- select first(regex) (stub agg function and group by tag only) (result)
-- -- SELECT first('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select first(regex) (stub agg function, expose data, explain)
--Testcase 129:
EXPLAIN VERBOSE
SELECT (first('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select first(regex) (stub agg function, expose data, result)
--Testcase 130:
SELECT * FROM (
SELECT (first('/value[1,4]/')::s3).* from s3
) AS t ORDER BY 1;

--Testcase 131:
EXPLAIN VERBOSE
SELECT last(time, value1), last(time, value2), last(time, value3), last(time, value4) FROM s3 ORDER BY 1;

--Testcase 132:
SELECT last(time, value1), last(time, value2), last(time, value3), last(time, value4) FROM s3 ORDER BY 1;

-- select last(*) (stub agg function, explain)
--Testcase 133:
EXPLAIN VERBOSE
SELECT last_all(*) from s3 ORDER BY 1;

-- select last(*) (stub agg function, result)
--Testcase 134:
SELECT * FROM (
SELECT last_all(*) from s3
) AS t ORDER BY 1;

-- select last(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 135:
EXPLAIN VERBOSE
SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select last(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 136:
SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- -- select last(*) (stub agg function and group by tag only) (explain)
-- -- EXPLAIN VERBOSE
-- SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- -- select last(*) (stub agg function and group by tag only) (result)
-- -- SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select last(*) (stub agg function, expose data, explain)
--Testcase 137:
EXPLAIN VERBOSE
SELECT (last_all(*)::s3).* from s3 ORDER BY 1;

-- select last(*) (stub agg function, expose data, result)
--Testcase 138:
SELECT * FROM (
SELECT (last_all(*)::s3).* from s3
) AS t ORDER BY 1;

-- select last(regex) (stub function, explain)
--Testcase 139:
EXPLAIN VERBOSE
SELECT last('/value[1,4]/') from s3 ORDER BY 1;

-- select last(regex) (stub function, result)
--Testcase 140:
SELECT last('/value[1,4]/') from s3 ORDER BY 1;

-- select multiple regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 141:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/'), first('/^v.*/') from s3 ORDER BY 1;

-- select multiple regex functions (do not push down, raise warning and stub error) (result)
--Testcase 142:
SELECT first('/value[1,4]/'), first('/^v.*/') from s3 ORDER BY 1;

-- select last(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 143:
EXPLAIN VERBOSE
SELECT last('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select last(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 144:
SELECT last('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- -- select last(regex) (stub agg function and group by tag only) (explain)
-- -- EXPLAIN VERBOSE
-- SELECT last('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- -- select last(regex) (stub agg function and group by tag only) (result)
-- -- SELECT last('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select last(regex) (stub agg function, expose data, explain)
--Testcase 145:
EXPLAIN VERBOSE
SELECT (last('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select last(regex) (stub agg function, expose data, result)
--Testcase 146:
SELECT * FROM (
SELECT (last('/value[1,4]/')::s3).* from s3
) AS t ORDER BY 1;

--Testcase 147:
EXPLAIN VERBOSE
SELECT sample(value2, 3) FROM s3 WHERE value2 < 200 ORDER BY 1;
--Testcase 148:
SELECT sample(value2, 3) FROM s3 WHERE value2 < 200 ORDER BY 1;

--Testcase 149:
EXPLAIN VERBOSE
SELECT sample(value2, 1) FROM s3 WHERE time >= to_timestamp(0) AND time <= to_timestamp(5) GROUP BY influx_time(time, interval '3s') ORDER BY 1;

--Testcase 150:
SELECT sample(value2, 1) FROM s3 WHERE time >= to_timestamp(0) AND time <= to_timestamp(5) GROUP BY influx_time(time, interval '3s') ORDER BY 1;

-- select sample(*, int) (stub agg function, explain)
--Testcase 151:
EXPLAIN VERBOSE
SELECT sample_all(50) from s3 ORDER BY 1;

-- select sample(*, int) (stub agg function, result)
--Testcase 152:
SELECT * FROM (
SELECT sample_all(50) from s3
) AS t ORDER BY 1;

-- select sample(*, int) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 153:
EXPLAIN VERBOSE
SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select sample(*, int) (stub agg function and group by influx_time() and tag) (result)
--Testcase 154:
SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- -- select sample(*, int) (stub agg function and group by tag only) (explain)
-- -- EXPLAIN VERBOSE
-- SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- -- select sample(*, int) (stub agg function and group by tag only) (result)
-- -- SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select sample(*, int) (stub agg function, expose data, explain)
--Testcase 155:
EXPLAIN VERBOSE
SELECT (sample_all(50)::s3).* from s3 ORDER BY 1;

-- select sample(*, int) (stub agg function, expose data, result)
--Testcase 156:
SELECT * FROM (
SELECT (sample_all(50)::s3).* from s3
) AS t ORDER BY 1;

-- select sample(regex) (stub agg function, explain)
--Testcase 157:
EXPLAIN VERBOSE
SELECT sample('/value[1,4]/', 50) from s3 ORDER BY 1;

-- select sample(regex) (stub agg function, result)
--Testcase 158:
SELECT sample('/value[1,4]/', 50) from s3 ORDER BY 1;

-- select sample(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 159:
EXPLAIN VERBOSE
SELECT sample('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select sample(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 160:
SELECT sample('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- -- select sample(regex) (stub agg function and group by tag only) (explain)
-- -- EXPLAIN VERBOSE
-- SELECT sample('/value[1,4]/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- -- select sample(regex) (stub agg function and group by tag only) (result)
-- -- SELECT sample('/value[1,4]/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select sample(regex) (stub agg function, expose data, explain)
--Testcase 161:
EXPLAIN VERBOSE
SELECT (sample('/value[1,4]/', 50)::s3).* from s3 ORDER BY 1;

-- select sample(regex) (stub agg function, expose data, result)
--Testcase 162:
SELECT * FROM (
SELECT (sample('/value[1,4]/', 50)::s3).* from s3
) AS t ORDER BY 1;

--Testcase 163:
EXPLAIN VERBOSE
SELECT cumulative_sum(value1),cumulative_sum(value2),cumulative_sum(value3),cumulative_sum(value4) FROM s3 ORDER BY 1, 2, 3, 4;

--Testcase 164:
SELECT cumulative_sum(value1),cumulative_sum(value2),cumulative_sum(value3),cumulative_sum(value4) FROM s3 ORDER BY 1, 2, 3, 4;

-- select cumulative_sum(*) (stub function, explain)
--Testcase 165:
EXPLAIN VERBOSE
SELECT cumulative_sum_all() from s3 ORDER BY 1;

-- select cumulative_sum(*) (stub function, result)
--Testcase 166:
SELECT * FROM (
SELECT cumulative_sum_all() from s3
) AS t ORDER BY 1;

-- select cumulative_sum(regex) (stub function, explain)
--Testcase 167:
EXPLAIN VERBOSE
SELECT cumulative_sum('/value[1,4]/') from s3 ORDER BY 1;

-- select cumulative_sum(regex) (stub function, result)
--Testcase 168:
SELECT cumulative_sum('/value[1,4]/') from s3 ORDER BY 1;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 169:
EXPLAIN VERBOSE
SELECT cumulative_sum_all(), cumulative_sum('/value[1,4]/') from s3 ORDER BY 1;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (result)
--SELECT cumulative_sum_all(), cumulative_sum('/value[1,4]/') from s3 ORDER BY 1;

-- select cumulative_sum(*) (stub function and group by tag only) (explain)
--Testcase 170:
EXPLAIN VERBOSE
SELECT cumulative_sum_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select cumulative_sum(*) (stub function and group by tag only) (result)
--Testcase 171:
SELECT cumulative_sum_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select cumulative_sum(regex) (stub function and group by tag only) (explain)
--Testcase 172:
EXPLAIN VERBOSE
SELECT cumulative_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select cumulative_sum(regex) (stub function and group by tag only) (result)
--Testcase 173:
SELECT cumulative_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select cumulative_sum(*), cumulative_sum(regex) (stub function, expose data, explain)
--Testcase 174:
EXPLAIN VERBOSE
SELECT (cumulative_sum_all()::s3).*, (cumulative_sum('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select cumulative_sum(*), cumulative_sum(regex) (stub function, expose data, result)
--SELECT (cumulative_sum_all()::s3).*, (cumulative_sum('/value[1,4]/')::s3).* from s3 ORDER BY 1;

--Testcase 175:
EXPLAIN VERBOSE
SELECT derivative(value1),derivative(value2),derivative(value3),derivative(value4) FROM s3 ORDER BY 1, 2, 3, 4;

--Testcase 176:
SELECT * FROM (
SELECT derivative(value1),derivative(value2),derivative(value3),derivative(value4) FROM s3
) as t ORDER BY 1, 2, 3, 4;

--Testcase 177:
EXPLAIN VERBOSE
SELECT derivative(value1, interval '0.5s'),derivative(value2, interval '0.2s'),derivative(value3, interval '0.1s'),derivative(value4, interval '2s') FROM s3 ORDER BY 1;

--Testcase 178:
SELECT derivative(value1, interval '0.5s'),derivative(value2, interval '0.2s'),derivative(value3, interval '0.1s'),derivative(value4, interval '2s') FROM s3 ORDER BY 1;

-- select derivative(*) (stub function, explain)
--Testcase 179:
EXPLAIN VERBOSE
SELECT derivative_all() from s3 ORDER BY 1;

-- select derivative(*) (stub function, result)
--Testcase 180:
SELECT * FROM (
SELECT derivative_all() from s3
) as t ORDER BY 1;

-- select derivative(regex) (stub function, explain)
--Testcase 181:
EXPLAIN VERBOSE
SELECT derivative('/value[1,4]/') from s3 ORDER BY 1;

-- select derivative(regex) (stub function, result)
--Testcase 182:
SELECT derivative('/value[1,4]/') from s3 ORDER BY 1;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 183:
EXPLAIN VERBOSE
SELECT derivative_all(), derivative('/value[1,4]/') from s3 ORDER BY 1;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (explain)
--SELECT derivative_all(), derivative('/value[1,4]/') from s3 ORDER BY 1;

-- select derivative(*) (stub function and group by tag only) (explain)
--Testcase 184:
EXPLAIN VERBOSE
SELECT derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select derivative(*) (stub function and group by tag only) (result)
--Testcase 185:
SELECT derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select derivative(regex) (stub function and group by tag only) (explain)
--Testcase 186:
EXPLAIN VERBOSE
SELECT derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select derivative(regex) (stub function and group by tag only) (result)
--Testcase 187:
SELECT derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select derivative(*) (stub function, expose data, explain)
--Testcase 188:
EXPLAIN VERBOSE
SELECT (derivative_all()::s3).* from s3 ORDER BY 1;

-- select derivative(*) (stub function, expose data, result)
--Testcase 189:
SELECT * FROM (
SELECT (derivative_all()::s3).* from s3
) as t ORDER BY 1;

-- select derivative(regex) (stub function, expose data, explain)
--Testcase 190:
EXPLAIN VERBOSE
SELECT (derivative('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select derivative(regex) (stub function, expose data, result)
--Testcase 191:
SELECT * FROM (
SELECT (derivative('/value[1,4]/')::s3).* from s3
) as t ORDER BY 1;

--Testcase 192:
EXPLAIN VERBOSE
SELECT non_negative_derivative(value1),non_negative_derivative(value2),non_negative_derivative(value3),non_negative_derivative(value4) FROM s3 ORDER BY 1, 2, 3, 4;

--Testcase 193:
SELECT * FROM (
SELECT non_negative_derivative(value1),non_negative_derivative(value2),non_negative_derivative(value3),non_negative_derivative(value4) FROM s3
) as t ORDER BY 1, 2, 3, 4;

--Testcase 194:
EXPLAIN VERBOSE
SELECT non_negative_derivative(value1, interval '0.5s'),non_negative_derivative(value2, interval '0.2s'),non_negative_derivative(value3, interval '0.1s'),non_negative_derivative(value4, interval '2s') FROM s3 ORDER BY 1, 2, 3, 4;

--Testcase 195:
SELECT non_negative_derivative(value1, interval '0.5s'),non_negative_derivative(value2, interval '0.2s'),non_negative_derivative(value3, interval '0.1s'),non_negative_derivative(value4, interval '2s') FROM s3 ORDER BY 1, 2, 3, 4;

-- select non_negative_derivative(*) (stub function, explain)
--Testcase 196:
EXPLAIN VERBOSE
SELECT non_negative_derivative_all() from s3 ORDER BY 1;

-- select non_negative_derivative(*) (stub function, result)
--Testcase 197:
SELECT * FROM (
SELECT non_negative_derivative_all() from s3
) as t ORDER BY 1;

-- select non_negative_derivative(regex) (stub function, explain)
--Testcase 198:
EXPLAIN VERBOSE
SELECT non_negative_derivative('/value[1,4]/') from s3 ORDER BY 1;

-- select non_negative_derivative(regex) (stub function, result)
--Testcase 199:
SELECT non_negative_derivative('/value[1,4]/') from s3 ORDER BY 1;

-- select non_negative_derivative(*) (stub function and group by tag only) (explain)
--Testcase 200:
EXPLAIN VERBOSE
SELECT non_negative_derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_derivative(*) (stub function and group by tag only) (result)
--Testcase 201:
SELECT non_negative_derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_derivative(regex) (stub function and group by tag only) (explain)
--Testcase 202:
EXPLAIN VERBOSE
SELECT non_negative_derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_derivative(regex) (stub function and group by tag only) (result)
--Testcase 203:
SELECT non_negative_derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_derivative(*) (stub function, expose data, explain)
--Testcase 204:
EXPLAIN VERBOSE
SELECT (non_negative_derivative_all()::s3).* from s3 ORDER BY 1;

-- select non_negative_derivative(*) (stub function, expose data, result)
--Testcase 205:
SELECT * FROM (
SELECT (non_negative_derivative_all()::s3).* from s3
) as t ORDER BY 1;

-- select non_negative_derivative(regex) (stub function, expose data, explain)
--Testcase 206:
EXPLAIN VERBOSE
SELECT (non_negative_derivative('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select non_negative_derivative(regex) (stub function, expose data, result)
--Testcase 207:
SELECT * FROM (
SELECT (non_negative_derivative('/value[1,4]/')::s3).* from s3
) as t ORDER BY 1;

--Testcase 208:
EXPLAIN VERBOSE
SELECT difference(value1),difference(value2),difference(value3),difference(value4) FROM s3 ORDER BY 1, 2, 3, 4;

--Testcase 209:
SELECT difference(value1),difference(value2),difference(value3),difference(value4) FROM s3 ORDER BY 1, 2, 3, 4;

-- select difference(*) (stub function, explain)
--Testcase 210:
EXPLAIN VERBOSE
SELECT difference_all() from s3 ORDER BY 1;

-- select difference(*) (stub function, result)
--Testcase 211:
SELECT * FROM (
SELECT difference_all() from s3
) as t ORDER BY 1;

-- select difference(regex) (stub function, explain)
--Testcase 212:
EXPLAIN VERBOSE
SELECT difference('/value[1,4]/') from s3 ORDER BY 1;

-- select difference(regex) (stub function, result)
--Testcase 213:
SELECT difference('/value[1,4]/') from s3 ORDER BY 1;

-- select difference(*) (stub function and group by tag only) (explain)
--Testcase 214:
EXPLAIN VERBOSE
SELECT difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select difference(*) (stub function and group by tag only) (result)
--Testcase 215:
SELECT difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select difference(regex) (stub function and group by tag only) (explain)
--Testcase 216:
EXPLAIN VERBOSE
SELECT difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select difference(regex) (stub function and group by tag only) (result)
--Testcase 217:
SELECT difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select difference(*) (stub function, expose data, explain)
--Testcase 218:
EXPLAIN VERBOSE
SELECT (difference_all()::s3).* from s3 ORDER BY 1;

-- select difference(*) (stub function, expose data, result)
--Testcase 219:
SELECT * FROM (
SELECT (difference_all()::s3).* from s3
) as t ORDER BY 1;

-- select difference(regex) (stub function, expose data, explain)
--Testcase 220:
EXPLAIN VERBOSE
SELECT (difference('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select difference(regex) (stub function, expose data, result)
--Testcase 221:
SELECT * FROM (
SELECT (difference('/value[1,4]/')::s3).* from s3
) as t ORDER BY 1;

--Testcase 222:
EXPLAIN VERBOSE
SELECT non_negative_difference(value1),non_negative_difference(value2),non_negative_difference(value3),non_negative_difference(value4) FROM s3 ORDER BY 1;

--Testcase 223:
SELECT non_negative_difference(value1),non_negative_difference(value2),non_negative_difference(value3),non_negative_difference(value4) FROM s3 ORDER BY 1;

-- select non_negative_difference(*) (stub function, explain)
--Testcase 224:
EXPLAIN VERBOSE
SELECT non_negative_difference_all() from s3 ORDER BY 1;

-- select non_negative_difference(*) (stub function, result)
--Testcase 225:
SELECT * FROM (
SELECT non_negative_difference_all() from s3
) as t ORDER BY 1;

-- select non_negative_difference(regex) (stub function, explain)
--Testcase 226:
EXPLAIN VERBOSE
SELECT non_negative_difference('/value[1,4]/') from s3 ORDER BY 1;

-- select non_negative_difference(*), non_negative_difference(regex) (stub function, result)
--Testcase 227:
SELECT non_negative_difference('/value[1,4]/') from s3 ORDER BY 1;

-- select non_negative_difference(*) (stub function and group by tag only) (explain)
--Testcase 228:
EXPLAIN VERBOSE
SELECT non_negative_difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_difference(*) (stub function and group by tag only) (result)
--Testcase 229:
SELECT non_negative_difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_difference(regex) (stub function and group by tag only) (explain)
--Testcase 230:
EXPLAIN VERBOSE
SELECT non_negative_difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_difference(regex) (stub function and group by tag only) (result)
--Testcase 231:
SELECT non_negative_difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select non_negative_difference(*) (stub function, expose data, explain)
--Testcase 232:
EXPLAIN VERBOSE
SELECT (non_negative_difference_all()::s3).* from s3 ORDER BY 1;

-- select non_negative_difference(*) (stub function, expose data, result)
--Testcase 233:
SELECT * FROM (
SELECT (non_negative_difference_all()::s3).* from s3
) as t ORDER BY 1;

-- select non_negative_difference(regex) (stub function, expose data, explain)
--Testcase 234:
EXPLAIN VERBOSE
SELECT (non_negative_difference('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select non_negative_difference(regex) (stub function, expose data, result)
--Testcase 235:
SELECT * FROM (
SELECT (non_negative_difference('/value[1,4]/')::s3).* from s3
) as t ORDER BY 1;

--Testcase 236:
EXPLAIN VERBOSE
SELECT elapsed(value1),elapsed(value2),elapsed(value3),elapsed(value4) FROM s3 ORDER BY 1;

--Testcase 237:
SELECT elapsed(value1),elapsed(value2),elapsed(value3),elapsed(value4) FROM s3 ORDER BY 1;

--Testcase 238:
EXPLAIN VERBOSE
SELECT elapsed(value1, interval '0.5s'),elapsed(value2, interval '0.2s'),elapsed(value3, interval '0.1s'),elapsed(value4, interval '2s') FROM s3 ORDER BY 1;

--Testcase 239:
SELECT elapsed(value1, interval '0.5s'),elapsed(value2, interval '0.2s'),elapsed(value3, interval '0.1s'),elapsed(value4, interval '2s') FROM s3 ORDER BY 1;

-- select elapsed(*) (stub function, explain)
--Testcase 240:
EXPLAIN VERBOSE
SELECT elapsed_all() from s3 ORDER BY 1;

-- select elapsed(*) (stub function, result)
--Testcase 241:
SELECT * FROM (
SELECT elapsed_all() from s3
) as t ORDER BY 1;

-- select elapsed(regex) (stub function, explain)
--Testcase 242:
EXPLAIN VERBOSE
SELECT elapsed('/value[1,4]/') from s3 ORDER BY 1;

-- select elapsed(regex) (stub function, result)
--Testcase 243:
SELECT elapsed('/value[1,4]/') from s3 ORDER BY 1;

-- select elapsed(*) (stub function and group by tag only) (explain)
--Testcase 244:
EXPLAIN VERBOSE
SELECT elapsed_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select elapsed(*) (stub function and group by tag only) (result)
--Testcase 245:
SELECT elapsed_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select elapsed(regex) (stub function and group by tag only) (explain)
--Testcase 246:
EXPLAIN VERBOSE
SELECT elapsed('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select elapsed(regex) (stub function and group by tag only) (result)
--Testcase 247:
SELECT elapsed('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select elapsed(*) (stub function, expose data, explain)
--Testcase 248:
EXPLAIN VERBOSE
SELECT (elapsed_all()::s3).* from s3 ORDER BY 1;

-- select elapsed(*) (stub function, expose data, result)
--Testcase 249:
SELECT * FROM (
SELECT (elapsed_all()::s3).* from s3
) as t ORDER BY 1;

-- select elapsed(regex) (stub function, expose data, explain)
--Testcase 250:
EXPLAIN VERBOSE
SELECT (elapsed('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select elapsed(regex) (stub function, expose data, result)
--Testcase 251:
SELECT * FROM (
SELECT (elapsed('/value[1,4]/')::s3).* from s3
) as t ORDER BY 1;

--Testcase 252:
EXPLAIN VERBOSE
SELECT moving_average(value1, 2),moving_average(value2, 2),moving_average(value3, 2),moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 253:
SELECT moving_average(value1, 2),moving_average(value2, 2),moving_average(value3, 2),moving_average(value4, 2) FROM s3 ORDER BY 1;

-- select moving_average(*) (stub function, explain)
--Testcase 254:
EXPLAIN VERBOSE
SELECT moving_average_all(2) from s3 ORDER BY 1;

-- select moving_average(*) (stub function, result)
--Testcase 255:
SELECT * FROM (
SELECT moving_average_all(2) from s3
) as t ORDER BY 1;

-- select moving_average(regex) (stub function, explain)
--Testcase 256:
EXPLAIN VERBOSE
SELECT moving_average('/value[1,4]/', 2) from s3 ORDER BY 1;

-- select moving_average(regex) (stub function, result)
--Testcase 257:
SELECT moving_average('/value[1,4]/', 2) from s3 ORDER BY 1;

-- select moving_average(*) (stub function and group by tag only) (explain)
--Testcase 258:
EXPLAIN VERBOSE
SELECT moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select moving_average(*) (stub function and group by tag only) (result)
--Testcase 259:
SELECT moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 260:
EXPLAIN VERBOSE
SELECT moving_average('/value[1,4]/', 2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select moving_average(regex) (stub function and group by tag only) (result)
--Testcase 261:
SELECT moving_average('/value[1,4]/', 2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select moving_average(*) (stub function, expose data, explain)
--Testcase 262:
EXPLAIN VERBOSE
SELECT (moving_average_all(2)::s3).* from s3 ORDER BY 1;

-- select moving_average(*) (stub function, expose data, result)
--Testcase 263:
SELECT * FROM (
SELECT (moving_average_all(2)::s3).* from s3
) as t ORDER BY 1;

-- select moving_average(regex) (stub function, expose data, explain)
--Testcase 264:
EXPLAIN VERBOSE
SELECT (moving_average('/value[1,4]/', 2)::s3).* from s3 ORDER BY 1;

-- select moving_average(regex) (stub function, expose data, result)
--Testcase 265:
SELECT * FROM (
SELECT (moving_average('/value[1,4]/', 2)::s3).* from s3
) as t ORDER BY 1;

--Testcase 266:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator(value1, 2),chande_momentum_oscillator(value2, 2),chande_momentum_oscillator(value3, 2),chande_momentum_oscillator(value4, 2) FROM s3 ORDER BY 1;

--Testcase 267:
SELECT chande_momentum_oscillator(value1, 2),chande_momentum_oscillator(value2, 2),chande_momentum_oscillator(value3, 2),chande_momentum_oscillator(value4, 2) FROM s3 ORDER BY 1;

--Testcase 268:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator(value1, 2, 2),chande_momentum_oscillator(value2, 2, 2),chande_momentum_oscillator(value3, 2, 2),chande_momentum_oscillator(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 269:
SELECT chande_momentum_oscillator(value1, 2, 2),chande_momentum_oscillator(value2, 2, 2),chande_momentum_oscillator(value3, 2, 2),chande_momentum_oscillator(value4, 2, 2) FROM s3 ORDER BY 1;

-- select chande_momentum_oscillator(*) (stub function, explain)
--Testcase 270:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator_all(2) from s3 ORDER BY 1;

-- select chande_momentum_oscillator(*) (stub function, result)
--Testcase 271:
SELECT * FROM (
SELECT chande_momentum_oscillator_all(2) from s3
) as t ORDER BY 1;

-- select chande_momentum_oscillator(regex) (stub function, explain)
--Testcase 272:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator('/value[1,4]/',2) from s3 ORDER BY 1;

-- select chande_momentum_oscillator(regex) (stub function, result)
--Testcase 273:
SELECT chande_momentum_oscillator('/value[1,4]/',2) from s3 ORDER BY 1;

-- select chande_momentum_oscillator(*) (stub function and group by tag only) (explain)
--Testcase 274:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select chande_momentum_oscillator(*) (stub function and group by tag only) (result)
--Testcase 275:
SELECT chande_momentum_oscillator_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select chande_momentum_oscillator(regex) (stub function and group by tag only) (explain)
--Testcase 276:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select chande_momentum_oscillator(regex) (stub function and group by tag only) (result)
--Testcase 277:
SELECT chande_momentum_oscillator('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select chande_momentum_oscillator(*) (stub function, expose data, explain)
--Testcase 278:
EXPLAIN VERBOSE
SELECT (chande_momentum_oscillator_all(2)::s3).* from s3 ORDER BY 1;

-- select chande_momentum_oscillator(*) (stub function, expose data, result)
--Testcase 279:
SELECT * FROM (
SELECT (chande_momentum_oscillator_all(2)::s3).* from s3
) as t ORDER BY 1;

-- select chande_momentum_oscillator(regex) (stub function, expose data, explain)
--Testcase 280:
EXPLAIN VERBOSE
SELECT (chande_momentum_oscillator('/value[1,4]/',2)::s3).* from s3 ORDER BY 1;

-- select chande_momentum_oscillator(regex) (stub function, expose data, result)
--Testcase 281:
SELECT * FROM (
SELECT (chande_momentum_oscillator('/value[1,4]/',2)::s3).* from s3
) as t ORDER BY 1;

--Testcase 282:
EXPLAIN VERBOSE
SELECT exponential_moving_average(value1, 2),exponential_moving_average(value2, 2),exponential_moving_average(value3, 2),exponential_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 283:
SELECT exponential_moving_average(value1, 2),exponential_moving_average(value2, 2),exponential_moving_average(value3, 2),exponential_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 284:
EXPLAIN VERBOSE
SELECT exponential_moving_average(value1, 2, 2),exponential_moving_average(value2, 2, 2),exponential_moving_average(value3, 2, 2),exponential_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 285:
SELECT exponential_moving_average(value1, 2, 2),exponential_moving_average(value2, 2, 2),exponential_moving_average(value3, 2, 2),exponential_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

-- select exponential_moving_average(*) (stub function, explain)
--Testcase 286:
EXPLAIN VERBOSE
SELECT exponential_moving_average_all(2) from s3 ORDER BY 1;

-- select exponential_moving_average(*) (stub function, result)
--Testcase 287:
SELECT * FROM (
SELECT exponential_moving_average_all(2) from s3
) as t ORDER BY 1;

-- select exponential_moving_average(regex) (stub function, explain)
--Testcase 288:
EXPLAIN VERBOSE
SELECT exponential_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select exponential_moving_average(regex) (stub function, result)
--Testcase 289:
SELECT exponential_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select exponential_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 290:
EXPLAIN VERBOSE
SELECT exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select exponential_moving_average(*) (stub function and group by tag only) (result)
--Testcase 291:
SELECT exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select exponential_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 292:
EXPLAIN VERBOSE
SELECT exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select exponential_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 293:
SELECT exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

--Testcase 294:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average(value1, 2),double_exponential_moving_average(value2, 2),double_exponential_moving_average(value3, 2),double_exponential_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 295:
SELECT double_exponential_moving_average(value1, 2),double_exponential_moving_average(value2, 2),double_exponential_moving_average(value3, 2),double_exponential_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 296:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average(value1, 2, 2),double_exponential_moving_average(value2, 2, 2),double_exponential_moving_average(value3, 2, 2),double_exponential_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 297:
SELECT double_exponential_moving_average(value1, 2, 2),double_exponential_moving_average(value2, 2, 2),double_exponential_moving_average(value3, 2, 2),double_exponential_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

-- select double_exponential_moving_average(*) (stub function, explain)
--Testcase 298:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average_all(2) from s3 ORDER BY 1;

-- select double_exponential_moving_average(*) (stub function, result)
--Testcase 299:
SELECT * FROM (
SELECT double_exponential_moving_average_all(2) from s3
) as t ORDER BY 1;

-- select double_exponential_moving_average(regex) (stub function, explain)
--Testcase 300:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select double_exponential_moving_average(regex) (stub function, result)
--Testcase 301:
SELECT double_exponential_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select double_exponential_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 302:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select double_exponential_moving_average(*) (stub function and group by tag only) (result)
--Testcase 303:
SELECT double_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select double_exponential_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 304:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select double_exponential_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 305:
SELECT double_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

--Testcase 306:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio(value1, 2),kaufmans_efficiency_ratio(value2, 2),kaufmans_efficiency_ratio(value3, 2),kaufmans_efficiency_ratio(value4, 2) FROM s3 ORDER BY 1;

--Testcase 307:
SELECT kaufmans_efficiency_ratio(value1, 2),kaufmans_efficiency_ratio(value2, 2),kaufmans_efficiency_ratio(value3, 2),kaufmans_efficiency_ratio(value4, 2) FROM s3 ORDER BY 1;

--Testcase 308:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio(value1, 2, 2),kaufmans_efficiency_ratio(value2, 2, 2),kaufmans_efficiency_ratio(value3, 2, 2),kaufmans_efficiency_ratio(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 309:
SELECT kaufmans_efficiency_ratio(value1, 2, 2),kaufmans_efficiency_ratio(value2, 2, 2),kaufmans_efficiency_ratio(value3, 2, 2),kaufmans_efficiency_ratio(value4, 2, 2) FROM s3 ORDER BY 1;

-- select kaufmans_efficiency_ratio(*) (stub function, explain)
--Testcase 310:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio_all(2) from s3 ORDER BY 1;

-- select kaufmans_efficiency_ratio(*) (stub function, result)
--Testcase 311:
SELECT * FROM (
SELECT kaufmans_efficiency_ratio_all(2) from s3
) as t ORDER BY 1;

-- select kaufmans_efficiency_ratio(regex) (stub function, explain)
--Testcase 312:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) from s3 ORDER BY 1;

-- select kaufmans_efficiency_ratio(regex) (stub function, result)
--Testcase 313:
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) from s3 ORDER BY 1;

-- select kaufmans_efficiency_ratio(*) (stub function and group by tag only) (explain)
--Testcase 314:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_efficiency_ratio(*) (stub function and group by tag only) (result)
--Testcase 315:
SELECT kaufmans_efficiency_ratio_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_efficiency_ratio(regex) (stub function and group by tag only) (explain)
--Testcase 316:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_efficiency_ratio(regex) (stub function and group by tag only) (result)
--Testcase 317:
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_efficiency_ratio(*) (stub function, expose data, explain)
--Testcase 318:
EXPLAIN VERBOSE
SELECT (kaufmans_efficiency_ratio_all(2)::s3).* from s3 ORDER BY 1;

-- select kaufmans_efficiency_ratio(*) (stub function, expose data, result)
--Testcase 319:
SELECT * FROM (
SELECT (kaufmans_efficiency_ratio_all(2)::s3).* from s3
) as t ORDER BY 1;

-- select kaufmans_efficiency_ratio(regex) (stub function, expose data, explain)
--Testcase 320:
EXPLAIN VERBOSE
SELECT (kaufmans_efficiency_ratio('/value[1,4]/',2)::s3).* from s3 ORDER BY 1;

-- select kaufmans_efficiency_ratio(regex) (stub function, expose data, result)
--Testcase 321:
SELECT * FROM (
SELECT (kaufmans_efficiency_ratio('/value[1,4]/',2)::s3).* from s3
) as t ORDER BY 1;

--Testcase 322:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average(value1, 2),kaufmans_adaptive_moving_average(value2, 2),kaufmans_adaptive_moving_average(value3, 2),kaufmans_adaptive_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 323:
SELECT kaufmans_adaptive_moving_average(value1, 2),kaufmans_adaptive_moving_average(value2, 2),kaufmans_adaptive_moving_average(value3, 2),kaufmans_adaptive_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 324:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average(value1, 2, 2),kaufmans_adaptive_moving_average(value2, 2, 2),kaufmans_adaptive_moving_average(value3, 2, 2),kaufmans_adaptive_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 325:
SELECT kaufmans_adaptive_moving_average(value1, 2, 2),kaufmans_adaptive_moving_average(value2, 2, 2),kaufmans_adaptive_moving_average(value3, 2, 2),kaufmans_adaptive_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(*) (stub function, explain)
--Testcase 326:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average_all(2) from s3 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(*) (stub function, result)
--Testcase 327:
SELECT * FROM (
SELECT kaufmans_adaptive_moving_average_all(2) from s3
) as t ORDER BY 1;

-- select kaufmans_adaptive_moving_average(regex) (stub function, explain)
--Testcase 328:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(regex) (stub function, result)
--Testcase 329:
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 330:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(*) (stub function and group by tag only) (result)
--Testcase 331:
SELECT kaufmans_adaptive_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 332:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select kaufmans_adaptive_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 333:
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

--Testcase 334:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average(value1, 2),triple_exponential_moving_average(value2, 2),triple_exponential_moving_average(value3, 2),triple_exponential_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 335:
SELECT triple_exponential_moving_average(value1, 2),triple_exponential_moving_average(value2, 2),triple_exponential_moving_average(value3, 2),triple_exponential_moving_average(value4, 2) FROM s3 ORDER BY 1;

--Testcase 336:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average(value1, 2, 2),triple_exponential_moving_average(value2, 2, 2),triple_exponential_moving_average(value3, 2, 2),triple_exponential_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 337:
SELECT triple_exponential_moving_average(value1, 2, 2),triple_exponential_moving_average(value2, 2, 2),triple_exponential_moving_average(value3, 2, 2),triple_exponential_moving_average(value4, 2, 2) FROM s3 ORDER BY 1;

-- select triple_exponential_moving_average(*) (stub function, explain)
--Testcase 338:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average_all(2) from s3 ORDER BY 1;

-- select triple_exponential_moving_average(*) (stub function, result)
--Testcase 339:
SELECT * FROM (
SELECT triple_exponential_moving_average_all(2) from s3
) as t ORDER BY 1;

-- select triple_exponential_moving_average(regex) (stub function, explain)
--Testcase 340:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select triple_exponential_moving_average(regex) (stub function, result)
--Testcase 341:
SELECT triple_exponential_moving_average('/value[1,4]/',2) from s3 ORDER BY 1;

-- select triple_exponential_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 342:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select triple_exponential_moving_average(*) (stub function and group by tag only) (result)
--Testcase 343:
SELECT triple_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select triple_exponential_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 344:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select triple_exponential_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 345:
SELECT triple_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

--Testcase 346:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative(value1, 2),triple_exponential_derivative(value2, 2),triple_exponential_derivative(value3, 2),triple_exponential_derivative(value4, 2) FROM s3 ORDER BY 1;

--Testcase 347:
SELECT triple_exponential_derivative(value1, 2),triple_exponential_derivative(value2, 2),triple_exponential_derivative(value3, 2),triple_exponential_derivative(value4, 2) FROM s3 ORDER BY 1;

--Testcase 348:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative(value1, 2, 2),triple_exponential_derivative(value2, 2, 2),triple_exponential_derivative(value3, 2, 2),triple_exponential_derivative(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 349:
SELECT triple_exponential_derivative(value1, 2, 2),triple_exponential_derivative(value2, 2, 2),triple_exponential_derivative(value3, 2, 2),triple_exponential_derivative(value4, 2, 2) FROM s3 ORDER BY 1;

-- select triple_exponential_derivative(*) (stub function, explain)
--Testcase 350:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative_all(2) from s3 ORDER BY 1;

-- select triple_exponential_derivative(*) (stub function, result)
--Testcase 351:
SELECT * FROM (
SELECT triple_exponential_derivative_all(2) from s3
) as t ORDER BY 1;

-- select triple_exponential_derivative(regex) (stub function, explain)
--Testcase 352:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative('/value[1,4]/',2) from s3 ORDER BY 1;

-- select triple_exponential_derivative(regex) (stub function, result)
--Testcase 353:
SELECT triple_exponential_derivative('/value[1,4]/',2) from s3 ORDER BY 1;

-- select triple_exponential_derivative(*) (stub function and group by tag only) (explain)
--Testcase 354:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select triple_exponential_derivative(*) (stub function and group by tag only) (result)
--Testcase 355:
SELECT triple_exponential_derivative_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select triple_exponential_derivative(regex) (stub function and group by tag only) (explain)
--Testcase 356:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select triple_exponential_derivative(regex) (stub function and group by tag only) (result)
--Testcase 357:
SELECT triple_exponential_derivative('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

--Testcase 358:
EXPLAIN VERBOSE
SELECT relative_strength_index(value1, 2),relative_strength_index(value2, 2),relative_strength_index(value3, 2),relative_strength_index(value4, 2) FROM s3 ORDER BY 1;

--Testcase 359:
SELECT relative_strength_index(value1, 2),relative_strength_index(value2, 2),relative_strength_index(value3, 2),relative_strength_index(value4, 2) FROM s3 ORDER BY 1;

--Testcase 360:
EXPLAIN VERBOSE
SELECT relative_strength_index(value1, 2, 2),relative_strength_index(value2, 2, 2),relative_strength_index(value3, 2, 2),relative_strength_index(value4, 2, 2) FROM s3 ORDER BY 1;

--Testcase 361:
SELECT relative_strength_index(value1, 2, 2),relative_strength_index(value2, 2, 2),relative_strength_index(value3, 2, 2),relative_strength_index(value4, 2, 2) FROM s3 ORDER BY 1;

-- select relative_strength_index(*) (stub function, explain)
--Testcase 362:
EXPLAIN VERBOSE
SELECT relative_strength_index_all(2) from s3 ORDER BY 1;

-- select relative_strength_index(*) (stub function, result)
--Testcase 363:
SELECT * FROM (
SELECT relative_strength_index_all(2) from s3
) as t ORDER BY 1;

-- select relative_strength_index(regex) (stub function, explain)
--Testcase 364:
EXPLAIN VERBOSE
SELECT relative_strength_index('/value[1,4]/',2) from s3 ORDER BY 1;

-- select relative_strength_index(regex) (stub function, result)
--Testcase 365:
SELECT relative_strength_index('/value[1,4]/',2) from s3 ORDER BY 1;

-- select relative_strength_index(*) (stub function and group by tag only) (explain)
--Testcase 366:
EXPLAIN VERBOSE
SELECT relative_strength_index_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select relative_strength_index(*) (stub function and group by tag only) (result)
--Testcase 367:
SELECT relative_strength_index_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select relative_strength_index(regex) (stub function and group by tag only) (explain)
--Testcase 368:
EXPLAIN VERBOSE
SELECT relative_strength_index('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select relative_strength_index(regex) (stub function and group by tag only) (result)
--Testcase 369:
SELECT relative_strength_index('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select relative_strength_index(*) (stub function, expose data, explain)
--Testcase 370:
EXPLAIN VERBOSE
SELECT (relative_strength_index_all(2)::s3).* from s3 ORDER BY 1;

-- select relative_strength_index(*) (stub function, expose data, result)
--Testcase 371:
SELECT * FROM (
SELECT (relative_strength_index_all(2)::s3).* from s3
) as t ORDER BY 1;

-- select relative_strength_index(regex) (stub function, expose data, explain)
--Testcase 372:
EXPLAIN VERBOSE
SELECT (relative_strength_index('/value[1,4]/',2)::s3).* from s3 ORDER BY 1;

-- select relative_strength_index(regex) (stub function, expose data, result)
--Testcase 373:
SELECT * FROM (
SELECT (relative_strength_index('/value[1,4]/',2)::s3).* from s3
) as t ORDER BY 1;

-- select integral (stub agg function, explain)
--Testcase 374:
EXPLAIN VERBOSE
SELECT integral(value1),integral(value2),integral(value3),integral(value4) FROM s3 ORDER BY 1;

-- select integral (stub agg function, result)
--Testcase 375:
SELECT integral(value1),integral(value2),integral(value3),integral(value4) FROM s3 ORDER BY 1;

--Testcase 376:
EXPLAIN VERBOSE
SELECT integral(value1, interval '1s'),integral(value2, interval '1s'),integral(value3, interval '1s'),integral(value4, interval '1s') FROM s3 ORDER BY 1;

-- select integral (stub agg function, result)
--Testcase 377:
SELECT integral(value1, interval '1s'),integral(value2, interval '1s'),integral(value3, interval '1s'),integral(value4, interval '1s') FROM s3 ORDER BY 1;

-- select integral (stub agg function, raise exception if not expected type)
--SELECT integral(value1::numeric),integral(value2::numeric),integral(value3::numeric),integral(value4::numeric) FROM s3 ORDER BY 1;

-- select integral (stub agg function and group by influx_time() and tag) (explain)
--Testcase 378:
EXPLAIN VERBOSE
SELECT integral("value1"),influx_time(time, interval '1s'),tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral (stub agg function and group by influx_time() and tag) (result)
--Testcase 379:
SELECT integral("value1"),influx_time(time, interval '1s'),tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral (stub agg function and group by influx_time() and tag) (explain)
--Testcase 380:
EXPLAIN VERBOSE
SELECT integral("value1", interval '1s'),influx_time(time, interval '1s'),tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral (stub agg function and group by influx_time() and tag) (result)
--Testcase 381:
SELECT integral("value1", interval '1s'),influx_time(time, interval '1s'),tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral (stub agg function and group by tag only) (result)
--Testcase 382:
SELECT tag1,integral("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select integral (stub agg function and other aggs) (result)
--Testcase 383:
SELECT sum("value1"),integral("value1"),count("value1") FROM s3 ORDER BY 1;

-- select integral (stub agg function and group by tag only) (result)
--Testcase 384:
SELECT tag1,integral("value1", interval '1s') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select integral (stub agg function and other aggs) (result)
--Testcase 385:
SELECT sum("value1"),integral("value1", interval '1s'),count("value1") FROM s3 ORDER BY 1;

-- select integral over join query (explain)
--Testcase 386:
EXPLAIN VERBOSE
SELECT integral(t1.value1), integral(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select integral over join query (result, stub call error)
--Testcase 387:
SELECT integral(t1.value1), integral(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select integral over join query (explain)
--Testcase 388:
EXPLAIN VERBOSE
SELECT integral(t1.value1, interval '1s'), integral(t2.value1, interval '1s') FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select integral over join query (result, stub call error)
--Testcase 389:
SELECT integral(t1.value1, interval '1s'), integral(t2.value1, interval '1s') FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select integral with having (explain)
--Testcase 390:
EXPLAIN VERBOSE
SELECT integral(value1) FROM s3 HAVING integral(value1) > 100 ORDER BY 1;

-- select integral with having (explain, not pushdown, stub call error)
--Testcase 391:
SELECT integral(value1) FROM s3 HAVING integral(value1) > 100 ORDER BY 1;

-- select integral with having (explain)
--Testcase 392:
EXPLAIN VERBOSE
SELECT integral(value1, interval '1s') FROM s3 HAVING integral(value1, interval '1s') > 100 ORDER BY 1;

-- select integral with having (explain, not pushdown, stub call error)
--Testcase 393:
SELECT integral(value1, interval '1s') FROM s3 HAVING integral(value1, interval '1s') > 100 ORDER BY 1;

-- select integral(*) (stub agg function, explain)
--Testcase 394:
EXPLAIN VERBOSE
SELECT integral_all(*) from s3 ORDER BY 1;

-- select integral(*) (stub agg function, result)
--Testcase 395:
SELECT integral_all(*) from s3 ORDER BY 1;

-- select integral(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 396:
EXPLAIN VERBOSE
SELECT integral_all(*) FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 397:
SELECT integral_all(*) FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral(*) (stub agg function and group by tag only) (explain)
--Testcase 398:
EXPLAIN VERBOSE
SELECT integral_all(*) FROM s3 WHERE value1 > 0.3 GROUP BY tag1 ORDER BY 1;

-- select integral(*) (stub agg function and group by tag only) (result)
--Testcase 399:
SELECT integral_all(*) FROM s3 WHERE value1 > 0.3 GROUP BY tag1 ORDER BY 1;

-- select integral(*) (stub agg function, expose data, explain)
--Testcase 400:
EXPLAIN VERBOSE
SELECT (integral_all(*)::s3).* from s3 ORDER BY 1;

-- select integral(*) (stub agg function, expose data, result)
--Testcase 401:
SELECT (integral_all(*)::s3).* from s3 ORDER BY 1;

-- select integral(regex) (stub agg function, explain)
--Testcase 402:
EXPLAIN VERBOSE
SELECT integral('/value[1,4]/') from s3 ORDER BY 1;

-- select integral(regex) (stub agg function, result)
--Testcase 403:
SELECT integral('/value[1,4]/') from s3 ORDER BY 1;

-- select integral(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 404:
EXPLAIN VERBOSE
SELECT integral('/^v.*/') FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 405:
SELECT integral('/^v.*/') FROM s3 GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select integral(regex) (stub agg function and group by tag only) (explain)
--Testcase 406:
EXPLAIN VERBOSE
SELECT integral('/value[1,4]/') FROM s3 WHERE value1 > 0.3 GROUP BY tag1 ORDER BY 1;

-- select integral(regex) (stub agg function and group by tag only) (result)
--Testcase 407:
SELECT integral('/value[1,4]/') FROM s3 WHERE value1 > 0.3 GROUP BY tag1 ORDER BY 1;

-- select integral(regex) (stub agg function, expose data, explain)
--Testcase 408:
EXPLAIN VERBOSE
SELECT (integral('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select integral(regex) (stub agg function, expose data, result)
--Testcase 409:
SELECT (integral('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select mean (stub agg function, explain)
--Testcase 410:
EXPLAIN VERBOSE
SELECT mean(value1),mean(value2),mean(value3),mean(value4) FROM s3 ORDER BY 1;

-- select mean (stub agg function, result)
--Testcase 411:
SELECT mean(value1),mean(value2),mean(value3),mean(value4) FROM s3 ORDER BY 1;

-- select mean (stub agg function, raise exception if not expected type)
--SELECT mean(value1::numeric),mean(value2::numeric),mean(value3::numeric),mean(value4::numeric) FROM s3 ORDER BY 1;

-- select mean (stub agg function and group by influx_time() and tag) (explain)
--Testcase 412:
EXPLAIN VERBOSE
SELECT mean("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select mean (stub agg function and group by influx_time() and tag) (result)
--Testcase 413:
SELECT mean("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select mean (stub agg function and group by tag only) (result)
--Testcase 414:
SELECT tag1,mean("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select mean (stub agg function and other aggs) (result)
--Testcase 415:
SELECT sum("value1"),mean("value1"),count("value1") FROM s3 ORDER BY 1;

-- select mean over join query (explain)
--Testcase 416:
EXPLAIN VERBOSE
SELECT mean(t1.value1), mean(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select mean over join query (result, stub call error)
--Testcase 417:
SELECT mean(t1.value1), mean(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select mean with having (explain)
--Testcase 418:
EXPLAIN VERBOSE
SELECT mean(value1) FROM s3 HAVING mean(value1) > 100 ORDER BY 1;

-- select mean with having (explain, not pushdown, stub call error)
--Testcase 419:
SELECT mean(value1) FROM s3 HAVING mean(value1) > 100 ORDER BY 1;

-- select mean(*) (stub agg function, explain)
--Testcase 420:
EXPLAIN VERBOSE
SELECT mean_all(*) from s3 ORDER BY 1;

-- select mean(*) (stub agg function, result)
--Testcase 421:
SELECT mean_all(*) from s3 ORDER BY 1;

-- select mean(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 422:
EXPLAIN VERBOSE
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select mean(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 423:
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select mean(*) (stub agg function and group by tag only) (explain)
--Testcase 424:
EXPLAIN VERBOSE
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select mean(*) (stub agg function and group by tag only) (result)
--Testcase 425:
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select mean(*) (stub agg function, expose data, explain)
--Testcase 426:
EXPLAIN VERBOSE
SELECT (mean_all(*)::s3).* from s3 ORDER BY 1;

-- select mean(*) (stub agg function, expose data, result)
--Testcase 427:
SELECT (mean_all(*)::s3).* from s3 ORDER BY 1;

-- select mean(regex) (stub agg function, explain)
--Testcase 428:
EXPLAIN VERBOSE
SELECT mean('/value[1,4]/') from s3 ORDER BY 1;

-- select mean(regex) (stub agg function, result)
--Testcase 429:
SELECT mean('/value[1,4]/') from s3 ORDER BY 1;

-- select mean(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 430:
EXPLAIN VERBOSE
SELECT mean('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select mean(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 431:
SELECT mean('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select mean(regex) (stub agg function and group by tag only) (explain)
--Testcase 432:
EXPLAIN VERBOSE
SELECT mean('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select mean(regex) (stub agg function and group by tag only) (result)
--Testcase 433:
SELECT mean('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select mean(regex) (stub agg function, expose data, explain)
--Testcase 434:
EXPLAIN VERBOSE
SELECT (mean('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select mean(regex) (stub agg function, expose data, result)
--Testcase 435:
SELECT (mean('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select median (stub agg function, explain)
--Testcase 436:
EXPLAIN VERBOSE
SELECT median(value1),median(value2),median(value3),median(value4) FROM s3 ORDER BY 1;

-- select median (stub agg function, result)
--Testcase 437:
SELECT median(value1),median(value2),median(value3),median(value4) FROM s3 ORDER BY 1;

-- select median (stub agg function, raise exception if not expected type)
--SELECT median(value1::numeric),median(value2::numeric),median(value3::numeric),median(value4::numeric) FROM s3 ORDER BY 1;

-- select median (stub agg function and group by influx_time() and tag) (explain)
--Testcase 438:
EXPLAIN VERBOSE
SELECT median("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select median (stub agg function and group by influx_time() and tag) (result)
--Testcase 439:
SELECT median("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select median (stub agg function and group by tag only) (result)
--Testcase 440:
SELECT tag1,median("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select median (stub agg function and other aggs) (result)
--Testcase 441:
SELECT sum("value1"),median("value1"),count("value1") FROM s3 ORDER BY 1;

-- select median over join query (explain)
--Testcase 442:
EXPLAIN VERBOSE
SELECT median(t1.value1), median(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select median over join query (result, stub call error)
--Testcase 443:
SELECT median(t1.value1), median(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select median with having (explain)
--Testcase 444:
EXPLAIN VERBOSE
SELECT median(value1) FROM s3 HAVING median(value1) > 100 ORDER BY 1;

-- select median with having (explain, not pushdown, stub call error)
--Testcase 445:
SELECT median(value1) FROM s3 HAVING median(value1) > 100 ORDER BY 1;

-- select median(*) (stub agg function, explain)
--Testcase 446:
EXPLAIN VERBOSE
SELECT median_all(*) from s3 ORDER BY 1;

-- select median(*) (stub agg function, result)
--Testcase 447:
SELECT median_all(*) from s3 ORDER BY 1;

-- select median(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 448:
EXPLAIN VERBOSE
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select median(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 449:
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select median(*) (stub agg function and group by tag only) (explain)
--Testcase 450:
EXPLAIN VERBOSE
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select median(*) (stub agg function and group by tag only) (result)
--Testcase 451:
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select median(*) (stub agg function, expose data, explain)
--Testcase 452:
EXPLAIN VERBOSE
SELECT (median_all(*)::s3).* from s3 ORDER BY 1;

-- select median(*) (stub agg function, expose data, result)
--Testcase 453:
SELECT (median_all(*)::s3).* from s3 ORDER BY 1;

-- select median(regex) (stub agg function, explain)
--Testcase 454:
EXPLAIN VERBOSE
SELECT median('/^v.*/') from s3 ORDER BY 1;

-- select median(regex) (stub agg function, result)
--Testcase 455:
SELECT  median('/^v.*/') from s3 ORDER BY 1;

-- select median(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 456:
EXPLAIN VERBOSE
SELECT median('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select median(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 457:
SELECT median('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select median(regex) (stub agg function and group by tag only) (explain)
--Testcase 458:
EXPLAIN VERBOSE
SELECT median('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select median(regex) (stub agg function and group by tag only) (result)
--Testcase 459:
SELECT median('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select median(regex) (stub agg function, expose data, explain)
--Testcase 460:
EXPLAIN VERBOSE
SELECT (median('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select median(regex) (stub agg function, expose data, result)
--Testcase 461:
SELECT (median('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select influx_mode (stub agg function, explain)
--Testcase 462:
EXPLAIN VERBOSE
SELECT influx_mode(value1),influx_mode(value2),influx_mode(value3),influx_mode(value4) FROM s3 ORDER BY 1;

-- select influx_mode (stub agg function, result)
--Testcase 463:
SELECT influx_mode(value1),influx_mode(value2),influx_mode(value3),influx_mode(value4) FROM s3 ORDER BY 1;

-- select influx_mode (stub agg function, raise exception if not expected type)
--SELECT influx_mode(value1::numeric),influx_mode(value2::numeric),influx_mode(value3::numeric),influx_mode(value4::numeric) FROM s3 ORDER BY 1;

-- select influx_mode (stub agg function and group by influx_time() and tag) (explain)
--Testcase 464:
EXPLAIN VERBOSE
SELECT influx_mode("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_mode (stub agg function and group by influx_time() and tag) (result)
--Testcase 465:
SELECT influx_mode("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_mode (stub agg function and group by tag only) (result)
--Testcase 466:
SELECT tag1,influx_mode("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_mode (stub agg function and other aggs) (result)
--Testcase 467:
SELECT sum("value1"),influx_mode("value1"),count("value1") FROM s3 ORDER BY 1;

-- select influx_mode over join query (explain)
--Testcase 468:
EXPLAIN VERBOSE
SELECT influx_mode(t1.value1), influx_mode(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select influx_mode over join query (result, stub call error)
--Testcase 469:
SELECT influx_mode(t1.value1), influx_mode(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select influx_mode with having (explain)
--Testcase 470:
EXPLAIN VERBOSE
SELECT influx_mode(value1) FROM s3 HAVING influx_mode(value1) > 100 ORDER BY 1;

-- select influx_mode with having (explain, not pushdown, stub call error)
--Testcase 471:
SELECT influx_mode(value1) FROM s3 HAVING influx_mode(value1) > 100 ORDER BY 1;

-- select influx_mode(*) (stub agg function, explain)
--Testcase 472:
EXPLAIN VERBOSE
SELECT influx_mode_all(*) from s3 ORDER BY 1;

-- select influx_mode(*) (stub agg function, result)
--Testcase 473:
SELECT influx_mode_all(*) from s3 ORDER BY 1;

-- select influx_mode(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 474:
EXPLAIN VERBOSE
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_mode(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 475:
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_mode(*) (stub agg function and group by tag only) (explain)
--Testcase 476:
EXPLAIN VERBOSE
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_mode(*) (stub agg function and group by tag only) (result)
--Testcase 477:
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_mode(*) (stub agg function, expose data, explain)
--Testcase 478:
EXPLAIN VERBOSE
SELECT (influx_mode_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_mode(*) (stub agg function, expose data, result)
--Testcase 479:
SELECT (influx_mode_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_mode(regex) (stub function, explain)
--Testcase 480:
EXPLAIN VERBOSE
SELECT influx_mode('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_mode(regex) (stub function, result)
--Testcase 481:
SELECT influx_mode('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_mode(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 482:
EXPLAIN VERBOSE
SELECT influx_mode('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_mode(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 483:
SELECT influx_mode('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_mode(regex) (stub agg function and group by tag only) (explain)
--Testcase 484:
EXPLAIN VERBOSE
SELECT influx_mode('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_mode(regex) (stub agg function and group by tag only) (result)
--Testcase 485:
SELECT influx_mode('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_mode(regex) (stub agg function, expose data, explain)
--Testcase 486:
EXPLAIN VERBOSE
SELECT (influx_mode('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select influx_mode(regex) (stub agg function, expose data, result)
--Testcase 487:
SELECT (influx_mode('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select stddev (agg function, explain)
--Testcase 488:
EXPLAIN VERBOSE
SELECT stddev(value1),stddev(value2),stddev(value3),stddev(value4) FROM s3 ORDER BY 1;

-- select stddev (agg function, result)
--Testcase 489:
SELECT stddev(value1),stddev(value2),stddev(value3),stddev(value4) FROM s3 ORDER BY 1;

-- select stddev (agg function and group by influx_time() and tag) (explain)
--Testcase 490:
EXPLAIN VERBOSE
SELECT stddev("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select stddev (agg function and group by influx_time() and tag) (result)
--Testcase 491:
SELECT stddev("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select stddev (agg function and group by tag only) (result)
--Testcase 492:
SELECT tag1,stddev("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select stddev (agg function and other aggs) (result)
--Testcase 493:
SELECT sum("value1"),stddev("value1"),count("value1") FROM s3 ORDER BY 1;

-- select stddev(*) (stub agg function, explain)
--Testcase 494:
EXPLAIN VERBOSE
SELECT stddev_all(*) from s3 ORDER BY 1;

-- select stddev(*) (stub agg function, result)
--Testcase 495:
SELECT stddev_all(*) from s3 ORDER BY 1;

-- select stddev(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 496:
EXPLAIN VERBOSE
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select stddev(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 497:
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select stddev(*) (stub agg function and group by tag only) (explain)
--Testcase 498:
EXPLAIN VERBOSE
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select stddev(*) (stub agg function and group by tag only) (result)
--Testcase 499:
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select stddev(regex) (stub function, explain)
--Testcase 500:
EXPLAIN VERBOSE
SELECT stddev('/value[1,4]/') from s3 ORDER BY 1;

-- select stddev(regex) (stub function, result)
--Testcase 501:
SELECT stddev('/value[1,4]/') from s3 ORDER BY 1;

-- select stddev(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 502:
EXPLAIN VERBOSE
SELECT stddev('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select stddev(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 503:
SELECT stddev('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select stddev(regex) (stub agg function and group by tag only) (explain)
--Testcase 504:
EXPLAIN VERBOSE
SELECT stddev('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select stddev(regex) (stub agg function and group by tag only) (result)
--Testcase 505:
SELECT stddev('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_sum(*) (stub agg function, explain)
--Testcase 506:
EXPLAIN VERBOSE
SELECT influx_sum_all(*) from s3 ORDER BY 1;

-- select influx_sum(*) (stub agg function, result)
--Testcase 507:
SELECT influx_sum_all(*) from s3 ORDER BY 1;

-- select influx_sum(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 508:
EXPLAIN VERBOSE
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_sum(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 509:
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_sum(*) (stub agg function and group by tag only) (explain)
--Testcase 510:
EXPLAIN VERBOSE
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_sum(*) (stub agg function and group by tag only) (result)
--Testcase 511:
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_sum(*) (stub agg function, expose data, explain)
--Testcase 512:
EXPLAIN VERBOSE
SELECT (influx_sum_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_sum(*) (stub agg function, expose data, result)
--Testcase 513:
SELECT (influx_sum_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_sum(regex) (stub function, explain)
--Testcase 514:
EXPLAIN VERBOSE
SELECT influx_sum('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_sum(regex) (stub function, result)
--Testcase 515:
SELECT influx_sum('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_sum(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 516:
EXPLAIN VERBOSE
SELECT influx_sum('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_sum(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 517:
SELECT influx_sum('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_sum(regex) (stub agg function and group by tag only) (explain)
--Testcase 518:
EXPLAIN VERBOSE
SELECT influx_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_sum(regex) (stub agg function and group by tag only) (result)
--Testcase 519:
SELECT influx_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_sum(regex) (stub agg function, expose data, explain)
--Testcase 520:
EXPLAIN VERBOSE
SELECT (influx_sum('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select influx_sum(regex) (stub agg function, expose data, result)
--Testcase 521:
SELECT (influx_sum('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- selector function bottom() (explain)
--Testcase 522:
EXPLAIN VERBOSE
SELECT bottom(value1, 1) FROM s3 ORDER BY 1;

-- selector function bottom() (result)
--Testcase 523:
SELECT bottom(value1, 1) FROM s3 ORDER BY 1;

-- selector function bottom() cannot be combined with other functions(explain)
--Testcase 524:
EXPLAIN VERBOSE
SELECT bottom(value1, 1), bottom(value2, 1), bottom(value3, 1), bottom(value4, 1) FROM s3 ORDER BY 1;

-- selector function bottom() cannot be combined with other functions(result)
--SELECT bottom(value1, 1), bottom(value2, 1), bottom(value3, 1), bottom(value4, 1) FROM s3 ORDER BY 1;

-- select influx_max(*) (stub agg function, explain)
--Testcase 525:
EXPLAIN VERBOSE
SELECT influx_max_all(*) from s3 ORDER BY 1;

-- select influx_max(*) (stub agg function, result)
--Testcase 526:
SELECT influx_max_all(*) from s3 ORDER BY 1;

-- select influx_max(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 527:
EXPLAIN VERBOSE
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_max(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 528:
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_max(*) (stub agg function and group by tag only) (explain)
--Testcase 529:
EXPLAIN VERBOSE
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_max(*) (stub agg function and group by tag only) (result)
--Testcase 530:
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_max(*) (stub agg function, expose data, explain)
--Testcase 531:
EXPLAIN VERBOSE
SELECT (influx_max_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_max(*) (stub agg function, expose data, result)
--Testcase 532:
SELECT (influx_max_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_max(regex) (stub function, explain)
--Testcase 533:
EXPLAIN VERBOSE
SELECT influx_max('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_max(regex) (stub function, result)
--Testcase 534:
SELECT influx_max('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_max(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 535:
EXPLAIN VERBOSE
SELECT influx_max('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_max(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 536:
SELECT influx_max('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_max(regex) (stub agg function and group by tag only) (explain)
--Testcase 537:
EXPLAIN VERBOSE
SELECT influx_max('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_max(regex) (stub agg function and group by tag only) (result)
--Testcase 538:
SELECT influx_max('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_max(regex) (stub agg function, expose data, explain)
--Testcase 539:
EXPLAIN VERBOSE
SELECT (influx_max('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select influx_max(regex) (stub agg function, expose data, result)
--Testcase 540:
SELECT (influx_max('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select influx_min(*) (stub agg function, explain)
--Testcase 541:
EXPLAIN VERBOSE
SELECT influx_min_all(*) from s3 ORDER BY 1;

-- select influx_min(*) (stub agg function, result)
--Testcase 542:
SELECT influx_min_all(*) from s3 ORDER BY 1;

-- select influx_min(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 543:
EXPLAIN VERBOSE
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_min(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 544:
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_min(*) (stub agg function and group by tag only) (explain)
--Testcase 545:
EXPLAIN VERBOSE
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_min(*) (stub agg function and group by tag only) (result)
--Testcase 546:
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_min(*) (stub agg function, expose data, explain)
--Testcase 547:
EXPLAIN VERBOSE
SELECT (influx_min_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_min(*) (stub agg function, expose data, result)
--Testcase 548:
SELECT (influx_min_all(*)::s3).* from s3 ORDER BY 1;

-- select influx_min(regex) (stub function, explain)
--Testcase 549:
EXPLAIN VERBOSE
SELECT influx_min('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_min(regex) (stub function, result)
--Testcase 550:
SELECT influx_min('/value[1,4]/') from s3 ORDER BY 1;

-- select influx_min(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 551:
EXPLAIN VERBOSE
SELECT influx_min('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_min(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 552:
SELECT influx_min('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select influx_min(regex) (stub agg function and group by tag only) (explain)
--Testcase 553:
EXPLAIN VERBOSE
SELECT influx_min('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_min(regex) (stub agg function and group by tag only) (result)
--Testcase 554:
SELECT influx_min('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select influx_min(regex) (stub agg function, expose data, explain)
--Testcase 555:
EXPLAIN VERBOSE
SELECT (influx_min('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- select influx_min(regex) (stub agg function, expose data, result)
--Testcase 556:
SELECT (influx_min('/value[1,4]/')::s3).* from s3 ORDER BY 1;

-- selector function percentile() (explain)
--Testcase 557:
EXPLAIN VERBOSE
SELECT percentile(value1, 50), percentile(value2, 60), percentile(value3, 25), percentile(value4, 33) FROM s3 ORDER BY 1;

-- selector function percentile() (result)
--Testcase 558:
SELECT * FROM (
SELECT percentile(value1, 50), percentile(value2, 60), percentile(value3, 25), percentile(value4, 33) FROM s3
) as t ORDER BY 1, 2, 3, 4;

-- selector function percentile() (explain)
--Testcase 559:
EXPLAIN VERBOSE
SELECT percentile(value1, 1.5), percentile(value2, 6.7), percentile(value3, 20.5), percentile(value4, 75.2) FROM s3 ORDER BY 1, 2, 3, 4;

-- selector function percentile() (result)
--Testcase 560:
SELECT percentile(value1, 1.5), percentile(value2, 6.7), percentile(value3, 20.5), percentile(value4, 75.2) FROM s3 ORDER BY 1, 2, 3, 4;

-- select percentile(*, int) (stub function, explain)
--Testcase 561:
EXPLAIN VERBOSE
SELECT percentile_all(50) from s3 ORDER BY 1;

-- select percentile(*, int) (stub function, result)
--Testcase 562:
SELECT * FROM (
SELECT percentile_all(50) from s3
) as t ORDER BY 1;

-- select percentile(*, float8) (stub function, explain)
--Testcase 563:
EXPLAIN VERBOSE
SELECT percentile_all(70.5) from s3 ORDER BY 1;

-- select percentile(*, float8) (stub function, result)
--Testcase 564:
SELECT percentile_all(70.5) from s3 ORDER BY 1;

-- select percentile(*, int) (stub function and group by influx_time() and tag) (explain)
--Testcase 565:
EXPLAIN VERBOSE
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select percentile(*, int) (stub function and group by influx_time() and tag) (result)
--Testcase 566:
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select percentile(*, float8) (stub function and group by influx_time() and tag) (explain)
--Testcase 567:
EXPLAIN VERBOSE
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select percentile(*, float8) (stub function and group by influx_time() and tag) (result)
--Testcase 568:
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select percentile(*, int) (stub function and group by tag only) (explain)
--Testcase 569:
EXPLAIN VERBOSE
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select percentile(*, int) (stub function and group by tag only) (result)
--Testcase 570:
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select percentile(*, float8) (stub function and group by tag only) (explain)
--Testcase 571:
EXPLAIN VERBOSE
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select percentile(*, float8) (stub function and group by tag only) (result)
--Testcase 572:
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select percentile(*, int) (stub function, expose data, explain)
--Testcase 573:
EXPLAIN VERBOSE
SELECT (percentile_all(50)::s3).* from s3 ORDER BY 1, 2, 3, 4;

-- select percentile(*, int) (stub function, expose data, result)
--Testcase 574:
SELECT * FROM (
SELECT (percentile_all(50)::s3).* from s3
) as t ORDER BY 1, 2, 3, 4;

-- select percentile(*, int) (stub function, expose data, explain)
--Testcase 575:
EXPLAIN VERBOSE
SELECT (percentile_all(70.5)::s3).* from s3 ORDER BY 1, 2, 3, 4;

-- select percentile(*, int) (stub function, expose data, result)
--Testcase 576:
SELECT * FROM (
SELECT (percentile_all(70.5)::s3).* from s3
) as t ORDER BY 1, 2, 3, 4;

-- select percentile(regex) (stub function, explain)
--Testcase 577:
EXPLAIN VERBOSE
SELECT percentile('/value[1,4]/', 50) from s3 ORDER BY 1;

-- select percentile(regex) (stub function, result)
--Testcase 578:
SELECT percentile('/value[1,4]/', 50) from s3 ORDER BY 1;

-- select percentile(regex) (stub function and group by influx_time() and tag) (explain)
--Testcase 579:
EXPLAIN VERBOSE
SELECT percentile('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select percentile(regex) (stub function and group by influx_time() and tag) (result)
--Testcase 580:
SELECT percentile('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select percentile(regex) (stub function and group by tag only) (explain)
--Testcase 581:
EXPLAIN VERBOSE
SELECT percentile('/value[1,4]/', 70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select percentile(regex) (stub function and group by tag only) (result)
--Testcase 582:
SELECT percentile('/value[1,4]/', 70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select percentile(regex) (stub function, expose data, explain)
--Testcase 583:
EXPLAIN VERBOSE
SELECT (percentile('/value[1,4]/', 50)::s3).* from s3 ORDER BY 1, 2, 3, 4;

-- select percentile(regex) (stub function, expose data, result)
--Testcase 584:
SELECT * FROM (
SELECT (percentile('/value[1,4]/', 50)::s3).* from s3
) as t ORDER BY 1, 2, 3, 4;

-- select percentile(regex) (stub function, expose data, explain)
--Testcase 585:
EXPLAIN VERBOSE
SELECT (percentile('/value[1,4]/', 70.5)::s3).* from s3 ORDER BY 1, 2, 3, 4;

-- select percentile(regex) (stub function, expose data, result)
--Testcase 586:
SELECT * FROM (
SELECT (percentile('/value[1,4]/', 70.5)::s3).* from s3
) as t ORDER BY 1, 2, 3, 4;

-- selector function top(field_key,N) (explain)
--Testcase 587:
EXPLAIN VERBOSE
SELECT top(value1, 1) FROM s3 ORDER BY 1;

-- selector function top(field_key,N) (result)
--Testcase 588:
SELECT top(value1, 1) FROM s3 ORDER BY 1;

-- selector function top(field_key,tag_key(s),N) (explain)
--Testcase 589:
EXPLAIN VERBOSE
SELECT top(value1, tag1, 1) FROM s3 ORDER BY 1;

-- selector function top(field_key,tag_key(s),N) (result)
--Testcase 590:
SELECT top(value1, tag1, 1) FROM s3 ORDER BY 1;

-- selector function top() cannot be combined with other functions(explain)
--Testcase 591:
EXPLAIN VERBOSE
SELECT top(value1, 1), top(value2, 1), top(value3, 1), top(value4, 1) FROM s3 ORDER BY 1;

-- selector function top() cannot be combined with other functions(result)
--SELECT top(value1, 1), top(value2, 1), top(value3, 1), top(value4, 1) FROM s3 ORDER BY 1;

-- select acos (builtin function, explain)
--Testcase 592:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 ORDER BY 1;

-- select acos (builtin function, result)
--Testcase 593:
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 ORDER BY 1;

-- select acos (builtin function, not pushdown constraints, explain)
--Testcase 594:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 WHERE to_hex(value2) = '64' ORDER BY 1;

-- select acos (builtin function, not pushdown constraints, result)
--Testcase 595:
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 WHERE to_hex(value2) = '64' ORDER BY 1;

-- select acos (builtin function, pushdown constraints, explain)
--Testcase 596:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select acos (builtin function, pushdown constraints, result)
--Testcase 597:
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select acos as nest function with agg (pushdown, explain)
--Testcase 598:
EXPLAIN VERBOSE
SELECT sum(value3),acos(sum(value3)) FROM s3 ORDER BY 1;

-- select acos as nest function with agg (pushdown, result)
--Testcase 599:
SELECT sum(value3),acos(sum(value3)) FROM s3 ORDER BY 1;

-- select acos as nest with log2 (pushdown, explain)
--Testcase 600:
EXPLAIN VERBOSE
SELECT acos(log2(value1)),acos(log2(1/value1)) FROM s3;

-- select acos as nest with log2 (pushdown, result)
--Testcase 601:
SELECT * FROM (
SELECT acos(log2(value1)),acos(log2(1/value1)) FROM s3
) as t ORDER BY 1, 2;

-- select acos with non pushdown func and explicit constant (explain)
--Testcase 602:
EXPLAIN VERBOSE
SELECT acos(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select acos with non pushdown func and explicit constant (result)
--Testcase 603:
SELECT * FROM (
SELECT acos(value3), pi(), 4.1 FROM s3
) as t ORDER BY 1;

-- select acos with order by (explain)
--Testcase 604:
EXPLAIN VERBOSE
SELECT value1, acos(1-value1) FROM s3 ORDER BY acos(1-value1);

-- select acos with order by (result)
--Testcase 605:
SELECT value1, acos(1-value1) FROM s3 ORDER BY acos(1-value1);

-- select acos with order by index (result)
--Testcase 606:
SELECT value1, acos(1-value1) FROM s3 ORDER BY 2,1;

-- select acos with order by index (result)
--Testcase 607:
SELECT value1, acos(1-value1) FROM s3 ORDER BY 1,2;

-- select acos and as
--Testcase 608:
SELECT acos(value3) as acos1 FROM s3 ORDER BY 1;

-- select acos(*) (stub function, explain)
--Testcase 609:
EXPLAIN VERBOSE
SELECT acos_all() from s3 ORDER BY 1;

-- select acos(*) (stub function, result)
--Testcase 610:
SELECT * FROM (
SELECT acos_all() from s3
) as t ORDER BY 1;

-- select acos(*) (stub function and group by tag only) (explain)
--Testcase 611:
EXPLAIN VERBOSE
SELECT acos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select acos(*) (stub function and group by tag only) (result)
--Testcase 612:
SELECT acos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select acos(*) (stub function, expose data, explain)
--Testcase 613:
EXPLAIN VERBOSE
SELECT (acos_all()::s3).* from s3 ORDER BY 1;

-- select acos(*) (stub function, expose data, result)
--Testcase 614:
SELECT * FROM (
SELECT (acos_all()::s3).* from s3
) as t ORDER BY 1;

-- select asin (builtin function, explain)
--Testcase 615:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 ORDER BY 1;

-- select asin (builtin function, result)
--Testcase 616:
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 ORDER BY 1;

-- select asin (builtin function, not pushdown constraints, explain)
--Testcase 617:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 WHERE to_hex(value2) = '64' ORDER BY 1;

-- select asin (builtin function, not pushdown constraints, result)
--Testcase 618:
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 WHERE to_hex(value2) = '64' ORDER BY 1;

-- select asin (builtin function, pushdown constraints, explain)
--Testcase 619:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select asin (builtin function, pushdown constraints, result)
--Testcase 620:
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select asin as nest function with agg (pushdown, explain)
--Testcase 621:
EXPLAIN VERBOSE
SELECT sum(value3),asin(sum(value3)) FROM s3 ORDER BY 1;

-- select asin as nest function with agg (pushdown, result)
--Testcase 622:
SELECT sum(value3),asin(sum(value3)) FROM s3 ORDER BY 1;

-- select asin as nest with log2 (pushdown, explain)
--Testcase 623:
EXPLAIN VERBOSE
SELECT asin(log2(value1)),asin(log2(1/value1)) FROM s3;

-- select asin as nest with log2 (pushdown, result)
--Testcase 624:
SELECT * FROM (
SELECT asin(log2(value1)),asin(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select asin with non pushdown func and explicit constant (explain)
--Testcase 625:
EXPLAIN VERBOSE
SELECT asin(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select asin with non pushdown func and explicit constant (result)
--Testcase 626:
SELECT asin(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select asin with order by (explain)
--Testcase 627:
EXPLAIN VERBOSE
SELECT value1, asin(1-value1) FROM s3 ORDER BY asin(1-value1);

-- select asin with order by (result)
--Testcase 628:
SELECT value1, asin(1-value1) FROM s3 ORDER BY asin(1-value1);

-- select asin with order by index (result)
--Testcase 629:
SELECT value1, asin(1-value1) FROM s3 ORDER BY 2,1;

-- select asin with order by index (result)
--Testcase 630:
SELECT value1, asin(1-value1) FROM s3 ORDER BY 1,2;

-- select asin and as
--Testcase 631:
SELECT asin(value3) as asin1 FROM s3 ORDER BY 1;

-- select asin(*) (stub function, explain)
--Testcase 632:
EXPLAIN VERBOSE
SELECT asin_all() from s3 ORDER BY 1;

-- select asin(*) (stub function, result)
--Testcase 633:
SELECT * FROM (
SELECT asin_all() from s3
) as t ORDER BY 1;

-- select asin(*) (stub function and group by tag only) (explain)
--Testcase 634:
EXPLAIN VERBOSE
SELECT asin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select asin(*) (stub function and group by tag only) (result)
--Testcase 635:
SELECT asin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select asin(*) (stub function, expose data, explain)
--Testcase 636:
EXPLAIN VERBOSE
SELECT (asin_all()::s3).* from s3 ORDER BY 1;

-- select asin(*) (stub function, expose data, result)
--Testcase 637:
SELECT * FROM (
SELECT (asin_all()::s3).* from s3
) as t ORDER BY 1;

-- select atan (builtin function, explain)
--Testcase 638:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 ORDER BY 1;

-- select atan (builtin function, result)
--Testcase 639:
SELECT * FROM (
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3
) as t ORDER BY 1;

-- select atan (builtin function, not pushdown constraints, explain)
--Testcase 640:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select atan (builtin function, not pushdown constraints, result)
--Testcase 641:
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select atan (builtin function, pushdown constraints, explain)
--Testcase 642:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select atan (builtin function, pushdown constraints, result)
--Testcase 643:
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select atan as nest function with agg (pushdown, explain)
--Testcase 644:
EXPLAIN VERBOSE
SELECT sum(value3),atan(sum(value3)) FROM s3 ORDER BY 1;

-- select atan as nest function with agg (pushdown, result)
--Testcase 645:
SELECT sum(value3),atan(sum(value3)) FROM s3 ORDER BY 1;

-- select atan as nest with log2 (pushdown, explain)
--Testcase 646:
EXPLAIN VERBOSE
SELECT atan(log2(value1)),atan(log2(1/value1)) FROM s3;

-- select atan as nest with log2 (pushdown, result)
--Testcase 647:
SELECT * FROM (
SELECT atan(log2(value1)),atan(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select atan with non pushdown func and explicit constant (explain)
--Testcase 648:
EXPLAIN VERBOSE
SELECT atan(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select atan with non pushdown func and explicit constant (result)
--Testcase 649:
SELECT atan(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select atan with order by (explain)
--Testcase 650:
EXPLAIN VERBOSE
SELECT value1, atan(1-value1) FROM s3 ORDER BY atan(1-value1);

-- select atan with order by (result)
--Testcase 651:
SELECT value1, atan(1-value1) FROM s3 ORDER BY atan(1-value1);

-- select atan with order by index (result)
--Testcase 652:
SELECT value1, atan(1-value1) FROM s3 ORDER BY 2,1;

-- select atan with order by index (result)
--Testcase 653:
SELECT value1, atan(1-value1) FROM s3 ORDER BY 1,2;

-- select atan and as
--Testcase 654:
SELECT * FROM (
SELECT atan(value3) as atan1 FROM s3
) as t ORDER BY 1;

-- select atan(*) (stub function, explain)
--Testcase 655:
EXPLAIN VERBOSE
SELECT atan_all() from s3 ORDER BY 1;

-- select atan(*) (stub function, result)
--Testcase 656:
SELECT * FROM (
SELECT atan_all() from s3
) as t ORDER BY 1;

-- select atan(*) (stub function and group by tag only) (explain)
--Testcase 657:
EXPLAIN VERBOSE
SELECT atan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select atan(*) (stub function and group by tag only) (result)
--Testcase 658:
SELECT atan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select atan(*) (stub function, expose data, explain)
--Testcase 659:
EXPLAIN VERBOSE
SELECT (atan_all()::s3).* from s3 ORDER BY 1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--SELECT asin_all(), acos_all(), atan_all() FROM s3 ORDER BY 1;

-- select atan2 (builtin function, explain)
--Testcase 660:
EXPLAIN VERBOSE
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 ORDER BY 1;

-- select atan2 (builtin function, result)
--Testcase 661:
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 ORDER BY 1;

-- select atan2 (builtin function, not pushdown constraints, explain)
--Testcase 662:
EXPLAIN VERBOSE
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select atan2 (builtin function, not pushdown constraints, result)
--Testcase 663:
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select atan2 (builtin function, pushdown constraints, explain)
--Testcase 664:
EXPLAIN VERBOSE
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select atan2 (builtin function, pushdown constraints, result)
--Testcase 665:
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select atan2 as nest function with agg (pushdown, explain)
--Testcase 666:
EXPLAIN VERBOSE
SELECT sum(value3), sum(value4),atan2(sum(value3), sum(value3)) FROM s3 ORDER BY 1;

-- select atan2 as nest function with agg (pushdown, result)
--Testcase 667:
SELECT sum(value3), sum(value4),atan2(sum(value3), sum(value3)) FROM s3 ORDER BY 1;

-- select atan2 as nest with log2 (pushdown, explain)
--Testcase 668:
EXPLAIN VERBOSE
SELECT atan2(log2(value1), log2(value1)),atan2(log2(1/value1), log2(1/value1)) FROM s3;

-- select atan2 as nest with log2 (pushdown, result)
--Testcase 669:
SELECT * FROM (
SELECT atan2(log2(value1), log2(value1)),atan2(log2(1/value1), log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select atan2 with non pushdown func and explicit constant (explain)
--Testcase 670:
EXPLAIN VERBOSE
SELECT atan2(value3, value4), pi(), 4.1 FROM s3 ORDER BY 1;

-- select atan2 with non pushdown func and explicit constant (result)
--Testcase 671:
SELECT atan2(value3, value4), pi(), 4.1 FROM s3 ORDER BY 1;

-- select atan2 with order by (explain)
--Testcase 672:
EXPLAIN VERBOSE
SELECT value1, atan2(1-value1, 1-value2) FROM s3 ORDER BY atan2(1-value1, 1-value2);

-- select atan2 with order by (result)
--Testcase 673:
SELECT value1, atan2(1-value1, 1-value2) FROM s3 ORDER BY atan2(1-value1, 1-value2);

-- select atan2 with order by index (result)
--Testcase 674:
SELECT value1, atan2(1-value1, 1-value2) FROM s3 ORDER BY 2,1;

-- select atan2 with order by index (result)
--Testcase 675:
SELECT value1, atan2(1-value1, 1-value2) FROM s3 ORDER BY 1,2;

-- select atan2 and as
--Testcase 676:
SELECT atan2(value3, value4) as atan21 FROM s3 ORDER BY 1;

-- select atan2(*) (stub function, explain)
--Testcase 677:
EXPLAIN VERBOSE
SELECT atan2_all(value1) from s3 ORDER BY 1;

-- select atan2(*) (stub function, result)
--Testcase 678:
SELECT * FROM (
SELECT atan2_all(value1) from s3
) as t ORDER BY 1;

-- select ceil (builtin function, explain)
--Testcase 679:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 ORDER BY 1;

-- select ceil (builtin function, result)
--Testcase 680:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 ORDER BY 1;

-- select ceil (builtin function, not pushdown constraints, explain)
--Testcase 681:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select ceil (builtin function, not pushdown constraints, result)
--Testcase 682:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select ceil (builtin function, pushdown constraints, explain)
--Testcase 683:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select ceil (builtin function, pushdown constraints, result)
--Testcase 684:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select ceil as nest function with agg (pushdown, explain)
--Testcase 685:
EXPLAIN VERBOSE
SELECT sum(value3),ceil(sum(value3)) FROM s3 ORDER BY 1;

-- select ceil as nest function with agg (pushdown, result)
--Testcase 686:
SELECT sum(value3),ceil(sum(value3)) FROM s3 ORDER BY 1;

-- select ceil as nest with log2 (pushdown, explain)
--Testcase 687:
EXPLAIN VERBOSE
SELECT ceil(log2(value1)),ceil(log2(1/value1)) FROM s3;

-- select ceil as nest with log2 (pushdown, result)
--Testcase 688:
SELECT * FROM (
SELECT ceil(log2(value1)),ceil(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select ceil with non pushdown func and explicit constant (explain)
--Testcase 689:
EXPLAIN VERBOSE
SELECT ceil(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select ceil with non pushdown func and explicit constant (result)
--Testcase 690:
SELECT * FROM (
SELECT ceil(value3), pi(), 4.1 FROM s3
) as t ORDER BY 1;

-- select ceil with order by (explain)
--Testcase 691:
EXPLAIN VERBOSE
SELECT value1, ceil(1-value1) FROM s3 ORDER BY ceil(1-value1);

-- select ceil with order by (result)
--Testcase 692:
SELECT value1, ceil(1-value1) FROM s3 ORDER BY ceil(1-value1);

-- select ceil with order by index (result)
--Testcase 693:
SELECT value1, ceil(1-value1) FROM s3 ORDER BY 2,1;

-- select ceil with order by index (result)
--Testcase 694:
SELECT value1, ceil(1-value1) FROM s3 ORDER BY 1,2;

-- select ceil and as
--Testcase 695:
SELECT * FROM (
SELECT ceil(value3) as ceil1 FROM s3
) as t ORDER BY 1;

-- select ceil(*) (stub function, explain)
--Testcase 696:
EXPLAIN VERBOSE
SELECT ceil_all() from s3 ORDER BY 1;

-- select ceil(*) (stub function, result)
--Testcase 697:
SELECT * FROM (
SELECT ceil_all() from s3
) as t ORDER BY 1;

-- select ceil(*) (stub function and group by tag only) (explain)
--Testcase 698:
EXPLAIN VERBOSE
SELECT ceil_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select ceil(*) (stub function and group by tag only) (result)
--Testcase 699:
SELECT ceil_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select ceil(*) (stub function, expose data, explain)
--Testcase 700:
EXPLAIN VERBOSE
SELECT (ceil_all()::s3).* from s3 ORDER BY 1;

-- select ceil(*) (stub function, expose data, result)
--Testcase 701:
SELECT * FROM (
SELECT (ceil_all()::s3).* from s3
) as t ORDER BY 1;

-- select cos (builtin function, explain)
--Testcase 702:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 ORDER BY 1;

-- select cos (builtin function, result)
--Testcase 703:
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 ORDER BY 1;

-- select cos (builtin function, not pushdown constraints, explain)
--Testcase 704:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select cos (builtin function, not pushdown constraints, result)
--Testcase 705:
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select cos (builtin function, pushdown constraints, explain)
--Testcase 706:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select cos (builtin function, pushdown constraints, result)
--Testcase 707:
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select cos as nest function with agg (pushdown, explain)
--Testcase 708:
EXPLAIN VERBOSE
SELECT sum(value3),cos(sum(value3)) FROM s3 ORDER BY 1;

-- select cos as nest function with agg (pushdown, result)
--Testcase 709:
SELECT sum(value3),cos(sum(value3)) FROM s3 ORDER BY 1;

-- select cos as nest with log2 (pushdown, explain)
--Testcase 710:
EXPLAIN VERBOSE
SELECT cos(log2(value1)),cos(log2(1/value1)) FROM s3;

-- select cos as nest with log2 (pushdown, result)
--Testcase 711:
SELECT * FROM (
SELECT cos(log2(value1)),cos(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select cos with non pushdown func and explicit constant (explain)
--Testcase 712:
EXPLAIN VERBOSE
SELECT cos(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select cos with non pushdown func and explicit constant (result)
--Testcase 713:
SELECT cos(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select cos with order by (explain)
--Testcase 714:
EXPLAIN VERBOSE
SELECT value1, cos(1-value1) FROM s3 ORDER BY cos(1-value1);

-- select cos with order by (result)
--Testcase 715:
SELECT value1, cos(1-value1) FROM s3 ORDER BY cos(1-value1);

-- select cos with order by index (result)
--Testcase 716:
SELECT value1, cos(1-value1) FROM s3 ORDER BY 2,1;

-- select cos with order by index (result)
--Testcase 717:
SELECT value1, cos(1-value1) FROM s3 ORDER BY 1,2;

-- select cos and as
--Testcase 718:
SELECT cos(value3) as cos1 FROM s3 ORDER BY 1;

-- select cos(*) (stub function, explain)
--Testcase 719:
EXPLAIN VERBOSE
SELECT cos_all() from s3 ORDER BY 1;

-- select cos(*) (stub function, result)
--Testcase 720:
SELECT * FROM (
SELECT cos_all() from s3
) as t ORDER BY 1;

-- select cos(*) (stub function and group by tag only) (explain)
--Testcase 721:
EXPLAIN VERBOSE
SELECT cos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select cos(*) (stub function and group by tag only) (result)
--Testcase 722:
SELECT cos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select exp (builtin function, explain)
--Testcase 723:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 ORDER BY 1;

-- select exp (builtin function, result)
--Testcase 724:
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 ORDER BY 1;

-- select exp (builtin function, not pushdown constraints, explain)
--Testcase 725:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select exp (builtin function, not pushdown constraints, result)
--Testcase 726:
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select exp (builtin function, pushdown constraints, explain)
--Testcase 727:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select exp (builtin function, pushdown constraints, result)
--Testcase 728:
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select exp as nest function with agg (pushdown, explain)
--Testcase 729:
EXPLAIN VERBOSE
SELECT sum(value3),exp(sum(value3)) FROM s3 ORDER BY 1;

-- select exp as nest function with agg (pushdown, result)
--Testcase 730:
SELECT sum(value3),exp(sum(value3)) FROM s3 ORDER BY 1;

-- select exp as nest with log2 (pushdown, explain)
--Testcase 731:
EXPLAIN VERBOSE
SELECT exp(log2(value1)),exp(log2(1/value1)) FROM s3;

-- select exp as nest with log2 (pushdown, result)
--Testcase 732:
SELECT * FROM (
SELECT exp(log2(value1)),exp(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select exp with non pushdown func and explicit constant (explain)
--Testcase 733:
EXPLAIN VERBOSE
SELECT exp(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select exp with non pushdown func and explicit constant (result)
--Testcase 734:
SELECT exp(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select exp with order by (explain)
--Testcase 735:
EXPLAIN VERBOSE
SELECT value1, exp(1-value1) FROM s3 ORDER BY exp(1-value1);

-- select exp with order by (result)
--Testcase 736:
SELECT value1, exp(1-value1) FROM s3 ORDER BY exp(1-value1);

-- select exp with order by index (result)
--Testcase 737:
SELECT value1, exp(1-value1) FROM s3 ORDER BY 2,1;

-- select exp with order by index (result)
--Testcase 738:
SELECT value1, exp(1-value1) FROM s3 ORDER BY 1,2;

-- select exp and as
--Testcase 739:
SELECT exp(value3) as exp1 FROM s3 ORDER BY 1;

-- select exp(*) (stub function, explain)
--Testcase 740:
EXPLAIN VERBOSE
SELECT exp_all() from s3 ORDER BY 1;

-- select exp(*) (stub function, result)
--Testcase 741:
SELECT * FROM (
SELECT exp_all() from s3
) as t ORDER BY 1;

-- select exp(*) (stub function and group by tag only) (explain)
--Testcase 742:
EXPLAIN VERBOSE
SELECT exp_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select exp(*) (stub function and group by tag only) (result)
--Testcase 743:
SELECT exp_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--SELECT ceil_all(), cos_all(), exp_all() FROM s3 ORDER BY 1;

-- select floor (builtin function, explain)
--Testcase 744:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 ORDER BY 1;

-- select floor (builtin function, result)
--Testcase 745:
SELECT * FROM (
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3
) as t ORDER BY 1, 2, 3, 4;

-- select floor (builtin function, not pushdown constraints, explain)
--Testcase 746:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select floor (builtin function, not pushdown constraints, result)
--Testcase 747:
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select floor (builtin function, pushdown constraints, explain)
--Testcase 748:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select floor (builtin function, pushdown constraints, result)
--Testcase 749:
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select floor as nest function with agg (pushdown, explain)
--Testcase 750:
EXPLAIN VERBOSE
SELECT sum(value3),floor(sum(value3)) FROM s3 ORDER BY 1;

-- select floor as nest function with agg (pushdown, result)
--Testcase 751:
SELECT sum(value3),floor(sum(value3)) FROM s3 ORDER BY 1;

-- select floor as nest with log2 (pushdown, explain)
--Testcase 752:
EXPLAIN VERBOSE
SELECT floor(log2(value1)),floor(log2(1/value1)) FROM s3;

-- select floor as nest with log2 (pushdown, result)
--Testcase 753:
SELECT * FROM (
SELECT floor(log2(value1)),floor(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select floor with non pushdown func and explicit constant (explain)
--Testcase 754:
EXPLAIN VERBOSE
SELECT floor(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select floor with non pushdown func and explicit constant (result)
--Testcase 755:
SELECT * FROM (
SELECT floor(value3), pi(), 4.1 FROM s3
) as t ORDER BY 1;

-- select floor with order by (explain)
--Testcase 756:
EXPLAIN VERBOSE
SELECT value1, floor(1-value1) FROM s3 ORDER BY floor(1-value1);

-- select floor with order by (result)
--Testcase 757:
SELECT value1, floor(1-value1) FROM s3 ORDER BY floor(1-value1);

-- select floor with order by index (result)
--Testcase 758:
SELECT value1, floor(1-value1) FROM s3 ORDER BY 2,1;

-- select floor with order by index (result)
--Testcase 759:
SELECT value1, floor(1-value1) FROM s3 ORDER BY 1,2;

-- select floor and as
--Testcase 760:
SELECT floor(value3) as floor1 FROM s3 ORDER BY 1;

-- select floor(*) (stub function, explain)
--Testcase 761:
EXPLAIN VERBOSE
SELECT floor_all() from s3 ORDER BY 1;

-- select floor(*) (stub function, result)
--Testcase 762:
SELECT * FROM (
SELECT floor_all() from s3
) as t ORDER BY 1;

-- select floor(*) (stub function and group by tag only) (explain)
--Testcase 763:
EXPLAIN VERBOSE
SELECT floor_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select floor(*) (stub function and group by tag only) (result)
--Testcase 764:
SELECT floor_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select floor(*) (stub function, expose data, explain)
--Testcase 765:
EXPLAIN VERBOSE
SELECT (floor_all()::s3).* from s3 ORDER BY 1;

-- select floor(*) (stub function, expose data, result)
--Testcase 766:
SELECT * FROM (
SELECT (floor_all()::s3).* from s3
) as t ORDER BY 1;

-- select ln (builtin function, explain)
--Testcase 767:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 ORDER BY 1;

-- select ln (builtin function, result)
--Testcase 768:
SELECT * FROM (
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3
) as t ORDER BY 1, 2, 3, 4;

-- select ln (builtin function, not pushdown constraints, explain)
--Testcase 769:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select ln (builtin function, not pushdown constraints, result)
--Testcase 770:
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select ln (builtin function, pushdown constraints, explain)
--Testcase 771:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select ln (builtin function, pushdown constraints, result)
--Testcase 772:
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select ln as nest function with agg (pushdown, explain)
--Testcase 773:
EXPLAIN VERBOSE
SELECT sum(value3),ln(sum(value3)) FROM s3 ORDER BY 1;

-- select ln as nest function with agg (pushdown, result)
--Testcase 774:
SELECT sum(value3),ln(sum(value3)) FROM s3 ORDER BY 1;

-- select ln as nest with log2 (pushdown, explain)
--Testcase 775:
EXPLAIN VERBOSE
SELECT ln(log2(value1)),ln(log2(1/value1)) FROM s3;

-- select ln as nest with log2 (pushdown, result)
--Testcase 776:
SELECT * FROM (
SELECT ln(log2(value1)),ln(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select ln with non pushdown func and explicit constant (explain)
--Testcase 777:
EXPLAIN VERBOSE
SELECT ln(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select ln with non pushdown func and explicit constant (result)
--Testcase 778:
SELECT ln(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select ln with order by (explain)
--Testcase 779:
EXPLAIN VERBOSE
SELECT value1, ln(1-value1) FROM s3 ORDER BY ln(1-value1);

-- select ln with order by (result)
--Testcase 780:
SELECT value1, ln(1-value1) FROM s3 ORDER BY ln(1-value1);

-- select ln with order by index (result)
--Testcase 781:
SELECT value1, ln(1-value1) FROM s3 ORDER BY 2,1;

-- select ln with order by index (result)
--Testcase 782:
SELECT value1, ln(1-value1) FROM s3 ORDER BY 1,2;

-- select ln and as
--Testcase 783:
SELECT ln(value1) as ln1 FROM s3 ORDER BY 1;

-- select ln(*) (stub function, explain)
--Testcase 784:
EXPLAIN VERBOSE
SELECT ln_all() from s3 ORDER BY 1;

-- select ln(*) (stub function, result)
--Testcase 785:
SELECT * FROM (
SELECT ln_all() from s3
) as t ORDER BY 1;

-- select ln(*) (stub function and group by tag only) (explain)
--Testcase 786:
EXPLAIN VERBOSE
SELECT ln_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select ln(*) (stub function and group by tag only) (result)
--Testcase 787:
SELECT ln_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--SELECT ln_all(), floor_all() FROM s3 ORDER BY 1;

-- select pow (builtin function, explain)
--Testcase 788:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 ORDER BY 1;

-- select pow (builtin function, result)
--Testcase 789:
SELECT * FROM (
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3
) as t ORDER BY 1, 2, 3, 4;

-- select pow (builtin function, not pushdown constraints, explain)
--Testcase 790:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select pow (builtin function, not pushdown constraints, result)
--Testcase 791:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select pow (builtin function, pushdown constraints, explain)
--Testcase 792:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select pow (builtin function, pushdown constraints, result)
--Testcase 793:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select pow as nest function with agg (pushdown, explain)
--Testcase 794:
EXPLAIN VERBOSE
SELECT sum(value3),pow(sum(value3), 2) FROM s3 ORDER BY 1;

-- select pow as nest function with agg (pushdown, result)
--Testcase 795:
SELECT sum(value3),pow(sum(value3), 2) FROM s3 ORDER BY 1;

-- select pow as nest with log2 (pushdown, explain)
--Testcase 796:
EXPLAIN VERBOSE
SELECT pow(log2(value1), 2),pow(log2(1/value1), 2) FROM s3;

-- select pow as nest with log2 (pushdown, result)
--Testcase 797:
SELECT * FROM (
SELECT pow(log2(value1), 2),pow(log2(1/value1), 2) FROM s3
) as t ORDER BY 1;

-- select pow with non pushdown func and explicit constant (explain)
--Testcase 798:
EXPLAIN VERBOSE
SELECT pow(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select pow with non pushdown func and explicit constant (result)
--Testcase 799:
SELECT pow(value3, 2), pi(), 4.1 FROM s3 ORDER BY 1;

-- select pow with order by (explain)
--Testcase 800:
EXPLAIN VERBOSE
SELECT value1, pow(1-value1, 2) FROM s3 ORDER BY pow(1-value1, 2);

-- select pow with order by (result)
--Testcase 801:
SELECT value1, pow(1-value1, 2) FROM s3 ORDER BY pow(1-value1, 2);

-- select pow with order by index (result)
--Testcase 802:
SELECT value1, pow(1-value1, 2) FROM s3 ORDER BY 2,1;

-- select pow with order by index (result)
--Testcase 803:
SELECT value1, pow(1-value1, 2) FROM s3 ORDER BY 1,2;

-- select pow and as
--Testcase 804:
SELECT * FROM (
SELECT pow(value3, 2) as pow1 FROM s3
) as t ORDER BY 1;

-- select pow_all(2) (stub function, explain)
--Testcase 805:
EXPLAIN VERBOSE
SELECT pow_all(2) from s3 ORDER BY 1;

-- select pow_all(2) (stub function, result)
--Testcase 806:
SELECT * FROM (
SELECT pow_all(2) from s3
) as t ORDER BY 1;

-- select pow_all(2) (stub function and group by tag only) (explain)
--Testcase 807:
EXPLAIN VERBOSE
SELECT pow_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select pow_all(2) (stub function and group by tag only) (result)
--Testcase 808:
SELECT pow_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select pow_all(2) (stub function, expose data, explain)
--Testcase 809:
EXPLAIN VERBOSE
SELECT (pow_all(2)::s3).* from s3 ORDER BY 1;

-- select pow_all(2) (stub function, expose data, result)
--Testcase 810:
SELECT * FROM (
SELECT (pow_all(2)::s3).* from s3
) as t ORDER BY 1;

-- select round (builtin function, explain)
--Testcase 811:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 ORDER BY 1;

-- select round (builtin function, result)
--Testcase 812:
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 ORDER BY 1;

-- select round (builtin function, not pushdown constraints, explain)
--Testcase 813:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select round (builtin function, not pushdown constraints, result)
--Testcase 814:
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select round (builtin function, pushdown constraints, explain)
--Testcase 815:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select round (builtin function, pushdown constraints, result)
--Testcase 816:
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select round as nest function with agg (pushdown, explain)
--Testcase 817:
EXPLAIN VERBOSE
SELECT sum(value3),round(sum(value3)) FROM s3 ORDER BY 1;

-- select round as nest function with agg (pushdown, result)
--Testcase 818:
SELECT sum(value3),round(sum(value3)) FROM s3 ORDER BY 1;

-- select round as nest with log2 (pushdown, explain)
--Testcase 819:
EXPLAIN VERBOSE
SELECT round(log2(value1)),round(log2(1/value1)) FROM s3;

-- select round as nest with log2 (pushdown, result)
--Testcase 820:
SELECT * FROM (
SELECT round(log2(value1)),round(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select round with non pushdown func and roundlicit constant (explain)
--Testcase 821:
EXPLAIN VERBOSE
SELECT round(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select round with non pushdown func and roundlicit constant (result)
--Testcase 822:
SELECT round(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select round with order by (explain)
--Testcase 823:
EXPLAIN VERBOSE
SELECT value1, round(1-value1) FROM s3 ORDER BY round(1-value1);

-- select round with order by (result)
--Testcase 824:
SELECT value1, round(1-value1) FROM s3 ORDER BY round(1-value1);

-- select round with order by index (result)
--Testcase 825:
SELECT value1, round(1-value1) FROM s3 ORDER BY 2,1;

-- select round with order by index (result)
--Testcase 826:
SELECT value1, round(1-value1) FROM s3 ORDER BY 1,2;

-- select round and as
--Testcase 827:
SELECT round(value3) as round1 FROM s3 ORDER BY 1;

-- select round(*) (stub function, explain)
--Testcase 828:
EXPLAIN VERBOSE
SELECT round_all() from s3 ORDER BY 1;

-- select round(*) (stub function, result)
--Testcase 829:
SELECT * FROM (
SELECT round_all() from s3
) as t ORDER BY 1;

-- select round(*) (stub function and group by tag only) (explain)
--Testcase 830:
EXPLAIN VERBOSE
SELECT round_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select round(*) (stub function and group by tag only) (result)
--Testcase 831:
SELECT round_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select round(*) (stub function, expose data, explain)
--Testcase 832:
EXPLAIN VERBOSE
SELECT (round_all()::s3).* from s3 ORDER BY 1;

-- select round(*) (stub function, expose data, result)
--Testcase 833:
SELECT * FROM (
SELECT (round_all()::s3).* from s3
) as t ORDER BY 1;

-- select sin (builtin function, explain)
--Testcase 834:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 ORDER BY 1;

-- select sin (builtin function, result)
--Testcase 835:
SELECT * FROM (
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3
) as t ORDER BY 1, 2, 3, 4;

-- select sin (builtin function, not pushdown constraints, explain)
--Testcase 836:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select sin (builtin function, not pushdown constraints, result)
--Testcase 837:
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select sin (builtin function, pushdown constraints, explain)
--Testcase 838:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select sin (builtin function, pushdown constraints, result)
--Testcase 839:
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select sin as nest function with agg (pushdown, explain)
--Testcase 840:
EXPLAIN VERBOSE
SELECT sum(value3),sin(sum(value3)) FROM s3 ORDER BY 1;

-- select sin as nest function with agg (pushdown, result)
--Testcase 841:
SELECT sum(value3),sin(sum(value3)) FROM s3 ORDER BY 1;

-- select sin as nest with log2 (pushdown, explain)
--Testcase 842:
EXPLAIN VERBOSE
SELECT sin(log2(value1)),sin(log2(1/value1)) FROM s3;

-- select sin as nest with log2 (pushdown, result)
--Testcase 843:
SELECT * FROM (
SELECT sin(log2(value1)),sin(log2(1/value1)) FROM s3
) as t ORDER BY 1;

-- select sin with non pushdown func and explicit constant (explain)
--Testcase 844:
EXPLAIN VERBOSE
SELECT sin(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select sin with non pushdown func and explicit constant (result)
--Testcase 845:
SELECT sin(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select sin with order by (explain)
--Testcase 846:
EXPLAIN VERBOSE
SELECT value1, sin(1-value1) FROM s3 ORDER BY sin(1-value1);

-- select sin with order by (result)
--Testcase 847:
SELECT value1, sin(1-value1) FROM s3 ORDER BY sin(1-value1);

-- select sin with order by index (result)
--Testcase 848:
SELECT value1, sin(1-value1) FROM s3 ORDER BY 2,1;

-- select sin with order by index (result)
--Testcase 849:
SELECT value1, sin(1-value1) FROM s3 ORDER BY 1,2;

-- select sin and as
--Testcase 850:
SELECT sin(value3) as sin1 FROM s3 ORDER BY 1;

-- select sin(*) (stub function, explain)
--Testcase 851:
EXPLAIN VERBOSE
SELECT sin_all() from s3 ORDER BY 1;

-- select sin(*) (stub function, result)
--Testcase 852:
SELECT * FROM (
SELECT sin_all() from s3
) as t ORDER BY 1;

-- select sin(*) (stub function and group by tag only) (explain)
--Testcase 853:
EXPLAIN VERBOSE
SELECT sin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select sin(*) (stub function and group by tag only) (result)
--Testcase 854:
SELECT sin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select tan (builtin function, explain)
--Testcase 855:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 ORDER BY 1;

-- select tan (builtin function, result)
--Testcase 856:
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 ORDER BY 1;

-- select tan (builtin function, not pushdown constraints, explain)
--Testcase 857:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select tan (builtin function, not pushdown constraints, result)
--Testcase 858:
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 WHERE to_hex(value2) != '64' ORDER BY 1;

-- select tan (builtin function, pushdown constraints, explain)
--Testcase 859:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select tan (builtin function, pushdown constraints, result)
--Testcase 860:
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select tan as nest function with agg (pushdown, explain)
--Testcase 861:
EXPLAIN VERBOSE
SELECT sum(value3),tan(sum(value3)) FROM s3 ORDER BY 1;

-- select tan as nest function with agg (pushdown, result)
--Testcase 862:
SELECT sum(value3),tan(sum(value3)) FROM s3 ORDER BY 1;

-- select tan as nest with log2 (pushdown, explain)
--Testcase 863:
EXPLAIN VERBOSE
SELECT tan(log2(value1)),tan(log2(1/value1)) FROM s3;

-- select tan as nest with log2 (pushdown, result)
--Testcase 864:
SELECT * FROM (
SELECT tan(log2(value1)),tan(log2(1/value1)) FROM s3
) as t ORDER BY 1, 2;

-- select tan with non pushdown func and tanlicit constant (explain)
--Testcase 865:
EXPLAIN VERBOSE
SELECT tan(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select tan with non pushdown func and tanlicit constant (result)
--Testcase 866:
SELECT tan(value3), pi(), 4.1 FROM s3 ORDER BY 1;

-- select tan with order by (explain)
--Testcase 867:
EXPLAIN VERBOSE
SELECT value1, tan(1-value1) FROM s3 ORDER BY tan(1-value1);

-- select tan with order by (result)
--Testcase 868:
SELECT value1, tan(1-value1) FROM s3 ORDER BY tan(1-value1);

-- select tan with order by index (result)
--Testcase 869:
SELECT value1, tan(1-value1) FROM s3 ORDER BY 2,1;

-- select tan with order by index (result)
--Testcase 870:
SELECT value1, tan(1-value1) FROM s3 ORDER BY 1,2;

-- select tan and as
--Testcase 871:
SELECT tan(value3) as tan1 FROM s3 ORDER BY 1;

-- select tan(*) (stub function, explain)
--Testcase 872:
EXPLAIN VERBOSE
SELECT tan_all() from s3 ORDER BY 1;

-- select tan(*) (stub function, result)
--Testcase 873:
SELECT * FROM (
SELECT tan_all() from s3
) as t ORDER BY 1;

-- select tan(*) (stub function and group by tag only) (explain)
--Testcase 874:
EXPLAIN VERBOSE
SELECT tan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select tan(*) (stub function and group by tag only) (result)
--Testcase 875:
SELECT tan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--SELECT sin_all(), round_all(), tan_all() FROM s3 ORDER BY 1;

-- select predictors function holt_winters() (explain)
--Testcase 876:
EXPLAIN VERBOSE
SELECT holt_winters(min(value1), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s') ORDER BY 1;

-- select predictors function holt_winters() (result)
--Testcase 877:
SELECT holt_winters(min(value1), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s') ORDER BY 1;

-- select predictors function holt_winters_with_fit() (explain)
--Testcase 878:
EXPLAIN VERBOSE
SELECT holt_winters_with_fit(min(value1), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s') ORDER BY 1;

-- select predictors function holt_winters_with_fit() (result)
--Testcase 879:
SELECT holt_winters_with_fit(min(value1), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s') ORDER BY 1;

-- select count(*) function of InfluxDB (stub agg function, explain)
--Testcase 880:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 ORDER BY 1;

-- select count(*) function of InfluxDB (stub agg function, result)
--Testcase 881:
SELECT influx_count_all(*) FROM s3 ORDER BY 1;

-- select count(*) function of InfluxDB (stub agg function and group by influx_time() and tag) (explain)
--Testcase 882:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select count(*) function of InfluxDB (stub agg function and group by influx_time() and tag) (result)
--Testcase 883:
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select count(*) function of InfluxDB (stub agg function and group by tag only) (explain)
--Testcase 884:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select count(*) function of InfluxDB (stub agg function and group by tag only) (result)
--Testcase 885:
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select count(*) function of InfluxDB over join query (explain)
--Testcase 886:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select count(*) function of InfluxDB over join query (result, stub call error)
--Testcase 887:
SELECT influx_count_all(*) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select distinct (stub agg function, explain)
--Testcase 888:
EXPLAIN VERBOSE
SELECT influx_distinct(value1) FROM s3 ORDER BY 1;

-- select distinct (stub agg function, result)
--Testcase 889:
SELECT influx_distinct(value1) FROM s3 ORDER BY 1;

-- select distinct (stub agg function and group by influx_time() and tag) (explain)
--Testcase 890:
EXPLAIN VERBOSE
SELECT influx_distinct(value1), influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select distinct (stub agg function and group by influx_time() and tag) (result)
--Testcase 891:
SELECT influx_distinct(value1), influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1 ORDER BY 1;

-- select distinct (stub agg function and group by tag only) (explain)
--Testcase 892:
EXPLAIN VERBOSE
SELECT influx_distinct(value2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select distinct (stub agg function and group by tag only) (result)
--Testcase 893:
SELECT influx_distinct(value2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY 1;

-- select distinct over join query (explain)
--Testcase 894:
EXPLAIN VERBOSE
SELECT influx_distinct(t1.value2) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select distinct over join query (result, stub call error)
--Testcase 895:
SELECT influx_distinct(t1.value2) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1 ORDER BY 1;

-- select distinct with having (explain)
--Testcase 896:
EXPLAIN VERBOSE
SELECT influx_distinct(value2) FROM s3 HAVING influx_distinct(value2) > 100 ORDER BY 1;

-- select distinct with having (result, not pushdown, stub call error)
--Testcase 897:
SELECT influx_distinct(value2) FROM s3 HAVING influx_distinct(value2) > 100 ORDER BY 1;

--Drop all foreign tables
--Testcase 898:
DROP FOREIGN TABLE s3__pgspider_svr1__0;
--Testcase 899:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_svr1;
--Testcase 900:
DROP SERVER pgspider_svr1;

--Testcase 901:
DROP FOREIGN TABLE s3__pgspider_svr2__0;
--Testcase 902:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_svr2;
--Testcase 903:
DROP SERVER pgspider_svr2;

--Testcase 904:
DROP EXTENSION pgspider_fdw;

--Testcase 905:
DROP FOREIGN TABLE s3;
--Testcase 906:
DROP USER MAPPING FOR CURRENT_USER SERVER pgspider_core_svr;
--Testcase 907:
DROP SERVER pgspider_core_svr;
--Testcase 908:
DROP EXTENSION pgspider_core_fdw;
