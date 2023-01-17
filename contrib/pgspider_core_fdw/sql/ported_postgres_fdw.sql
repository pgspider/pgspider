-- ===================================================================
-- create FDW objects
-- ===================================================================

--Testcase 1:
CREATE EXTENSION postgres_fdw;
--Testcase 2:
CREATE EXTENSION pgspider_core_fdw;
--Testcase 3:
CREATE EXTENSION dblink;

-- we use dblink to support insert data during test is in progress in some test cases
--Testcase 4:
select dblink_connect('dbname=postdb host=127.0.0.1
  port=15432 user=postgres password=postgres');

--Testcase 5:
CREATE SERVER pgspider_srv FOREIGN DATA WRAPPER pgspider_core_fdw;
DO $d$
    BEGIN
        EXECUTE $$CREATE SERVER postgres_srv FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (host '127.0.0.1',
                     port '15432',
                     dbname 'postdb'
            )$$;
        EXECUTE $$CREATE SERVER postgres_srv2 FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (host '127.0.0.1',
                     port '15432',
                     dbname 'postdb'
            )$$;
        EXECUTE $$CREATE SERVER postgres_srv3 FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (host '127.0.0.1',
                     port '15432',
                     dbname 'postdb'
            )$$;
    END;
$d$;

--Testcase 6:
CREATE USER MAPPING FOR public SERVER pgspider_srv
  OPTIONS (user 'postgres', password 'postgres');
--Testcase 7:
CREATE USER MAPPING FOR public SERVER postgres_srv
  OPTIONS (user 'postgres', password 'postgres');
--Testcase 8:
CREATE USER MAPPING FOR public SERVER postgres_srv2
  OPTIONS (user 'postgres', password 'postgres');
--Testcase 9:
CREATE USER MAPPING FOR public SERVER postgres_srv3
  OPTIONS (user 'postgres', password 'postgres');

-- ===================================================================
-- create objects used through PostgreSQL FDW server
-- ===================================================================
--Testcase 10:
CREATE TYPE user_enum AS ENUM ('foo', 'bar', 'buz');
--Testcase 11:
CREATE SCHEMA "S 1";
--CREATE TABLE "S 1"."T 1" (
--	"C 1" int NOT NULL,
--	c2 int NOT NULL,
--	c3 text,
--	c4 timestamptz,
--	c5 timestamp,
--	c6 varchar(10),
--	c7 char(10),
--	c8 user_enum,
--	CONSTRAINT t1_pkey PRIMARY KEY ("C 1")
--);
--CREATE TABLE "S 1"."T 2" (
--	c1 int NOT NULL,
--	c2 text,
--	CONSTRAINT t2_pkey PRIMARY KEY (c1)
--);
--CREATE TABLE "S 1"."T 3" (
--	c1 int NOT NULL,
--	c2 int NOT NULL,
--	c3 text,
--	CONSTRAINT t3_pkey PRIMARY KEY (c1)
--);
--CREATE TABLE "S 1"."T 4" (
--	c1 int NOT NULL,
--	c2 int NOT NULL,
--	c3 text,
--	CONSTRAINT t4_pkey PRIMARY KEY (c1)
--);

-- Disable autovacuum for these tables to avoid unexpected effects of that
--ALTER TABLE "S 1"."T 1" SET (autovacuum_enabled = 'false');
--ALTER TABLE "S 1"."T 2" SET (autovacuum_enabled = 'false');
--ALTER TABLE "S 1"."T 3" SET (autovacuum_enabled = 'false');
--ALTER TABLE "S 1"."T 4" SET (autovacuum_enabled = 'false');

IMPORT FOREIGN SCHEMA "S 1" FROM SERVER postgres_srv INTO "S 1";

--Testcase 12:
INSERT INTO "S 1"."T 1"
	SELECT id,
	       id % 10,
	       to_char(id, 'FM00000'),
	       '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
	       '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
	       id % 10,
	       id % 10,
	       'foo'::user_enum
	FROM generate_series(1, 1000) id;
--Testcase 13:
INSERT INTO "S 1"."T 2"
	SELECT id,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
--Testcase 14:
INSERT INTO "S 1"."T 3"
	SELECT id,
	       id + 1,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
--Testcase 15:
DELETE FROM "S 1"."T 3" WHERE c1 % 2 != 0;	-- delete for outer join tests
--Testcase 16:
INSERT INTO "S 1"."T 4"
	SELECT id,
	       id + 1,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
--Testcase 17:
DELETE FROM "S 1"."T 4" WHERE c1 % 3 != 0;	-- delete for outer join tests

ANALYZE "S 1"."T 1";
ANALYZE "S 1"."T 2";
ANALYZE "S 1"."T 3";
ANALYZE "S 1"."T 4";

-- ===================================================================
-- create foreign tables
-- ===================================================================
--Testcase 18:
CREATE FOREIGN TABLE ft1 (
	c0 int,
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 user_enum,
	__spd_url text
) SERVER pgspider_srv;
--Testcase 19:
ALTER FOREIGN TABLE ft1 DROP COLUMN c0;

--Testcase 20:
CREATE FOREIGN TABLE ft1__postgres_srv__0 (
	c0 int,
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 user_enum
) SERVER postgres_srv OPTIONS (schema_name 'S 1', table_name 'T 1');;
--Testcase 21:
ALTER FOREIGN TABLE ft1__postgres_srv__0 DROP COLUMN c0;

--Testcase 22:
CREATE FOREIGN TABLE ft2 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	cx int,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft2',
	c8 user_enum,
	__spd_url text
) SERVER pgspider_srv;
--Testcase 23:
ALTER FOREIGN TABLE ft2 DROP COLUMN cx;

--Testcase 24:
CREATE FOREIGN TABLE ft2__postgres_srv__0 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	cx int,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft2',
	c8 user_enum
) SERVER postgres_srv OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 25:
ALTER FOREIGN TABLE ft2__postgres_srv__0 DROP COLUMN cx;

--Testcase 26:
CREATE FOREIGN TABLE ft4 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	__spd_url text
) SERVER pgspider_srv;

--Testcase 27:
CREATE FOREIGN TABLE ft4__postgres_srv__0 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text
) SERVER postgres_srv OPTIONS (schema_name 'S 1', table_name 'T 3');

--Testcase 28:
CREATE FOREIGN TABLE ft5 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	__spd_url text
) SERVER pgspider_srv;

--Testcase 29:
CREATE FOREIGN TABLE ft5__postgres_srv__0 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text
) SERVER postgres_srv OPTIONS (schema_name 'S 1', table_name 'T 4');

--Testcase 30:
CREATE FOREIGN TABLE ft6 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	__spd_url text
) SERVER pgspider_srv;

--Testcase 31:
CREATE FOREIGN TABLE ft6__postgres_srv2__0 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text
) SERVER postgres_srv2 OPTIONS (schema_name 'S 1', table_name 'T 4');

-- ===================================================================
-- tests for validator
-- ===================================================================
-- skip, pgspider_core_fdw does not support these options
-- requiressl and some other parameters are omitted because
-- valid values for them depend on configure options
--  ALTER SERVER pgspider_srv OPTIONS (
-- 	use_remote_estimate 'false',
-- 	updatable 'true',
-- 	fdw_startup_cost '123.456',
-- 	fdw_tuple_cost '0.123',
-- 	service 'value',
-- 	connect_timeout 'value',
-- 	dbname 'value',
-- 	host 'value',
-- 	hostaddr 'value',
-- 	port 'value',
-- 	--client_encoding 'value',
-- 	application_name 'value',
-- 	--fallback_application_name 'value',
-- 	keepalives 'value',
-- 	keepalives_idle 'value',
-- 	keepalives_interval 'value',
-- 	tcp_user_timeout 'value',
-- 	-- requiressl 'value',
-- 	sslcompression 'value',
-- 	sslmode 'value',
-- 	sslcert 'value',
-- 	sslkey 'value',
-- 	sslrootcert 'value',
-- 	sslcrl 'value',
-- 	--requirepeer 'value',
-- 	krbsrvname 'value',
-- 	gsslib 'value'
-- 	--replication 'value'
--);
-- Error, invalid list syntax
--  ALTER SERVER pgspider_srv OPTIONS (ADD extensions 'foo; bar');

-- OK but gets a warning
-- ALTER SERVER pgspider_srv OPTIONS (ADD extensions 'foo, bar');
-- ALTER SERVER pgspider_srv OPTIONS (DROP extensions);

--Testcase 34:
ALTER USER MAPPING FOR public SERVER pgspider_srv
	OPTIONS (DROP user, DROP password);

-- Skip, pgspider_core_fdw does not support ssl
-- Attempt to add a valid option that's not allowed in a user mapping
--ALTER USER MAPPING FOR public SERVER pgspider_srv
--	OPTIONS (ADD sslmode 'require');

-- But we can add valid ones fine
--ALTER USER MAPPING FOR public SERVER pgspider_srv
--	OPTIONS (ADD sslpassword 'dummy');

-- Ensure valid options we haven't used in a user mapping yet are
-- permitted to check validation.
--ALTER USER MAPPING FOR public SERVER pgspider_srv
--	OPTIONS (ADD sslkey 'value', ADD sslcert 'value');

--Testcase 35:
ALTER FOREIGN TABLE ft1 ALTER COLUMN c1 OPTIONS (column_name 'C 1');
--Testcase 36:
ALTER FOREIGN TABLE ft1__postgres_srv__0 ALTER COLUMN c1 OPTIONS (column_name 'C 1');
--Testcase 37:
ALTER FOREIGN TABLE ft2 ALTER COLUMN c1 OPTIONS (column_name 'C 1');
--Testcase 38:
ALTER FOREIGN TABLE ft2__postgres_srv__0 ALTER COLUMN c1 OPTIONS (column_name 'C 1');
--Testcase 39:
\det+

-- Test that alteration of server options causes reconnection
-- Remote's errors might be non-English, so hide them to ensure stable results
\set VERBOSITY terse
--Testcase 40:
SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work
--Testcase 41:
ALTER SERVER postgres_srv OPTIONS (SET dbname 'no such database');
--Testcase 42:
SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should fail
DO $d$
    BEGIN
        EXECUTE $$ALTER SERVER postgres_srv
            OPTIONS (SET dbname 'postdb')$$;
    END;
$d$;
--Testcase 43:
SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work again

-- Test that alteration of user mapping options causes reconnection
-- ALTER USER MAPPING FOR CURRENT_USER SERVER postgres_srv
--   OPTIONS (ADD user 'no such user');
-- SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should fail
-- ALTER USER MAPPING FOR CURRENT_USER SERVER postgres_srv
--   OPTIONS (DROP user);
-- SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work again
\set VERBOSITY default

-- Now we should be able to run ANALYZE.
-- To exercise multiple code paths, we use local stats on ft1
-- and remote-estimate mode on ft2.
--ANALYZE ft1;
--Testcase 44:
ALTER FOREIGN TABLE ft2 OPTIONS (use_remote_estimate 'true');

-- ===================================================================
-- test error case for create publication on foreign table
-- ===================================================================
--Testcase 1186:
CREATE PUBLICATION testpub_ftbl FOR TABLE ft1;  -- should fail

-- ===================================================================
-- simple queries
-- ===================================================================
-- single table without alias
--Testcase 45:
EXPLAIN (COSTS OFF) SELECT * FROM ft1 ORDER BY c3, c1 OFFSET 100 LIMIT 10;
--Testcase 46:
SELECT * FROM ft1 ORDER BY c3, c1 OFFSET 100 LIMIT 10;
-- single table with alias - also test that tableoid sort is not pushed to remote side
--Testcase 47:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 ORDER BY t1.c3, t1.c1, t1.tableoid OFFSET 100 LIMIT 10;
--Testcase 48:
SELECT * FROM ft1 t1 ORDER BY t1.c3, t1.c1, t1.tableoid OFFSET 100 LIMIT 10;
-- whole-row reference
--Testcase 49:
EXPLAIN (VERBOSE, COSTS OFF) SELECT t1 FROM ft1 t1 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 50:
SELECT t1 FROM ft1 t1 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- empty result
--Testcase 51:
SELECT * FROM ft1 WHERE false;
-- with WHERE clause
--Testcase 52:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 101 AND t1.c6 = '1' AND t1.c7 >= '1';
--Testcase 53:
SELECT * FROM ft1 t1 WHERE t1.c1 = 101 AND t1.c6 = '1' AND t1.c7 >= '1';
-- with FOR UPDATE/SHARE
--Testcase 54:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = 101 FOR UPDATE;
--Testcase 55:
SELECT * FROM ft1 t1 WHERE c1 = 101 FOR UPDATE;
--Testcase 56:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = 102 FOR SHARE;
--Testcase 57:
SELECT * FROM ft1 t1 WHERE c1 = 102 FOR SHARE;
-- aggregate
--Testcase 58:
SELECT COUNT(*) FROM ft1 t1;
-- subquery
--Testcase 59:
SELECT * FROM ft1 t1 WHERE t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 <= 10) ORDER BY c1;
-- subquery+MAX
--Testcase 60:
SELECT * FROM ft1 t1 WHERE t1.c3 = (SELECT MAX(c3) FROM ft2 t2) ORDER BY c1;
-- used in CTE
--Testcase 61:
WITH t1 AS (SELECT * FROM ft1 WHERE c1 <= 10) SELECT t2.c1, t2.c2, t2.c3, t2.c4 FROM t1, ft2 t2 WHERE t1.c1 = t2.c1 ORDER BY t1.c1;
-- fixed values
--Testcase 62:
SELECT 'fixed', NULL FROM ft1 t1 WHERE c1 = 1;
-- Test forcing the remote server to produce sorted data for a merge join.
--Testcase 63:
SET enable_hashjoin TO false;
--Testcase 64:
SET enable_nestloop TO false;
-- inner join; expressions in the clauses appear in the equivalence class list
--Testcase 65:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1.c1, t2."C 1" FROM ft2 t1 JOIN "S 1"."T 1" t2 ON (t1.c1 = t2."C 1") OFFSET 100 LIMIT 10;
--Testcase 66:
SELECT t1.c1, t2."C 1" FROM ft2 t1 JOIN "S 1"."T 1" t2 ON (t1.c1 = t2."C 1") OFFSET 100 LIMIT 10;
-- outer join; expressions in the clauses do not appear in equivalence class
-- list but no output change as compared to the previous query
--Testcase 67:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1.c1, t2."C 1" FROM ft2 t1 LEFT JOIN "S 1"."T 1" t2 ON (t1.c1 = t2."C 1") OFFSET 100 LIMIT 10;
--Testcase 68:
SELECT t1.c1, t2."C 1" FROM ft2 t1 LEFT JOIN "S 1"."T 1" t2 ON (t1.c1 = t2."C 1") OFFSET 100 LIMIT 10;
-- A join between local table and foreign join. ORDER BY clause is added to the
-- foreign join so that the local table can be joined using merge join strategy.
--Testcase 69:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C 1" FROM "S 1"."T 1" t1 left join ft1 t2 join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C 1") OFFSET 100 LIMIT 10;
--Testcase 70:
SELECT t1."C 1" FROM "S 1"."T 1" t1 left join ft1 t2 join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C 1") OFFSET 100 LIMIT 10;
-- Test similar to above, except that the full join prevents any equivalence
-- classes from being merged. This produces single relation equivalence classes
-- included in join restrictions.
--Testcase 71:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C 1", t2.c1, t3.c1 FROM "S 1"."T 1" t1 left join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C 1") OFFSET 100 LIMIT 10;
--Testcase 72:
SELECT t1."C 1", t2.c1, t3.c1 FROM "S 1"."T 1" t1 left join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C 1") OFFSET 100 LIMIT 10;
-- Test similar to above with all full outer joins
--Testcase 73:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C 1", t2.c1, t3.c1 FROM "S 1"."T 1" t1 full join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C 1") OFFSET 100 LIMIT 10;
--Testcase 74:
SELECT t1."C 1", t2.c1, t3.c1 FROM "S 1"."T 1" t1 full join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C 1") OFFSET 100 LIMIT 10;
--Testcase 75:
RESET enable_hashjoin;
--Testcase 76:
RESET enable_nestloop;

-- Test executing assertion in estimate_path_cost_size() that makes sure that
-- retrieved_rows for foreign rel re-used to cost pre-sorted foreign paths is
-- a sensible value even when the rel has tuples=0
--Testcase 77:
CREATE FOREIGN TABLE ft_empty (c1 int NOT NULL, c2 text, __spd_url text)
  SERVER pgspider_srv;
--Testcase 78:
CREATE FOREIGN TABLE ft_empty__postgres_srv__0 (c1 int NOT NULL, c2 text)
  SERVER postgres_srv OPTIONS (table_name 'ft_empty');
--Testcase 79:
INSERT INTO ft_empty__postgres_srv__0
  SELECT id, 'AAA' || to_char(id, 'FM000') FROM generate_series(1, 100) id;
--Testcase 80:
DELETE FROM ft_empty__postgres_srv__0;
ANALYZE ft_empty__postgres_srv__0;
--Testcase 81:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft_empty ORDER BY c1;

-- ===================================================================
-- WHERE with remotely-executable conditions
-- ===================================================================
--Testcase 82:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 1;         -- Var, OpExpr(b), Const
--Testcase 83:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 100 AND t1.c2 = 0; -- BoolExpr
--Testcase 84:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 IS NULL;        -- NullTest
--Testcase 85:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 IS NOT NULL;    -- NullTest
--Testcase 86:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE round(abs(c1), 0) = 1; -- FuncExpr
--Testcase 87:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = -c1;          -- OpExpr(l)
--Testcase 88:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (c1 IS NOT NULL) IS DISTINCT FROM (c1 IS NOT NULL); -- DistinctExpr
--Testcase 89:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = ANY(ARRAY[c2, 1, c1 + 0]); -- ScalarArrayOpExpr
--Testcase 90:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = (ARRAY[c1,c2,3])[1]; -- SubscriptingRef
--Testcase 91:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c6 = E'foo''s\\bar';  -- check special chars
--Testcase 92:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c8 = 'foo';  -- can't be sent to remote
-- parameterized remote path for foreign table
--Testcase 93:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM "S 1"."T 1" a, ft2 b WHERE a."C 1" = 47 AND b.c1 = a.c2;
--Testcase 94:
SELECT * FROM ft2 a, ft2 b WHERE a.c1 = 47 AND b.c1 = a.c2;

-- check both safe and unsafe join conditions
--Testcase 95:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft2 a, ft2 b
  WHERE a.c2 = 6 AND b.c1 = a.c1 AND a.c8 = 'foo' AND b.c7 = upper(a.c7);
--Testcase 96:
SELECT * FROM ft2 a, ft2 b
WHERE a.c2 = 6 AND b.c1 = a.c1 AND a.c8 = 'foo' AND b.c7 = upper(a.c7);
-- bug before 9.3.5 due to sloppy handling of remote-estimate parameters
--Testcase 97:
SELECT * FROM ft1 WHERE c1 = ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 98:
SELECT * FROM ft2 WHERE c1 = ANY (ARRAY(SELECT c1 FROM ft1 WHERE c1 < 5));
-- we should not push order by clause with volatile expressions or unsafe
-- collations
--Testcase 99:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT * FROM ft2 ORDER BY ft2.c1, random();
--Testcase 100:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT * FROM ft2 ORDER BY ft2.c1, ft2.c3 collate "C";

-- user-defined operator/function
--Testcase 101:
CREATE FUNCTION postgres_fdw_abs(int) RETURNS int AS $$
BEGIN
RETURN abs($1);
END
$$ LANGUAGE plpgsql IMMUTABLE;
--Testcase 102:
CREATE OPERATOR === (
    LEFTARG = int,
    RIGHTARG = int,
    PROCEDURE = int4eq,
    COMMUTATOR = ===
);

-- built-in operators and functions can be shipped for remote execution
--Testcase 103:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = abs(t1.c2);
--Testcase 104:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = abs(t1.c2);
--Testcase 105:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = t1.c2;
--Testcase 106:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = t1.c2;

-- by default, user-defined ones cannot
--Testcase 107:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 108:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 109:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 110:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;

-- ORDER BY can be shipped, though
--Testcase 111:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;
--Testcase 112:
SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;

-- but let's put them in an extension ...
--Testcase 113:
ALTER EXTENSION pgspider_core_fdw ADD FUNCTION postgres_fdw_abs(int);
--Testcase 114:
ALTER EXTENSION pgspider_core_fdw ADD OPERATOR === (int, int);
--Testcase 115:
ALTER SERVER postgres_srv OPTIONS (ADD extensions 'postgres_fdw');

-- ... now they can be shipped
--Testcase 116:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 117:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 118:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 119:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;

-- and both ORDER BY and LIMIT can be shipped
--Testcase 120:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;
--Testcase 121:
SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;

-- Test CASE pushdown
--Testcase 1187:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT c1,c2,c3 FROM ft2 WHERE CASE WHEN c1 > 990 THEN c1 END < 1000 ORDER BY c1;
--Testcase 1188:
SELECT c1,c2,c3 FROM ft2 WHERE CASE WHEN c1 > 990 THEN c1 END < 1000 ORDER BY c1;

-- Nested CASE
--Testcase 1189:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT c1,c2,c3 FROM ft2 WHERE CASE CASE WHEN c2 > 0 THEN c2 END WHEN 100 THEN 601 WHEN c2 THEN c2 ELSE 0 END > 600 ORDER BY c1;

--Testcase 1190:
SELECT c1,c2,c3 FROM ft2 WHERE CASE CASE WHEN c2 > 0 THEN c2 END WHEN 100 THEN 601 WHEN c2 THEN c2 ELSE 0 END > 600 ORDER BY c1;

-- CASE arg WHEN
--Testcase 1191:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE c1 > (CASE mod(c1, 4) WHEN 0 THEN 1 WHEN 2 THEN 50 ELSE 100 END);

-- CASE cannot be pushed down because of unshippable arg clause
--Testcase 1192:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE c1 > (CASE random()::integer WHEN 0 THEN 1 WHEN 2 THEN 50 ELSE 100 END);

-- these are shippable
--Testcase 1193:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE CASE c6 WHEN 'foo' THEN true ELSE c3 < 'bar' END;
--Testcase 1194:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE CASE c3 WHEN c6 THEN true ELSE c3 < 'bar' END;

-- but this is not because of collation
--Testcase 1195:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE CASE c3 COLLATE "C" WHEN c6 THEN true ELSE c3 < 'bar' END;

-- check schema-qualification of regconfig constant
--Testcase 1244:
CREATE TEXT SEARCH CONFIGURATION public.custom_search
  (COPY = pg_catalog.english);
--Testcase 1245:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT c1, to_tsvector('custom_search'::regconfig, c3) FROM ft1
WHERE c1 = 642 AND length(to_tsvector('custom_search'::regconfig, c3)) > 0;
--Testcase 1246:
SELECT c1, to_tsvector('custom_search'::regconfig, c3) FROM ft1
WHERE c1 = 642 AND length(to_tsvector('custom_search'::regconfig, c3)) > 0;

-- ===================================================================
-- JOIN queries
-- ===================================================================
-- Analyze ft4 and ft5 so that we have better statistics. These tables do not
-- have use_remote_estimate set.
ANALYZE ft4;
ANALYZE ft5;

-- join two tables
--Testcase 122:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 123:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- join three tables
--Testcase 124:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) JOIN ft4 t3 ON (t3.c1 = t1.c1) ORDER BY t1.c3, t1.c1 OFFSET 10 LIMIT 10;
--Testcase 125:
SELECT t1.c1, t2.c2, t3.c3 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) JOIN ft4 t3 ON (t3.c1 = t1.c1) ORDER BY t1.c3, t1.c1 OFFSET 10 LIMIT 10;
-- left outer join
--Testcase 126:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 127:
SELECT t1.c1, t2.c1 FROM ft4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
-- left outer join three tables
--Testcase 128:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 129:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + placement of clauses.
-- clauses within the nullable side are not pulled up, but top level clause on
-- non-nullable side is pushed into non-nullable side
--Testcase 130:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1) WHERE t1.c1 < 10;
--Testcase 131:
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1) WHERE t1.c1 < 10;
-- clauses within the nullable side are not pulled up, but the top level clause
-- on nullable side is not pushed down into nullable side
--Testcase 132:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
			WHERE (t2.c1 < 10 OR t2.c1 IS NULL) AND t1.c1 < 10;
--Testcase 133:
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
			WHERE (t2.c1 < 10 OR t2.c1 IS NULL) AND t1.c1 < 10;
-- right outer join
--Testcase 134:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft5 t1 RIGHT JOIN ft4 t2 ON (t1.c1 = t2.c1) ORDER BY t2.c1, t1.c1 OFFSET 10 LIMIT 10;
--Testcase 135:
SELECT t1.c1, t2.c1 FROM ft5 t1 RIGHT JOIN ft4 t2 ON (t1.c1 = t2.c1) ORDER BY t2.c1, t1.c1 OFFSET 10 LIMIT 10;
-- right outer join three tables
--Testcase 136:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 137:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join
--Testcase 138:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 45 LIMIT 10;
--Testcase 139:
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 45 LIMIT 10;
-- full outer join with restrictions on the joining relations
-- a. the joining relations are both base relations
--Testcase 140:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1;
--Testcase 141:
SELECT t1.c1, t2.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1;
--Testcase 142:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT 1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (TRUE) OFFSET 10 LIMIT 10;
--Testcase 143:
SELECT 1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (TRUE) OFFSET 10 LIMIT 10;
-- b. one of the joining relations is a base relation and the other is a join
-- relation
--Testcase 144:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM ft4 t2 LEFT JOIN ft5 t3 ON (t2.c1 = t3.c1) WHERE (t2.c1 between 50 and 60)) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
--Testcase 145:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM ft4 t2 LEFT JOIN ft5 t3 ON (t2.c1 = t3.c1) WHERE (t2.c1 between 50 and 60)) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
-- c. test deparsing the remote query as nested subqueries
--Testcase 146:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
--Testcase 147:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
-- d. test deparsing rowmarked relations as subqueries
--Testcase 148:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM "S 1"."T 3" WHERE c1 = 50) t1 INNER JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (TRUE) ORDER BY t1.c1, ss.a, ss.b FOR UPDATE OF t1;
--Testcase 149:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM "S 1"."T 3" WHERE c1 = 50) t1 INNER JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (TRUE) ORDER BY t1.c1, ss.a, ss.b FOR UPDATE OF t1;
-- full outer join + inner join
--Testcase 150:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1, t3.c1 FROM ft4 t1 INNER JOIN ft5 t2 ON (t1.c1 = t2.c1 + 1 and t1.c1 between 50 and 60) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1, t2.c1, t3.c1 LIMIT 10;
--Testcase 151:
SELECT t1.c1, t2.c1, t3.c1 FROM ft4 t1 INNER JOIN ft5 t2 ON (t1.c1 = t2.c1 + 1 and t1.c1 between 50 and 60) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1, t2.c1, t3.c1 LIMIT 10;
-- full outer join three tables
--Testcase 152:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1 OFFSET 10 LIMIT 10;
--Testcase 153:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1 OFFSET 10 LIMIT 10;
-- full outer join + right outer join
--Testcase 154:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 155:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- right outer join + full outer join
--Testcase 156:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 157:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + left outer join
--Testcase 158:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 159:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + full outer join
--Testcase 160:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1 OFFSET 10 LIMIT 10;
--Testcase 161:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1 OFFSET 10 LIMIT 10;
--Testcase 162:
SET enable_memoize TO off;
-- right outer join + left outer join
--Testcase 163:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 164:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 165:
RESET enable_memoize;
-- left outer join + right outer join
--Testcase 166:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 167:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + WHERE clause, only matched rows
--Testcase 168:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) WHERE (t1.c1 = t2.c1 OR t1.c1 IS NULL) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 169:
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) WHERE (t1.c1 = t2.c1 OR t1.c1 IS NULL) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
-- full outer join + WHERE clause with shippable extensions set
--Testcase 170:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t1.c3 FROM ft1 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE postgres_fdw_abs(t1.c1) > 0 OFFSET 10 LIMIT 10;
--Testcase 171:
ALTER SERVER postgres_srv OPTIONS (DROP extensions);
-- full outer join + WHERE clause with shippable extensions not set
--Testcase 172:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t1.c3 FROM ft1 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE postgres_fdw_abs(t1.c1) > 0 OFFSET 10 LIMIT 10;
--Testcase 173:
ALTER SERVER postgres_srv OPTIONS (ADD extensions 'postgres_fdw');
-- join two tables with FOR UPDATE clause
-- tests whole-row reference for row marks
--Testcase 174:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE OF t1;
--Testcase 175:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE OF t1;
--Testcase 176:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE;
--Testcase 177:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE;
-- join two tables with FOR SHARE clause
--Testcase 178:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE OF t1;
--Testcase 179:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE OF t1;
--Testcase 180:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE;
--Testcase 181:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE;
-- join in CTE
--Testcase 182:
EXPLAIN (VERBOSE, COSTS OFF)
WITH t (c1_1, c1_3, c2_1) AS MATERIALIZED (SELECT t1.c1, t1.c3, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1 OFFSET 100 LIMIT 10;
--Testcase 183:
WITH t (c1_1, c1_3, c2_1) AS MATERIALIZED (SELECT t1.c1, t1.c3, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1 OFFSET 100 LIMIT 10;
-- ctid with whole-row reference
--Testcase 184:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.ctid, t1, t2, t1.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- SEMI JOIN, not pushed down
--Testcase 185:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1 FROM ft1 t1 WHERE EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c1) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
--Testcase 186:
SELECT t1.c1 FROM ft1 t1 WHERE EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c1) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
-- ANTI JOIN, not pushed down
--Testcase 187:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1 FROM ft1 t1 WHERE NOT EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c2) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
--Testcase 188:
SELECT t1.c1 FROM ft1 t1 WHERE NOT EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c2) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
-- CROSS JOIN can be pushed down
--Testcase 189:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 CROSS JOIN ft2 t2 ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 190:
SELECT t1.c1, t2.c1 FROM ft1 t1 CROSS JOIN ft2 t2 ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- different server, not pushed down. No result expected.
--Testcase 191:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft5 t1 JOIN ft6 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 192:
SELECT t1.c1, t2.c1 FROM ft5 t1 JOIN ft6 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- unsafe join conditions (c8 has a UDT), not pushed down. Practically a CROSS
-- JOIN since c8 in both tables has same value.
--Testcase 193:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c8 = t2.c8) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 194:
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c8 = t2.c8) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- unsafe conditions on one side (c8 has a UDT), not pushed down.
--Testcase 195:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = 'foo' ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 196:
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = 'foo' ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- join where unsafe to pushdown condition in WHERE clause has a column not
-- in the SELECT clause. In this test unsafe clause needs to have column
-- references from both joining sides so that the clause is not pushed down
-- into one of the joining sides.
--Testcase 197:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = t2.c8 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 198:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = t2.c8 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- Aggregate after UNION, for testing setrefs
--Testcase 199:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1c1, avg(t1c1 + t2c1) FROM (SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) UNION SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) AS t (t1c1, t2c1) GROUP BY t1c1 ORDER BY t1c1 OFFSET 100 LIMIT 10;
--Testcase 200:
SELECT t1c1, avg(t1c1 + t2c1) FROM (SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) UNION SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) AS t (t1c1, t2c1) GROUP BY t1c1 ORDER BY t1c1 OFFSET 100 LIMIT 10;
-- join with lateral reference
--Testcase 201:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1."C 1" FROM "S 1"."T 1" t1, LATERAL (SELECT DISTINCT t2.c1, t3.c1 FROM ft1 t2, ft2 t3 WHERE t2.c1 = t3.c1 AND t2.c2 = t1.c2) q ORDER BY t1."C 1" OFFSET 10 LIMIT 10;
--Testcase 202:
SELECT t1."C 1" FROM "S 1"."T 1" t1, LATERAL (SELECT DISTINCT t2.c1, t3.c1 FROM ft1 t2, ft2 t3 WHERE t2.c1 = t3.c1 AND t2.c2 = t1.c2) q ORDER BY t1."C 1" OFFSET 10 LIMIT 10;

-- non-Var items in targetlist of the nullable rel of a join preventing
-- push-down in some cases
-- unable to push {ft1, ft2}
--Testcase 203:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT q.a, ft2.c1 FROM (SELECT 13 FROM ft1 WHERE c1 = 13) q(a) RIGHT JOIN ft2 ON (q.a = ft2.c1) WHERE ft2.c1 BETWEEN 10 AND 15;
--Testcase 204:
SELECT q.a, ft2.c1 FROM (SELECT 13 FROM ft1 WHERE c1 = 13) q(a) RIGHT JOIN ft2 ON (q.a = ft2.c1) WHERE ft2.c1 BETWEEN 10 AND 15;

-- ok to push {ft1, ft2} but not {ft1, ft2, ft4}
--Testcase 205:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ft4.c1, q.* FROM ft4 LEFT JOIN (SELECT 13, ft1.c1, ft2.c1 FROM ft1 RIGHT JOIN ft2 ON (ft1.c1 = ft2.c1) WHERE ft1.c1 = 12) q(a, b, c) ON (ft4.c1 = q.b) WHERE ft4.c1 BETWEEN 10 AND 15;
--Testcase 206:
SELECT ft4.c1, q.* FROM ft4 LEFT JOIN (SELECT 13, ft1.c1, ft2.c1 FROM ft1 RIGHT JOIN ft2 ON (ft1.c1 = ft2.c1) WHERE ft1.c1 = 12) q(a, b, c) ON (ft4.c1 = q.b) WHERE ft4.c1 BETWEEN 10 AND 15;

-- join with nullable side with some columns with null values
--Testcase 207:
UPDATE ft5__postgres_srv__0 SET c3 = null where c1 % 9 = 0;
--Testcase 208:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ft5, ft5.c1, ft5.c2, ft5.c3, ft4.c1, ft4.c2 FROM ft5 left join ft4 on ft5.c1 = ft4.c1 WHERE ft4.c1 BETWEEN 10 and 30 ORDER BY ft5.c1, ft4.c1;
--Testcase 209:
SELECT ft5, ft5.c1, ft5.c2, ft5.c3, ft4.c1, ft4.c2 FROM ft5 left join ft4 on ft5.c1 = ft4.c1 WHERE ft4.c1 BETWEEN 10 and 30 ORDER BY ft5.c1, ft4.c1;

-- multi-way join involving multiple merge joins
-- (this case used to have EPQ-related planning problems)
--Testcase 210:
CREATE TABLE local_tbl (c1 int NOT NULL, c2 int NOT NULL, c3 text, CONSTRAINT local_tbl_pkey PRIMARY KEY (c1));
--Testcase 211:
INSERT INTO local_tbl SELECT id, id % 10, to_char(id, 'FM0000') FROM generate_series(1, 1000) id;
ANALYZE local_tbl;
--Testcase 212:
SET enable_nestloop TO false;
--Testcase 213:
SET enable_hashjoin TO false;
--Testcase 214:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1, ft2, ft4, ft5, local_tbl WHERE ft1.c1 = ft2.c1 AND ft1.c2 = ft4.c1
    AND ft1.c2 = ft5.c1 AND ft1.c2 = local_tbl.c1 AND ft1.c1 < 100 AND ft2.c1 < 100 FOR UPDATE;
--Testcase 215:
SELECT * FROM ft1, ft2, ft4, ft5, local_tbl WHERE ft1.c1 = ft2.c1 AND ft1.c2 = ft4.c1
    AND ft1.c2 = ft5.c1 AND ft1.c2 = local_tbl.c1 AND ft1.c1 < 100 AND ft2.c1 < 100 FOR UPDATE;
--Testcase 216:
RESET enable_nestloop;
--Testcase 217:
RESET enable_hashjoin;

-- test that add_paths_with_pathkeys_for_rel() arranges for the epq_path to
-- return columns needed by the parent ForeignScan node
--Testcase 1247:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM local_tbl LEFT JOIN (SELECT ft1.*, COALESCE(ft1.c3 || ft2.c3, 'foobar') FROM ft1 INNER JOIN ft2 ON (ft1.c1 = ft2.c1 AND ft1.c1 < 100)) ss ON (local_tbl.c1 = ss.c1) ORDER BY local_tbl.c1 FOR UPDATE OF local_tbl;

--Testcase 1248:
ALTER SERVER postgres_srv OPTIONS (DROP extensions);
--Testcase 1249:
ALTER SERVER postgres_srv OPTIONS (ADD fdw_startup_cost '10000.0');
--Testcase 1250:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM local_tbl LEFT JOIN (SELECT ft1.* FROM ft1 INNER JOIN ft2 ON (ft1.c1 = ft2.c1 AND ft1.c1 < 100 AND ft1.c1 = postgres_fdw_abs(ft2.c2))) ss ON (local_tbl.c3 = ss.c3) ORDER BY local_tbl.c1 FOR UPDATE OF local_tbl;
--Testcase 1251:
ALTER SERVER postgres_srv OPTIONS (DROP fdw_startup_cost);
--Testcase 1252:
ALTER SERVER postgres_srv OPTIONS (ADD extensions 'postgres_fdw');

--Testcase 218:
DROP TABLE local_tbl;

-- check join pushdown in situations where multiple userids are involved
--Testcase 219:
CREATE ROLE regress_view_owner SUPERUSER;
--Testcase 220:
CREATE USER MAPPING FOR regress_view_owner SERVER postgres_srv;
GRANT SELECT ON ft4 TO regress_view_owner;
GRANT SELECT ON ft5 TO regress_view_owner;

--Testcase 221:
CREATE VIEW v4 AS SELECT * FROM ft4;
--Testcase 222:
CREATE VIEW v5 AS SELECT * FROM ft5;
--Testcase 223:
ALTER VIEW v5 OWNER TO regress_view_owner;
--Testcase 224:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can't be pushed down, different view owners
--Testcase 225:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 226:
ALTER VIEW v4 OWNER TO regress_view_owner;
--Testcase 227:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can be pushed down
--Testcase 228:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;

--Testcase 229:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can't be pushed down, view owner not current user
--Testcase 230:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 231:
ALTER VIEW v4 OWNER TO CURRENT_USER;
--Testcase 232:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can be pushed down
--Testcase 233:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 234:
ALTER VIEW v4 OWNER TO regress_view_owner;

-- cleanup
--Testcase 235:
DROP OWNED BY regress_view_owner;
--Testcase 236:
DROP ROLE regress_view_owner;


-- ===================================================================
-- Aggregate and grouping queries
-- ===================================================================

-- Simple aggregates
--Testcase 237:
explain (verbose, costs off)
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2;
--Testcase 238:
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2;

--Testcase 239:
explain (verbose, costs off)
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2 limit 1;
--Testcase 240:
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2 limit 1;

-- Aggregate is not pushed down as aggregation contains random()
--Testcase 241:
explain (verbose, costs off)
select sum(c1 * (random() <= 1)::int) as sum, avg(c1) from ft1;

-- Aggregate over join query
--Testcase 242:
explain (verbose, costs off)
select count(*), sum(t1.c1), avg(t2.c1) from ft1 t1 inner join ft1 t2 on (t1.c2 = t2.c2) where t1.c2 = 6;
--Testcase 243:
select count(*), sum(t1.c1), avg(t2.c1) from ft1 t1 inner join ft1 t2 on (t1.c2 = t2.c2) where t1.c2 = 6;

-- Not pushed down due to local conditions present in underneath input rel
--Testcase 244:
explain (verbose, costs off)
select sum(t1.c1), count(t2.c1) from ft1 t1 inner join ft2 t2 on (t1.c1 = t2.c1) where ((t1.c1 * t2.c1)/(t1.c1 * t2.c1)) * random() <= 1;

-- GROUP BY clause having expressions
--Testcase 245:
explain (verbose, costs off)
select c2/2, sum(c2) * (c2/2) from ft1 group by c2/2 order by c2/2;
--Testcase 246:
select c2/2, sum(c2) * (c2/2) from ft1 group by c2/2 order by c2/2;

-- Aggregates in subquery are pushed down.
--Testcase 247:
explain (verbose, costs off)
select count(x.a), sum(x.a) from (select c2 a, sum(c1) b from ft1 group by c2, sqrt(c1) order by 1, 2) x;
--Testcase 248:
select count(x.a), sum(x.a) from (select c2 a, sum(c1) b from ft1 group by c2, sqrt(c1) order by 1, 2) x;

-- Aggregate is still pushed down by taking unshippable expression out
--Testcase 249:
explain (verbose, costs off)
select c2 * (random() <= 1)::int as sum1, sum(c1) * c2 as sum2 from ft1 group by c2 order by 1, 2;
--Testcase 250:
select c2 * (random() <= 1)::int as sum1, sum(c1) * c2 as sum2 from ft1 group by c2 order by 1, 2;

-- Aggregate with unshippable GROUP BY clause are not pushed
--Testcase 251:
explain (verbose, costs off)
select c2 * (random() <= 1)::int as c2 from ft2 group by c2 * (random() <= 1)::int order by 1;

-- GROUP BY clause in various forms, cardinal, alias and constant expression
--Testcase 252:
explain (verbose, costs off)
select count(c2) w, c2 x, 5 y, 7.0 z from ft1 group by 2, y, 9.0::int order by 2;
--Testcase 253:
select count(c2) w, c2 x, 5 y, 7.0 z from ft1 group by 2, y, 9.0::int order by 2;

-- GROUP BY clause referring to same column multiple times
-- Also, ORDER BY contains an aggregate function
--Testcase 254:
explain (verbose, costs off)
select c2, c2 from ft1 where c2 > 6 group by 1, 2 order by sum(c1);
--Testcase 255:
select c2, c2 from ft1 where c2 > 6 group by 1, 2 order by sum(c1);

-- Testing HAVING clause shippability
--Testcase 256:
explain (verbose, costs off)
select c2, sum(c1) from ft2 group by c2 having avg(c1) < 500 and sum(c1) < 49800 order by c2;
--Testcase 257:
select c2, sum(c1) from ft2 group by c2 having avg(c1) < 500 and sum(c1) < 49800 order by c2;

-- Unshippable HAVING clause will be evaluated locally, and other qual in HAVING clause is pushed down
--Testcase 258:
explain (verbose, costs off)
select count(*) from (select c5, count(c1) from ft1 group by c5, sqrt(c2) having (avg(c1) / avg(c1)) * random() <= 1 and avg(c1) < 500) x;
--Testcase 259:
select count(*) from (select c5, count(c1) from ft1 group by c5, sqrt(c2) having (avg(c1) / avg(c1)) * random() <= 1 and avg(c1) < 500) x;

-- Aggregate in HAVING clause is not pushable, and thus aggregation is not pushed down
--Testcase 260:
explain (verbose, costs off)
select sum(c1) from ft1 group by c2 having avg(c1 * (random() <= 1)::int) > 100 order by 1;

-- Remote aggregate in combination with a local Param (for the output
-- of an initplan) can be trouble, per bug #15781
--Testcase 261:
explain (verbose, costs off)
select exists(select 1 from pg_enum), sum(c1) from ft1;
--Testcase 262:
select exists(select 1 from pg_enum), sum(c1) from ft1;

--Testcase 263:
explain (verbose, costs off)
select exists(select 1 from pg_enum), sum(c1) from ft1 group by 1;
--Testcase 264:
select exists(select 1 from pg_enum), sum(c1) from ft1 group by 1;


-- Testing ORDER BY, DISTINCT, FILTER, Ordered-sets and VARIADIC within aggregates

-- ORDER BY within aggregate, same column used to order
--Testcase 265:
explain (verbose, costs off)
select array_agg(c1 order by c1) from ft1 where c1 < 100 group by c2 order by 1;
--Testcase 266:
select array_agg(c1 order by c1) from ft1 where c1 < 100 group by c2 order by 1;

-- ORDER BY within aggregate, different column used to order also using DESC
--Testcase 267:
explain (verbose, costs off)
select array_agg(c5 order by c1 desc) from ft2 where c2 = 6 and c1 < 50;
--Testcase 268:
select array_agg(c5 order by c1 desc) from ft2 where c2 = 6 and c1 < 50;

-- DISTINCT within aggregate
--Testcase 269:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 270:
select array_agg(distinct (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

-- DISTINCT combined with ORDER BY within aggregate
--Testcase 271:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 272:
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

--Testcase 273:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5 desc nulls last) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 274:
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5 desc nulls last) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

-- FILTER within aggregate
--Testcase 275:
explain (verbose, costs off)
select sum(c1) filter (where c1 < 100 and c2 > 5) from ft1 group by c2 order by 1 nulls last;
--Testcase 276:
select sum(c1) filter (where c1 < 100 and c2 > 5) from ft1 group by c2 order by 1 nulls last;

-- DISTINCT, ORDER BY and FILTER within aggregate
--Testcase 277:
explain (verbose, costs off)
select sum(c1%3), sum(distinct c1%3 order by c1%3) filter (where c1%3 < 2), c2 from ft1 where c2 = 6 group by c2;
--Testcase 278:
select sum(c1%3), sum(distinct c1%3 order by c1%3) filter (where c1%3 < 2), c2 from ft1 where c2 = 6 group by c2;

-- Outer query is aggregation query
--Testcase 279:
explain (verbose, costs off)
select distinct (select count(*) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
--Testcase 280:
select distinct (select count(*) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
-- Inner query is aggregation query
--Testcase 281:
explain (verbose, costs off)
select distinct (select count(t1.c1) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
--Testcase 282:
select distinct (select count(t1.c1) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;

-- Aggregate not pushed down as FILTER condition is not pushable
--Testcase 283:
explain (verbose, costs off)
select sum(c1) filter (where (c1 / c1) * random() <= 1) from ft1 group by c2 order by 1;
--Testcase 284:
explain (verbose, costs off)
select sum(c2) filter (where c2 in (select c2 from ft1 where c2 < 5)) from ft1;

-- Ordered-sets within aggregate
--Testcase 285:
explain (verbose, costs off)
select c2, rank('10'::varchar) within group (order by c6), percentile_cont(c2/10::numeric) within group (order by c1) from ft1 where c2 < 10 group by c2 having percentile_cont(c2/10::numeric) within group (order by c1) < 500 order by c2;
--Testcase 286:
select c2, rank('10'::varchar) within group (order by c6), percentile_cont(c2/10::numeric) within group (order by c1) from ft1 where c2 < 10 group by c2 having percentile_cont(c2/10::numeric) within group (order by c1) < 500 order by c2;

-- Using multiple arguments within aggregates
--Testcase 287:
explain (verbose, costs off)
select c1, rank(c1, c2) within group (order by c1, c2) from ft1 group by c1, c2 having c1 = 6 order by 1;
--Testcase 288:
select c1, rank(c1, c2) within group (order by c1, c2) from ft1 group by c1, c2 having c1 = 6 order by 1;

-- User defined function for user defined aggregate, VARIADIC
--Testcase 289:
create function least_accum(anyelement, variadic anyarray)
returns anyelement language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';
--Testcase 290:
create aggregate least_agg(variadic items anyarray) (
  stype = anyelement, sfunc = least_accum
);

-- Disable hash aggregation for plan stability.
--Testcase 291:
set enable_hashagg to false;

-- Not pushed down due to user defined aggregate
--Testcase 292:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 group by c2 order by c2;

-- Add function and aggregate into extension
--Testcase 293:
alter extension pgspider_core_fdw add function least_accum(anyelement, variadic anyarray);
--Testcase 294:
alter extension pgspider_core_fdw add aggregate least_agg(variadic items anyarray);
--Testcase 295:
alter server postgres_srv options (set extensions 'postgres_fdw');

-- Now aggregate will be pushed.  Aggregate will display VARIADIC argument.
--Testcase 296:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 where c2 < 100 group by c2 order by c2;
--Testcase 297:
select c2, least_agg(c1) from ft1 where c2 < 100 group by c2 order by c2;

-- Remove function and aggregate from extension
--Testcase 298:
alter extension pgspider_core_fdw drop function least_accum(anyelement, variadic anyarray);
--Testcase 299:
alter extension pgspider_core_fdw drop aggregate least_agg(variadic items anyarray);
--Testcase 300:
alter server postgres_srv options (set extensions 'postgres_fdw');

-- Not pushed down as we have dropped objects from extension.
--Testcase 301:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 group by c2 order by c2;

-- Cleanup
--Testcase 302:
reset enable_hashagg;
--Testcase 303:
drop aggregate least_agg(variadic items anyarray);
--Testcase 304:
drop function least_accum(anyelement, variadic anyarray);


-- Testing USING OPERATOR() in ORDER BY within aggregate.
-- For this, we need user defined operators along with operator family and
-- operator class.  Create those and then add them in extension.  Note that
-- user defined objects are considered unshippable unless they are part of
-- the extension.
--Testcase 305:
create operator public.<^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4eq
);

--Testcase 306:
create operator public.=^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4lt
);

--Testcase 307:
create operator public.>^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4gt
);

--Testcase 308:
create operator family my_op_family using btree;

--Testcase 309:
create function my_op_cmp(a int, b int) returns int as
  $$begin return btint4cmp(a, b); end $$ language plpgsql;

--Testcase 310:
create operator class my_op_class for type int using btree family my_op_family as
 operator 1 public.<^,
 operator 3 public.=^,
 operator 5 public.>^,
 function 1 my_op_cmp(int, int);

-- This will not be pushed as user defined sort operator is not part of the
-- extension yet.
--Testcase 311:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- This should not be pushed either.
--Testcase 1196:
explain (verbose, costs off)
select * from ft2 order by c1 using operator(public.<^);

-- Update local stats on ft2
ANALYZE ft2;

-- Add into extension
--Testcase 312:
alter extension pgspider_core_fdw add operator class my_op_class using btree;
--Testcase 313:
alter extension pgspider_core_fdw add function my_op_cmp(a int, b int);
--Testcase 314:
alter extension pgspider_core_fdw add operator family my_op_family using btree;
--Testcase 315:
alter extension pgspider_core_fdw add operator public.<^(int, int);
--Testcase 316:
alter extension pgspider_core_fdw add operator public.=^(int, int);
--Testcase 317:
alter extension pgspider_core_fdw add operator public.>^(int, int);
--Testcase 318:
alter server postgres_srv options (set extensions 'postgres_fdw');

-- PGSpider can not push down this operator
--Testcase 319:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;
--Testcase 320:
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- This should not be pushed too.
--Testcase 1197:
explain (verbose, costs off)
select * from ft2 order by c1 using operator(public.<^);

-- Remove from extension
--Testcase 321:
alter extension pgspider_core_fdw drop operator class my_op_class using btree;
--Testcase 322:
alter extension pgspider_core_fdw drop function my_op_cmp(a int, b int);
--Testcase 323:
alter extension pgspider_core_fdw drop operator family my_op_family using btree;
--Testcase 324:
alter extension pgspider_core_fdw drop operator public.<^(int, int);
--Testcase 325:
alter extension pgspider_core_fdw drop operator public.=^(int, int);
--Testcase 326:
alter extension pgspider_core_fdw drop operator public.>^(int, int);
--Testcase 327:
alter server postgres_srv options (set extensions 'postgres_fdw');

-- This will not be pushed as sort operator is now removed from the extension.
--Testcase 328:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- Cleanup
--Testcase 329:
drop operator class my_op_class using btree;
--Testcase 330:
drop function my_op_cmp(a int, b int);
--Testcase 331:
drop operator family my_op_family using btree;
--Testcase 332:
drop operator public.>^(int, int);
--Testcase 333:
drop operator public.=^(int, int);
--Testcase 334:
drop operator public.<^(int, int);

-- Input relation to aggregate push down hook is not safe to pushdown and thus
-- the aggregate cannot be pushed down to foreign server.
--Testcase 335:
explain (verbose, costs off)
select count(t1.c3) from ft2 t1 left join ft2 t2 on (t1.c1 = random() * t2.c2);

-- Subquery in FROM clause having aggregate
--Testcase 336:
explain (verbose, costs off)
select count(*), x.b from ft1, (select c2 a, sum(c1) b from ft1 group by c2) x where ft1.c2 = x.a group by x.b order by 1, 2;
--Testcase 337:
select count(*), x.b from ft1, (select c2 a, sum(c1) b from ft1 group by c2) x where ft1.c2 = x.a group by x.b order by 1, 2;

-- FULL join with IS NULL check in HAVING
--Testcase 338:
explain (verbose, costs off)
select avg(t1.c1), sum(t2.c1) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) group by t2.c1 having (avg(t1.c1) is null and sum(t2.c1) < 10) or sum(t2.c1) is null order by 1 nulls last, 2;
--Testcase 339:
select avg(t1.c1), sum(t2.c1) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) group by t2.c1 having (avg(t1.c1) is null and sum(t2.c1) < 10) or sum(t2.c1) is null order by 1 nulls last, 2;

-- Aggregate over FULL join needing to deparse the joining relations as
-- subqueries.
--Testcase 340:
explain (verbose, costs off)
select count(*), sum(t1.c1), avg(t2.c1) from (select c1 from ft4 where c1 between 50 and 60) t1 full join (select c1 from ft5 where c1 between 50 and 60) t2 on (t1.c1 = t2.c1);
--Testcase 341:
select count(*), sum(t1.c1), avg(t2.c1) from (select c1 from ft4 where c1 between 50 and 60) t1 full join (select c1 from ft5 where c1 between 50 and 60) t2 on (t1.c1 = t2.c1);

-- ORDER BY expression is part of the target list but not pushed down to
-- foreign server.
--Testcase 342:
explain (verbose, costs off)
select sum(c2) * (random() <= 1)::int as sum from ft1 order by 1;
--Testcase 343:
select sum(c2) * (random() <= 1)::int as sum from ft1 order by 1;

-- LATERAL join, with parameterization
--Testcase 344:
set enable_hashagg to false;
--Testcase 345:
explain (verbose, costs off)
select c2, sum from "S 1"."T 1" t1, lateral (select sum(t2.c1 + t1."C 1") sum from ft2 t2 group by t2.c1) qry where t1.c2 * 2 = qry.sum and t1.c2 < 3 and t1."C 1" < 100 order by 1;
--Testcase 346:
select c2, sum from "S 1"."T 1" t1, lateral (select sum(t2.c1 + t1."C 1") sum from ft2 t2 group by t2.c1) qry where t1.c2 * 2 = qry.sum and t1.c2 < 3 and t1."C 1" < 100 order by 1;
--Testcase 347:
reset enable_hashagg;

-- bug #15613: bad plan for foreign table scan with lateral reference
--Testcase 348:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ref_0.c2, subq_1.*
FROM
    "S 1"."T 1" AS ref_0,
    LATERAL (
        SELECT ref_0."C 1" c1, subq_0.*
        FROM (SELECT ref_0.c2, ref_1.c3
              FROM ft1 AS ref_1) AS subq_0
             RIGHT JOIN ft2 AS ref_3 ON (subq_0.c3 = ref_3.c3)
    ) AS subq_1
WHERE ref_0."C 1" < 10 AND subq_1.c3 = '00001'
ORDER BY ref_0."C 1";

--Testcase 349:
SELECT ref_0.c2, subq_1.*
FROM
    "S 1"."T 1" AS ref_0,
    LATERAL (
        SELECT ref_0."C 1" c1, subq_0.*
        FROM (SELECT ref_0.c2, ref_1.c3
              FROM ft1 AS ref_1) AS subq_0
             RIGHT JOIN ft2 AS ref_3 ON (subq_0.c3 = ref_3.c3)
    ) AS subq_1
WHERE ref_0."C 1" < 10 AND subq_1.c3 = '00001'
ORDER BY ref_0."C 1";

-- Check with placeHolderVars
--Testcase 350:
explain (verbose, costs off)
select sum(q.a), count(q.b) from ft4 left join (select 13, avg(ft1.c1), sum(ft2.c1) from ft1 right join ft2 on (ft1.c1 = ft2.c1)) q(a, b, c) on (ft4.c1 <= q.b);
--Testcase 351:
select sum(q.a), count(q.b) from ft4 left join (select 13, avg(ft1.c1), sum(ft2.c1) from ft1 right join ft2 on (ft1.c1 = ft2.c1)) q(a, b, c) on (ft4.c1 <= q.b);


-- Not supported cases
-- Grouping sets
--Testcase 352:
explain (verbose, costs off)
select c2, sum(c1) from ft1 where c2 < 3 group by rollup(c2) order by 1 nulls last;
--Testcase 353:
select c2, sum(c1) from ft1 where c2 < 3 group by rollup(c2) order by 1 nulls last;
--Testcase 354:
explain (verbose, costs off)
select c2, sum(c1) from ft1 where c2 < 3 group by cube(c2) order by 1 nulls last;
--Testcase 355:
select c2, sum(c1) from ft1 where c2 < 3 group by cube(c2) order by 1 nulls last;
--Testcase 356:
explain (verbose, costs off)
select c2, c6, sum(c1) from ft1 where c2 < 3 group by grouping sets(c2, c6) order by 1 nulls last, 2 nulls last;
--Testcase 357:
select c2, c6, sum(c1) from ft1 where c2 < 3 group by grouping sets(c2, c6) order by 1 nulls last, 2 nulls last;
--Testcase 358:
explain (verbose, costs off)
select c2, sum(c1), grouping(c2) from ft1 where c2 < 3 group by c2 order by 1 nulls last;
--Testcase 359:
select c2, sum(c1), grouping(c2) from ft1 where c2 < 3 group by c2 order by 1 nulls last;

-- DISTINCT itself is not pushed down, whereas underneath aggregate is pushed
--Testcase 360:
explain (verbose, costs off)
select distinct sum(c1)/1000 s from ft2 where c2 < 6 group by c2 order by 1;
--Testcase 361:
select distinct sum(c1)/1000 s from ft2 where c2 < 6 group by c2 order by 1;

-- WindowAgg
--Testcase 362:
explain (verbose, costs off)
select c2, sum(c2), count(c2) over (partition by c2%2) from ft2 where c2 < 10 group by c2 order by 1;
--Testcase 363:
select c2, sum(c2), count(c2) over (partition by c2%2) from ft2 where c2 < 10 group by c2 order by 1;
--Testcase 364:
explain (verbose, costs off)
select c2, array_agg(c2) over (partition by c2%2 order by c2 desc) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 365:
select c2, array_agg(c2) over (partition by c2%2 order by c2 desc) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 366:
explain (verbose, costs off)
select c2, array_agg(c2) over (partition by c2%2 order by c2 range between current row and unbounded following) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 367:
select c2, array_agg(c2) over (partition by c2%2 order by c2 range between current row and unbounded following) from ft1 where c2 < 10 group by c2 order by 1;


-- ===================================================================
-- parameterized queries
-- ===================================================================
-- simple join
--Testcase 368:
PREPARE st1(int, int) AS SELECT t1.c3, t2.c3 FROM ft1 t1, ft2 t2 WHERE t1.c1 = $1 AND t2.c1 = $2;
--Testcase 369:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st1(1, 2);
--Testcase 370:
EXECUTE st1(1, 1);
--Testcase 371:
EXECUTE st1(101, 101);
-- subquery using stable function (can't be sent to remote)
--Testcase 372:
PREPARE st2(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 < $2 AND t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 > $1 AND date(c4) = '1970-01-17'::date) ORDER BY c1;
--Testcase 373:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st2(10, 20);
--Testcase 374:
EXECUTE st2(10, 20);
--Testcase 375:
EXECUTE st2(101, 121);
-- subquery using immutable function (can be sent to remote)
--Testcase 376:
PREPARE st3(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 < $2 AND t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 > $1 AND date(c5) = '1970-01-17'::date) ORDER BY c1;
--Testcase 377:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st3(10, 20);
--Testcase 378:
EXECUTE st3(10, 20);
--Testcase 379:
EXECUTE st3(20, 30);
-- custom plan should be chosen initially
--Testcase 380:
PREPARE st4(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 = $1;
--Testcase 381:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 382:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 383:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 384:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 385:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
-- once we try it enough times, should switch to generic plan
--Testcase 386:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
-- value of $1 should not be sent to remote
--Testcase 387:
PREPARE st5(user_enum,int) AS SELECT * FROM ft1 t1 WHERE c8 = $1 and c1 = $2;
--Testcase 388:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 389:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 390:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 391:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 392:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 393:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 394:
EXECUTE st5('foo', 1);

-- altering FDW options requires replanning
--Testcase 395:
PREPARE st6 AS SELECT * FROM ft1 t1 WHERE t1.c1 = t1.c2;
--Testcase 396:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st6;
--Testcase 397:
PREPARE st7 AS INSERT INTO ft1__postgres_srv__0 (c1,c2,c3) VALUES (1001,101,'foo');
--Testcase 398:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st7;
--Testcase 399:
ALTER TABLE "S 1"."T 1" RENAME TO "T 0";
--Testcase 400:
ALTER FOREIGN TABLE ft1__postgres_srv__0 OPTIONS (SET table_name 'T 0');
--Testcase 401:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st6;
--Testcase 402:
EXECUTE st6;
--Testcase 403:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st7;
--Testcase 404:
ALTER TABLE "S 1"."T 0" RENAME TO "T 1";
--Testcase 405:
ALTER FOREIGN TABLE ft1__postgres_srv__0 OPTIONS (SET table_name 'T 1');

--Testcase 406:
PREPARE st8 AS SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 407:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st8;
--Testcase 408:
ALTER SERVER postgres_srv OPTIONS (DROP extensions);
--Testcase 409:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st8;
--Testcase 410:
EXECUTE st8;
--Testcase 411:
ALTER SERVER postgres_srv OPTIONS (ADD extensions 'postgres_fdw');

-- cleanup
DEALLOCATE st1;
DEALLOCATE st2;
DEALLOCATE st3;
DEALLOCATE st4;
DEALLOCATE st5;
DEALLOCATE st6;
DEALLOCATE st7;
DEALLOCATE st8;

-- System columns, except ctid and oid, should not be sent to remote
--Testcase 412:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 t1 WHERE t1.tableoid = 'pg_class'::regclass LIMIT 1;
--Testcase 413:
SELECT * FROM ft1 t1 WHERE t1.tableoid = 'ft1'::regclass LIMIT 1;
--Testcase 414:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tableoid::regclass, * FROM ft1 t1 LIMIT 1;
--Testcase 415:
SELECT tableoid::regclass, * FROM ft1 t1 LIMIT 1;
--Testcase 416:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 t1 WHERE t1.ctid = '(0,2)';
--Testcase 417:
SELECT * FROM ft1 t1 WHERE t1.ctid = '(0,2)';
--Testcase 418:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ctid, * FROM ft1 t1 LIMIT 1;
--Testcase 419:
SELECT ctid, * FROM ft1 t1 LIMIT 1;

-- ===================================================================
-- used in PL/pgSQL function
-- ===================================================================
--Testcase 420:
CREATE OR REPLACE FUNCTION f_test(p_c1 int) RETURNS int AS $$
DECLARE
	v_c1 int;
BEGIN
--Testcase 421:
    SELECT c1 INTO v_c1 FROM ft1 WHERE c1 = p_c1 LIMIT 1;
    PERFORM c1 FROM ft1 WHERE c1 = p_c1 AND p_c1 = v_c1 LIMIT 1;
    RETURN v_c1;
END;
$$ LANGUAGE plpgsql;
--Testcase 422:
SELECT f_test(100);
--Testcase 423:
DROP FUNCTION f_test(int);

-- ===================================================================
-- REINDEX
-- ===================================================================
-- remote table is not created here
--Testcase 424:
CREATE FOREIGN TABLE reindex_foreign (c1 int, c2 int)
  SERVER postgres_srv2 OPTIONS (table_name 'reindex_local');
REINDEX TABLE reindex_foreign; -- error
REINDEX TABLE CONCURRENTLY reindex_foreign; -- error
--Testcase 425:
DROP FOREIGN TABLE reindex_foreign;
-- partitions and foreign tables
--Testcase 426:
CREATE TABLE reind_fdw_parent (c1 int) PARTITION BY RANGE (c1);
--Testcase 427:
CREATE TABLE reind_fdw_0_10 PARTITION OF reind_fdw_parent
  FOR VALUES FROM (0) TO (10);
--Testcase 428:
CREATE FOREIGN TABLE reind_fdw_10_20 PARTITION OF reind_fdw_parent
  FOR VALUES FROM (10) TO (20)
  SERVER postgres_srv OPTIONS (table_name 'reind_local_10_20');
REINDEX TABLE reind_fdw_parent; -- ok
REINDEX TABLE CONCURRENTLY reind_fdw_parent; -- ok
--Testcase 429:
DROP TABLE reind_fdw_parent;

-- ===================================================================
-- conversion error
-- ===================================================================
--Testcase 430:
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE int;
--Testcase 431:
ALTER FOREIGN TABLE ft1__postgres_srv__0 ALTER COLUMN c8 TYPE int;
--Testcase 432:
SELECT * FROM ft1 ftx(x1,x2,x3,x4,x5,x6,x7,x8) WHERE x1 = 1;  -- ERROR
--Testcase 433:
SELECT ftx.x1, ft2.c2, ftx.x8 FROM ft1 ftx(x1,x2,x3,x4,x5,x6,x7,x8), ft2
  WHERE ftx.x1 = ft2.c1 AND ftx.x1 = 1; -- ERROR
--Testcase 434:
SELECT ftx.x1, ft2.c2, ftx FROM ft1 ftx(x1,x2,x3,x4,x5,x6,x7,x8), ft2
  WHERE ftx.x1 = ft2.c1 AND ftx.x1 = 1; -- ERROR
--Testcase 435:
SELECT sum(c2), array_agg(c8) FROM ft1 GROUP BY c8; -- ERROR
ANALYZE ft1; -- ERROR
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE user_enum;
ALTER FOREIGN TABLE ft1__postgres_srv__0 ALTER COLUMN c8 TYPE user_enum;

-- ===================================================================
-- local type can be different from remote type in some cases,
-- in particular if similarly-named operators do equivalent things
-- ===================================================================
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE text;
ALTER FOREIGN TABLE ft1__postgres_srv__0 ALTER COLUMN c8 TYPE text;
--Testcase 1198:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE c8 = 'foo' LIMIT 1;
--Testcase 1199:
SELECT * FROM ft1 WHERE c8 = 'foo' LIMIT 1;
--Testcase 1200:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 WHERE 'foo' = c8 LIMIT 1;
--Testcase 1201:
SELECT * FROM ft1 WHERE 'foo' = c8 LIMIT 1;
-- we declared c8 to be text locally, but it's still the same type on
-- the remote which will balk if we try to do anything incompatible
-- with that remote type
--Testcase 1202:
SELECT * FROM ft1 WHERE c8 LIKE 'foo' LIMIT 1; -- ERROR
--Testcase 1203:
SELECT * FROM ft1 WHERE c8::text LIKE 'foo' LIMIT 1; -- ERROR; cast not pushed down
--Testcase 436:
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE user_enum;
--Testcase 437:
ALTER FOREIGN TABLE ft1__postgres_srv__0 ALTER COLUMN c8 TYPE user_enum;

-- ===================================================================
-- subtransaction
--  + local/remote error doesn't break cursor
-- ===================================================================
BEGIN;
DECLARE c CURSOR FOR SELECT * FROM ft1 ORDER BY c1;
--Testcase 438:
FETCH c;
SAVEPOINT s;
ERROR OUT;          -- ERROR
ROLLBACK TO s;
--Testcase 439:
FETCH c;
SAVEPOINT s;
--Testcase 440:
SELECT * FROM ft1 WHERE 1 / (c1 - 1) > 0;  -- ERROR
ROLLBACK TO s;
--Testcase 441:
FETCH c;
--Testcase 442:
SELECT * FROM ft1 ORDER BY c1 LIMIT 1;
COMMIT;

-- ===================================================================
-- enhanced for transaction/subtransaction
-- ===================================================================
--Testcase 1147:
BEGIN;
--Testcase 1148:
DECLARE c CURSOR FOR SELECT * FROM ft1;
--Testcase 1149:
FETCH c;
--Testcase 1150:
SAVEPOINT s;
--Testcase 1151:
ERROR OUT;          -- ERROR
--Testcase 1152:
ROLLBACK TO s;
--Testcase 1153:
FETCH c;
--Testcase 1154:
SAVEPOINT s;
--Testcase 1155:
COMMIT;

--Testcase 1156:
BEGIN;
--Testcase 1157:
SAVEPOINT s;
--Testcase 1158:
DECLARE c1 CURSOR FOR SELECT * FROM ft1 t1;
--Testcase 1159:
ROLLBACK TO s;
--Testcase 1160:
COMMIT;

--Testcase 1161:
BEGIN;
--Testcase 1162:
SAVEPOINT s;
--Testcase 1163:
DECLARE c1 CURSOR FOR SELECT * FROM ft1 t1;
--Testcase 1164:
COMMIT;

--Testcase 1165:
BEGIN;
--Testcase 1166:
DECLARE c CURSOR FOR SELECT * FROM ft1 t1;
--Testcase 1167:
SAVEPOINT s;
--Testcase 1168:
DECLARE c1 CURSOR FOR SELECT * FROM ft1 t1;
--Testcase 1169:
SAVEPOINT s2;
--Testcase 1170:
DECLARE c2 CURSOR FOR SELECT * FROM ft1 t1;
--Testcase 1171:
FETCH c1;
--Testcase 1172:
ERROR OUT;          -- ERROR
--Testcase 1173:
ROLLBACK TO s2;
--Testcase 1174:
FETCH c1;
--Testcase 1175:
ERROR OUT;          -- ERROR
--Testcase 1176:
ROLLBACK TO s;
--Testcase 1177:
FETCH c;
--Testcase 1178:
COMMIT;

-- test for timeout handler
-- enable timeout
set statement_timeout = 1000;
--Testcase 1179:
BEGIN;
--Testcase 1180:
DECLARE c1 CURSOR FOR SELECT * FROM ft1 t1;
--Testcase 1181:
SAVEPOINT s;
--Testcase 1182:
ERROR OUT;

-- wait to timeout
-- can not call postgres fucntion such as pg_sleep() when transaction abort
-- -> call the shell script
\! sleep 2

--Testcase 1183:
ROLLBACK TO s;
--Testcase 1184:
-- this case can has non-stable result because c1 CURSOR can be done before has any pending request.
--Testcase 1204:
FETCH 1000 FROM c1; -- should fail
--Testcase 1185:
FETCH c1; -- should fail
COMMIT;
-- disable timeout
set statement_timeout = 0;

-- ===================================================================
-- test handling of collations
-- ===================================================================
--Testcase 443:
create foreign table ft3 (f1 text collate "C", f2 text, f3 varchar(10), __spd_url text)
  server pgspider_srv;
--Testcase 444:
create foreign table loct3 (f1 text collate "C", f2 text, f3 varchar(10))
  server postgres_srv;
--Testcase 445:
create foreign table ft3__postgres_srv__0 (f1 text collate "C", f2 text, f3 varchar(10))
  server postgres_srv options (table_name 'loct3', use_remote_estimate 'true');

-- can be sent to remote
--Testcase 446:
explain (verbose, costs off) select * from ft3 where f1 = 'foo';
--Testcase 447:
explain (verbose, costs off) select * from ft3 where f1 COLLATE "C" = 'foo';
--Testcase 448:
explain (verbose, costs off) select * from ft3 where f2 = 'foo';
--Testcase 449:
explain (verbose, costs off) select * from ft3 where f3 = 'foo';
--Testcase 450:
explain (verbose, costs off) select * from ft3 f, loct3 l
  where f.f3 = l.f3 and l.f1 = 'foo';
-- can't be sent to remote
--Testcase 451:
explain (verbose, costs off) select * from ft3 where f1 COLLATE "POSIX" = 'foo';
--Testcase 452:
explain (verbose, costs off) select * from ft3 where f1 = 'foo' COLLATE "C";
--Testcase 453:
explain (verbose, costs off) select * from ft3 where f2 COLLATE "C" = 'foo';
--Testcase 454:
explain (verbose, costs off) select * from ft3 where f2 = 'foo' COLLATE "C";
--Testcase 455:
explain (verbose, costs off) select * from ft3 f, loct3 l
  where f.f3 = l.f3 COLLATE "POSIX" and l.f1 = 'foo';

-- ===================================================================
-- test writable foreign table stuff
-- ===================================================================
--Testcase 456:
EXPLAIN (verbose, costs off)
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3) SELECT c1+1000,c2+100, c3 || c3 FROM ft2 LIMIT 20;
--Testcase 457:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3) SELECT c1+1000,c2+100, c3 || c3 FROM ft2 LIMIT 20;
--Testcase 458:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3)
  VALUES (1101,201,'aaa'), (1102,202,'bbb'), (1103,203,'ccc') RETURNING *;
--Testcase 459:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3) VALUES (1104,204,'ddd'), (1105,205,'eee');
--Testcase 460:
EXPLAIN (verbose, costs off)
UPDATE ft2__postgres_srv__0 SET c2 = c2 + 300, c3 = c3 || '_update3' WHERE c1 % 10 = 3;              -- can be pushed down
--Testcase 461:
UPDATE ft2__postgres_srv__0 SET c2 = c2 + 300, c3 = c3 || '_update3' WHERE c1 % 10 = 3;
--Testcase 462:
EXPLAIN (verbose, costs off)
UPDATE ft2__postgres_srv__0 SET c2 = c2 + 400, c3 = c3 || '_update7' WHERE c1 % 10 = 7 RETURNING *;  -- can be pushed down
--Testcase 463:
UPDATE ft2__postgres_srv__0 SET c2 = c2 + 400, c3 = c3 || '_update7' WHERE c1 % 10 = 7 RETURNING *;
--Testcase 464:
EXPLAIN (verbose, costs off)
UPDATE ft2__postgres_srv__0 SET c2 = ft2__postgres_srv__0.c2 + 500, c3 = ft2__postgres_srv__0.c3 || '_update9', c7 = DEFAULT
  FROM ft1 WHERE ft1.c1 = ft2__postgres_srv__0.c2 AND ft1.c1 % 10 = 9;                               -- can be pushed down
--Testcase 465:
UPDATE ft2__postgres_srv__0 SET c2 = ft2__postgres_srv__0.c2 + 500, c3 = ft2__postgres_srv__0.c3 || '_update9', c7 = DEFAULT
  FROM ft1 WHERE ft1.c1 = ft2__postgres_srv__0.c2 AND ft1.c1 % 10 = 9;
--Testcase 466:
EXPLAIN (verbose, costs off)
  DELETE FROM ft2__postgres_srv__0 WHERE c1 % 10 = 5 RETURNING c1, c4;                               -- can be pushed down
--Testcase 467:
DELETE FROM ft2__postgres_srv__0 WHERE c1 % 10 = 5 RETURNING c1, c4;
--Testcase 468:
EXPLAIN (verbose, costs off)
DELETE FROM ft2__postgres_srv__0 USING ft1 WHERE ft1.c1 = ft2__postgres_srv__0.c2 AND ft1.c1 % 10 = 2;                -- can be pushed down
--Testcase 469:
DELETE FROM ft2__postgres_srv__0 USING ft1 WHERE ft1.c1 = ft2__postgres_srv__0.c2 AND ft1.c1 % 10 = 2;
--Testcase 470:
SELECT c1,c2,c3,c4 FROM ft2 ORDER BY c1;
--Testcase 471:
EXPLAIN (verbose, costs off)
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3) VALUES (1200,999,'foo') RETURNING tableoid::regclass;
--Testcase 472:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3) VALUES (1200,999,'foo') RETURNING tableoid::regclass;
--Testcase 473:
EXPLAIN (verbose, costs off)
UPDATE ft2__postgres_srv__0 SET c3 = 'bar' WHERE c1 = 1200 RETURNING tableoid::regclass;             -- can be pushed down
--Testcase 474:
UPDATE ft2__postgres_srv__0 SET c3 = 'bar' WHERE c1 = 1200 RETURNING tableoid::regclass;
--Testcase 475:
EXPLAIN (verbose, costs off)
DELETE FROM ft2__postgres_srv__0 WHERE c1 = 1200 RETURNING tableoid::regclass;                       -- can be pushed down
--Testcase 476:
DELETE FROM ft2__postgres_srv__0 WHERE c1 = 1200 RETURNING tableoid::regclass;

-- Test UPDATE/DELETE with RETURNING on a three-table join
--Testcase 477:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3)
  SELECT id, id - 1200, to_char(id, 'FM00000') FROM generate_series(1201, 1300) id;
--Testcase 478:
EXPLAIN (verbose, costs off)
UPDATE ft2__postgres_srv__0 SET c3 = 'foo'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2__postgres_srv__0.c1 > 1200 AND ft2__postgres_srv__0.c2 = ft4.c1
  RETURNING ft2__postgres_srv__0, ft2__postgres_srv__0.*, ft4, ft4.*;       -- can be pushed down
--Testcase 479:
UPDATE ft2__postgres_srv__0 SET c3 = 'foo'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2__postgres_srv__0.c1 > 1200 AND ft2__postgres_srv__0.c2 = ft4.c1
  RETURNING ft2__postgres_srv__0, ft2__postgres_srv__0.*, ft4, ft4.*;
--Testcase 480:
EXPLAIN (verbose, costs off)
DELETE FROM ft2__postgres_srv__0
  USING ft4 LEFT JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2__postgres_srv__0.c1 > 1200 AND ft2__postgres_srv__0.c1 % 10 = 0 AND ft2__postgres_srv__0.c2 = ft4.c1
  RETURNING 100;                          -- can be pushed down
--Testcase 481:
DELETE FROM ft2__postgres_srv__0
  USING ft4 LEFT JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2__postgres_srv__0.c1 > 1200 AND ft2__postgres_srv__0.c1 % 10 = 0 AND ft2__postgres_srv__0.c2 = ft4.c1
  RETURNING 100;
--Testcase 482:
DELETE FROM ft2__postgres_srv__0 WHERE ft2__postgres_srv__0.c1 > 1200;

-- Test UPDATE with a MULTIEXPR sub-select
-- (maybe someday this'll be remotely executable, but not today)
--Testcase 483:
EXPLAIN (verbose, costs off)
UPDATE ft2__postgres_srv__0 AS target SET (c2, c7) = (
    SELECT c2 * 10, c7
        FROM ft2__postgres_srv__0 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;
--Testcase 484:
UPDATE ft2__postgres_srv__0 AS target SET (c2, c7) = (
    SELECT c2 * 10, c7
        FROM ft2__postgres_srv__0 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;

--Testcase 485:
UPDATE ft2__postgres_srv__0 AS target SET (c2) = (
    SELECT c2 / 10
        FROM ft2__postgres_srv__0 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;

-- Test UPDATE involving a join that can be pushed down,
-- but a SET clause that can't be
--Testcase 486:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE ft2__postgres_srv__0 d SET c2 = CASE WHEN random() >= 0 THEN d.c2 ELSE 0 END
  FROM ft2__postgres_srv__0 AS t WHERE d.c1 = t.c1 AND d.c1 > 1000;
--Testcase 487:
UPDATE ft2__postgres_srv__0 d SET c2 = CASE WHEN random() >= 0 THEN d.c2 ELSE 0 END
  FROM ft2__postgres_srv__0 AS t WHERE d.c1 = t.c1 AND d.c1 > 1000;

-- Test UPDATE/DELETE with WHERE or JOIN/ON conditions containing
-- user-defined operators/functions
--Testcase 488:
ALTER SERVER postgres_srv OPTIONS (DROP extensions);
--Testcase 489:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3)
  SELECT id, id % 10, to_char(id, 'FM00000') FROM generate_series(2001, 2010) id;
--Testcase 490:
EXPLAIN (verbose, costs off)
UPDATE ft2__postgres_srv__0 SET c3 = 'bar' WHERE postgres_fdw_abs(c1) > 2000 RETURNING *;            -- can't be pushed down
--Testcase 491:
UPDATE ft2__postgres_srv__0 SET c3 = 'bar' WHERE postgres_fdw_abs(c1) > 2000 RETURNING *;
--Testcase 492:
EXPLAIN (verbose, costs off)
UPDATE ft2__postgres_srv__0 SET c3 = 'baz'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2__postgres_srv__0.c1 > 2000 AND ft2__postgres_srv__0.c2 === ft4.c1
  RETURNING ft2__postgres_srv__0.*, ft4.*, ft5.*;                                                    -- can't be pushed down
--Testcase 493:
UPDATE ft2__postgres_srv__0 SET c3 = 'baz'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2__postgres_srv__0.c1 > 2000 AND ft2__postgres_srv__0.c2 === ft4.c1
  RETURNING ft2__postgres_srv__0.*, ft4.*, ft5.*;
--Testcase 494:
EXPLAIN (verbose, costs off)
DELETE FROM ft2__postgres_srv__0
  USING ft4 INNER JOIN ft5 ON (ft4.c1 === ft5.c1)
  WHERE ft2__postgres_srv__0.c1 > 2000 AND ft2__postgres_srv__0.c2 = ft4.c1
  RETURNING ft2__postgres_srv__0.c1, ft2__postgres_srv__0.c2, ft2__postgres_srv__0.c3;       -- can't be pushed down
--Testcase 495:
DELETE FROM ft2__postgres_srv__0
  USING ft4 INNER JOIN ft5 ON (ft4.c1 === ft5.c1)
  WHERE ft2__postgres_srv__0.c1 > 2000 AND ft2__postgres_srv__0.c2 = ft4.c1
  RETURNING ft2__postgres_srv__0.c1, ft2__postgres_srv__0.c2, ft2__postgres_srv__0.c3;
-- DELETE FROM ft2 WHERE ft2.c1 > 2000;
--Testcase 496:
DELETE FROM ft2__postgres_srv__0 WHERE ft2__postgres_srv__0.c1 > 2000;
--Testcase 497:
ALTER SERVER postgres_srv OPTIONS (ADD extensions 'postgres_fdw');

-- Test that trigger on remote table works as expected
--Testcase 498:
CREATE OR REPLACE FUNCTION "S 1".F_BRTRIG() RETURNS trigger AS $$
BEGIN
    NEW.c3 = NEW.c3 || '_trig_update';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
--Testcase 499:
CREATE TRIGGER t1_br_insert BEFORE INSERT OR UPDATE
    ON "S 1"."T 1" FOR EACH ROW EXECUTE PROCEDURE "S 1".F_BRTRIG();
--Testcase 500:
SELECT dblink_exec('CREATE TRIGGER t1_br_insert BEFORE INSERT OR UPDATE
    ON "S 1"."T 1" FOR EACH ROW EXECUTE PROCEDURE "S 1".F_BRTRIG();');

--Testcase 501:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3) VALUES (1208, 818, 'fff') RETURNING *;
--Testcase 502:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3,c6) VALUES (1218, 818, 'ggg', '(--;') RETURNING *;
--Testcase 503:
UPDATE ft2__postgres_srv__0 SET c2 = c2 + 600 WHERE c1 % 10 = 8 AND c1 < 1200 RETURNING *;

-- Test errors thrown on remote side during update
--Testcase 504:
ALTER TABLE "S 1"."T 1" ADD CONSTRAINT c2positive CHECK (c2 >= 0);
--Testcase 505:
SELECT dblink_exec('ALTER TABLE "S 1"."T 1" ADD CONSTRAINT c2positive CHECK (c2 >= 0);');

--Testcase 506:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(11, 12);  -- duplicate key
--Testcase 507:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(11, 12) ON CONFLICT DO NOTHING; -- works
--Testcase 508:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(11, 12) ON CONFLICT (c1, c2) DO NOTHING; -- unsupported
--Testcase 509:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(11, 12) ON CONFLICT (c1, c2) DO UPDATE SET c3 = 'ffg'; -- unsupported
--Testcase 510:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(1111, -2);  -- c2positive
--Testcase 511:
UPDATE ft1__postgres_srv__0 SET c2 = -c2 WHERE c1 = 1;  -- c2positive

-- Test savepoint/rollback behavior
--Testcase 512:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
--Testcase 513:
select c2, count(*) from "S 1"."T 1" where c2 < 500 group by 1 order by 1;
begin;
--Testcase 514:
update ft2__postgres_srv__0 set c2 = 42 where c2 = 0;
--Testcase 515:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
savepoint s1;
--Testcase 516:
update ft2__postgres_srv__0 set c2 = 44 where c2 = 4;
--Testcase 517:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
release savepoint s1;
--Testcase 518:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
savepoint s2;
--Testcase 519:
update ft2__postgres_srv__0 set c2 = 46 where c2 = 6;
--Testcase 520:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
rollback to savepoint s2;
--Testcase 521:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
release savepoint s2;
--Testcase 522:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
savepoint s3;
--Testcase 523:
update ft2__postgres_srv__0 set c2 = -2 where c2 = 42 and c1 = 10; -- fail on remote side
rollback to savepoint s3;
--Testcase 524:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
release savepoint s3;
--Testcase 525:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
-- none of the above is committed yet remotely
--Testcase 526:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
commit;
--Testcase 527:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
--Testcase 528:
select c2, count(*) from "S 1"."T 1" where c2 < 500 group by 1 order by 1;

-- VACUUM ANALYZE "S 1"."T 1";

-- Above DMLs add data with c6 as NULL in ft1, so test ORDER BY NULLS LAST and NULLs
-- FIRST behavior here.
-- ORDER BY DESC NULLS LAST options
--Testcase 529:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 DESC NULLS LAST, c1 OFFSET 795 LIMIT 10;
--Testcase 530:
SELECT * FROM ft1 ORDER BY c6 DESC NULLS LAST, c1 OFFSET 795  LIMIT 10;
-- ORDER BY DESC NULLS FIRST options
--Testcase 531:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 DESC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
--Testcase 532:
SELECT * FROM ft1 ORDER BY c6 DESC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
-- ORDER BY ASC NULLS FIRST options
--Testcase 533:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 ASC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
--Testcase 534:
SELECT * FROM ft1 ORDER BY c6 ASC NULLS FIRST, c1 OFFSET 15 LIMIT 10;

-- ===================================================================
-- test check constraints
-- ===================================================================

-- Consistent check constraints provide consistent results
--Testcase 535:
ALTER FOREIGN TABLE ft1 ADD CONSTRAINT ft1_c2positive CHECK (c2 >= 0);
--Testcase 536:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 537:
SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 538:
SET constraint_exclusion = 'on';
--Testcase 539:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 540:
SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 541:
RESET constraint_exclusion;
-- check constraint is enforced on the remote side, not locally
--Testcase 542:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(1111, -2);  -- c2positive
--Testcase 543:
UPDATE ft1__postgres_srv__0 SET c2 = -c2 WHERE c1 = 1;  -- c2positive
--Testcase 544:
ALTER FOREIGN TABLE ft1 DROP CONSTRAINT ft1_c2positive;

-- But inconsistent check constraints provide inconsistent results
--Testcase 545:
ALTER FOREIGN TABLE ft1 ADD CONSTRAINT ft1_c2negative CHECK (c2 < 0);
--Testcase 546:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 547:
SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 548:
SET constraint_exclusion = 'on';
--Testcase 549:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 550:
SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 551:
RESET constraint_exclusion;
-- local check constraint is not actually enforced
--Testcase 552:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(1111, 2);
--Testcase 553:
UPDATE ft1__postgres_srv__0 SET c2 = c2 + 1 WHERE c1 = 1;
--Testcase 554:
ALTER FOREIGN TABLE ft1 DROP CONSTRAINT ft1_c2negative;

-- ===================================================================
-- test WITH CHECK OPTION constraints
-- ===================================================================

--Testcase 555:
CREATE FUNCTION row_before_insupd_trigfunc() RETURNS trigger AS $$BEGIN NEW.a := NEW.a + 10; RETURN NEW; END$$ LANGUAGE plpgsql;

--Testcase 556:
SELECT dblink_exec('CREATE TRIGGER row_before_insupd_trigger BEFORE INSERT OR UPDATE ON base_tbl
  FOR EACH ROW EXECUTE PROCEDURE row_before_insupd_trigfunc();');
--Testcase 557:
CREATE FOREIGN TABLE foreign_tbl (a int, b int, __spd_url text)
  SERVER pgspider_srv;
--Testcase 558:
CREATE FOREIGN TABLE foreign_tbl__postgres_srv__0 (a int, b int)
  SERVER postgres_srv OPTIONS(table_name 'base_tbl');
--Testcase 559:
CREATE VIEW rw_view AS SELECT * FROM foreign_tbl
  WHERE a < b WITH CHECK OPTION;
--Testcase 560:
\d+ rw_view

--EXPLAIN (VERBOSE, COSTS OFF)
--INSERT INTO rw_view VALUES (0, 5);
--INSERT INTO rw_view VALUES (0, 5); -- should fail
--EXPLAIN (VERBOSE, COSTS OFF)
--INSERT INTO rw_view VALUES (0, 15);
--INSERT INTO rw_view VALUES (0, 15); -- ok
--SELECT * FROM foreign_tbl;

--EXPLAIN (VERBOSE, COSTS OFF)
--UPDATE rw_view SET b = b + 5;
--UPDATE rw_view SET b = b + 5; -- should fail
--EXPLAIN (VERBOSE, COSTS OFF)
--UPDATE rw_view SET b = b + 15;
--UPDATE rw_view SET b = b + 15; -- ok
--SELECT * FROM foreign_tbl;

-- -- We don't allow batch insert when there are any WCO constraints
-- ALTER SERVER postgres_srv OPTIONS (ADD batch_size '10');
-- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO rw_view VALUES (0, 15), (0, 5);
-- INSERT INTO rw_view VALUES (0, 15), (0, 5); -- should fail
-- SELECT * FROM foreign_tbl;
-- ALTER SERVER postgres_srv OPTIONS (DROP batch_size);

--Testcase 561:
DROP FOREIGN TABLE foreign_tbl CASCADE;
--Testcase 562:
DROP FOREIGN TABLE foreign_tbl__postgres_srv__0 CASCADE;
--Testcase 563:
SELECT dblink_exec('DROP TRIGGER row_before_insupd_trigger ON base_tbl;');
--Testcase 564:
SELECT dblink_exec('DROP TABLE base_tbl;');

-- test WCO for partitions

--Testcase 565:
SELECT dblink_exec('CREATE TRIGGER row_before_insupd_trigger BEFORE INSERT OR UPDATE ON child_tbl FOR EACH ROW EXECUTE PROCEDURE row_before_insupd_trigfunc();');
--Testcase 566:
CREATE FOREIGN TABLE foreign_tbl (a int, b int, __spd_url text)
  SERVER pgspider_srv;
--Testcase 567:
CREATE FOREIGN TABLE foreign_tbl__postgres_srv__0 (a int, b int)
  SERVER postgres_srv OPTIONS(table_name 'child_tbl');

--Testcase 568:
CREATE TABLE parent_tbl (a int, b int, __spd_url text) PARTITION BY RANGE(a);
--Testcase 569:
ALTER TABLE parent_tbl ATTACH PARTITION foreign_tbl FOR VALUES FROM (0) TO (100);
-- Detach and re-attach once, to stress the concurrent detach case.
ALTER TABLE parent_tbl DETACH PARTITION foreign_tbl CONCURRENTLY;
ALTER TABLE parent_tbl ATTACH PARTITION foreign_tbl FOR VALUES FROM (0) TO (100);

--Testcase 570:
CREATE VIEW rw_view AS SELECT * FROM parent_tbl
  WHERE a < b WITH CHECK OPTION;
--Testcase 571:
\d+ rw_view

--EXPLAIN (VERBOSE, COSTS OFF)
--INSERT INTO rw_view VALUES (0, 5);
--INSERT INTO rw_view VALUES (0, 5); -- should fail
--EXPLAIN (VERBOSE, COSTS OFF)
--INSERT INTO rw_view VALUES (0, 15);
--INSERT INTO rw_view VALUES (0, 15); -- ok
--SELECT * FROM foreign_tbl;

--EXPLAIN (VERBOSE, COSTS OFF)
--UPDATE rw_view SET b = b + 5;
--UPDATE rw_view SET b = b + 5; -- should fail
--EXPLAIN (VERBOSE, COSTS OFF)
--UPDATE rw_view SET b = b + 15;
--UPDATE rw_view SET b = b + 15; -- ok
--SELECT * FROM foreign_tbl;

-- -- We don't allow batch insert when there are any WCO constraints
-- ALTER SERVER postgres_srv OPTIONS (ADD batch_size '10');
-- EXPLAIN (VERBOSE, COSTS OFF)
-- INSERT INTO rw_view VALUES (0, 15), (0, 5);
-- INSERT INTO rw_view VALUES (0, 15), (0, 5); -- should fail
-- SELECT * FROM foreign_tbl;
-- ALTER SERVER postgres_srv OPTIONS (DROP batch_size);

--Testcase 572:
DROP FOREIGN TABLE foreign_tbl CASCADE;
--Testcase 573:
DROP FOREIGN TABLE foreign_tbl__postgres_srv__0 CASCADE;
--Testcase 574:
SELECT dblink_exec('DROP TRIGGER row_before_insupd_trigger ON child_tbl;');
--Testcase 575:
DROP TABLE parent_tbl CASCADE;;

--Testcase 576:
DROP FUNCTION row_before_insupd_trigfunc;

-- ===================================================================
-- test serial columns (ie, sequence-based defaults)
-- ===================================================================
--Testcase 577:
create foreign table rem1 (f1 serial, f2 text, __spd_url text)
  server pgspider_srv;
--Testcase 578:
create foreign table rem1__postgres_srv__0 (f1 serial, f2 text)
  server postgres_srv options(table_name 'loc1_1');
--Testcase 579:
select pg_catalog.setval('rem1__postgres_srv__0_f1_seq', 10, false);
--Testcase 580:
select dblink_exec('insert into loc1_1(f2) values(''hi'');');
--Testcase 581:
insert into rem1__postgres_srv__0(f2) values('hi remote');
--Testcase 582:
select dblink_exec('insert into loc1_1(f2) values(''bye'');');
--Testcase 583:
insert into rem1__postgres_srv__0(f2) values('bye remote');
--Testcase 584:
select * from rem1;
--Testcase 585:
select * from rem1__postgres_srv__0;

-- ===================================================================
-- test generated columns
-- ===================================================================
--Testcase 586:
create foreign table grem1 (
  a int,
  b int generated always as (a * 2) stored,
  __spd_url text)
  server pgspider_srv;
--Testcase 587:
create foreign table grem1__postgres_srv__0 (
  a int,
  b int generated always as (a * 2) stored)
  server postgres_srv options(table_name 'gloc1');
--Testcase 588:
explain (verbose, costs off)
insert into grem1__postgres_srv__0 (a) values (1), (2);
--Testcase 1205:
insert into grem1__postgres_srv__0 (a) values (1), (2);
--Testcase 589:
explain (verbose, costs off)
update grem1__postgres_srv__0 set a = 22 where a = 2;
--Testcase 1206:
update grem1__postgres_srv__0 set a = 22 where a = 2;
--Testcase 590:
select * from grem1;
--Testcase 1207:
select * from grem1__postgres_srv__0;
--Testcase 1208:
delete from grem1__postgres_srv__0;

-- test copy from
copy grem1__postgres_srv__0 from stdin;
1
2
\.
--Testcase 1209:
select * from grem1;
--Testcase 1210:
select * from grem1__postgres_srv__0;
--Testcase 1211:
delete from grem1__postgres_srv__0;

-- test batch insert
alter server postgres_srv options (add batch_size '10');
--Testcase 1212:
explain (verbose, costs off)
insert into grem1__postgres_srv__0 (a) values (1), (2);
--Testcase 1213:
insert into grem1__postgres_srv__0 (a) values (1), (2);
--Testcase 1214:
select * from grem1;
--Testcase 1215:
select * from grem1__postgres_srv__0;
--Testcase 1216:
delete from grem1__postgres_srv__0;
alter server postgres_srv options (drop batch_size);

-- ===================================================================
-- test local triggers
-- ===================================================================

-- Trigger functions "borrowed" from triggers regress test.
--Testcase 591:
CREATE FUNCTION trigger_func() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
	RAISE NOTICE 'trigger_func(%) called: action = %, when = %, level = %',
		TG_ARGV[0], TG_OP, TG_WHEN, TG_LEVEL;
	RETURN NULL;
END;$$;

--Testcase 592:
CREATE TRIGGER trig_stmt_before BEFORE DELETE OR INSERT OR UPDATE ON rem1__postgres_srv__0
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 593:
CREATE TRIGGER trig_stmt_after AFTER DELETE OR INSERT OR UPDATE ON rem1__postgres_srv__0
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();

--Testcase 594:
CREATE OR REPLACE FUNCTION trigger_data()  RETURNS trigger
LANGUAGE plpgsql AS $$

declare
	oldnew text[];
	relid text;
    argstr text;
begin

	relid := TG_relid::regclass;
	argstr := '';
	for i in 0 .. TG_nargs - 1 loop
		if i > 0 then
			argstr := argstr || ', ';
		end if;
		argstr := argstr || TG_argv[i];
	end loop;

    RAISE NOTICE '%(%) % % % ON %',
		tg_name, argstr, TG_when, TG_level, TG_OP, relid;
    oldnew := '{}'::text[];
	if TG_OP != 'INSERT' then
		oldnew := array_append(oldnew, format('OLD: %s', OLD));
	end if;

	if TG_OP != 'DELETE' then
		oldnew := array_append(oldnew, format('NEW: %s', NEW));
	end if;

    RAISE NOTICE '%', array_to_string(oldnew, ',');

	if TG_OP = 'DELETE' then
		return OLD;
	else
		return NEW;
	end if;
end;
$$;

-- Test basic functionality
--Testcase 595:
CREATE TRIGGER trig_row_before
BEFORE INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 596:
CREATE TRIGGER trig_row_after
AFTER INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 597:
delete from rem1__postgres_srv__0;
--Testcase 598:
insert into rem1__postgres_srv__0 values(1,'insert');
--Testcase 599:
update rem1__postgres_srv__0 set f2  = 'update' where f1 = 1;
--Testcase 600:
update rem1__postgres_srv__0 set f2 = f2 || f2;


-- cleanup
--Testcase 601:
DROP TRIGGER trig_row_before ON rem1__postgres_srv__0;
--Testcase 602:
DROP TRIGGER trig_row_after ON rem1__postgres_srv__0;
--Testcase 603:
DROP TRIGGER trig_stmt_before ON rem1__postgres_srv__0;
--Testcase 604:
DROP TRIGGER trig_stmt_after ON rem1__postgres_srv__0;

--Testcase 605:
DELETE from rem1__postgres_srv__0;

-- Test multiple AFTER ROW triggers on a foreign table
--Testcase 606:
CREATE TRIGGER trig_row_after1
AFTER INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 607:
CREATE TRIGGER trig_row_after2
AFTER INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 608:
insert into rem1__postgres_srv__0 values(1,'insert');
--Testcase 609:
update rem1__postgres_srv__0 set f2  = 'update' where f1 = 1;
--Testcase 610:
update rem1__postgres_srv__0 set f2 = f2 || f2;
--Testcase 611:
delete from rem1__postgres_srv__0;

-- cleanup
--Testcase 612:
DROP TRIGGER trig_row_after1 ON rem1__postgres_srv__0;
--Testcase 613:
DROP TRIGGER trig_row_after2 ON rem1__postgres_srv__0;

-- Test WHEN conditions

--Testcase 614:
CREATE TRIGGER trig_row_before_insupd
BEFORE INSERT OR UPDATE ON rem1__postgres_srv__0
FOR EACH ROW
WHEN (NEW.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 615:
CREATE TRIGGER trig_row_after_insupd
AFTER INSERT OR UPDATE ON rem1__postgres_srv__0
FOR EACH ROW
WHEN (NEW.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

-- Insert or update not matching: nothing happens
--Testcase 616:
INSERT INTO rem1__postgres_srv__0 values(1, 'insert');
--Testcase 617:
UPDATE rem1__postgres_srv__0 set f2 = 'test';

-- Insert or update matching: triggers are fired
--Testcase 618:
INSERT INTO rem1__postgres_srv__0 values(2, 'update');
--Testcase 619:
UPDATE rem1__postgres_srv__0 set f2 = 'update update' where f1 = '2';

--Testcase 620:
CREATE TRIGGER trig_row_before_delete
BEFORE DELETE ON rem1__postgres_srv__0
FOR EACH ROW
WHEN (OLD.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 621:
CREATE TRIGGER trig_row_after_delete
AFTER DELETE ON rem1__postgres_srv__0
FOR EACH ROW
WHEN (OLD.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

-- Trigger is fired for f1=2, not for f1=1
--Testcase 622:
DELETE FROM rem1__postgres_srv__0;

-- cleanup
--Testcase 623:
DROP TRIGGER trig_row_before_insupd ON rem1__postgres_srv__0;
--Testcase 624:
DROP TRIGGER trig_row_after_insupd ON rem1__postgres_srv__0;
--Testcase 625:
DROP TRIGGER trig_row_before_delete ON rem1__postgres_srv__0;
--Testcase 626:
DROP TRIGGER trig_row_after_delete ON rem1__postgres_srv__0;


-- Test various RETURN statements in BEFORE triggers.

--Testcase 627:
CREATE FUNCTION trig_row_before_insupdate() RETURNS TRIGGER AS $$
  BEGIN
    NEW.f2 := NEW.f2 || ' triggered !';
    RETURN NEW;
  END
$$ language plpgsql;

--Testcase 628:
CREATE TRIGGER trig_row_before_insupd
BEFORE INSERT OR UPDATE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

-- The new values should have 'triggered' appended
--Testcase 629:
INSERT INTO rem1__postgres_srv__0 values(1, 'insert');
--Testcase 630:
SELECT * from rem1;
--Testcase 631:
INSERT INTO rem1__postgres_srv__0 values(2, 'insert') RETURNING f2;
--Testcase 632:
SELECT * from rem1;
--Testcase 633:
UPDATE rem1__postgres_srv__0 set f2 = '';
--Testcase 634:
SELECT * from rem1;
--Testcase 635:
UPDATE rem1__postgres_srv__0 set f2 = 'skidoo' RETURNING f2;
--Testcase 636:
SELECT * from rem1;

--Testcase 637:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f1 = 10;          -- all columns should be transmitted
--Testcase 638:
UPDATE rem1__postgres_srv__0 set f1 = 10;
--Testcase 639:
SELECT * from rem1;

--Testcase 640:
DELETE FROM rem1__postgres_srv__0;

-- Add a second trigger, to check that the changes are propagated correctly
-- from trigger to trigger
--Testcase 641:
CREATE TRIGGER trig_row_before_insupd2
BEFORE INSERT OR UPDATE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

--Testcase 642:
INSERT INTO rem1__postgres_srv__0 values(1, 'insert');
--Testcase 643:
SELECT * from rem1;
--Testcase 644:
INSERT INTO rem1__postgres_srv__0 values(2, 'insert') RETURNING f2;
--Testcase 645:
SELECT * from rem1;
--Testcase 646:
UPDATE rem1__postgres_srv__0 set f2 = '';
--Testcase 647:
SELECT * from rem1;
--Testcase 648:
UPDATE rem1__postgres_srv__0 set f2 = 'skidoo' RETURNING f2;
--Testcase 649:
SELECT * from rem1;

--Testcase 650:
DROP TRIGGER trig_row_before_insupd ON rem1__postgres_srv__0;
--Testcase 651:
DROP TRIGGER trig_row_before_insupd2 ON rem1__postgres_srv__0;

--Testcase 652:
DELETE from rem1__postgres_srv__0;

--Testcase 653:
INSERT INTO rem1__postgres_srv__0 VALUES (1, 'test');

-- Test with a trigger returning NULL
--Testcase 654:
CREATE FUNCTION trig_null() RETURNS TRIGGER AS $$
  BEGIN
    RETURN NULL;
  END
$$ language plpgsql;

--Testcase 655:
CREATE TRIGGER trig_null
BEFORE INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trig_null();

-- Nothing should have changed.
--Testcase 656:
INSERT INTO rem1__postgres_srv__0 VALUES (2, 'test2');

--Testcase 657:
SELECT * from rem1;

--Testcase 658:
UPDATE rem1__postgres_srv__0 SET f2 = 'test2';

--Testcase 659:
SELECT * from rem1;

--Testcase 660:
DELETE from rem1__postgres_srv__0;

--Testcase 661:
SELECT * from rem1;

--Testcase 662:
DROP TRIGGER trig_null ON rem1__postgres_srv__0;
--Testcase 663:
DELETE from rem1__postgres_srv__0;

-- Test a combination of local and remote triggers
--Testcase 664:
CREATE TRIGGER trig_row_before
BEFORE INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 665:
CREATE TRIGGER trig_row_after
AFTER INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 666:
CREATE TRIGGER trig_local_before BEFORE INSERT OR UPDATE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

--Testcase 667:
INSERT INTO rem1__postgres_srv__0(f2) VALUES ('test');
--Testcase 668:
UPDATE rem1__postgres_srv__0 SET f2 = 'testo';

-- Test returning a system attribute
--Testcase 669:
INSERT INTO rem1__postgres_srv__0(f2) VALUES ('test') RETURNING ctid;

-- cleanup
--Testcase 670:
DROP TRIGGER trig_row_before ON rem1__postgres_srv__0;
--Testcase 671:
DROP TRIGGER trig_row_after ON rem1__postgres_srv__0;
--Testcase 672:
DROP TRIGGER trig_local_before ON rem1__postgres_srv__0;


-- Test direct foreign table modification functionality
--Testcase 1217:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
--Testcase 1218:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0 WHERE false;     -- currently can't be pushed down

-- Test with statement-level triggers
--Testcase 673:
CREATE TRIGGER trig_stmt_before
	BEFORE DELETE OR INSERT OR UPDATE ON rem1__postgres_srv__0
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 674:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can be pushed down
--Testcase 675:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
--Testcase 676:
DROP TRIGGER trig_stmt_before ON rem1__postgres_srv__0;

--Testcase 677:
CREATE TRIGGER trig_stmt_after
	AFTER DELETE OR INSERT OR UPDATE ON rem1__postgres_srv__0
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 678:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can be pushed down
--Testcase 679:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
--Testcase 680:
DROP TRIGGER trig_stmt_after ON rem1__postgres_srv__0;

-- Test with row-level ON INSERT triggers
--Testcase 681:
CREATE TRIGGER trig_row_before_insert
BEFORE INSERT ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 682:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can be pushed down
--Testcase 683:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
--Testcase 684:
DROP TRIGGER trig_row_before_insert ON rem1__postgres_srv__0;

--Testcase 685:
CREATE TRIGGER trig_row_after_insert
AFTER INSERT ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 686:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can be pushed down
--Testcase 687:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
--Testcase 688:
DROP TRIGGER trig_row_after_insert ON rem1__postgres_srv__0;

-- Test with row-level ON UPDATE triggers
--Testcase 689:
CREATE TRIGGER trig_row_before_update
BEFORE UPDATE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 690:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can't be pushed down
--Testcase 691:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
--Testcase 692:
DROP TRIGGER trig_row_before_update ON rem1__postgres_srv__0;

--Testcase 693:
CREATE TRIGGER trig_row_after_update
AFTER UPDATE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 694:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can't be pushed down
--Testcase 695:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
--Testcase 696:
DROP TRIGGER trig_row_after_update ON rem1__postgres_srv__0;

-- Test with row-level ON DELETE triggers
--Testcase 697:
CREATE TRIGGER trig_row_before_delete
BEFORE DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 698:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can be pushed down
--Testcase 699:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can't be pushed down
--Testcase 700:
DROP TRIGGER trig_row_before_delete ON rem1__postgres_srv__0;

--Testcase 701:
CREATE TRIGGER trig_row_after_delete
AFTER DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 702:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can be pushed down
--Testcase 703:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can't be pushed down
--Testcase 704:
DROP TRIGGER trig_row_after_delete ON rem1__postgres_srv__0;

-- ===================================================================
-- test inheritance features
-- ===================================================================

--Testcase 705:
CREATE TABLE a (aa TEXT);
--Testcase 706:
CREATE FOREIGN TABLE b (aa TEXT, bb TEXT, __spd_url TEXT)
  SERVER pgspider_srv;
--Testcase 707:
CREATE FOREIGN TABLE b__postgres_srv__0 (bb TEXT) INHERITS (a)
  SERVER postgres_srv OPTIONS (table_name 'loct_1');

--Testcase 708:
INSERT INTO a(aa) VALUES('aaa');
--Testcase 709:
INSERT INTO a(aa) VALUES('aaaa');
--Testcase 710:
INSERT INTO a(aa) VALUES('aaaaa');

--Testcase 711:
INSERT INTO b__postgres_srv__0(aa) VALUES('bbb');
--Testcase 712:
INSERT INTO b__postgres_srv__0(aa) VALUES('bbbb');
--Testcase 713:
INSERT INTO b__postgres_srv__0(aa) VALUES('bbbbb');

--Testcase 714:
SELECT tableoid::regclass, * FROM a;
--Testcase 715:
SELECT tableoid::regclass, * FROM b;
--Testcase 716:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 717:
UPDATE a SET aa = 'zzzzzz' WHERE aa LIKE 'aaaa%';

--Testcase 718:
SELECT tableoid::regclass, * FROM a;
--Testcase 719:
SELECT tableoid::regclass, * FROM b;
--Testcase 720:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 721:
UPDATE b__postgres_srv__0 SET aa = 'new';

--Testcase 722:
SELECT tableoid::regclass, * FROM a;
--Testcase 723:
SELECT tableoid::regclass, * FROM b;
--Testcase 724:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 725:
UPDATE a SET aa = 'newtoo';

--Testcase 726:
SELECT tableoid::regclass, * FROM a;
--Testcase 727:
SELECT tableoid::regclass, * FROM b;
--Testcase 728:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 729:
DELETE FROM a;

--Testcase 730:
SELECT tableoid::regclass, * FROM a;
--Testcase 731:
SELECT tableoid::regclass, * FROM b;
--Testcase 732:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 733:
DROP TABLE a CASCADE;
--Testcase 734:
DROP FOREIGN TABLE b CASCADE;

-- Check SELECT FOR UPDATE/SHARE with an inherited source table
--Testcase 735:
create table foo (f1 int, f2 int);
--Testcase 736:
create foreign table foo2 (f1 int, f2 int, f3 int, __spd_url text)
  server pgspider_srv;
--Testcase 737:
create foreign table foo2__postgres_srv__0 (f3 int) inherits (foo)
  server postgres_srv options (table_name 'loct1_1');

--Testcase 738:
create table bar (f1 int, f2 int);
--Testcase 739:
create foreign table bar2 (f1 int, f2 int, f3 int, __spd_url text)
  server pgspider_srv;
--Testcase 740:
create foreign table bar2__postgres_srv__0 (f3 int) inherits (bar)
  server postgres_srv options (table_name 'loct2_1');

--Testcase 741:
alter table foo set (autovacuum_enabled = 'false');
--Testcase 742:
alter table bar set (autovacuum_enabled = 'false');

--Testcase 743:
insert into foo values(1,1);
--Testcase 744:
insert into foo values(3,3);
--Testcase 745:
insert into foo2__postgres_srv__0 values(2,2,2);
--Testcase 746:
insert into foo2__postgres_srv__0 values(4,4,4);
--Testcase 747:
insert into bar values(1,11);
--Testcase 748:
insert into bar values(2,22);
--Testcase 749:
insert into bar values(6,66);
--Testcase 750:
insert into bar2__postgres_srv__0 values(3,33,33);
--Testcase 751:
insert into bar2__postgres_srv__0 values(4,44,44);
--Testcase 752:
insert into bar2__postgres_srv__0 values(7,77,77);

--Testcase 753:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo) for update;
--Testcase 754:
select * from bar where f1 in (select f1 from foo) for update;

--Testcase 755:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo) for share;
--Testcase 756:
select * from bar where f1 in (select f1 from foo) for share;

-- Now check SELECT FOR UPDATE/SHARE with an inherited source table,
-- where the parent is itself a foreign table
--Testcase 757:
create foreign table foo2child (f1 int, f2 int, f3 int, __spd_url text)
  server pgspider_srv;
--Testcase 758:
create foreign table foo2child__postgres_srv__0 (f1 int, f2 int, f3 int)
  server postgres_srv options (table_name 'loct4');

--Testcase 759:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo2) for share;
--Testcase 760:
select * from bar where f1 in (select f1 from foo2) for share;

--Testcase 761:
drop foreign table foo2child__postgres_srv__0;
--Testcase 762:
drop foreign table foo2child;

-- And with a local child relation of the foreign table parent
--Testcase 763:
create table foo2child (f3 int) inherits (foo2__postgres_srv__0);

--Testcase 764:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo2) for share;
--Testcase 765:
select * from bar where f1 in (select f1 from foo2) for share;

--Testcase 766:
drop table foo2child;

-- Check UPDATE with inherited target and an inherited source table
--Testcase 767:
explain (verbose, costs off)
update bar set f2 = f2 + 100 where f1 in (select f1 from foo);
--Testcase 768:
update bar set f2 = f2 + 100 where f1 in (select f1 from foo);

--Testcase 769:
select tableoid::regclass, * from bar order by 1,2;

-- Check UPDATE with inherited target and an appendrel subquery
--Testcase 770:
explain (verbose, costs off)
update bar set f2 = f2 + 100
from
  ( select f1 from foo union all select f1+3 from foo ) ss
where bar.f1 = ss.f1;
--Testcase 771:
update bar set f2 = f2 + 100
from
  ( select f1 from foo union all select f1+3 from foo ) ss
where bar.f1 = ss.f1;

--Testcase 772:
select tableoid::regclass, * from bar order by 1,2;

-- Test forcing the remote server to produce sorted data for a merge join,
-- but the foreign table is an inheritance child.
truncate table foo2__postgres_srv__0;
truncate table only foo;
\set num_rows_foo 2000
--Testcase 773:
insert into foo2__postgres_srv__0 select generate_series(0, :num_rows_foo, 2), generate_series(0, :num_rows_foo, 2), generate_series(0, :num_rows_foo, 2);
--Testcase 774:
insert into foo select generate_series(1, :num_rows_foo, 2), generate_series(1, :num_rows_foo, 2);
--Testcase 775:
SET enable_hashjoin to false;
--Testcase 776:
SET enable_nestloop to false;
--Testcase 777:
alter foreign table foo2 options (use_remote_estimate 'true');
analyze foo;
-- inner join; expressions in the clauses appear in the equivalence class list
--Testcase 778:
explain (verbose, costs off)
	select foo.f1, foo2.f1 from foo join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
--Testcase 779:
select foo.f1, foo2.f1 from foo join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
-- outer join; expressions in the clauses do not appear in equivalence class
-- list but no output change as compared to the previous query
--Testcase 780:
explain (verbose, costs off)
	select foo.f1, foo2.f1 from foo left join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
--Testcase 781:
select foo.f1, foo2.f1 from foo left join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
--Testcase 782:
RESET enable_hashjoin;
--Testcase 783:
RESET enable_nestloop;

-- Test that WHERE CURRENT OF is not supported
begin;
declare c cursor for select * from bar where f1 = 7;
--Testcase 784:
fetch from c;
--Testcase 785:
update bar set f2 = null where current of c;
rollback;

--Testcase 786:
explain (verbose, costs off)
delete from foo where f1 < 5 returning *;
--Testcase 787:
delete from foo where f1 < 5 returning *;
--Testcase 788:
explain (verbose, costs off)
update bar set f2 = f2 + 100 returning *;
--Testcase 789:
update bar set f2 = f2 + 100 returning *;

-- Test that UPDATE/DELETE with inherited target works with row-level triggers
--Testcase 790:
CREATE TRIGGER trig_row_before
BEFORE UPDATE OR DELETE ON bar2
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 791:
CREATE TRIGGER trig_row_after
AFTER UPDATE OR DELETE ON bar2
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 792:
explain (verbose, costs off)
update bar set f2 = f2 + 100;
--Testcase 793:
update bar set f2 = f2 + 100;

--Testcase 794:
explain (verbose, costs off)
delete from bar where f2 < 400;
--Testcase 795:
delete from bar where f2 < 400;

-- cleanup
--Testcase 796:
drop foreign table foo2 cascade;
--Testcase 797:
drop foreign table bar2 cascade;

-- Test pushing down UPDATE/DELETE joins to the remote server
--Testcase 798:
create table parent (a int, b text);
--Testcase 799:
create foreign table remt1 (a int, b text, __spd_url text)
  server pgspider_srv;
--Testcase 800:
create foreign table remt1__postgres_srv__0 (a int, b text)
  server postgres_srv options (table_name 'loct1_2');
--Testcase 801:
create foreign table remt2 (a int, b text, __spd_url text)
  server pgspider_srv;
--Testcase 802:
create foreign table remt2__postgres_srv__0 (a int, b text)
  server postgres_srv options (table_name 'loct2_2');
--Testcase 803:
alter foreign table remt1__postgres_srv__0 inherit parent;
--alter foreign table remt1__postgres_srv__0 inherit parent__postgres_srv__0;

--Testcase 804:
insert into remt1__postgres_srv__0 values (1, 'foo');
--Testcase 805:
insert into remt1__postgres_srv__0 values (2, 'bar');
--Testcase 806:
insert into remt2__postgres_srv__0 values (1, 'foo');
--Testcase 807:
insert into remt2__postgres_srv__0 values (2, 'bar');

--analyze remt1;
--analyze remt2;

--Testcase 808:
explain (verbose, costs off)
update parent set b = parent.b || remt2.b from remt2 where parent.a = remt2.a returning *;
--Testcase 809:
update parent set b = parent.b || remt2.b from remt2 where parent.a = remt2.a returning *;
--Testcase 810:
explain (verbose, costs off)
delete from parent using remt2 where parent.a = remt2.a returning parent;
--Testcase 811:
delete from parent using remt2 where parent.a = remt2.a returning parent;

-- cleanup
--Testcase 812:
drop foreign table remt1;
--Testcase 813:
drop foreign table remt2;
--Testcase 814:
drop foreign table remt1__postgres_srv__0;
--Testcase 815:
drop foreign table remt2__postgres_srv__0;
--Testcase 816:
drop table parent;

-- ===================================================================
-- test tuple routing for foreign-table partitions
-- ===================================================================

-- Test insert tuple routing
--Testcase 817:
create foreign table itrtest (a int, b text, __spd_url text)
  server pgspider_srv;
--Testcase 818:
create foreign table itrtest__postgres_srv__0 (a int, b text)
  server postgres_srv options (table_name 'itrtest');
--Testcase 819:
SELECT dblink_exec('create foreign table remp1
  (a int check (a in (1)), b text) server postgres_srv
  options (table_name ''loct1_3'');');

--Testcase 820:
create foreign table remp1 (a int check (a in (1)), b text, __spd_url text)
  server pgspider_srv;
--Testcase 821:
create foreign table remp1__postgres_srv__0 (a int check (a in (1)), b text)
  server postgres_srv options (table_name 'remp1');
--Testcase 822:
SELECT dblink_exec('create foreign table remp2
  (b text, a int check (a in (2))) server postgres_srv
   options (table_name ''loct2_3'');');

--Testcase 823:
create foreign table remp2 (b text, a int check (a in (2)), __spd_url text)
  server pgspider_srv;
--Testcase 824:
create foreign table remp2__postgres_srv__0 (b text, a int check (a in (2)))
  server postgres_srv options (table_name 'remp2');

-- Does not support attach partition on foreign table
--Testcase 825:
SELECT dblink_exec('alter table itrtest attach partition remp1 for values in (1);');
--Testcase 826:
SELECT dblink_exec('alter table itrtest attach partition remp2 for values in (2);');

--Testcase 827:
insert into itrtest__postgres_srv__0 values (1, 'foo');
--Testcase 828:
insert into itrtest__postgres_srv__0 values (1, 'bar') returning *;
--Testcase 829:
insert into itrtest__postgres_srv__0 values (2, 'baz');
--Testcase 830:
insert into itrtest__postgres_srv__0 values (2, 'qux') returning *;
--Testcase 831:
insert into itrtest__postgres_srv__0 values (1, 'test1'), (2, 'test2') returning *;

--Testcase 832:
select tableoid::regclass, * FROM itrtest;
--Testcase 833:
select tableoid::regclass, * FROM remp1;
--Testcase 834:
select tableoid::regclass, * FROM remp2;

--Testcase 835:
delete from itrtest__postgres_srv__0;

--Testcase 836:
SELECT dblink_exec('create unique index loct1_idx on loct1_3 (a);');

-- DO NOTHING without an inference specification is supported
--Testcase 837:
insert into itrtest__postgres_srv__0 values (1, 'foo') on conflict do nothing returning *;
--Testcase 838:
insert into itrtest__postgres_srv__0 values (1, 'foo') on conflict do nothing returning *;

-- But other cases are not supported
--Testcase 839:
insert into itrtest__postgres_srv__0 values (1, 'bar') on conflict (a) do nothing;
--Testcase 840:
insert into itrtest__postgres_srv__0 values (1, 'bar') on conflict (a) do update set b = excluded.b;

--Testcase 841:
select tableoid::regclass, * FROM itrtest;

-- delete from itrtest;
--Testcase 842:
delete from itrtest__postgres_srv__0;

--Testcase 843:
SELECT dblink_exec('drop index loct1_idx;');

-- Test that remote triggers work with insert tuple routing
--Testcase 844:
create function br_insert_trigfunc() returns trigger as $$
begin
	new.b := new.b || ' triggered !';
	return new;
end
$$ language plpgsql;
--Testcase 845:
SELECT dblink_exec('create trigger loct1_br_insert_trigger before insert on loct1_3
        for each row execute procedure br_insert_trigfunc();');
--Testcase 846:
SELECT dblink_exec('create trigger loct2_br_insert_trigger before insert on loct2_3
	for each row execute procedure br_insert_trigfunc();');
-- The new values are concatenated with ' triggered !'
--Testcase 847:
insert into itrtest__postgres_srv__0 values (1, 'foo') returning *;
--Testcase 848:
insert into itrtest__postgres_srv__0 values (2, 'qux') returning *;
--Testcase 849:
insert into itrtest__postgres_srv__0 values (1, 'test1'), (2, 'test2') returning *;
--Testcase 850:
with result as (insert into itrtest__postgres_srv__0 values (1, 'test1'), (2, 'test2') returning *) select * from result;

--Testcase 851:
SELECT dblink_exec('drop trigger loct1_br_insert_trigger on loct1_3;');
--Testcase 852:
SELECT dblink_exec('drop trigger loct2_br_insert_trigger on loct2_3;');

--Testcase 853:
drop foreign table remp1;
--Testcase 854:
drop foreign table remp2;
--Testcase 855:
drop foreign table remp1__postgres_srv__0;
--Testcase 856:
drop foreign table remp2__postgres_srv__0;
--Testcase 857:
drop foreign table itrtest;
--Testcase 858:
drop foreign table itrtest__postgres_srv__0;

-- Test update tuple routing
--Testcase 859:
create foreign table utrtest (a int, b text)
  server pgspider_srv;
--Testcase 860:
create foreign table utrtest__postgres_srv__0 (a int, b text)
  server postgres_srv options (table_name 'utrtest');
--Testcase 861:
SELECT dblink_exec('create foreign table remp
  (a int check (a in (1)), b text)
  server postgres_srv options (table_name ''loct_2'');');

--Testcase 862:
create foreign table remp (a int check (a in (1)), b text, __spd_url text)
  server pgspider_srv;
--Testcase 863:
create foreign table remp__postgres_srv__0 (a int check (a in (1)), b text)
  server postgres_srv options (table_name 'remp');

--Testcase 864:
create foreign table locp (a int check (a in (2)), b text, __spd_url text)
  server pgspider_srv;
--Testcase 865:
create foreign table locp__postgres_srv__0 (a int check (a in (2)), b text)
  server postgres_srv options (table_name 'locp_2');
--Testcase 866:
SELECT dblink_exec('alter table utrtest attach partition remp for values in (1);');
--Testcase 867:
SELECT dblink_exec('alter table utrtest attach partition locp_2 for values in (2);');

--Testcase 868:
insert into utrtest__postgres_srv__0 values (1, 'foo');
--Testcase 869:
insert into utrtest__postgres_srv__0 values (2, 'qux');

--Testcase 870:
select tableoid::regclass, * FROM utrtest;
--Testcase 871:
select tableoid::regclass, * FROM remp;
--Testcase 872:
select tableoid::regclass, * FROM locp;

-- It's not allowed to move a row from a partition that is foreign to another
--Testcase 873:
update utrtest__postgres_srv__0 set a = 2 where b = 'foo' returning *;

-- But the reverse is allowed
--Testcase 874:
update utrtest__postgres_srv__0 set a = 1 where b = 'qux' returning *;

--Testcase 875:
select tableoid::regclass, * FROM utrtest;
--Testcase 876:
select tableoid::regclass, * FROM remp;
--Testcase 877:
select tableoid::regclass, * FROM locp;

-- The executor should not let unexercised FDWs shut down
--Testcase 878:
update utrtest__postgres_srv__0 set a = 1 where b = 'foo';

-- Test that remote triggers work with update tuple routing
--Testcase 879:
SELECT dblink_exec('create trigger loct_br_insert_trigger before insert on loct_2
	for each row execute procedure br_insert_trigfunc();');

--Testcase 880:
delete from utrtest__postgres_srv__0;
--Testcase 881:
insert into utrtest__postgres_srv__0 values (2, 'qux');

-- Check case where the foreign partition is a subplan target rel
-- explain (verbose, costs off)
-- update utrtest set a = 1 where a = 1 or a = 2 returning *;
-- The new values are concatenated with ' triggered !'
--Testcase 882:
update utrtest__postgres_srv__0 set a = 1 where a = 1 or a = 2 returning *;

--Testcase 883:
delete from utrtest__postgres_srv__0;
--Testcase 884:
insert into utrtest__postgres_srv__0 values (2, 'qux');

-- Check case where the foreign partition isn't a subplan target rel
-- explain (verbose, costs off)
-- update utrtest set a = 1 where a = 2 returning *;
-- The new values are concatenated with ' triggered !'
--Testcase 885:
update utrtest__postgres_srv__0 set a = 1 where a = 2 returning *;

--Testcase 886:
SELECT dblink_exec('drop trigger loct_br_insert_trigger on loct_2;');

-- We can move rows to a foreign partition that has been updated already,
-- but can't move rows to a foreign partition that hasn't been updated yet

--Testcase 887:
delete from utrtest__postgres_srv__0;
--Testcase 888:
insert into utrtest__postgres_srv__0 values (1, 'foo');
--Testcase 889:
insert into utrtest__postgres_srv__0 values (2, 'qux');

-- Test the former case:
-- with a direct modification plan
-- explain (verbose, costs off)
-- update utrtest set a = 1 returning *;
--Testcase 890:
update utrtest__postgres_srv__0 set a = 1 returning *;

--Testcase 891:
delete from utrtest__postgres_srv__0;
--Testcase 892:
insert into utrtest__postgres_srv__0 values (1, 'foo');
--Testcase 893:
insert into utrtest__postgres_srv__0 values (2, 'qux');

-- with a non-direct modification plan
-- explain (verbose, costs off)
-- update utrtest set a = 1 from (values (1), (2)) s(x) where a = s.x returning *;
--Testcase 894:
update utrtest__postgres_srv__0 set a = 1 from (values (1), (2)) s(x) where a = s.x returning *;

-- Change the definition of utrtest so that the foreign partition get updated
-- after the local partition
--Testcase 895:
delete from utrtest__postgres_srv__0;
--Testcase 896:
SELECT dblink_exec('alter table utrtest detach partition remp;');
--Testcase 897:
SELECT dblink_exec('drop foreign table remp;');
--Testcase 898:
drop foreign table remp;
--Testcase 899:
drop foreign table remp__postgres_srv__0;
--Testcase 900:
SELECT dblink_exec('alter table loct_2 drop constraint loct_2_a_check;');
--Testcase 901:
SELECT dblink_exec('alter table loct_2 add check (a in (3));');
--Testcase 902:
SELECT dblink_exec('create foreign table remp (a int check (a in (3)), b text)
  server postgres_srv options (table_name ''loct_2'');');
--Testcase 903:
SELECT dblink_exec('alter table utrtest attach partition remp for values in (3);');

--Testcase 904:
insert into utrtest__postgres_srv__0 values (2, 'qux');
--Testcase 905:
insert into utrtest__postgres_srv__0 values (3, 'xyzzy');

-- Test the latter case:
-- with a direct modification plan
-- explain (verbose, costs off)
-- update utrtest set a = 3 returning *;
--Testcase 906:
update utrtest__postgres_srv__0 set a = 3 returning *; -- ERROR

-- -- with a non-direct modification plan
-- explain (verbose, costs off)
-- update utrtest set a = 3 from (values (2), (3)) s(x) where a = s.x returning *;
--Testcase 907:
update utrtest__postgres_srv__0 set a = 3 from (values (2), (3)) s(x) where a = s.x returning *; -- ERROR

--Testcase 908:
drop foreign table utrtest;
--Testcase 909:
drop foreign table utrtest__postgres_srv__0;
--drop table loct;

-- Test copy tuple routing
---create table ctrtest (a int, b text, __spd_url text) partition by list (a);
---create table loct1 (a int check (a in (1)), b text);
--Testcase 910:
create foreign table ctrtest (a int, b text, __spd_url text)
  server pgspider_srv;
--Testcase 911:
create foreign table ctrtest__postgres_srv__0 (a int, b text)
  server postgres_srv options (table_name 'ctrtest');
--Testcase 912:
create foreign table remp1 (a int check (a in (1)), b text, __spd_url text)
  server pgspider_srv;
--Testcase 913:
create foreign table remp1__postgres_srv__0 (a int check (a in (1)), b text)
  server postgres_srv options (table_name 'loct1_4');
--Testcase 914:
create foreign table remp2 (b text, a int check (a in (2)), __spd_url text)
  server pgspider_srv;
--Testcase 915:
create foreign table remp2__postgres_srv__0 (b text, a int check (a in (2)))
  server postgres_srv options (table_name 'loct2_4');
--alter table ctrtest attach partition remp1 for values in (1);
--alter table ctrtest attach partition remp2 for values in (2);

copy ctrtest__postgres_srv__0 from stdin;
1	foo
2	qux
\.

--Testcase 916:
select tableoid::regclass, * FROM ctrtest;
--Testcase 917:
select tableoid::regclass, * FROM remp1;
--Testcase 918:
select tableoid::regclass, * FROM remp2;

-- Copying into foreign partitions directly should work as well
copy remp1__postgres_srv__0 from stdin;
1	bar
\.

--Testcase 919:
select tableoid::regclass, * FROM remp1;

--Testcase 920:
drop foreign table remp1;
--Testcase 921:
drop foreign table remp2;
--Testcase 922:
drop foreign table remp1__postgres_srv__0;
--Testcase 923:
drop foreign table remp2__postgres_srv__0;
--Testcase 924:
drop foreign table ctrtest;
--Testcase 925:
drop foreign table ctrtest__postgres_srv__0;


-- ===================================================================
-- test COPY FROM
-- ===================================================================

--Testcase 926:
create foreign table rem2 (f1 int, f2 text, __spd_url text)
  server pgspider_srv;
--Testcase 927:
create foreign table rem2__postgres_srv__0 (f1 int, f2 text)
  server postgres_srv options(table_name 'loc2_1');

-- Test basic functionality
copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 928:
select * from rem2;

--Testcase 929:
delete from rem2__postgres_srv__0;

-- Test check constraints
--Testcase 930:
alter foreign table rem2 add constraint rem2_f1positive check (f1 >= 0);

-- check constraint is enforced on the remote side, not locally
copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
copy rem2__postgres_srv__0 from stdin; -- ERROR
-1	xyzzy
\.
--Testcase 931:
select * from rem2;

--Testcase 932:
alter foreign table rem2 drop constraint rem2_f1positive;

--Testcase 933:
delete from rem2__postgres_srv__0;

-- Test local triggers
--Testcase 934:
create trigger trig_stmt_before before insert on rem2__postgres_srv__0
	for each statement execute procedure trigger_func();
--Testcase 935:
create trigger trig_stmt_after after insert on rem2__postgres_srv__0
	for each statement execute procedure trigger_func();
--Testcase 936:
create trigger trig_row_before before insert on rem2__postgres_srv__0
	for each row execute procedure trigger_data(23,'skidoo');
--Testcase 937:
create trigger trig_row_after after insert on rem2__postgres_srv__0
	for each row execute procedure trigger_data(23,'skidoo');

copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 938:
select * from rem2;

--Testcase 939:
drop trigger trig_row_before on rem2__postgres_srv__0;
--Testcase 940:
drop trigger trig_row_after on rem2__postgres_srv__0;
--Testcase 941:
drop trigger trig_stmt_before on rem2__postgres_srv__0;
--Testcase 942:
drop trigger trig_stmt_after on rem2__postgres_srv__0;

--Testcase 943:
delete from rem2__postgres_srv__0;

--Testcase 944:
create trigger trig_row_before_insert before insert on rem2__postgres_srv__0
	for each row execute procedure trig_row_before_insupdate();

-- The new values are concatenated with ' triggered !'
copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 945:
select * from rem2;

--Testcase 946:
drop trigger trig_row_before_insert on rem2__postgres_srv__0;

--Testcase 947:
delete from rem2__postgres_srv__0;

--Testcase 948:
create trigger trig_null before insert on rem2__postgres_srv__0
	for each row execute procedure trig_null();

-- Nothing happens
copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 949:
select * from rem2;

--Testcase 950:
drop trigger trig_null on rem2__postgres_srv__0;

--Testcase 951:
delete from rem2__postgres_srv__0;

-- Test remote triggers
--Testcase 952:
SELECT dblink_exec('create trigger trig_row_before_insert before insert on loc2_1
	for each row execute procedure trig_row_before_insupdate();');

-- The new values are concatenated with ' triggered !'
copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 953:
select * from rem2;

--Testcase 954:
SELECT dblink_exec('drop trigger trig_row_before_insert on loc2_1;');

--Testcase 955:
delete from rem2__postgres_srv__0;

--Testcase 956:
SELECT dblink_exec('create trigger trig_null before insert on loc2_1
	for each row execute procedure trig_null();');

-- Nothing happens
copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 957:
select * from rem2;

--Testcase 958:
SELECT dblink_exec('drop trigger trig_null on loc2_1;');

--Testcase 959:
delete from rem2__postgres_srv__0;

-- Test a combination of local and remote triggers
--Testcase 960:
create trigger rem2_trig_row_before before insert on rem2__postgres_srv__0
	for each row execute procedure trigger_data(23,'skidoo');
--Testcase 961:
create trigger rem2_trig_row_after after insert on rem2__postgres_srv__0
	for each row execute procedure trigger_data(23,'skidoo');
--Testcase 962:
SELECT dblink_exec('create trigger loc2_trig_row_before_insert before insert on loc2_1
	for each row execute procedure trig_row_before_insupdate();');

copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 963:
select * from rem2;

--Testcase 964:
drop trigger rem2_trig_row_before on rem2__postgres_srv__0;
--Testcase 965:
drop trigger rem2_trig_row_after on rem2__postgres_srv__0;
--Testcase 966:
SELECT dblink_exec('drop trigger loc2_trig_row_before_insert on loc2_1;');

--Testcase 967:
delete from rem2__postgres_srv__0;

-- test COPY FROM with foreign table created in the same transaction
begin;
--Testcase 968:
create foreign table rem3 (f1 int, f2 text, __spd_url text)
	server pgspider_srv;
--Testcase 969:
create foreign table rem3__postgres_srv__0 (f1 int, f2 text)
	server postgres_srv options(table_name 'loc3_1');
copy rem3__postgres_srv__0 from stdin;
1	foo
2	bar
\.
commit;
--Testcase 970:
select * from rem3;
--Testcase 971:
drop foreign table rem3;
--Testcase 972:
drop foreign table rem3__postgres_srv__0;

-- ===================================================================
-- test for TRUNCATE
-- ===================================================================
--Testcase 973:
CREATE FOREIGN TABLE tru_rtable0 (id int) SERVER postgres_srv;
--Testcase 974:
CREATE FOREIGN TABLE tru_ftable (id int)
       SERVER postgres_srv OPTIONS (table_name 'tru_rtable0');
--Testcase 975:
INSERT INTO tru_rtable0 (SELECT x FROM generate_series(1,10) x);

--Testcase 976:
CREATE TABLE tru_ptable (id int) PARTITION BY HASH(id);
--Testcase 977:
CREATE FOREIGN TABLE tru_ptable__p0 PARTITION OF tru_ptable
                            FOR VALUES WITH (MODULUS 2, REMAINDER 0) SERVER postgres_srv;
--Testcase 978:
CREATE FOREIGN TABLE tru_rtable1 (id int) SERVER postgres_srv;
--Testcase 979:
CREATE FOREIGN TABLE tru_ftable__p1 PARTITION OF tru_ptable
                                    FOR VALUES WITH (MODULUS 2, REMAINDER 1)
       SERVER postgres_srv OPTIONS (table_name 'tru_rtable1');
--Testcase 980:
INSERT INTO tru_ptable (SELECT x FROM generate_series(11,20) x);

--Testcase 981:
CREATE FOREIGN TABLE tru_pk_table(id int) SERVER postgres_srv;
--Testcase 982:
CREATE FOREIGN TABLE tru_fk_table(fkey int) SERVER postgres_srv;
--Testcase 983:
INSERT INTO tru_pk_table (SELECT x FROM generate_series(1,10) x);
--Testcase 984:
INSERT INTO tru_fk_table (SELECT x % 10 + 1 FROM generate_series(5,25) x);
--Testcase 985:
CREATE FOREIGN TABLE tru_pk_ftable (id int)
       SERVER postgres_srv OPTIONS (table_name 'tru_pk_table');

--Testcase 986:
CREATE FOREIGN TABLE tru_rtable_parent (id int) SERVER postgres_srv;
--Testcase 987:
CREATE FOREIGN TABLE tru_rtable_child (id int) SERVER postgres_srv;
--Testcase 988:
CREATE FOREIGN TABLE tru_ftable_parent (id int)
       SERVER postgres_srv OPTIONS (table_name 'tru_rtable_parent');
--Testcase 989:
CREATE FOREIGN TABLE tru_ftable_child () INHERITS (tru_ftable_parent)
       SERVER postgres_srv OPTIONS (table_name 'tru_rtable_child');
--Testcase 990:
INSERT INTO tru_rtable_parent (SELECT x FROM generate_series(1,8) x);
--Testcase 991:
INSERT INTO tru_rtable_child  (SELECT x FROM generate_series(10, 18) x);

-- normal truncate
--Testcase 992:
SELECT sum(id) FROM tru_ftable;        -- 55
TRUNCATE tru_ftable;
--Testcase 993:
SELECT count(*) FROM tru_rtable0;		-- 0
--Testcase 994:
SELECT count(*) FROM tru_ftable;		-- 0

-- 'truncatable' option
--Testcase 995:
ALTER SERVER postgres_srv OPTIONS (ADD truncatable 'false');
TRUNCATE tru_ftable;			-- error
--Testcase 996:
ALTER FOREIGN TABLE tru_ftable OPTIONS (ADD truncatable 'true');
TRUNCATE tru_ftable;			-- accepted
--Testcase 997:
ALTER FOREIGN TABLE tru_ftable OPTIONS (SET truncatable 'false');
TRUNCATE tru_ftable;			-- error
--Testcase 998:
ALTER SERVER postgres_srv OPTIONS (DROP truncatable);
--Testcase 999:
ALTER FOREIGN TABLE tru_ftable OPTIONS (SET truncatable 'false');
TRUNCATE tru_ftable;			-- error
--Testcase 1000:
ALTER FOREIGN TABLE tru_ftable OPTIONS (SET truncatable 'true');
TRUNCATE tru_ftable;			-- accepted

-- partitioned table with both local and foreign tables as partitions
--Testcase 1001:
SELECT sum(id) FROM tru_ptable;        -- 155
TRUNCATE tru_ptable;
--Testcase 1002:
SELECT count(*) FROM tru_ptable;		-- 0
--Testcase 1003:
SELECT count(*) FROM tru_ptable__p0;	-- 0
--Testcase 1004:
SELECT count(*) FROM tru_ftable__p1;	-- 0
--Testcase 1005:
SELECT count(*) FROM tru_rtable1;		-- 0

-- 'CASCADE' option
--Testcase 1006:
SELECT sum(id) FROM tru_pk_ftable;      -- 55
TRUNCATE tru_pk_ftable;	-- failed by FK reference
TRUNCATE tru_pk_ftable CASCADE;
--Testcase 1007:
SELECT count(*) FROM tru_pk_ftable;    -- 0
--Testcase 1008:
SELECT count(*) FROM tru_fk_table;		-- also truncated,0

-- truncate two tables at a command
--Testcase 1009:
INSERT INTO tru_ftable (SELECT x FROM generate_series(1,8) x);
--Testcase 1010:
INSERT INTO tru_pk_ftable (SELECT x FROM generate_series(3,10) x);
--Testcase 1011:
SELECT count(*) from tru_ftable; -- 8
--Testcase 1012:
SELECT count(*) from tru_pk_ftable; -- 8
TRUNCATE tru_ftable, tru_pk_ftable CASCADE;
--Testcase 1013:
SELECT count(*) from tru_ftable; -- 0
--Testcase 1014:
SELECT count(*) from tru_pk_ftable; -- 0

-- truncate with ONLY clause
-- Since ONLY is specified, the table tru_ftable_child that inherits
-- tru_ftable_parent locally is not truncated.
TRUNCATE ONLY tru_ftable_parent;
--Testcase 1015:
SELECT sum(id) FROM tru_ftable_parent;  -- 126
TRUNCATE tru_ftable_parent;
--Testcase 1016:
SELECT count(*) FROM tru_ftable_parent; -- 0

-- in case when remote table has inherited children
--Testcase 1017:
CREATE FOREIGN TABLE tru_rtable0_child () INHERITS (tru_rtable0) SERVER postgres_srv;
--Testcase 1018:
INSERT INTO tru_rtable0 (SELECT x FROM generate_series(5,9) x);
--Testcase 1019:
INSERT INTO tru_rtable0_child (SELECT x FROM generate_series(10,14) x);
--Testcase 1020:
SELECT sum(id) FROM tru_ftable;   -- 95

-- Both parent and child tables in the foreign server are truncated
-- even though ONLY is specified because ONLY has no effect
-- when truncating a foreign table.
TRUNCATE ONLY tru_ftable;
--Testcase 1021:
SELECT count(*) FROM tru_ftable;   -- 0

--Testcase 1022:
INSERT INTO tru_rtable0 (SELECT x FROM generate_series(21,25) x);
--Testcase 1023:
INSERT INTO tru_rtable0_child (SELECT x FROM generate_series(26,30) x);
--Testcase 1024:
SELECT sum(id) FROM tru_ftable;		-- 255
TRUNCATE tru_ftable;			-- truncate both of parent and child
--Testcase 1025:
SELECT count(*) FROM tru_ftable;    -- 0

-- cleanup
--Testcase 1026:
DROP FOREIGN TABLE tru_ftable_parent, tru_ftable_child, tru_pk_ftable,tru_ftable__p1,tru_ftable;
--Testcase 1027:
DROP FOREIGN TABLE tru_rtable0, tru_rtable1, tru_ptable__p0, tru_pk_table, tru_fk_table,
tru_rtable_parent,tru_rtable_child, tru_rtable0_child;
--Testcase 1028:
DROP TABLE tru_ptable;
-- ===================================================================
-- test IMPORT FOREIGN SCHEMA
-- ===================================================================

--Testcase 1029:
CREATE TYPE typ1 AS (m1 int, m2 varchar);
--Testcase 1030:
CREATE SCHEMA import_dest1;
IMPORT FOREIGN SCHEMA import_source FROM SERVER postgres_srv INTO import_dest1;
--Testcase 1031:
\det+ import_dest1.*
--Testcase 1032:
\d import_dest1.*

-- Options
--Testcase 1033:
CREATE SCHEMA import_dest2;
IMPORT FOREIGN SCHEMA import_source FROM SERVER postgres_srv INTO import_dest2
  OPTIONS (import_default 'true');
--Testcase 1034:
\det+ import_dest2.*
--Testcase 1035:
\d import_dest2.*
--Testcase 1036:
CREATE SCHEMA import_dest3;
IMPORT FOREIGN SCHEMA import_source FROM SERVER postgres_srv INTO import_dest3
  OPTIONS (import_collate 'false', import_generated 'false', import_not_null 'false');
--Testcase 1037:
\det+ import_dest3.*
--Testcase 1038:
\d import_dest3.*

-- Check LIMIT TO and EXCEPT
--Testcase 1039:
CREATE SCHEMA import_dest4;
IMPORT FOREIGN SCHEMA import_source LIMIT TO (t1, nonesuch, t4_part)
  FROM SERVER postgres_srv INTO import_dest4;
--Testcase 1040:
\det+ import_dest4.*
IMPORT FOREIGN SCHEMA import_source EXCEPT (t1, "x 4", nonesuch, t4_part)
  FROM SERVER postgres_srv INTO import_dest4;
--Testcase 1041:
\det+ import_dest4.*

-- Assorted error cases
IMPORT FOREIGN SCHEMA import_source FROM SERVER postgres_srv INTO import_dest4;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER postgres_srv INTO import_dest4;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER postgres_srv INTO notthere;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER nowhere INTO notthere;

-- Check case of a type present only on the remote server.
-- We can fake this by dropping the type locally in our transaction.
--Testcase 1042:
CREATE TYPE "Colors" AS ENUM ('red', 'green', 'blue');
--Testcase 1043:
SELECT dblink_exec('CREATE TABLE import_source.t5 (c1 int, c2 text collate "C", "Col" "Colors");');

--Testcase 1044:
CREATE SCHEMA import_dest5;
BEGIN;
--Testcase 1045:
DROP TYPE "Colors" CASCADE;
IMPORT FOREIGN SCHEMA import_source LIMIT TO (t5)
  FROM SERVER postgres_srv INTO import_dest5;  -- ERROR

ROLLBACK;

BEGIN;


--Testcase 1046:
CREATE SERVER fetch101 FOREIGN DATA WRAPPER postgres_fdw OPTIONS( fetch_size '101' );

--Testcase 1047:
SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'fetch101'
AND srvoptions @> array['fetch_size=101'];

--Testcase 1048:
ALTER SERVER fetch101 OPTIONS( SET fetch_size '202' );

--Testcase 1049:
SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'fetch101'
AND srvoptions @> array['fetch_size=101'];

--Testcase 1050:
SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'fetch101'
AND srvoptions @> array['fetch_size=202'];

--Testcase 1051:
CREATE FOREIGN TABLE table30000 ( x int ) SERVER fetch101 OPTIONS ( fetch_size '30000' );

--Testcase 1052:
SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30000'::regclass
AND ftoptions @> array['fetch_size=30000'];

--Testcase 1053:
ALTER FOREIGN TABLE table30000 OPTIONS ( SET fetch_size '60000');

--Testcase 1054:
SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30000'::regclass
AND ftoptions @> array['fetch_size=30000'];

--Testcase 1055:
SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30000'::regclass
AND ftoptions @> array['fetch_size=60000'];

ROLLBACK;

-- ===================================================================
-- test partitionwise joins
-- ===================================================================
--Testcase 1056:
SET enable_partitionwise_join=on;

--Testcase 1057:
CREATE TABLE fprt1 (a int, b int, c varchar) PARTITION BY RANGE(a);
--Testcase 1058:
CREATE FOREIGN TABLE ftprt1_p1(a int, b int, c varchar, __spd_url text)
	SERVER pgspider_srv;
--Testcase 1059:
CREATE FOREIGN TABLE ftprt1_p1__postgres_srv__0 PARTITION OF fprt1 FOR VALUES FROM (0) TO (250)
	SERVER postgres_srv OPTIONS (table_name 'fprt1_p1', use_remote_estimate 'true');
--Testcase 1060:
CREATE FOREIGN TABLE ftprt1_p2(a int, b int, c varchar, __spd_url text)
	SERVER pgspider_srv;
--Testcase 1061:
CREATE FOREIGN TABLE ftprt1_p2__postgres_srv__0 PARTITION OF fprt1 FOR VALUES FROM (250) TO (500)
	SERVER postgres_srv OPTIONS (TABLE_NAME 'fprt1_p2');
ANALYZE fprt1;
--ANALYZE ftprt1_p1;
--ANALYZE ftprt1_p2;

--Testcase 1062:
CREATE TABLE fprt2 (a int, b int, c varchar) PARTITION BY RANGE(b);
--Testcase 1063:
CREATE FOREIGN TABLE ftprt2_p1 (b int, c varchar, a int, __spd_url text)
	SERVER pgspider_srv;
--Testcase 1064:
CREATE FOREIGN TABLE ftprt2_p1__postgres_srv__0 (b int, c varchar, a int)
	SERVER postgres_srv OPTIONS (table_name 'fprt2_p1', use_remote_estimate 'true');
--Testcase 1065:
ALTER TABLE fprt2 ATTACH PARTITION ftprt2_p1__postgres_srv__0 FOR VALUES FROM (0) TO (250);
--Testcase 1066:
CREATE FOREIGN TABLE ftprt2_p2 (b int, c varchar, a int, __spd_url text)
	SERVER pgspider_srv;
--Testcase 1067:
CREATE FOREIGN TABLE ftprt2_p2__postgres_srv__0 PARTITION OF fprt2 FOR VALUES FROM (250) TO (500)
	SERVER postgres_srv OPTIONS (table_name 'fprt2_p2', use_remote_estimate 'true');

ANALYZE fprt2;
--ANALYZE ftprt2_p1;
--ANALYZE ftprt2_p2;

-- inner join three tables
--Testcase 1068:
EXPLAIN (COSTS OFF)
SELECT t1.a,t2.b,t3.c FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) INNER JOIN fprt1 t3 ON (t2.b = t3.a) WHERE t1.a % 25 =0 ORDER BY 1,2,3;
--Testcase 1069:
SELECT t1.a,t2.b,t3.c FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) INNER JOIN fprt1 t3 ON (t2.b = t3.a) WHERE t1.a % 25 =0 ORDER BY 1,2,3;

-- left outer join + nullable clause
--Testcase 1070:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.a,t2.b,t2.c FROM fprt1 t1 LEFT JOIN (SELECT * FROM fprt2 WHERE a < 10) t2 ON (t1.a = t2.b and t1.b = t2.a) WHERE t1.a < 10 ORDER BY 1,2,3;
--Testcase 1071:
SELECT t1.a,t2.b,t2.c FROM fprt1 t1 LEFT JOIN (SELECT * FROM fprt2 WHERE a < 10) t2 ON (t1.a = t2.b and t1.b = t2.a) WHERE t1.a < 10 ORDER BY 1,2,3;

-- with whole-row reference; partitionwise join does not apply
--Testcase 1072:
EXPLAIN (COSTS OFF)
SELECT t1.wr, t2.wr FROM (SELECT t1 wr, a FROM fprt1 t1 WHERE t1.a % 25 = 0) t1 FULL JOIN (SELECT t2 wr, b FROM fprt2 t2 WHERE t2.b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY 1,2;
--Testcase 1073:
SELECT t1.wr, t2.wr FROM (SELECT t1 wr, a FROM fprt1 t1 WHERE t1.a % 25 = 0) t1 FULL JOIN (SELECT t2 wr, b FROM fprt2 t2 WHERE t2.b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY 1,2;

-- join with lateral reference
--Testcase 1074:
EXPLAIN (COSTS OFF)
SELECT t1.a,t1.b FROM fprt1 t1, LATERAL (SELECT t2.a, t2.b FROM fprt2 t2 WHERE t1.a = t2.b AND t1.b = t2.a) q WHERE t1.a%25 = 0 ORDER BY 1,2;
--Testcase 1075:
SELECT t1.a,t1.b FROM fprt1 t1, LATERAL (SELECT t2.a, t2.b FROM fprt2 t2 WHERE t1.a = t2.b AND t1.b = t2.a) q WHERE t1.a%25 = 0 ORDER BY 1,2;

-- with PHVs, partitionwise join selected but no join pushdown
--Testcase 1076:
EXPLAIN (COSTS OFF)
SELECT t1.a, t1.phv, t2.b, t2.phv FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE a % 25 = 0) t1 FULL JOIN (SELECT 't2_phv' phv, * FROM fprt2 WHERE b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY t1.a, t2.b;
--Testcase 1077:
SELECT t1.a, t1.phv, t2.b, t2.phv FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE a % 25 = 0) t1 FULL JOIN (SELECT 't2_phv' phv, * FROM fprt2 WHERE b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY t1.a, t2.b;

-- test FOR UPDATE; partitionwise join does not apply
--Testcase 1078:
EXPLAIN (COSTS OFF)
SELECT t1.a, t2.b FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) WHERE t1.a % 25 = 0 ORDER BY 1,2 FOR UPDATE OF t1;
--Testcase 1079:
SELECT t1.a, t2.b FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) WHERE t1.a % 25 = 0 ORDER BY 1,2 FOR UPDATE OF t1;

--Testcase 1080:
RESET enable_partitionwise_join;


-- ===================================================================
-- test partitionwise aggregates
-- ===================================================================

--Testcase 1081:
CREATE TABLE pagg_tab (a int, b int, c text) PARTITION BY RANGE(a);

-- Create foreign table on pgspider node
--Testcase 1082:
CREATE FOREIGN TABLE fpagg_tab_p1 (a int, b int, c text, __spd_url text)
  SERVER pgspider_srv;
--Testcase 1083:
CREATE FOREIGN TABLE fpagg_tab_p2 (a int, b int, c text, __spd_url text)
  SERVER pgspider_srv;
--Testcase 1084:
CREATE FOREIGN TABLE fpagg_tab_p3 (a int, b int, c text, __spd_url text)
  SERVER pgspider_srv;

-- Create foreign partitions
--Testcase 1085:
CREATE FOREIGN TABLE fpagg_tab_p1__postgres_srv__0
  PARTITION OF pagg_tab FOR VALUES FROM (0) TO (10)
  SERVER postgres_srv OPTIONS (table_name 'pagg_tab_p1');
--Testcase 1086:
CREATE FOREIGN TABLE fpagg_tab_p2__postgres_srv__0
  PARTITION OF pagg_tab FOR VALUES FROM (10) TO (20)
  SERVER postgres_srv OPTIONS (table_name 'pagg_tab_p2');;
--Testcase 1087:
CREATE FOREIGN TABLE fpagg_tab_p3__postgres_srv__0
  PARTITION OF pagg_tab FOR VALUES FROM (20) TO (30)
  SERVER postgres_srv OPTIONS (table_name 'pagg_tab_p3');;

ANALYZE pagg_tab;
--ANALYZE fpagg_tab_p1;
--ANALYZE fpagg_tab_p2;
--ANALYZE fpagg_tab_p3;

-- When GROUP BY clause matches with PARTITION KEY.
-- Plan with partitionwise aggregates is disabled
--Testcase 1088:
SET enable_partitionwise_aggregate TO false;
--Testcase 1089:
EXPLAIN (COSTS OFF)
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- Plan with partitionwise aggregates is enabled
--Testcase 1090:
SET enable_partitionwise_aggregate TO true;
--Testcase 1091:
EXPLAIN (COSTS OFF)
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;
--Testcase 1092:
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- Check with whole-row reference
-- Should have all the columns in the target list for the given relation
--Testcase 1093:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT a, count(t1) FROM pagg_tab t1 GROUP BY a HAVING avg(b) < 22 ORDER BY 1;
--Testcase 1094:
SELECT a, count(t1) FROM pagg_tab t1 GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- When GROUP BY clause does not match with PARTITION KEY.
--Testcase 1095:
EXPLAIN (COSTS OFF)
SELECT b, avg(a), max(a), count(*) FROM pagg_tab GROUP BY b HAVING sum(a) < 700 ORDER BY 1;

-- ===================================================================
-- skip this test, pgspider_core_fdw does not support ssl
-- access rights and superuser
-- ===================================================================
/*
-- Non-superuser cannot create a FDW without a password in the connstr
CREATE ROLE regress_nosuper NOSUPERUSER;

GRANT USAGE ON FOREIGN DATA WRAPPER postgres_fdw TO regress_nosuper;

SET ROLE regress_nosuper;

SHOW is_superuser;

-- This will be OK, we can create the FDW
DO $d$
    BEGIN
        EXECUTE $$CREATE SERVER loopback_nopw FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (dbname '$$||current_database()||$$',
                     port '$$||current_setting('port')||$$'
            )$$;
    END;
$d$;

-- But creation of user mappings for non-superusers should fail
CREATE USER MAPPING FOR public SERVER loopback_nopw;
CREATE USER MAPPING FOR CURRENT_USER SERVER loopback_nopw;

CREATE FOREIGN TABLE pg_temp.ft1_nopw (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 user_enum
) SERVER loopback_nopw OPTIONS (schema_name 'public', table_name 'ft1');

SELECT 1 FROM ft1_nopw LIMIT 1;

-- If we add a password to the connstr it'll fail, because we don't allow passwords
-- in connstrs only in user mappings.

DO $d$
    BEGIN
        EXECUTE $$ALTER SERVER loopback_nopw OPTIONS (ADD password 'dummypw')$$;
    END;
$d$;

-- If we add a password for our user mapping instead, we should get a different
-- error because the password wasn't actually *used* when we run with trust auth.
--
-- This won't work with installcheck, but neither will most of the FDW checks.

ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD password 'dummypw');

SELECT 1 FROM ft1_nopw LIMIT 1;

-- Unpriv user cannot make the mapping passwordless
ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD password_required 'false');


SELECT 1 FROM ft1_nopw LIMIT 1;

RESET ROLE;

-- But the superuser can
ALTER USER MAPPING FOR regress_nosuper SERVER loopback_nopw OPTIONS (ADD password_required 'false');

SET ROLE regress_nosuper;

-- Should finally work now
SELECT 1 FROM ft1_nopw LIMIT 1;

-- unpriv user also cannot set sslcert / sslkey on the user mapping
-- first set password_required so we see the right error messages
ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (SET password_required 'true');
ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD sslcert 'foo.crt');
ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD sslkey 'foo.key');

-- We're done with the role named after a specific user and need to check the
-- changes to the public mapping.
DROP USER MAPPING FOR CURRENT_USER SERVER loopback_nopw;

-- This will fail again as it'll resolve the user mapping for public, which
-- lacks password_required=false
SELECT 1 FROM ft1_nopw LIMIT 1;

RESET ROLE;

-- The user mapping for public is passwordless and lacks the password_required=false
-- mapping option, but will work because the current user is a superuser.
SELECT 1 FROM ft1_nopw LIMIT 1;

-- cleanup
DROP USER MAPPING FOR public SERVER loopback_nopw;
DROP OWNED BY regress_nosuper;
DROP ROLE regress_nosuper;

-- Clean-up
RESET enable_partitionwise_aggregate;

-- Two-phase transactions are not supported.
BEGIN;
SELECT count(*) FROM ft1;
-- error here
PREPARE TRANSACTION 'fdw_tpc';
ROLLBACK;
*/

-- ===================================================================
-- skip this test, pgspider_core_fdw does not support connection
-- reestablish new connection
-- ===================================================================
/*
-- Change application_name of remote connection to special one
-- so that we can easily terminate the connection later.
ALTER SERVER loopback OPTIONS (application_name 'fdw_retry_check');

-- If debug_discard_caches is active, it results in
-- dropping remote connections after every transaction, making it
-- impossible to test termination meaningfully.  So turn that off
-- for this test.
SET debug_discard_caches = 0;

-- Make sure we have a remote connection.
SELECT 1 FROM ft1 LIMIT 1;

-- Terminate the remote connection and wait for the termination to complete.
SELECT pg_terminate_backend(pid, 180000) FROM pg_stat_activity
	WHERE application_name = 'fdw_retry_check';

-- This query should detect the broken connection when starting new remote
-- transaction, reestablish new connection, and then succeed.
BEGIN;
SELECT 1 FROM ft1 LIMIT 1;

-- If we detect the broken connection when starting a new remote
-- subtransaction, we should fail instead of establishing a new connection.
-- Terminate the remote connection and wait for the termination to complete.
SELECT pg_terminate_backend(pid, 180000) FROM pg_stat_activity
	WHERE application_name = 'fdw_retry_check';
SAVEPOINT s;
-- The text of the error might vary across platforms, so only show SQLSTATE.
\set VERBOSITY sqlstate
SELECT 1 FROM ft1 LIMIT 1;    -- should fail
\set VERBOSITY default
COMMIT;

RESET debug_discard_caches;

-- =============================================================================
-- test connection invalidation cases and postgres_fdw_get_connections function
-- =============================================================================
-- Let's ensure to close all the existing cached connections.
SELECT 1 FROM postgres_fdw_disconnect_all();
-- No cached connections, so no records should be output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- This test case is for closing the connection in pgfdw_xact_callback
BEGIN;
-- Connection xact depth becomes 1 i.e. the connection is in midst of the xact.
SELECT 1 FROM ft1 LIMIT 1;
SELECT 1 FROM ft7 LIMIT 1;
-- List all the existing cached connections. loopback and loopback3 should be
-- output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- Connections are not closed at the end of the alter and drop statements.
-- That's because the connections are in midst of this xact,
-- they are just marked as invalid in pgfdw_inval_callback.
ALTER SERVER loopback OPTIONS (ADD use_remote_estimate 'off');
DROP SERVER loopback3 CASCADE;
-- List all the existing cached connections. loopback and loopback3
-- should be output as invalid connections. Also the server name for
-- loopback3 should be NULL because the server was dropped.
SELECT * FROM postgres_fdw_get_connections() ORDER BY 1;
-- The invalid connections get closed in pgfdw_xact_callback during commit.
COMMIT;
-- All cached connections were closed while committing above xact, so no
-- records should be output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;

-- =======================================================================
-- test postgres_fdw_disconnect and postgres_fdw_disconnect_all functions
-- =======================================================================
BEGIN;
-- Ensure to cache loopback connection.
SELECT 1 FROM ft1 LIMIT 1;
-- Ensure to cache loopback2 connection.
SELECT 1 FROM ft6 LIMIT 1;
-- List all the existing cached connections. loopback and loopback2 should be
-- output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- Issue a warning and return false as loopback connection is still in use and
-- can not be closed.
SELECT postgres_fdw_disconnect('loopback');
-- List all the existing cached connections. loopback and loopback2 should be
-- output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
-- Return false as connections are still in use, warnings are issued.
-- But disable warnings temporarily because the order of them is not stable.
SET client_min_messages = 'ERROR';
SELECT postgres_fdw_disconnect_all();
RESET client_min_messages;
COMMIT;
-- Ensure that loopback2 connection is closed.
SELECT 1 FROM postgres_fdw_disconnect('loopback2');
SELECT server_name FROM postgres_fdw_get_connections() WHERE server_name = 'loopback2';
-- Return false as loopback2 connection is closed already.
SELECT postgres_fdw_disconnect('loopback2');
-- Return an error as there is no foreign server with given name.
SELECT postgres_fdw_disconnect('unknownserver');
-- Let's ensure to close all the existing cached connections.
SELECT 1 FROM postgres_fdw_disconnect_all();
-- No cached connections, so no records should be output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;

-- =============================================================================
-- test case for having multiple cached connections for a foreign server
-- =============================================================================
CREATE ROLE regress_multi_conn_user1 SUPERUSER;
CREATE ROLE regress_multi_conn_user2 SUPERUSER;
CREATE USER MAPPING FOR regress_multi_conn_user1 SERVER loopback;
CREATE USER MAPPING FOR regress_multi_conn_user2 SERVER loopback;

BEGIN;
-- Will cache loopback connection with user mapping for regress_multi_conn_user1
SET ROLE regress_multi_conn_user1;
SELECT 1 FROM ft1 LIMIT 1;
RESET ROLE;

-- Will cache loopback connection with user mapping for regress_multi_conn_user2
SET ROLE regress_multi_conn_user2;
SELECT 1 FROM ft1 LIMIT 1;
RESET ROLE;

-- Should output two connections for loopback server
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
COMMIT;
-- Let's ensure to close all the existing cached connections.
SELECT 1 FROM postgres_fdw_disconnect_all();
-- No cached connections, so no records should be output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;

-- Clean up
DROP USER MAPPING FOR regress_multi_conn_user1 SERVER loopback;
DROP USER MAPPING FOR regress_multi_conn_user2 SERVER loopback;
DROP ROLE regress_multi_conn_user1;
DROP ROLE regress_multi_conn_user2;

-- ===================================================================
-- Test foreign server level option keep_connections
-- ===================================================================
-- By default, the connections associated with foreign server are cached i.e.
-- keep_connections option is on. Set it to off.
ALTER SERVER loopback OPTIONS (keep_connections 'off');
-- connection to loopback server is closed at the end of xact
-- as keep_connections was set to off.
SELECT 1 FROM ft1 LIMIT 1;
-- No cached connections, so no records should be output.
SELECT server_name FROM postgres_fdw_get_connections() ORDER BY 1;
ALTER SERVER loopback OPTIONS (SET keep_connections 'on');
*/

-- ===================================================================
-- batch insert
-- ===================================================================

BEGIN;

--Testcase 1096:
CREATE SERVER batch10 FOREIGN DATA WRAPPER postgres_fdw OPTIONS( batch_size '10' );

--Testcase 1097:
SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'batch10'
AND srvoptions @> array['batch_size=10'];

--Testcase 1098:
ALTER SERVER batch10 OPTIONS( SET batch_size '20' );

--Testcase 1099:
SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'batch10'
AND srvoptions @> array['batch_size=10'];

--Testcase 1100:
SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'batch10'
AND srvoptions @> array['batch_size=20'];

--Testcase 1101:
CREATE FOREIGN TABLE table30 ( x int ) SERVER batch10 OPTIONS ( batch_size '30' );

--Testcase 1102:
SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30'::regclass
AND ftoptions @> array['batch_size=30'];

--Testcase 1103:
ALTER FOREIGN TABLE table30 OPTIONS ( SET batch_size '40');

--Testcase 1104:
SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30'::regclass
AND ftoptions @> array['batch_size=30'];

--Testcase 1105:
SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30'::regclass
AND ftoptions @> array['batch_size=40'];

ROLLBACK;

--Testcase 1106:
CREATE FOREIGN TABLE batch_table ( x int ) SERVER postgres_srv;

--Testcase 1107:
CREATE FOREIGN TABLE ftable ( x int ) SERVER postgres_srv OPTIONS ( table_name 'batch_table', batch_size '10' );
--Testcase 1108:
EXPLAIN (VERBOSE, COSTS OFF) INSERT INTO ftable SELECT * FROM generate_series(1, 10) i;
--Testcase 1109:
INSERT INTO ftable SELECT * FROM generate_series(1, 10) i;
--Testcase 1110:
INSERT INTO ftable SELECT * FROM generate_series(11, 31) i;
--Testcase 1111:
INSERT INTO ftable VALUES (32);
--Testcase 1112:
INSERT INTO ftable VALUES (33), (34);
--Testcase 1113:
SELECT COUNT(*) FROM ftable;
TRUNCATE batch_table;
--Testcase 1114:
DROP FOREIGN TABLE ftable;

-- try if large batches exceed max number of bind parameters
--Testcase 1115:
CREATE FOREIGN TABLE ftable ( x int ) SERVER postgres_srv OPTIONS ( table_name 'batch_table', batch_size '100000' );
--Testcase 1116:
INSERT INTO ftable SELECT * FROM generate_series(1, 70000) i;
--Testcase 1117:
SELECT COUNT(*) FROM ftable;
TRUNCATE batch_table;
--Testcase 1118:
DROP FOREIGN TABLE ftable;

-- Disable batch insert
--Testcase 1119:
CREATE FOREIGN TABLE ftable ( x int ) SERVER postgres_srv OPTIONS ( table_name 'batch_table', batch_size '1' );
--Testcase 1120:
EXPLAIN (VERBOSE, COSTS OFF) INSERT INTO ftable VALUES (1), (2);
--Testcase 1121:
INSERT INTO ftable VALUES (1), (2);
--Testcase 1122:
SELECT COUNT(*) FROM ftable;

-- Disable batch inserting into foreign tables with BEFORE ROW INSERT triggers
-- even if the batch_size option is enabled.
ALTER FOREIGN TABLE ftable OPTIONS ( SET batch_size '10' );
--Testcase 1219:
CREATE TRIGGER trig_row_before BEFORE INSERT ON ftable
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 1220:
EXPLAIN (VERBOSE, COSTS OFF) INSERT INTO ftable VALUES (3), (4);
--Testcase 1221:
INSERT INTO ftable VALUES (3), (4);
--Testcase 1222:
SELECT COUNT(*) FROM ftable;

-- Clean up
--Testcase 1223:
DROP TRIGGER trig_row_before ON ftable;
--Testcase 1123:
DROP FOREIGN TABLE ftable;
--Testcase 1124:
DROP FOREIGN TABLE batch_table;

-- Use partitioning
--Testcase 1125:
CREATE TABLE batch_table ( x int ) PARTITION BY HASH (x);

--Testcase 1126:
CREATE FOREIGN TABLE batch_table_p0f
	PARTITION OF batch_table
	FOR VALUES WITH (MODULUS 3, REMAINDER 0)
	SERVER postgres_srv
	OPTIONS (table_name 'batch_table_p0', batch_size '10');

--Testcase 1127:
CREATE FOREIGN TABLE batch_table_p1f
	PARTITION OF batch_table
	FOR VALUES WITH (MODULUS 3, REMAINDER 1)
	SERVER postgres_srv
	OPTIONS (table_name 'batch_table_p1', batch_size '1');

--Testcase 1128:
CREATE TABLE batch_table_p2
	PARTITION OF batch_table
	FOR VALUES WITH (MODULUS 3, REMAINDER 2);

--Testcase 1129:
INSERT INTO batch_table SELECT * FROM generate_series(1, 66) i;
--Testcase 1130:
SELECT COUNT(*) FROM batch_table;

-- Check that enabling batched inserts doesn't interfere with cross-partition
-- updates
--Testcase 1131:
CREATE TABLE batch_cp_upd_test (a int) PARTITION BY LIST (a);

--Testcase 1132:
CREATE FOREIGN TABLE batch_cp_upd_test1_f
	PARTITION OF batch_cp_upd_test
	FOR VALUES IN (1)
	SERVER postgres_srv
	OPTIONS (table_name 'batch_cp_upd_test1', batch_size '10');
--Testcase 1133:
CREATE TABLE batch_cp_up_test1 PARTITION OF batch_cp_upd_test
	FOR VALUES IN (2);
--Testcase 1134:
INSERT INTO batch_cp_upd_test VALUES (1), (2);

-- The following moves a row from the local partition to the foreign one
--Testcase 1135:
UPDATE batch_cp_upd_test t SET a = 1 FROM (VALUES (1), (2)) s(a) WHERE t.a = s.a;
--Testcase 1136:
SELECT tableoid::regclass, * FROM batch_cp_upd_test;

-- Clean up
--Testcase 1137:
DROP TABLE batch_table, batch_cp_upd_test CASCADE;

-- Use partitioning
--Testcase 1138:
ALTER SERVER postgres_srv OPTIONS (ADD batch_size '10');

--Testcase 1139:
CREATE TABLE batch_table ( x int, field1 text, field2 text) PARTITION BY HASH (x);

--Testcase 1140:
CREATE FOREIGN TABLE batch_table_p2f
	PARTITION OF batch_table
	FOR VALUES WITH (MODULUS 2, REMAINDER 0)
	SERVER postgres_srv
	OPTIONS (table_name 'batch_table_p2');

--Testcase 1141:
CREATE FOREIGN TABLE batch_table_p3f
	PARTITION OF batch_table
	FOR VALUES WITH (MODULUS 2, REMAINDER 1)
	SERVER postgres_srv
	OPTIONS (table_name 'batch_table_p3');

--Testcase 1142:
INSERT INTO batch_table SELECT i, 'test'||i, 'test'|| i FROM generate_series(1, 50) i;
--Testcase 1143:
SELECT COUNT(*) FROM batch_table;
--Testcase 1144:
SELECT * FROM batch_table ORDER BY x;

--Testcase 1145:
ALTER SERVER postgres_srv OPTIONS (DROP batch_size);

-- ===================================================================
-- skip this test, pgspider_core_fdw does not support asynchronous execution
-- test asynchronous execution
-- ===================================================================
/*
ALTER SERVER loopback OPTIONS (DROP extensions);
ALTER SERVER loopback OPTIONS (ADD async_capable 'true');
ALTER SERVER loopback2 OPTIONS (ADD async_capable 'true');

CREATE TABLE async_pt (a int, b int, c text) PARTITION BY RANGE (a);
CREATE TABLE base_tbl1 (a int, b int, c text);
CREATE TABLE base_tbl2 (a int, b int, c text);
CREATE FOREIGN TABLE async_p1 PARTITION OF async_pt FOR VALUES FROM (1000) TO (2000)
  SERVER loopback OPTIONS (table_name 'base_tbl1');
CREATE FOREIGN TABLE async_p2 PARTITION OF async_pt FOR VALUES FROM (2000) TO (3000)
  SERVER loopback2 OPTIONS (table_name 'base_tbl2');
INSERT INTO async_p1 SELECT 1000 + i, i, to_char(i, 'FM0000') FROM generate_series(0, 999, 5) i;
INSERT INTO async_p2 SELECT 2000 + i, i, to_char(i, 'FM0000') FROM generate_series(0, 999, 5) i;
ANALYZE async_pt;

-- simple queries
CREATE TABLE result_tbl (a int, b int, c text);

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b % 100 = 0;
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b % 100 = 0;

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl SELECT a, b, 'AAA' || c FROM async_pt WHERE b === 505;
INSERT INTO result_tbl SELECT a, b, 'AAA' || c FROM async_pt WHERE b === 505;

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

-- Check case where multiple partitions use the same connection
CREATE TABLE base_tbl3 (a int, b int, c text);
CREATE FOREIGN TABLE async_p3 PARTITION OF async_pt FOR VALUES FROM (3000) TO (4000)
  SERVER loopback2 OPTIONS (table_name 'base_tbl3');
INSERT INTO async_p3 SELECT 3000 + i, i, to_char(i, 'FM0000') FROM generate_series(0, 999, 5) i;
ANALYZE async_pt;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

DROP FOREIGN TABLE async_p3;
DROP TABLE base_tbl3;

-- Check case where the partitioned table has local/remote partitions
CREATE TABLE async_p3 PARTITION OF async_pt FOR VALUES FROM (3000) TO (4000);
INSERT INTO async_p3 SELECT 3000 + i, i, to_char(i, 'FM0000') FROM generate_series(0, 999, 5) i;
ANALYZE async_pt;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;
INSERT INTO result_tbl SELECT * FROM async_pt WHERE b === 505;

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

-- partitionwise joins
SET enable_partitionwise_join TO true;

CREATE TABLE join_tbl (a1 int, b1 int, c1 text, a2 int, b2 int, c2 text);

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO join_tbl SELECT * FROM async_pt t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;
INSERT INTO join_tbl SELECT * FROM async_pt t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;

SELECT * FROM join_tbl ORDER BY a1;
DELETE FROM join_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO join_tbl SELECT t1.a, t1.b, 'AAA' || t1.c, t2.a, t2.b, 'AAA' || t2.c FROM async_pt t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;
INSERT INTO join_tbl SELECT t1.a, t1.b, 'AAA' || t1.c, t2.a, t2.b, 'AAA' || t2.c FROM async_pt t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;

SELECT * FROM join_tbl ORDER BY a1;
DELETE FROM join_tbl;

RESET enable_partitionwise_join;

-- Test rescan of an async Append node with do_exec_prune=false
SET enable_hashjoin TO false;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO join_tbl SELECT * FROM async_p1 t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;
INSERT INTO join_tbl SELECT * FROM async_p1 t1, async_pt t2 WHERE t1.a = t2.a AND t1.b = t2.b AND t1.b % 100 = 0;

SELECT * FROM join_tbl ORDER BY a1;
DELETE FROM join_tbl;

RESET enable_hashjoin;

-- Test interaction of async execution with plan-time partition pruning
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM async_pt WHERE a < 3000;

EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM async_pt WHERE a < 2000;

-- Test interaction of async execution with run-time partition pruning
SET plan_cache_mode TO force_generic_plan;

PREPARE async_pt_query (int, int) AS
  INSERT INTO result_tbl SELECT * FROM async_pt WHERE a < $1 AND b === $2;

EXPLAIN (VERBOSE, COSTS OFF)
EXECUTE async_pt_query (3000, 505);
EXECUTE async_pt_query (3000, 505);

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
EXECUTE async_pt_query (2000, 505);
EXECUTE async_pt_query (2000, 505);

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

RESET plan_cache_mode;

CREATE TABLE local_tbl(a int, b int, c text);
INSERT INTO local_tbl VALUES (1505, 505, 'foo'), (2505, 505, 'bar');
ANALYZE local_tbl;

CREATE INDEX base_tbl1_idx ON base_tbl1 (a);
CREATE INDEX base_tbl2_idx ON base_tbl2 (a);
CREATE INDEX async_p3_idx ON async_p3 (a);
ANALYZE base_tbl1;
ANALYZE base_tbl2;
ANALYZE async_p3;

ALTER FOREIGN TABLE async_p1 OPTIONS (use_remote_estimate 'true');
ALTER FOREIGN TABLE async_p2 OPTIONS (use_remote_estimate 'true');

EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM local_tbl, async_pt WHERE local_tbl.a = async_pt.a AND local_tbl.c = 'bar';
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF, TIMING OFF)
SELECT * FROM local_tbl, async_pt WHERE local_tbl.a = async_pt.a AND local_tbl.c = 'bar';
SELECT * FROM local_tbl, async_pt WHERE local_tbl.a = async_pt.a AND local_tbl.c = 'bar';

ALTER FOREIGN TABLE async_p1 OPTIONS (DROP use_remote_estimate);
ALTER FOREIGN TABLE async_p2 OPTIONS (DROP use_remote_estimate);

DROP TABLE local_tbl;
DROP INDEX base_tbl1_idx;
DROP INDEX base_tbl2_idx;
DROP INDEX async_p3_idx;

-- UNION queries
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl
(SELECT a, b, 'AAA' || c FROM async_p1 ORDER BY a LIMIT 10)
UNION
(SELECT a, b, 'AAA' || c FROM async_p2 WHERE b < 10);
INSERT INTO result_tbl
(SELECT a, b, 'AAA' || c FROM async_p1 ORDER BY a LIMIT 10)
UNION
(SELECT a, b, 'AAA' || c FROM async_p2 WHERE b < 10);

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO result_tbl
(SELECT a, b, 'AAA' || c FROM async_p1 ORDER BY a LIMIT 10)
UNION ALL
(SELECT a, b, 'AAA' || c FROM async_p2 WHERE b < 10);
INSERT INTO result_tbl
(SELECT a, b, 'AAA' || c FROM async_p1 ORDER BY a LIMIT 10)
UNION ALL
(SELECT a, b, 'AAA' || c FROM async_p2 WHERE b < 10);

SELECT * FROM result_tbl ORDER BY a;
DELETE FROM result_tbl;

-- Disable async execution if we use gating Result nodes for pseudoconstant
-- quals
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM async_pt WHERE CURRENT_USER = SESSION_USER;

EXPLAIN (VERBOSE, COSTS OFF)
(SELECT * FROM async_p1 WHERE CURRENT_USER = SESSION_USER)
UNION ALL
(SELECT * FROM async_p2 WHERE CURRENT_USER = SESSION_USER);

EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ((SELECT * FROM async_p1 WHERE b < 10) UNION ALL (SELECT * FROM async_p2 WHERE b < 10)) s WHERE CURRENT_USER = SESSION_USER;

-- Test that pending requests are processed properly
SET enable_mergejoin TO false;
SET enable_hashjoin TO false;

EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM async_pt t1, async_p2 t2 WHERE t1.a = t2.a AND t1.b === 505;
SELECT * FROM async_pt t1, async_p2 t2 WHERE t1.a = t2.a AND t1.b === 505;

CREATE TABLE local_tbl (a int, b int, c text);
INSERT INTO local_tbl VALUES (1505, 505, 'foo');
ANALYZE local_tbl;

EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM local_tbl t1 LEFT JOIN (SELECT *, (SELECT count(*) FROM async_pt WHERE a < 3000) FROM async_pt WHERE a < 3000) t2 ON t1.a = t2.a;
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF, TIMING OFF)
SELECT * FROM local_tbl t1 LEFT JOIN (SELECT *, (SELECT count(*) FROM async_pt WHERE a < 3000) FROM async_pt WHERE a < 3000) t2 ON t1.a = t2.a;
SELECT * FROM local_tbl t1 LEFT JOIN (SELECT *, (SELECT count(*) FROM async_pt WHERE a < 3000) FROM async_pt WHERE a < 3000) t2 ON t1.a = t2.a;

EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM async_pt t1 WHERE t1.b === 505 LIMIT 1;
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF, TIMING OFF)
SELECT * FROM async_pt t1 WHERE t1.b === 505 LIMIT 1;
SELECT * FROM async_pt t1 WHERE t1.b === 505 LIMIT 1;

-- Check with foreign modify
CREATE TABLE base_tbl3 (a int, b int, c text);
CREATE FOREIGN TABLE remote_tbl (a int, b int, c text)
  SERVER loopback OPTIONS (table_name 'base_tbl3');
INSERT INTO remote_tbl VALUES (2505, 505, 'bar');

CREATE TABLE base_tbl4 (a int, b int, c text);
CREATE FOREIGN TABLE insert_tbl (a int, b int, c text)
  SERVER loopback OPTIONS (table_name 'base_tbl4');

EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO insert_tbl (SELECT * FROM local_tbl UNION ALL SELECT * FROM remote_tbl);
INSERT INTO insert_tbl (SELECT * FROM local_tbl UNION ALL SELECT * FROM remote_tbl);

SELECT * FROM insert_tbl ORDER BY a;

-- Check with direct modify
EXPLAIN (VERBOSE, COSTS OFF)
WITH t AS (UPDATE remote_tbl SET c = c || c RETURNING *)
INSERT INTO join_tbl SELECT * FROM async_pt LEFT JOIN t ON (async_pt.a = t.a AND async_pt.b = t.b) WHERE async_pt.b === 505;
WITH t AS (UPDATE remote_tbl SET c = c || c RETURNING *)
INSERT INTO join_tbl SELECT * FROM async_pt LEFT JOIN t ON (async_pt.a = t.a AND async_pt.b = t.b) WHERE async_pt.b === 505;

SELECT * FROM join_tbl ORDER BY a1;
DELETE FROM join_tbl;

DROP TABLE local_tbl;
DROP FOREIGN TABLE remote_tbl;
DROP FOREIGN TABLE insert_tbl;
DROP TABLE base_tbl3;
DROP TABLE base_tbl4;

RESET enable_mergejoin;
RESET enable_hashjoin;

-- Test that UPDATE/DELETE with inherited target works with async_capable enabled
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE async_pt SET c = c || c WHERE b = 0 RETURNING *;
UPDATE async_pt SET c = c || c WHERE b = 0 RETURNING *;
EXPLAIN (VERBOSE, COSTS OFF)
DELETE FROM async_pt WHERE b = 0 RETURNING *;
DELETE FROM async_pt WHERE b = 0 RETURNING *;

-- Check EXPLAIN ANALYZE for a query that scans empty partitions asynchronously
DELETE FROM async_p1;
DELETE FROM async_p2;
DELETE FROM async_p3;

EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF, TIMING OFF)
SELECT * FROM async_pt;

-- Clean up
DROP TABLE async_pt;
DROP TABLE base_tbl1;
DROP TABLE base_tbl2;
DROP TABLE result_tbl;
DROP TABLE join_tbl;

-- Test that an asynchronous fetch is processed before restarting the scan in
-- ReScanForeignScan
CREATE TABLE base_tbl (a int, b int);
INSERT INTO base_tbl VALUES (1, 11), (2, 22), (3, 33);
CREATE FOREIGN TABLE foreign_tbl (b int)
  SERVER loopback OPTIONS (table_name 'base_tbl');
CREATE FOREIGN TABLE foreign_tbl2 () INHERITS (foreign_tbl)
  SERVER loopback OPTIONS (table_name 'base_tbl');

EXPLAIN (VERBOSE, COSTS OFF)
SELECT a FROM base_tbl WHERE a IN (SELECT a FROM foreign_tbl);
SELECT a FROM base_tbl WHERE a IN (SELECT a FROM foreign_tbl);

-- Clean up
DROP FOREIGN TABLE foreign_tbl CASCADE;
DROP TABLE base_tbl;

ALTER SERVER loopback OPTIONS (DROP async_capable);
ALTER SERVER loopback2 OPTIONS (DROP async_capable);
*/

-- ===================================================================
-- test invalid server, foreign table and foreign data wrapper options
-- ===================================================================
-- Invalid fdw_startup_cost option
--Testcase 1224:
CREATE SERVER inv_scst FOREIGN DATA WRAPPER postgres_fdw
	OPTIONS(fdw_startup_cost '100$%$#$#');
-- Invalid fdw_tuple_cost option
--Testcase 1225:
CREATE SERVER inv_scst FOREIGN DATA WRAPPER postgres_fdw
	OPTIONS(fdw_tuple_cost '100$%$#$#');
-- Invalid fetch_size option
--Testcase 1226:
CREATE FOREIGN TABLE inv_fsz (c1 int )
	SERVER postgres_srv OPTIONS (fetch_size '100$%$#$#');
-- Invalid batch_size option
--Testcase 1227:
CREATE FOREIGN TABLE inv_bsz (c1 int )
	SERVER postgres_srv OPTIONS (batch_size '100$%$#$#');

-- Skip this test, pgspider does not support application_name and parallel_commit
/*
-- No option is allowed to be specified at foreign data wrapper level
ALTER FOREIGN DATA WRAPPER postgres_fdw OPTIONS (nonexistent 'fdw');

-- ===================================================================
-- test postgres_fdw.application_name GUC
-- ===================================================================
--- Turn debug_discard_caches off for this test to make sure that
--- the remote connection is alive when checking its application_name.
SET debug_discard_caches = 0;

-- Specify escape sequences in application_name option of a server
-- object so as to test that they are replaced with status information
-- expectedly.
--
-- Since pg_stat_activity.application_name may be truncated to less than
-- NAMEDATALEN characters, note that substring() needs to be used
-- at the condition of test query to make sure that the string consisting
-- of database name and process ID is also less than that.
ALTER SERVER postgres_srv2 OPTIONS (application_name 'fdw_%d%p');
SELECT 1 FROM ft6 LIMIT 1;
SELECT pg_terminate_backend(pid, 180000) FROM pg_stat_activity
  WHERE application_name =
    substring('fdw_' || current_database() || pg_backend_pid() for
      current_setting('max_identifier_length')::int);

-- postgres_fdw.application_name overrides application_name option
-- of a server object if both settings are present.
SET postgres_fdw.application_name TO 'fdw_%a%u%%';
SELECT 1 FROM ft6 LIMIT 1;
SELECT pg_terminate_backend(pid, 180000) FROM pg_stat_activity
  WHERE application_name =
    substring('fdw_' || current_setting('application_name') ||
      CURRENT_USER || '%' for current_setting('max_identifier_length')::int);

-- Test %c (session ID) and %C (cluster name) escape sequences.
SET postgres_fdw.application_name TO 'fdw_%C%c';
SELECT 1 FROM ft6 LIMIT 1;
SELECT pg_terminate_backend(pid, 180000) FROM pg_stat_activity
  WHERE application_name =
    substring('fdw_' || current_setting('cluster_name') ||
      to_hex(trunc(EXTRACT(EPOCH FROM (SELECT backend_start FROM
      pg_stat_get_activity(pg_backend_pid()))))::integer) || '.' ||
      to_hex(pg_backend_pid())
      for current_setting('max_identifier_length')::int);

--Clean up
RESET postgres_fdw.application_name;
RESET debug_discard_caches;
*/
-- ===================================================================
-- test parallel commit
-- ===================================================================
ALTER SERVER postgres_srv OPTIONS (ADD parallel_commit 'true');
ALTER SERVER postgres_srv2 OPTIONS (ADD parallel_commit 'true');

--Testcase 1228:
CREATE FOREIGN TABLE prem1 (f1 int, f2 text)
  SERVER postgres_srv OPTIONS (table_name 'ploc1');

--Testcase 1229:
CREATE FOREIGN TABLE prem2 (f1 int, f2 text)
  SERVER postgres_srv2 OPTIONS (table_name 'ploc2');

BEGIN;
--Testcase 1230:
INSERT INTO prem1 VALUES (101, 'foo');
--Testcase 1231:
INSERT INTO prem2 VALUES (201, 'bar');
COMMIT;
--Testcase 1232:
SELECT * FROM prem1;
--Testcase 1233:
SELECT * FROM prem2;

BEGIN;
SAVEPOINT s;
--Testcase 1234:
INSERT INTO prem1 VALUES (102, 'foofoo');
--Testcase 1235:
INSERT INTO prem2 VALUES (202, 'barbar');
RELEASE SAVEPOINT s;
COMMIT;
--Testcase 1236:
SELECT * FROM prem1;
--Testcase 1237:
SELECT * FROM prem2;

-- This tests executing DEALLOCATE ALL against foreign servers in parallel
-- during pre-commit
BEGIN;
SAVEPOINT s;
--Testcase 1238:
INSERT INTO prem1 VALUES (103, 'baz');
--Testcase 1239:
INSERT INTO prem2 VALUES (203, 'qux');
ROLLBACK TO SAVEPOINT s;
RELEASE SAVEPOINT s;
--Testcase 1240:
INSERT INTO prem1 VALUES (104, 'bazbaz');
--Testcase 1241:
INSERT INTO prem2 VALUES (204, 'quxqux');
COMMIT;
--Testcase 1242:
SELECT * FROM prem1;
--Testcase 1243:
SELECT * FROM prem2;

ALTER SERVER postgres_srv OPTIONS (DROP parallel_commit);
ALTER SERVER postgres_srv2 OPTIONS (DROP parallel_commit);

--Testcase 1146:
SELECT dblink_disconnect();
