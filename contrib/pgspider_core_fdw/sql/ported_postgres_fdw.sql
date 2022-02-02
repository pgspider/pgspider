-- ===================================================================
-- create FDW objects
-- ===================================================================

CREATE EXTENSION postgres_fdw;
CREATE EXTENSION pgspider_core_fdw;
CREATE EXTENSION dblink;

-- we use dblink to support insert data during test is in progress in some test cases
--Testcase 1:
select dblink_connect('dbname=postdb host=127.0.0.1 
	port=15432 user=postgres password=postgres');

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
    END;
$d$;

CREATE USER MAPPING FOR public SERVER pgspider_srv
	OPTIONS (user 'postgres', password 'postgres');
CREATE USER MAPPING FOR public SERVER postgres_srv
	OPTIONS (user 'postgres', password 'postgres');
CREATE USER MAPPING FOR public SERVER postgres_srv2
	OPTIONS (user 'postgres', password 'postgres');

-- ===================================================================
-- create objects used through PostgreSQL FDW server
-- ===================================================================
CREATE TYPE user_enum AS ENUM ('foo', 'bar', 'buz');
CREATE SCHEMA "S 1";
---CREATE TABLE "S 1"."T 1" (
---	"C 1" int NOT NULL,
---	c2 int NOT NULL,
---	c3 text,
---	c4 timestamptz,
---	c5 timestamp,
---	c6 varchar(10),
---	c7 char(10),
---	c8 user_enum,
---	CONSTRAINT t1_pkey PRIMARY KEY ("C 1")
---);
---CREATE TABLE "S 1"."T 2" (
---	c1 int NOT NULL,
---	c2 text,
---	CONSTRAINT t2_pkey PRIMARY KEY (c1)
---);
---CREATE TABLE "S 1"."T 3" (
---	c1 int NOT NULL,
---	c2 int NOT NULL,
---	c3 text,
---	CONSTRAINT t3_pkey PRIMARY KEY (c1)
---);
---CREATE TABLE "S 1"."T 4" (
---	c1 int NOT NULL,
---	c2 int NOT NULL,
---	c3 text,
---	CONSTRAINT t4_pkey PRIMARY KEY (c1)
---);

-- Disable autovacuum for these tables to avoid unexpected effects of that
---ALTER TABLE "S 1"."T 1" SET (autovacuum_enabled = 'false');
---ALTER TABLE "S 1"."T 2" SET (autovacuum_enabled = 'false');
---ALTER TABLE "S 1"."T 3" SET (autovacuum_enabled = 'false');
---ALTER TABLE "S 1"."T 4" SET (autovacuum_enabled = 'false');

IMPORT FOREIGN SCHEMA "S 1" FROM SERVER postgres_srv INTO "S 1";

--Testcase 2:
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
--Testcase 3:
INSERT INTO "S 1"."T 2"
	SELECT id,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
--Testcase 4:
INSERT INTO "S 1"."T 3"
	SELECT id,
	       id + 1,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
DELETE FROM "S 1"."T 3" WHERE c1 % 2 != 0;	-- delete for outer join tests
--Testcase 5:
INSERT INTO "S 1"."T 4"
	SELECT id,
	       id + 1,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
DELETE FROM "S 1"."T 4" WHERE c1 % 3 != 0;	-- delete for outer join tests

ANALYZE "S 1"."T 1";
ANALYZE "S 1"."T 2";
ANALYZE "S 1"."T 3";
ANALYZE "S 1"."T 4";

-- ===================================================================
-- create foreign tables
-- ===================================================================
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
ALTER FOREIGN TABLE ft1 DROP COLUMN c0;

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
ALTER FOREIGN TABLE ft1__postgres_srv__0 DROP COLUMN c0;

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
ALTER FOREIGN TABLE ft2 DROP COLUMN cx;

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
ALTER FOREIGN TABLE ft2__postgres_srv__0 DROP COLUMN cx;

CREATE FOREIGN TABLE ft4 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	__spd_url text
) SERVER pgspider_srv;

CREATE FOREIGN TABLE ft4__postgres_srv__0 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text
) SERVER postgres_srv OPTIONS (schema_name 'S 1', table_name 'T 3');

CREATE FOREIGN TABLE ft5 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	__spd_url text
) SERVER pgspider_srv;

CREATE FOREIGN TABLE ft5__postgres_srv__0 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text
) SERVER postgres_srv OPTIONS (schema_name 'S 1', table_name 'T 4');

CREATE FOREIGN TABLE ft6 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	__spd_url text
) SERVER pgspider_srv;

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

ALTER FOREIGN TABLE ft1 ALTER COLUMN c1 OPTIONS (column_name 'C 1');
ALTER FOREIGN TABLE ft1__postgres_srv__0 ALTER COLUMN c1 OPTIONS (column_name 'C 1');
ALTER FOREIGN TABLE ft2 ALTER COLUMN c1 OPTIONS (column_name 'C 1');
ALTER FOREIGN TABLE ft2__postgres_srv__0 ALTER COLUMN c1 OPTIONS (column_name 'C 1');
--Testcase 6:
\det+

-- Test that alteration of server options causes reconnection
-- Remote's errors might be non-English, so hide them to ensure stable results
\set VERBOSITY terse
--Testcase 7:
SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work
ALTER SERVER postgres_srv OPTIONS (SET dbname 'no such database');
--Testcase 8:
SELECT c3, c4 FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should fail
DO $d$
    BEGIN
        EXECUTE $$ALTER SERVER postgres_srv
            OPTIONS (SET dbname 'postdb')$$;
    END;
$d$;
--Testcase 9:
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
ALTER FOREIGN TABLE ft2 OPTIONS (use_remote_estimate 'true');

-- ===================================================================
-- simple queries
-- ===================================================================
-- single table without alias
--Testcase 10:
EXPLAIN (COSTS OFF) SELECT * FROM ft1 ORDER BY c3, c1 OFFSET 100 LIMIT 10;
--Testcase 11:
SELECT * FROM ft1 ORDER BY c3, c1 OFFSET 100 LIMIT 10;
-- single table with alias - also test that tableoid sort is not pushed to remote side
--Testcase 12:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 ORDER BY t1.c3, t1.c1, t1.tableoid OFFSET 100 LIMIT 10;
--Testcase 13:
SELECT * FROM ft1 t1 ORDER BY t1.c3, t1.c1, t1.tableoid OFFSET 100 LIMIT 10;
-- whole-row reference
--Testcase 14:
EXPLAIN (VERBOSE, COSTS OFF) SELECT t1 FROM ft1 t1 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 15:
SELECT t1 FROM ft1 t1 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- empty result
--Testcase 16:
SELECT * FROM ft1 WHERE false;
-- with WHERE clause
--Testcase 17:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 101 AND t1.c6 = '1' AND t1.c7 >= '1';
--Testcase 18:
SELECT * FROM ft1 t1 WHERE t1.c1 = 101 AND t1.c6 = '1' AND t1.c7 >= '1';
-- with FOR UPDATE/SHARE
--Testcase 19:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = 101 FOR UPDATE;
--Testcase 20:
SELECT * FROM ft1 t1 WHERE c1 = 101 FOR UPDATE;
--Testcase 21:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = 102 FOR SHARE;
--Testcase 22:
SELECT * FROM ft1 t1 WHERE c1 = 102 FOR SHARE;
-- aggregate
--Testcase 23:
SELECT COUNT(*) FROM ft1 t1;
-- subquery
--Testcase 24:
SELECT * FROM ft1 t1 WHERE t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 <= 10) ORDER BY c1;
-- subquery+MAX
--Testcase 25:
SELECT * FROM ft1 t1 WHERE t1.c3 = (SELECT MAX(c3) FROM ft2 t2) ORDER BY c1;
-- subquery return more than one row
SELECT * FROM ft1 t1 WHERE t1.c3 = (SELECT c3 FROM ft2 t2) ORDER BY c1;
-- used in CTE
--Testcase 26:
WITH t1 AS (SELECT * FROM ft1 WHERE c1 <= 10) SELECT t2.c1, t2.c2, t2.c3, t2.c4 FROM t1, ft2 t2 WHERE t1.c1 = t2.c1 ORDER BY t1.c1;
-- fixed values
--Testcase 27:
SELECT 'fixed', NULL FROM ft1 t1 WHERE c1 = 1;
-- Test forcing the remote server to produce sorted data for a merge join.
SET enable_hashjoin TO false;
SET enable_nestloop TO false;
-- inner join; expressions in the clauses appear in the equivalence class list
--Testcase 28:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1.c1, t2."C 1" FROM ft2 t1 JOIN "S 1"."T 1" t2 ON (t1.c1 = t2."C 1") OFFSET 100 LIMIT 10;
--Testcase 29:
SELECT t1.c1, t2."C 1" FROM ft2 t1 JOIN "S 1"."T 1" t2 ON (t1.c1 = t2."C 1") OFFSET 100 LIMIT 10;
-- outer join; expressions in the clauses do not appear in equivalence class
-- list but no output change as compared to the previous query
--Testcase 30:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1.c1, t2."C 1" FROM ft2 t1 LEFT JOIN "S 1"."T 1" t2 ON (t1.c1 = t2."C 1") OFFSET 100 LIMIT 10;
--Testcase 31:
SELECT t1.c1, t2."C 1" FROM ft2 t1 LEFT JOIN "S 1"."T 1" t2 ON (t1.c1 = t2."C 1") OFFSET 100 LIMIT 10;
-- A join between local table and foreign join. ORDER BY clause is added to the
-- foreign join so that the local table can be joined using merge join strategy.
--Testcase 32:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C 1" FROM "S 1"."T 1" t1 left join ft1 t2 join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C 1") OFFSET 100 LIMIT 10;
--Testcase 33:
SELECT t1."C 1" FROM "S 1"."T 1" t1 left join ft1 t2 join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C 1") OFFSET 100 LIMIT 10;
-- Test similar to above, except that the full join prevents any equivalence
-- classes from being merged. This produces single relation equivalence classes
-- included in join restrictions.
--Testcase 34:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C 1", t2.c1, t3.c1 FROM "S 1"."T 1" t1 left join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C 1") OFFSET 100 LIMIT 10;
--Testcase 35:
SELECT t1."C 1", t2.c1, t3.c1 FROM "S 1"."T 1" t1 left join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C 1") OFFSET 100 LIMIT 10;
-- Test similar to above with all full outer joins
--Testcase 36:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C 1", t2.c1, t3.c1 FROM "S 1"."T 1" t1 full join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C 1") OFFSET 100 LIMIT 10;
--Testcase 37:
SELECT t1."C 1", t2.c1, t3.c1 FROM "S 1"."T 1" t1 full join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C 1") OFFSET 100 LIMIT 10;
RESET enable_hashjoin;
RESET enable_nestloop;

-- ===================================================================
-- WHERE with remotely-executable conditions
-- ===================================================================
--Testcase 38:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 1;         -- Var, OpExpr(b), Const
--Testcase 39:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 100 AND t1.c2 = 0; -- BoolExpr
--Testcase 40:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 IS NULL;        -- NullTest
--Testcase 41:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 IS NOT NULL;    -- NullTest
--Testcase 42:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE round(abs(c1), 0) = 1; -- FuncExpr
--Testcase 43:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = -c1;          -- OpExpr(l)
--Testcase 44:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE 1 = c1!;           -- OpExpr(r)
--Testcase 45:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (c1 IS NOT NULL) IS DISTINCT FROM (c1 IS NOT NULL); -- DistinctExpr
--Testcase 46:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = ANY(ARRAY[c2, 1, c1 + 0]); -- ScalarArrayOpExpr
--Testcase 47:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = (ARRAY[c1,c2,3])[1]; -- SubscriptingRef
--Testcase 48:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c6 = E'foo''s\\bar';  -- check special chars
--Testcase 49:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c8 = 'foo';  -- can't be sent to remote
-- parameterized remote path for foreign table
--Testcase 50:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM "S 1"."T 1" a, ft2 b WHERE a."C 1" = 47 AND b.c1 = a.c2;
--Testcase 51:
SELECT * FROM ft2 a, ft2 b WHERE a.c1 = 47 AND b.c1 = a.c2;

-- check both safe and unsafe join conditions
--Testcase 52:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft2 a, ft2 b
  WHERE a.c2 = 6 AND b.c1 = a.c1 AND a.c8 = 'foo' AND b.c7 = upper(a.c7);
--Testcase 53:
SELECT * FROM ft2 a, ft2 b
WHERE a.c2 = 6 AND b.c1 = a.c1 AND a.c8 = 'foo' AND b.c7 = upper(a.c7);
-- bug before 9.3.5 due to sloppy handling of remote-estimate parameters
SELECT * FROM ft1 WHERE c1 = ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
SELECT * FROM ft2 WHERE c1 = ANY (ARRAY(SELECT c1 FROM ft1 WHERE c1 < 5));
-- we should not push order by clause with volatile expressions or unsafe
-- collations
--Testcase 54:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT * FROM ft2 ORDER BY ft2.c1, random();
--Testcase 55:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT * FROM ft2 ORDER BY ft2.c1, ft2.c3 collate "C";

-- user-defined operator/function
CREATE FUNCTION postgres_fdw_abs(int) RETURNS int AS $$
BEGIN
RETURN abs($1);
END
$$ LANGUAGE plpgsql IMMUTABLE;
CREATE OPERATOR === (
    LEFTARG = int,
    RIGHTARG = int,
    PROCEDURE = int4eq,
    COMMUTATOR = ===
);

-- built-in operators and functions can be shipped for remote execution
--Testcase 56:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = abs(t1.c2);
--Testcase 57:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = abs(t1.c2);
--Testcase 58:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = t1.c2;
--Testcase 59:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = t1.c2;

-- by default, user-defined ones cannot
--Testcase 60:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 61:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 62:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 63:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;

-- ORDER BY can be shipped, though
--Testcase 64:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;
--Testcase 65:
SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;

-- but let's put them in an extension ...
ALTER EXTENSION pgspider_core_fdw ADD FUNCTION postgres_fdw_abs(int);
ALTER EXTENSION pgspider_core_fdw ADD OPERATOR === (int, int);
ALTER SERVER postgres_srv OPTIONS (ADD extensions 'postgres_fdw');

-- ... now they can be shipped
--Testcase 66:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 67:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = postgres_fdw_abs(t1.c2);
--Testcase 68:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 69:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;

-- and both ORDER BY and LIMIT can be shipped
--Testcase 70:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;
--Testcase 71:
SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;

-- ===================================================================
-- JOIN queries
-- ===================================================================
-- Analyze ft4 and ft5 so that we have better statistics. These tables do not
-- have use_remote_estimate set.
ANALYZE ft4;
ANALYZE ft5;

-- join two tables
--Testcase 72:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 73:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- join three tables
--Testcase 74:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) JOIN ft4 t3 ON (t3.c1 = t1.c1) ORDER BY t1.c3, t1.c1 OFFSET 10 LIMIT 10;
--Testcase 75:
SELECT t1.c1, t2.c2, t3.c3 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) JOIN ft4 t3 ON (t3.c1 = t1.c1) ORDER BY t1.c3, t1.c1 OFFSET 10 LIMIT 10;
-- left outer join
--Testcase 76:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 77:
SELECT t1.c1, t2.c1 FROM ft4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
-- left outer join three tables
--Testcase 78:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 79:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + placement of clauses.
-- clauses within the nullable side are not pulled up, but top level clause on
-- non-nullable side is pushed into non-nullable side
--Testcase 80:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1) WHERE t1.c1 < 10;
--Testcase 81:
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1) WHERE t1.c1 < 10;
-- clauses within the nullable side are not pulled up, but the top level clause
-- on nullable side is not pushed down into nullable side
--Testcase 82:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
			WHERE (t2.c1 < 10 OR t2.c1 IS NULL) AND t1.c1 < 10;
--Testcase 83:
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
			WHERE (t2.c1 < 10 OR t2.c1 IS NULL) AND t1.c1 < 10;
-- right outer join
--Testcase 84:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft5 t1 RIGHT JOIN ft4 t2 ON (t1.c1 = t2.c1) ORDER BY t2.c1, t1.c1 OFFSET 10 LIMIT 10;
--Testcase 85:
SELECT t1.c1, t2.c1 FROM ft5 t1 RIGHT JOIN ft4 t2 ON (t1.c1 = t2.c1) ORDER BY t2.c1, t1.c1 OFFSET 10 LIMIT 10;
-- right outer join three tables
--Testcase 86:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 87:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join
--Testcase 88:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 45 LIMIT 10;
--Testcase 89:
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 45 LIMIT 10;
-- full outer join with restrictions on the joining relations
-- a. the joining relations are both base relations
--Testcase 90:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1;
--Testcase 91:
SELECT t1.c1, t2.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1;
--Testcase 92:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT 1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (TRUE) OFFSET 10 LIMIT 10;
--Testcase 93:
SELECT 1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (TRUE) OFFSET 10 LIMIT 10;
-- b. one of the joining relations is a base relation and the other is a join
-- relation
--Testcase 94:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM ft4 t2 LEFT JOIN ft5 t3 ON (t2.c1 = t3.c1) WHERE (t2.c1 between 50 and 60)) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
--Testcase 95:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM ft4 t2 LEFT JOIN ft5 t3 ON (t2.c1 = t3.c1) WHERE (t2.c1 between 50 and 60)) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
-- c. test deparsing the remote query as nested subqueries
--Testcase 96:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
--Testcase 97:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
-- d. test deparsing rowmarked relations as subqueries
--Testcase 98:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM "S 1"."T 3" WHERE c1 = 50) t1 INNER JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (TRUE) ORDER BY t1.c1, ss.a, ss.b FOR UPDATE OF t1;
--Testcase 99:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM "S 1"."T 3" WHERE c1 = 50) t1 INNER JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (TRUE) ORDER BY t1.c1, ss.a, ss.b FOR UPDATE OF t1;
-- full outer join + inner join
--Testcase 100:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1, t3.c1 FROM ft4 t1 INNER JOIN ft5 t2 ON (t1.c1 = t2.c1 + 1 and t1.c1 between 50 and 60) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1, t2.c1, t3.c1 LIMIT 10;
--Testcase 101:
SELECT t1.c1, t2.c1, t3.c1 FROM ft4 t1 INNER JOIN ft5 t2 ON (t1.c1 = t2.c1 + 1 and t1.c1 between 50 and 60) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1, t2.c1, t3.c1 LIMIT 10;
-- full outer join three tables
--Testcase 102:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1 OFFSET 10 LIMIT 10;
--Testcase 103:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1 OFFSET 10 LIMIT 10;
-- full outer join + right outer join
--Testcase 104:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 105:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- right outer join + full outer join
--Testcase 106:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 107:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + left outer join
--Testcase 108:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 109:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + full outer join
--Testcase 110:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1 OFFSET 10 LIMIT 10;
--Testcase 111:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1 OFFSET 10 LIMIT 10;
-- right outer join + left outer join
--Testcase 112:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 113:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + right outer join
--Testcase 114:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 115:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + WHERE clause, only matched rows
--Testcase 116:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) WHERE (t1.c1 = t2.c1 OR t1.c1 IS NULL) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 117:
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) WHERE (t1.c1 = t2.c1 OR t1.c1 IS NULL) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
-- full outer join + WHERE clause with shippable extensions set
--Testcase 118:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t1.c3 FROM ft1 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE postgres_fdw_abs(t1.c1) > 0 OFFSET 10 LIMIT 10;
ALTER SERVER postgres_srv OPTIONS (DROP extensions);
-- full outer join + WHERE clause with shippable extensions not set
--Testcase 119:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t1.c3 FROM ft1 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE postgres_fdw_abs(t1.c1) > 0 OFFSET 10 LIMIT 10;
ALTER SERVER postgres_srv OPTIONS (ADD extensions 'postgres_fdw');
-- join two tables with FOR UPDATE clause
-- tests whole-row reference for row marks
--Testcase 120:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE OF t1;
--Testcase 121:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE OF t1;
--Testcase 122:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE;
--Testcase 123:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE;
-- join two tables with FOR SHARE clause
--Testcase 124:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE OF t1;
--Testcase 125:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE OF t1;
--Testcase 126:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE;
--Testcase 127:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE;
-- join in CTE
--Testcase 128:
EXPLAIN (VERBOSE, COSTS OFF)
WITH t (c1_1, c1_3, c2_1) AS MATERIALIZED (SELECT t1.c1, t1.c3, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1 OFFSET 100 LIMIT 10;
--Testcase 129:
WITH t (c1_1, c1_3, c2_1) AS MATERIALIZED (SELECT t1.c1, t1.c3, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1 OFFSET 100 LIMIT 10;
-- ctid with whole-row reference
--Testcase 130:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.ctid, t1, t2, t1.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- SEMI JOIN, not pushed down
--Testcase 131:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1 FROM ft1 t1 WHERE EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c1) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
--Testcase 132:
SELECT t1.c1 FROM ft1 t1 WHERE EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c1) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
-- ANTI JOIN, not pushed down
--Testcase 133:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1 FROM ft1 t1 WHERE NOT EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c2) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
--Testcase 134:
SELECT t1.c1 FROM ft1 t1 WHERE NOT EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c2) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
-- CROSS JOIN can be pushed down
--Testcase 135:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 CROSS JOIN ft2 t2 ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 136:
SELECT t1.c1, t2.c1 FROM ft1 t1 CROSS JOIN ft2 t2 ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- different server, not pushed down. No result expected.
--Testcase 137:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft5 t1 JOIN ft6 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 138:
SELECT t1.c1, t2.c1 FROM ft5 t1 JOIN ft6 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- unsafe join conditions (c8 has a UDT), not pushed down. Practically a CROSS
-- JOIN since c8 in both tables has same value.
--Testcase 139:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c8 = t2.c8) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 140:
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c8 = t2.c8) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- unsafe conditions on one side (c8 has a UDT), not pushed down.
--Testcase 141:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = 'foo' ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 142:
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = 'foo' ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- join where unsafe to pushdown condition in WHERE clause has a column not
-- in the SELECT clause. In this test unsafe clause needs to have column
-- references from both joining sides so that the clause is not pushed down
-- into one of the joining sides.
--Testcase 143:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = t2.c8 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 144:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = t2.c8 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- Aggregate after UNION, for testing setrefs
--Testcase 145:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1c1, avg(t1c1 + t2c1) FROM (SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) UNION SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) AS t (t1c1, t2c1) GROUP BY t1c1 ORDER BY t1c1 OFFSET 100 LIMIT 10;
--Testcase 146:
SELECT t1c1, avg(t1c1 + t2c1) FROM (SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) UNION SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) AS t (t1c1, t2c1) GROUP BY t1c1 ORDER BY t1c1 OFFSET 100 LIMIT 10;
-- join with lateral reference
--Testcase 147:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1."C 1" FROM "S 1"."T 1" t1, LATERAL (SELECT DISTINCT t2.c1, t3.c1 FROM ft1 t2, ft2 t3 WHERE t2.c1 = t3.c1 AND t2.c2 = t1.c2) q ORDER BY t1."C 1" OFFSET 10 LIMIT 10;
--Testcase 148:
SELECT t1."C 1" FROM "S 1"."T 1" t1, LATERAL (SELECT DISTINCT t2.c1, t3.c1 FROM ft1 t2, ft2 t3 WHERE t2.c1 = t3.c1 AND t2.c2 = t1.c2) q ORDER BY t1."C 1" OFFSET 10 LIMIT 10;

-- non-Var items in targetlist of the nullable rel of a join preventing
-- push-down in some cases
-- unable to push {ft1, ft2}
--Testcase 149:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT q.a, ft2.c1 FROM (SELECT 13 FROM ft1 WHERE c1 = 13) q(a) RIGHT JOIN ft2 ON (q.a = ft2.c1) WHERE ft2.c1 BETWEEN 10 AND 15;
--Testcase 150:
SELECT q.a, ft2.c1 FROM (SELECT 13 FROM ft1 WHERE c1 = 13) q(a) RIGHT JOIN ft2 ON (q.a = ft2.c1) WHERE ft2.c1 BETWEEN 10 AND 15;

-- ok to push {ft1, ft2} but not {ft1, ft2, ft4}
--Testcase 151:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ft4.c1, q.* FROM ft4 LEFT JOIN (SELECT 13, ft1.c1, ft2.c1 FROM ft1 RIGHT JOIN ft2 ON (ft1.c1 = ft2.c1) WHERE ft1.c1 = 12) q(a, b, c) ON (ft4.c1 = q.b) WHERE ft4.c1 BETWEEN 10 AND 15;
--Testcase 152:
SELECT ft4.c1, q.* FROM ft4 LEFT JOIN (SELECT 13, ft1.c1, ft2.c1 FROM ft1 RIGHT JOIN ft2 ON (ft1.c1 = ft2.c1) WHERE ft1.c1 = 12) q(a, b, c) ON (ft4.c1 = q.b) WHERE ft4.c1 BETWEEN 10 AND 15;

-- join with nullable side with some columns with null values
--Testcase 153:
UPDATE ft5__postgres_srv__0 SET c3 = null where c1 % 9 = 0;
--Testcase 154:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ft5, ft5.c1, ft5.c2, ft5.c3, ft4.c1, ft4.c2 FROM ft5 left join ft4 on ft5.c1 = ft4.c1 WHERE ft4.c1 BETWEEN 10 and 30 ORDER BY ft5.c1, ft4.c1;
--Testcase 155:
SELECT ft5, ft5.c1, ft5.c2, ft5.c3, ft4.c1, ft4.c2 FROM ft5 left join ft4 on ft5.c1 = ft4.c1 WHERE ft4.c1 BETWEEN 10 and 30 ORDER BY ft5.c1, ft4.c1;

-- multi-way join involving multiple merge joins
-- (this case used to have EPQ-related planning problems)
CREATE TABLE local_tbl (c1 int NOT NULL, c2 int NOT NULL, c3 text, CONSTRAINT local_tbl_pkey PRIMARY KEY (c1));
--Testcase 156:
INSERT INTO local_tbl SELECT id, id % 10, to_char(id, 'FM0000') FROM generate_series(1, 1000) id;
ANALYZE local_tbl;
SET enable_nestloop TO false;
SET enable_hashjoin TO false;
--Testcase 157:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1, ft2, ft4, ft5, local_tbl WHERE ft1.c1 = ft2.c1 AND ft1.c2 = ft4.c1
    AND ft1.c2 = ft5.c1 AND ft1.c2 = local_tbl.c1 AND ft1.c1 < 100 AND ft2.c1 < 100 FOR UPDATE;
--Testcase 158:
SELECT * FROM ft1, ft2, ft4, ft5, local_tbl WHERE ft1.c1 = ft2.c1 AND ft1.c2 = ft4.c1
    AND ft1.c2 = ft5.c1 AND ft1.c2 = local_tbl.c1 AND ft1.c1 < 100 AND ft2.c1 < 100 FOR UPDATE;
RESET enable_nestloop;
RESET enable_hashjoin;
DROP TABLE local_tbl;

-- check join pushdown in situations where multiple userids are involved
CREATE ROLE regress_view_owner SUPERUSER;
CREATE USER MAPPING FOR regress_view_owner SERVER postgres_srv;
GRANT SELECT ON ft4 TO regress_view_owner;
GRANT SELECT ON ft5 TO regress_view_owner;

CREATE VIEW v4 AS SELECT * FROM ft4;
CREATE VIEW v5 AS SELECT * FROM ft5;
ALTER VIEW v5 OWNER TO regress_view_owner;
--Testcase 159:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can't be pushed down, different view owners
--Testcase 160:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
ALTER VIEW v4 OWNER TO regress_view_owner;
--Testcase 161:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can be pushed down
--Testcase 162:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;

--Testcase 163:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can't be pushed down, view owner not current user
--Testcase 164:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
ALTER VIEW v4 OWNER TO CURRENT_USER;
--Testcase 165:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can be pushed down
--Testcase 166:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
ALTER VIEW v4 OWNER TO regress_view_owner;

-- cleanup
DROP OWNED BY regress_view_owner;
DROP ROLE regress_view_owner;


-- ===================================================================
-- Aggregate and grouping queries
-- ===================================================================

-- Simple aggregates
--Testcase 167:
explain (verbose, costs off)
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2;
--Testcase 168:
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2;

--Testcase 169:
explain (verbose, costs off)
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2 limit 1;
--Testcase 170:
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2 limit 1;

-- Aggregate is not pushed down as aggregation contains random()
--Testcase 171:
explain (verbose, costs off)
select sum(c1 * (random() <= 1)::int) as sum, avg(c1) from ft1;

-- Aggregate over join query
--Testcase 172:
explain (verbose, costs off)
select count(*), sum(t1.c1), avg(t2.c1) from ft1 t1 inner join ft1 t2 on (t1.c2 = t2.c2) where t1.c2 = 6;
--Testcase 173:
select count(*), sum(t1.c1), avg(t2.c1) from ft1 t1 inner join ft1 t2 on (t1.c2 = t2.c2) where t1.c2 = 6;

-- Not pushed down due to local conditions present in underneath input rel
--Testcase 174:
explain (verbose, costs off)
select sum(t1.c1), count(t2.c1) from ft1 t1 inner join ft2 t2 on (t1.c1 = t2.c1) where ((t1.c1 * t2.c1)/(t1.c1 * t2.c1)) * random() <= 1;

-- GROUP BY clause having expressions
--Testcase 175:
explain (verbose, costs off)
select c2/2, sum(c2) * (c2/2) from ft1 group by c2/2 order by c2/2;
--Testcase 176:
select c2/2, sum(c2) * (c2/2) from ft1 group by c2/2 order by c2/2;

-- Aggregates in subquery are pushed down.
--Testcase 177:
explain (verbose, costs off)
select count(x.a), sum(x.a) from (select c2 a, sum(c1) b from ft1 group by c2, sqrt(c1) order by 1, 2) x;
--Testcase 178:
select count(x.a), sum(x.a) from (select c2 a, sum(c1) b from ft1 group by c2, sqrt(c1) order by 1, 2) x;

-- Aggregate is still pushed down by taking unshippable expression out
--Testcase 179:
explain (verbose, costs off)
select c2 * (random() <= 1)::int as sum1, sum(c1) * c2 as sum2 from ft1 group by c2 order by 1, 2;
--Testcase 180:
select c2 * (random() <= 1)::int as sum1, sum(c1) * c2 as sum2 from ft1 group by c2 order by 1, 2;

-- Aggregate with unshippable GROUP BY clause are not pushed
--Testcase 181:
explain (verbose, costs off)
select c2 * (random() <= 1)::int as c2 from ft2 group by c2 * (random() <= 1)::int order by 1;

-- GROUP BY clause in various forms, cardinal, alias and constant expression
--Testcase 182:
explain (verbose, costs off)
select count(c2) w, c2 x, 5 y, 7.0 z from ft1 group by 2, y, 9.0::int order by 2;
--Testcase 183:
select count(c2) w, c2 x, 5 y, 7.0 z from ft1 group by 2, y, 9.0::int order by 2;

-- GROUP BY clause referring to same column multiple times
-- Also, ORDER BY contains an aggregate function
--Testcase 184:
explain (verbose, costs off)
select c2, c2 from ft1 where c2 > 6 group by 1, 2 order by sum(c1);
--Testcase 185:
select c2, c2 from ft1 where c2 > 6 group by 1, 2 order by sum(c1);

-- Testing HAVING clause shippability
--Testcase 186:
explain (verbose, costs off)
select c2, sum(c1) from ft2 group by c2 having avg(c1) < 500 and sum(c1) < 49800 order by c2;
--Testcase 187:
select c2, sum(c1) from ft2 group by c2 having avg(c1) < 500 and sum(c1) < 49800 order by c2;

-- Unshippable HAVING clause will be evaluated locally, and other qual in HAVING clause is pushed down
--Testcase 188:
explain (verbose, costs off)
select count(*) from (select c5, count(c1) from ft1 group by c5, sqrt(c2) having (avg(c1) / avg(c1)) * random() <= 1 and avg(c1) < 500) x;
select count(*) from (select c5, count(c1) from ft1 group by c5, sqrt(c2) having (avg(c1) / avg(c1)) * random() <= 1 and avg(c1) < 500) x;

-- Aggregate in HAVING clause is not pushable, and thus aggregation is not pushed down
--Testcase 189:
explain (verbose, costs off)
select sum(c1) from ft1 group by c2 having avg(c1 * (random() <= 1)::int) > 100 order by 1;

-- Remote aggregate in combination with a local Param (for the output
-- of an initplan) can be trouble, per bug #15781
--Testcase 190:
explain (verbose, costs off)
select exists(select 1 from pg_enum), sum(c1) from ft1;
--Testcase 191:
select exists(select 1 from pg_enum), sum(c1) from ft1;

--Testcase 192:
explain (verbose, costs off)
select exists(select 1 from pg_enum), sum(c1) from ft1 group by 1;
--Testcase 193:
select exists(select 1 from pg_enum), sum(c1) from ft1 group by 1;


-- Testing ORDER BY, DISTINCT, FILTER, Ordered-sets and VARIADIC within aggregates

-- ORDER BY within aggregate, same column used to order
--Testcase 194:
explain (verbose, costs off)
select array_agg(c1 order by c1) from ft1 where c1 < 100 group by c2 order by 1;
--Testcase 195:
select array_agg(c1 order by c1) from ft1 where c1 < 100 group by c2 order by 1;

-- ORDER BY within aggregate, different column used to order also using DESC
--Testcase 196:
explain (verbose, costs off)
select array_agg(c5 order by c1 desc) from ft2 where c2 = 6 and c1 < 50;
--Testcase 197:
select array_agg(c5 order by c1 desc) from ft2 where c2 = 6 and c1 < 50;

-- DISTINCT within aggregate
--Testcase 198:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 199:
select array_agg(distinct (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

-- DISTINCT combined with ORDER BY within aggregate
--Testcase 200:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 201:
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

--Testcase 202:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5 desc nulls last) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 203:
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5 desc nulls last) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

-- FILTER within aggregate
--Testcase 204:
explain (verbose, costs off)
select sum(c1) filter (where c1 < 100 and c2 > 5) from ft1 group by c2 order by 1 nulls last;
--Testcase 205:
select sum(c1) filter (where c1 < 100 and c2 > 5) from ft1 group by c2 order by 1 nulls last;

-- DISTINCT, ORDER BY and FILTER within aggregate
--Testcase 206:
explain (verbose, costs off)
select sum(c1%3), sum(distinct c1%3 order by c1%3) filter (where c1%3 < 2), c2 from ft1 where c2 = 6 group by c2;
--Testcase 207:
select sum(c1%3), sum(distinct c1%3 order by c1%3) filter (where c1%3 < 2), c2 from ft1 where c2 = 6 group by c2;

-- Outer query is aggregation query
--Testcase 208:
explain (verbose, costs off)
select distinct (select count(*) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
--Testcase 209:
select distinct (select count(*) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
-- Inner query is aggregation query
--Testcase 210:
explain (verbose, costs off)
select distinct (select count(t1.c1) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
--Testcase 211:
select distinct (select count(t1.c1) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;

-- Aggregate not pushed down as FILTER condition is not pushable
--Testcase 212:
explain (verbose, costs off)
select sum(c1) filter (where (c1 / c1) * random() <= 1) from ft1 group by c2 order by 1;
--Testcase 213:
explain (verbose, costs off)
select sum(c2) filter (where c2 in (select c2 from ft1 where c2 < 5)) from ft1;

-- Ordered-sets within aggregate
--Testcase 214:
explain (verbose, costs off)
select c2, rank('10'::varchar) within group (order by c6), percentile_cont(c2/10::numeric) within group (order by c1) from ft1 where c2 < 10 group by c2 having percentile_cont(c2/10::numeric) within group (order by c1) < 500 order by c2;
--Testcase 215:
select c2, rank('10'::varchar) within group (order by c6), percentile_cont(c2/10::numeric) within group (order by c1) from ft1 where c2 < 10 group by c2 having percentile_cont(c2/10::numeric) within group (order by c1) < 500 order by c2;

-- Using multiple arguments within aggregates
--Testcase 216:
explain (verbose, costs off)
select c1, rank(c1, c2) within group (order by c1, c2) from ft1 group by c1, c2 having c1 = 6 order by 1;
--Testcase 217:
select c1, rank(c1, c2) within group (order by c1, c2) from ft1 group by c1, c2 having c1 = 6 order by 1;

-- User defined function for user defined aggregate, VARIADIC
create function least_accum(anyelement, variadic anyarray)
returns anyelement language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';
create aggregate least_agg(variadic items anyarray) (
  stype = anyelement, sfunc = least_accum
);

-- Disable hash aggregation for plan stability.
set enable_hashagg to false;

-- Not pushed down due to user defined aggregate
--Testcase 218:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 group by c2 order by c2;

-- Add function and aggregate into extension
alter extension pgspider_core_fdw add function least_accum(anyelement, variadic anyarray);
alter extension pgspider_core_fdw add aggregate least_agg(variadic items anyarray);
alter server postgres_srv options (set extensions 'postgres_fdw');

-- Now aggregate will be pushed.  Aggregate will display VARIADIC argument.
--Testcase 219:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 where c2 < 100 group by c2 order by c2;
--Testcase 220:
select c2, least_agg(c1) from ft1 where c2 < 100 group by c2 order by c2;

-- Remove function and aggregate from extension
alter extension pgspider_core_fdw drop function least_accum(anyelement, variadic anyarray);
alter extension pgspider_core_fdw drop aggregate least_agg(variadic items anyarray);
alter server postgres_srv options (set extensions 'postgres_fdw');

-- Not pushed down as we have dropped objects from extension.
--Testcase 221:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 group by c2 order by c2;

-- Cleanup
reset enable_hashagg;
drop aggregate least_agg(variadic items anyarray);
drop function least_accum(anyelement, variadic anyarray);


-- Testing USING OPERATOR() in ORDER BY within aggregate.
-- For this, we need user defined operators along with operator family and
-- operator class.  Create those and then add them in extension.  Note that
-- user defined objects are considered unshippable unless they are part of
-- the extension.
create operator public.<^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4eq
);

create operator public.=^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4lt
);

create operator public.>^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4gt
);

create operator family my_op_family using btree;

create function my_op_cmp(a int, b int) returns int as
  $$begin return btint4cmp(a, b); end $$ language plpgsql;

create operator class my_op_class for type int using btree family my_op_family as
 operator 1 public.<^,
 operator 3 public.=^,
 operator 5 public.>^,
 function 1 my_op_cmp(int, int);

-- This will not be pushed as user defined sort operator is not part of the
-- extension yet.
--Testcase 222:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- Update local stats on ft2
ANALYZE ft2;

-- Add into extension
alter extension pgspider_core_fdw add operator class my_op_class using btree;
alter extension pgspider_core_fdw add function my_op_cmp(a int, b int);
alter extension pgspider_core_fdw add operator family my_op_family using btree;
alter extension pgspider_core_fdw add operator public.<^(int, int);
alter extension pgspider_core_fdw add operator public.=^(int, int);
alter extension pgspider_core_fdw add operator public.>^(int, int);
alter server postgres_srv options (set extensions 'postgres_fdw');

-- Now this will be pushed as sort operator is part of the extension.
--Testcase 223:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;
--Testcase 224:
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- Remove from extension
alter extension pgspider_core_fdw drop operator class my_op_class using btree;
alter extension pgspider_core_fdw drop function my_op_cmp(a int, b int);
alter extension pgspider_core_fdw drop operator family my_op_family using btree;
alter extension pgspider_core_fdw drop operator public.<^(int, int);
alter extension pgspider_core_fdw drop operator public.=^(int, int);
alter extension pgspider_core_fdw drop operator public.>^(int, int);
alter server postgres_srv options (set extensions 'postgres_fdw');

-- This will not be pushed as sort operator is now removed from the extension.
--Testcase 225:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- Cleanup
drop operator class my_op_class using btree;
drop function my_op_cmp(a int, b int);
drop operator family my_op_family using btree;
drop operator public.>^(int, int);
drop operator public.=^(int, int);
drop operator public.<^(int, int);

-- Input relation to aggregate push down hook is not safe to pushdown and thus
-- the aggregate cannot be pushed down to foreign server.
--Testcase 226:
explain (verbose, costs off)
select count(t1.c3) from ft2 t1 left join ft2 t2 on (t1.c1 = random() * t2.c2);

-- Subquery in FROM clause having aggregate
--Testcase 227:
explain (verbose, costs off)
select count(*), x.b from ft1, (select c2 a, sum(c1) b from ft1 group by c2) x where ft1.c2 = x.a group by x.b order by 1, 2;
--Testcase 228:
select count(*), x.b from ft1, (select c2 a, sum(c1) b from ft1 group by c2) x where ft1.c2 = x.a group by x.b order by 1, 2;

-- FULL join with IS NULL check in HAVING
--Testcase 229:
explain (verbose, costs off)
select avg(t1.c1), sum(t2.c1) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) group by t2.c1 having (avg(t1.c1) is null and sum(t2.c1) < 10) or sum(t2.c1) is null order by 1 nulls last, 2;
--Testcase 230:
select avg(t1.c1), sum(t2.c1) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) group by t2.c1 having (avg(t1.c1) is null and sum(t2.c1) < 10) or sum(t2.c1) is null order by 1 nulls last, 2;

-- Aggregate over FULL join needing to deparse the joining relations as
-- subqueries.
--Testcase 231:
explain (verbose, costs off)
select count(*), sum(t1.c1), avg(t2.c1) from (select c1 from ft4 where c1 between 50 and 60) t1 full join (select c1 from ft5 where c1 between 50 and 60) t2 on (t1.c1 = t2.c1);
--Testcase 232:
select count(*), sum(t1.c1), avg(t2.c1) from (select c1 from ft4 where c1 between 50 and 60) t1 full join (select c1 from ft5 where c1 between 50 and 60) t2 on (t1.c1 = t2.c1);

-- ORDER BY expression is part of the target list but not pushed down to
-- foreign server.
--Testcase 233:
explain (verbose, costs off)
select sum(c2) * (random() <= 1)::int as sum from ft1 order by 1;
--Testcase 234:
select sum(c2) * (random() <= 1)::int as sum from ft1 order by 1;

-- LATERAL join, with parameterization
set enable_hashagg to false;
--Testcase 235:
explain (verbose, costs off)
select c2, sum from "S 1"."T 1" t1, lateral (select sum(t2.c1 + t1."C 1") sum from ft2 t2 group by t2.c1) qry where t1.c2 * 2 = qry.sum and t1.c2 < 3 and t1."C 1" < 100 order by 1;
--Testcase 236:
select c2, sum from "S 1"."T 1" t1, lateral (select sum(t2.c1 + t1."C 1") sum from ft2 t2 group by t2.c1) qry where t1.c2 * 2 = qry.sum and t1.c2 < 3 and t1."C 1" < 100 order by 1;
reset enable_hashagg;

-- bug #15613: bad plan for foreign table scan with lateral reference
--Testcase 237:
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

--Testcase 238:
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
--Testcase 239:
explain (verbose, costs off)
select sum(q.a), count(q.b) from ft4 left join (select 13, avg(ft1.c1), sum(ft2.c1) from ft1 right join ft2 on (ft1.c1 = ft2.c1)) q(a, b, c) on (ft4.c1 <= q.b);
--Testcase 240:
select sum(q.a), count(q.b) from ft4 left join (select 13, avg(ft1.c1), sum(ft2.c1) from ft1 right join ft2 on (ft1.c1 = ft2.c1)) q(a, b, c) on (ft4.c1 <= q.b);


-- Not supported cases
-- Grouping sets
--Testcase 241:
explain (verbose, costs off)
select c2, sum(c1) from ft1 where c2 < 3 group by rollup(c2) order by 1 nulls last;
--Testcase 242:
select c2, sum(c1) from ft1 where c2 < 3 group by rollup(c2) order by 1 nulls last;
--Testcase 243:
explain (verbose, costs off)
select c2, sum(c1) from ft1 where c2 < 3 group by cube(c2) order by 1 nulls last;
--Testcase 244:
select c2, sum(c1) from ft1 where c2 < 3 group by cube(c2) order by 1 nulls last;
--Testcase 245:
explain (verbose, costs off)
select c2, c6, sum(c1) from ft1 where c2 < 3 group by grouping sets(c2, c6) order by 1 nulls last, 2 nulls last;
--Testcase 246:
select c2, c6, sum(c1) from ft1 where c2 < 3 group by grouping sets(c2, c6) order by 1 nulls last, 2 nulls last;
--Testcase 247:
explain (verbose, costs off)
select c2, sum(c1), grouping(c2) from ft1 where c2 < 3 group by c2 order by 1 nulls last;
--Testcase 248:
select c2, sum(c1), grouping(c2) from ft1 where c2 < 3 group by c2 order by 1 nulls last;

-- DISTINCT itself is not pushed down, whereas underneath aggregate is pushed
explain (verbose, costs off)
select distinct sum(c1)/1000 s from ft2 where c2 < 6 group by c2 order by 1;
select distinct sum(c1)/1000 s from ft2 where c2 < 6 group by c2 order by 1;

-- WindowAgg
--Testcase 249:
explain (verbose, costs off)
select c2, sum(c2), count(c2) over (partition by c2%2) from ft2 where c2 < 10 group by c2 order by 1;
--Testcase 250:
select c2, sum(c2), count(c2) over (partition by c2%2) from ft2 where c2 < 10 group by c2 order by 1;
--Testcase 251:
explain (verbose, costs off)
select c2, array_agg(c2) over (partition by c2%2 order by c2 desc) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 252:
select c2, array_agg(c2) over (partition by c2%2 order by c2 desc) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 253:
explain (verbose, costs off)
select c2, array_agg(c2) over (partition by c2%2 order by c2 range between current row and unbounded following) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 254:
select c2, array_agg(c2) over (partition by c2%2 order by c2 range between current row and unbounded following) from ft1 where c2 < 10 group by c2 order by 1;


-- ===================================================================
-- parameterized queries
-- ===================================================================
-- simple join
--Testcase 255:
PREPARE st1(int, int) AS SELECT t1.c3, t2.c3 FROM ft1 t1, ft2 t2 WHERE t1.c1 = $1 AND t2.c1 = $2;
--Testcase 256:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st1(1, 2);
--Testcase 257:
EXECUTE st1(1, 1);
--Testcase 258:
EXECUTE st1(101, 101);
-- subquery using stable function (can't be sent to remote)
--Testcase 259:
PREPARE st2(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 < $2 AND t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 > $1 AND date(c4) = '1970-01-17'::date) ORDER BY c1;
--Testcase 260:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st2(10, 20);
--Testcase 261:
EXECUTE st2(10, 20);
--Testcase 262:
EXECUTE st2(101, 121);
-- subquery using immutable function (can be sent to remote)
--Testcase 263:
PREPARE st3(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 < $2 AND t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 > $1 AND date(c5) = '1970-01-17'::date) ORDER BY c1;
--Testcase 264:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st3(10, 20);
--Testcase 265:
EXECUTE st3(10, 20);
--Testcase 266:
EXECUTE st3(20, 30);
-- custom plan should be chosen initially
--Testcase 267:
PREPARE st4(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 = $1;
--Testcase 268:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 269:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 270:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 271:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 272:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
-- once we try it enough times, should switch to generic plan
--Testcase 273:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
-- value of $1 should not be sent to remote
--Testcase 274:
PREPARE st5(user_enum,int) AS SELECT * FROM ft1 t1 WHERE c8 = $1 and c1 = $2;
--Testcase 275:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 276:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 277:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 278:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 279:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 280:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 281:
EXECUTE st5('foo', 1);

-- altering FDW options requires replanning
--Testcase 282:
PREPARE st6 AS SELECT * FROM ft1 t1 WHERE t1.c1 = t1.c2;
--Testcase 283:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st6;
--Testcase 284:
PREPARE st7 AS INSERT INTO ft1__postgres_srv__0 (c1,c2,c3) VALUES (1001,101,'foo');
--Testcase 285:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st7;
ALTER TABLE "S 1"."T 1" RENAME TO "T 0";
ALTER FOREIGN TABLE ft1__postgres_srv__0 OPTIONS (SET table_name 'T 0');
--Testcase 286:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st6;
--Testcase 287:
EXECUTE st6;
--Testcase 288:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st7;
ALTER TABLE "S 1"."T 0" RENAME TO "T 1";
ALTER FOREIGN TABLE ft1__postgres_srv__0 OPTIONS (SET table_name 'T 1');

--Testcase 289:
PREPARE st8 AS SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 290:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st8;
ALTER SERVER postgres_srv OPTIONS (DROP extensions);
--Testcase 291:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st8;
--Testcase 292:
EXECUTE st8;
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
--Testcase 293:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 t1 WHERE t1.tableoid = 'pg_class'::regclass LIMIT 1;
--Testcase 294:
SELECT * FROM ft1 t1 WHERE t1.tableoid = 'ft1'::regclass LIMIT 1;
--Testcase 295:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tableoid::regclass, * FROM ft1 t1 LIMIT 1;
--Testcase 296:
SELECT tableoid::regclass, * FROM ft1 t1 LIMIT 1;
--Testcase 297:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 t1 WHERE t1.ctid = '(0,2)';
--Testcase 298:
SELECT * FROM ft1 t1 WHERE t1.ctid = '(0,2)';
--Testcase 299:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ctid, * FROM ft1 t1 LIMIT 1;
--Testcase 300:
SELECT ctid, * FROM ft1 t1 LIMIT 1;

-- ===================================================================
-- used in PL/pgSQL function
-- ===================================================================
CREATE OR REPLACE FUNCTION f_test(p_c1 int) RETURNS int AS $$
DECLARE
	v_c1 int;
BEGIN
    SELECT c1 INTO v_c1 FROM ft1 WHERE c1 = p_c1 LIMIT 1;
    PERFORM c1 FROM ft1 WHERE c1 = p_c1 AND p_c1 = v_c1 LIMIT 1;
    RETURN v_c1;
END;
$$ LANGUAGE plpgsql;
--Testcase 301:
SELECT f_test(100);
DROP FUNCTION f_test(int);

-- ===================================================================
-- conversion error
-- ===================================================================
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE int;
ALTER FOREIGN TABLE ft1__postgres_srv__0 ALTER COLUMN c8 TYPE int;
SELECT * FROM ft1 WHERE c1 = 1;  -- ERROR
SELECT  ft1.c1,  ft2.c2, ft1.c8 FROM ft1, ft2 WHERE ft1.c1 = ft2.c1 AND ft1.c1 = 1; -- ERROR
SELECT  ft1.c1,  ft2.c2, ft1 FROM ft1, ft2 WHERE ft1.c1 = ft2.c1 AND ft1.c1 = 1; -- ERROR
SELECT sum(c2), array_agg(c8) FROM ft1 GROUP BY c8; -- ERROR
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE user_enum;
ALTER FOREIGN TABLE ft1__postgres_srv__0 ALTER COLUMN c8 TYPE user_enum;

-- ===================================================================
-- subtransaction
--  + local/remote error doesn't break cursor
-- ===================================================================
BEGIN;
DECLARE c CURSOR FOR SELECT * FROM ft1 ORDER BY c1;
--Testcase 302:
FETCH c;
SAVEPOINT s;
ERROR OUT;          -- ERROR
ROLLBACK TO s;
--Testcase 303:
FETCH c;
SAVEPOINT s;
--Testcase 304:
SELECT * FROM ft1 WHERE 1 / (c1 - 1) > 0;  -- ERROR
ROLLBACK TO s;
--Testcase 305:
FETCH c;
--Testcase 306:
SELECT * FROM ft1 ORDER BY c1 LIMIT 1;
COMMIT;

-- ===================================================================
-- test handling of collations
-- ===================================================================
create foreign table ft3 (f1 text collate "C", f2 text, f3 varchar(10), __spd_url text)
  server pgspider_srv;
create foreign table ft3__postgres_srv__0 (f1 text collate "C", f2 text, f3 varchar(10))
  server postgres_srv options (table_name 'loct3_1', use_remote_estimate 'true');

-- can be sent to remote
--Testcase 307:
explain (verbose, costs off) select * from ft3 where f1 = 'foo';
--Testcase 308:
explain (verbose, costs off) select * from ft3 where f1 COLLATE "C" = 'foo';
--Testcase 309:
explain (verbose, costs off) select * from ft3 where f2 = 'foo';
--Testcase 310:
explain (verbose, costs off) select * from ft3 where f3 = 'foo';
--Testcase 311:
explain (verbose, costs off) select * from ft3 f, ft3 l
  where f.f3 = l.f3 and l.f1 = 'foo';
-- can't be sent to remote
--Testcase 312:
explain (verbose, costs off) select * from ft3 where f1 COLLATE "POSIX" = 'foo';
--Testcase 313:
explain (verbose, costs off) select * from ft3 where f1 = 'foo' COLLATE "C";
--Testcase 314:
explain (verbose, costs off) select * from ft3 where f2 COLLATE "C" = 'foo';
--Testcase 315:
explain (verbose, costs off) select * from ft3 where f2 = 'foo' COLLATE "C";
--Testcase 316:
explain (verbose, costs off) select * from ft3 f, ft3 l
  where f.f3 = l.f3 COLLATE "POSIX" and l.f1 = 'foo';

-- ===================================================================
-- test writable foreign table stuff
-- ===================================================================
-- EXPLAIN (verbose, costs off)
-- INSERT INTO ft2 (c1,c2,c3) SELECT c1+1000,c2+100, c3 || c3 FROM ft2 LIMIT 20;
--Testcase 317:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3) SELECT c1+1000,c2+100, c3 || c3 FROM ft2 LIMIT 20;
-- INSERT INTO ft2 (c1,c2,c3)
--   VALUES (1101,201,'aaa'), (1102,202,'bbb'), (1103,203,'ccc') RETURNING *;
--Testcase 318:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3)
  VALUES (1101,201,'aaa'), (1102,202,'bbb'), (1103,203,'ccc') RETURNING *;
-- INSERT INTO ft2 (c1,c2,c3) VALUES (1104,204,'ddd'), (1105,205,'eee');
--Testcase 319:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3) VALUES (1104,204,'ddd'), (1105,205,'eee');
-- EXPLAIN (verbose, costs off)
-- UPDATE ft2 SET c2 = c2 + 300, c3 = c3 || '_update3' WHERE c1 % 10 = 3;              -- can be pushed down
--Testcase 320:
UPDATE ft2__postgres_srv__0 SET c2 = c2 + 300, c3 = c3 || '_update3' WHERE c1 % 10 = 3;
-- EXPLAIN (verbose, costs off)
-- UPDATE ft2 SET c2 = c2 + 400, c3 = c3 || '_update7' WHERE c1 % 10 = 7 RETURNING *;  -- can be pushed down
--Testcase 321:
UPDATE ft2__postgres_srv__0 SET c2 = c2 + 400, c3 = c3 || '_update7' WHERE c1 % 10 = 7 RETURNING *;
-- EXPLAIN (verbose, costs off)
-- UPDATE ft2 SET c2 = ft2.c2 + 500, c3 = ft2.c3 || '_update9', c7 = DEFAULT
--   FROM ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 9;                               -- can be pushed down
--Testcase 322:
UPDATE ft2__postgres_srv__0 SET c2 = ft2__postgres_srv__0.c2 + 500, c3 = ft2__postgres_srv__0.c3 || '_update9', c7 = DEFAULT
  FROM ft1 WHERE ft1.c1 = ft2__postgres_srv__0.c2 AND ft1.c1 % 10 = 9;
-- EXPLAIN (verbose, costs off)
--   DELETE FROM ft2 WHERE c1 % 10 = 5 RETURNING c1, c4;                               -- can be pushed down
--Testcase 323:
DELETE FROM ft2__postgres_srv__0 WHERE c1 % 10 = 5 RETURNING c1, c4;
-- EXPLAIN (verbose, costs off)
-- DELETE FROM ft2 USING ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 2;                -- can be pushed down
--Testcase 324:
DELETE FROM ft2__postgres_srv__0 USING ft1 WHERE ft1.c1 = ft2__postgres_srv__0.c2 AND ft1.c1 % 10 = 2;
--Testcase 325:
SELECT c1,c2,c3,c4 FROM ft2 ORDER BY c1;
-- EXPLAIN (verbose, costs off)
-- INSERT INTO ft2 (c1,c2,c3) VALUES (1200,999,'foo') RETURNING tableoid::regclass;
--Testcase 326:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3) VALUES (1200,999,'foo') RETURNING tableoid::regclass;
-- EXPLAIN (verbose, costs off)
-- UPDATE ft2 SET c3 = 'bar' WHERE c1 = 1200 RETURNING tableoid::regclass;             -- can be pushed down
--Testcase 327:
UPDATE ft2__postgres_srv__0 SET c3 = 'bar' WHERE c1 = 1200 RETURNING tableoid::regclass;
-- EXPLAIN (verbose, costs off)
-- DELETE FROM ft2 WHERE c1 = 1200 RETURNING tableoid::regclass;                       -- can be pushed down
--Testcase 328:
DELETE FROM ft2__postgres_srv__0 WHERE c1 = 1200 RETURNING tableoid::regclass;

-- Test UPDATE/DELETE with RETURNING on a three-table join
--Testcase 329:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3)
  SELECT id, id - 1200, to_char(id, 'FM00000') FROM generate_series(1201, 1300) id;
-- EXPLAIN (verbose, costs off)
-- UPDATE ft2 SET c3 = 'foo'
--   FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
--   WHERE ft2.c1 > 1200 AND ft2.c2 = ft4.c1
--   RETURNING ft2, ft2.*, ft4, ft4.*;       -- can be pushed down
--Testcase 330:
UPDATE ft2__postgres_srv__0 SET c3 = 'foo'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2__postgres_srv__0.c1 > 1200 AND ft2__postgres_srv__0.c2 = ft4.c1
  RETURNING ft2__postgres_srv__0, ft2__postgres_srv__0.*, ft4, ft4.*;
-- EXPLAIN (verbose, costs off)
-- DELETE FROM ft2
--   USING ft4 LEFT JOIN ft5 ON (ft4.c1 = ft5.c1)
--   WHERE ft2.c1 > 1200 AND ft2.c1 % 10 = 0 AND ft2.c2 = ft4.c1
--   RETURNING 100;                          -- can be pushed down
--Testcase 331:
DELETE FROM ft2__postgres_srv__0
  USING ft4 LEFT JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2__postgres_srv__0.c1 > 1200 AND ft2__postgres_srv__0.c1 % 10 = 0 AND ft2__postgres_srv__0.c2 = ft4.c1
  RETURNING 100;
-- DELETE FROM ft2 WHERE ft2.c1 > 1200;
--Testcase 332:
DELETE FROM ft2__postgres_srv__0 WHERE ft2__postgres_srv__0.c1 > 1200;

-- Test UPDATE with a MULTIEXPR sub-select
-- (maybe someday this'll be remotely executable, but not today)
--EXPLAIN (verbose, costs off)
--UPDATE ft2 AS target SET (c2, c7) = (
--    SELECT c2 * 10, c7
--        FROM ft2 AS src
--        WHERE target.c1 = src.c1
--) WHERE c1 > 1100;
UPDATE ft2__postgres_srv__0 AS target SET (c2, c7) = (
    SELECT c2 * 10, c7
        FROM ft2__postgres_srv__0 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;

UPDATE ft2__postgres_srv__0 AS target SET (c2) = (
    SELECT c2 / 10
        FROM ft2__postgres_srv__0 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;

-- Test UPDATE/DELETE with WHERE or JOIN/ON conditions containing
-- user-defined operators/functions
ALTER SERVER postgres_srv OPTIONS (DROP extensions);
--Testcase 333:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3)
  SELECT id, id % 10, to_char(id, 'FM00000') FROM generate_series(2001, 2010) id;
-- EXPLAIN (verbose, costs off)
-- UPDATE ft2 SET c3 = 'bar' WHERE postgres_fdw_abs(c1) > 2000 RETURNING *;            -- can't be pushed down
--Testcase 334:
UPDATE ft2__postgres_srv__0 SET c3 = 'bar' WHERE postgres_fdw_abs(c1) > 2000 RETURNING *;
-- EXPLAIN (verbose, costs off)
-- UPDATE ft2 SET c3 = 'baz'
--   FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
--   WHERE ft2.c1 > 2000 AND ft2.c2 === ft4.c1
--   RETURNING ft2.*, ft4.*, ft5.*;                                                    -- can't be pushed down
--Testcase 335:
UPDATE ft2__postgres_srv__0 SET c3 = 'baz'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2__postgres_srv__0.c1 > 2000 AND ft2__postgres_srv__0.c2 === ft4.c1
  RETURNING ft2__postgres_srv__0.*, ft4.*, ft5.*;
-- EXPLAIN (verbose, costs off)
-- DELETE FROM ft2
--   USING ft4 INNER JOIN ft5 ON (ft4.c1 === ft5.c1)
--   WHERE ft2.c1 > 2000 AND ft2.c2 = ft4.c1
--   RETURNING ft2.c1, ft2.c2, ft2.c3;       -- can't be pushed down
--Testcase 336:
DELETE FROM ft2__postgres_srv__0
  USING ft4 INNER JOIN ft5 ON (ft4.c1 === ft5.c1)
  WHERE ft2__postgres_srv__0.c1 > 2000 AND ft2__postgres_srv__0.c2 = ft4.c1
  RETURNING ft2__postgres_srv__0.c1, ft2__postgres_srv__0.c2, ft2__postgres_srv__0.c3;
-- DELETE FROM ft2 WHERE ft2.c1 > 2000;
--Testcase 337:
DELETE FROM ft2__postgres_srv__0 WHERE ft2__postgres_srv__0.c1 > 2000;
ALTER SERVER postgres_srv OPTIONS (ADD extensions 'postgres_fdw');

-- Test that trigger on remote table works as expected
CREATE OR REPLACE FUNCTION "S 1".F_BRTRIG() RETURNS trigger AS $$
BEGIN
    NEW.c3 = NEW.c3 || '_trig_update';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER t1_br_insert BEFORE INSERT OR UPDATE
    ON "S 1"."T 1" FOR EACH ROW EXECUTE PROCEDURE "S 1".F_BRTRIG();
--Testcase 338:
SELECT dblink_exec('CREATE TRIGGER t1_br_insert BEFORE INSERT OR UPDATE
    ON "S 1"."T 1" FOR EACH ROW EXECUTE PROCEDURE "S 1".F_BRTRIG();');

--Testcase 339:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3) VALUES (1208, 818, 'fff') RETURNING *;
--Testcase 340:
INSERT INTO ft2__postgres_srv__0 (c1,c2,c3,c6) VALUES (1218, 818, 'ggg', '(--;') RETURNING *;
--Testcase 341:
UPDATE ft2__postgres_srv__0 SET c2 = c2 + 600 WHERE c1 % 10 = 8 AND c1 < 1200 RETURNING *;

-- Test errors thrown on remote side during update
ALTER TABLE "S 1"."T 1" ADD CONSTRAINT c2positive CHECK (c2 >= 0);
--Testcase 342:
SELECT dblink_exec('ALTER TABLE "S 1"."T 1" ADD CONSTRAINT c2positive CHECK (c2 >= 0);');

--Testcase 343:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(11, 12);  -- duplicate key
--Testcase 344:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(11, 12) ON CONFLICT DO NOTHING; -- works
--Testcase 345:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(11, 12) ON CONFLICT (c1, c2) DO NOTHING; -- unsupported
--Testcase 346:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(11, 12) ON CONFLICT (c1, c2) DO UPDATE SET c3 = 'ffg'; -- unsupported
--Testcase 347:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(1111, -2);  -- c2positive
--Testcase 348:
UPDATE ft1__postgres_srv__0 SET c2 = -c2 WHERE c1 = 1;  -- c2positive

-- Test savepoint/rollback behavior
--Testcase 349:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
--Testcase 350:
select c2, count(*) from "S 1"."T 1" where c2 < 500 group by 1 order by 1;
begin;
--Testcase 351:
update ft2__postgres_srv__0 set c2 = 42 where c2 = 0;
-- in transation, data is temporally stored in foreign table, not pushed to remote database
--Testcase 352:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
savepoint s1;
--Testcase 353:
update ft2__postgres_srv__0 set c2 = 44 where c2 = 4;
--Testcase 354:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
release savepoint s1;
--Testcase 355:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
savepoint s2;
--Testcase 356:
update ft2__postgres_srv__0 set c2 = 46 where c2 = 6;
--Testcase 357:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
rollback to savepoint s2;
--Testcase 358:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
release savepoint s2;
--Testcase 359:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
savepoint s3;
--Testcase 360:
update ft2__postgres_srv__0 set c2 = -2 where c2 = 42 and c1 = 10; -- fail on remote side
rollback to savepoint s3;
--Testcase 361:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
release savepoint s3;
--Testcase 362:
select c2, count(*) from ft2__postgres_srv__0 where c2 < 500 group by 1 order by 1;
-- none of the above is committed yet remotely
--Testcase 363:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
commit;
--Testcase 364:
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
--Testcase 365:
select c2, count(*) from "S 1"."T 1" where c2 < 500 group by 1 order by 1;

VACUUM ANALYZE "S 1"."T 1";

-- Above DMLs add data with c6 as NULL in ft1, so test ORDER BY NULLS LAST and NULLs
-- FIRST behavior here.
-- ORDER BY DESC NULLS LAST options
--Testcase 366:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 DESC NULLS LAST, c1 OFFSET 795 LIMIT 10;
--Testcase 367:
SELECT * FROM ft1 ORDER BY c6 DESC NULLS LAST, c1 OFFSET 795  LIMIT 10;
-- ORDER BY DESC NULLS FIRST options
--Testcase 368:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 DESC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
--Testcase 369:
SELECT * FROM ft1 ORDER BY c6 DESC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
-- ORDER BY ASC NULLS FIRST options
--Testcase 370:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 ASC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
--Testcase 371:
SELECT * FROM ft1 ORDER BY c6 ASC NULLS FIRST, c1 OFFSET 15 LIMIT 10;

-- ===================================================================
-- test check constraints
-- ===================================================================

-- Consistent check constraints provide consistent results
ALTER FOREIGN TABLE ft1 ADD CONSTRAINT ft1_c2positive CHECK (c2 >= 0);
--Testcase 372:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 373:
SELECT count(*) FROM ft1 WHERE c2 < 0;
SET constraint_exclusion = 'on';
--Testcase 374:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 375:
SELECT count(*) FROM ft1 WHERE c2 < 0;
RESET constraint_exclusion;
-- check constraint is enforced on the remote side, not locally
--Testcase 376:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(1111, -2);  -- c2positive
--Testcase 377:
UPDATE ft1__postgres_srv__0 SET c2 = -c2 WHERE c1 = 1;  -- c2positive
ALTER FOREIGN TABLE ft1 DROP CONSTRAINT ft1_c2positive;

-- But inconsistent check constraints provide inconsistent results
ALTER FOREIGN TABLE ft1 ADD CONSTRAINT ft1_c2negative CHECK (c2 < 0);
--Testcase 378:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 379:
SELECT count(*) FROM ft1 WHERE c2 >= 0;
SET constraint_exclusion = 'on';
--Testcase 380:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 381:
SELECT count(*) FROM ft1 WHERE c2 >= 0;
RESET constraint_exclusion;
-- local check constraint is not actually enforced
--Testcase 382:
INSERT INTO ft1__postgres_srv__0(c1, c2) VALUES(1111, 2);
--Testcase 383:
UPDATE ft1__postgres_srv__0 SET c2 = c2 + 1 WHERE c1 = 1;
ALTER FOREIGN TABLE ft1 DROP CONSTRAINT ft1_c2negative;

-- ===================================================================
-- test WITH CHECK OPTION constraints
-- ===================================================================

CREATE FUNCTION row_before_insupd_trigfunc() RETURNS trigger AS $$BEGIN NEW.a := NEW.a + 10; RETURN NEW; END$$ LANGUAGE plpgsql;

--Testcase 384:
SELECT dblink_exec('CREATE TRIGGER row_before_insupd_trigger BEFORE INSERT OR UPDATE ON base_tbl
  FOR EACH ROW EXECUTE PROCEDURE row_before_insupd_trigfunc();');
CREATE FOREIGN TABLE foreign_tbl (a int, b int, __spd_url text)
  SERVER pgspider_srv;
CREATE FOREIGN TABLE foreign_tbl__postgres_srv__0 (a int, b int)
  SERVER postgres_srv OPTIONS(table_name 'base_tbl');
CREATE VIEW rw_view AS SELECT * FROM foreign_tbl
  WHERE a < b WITH CHECK OPTION;
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

DROP FOREIGN TABLE foreign_tbl CASCADE;
DROP FOREIGN TABLE foreign_tbl__postgres_srv__0 CASCADE;
--Testcase 385:
SELECT dblink_exec('DROP TRIGGER row_before_insupd_trigger ON base_tbl;');
--Testcase 386:
SELECT dblink_exec('DROP TABLE base_tbl;');

-- test WCO for partitions

--Testcase 387:
SELECT dblink_exec('CREATE TRIGGER row_before_insupd_trigger BEFORE INSERT OR UPDATE ON child_tbl FOR EACH ROW EXECUTE PROCEDURE row_before_insupd_trigfunc();');
CREATE FOREIGN TABLE foreign_tbl (a int, b int, __spd_url text)
  SERVER pgspider_srv;
CREATE FOREIGN TABLE foreign_tbl__postgres_srv__0 (a int, b int)
  SERVER postgres_srv OPTIONS(table_name 'child_tbl');

CREATE TABLE parent_tbl (a int, b int) PARTITION BY RANGE(a);
ALTER TABLE parent_tbl ATTACH PARTITION foreign_tbl FOR VALUES FROM (0) TO (100);

CREATE VIEW rw_view AS SELECT * FROM parent_tbl
  WHERE a < b WITH CHECK OPTION;
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

DROP FOREIGN TABLE foreign_tbl CASCADE;
DROP FOREIGN TABLE foreign_tbl__postgres_srv__0 CASCADE;
--Testcase 388:
SELECT dblink_exec('DROP TRIGGER row_before_insupd_trigger ON child_tbl;');
DROP TABLE parent_tbl CASCADE;;

DROP FUNCTION row_before_insupd_trigfunc;

-- ===================================================================
-- test serial columns (ie, sequence-based defaults)
-- ===================================================================
create foreign table rem1 (f1 serial, f2 text, __spd_url text)
  server pgspider_srv;
create foreign table rem1__postgres_srv__0 (f1 serial, f2 text)
  server postgres_srv options(table_name 'loc1_1');
--Testcase 389:
select pg_catalog.setval('rem1__postgres_srv__0_f1_seq', 10, false);
--Testcase 390:
select dblink_exec('insert into loc1_1(f2) values(''hi'');');
--Testcase 391:
insert into rem1__postgres_srv__0(f2) values('hi remote');
--Testcase 392:
select dblink_exec('insert into loc1_1(f2) values(''bye'');');
--Testcase 393:
insert into rem1__postgres_srv__0(f2) values('bye remote');
--Testcase 394:
select * from rem1;
--Testcase 395:
select * from rem1__postgres_srv__0;

-- ===================================================================
-- test generated columns
-- ===================================================================
create foreign table grem1 (
  a int,
  b int generated always as (a * 2) stored,
  __spd_url text)
  server pgspider_srv;
create foreign table grem1__postgres_srv__0 (
  a int,
  b int generated always as (a * 2) stored)
  server postgres_srv options(table_name 'gloc1');
--Testcase 396:
insert into grem1__postgres_srv__0 (a) values (1), (2);
--Testcase 397:
update grem1__postgres_srv__0 set a = 22 where a = 2;
--Testcase 398:
select * from grem1;

-- ===================================================================
-- test local triggers
-- ===================================================================

-- Trigger functions "borrowed" from triggers regress test.
CREATE FUNCTION trigger_func() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
	RAISE NOTICE 'trigger_func(%) called: action = %, when = %, level = %',
		TG_ARGV[0], TG_OP, TG_WHEN, TG_LEVEL;
	RETURN NULL;
END;$$;

CREATE TRIGGER trig_stmt_before BEFORE DELETE OR INSERT OR UPDATE ON rem1__postgres_srv__0
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
CREATE TRIGGER trig_stmt_after AFTER DELETE OR INSERT OR UPDATE ON rem1__postgres_srv__0
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();

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
CREATE TRIGGER trig_row_before
BEFORE INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

CREATE TRIGGER trig_row_after
AFTER INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 399:
delete from rem1__postgres_srv__0;
--Testcase 400:
insert into rem1__postgres_srv__0 values(1,'insert');
--Testcase 401:
update rem1__postgres_srv__0 set f2  = 'update' where f1 = 1;
--Testcase 402:
update rem1__postgres_srv__0 set f2 = f2 || f2;


-- cleanup
DROP TRIGGER trig_row_before ON rem1__postgres_srv__0;
DROP TRIGGER trig_row_after ON rem1__postgres_srv__0;
DROP TRIGGER trig_stmt_before ON rem1__postgres_srv__0;
DROP TRIGGER trig_stmt_after ON rem1__postgres_srv__0;

--Testcase 403:
DELETE from rem1__postgres_srv__0;

-- Test multiple AFTER ROW triggers on a foreign table
CREATE TRIGGER trig_row_after1
AFTER INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

CREATE TRIGGER trig_row_after2
AFTER INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

insert into rem1__postgres_srv__0 values(1,'insert');
update rem1__postgres_srv__0 set f2  = 'update' where f1 = 1;
update rem1__postgres_srv__0 set f2 = f2 || f2;
delete from rem1__postgres_srv__0;

-- cleanup
DROP TRIGGER trig_row_after1 ON rem1__postgres_srv__0;
DROP TRIGGER trig_row_after2 ON rem1__postgres_srv__0;

-- Test WHEN conditions

CREATE TRIGGER trig_row_before_insupd
BEFORE INSERT OR UPDATE ON rem1__postgres_srv__0
FOR EACH ROW
WHEN (NEW.f2 like '%update%')
--Testcase 404:
EXECUTE PROCEDURE trigger_data(23,'skidoo');

CREATE TRIGGER trig_row_after_insupd
AFTER INSERT OR UPDATE ON rem1__postgres_srv__0
FOR EACH ROW
WHEN (NEW.f2 like '%update%')
--Testcase 405:
EXECUTE PROCEDURE trigger_data(23,'skidoo');

-- Insert or update not matching: nothing happens
--Testcase 406:
INSERT INTO rem1__postgres_srv__0 values(1, 'insert');
--Testcase 407:
UPDATE rem1__postgres_srv__0 set f2 = 'test';

-- Insert or update matching: triggers are fired
--Testcase 408:
INSERT INTO rem1__postgres_srv__0 values(2, 'update');
--Testcase 409:
UPDATE rem1__postgres_srv__0 set f2 = 'update update' where f1 = '2';

CREATE TRIGGER trig_row_before_delete
BEFORE DELETE ON rem1__postgres_srv__0
FOR EACH ROW
WHEN (OLD.f2 like '%update%')
--Testcase 410:
EXECUTE PROCEDURE trigger_data(23,'skidoo');

CREATE TRIGGER trig_row_after_delete
AFTER DELETE ON rem1__postgres_srv__0
FOR EACH ROW
WHEN (OLD.f2 like '%update%')
--Testcase 411:
EXECUTE PROCEDURE trigger_data(23,'skidoo');

-- Trigger is fired for f1=2, not for f1=1
--Testcase 412:
DELETE FROM rem1__postgres_srv__0;

-- cleanup
DROP TRIGGER trig_row_before_insupd ON rem1__postgres_srv__0;
DROP TRIGGER trig_row_after_insupd ON rem1__postgres_srv__0;
DROP TRIGGER trig_row_before_delete ON rem1__postgres_srv__0;
DROP TRIGGER trig_row_after_delete ON rem1__postgres_srv__0;


-- Test various RETURN statements in BEFORE triggers.

CREATE FUNCTION trig_row_before_insupdate() RETURNS TRIGGER AS $$
  BEGIN
    NEW.f2 := NEW.f2 || ' triggered !';
    RETURN NEW;
  END
$$ language plpgsql;

CREATE TRIGGER trig_row_before_insupd
BEFORE INSERT OR UPDATE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

-- The new values should have 'triggered' appended
--Testcase 413:
INSERT INTO rem1__postgres_srv__0 values(1, 'insert');
--Testcase 414:
SELECT * from rem1;
--Testcase 415:
INSERT INTO rem1__postgres_srv__0 values(2, 'insert') RETURNING f2;
--Testcase 416:
SELECT * from rem1;
--Testcase 417:
UPDATE rem1__postgres_srv__0 set f2 = '';
--Testcase 418:
SELECT * from rem1;
--Testcase 419:
UPDATE rem1__postgres_srv__0 set f2 = 'skidoo' RETURNING f2;
--Testcase 420:
SELECT * from rem1;

--Testcase 421:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f1 = 10;          -- all columns should be transmitted
--Testcase 422:
UPDATE rem1__postgres_srv__0 set f1 = 10;
--Testcase 423:
SELECT * from rem1;

--Testcase 424:
DELETE FROM rem1__postgres_srv__0;

-- Add a second trigger, to check that the changes are propagated correctly
-- from trigger to trigger
CREATE TRIGGER trig_row_before_insupd2
BEFORE INSERT OR UPDATE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

--Testcase 425:
INSERT INTO rem1__postgres_srv__0 values(1, 'insert');
--Testcase 426:
SELECT * from rem1;
--Testcase 427:
INSERT INTO rem1__postgres_srv__0 values(2, 'insert') RETURNING f2;
--Testcase 428:
SELECT * from rem1;
--Testcase 429:
UPDATE rem1__postgres_srv__0 set f2 = '';
--Testcase 430:
SELECT * from rem1;
--Testcase 431:
UPDATE rem1__postgres_srv__0 set f2 = 'skidoo' RETURNING f2;
--Testcase 432:
SELECT * from rem1;

DROP TRIGGER trig_row_before_insupd ON rem1__postgres_srv__0;
DROP TRIGGER trig_row_before_insupd2 ON rem1__postgres_srv__0;

--Testcase 433:
DELETE from rem1__postgres_srv__0;

--Testcase 434:
INSERT INTO rem1__postgres_srv__0 VALUES (1, 'test');

-- Test with a trigger returning NULL
CREATE FUNCTION trig_null() RETURNS TRIGGER AS $$
  BEGIN
    RETURN NULL;
  END
$$ language plpgsql;

CREATE TRIGGER trig_null
BEFORE INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trig_null();

-- Nothing should have changed.
--Testcase 435:
INSERT INTO rem1__postgres_srv__0 VALUES (2, 'test2');

--Testcase 436:
SELECT * from rem1;

--Testcase 437:
UPDATE rem1__postgres_srv__0 SET f2 = 'test2';

--Testcase 438:
SELECT * from rem1;

--Testcase 439:
DELETE from rem1__postgres_srv__0;

--Testcase 440:
SELECT * from rem1;

DROP TRIGGER trig_null ON rem1__postgres_srv__0;
--Testcase 441:
DELETE from rem1__postgres_srv__0;

-- Test a combination of local and remote triggers
CREATE TRIGGER trig_row_before
BEFORE INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

CREATE TRIGGER trig_row_after
AFTER INSERT OR UPDATE OR DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

CREATE TRIGGER trig_local_before BEFORE INSERT OR UPDATE ON rem1
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

--Testcase 442:
INSERT INTO rem1__postgres_srv__0(f2) VALUES ('test');
--Testcase 443:
UPDATE rem1__postgres_srv__0 SET f2 = 'testo';

-- Test returning a system attribute
--Testcase 444:
INSERT INTO rem1__postgres_srv__0(f2) VALUES ('test') RETURNING ctid;

-- cleanup
DROP TRIGGER trig_row_before ON rem1__postgres_srv__0;
DROP TRIGGER trig_row_after ON rem1__postgres_srv__0;
DROP TRIGGER trig_local_before ON rem1__postgres_srv__0;


-- Test direct foreign table modification functionality

-- Test with statement-level triggers
CREATE TRIGGER trig_stmt_before
	BEFORE DELETE OR INSERT OR UPDATE ON rem1__postgres_srv__0
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 445:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can be pushed down
--Testcase 446:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
DROP TRIGGER trig_stmt_before ON rem1__postgres_srv__0;

CREATE TRIGGER trig_stmt_after
	AFTER DELETE OR INSERT OR UPDATE ON rem1__postgres_srv__0
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 447:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can be pushed down
--Testcase 448:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
DROP TRIGGER trig_stmt_after ON rem1__postgres_srv__0;

-- Test with row-level ON INSERT triggers
CREATE TRIGGER trig_row_before_insert
BEFORE INSERT ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 449:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can be pushed down
--Testcase 450:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
DROP TRIGGER trig_row_before_insert ON rem1__postgres_srv__0;

CREATE TRIGGER trig_row_after_insert
AFTER INSERT ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 451:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can be pushed down
--Testcase 452:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
DROP TRIGGER trig_row_after_insert ON rem1__postgres_srv__0;

-- Test with row-level ON UPDATE triggers
CREATE TRIGGER trig_row_before_update
BEFORE UPDATE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 453:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can't be pushed down
--Testcase 454:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
DROP TRIGGER trig_row_before_update ON rem1__postgres_srv__0;

CREATE TRIGGER trig_row_after_update
AFTER UPDATE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 455:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can't be pushed down
--Testcase 456:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can be pushed down
DROP TRIGGER trig_row_after_update ON rem1__postgres_srv__0;

-- Test with row-level ON DELETE triggers
CREATE TRIGGER trig_row_before_delete
BEFORE DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 457:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can be pushed down
--Testcase 458:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can't be pushed down
DROP TRIGGER trig_row_before_delete ON rem1__postgres_srv__0;

CREATE TRIGGER trig_row_after_delete
AFTER DELETE ON rem1__postgres_srv__0
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 459:
EXPLAIN (verbose, costs off)
UPDATE rem1__postgres_srv__0 set f2 = '';          -- can be pushed down
--Testcase 460:
EXPLAIN (verbose, costs off)
DELETE FROM rem1__postgres_srv__0;                 -- can't be pushed down
DROP TRIGGER trig_row_after_delete ON rem1__postgres_srv__0;

-- ===================================================================
-- test inheritance features
-- ===================================================================

CREATE TABLE a (aa TEXT);
CREATE FOREIGN TABLE b (aa TEXT, bb TEXT, __spd_url TEXT)
  SERVER pgspider_srv;
CREATE FOREIGN TABLE b__postgres_srv__0 (bb TEXT) INHERITS (a)
  SERVER postgres_srv OPTIONS (table_name 'loct_1');

--Testcase 461:
INSERT INTO a(aa) VALUES('aaa');
--Testcase 462:
INSERT INTO a(aa) VALUES('aaaa');
--Testcase 463:
INSERT INTO a(aa) VALUES('aaaaa');

--Testcase 464:
INSERT INTO b__postgres_srv__0(aa) VALUES('bbb');
--Testcase 465:
INSERT INTO b__postgres_srv__0(aa) VALUES('bbbb');
--Testcase 466:
INSERT INTO b__postgres_srv__0(aa) VALUES('bbbbb');

--Testcase 467:
SELECT tableoid::regclass, * FROM a;
--Testcase 468:
SELECT tableoid::regclass, * FROM b;
--Testcase 469:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 470:
UPDATE a SET aa = 'zzzzzz' WHERE aa LIKE 'aaaa%';

--Testcase 471:
SELECT tableoid::regclass, * FROM a;
--Testcase 472:
SELECT tableoid::regclass, * FROM b;
--Testcase 473:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 474:
UPDATE b__postgres_srv__0 SET aa = 'new';

--Testcase 475:
SELECT tableoid::regclass, * FROM a;
--Testcase 476:
SELECT tableoid::regclass, * FROM b;
--Testcase 477:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 478:
UPDATE a SET aa = 'newtoo';

--Testcase 479:
SELECT tableoid::regclass, * FROM a;
--Testcase 480:
SELECT tableoid::regclass, * FROM b;
--Testcase 481:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 482:
DELETE FROM a;

--Testcase 483:
SELECT tableoid::regclass, * FROM a;
--Testcase 484:
SELECT tableoid::regclass, * FROM b;
--Testcase 485:
SELECT tableoid::regclass, * FROM ONLY a;

DROP TABLE a CASCADE;
DROP FOREIGN TABLE b CASCADE;

-- Check SELECT FOR UPDATE/SHARE with an inherited source table
create table foo (f1 int, f2 int);
create foreign table foo2 (f1 int, f2 int, f3 int, __spd_url text)
  server pgspider_srv;
create foreign table foo2__postgres_srv__0 (f3 int) inherits (foo)
  server postgres_srv options (table_name 'loct1_1');

create table bar (f1 int, f2 int);
create foreign table bar2 (f1 int, f2 int, f3 int, __spd_url text)
  server pgspider_srv;
create foreign table bar2__postgres_srv__0 (f3 int) inherits (bar)
  server postgres_srv options (table_name 'loct2_1');

alter table foo set (autovacuum_enabled = 'false');
alter table bar set (autovacuum_enabled = 'false');

--Testcase 486:
insert into foo values(1,1);
--Testcase 487:
insert into foo values(3,3);
--Testcase 488:
insert into foo2__postgres_srv__0 values(2,2,2);
--Testcase 489:
insert into foo2__postgres_srv__0 values(4,4,4);
--Testcase 490:
insert into bar values(1,11);
--Testcase 491:
insert into bar values(2,22);
--Testcase 492:
insert into bar values(6,66);
--Testcase 493:
insert into bar2__postgres_srv__0 values(3,33,33);
--Testcase 494:
insert into bar2__postgres_srv__0 values(4,44,44);
--Testcase 495:
insert into bar2__postgres_srv__0 values(7,77,77);

--Testcase 496:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo) for update;
--Testcase 497:
select * from bar where f1 in (select f1 from foo) for update;

--Testcase 498:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo) for share;
--Testcase 499:
select * from bar where f1 in (select f1 from foo) for share;

-- Check UPDATE with inherited target and an inherited source table
--Testcase 500:
explain (verbose, costs off)
update bar set f2 = f2 + 100 where f1 in (select f1 from foo);
--Testcase 501:
update bar set f2 = f2 + 100 where f1 in (select f1 from foo);

--Testcase 502:
select tableoid::regclass, * from bar order by 1,2;

-- Check UPDATE with inherited target and an appendrel subquery
--Testcase 503:
explain (verbose, costs off)
update bar set f2 = f2 + 100
from
  ( select f1 from foo union all select f1+3 from foo ) ss
where bar.f1 = ss.f1;
--Testcase 504:
update bar set f2 = f2 + 100
from
  ( select f1 from foo union all select f1+3 from foo ) ss
where bar.f1 = ss.f1;

--Testcase 505:
select tableoid::regclass, * from bar order by 1,2;

-- Test forcing the remote server to produce sorted data for a merge join,
-- but the foreign table is an inheritance child.
--Testcase 506:
delete from foo2__postgres_srv__0;
truncate table only foo;
\set num_rows_foo 2000
--Testcase 507:
insert into foo2__postgres_srv__0 select generate_series(0, :num_rows_foo, 2), generate_series(0, :num_rows_foo, 2), generate_series(0, :num_rows_foo, 2);
--Testcase 508:
insert into foo select generate_series(1, :num_rows_foo, 2), generate_series(1, :num_rows_foo, 2);
SET enable_hashjoin to false;
SET enable_nestloop to false;
alter foreign table foo2 options (use_remote_estimate 'true');
analyze foo;
-- inner join; expressions in the clauses appear in the equivalence class list
--Testcase 509:
explain (verbose, costs off)
	select foo.f1, foo2.f1 from foo join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
--Testcase 510:
select foo.f1, foo2.f1 from foo join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
-- outer join; expressions in the clauses do not appear in equivalence class
-- list but no output change as compared to the previous query
--Testcase 511:
explain (verbose, costs off)
	select foo.f1, foo2.f1 from foo left join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
--Testcase 512:
select foo.f1, foo2.f1 from foo left join foo2 on (foo.f1 = foo2.f1) order by foo.f2 offset 10 limit 10;
RESET enable_hashjoin;
RESET enable_nestloop;

-- Test that WHERE CURRENT OF is not supported
begin;
declare c cursor for select * from bar where f1 = 7;
--Testcase 513:
fetch from c;
--Testcase 514:
update bar set f2 = null where current of c;
rollback;

--Testcase 515:
explain (verbose, costs off)
delete from foo where f1 < 5 returning *;
--Testcase 516:
delete from foo where f1 < 5 returning *;
--Testcase 517:
explain (verbose, costs off)
update bar set f2 = f2 + 100 returning *;
--Testcase 518:
update bar set f2 = f2 + 100 returning *;

-- Test that UPDATE/DELETE with inherited target works with row-level triggers
CREATE TRIGGER trig_row_before
BEFORE UPDATE OR DELETE ON bar2
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

CREATE TRIGGER trig_row_after
AFTER UPDATE OR DELETE ON bar2
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 519:
explain (verbose, costs off)
update bar set f2 = f2 + 100;
--Testcase 520:
update bar set f2 = f2 + 100;

--Testcase 521:
explain (verbose, costs off)
delete from bar where f2 < 400;
--Testcase 522:
delete from bar where f2 < 400;

-- cleanup
drop foreign table foo2 cascade;
drop foreign table bar2 cascade;

-- Test pushing down UPDATE/DELETE joins to the remote server
create table parent (a int, b text);
create foreign table remt1 (a int, b text, __spd_url text)
  server pgspider_srv;
create foreign table remt1__postgres_srv__0 (a int, b text)
  server postgres_srv options (table_name 'loct1_2');
create foreign table remt2 (a int, b text, __spd_url text)
  server pgspider_srv;
create foreign table remt2__postgres_srv__0 (a int, b text)
  server postgres_srv options (table_name 'loct2_2');
alter foreign table remt1__postgres_srv__0 inherit parent;
--alter foreign table remt1__postgres_srv__0 inherit parent__postgres_srv__0;

--Testcase 523:
insert into remt1__postgres_srv__0 values (1, 'foo');
--Testcase 524:
insert into remt1__postgres_srv__0 values (2, 'bar');
--Testcase 525:
insert into remt2__postgres_srv__0 values (1, 'foo');
--Testcase 526:
insert into remt2__postgres_srv__0 values (2, 'bar');

--analyze remt1;
--analyze remt2;

--Testcase 527:
explain (verbose, costs off)
update parent set b = parent.b || remt2.b from remt2 where parent.a = remt2.a returning *;
--Testcase 528:
update parent set b = parent.b || remt2.b from remt2 where parent.a = remt2.a returning *;
--Testcase 529:
explain (verbose, costs off)
delete from parent using remt2 where parent.a = remt2.a returning parent;
--Testcase 530:
delete from parent using remt2 where parent.a = remt2.a returning parent;

-- cleanup
drop foreign table remt1;
drop foreign table remt2;
drop foreign table remt1__postgres_srv__0;
drop foreign table remt2__postgres_srv__0;
drop table parent;

-- ===================================================================
-- test tuple routing for foreign-table partitions
-- ===================================================================

-- Test insert tuple routing
create foreign table itrtest (a int, b text, __spd_url text)
  server pgspider_srv;
create foreign table itrtest__postgres_srv__0 (a int, b text)
  server postgres_srv options (table_name 'itrtest');
--Testcase 531:
SELECT dblink_exec('create foreign table remp1 
  (a int check (a in (1)), b text) server postgres_srv 
  options (table_name ''loct1_3'');');

create foreign table remp1 (a int check (a in (1)), b text, __spd_url text) 
  server pgspider_srv;
create foreign table remp1__postgres_srv__0 (a int check (a in (1)), b text) 
  server postgres_srv options (table_name 'remp1');
--Testcase 532:
SELECT dblink_exec('create foreign table remp2 
  (b text, a int check (a in (2))) server postgres_srv
   options (table_name ''loct2_3'');');

create foreign table remp2 (b text, a int check (a in (2)), __spd_url text) 
  server pgspider_srv;
create foreign table remp2__postgres_srv__0 (b text, a int check (a in (2))) 
  server postgres_srv options (table_name 'remp2');

-- Does not support attach partition on foreign table
--Testcase 533:
SELECT dblink_exec('alter table itrtest attach partition remp1 for values in (1);');
--Testcase 534:
SELECT dblink_exec('alter table itrtest attach partition remp2 for values in (2);');

--Testcase 535:
insert into itrtest__postgres_srv__0 values (1, 'foo');
--Testcase 536:
insert into itrtest__postgres_srv__0 values (1, 'bar') returning *;
--Testcase 537:
insert into itrtest__postgres_srv__0 values (2, 'baz');
--Testcase 538:
insert into itrtest__postgres_srv__0 values (2, 'qux') returning *;
--Testcase 539:
insert into itrtest__postgres_srv__0 values (1, 'test1'), (2, 'test2') returning *;

--Testcase 540:
select tableoid::regclass, * FROM itrtest;
--Testcase 541:
select tableoid::regclass, * FROM remp1;
--Testcase 542:
select tableoid::regclass, * FROM remp2;

--Testcase 543:
delete from itrtest__postgres_srv__0;

--Testcase 544:
SELECT dblink_exec('create unique index loct1_idx on loct1_3 (a);');

-- DO NOTHING without an inference specification is supported
--Testcase 545:
insert into itrtest__postgres_srv__0 values (1, 'foo') on conflict do nothing returning *;
--Testcase 546:
insert into itrtest__postgres_srv__0 values (1, 'foo') on conflict do nothing returning *;

-- But other cases are not supported
--Testcase 547:
insert into itrtest__postgres_srv__0 values (1, 'bar') on conflict (a) do nothing;
--Testcase 548:
insert into itrtest__postgres_srv__0 values (1, 'bar') on conflict (a) do update set b = excluded.b;

--Testcase 549:
select tableoid::regclass, * FROM itrtest;

-- delete from itrtest;
--Testcase 550:
delete from itrtest__postgres_srv__0;

--Testcase 551:
SELECT dblink_exec('drop index loct1_idx;');

-- Test that remote triggers work with insert tuple routing
create function br_insert_trigfunc() returns trigger as $$
begin
	new.b := new.b || ' triggered !';
	return new;
end
$$ language plpgsql;
--Testcase 552:
SELECT dblink_exec('create trigger loct1_br_insert_trigger before insert on loct1_3
        for each row execute procedure br_insert_trigfunc();');
--Testcase 553:
SELECT dblink_exec('create trigger loct2_br_insert_trigger before insert on loct2_3
	for each row execute procedure br_insert_trigfunc();');
-- The new values are concatenated with ' triggered !'
--Testcase 554:
insert into itrtest__postgres_srv__0 values (1, 'foo') returning *;
--Testcase 555:
insert into itrtest__postgres_srv__0 values (2, 'qux') returning *;
--Testcase 556:
insert into itrtest__postgres_srv__0 values (1, 'test1'), (2, 'test2') returning *;
with result as (insert into itrtest__postgres_srv__0 values (1, 'test1'), (2, 'test2') returning *) select * from result;

--Testcase 557:
SELECT dblink_exec('drop trigger loct1_br_insert_trigger on loct1_3;');
--Testcase 558:
SELECT dblink_exec('drop trigger loct2_br_insert_trigger on loct2_3;');

drop foreign table remp1;
drop foreign table remp2;
drop foreign table remp1__postgres_srv__0;
drop foreign table remp2__postgres_srv__0;
drop foreign table itrtest;
drop foreign table itrtest__postgres_srv__0;

-- Test update tuple routing
create foreign table utrtest (a int, b text)
  server pgspider_srv;
create foreign table utrtest__postgres_srv__0 (a int, b text)
  server postgres_srv options (table_name 'utrtest');
--Testcase 559:
SELECT dblink_exec('create foreign table remp 
  (a int check (a in (1)), b text) 
  server postgres_srv options (table_name ''loct_2'');');

create foreign table remp (a int check (a in (1)), b text, __spd_url text)
  server pgspider_srv;
create foreign table remp__postgres_srv__0 (a int check (a in (1)), b text)
  server postgres_srv options (table_name 'remp');

create foreign table locp (a int check (a in (2)), b text, __spd_url text)
  server pgspider_srv;
create foreign table locp__postgres_srv__0 (a int check (a in (2)), b text)
  server postgres_srv options (table_name 'locp_2');
--Testcase 560:
SELECT dblink_exec('alter table utrtest attach partition remp for values in (1);');
--Testcase 561:
SELECT dblink_exec('alter table utrtest attach partition locp_2 for values in (2);');

--Testcase 562:
insert into utrtest__postgres_srv__0 values (1, 'foo');
--Testcase 563:
insert into utrtest__postgres_srv__0 values (2, 'qux');

--Testcase 564:
select tableoid::regclass, * FROM utrtest;
--Testcase 565:
select tableoid::regclass, * FROM remp;
--Testcase 566:
select tableoid::regclass, * FROM locp;

-- It's not allowed to move a row from a partition that is foreign to another
--Testcase 567:
update utrtest__postgres_srv__0 set a = 2 where b = 'foo' returning *;

-- But the reverse is allowed
--Testcase 568:
update utrtest__postgres_srv__0 set a = 1 where b = 'qux' returning *;

--Testcase 569:
select tableoid::regclass, * FROM utrtest;
--Testcase 570:
select tableoid::regclass, * FROM remp;
--Testcase 571:
select tableoid::regclass, * FROM locp;

-- The executor should not let unexercised FDWs shut down
--Testcase 572:
update utrtest__postgres_srv__0 set a = 1 where b = 'foo';

-- Test that remote triggers work with update tuple routing
--Testcase 573:
SELECT dblink_exec('create trigger loct_br_insert_trigger before insert on loct_2
	for each row execute procedure br_insert_trigfunc();');

--Testcase 574:
delete from utrtest__postgres_srv__0;
--Testcase 575:
insert into utrtest__postgres_srv__0 values (2, 'qux');

-- Check case where the foreign partition is a subplan target rel
-- explain (verbose, costs off)
-- update utrtest set a = 1 where a = 1 or a = 2 returning *;
-- The new values are concatenated with ' triggered !'
--Testcase 576:
update utrtest__postgres_srv__0 set a = 1 where a = 1 or a = 2 returning *;

--Testcase 577:
delete from utrtest__postgres_srv__0;
--Testcase 578:
insert into utrtest__postgres_srv__0 values (2, 'qux');

-- Check case where the foreign partition isn't a subplan target rel
-- explain (verbose, costs off)
-- update utrtest set a = 1 where a = 2 returning *;
-- The new values are concatenated with ' triggered !'
--Testcase 579:
update utrtest__postgres_srv__0 set a = 1 where a = 2 returning *;

--Testcase 580:
SELECT dblink_exec('drop trigger loct_br_insert_trigger on loct_2;');

-- We can move rows to a foreign partition that has been updated already,
-- but can't move rows to a foreign partition that hasn't been updated yet

--Testcase 581:
delete from utrtest__postgres_srv__0;
--Testcase 582:
insert into utrtest__postgres_srv__0 values (1, 'foo');
--Testcase 583:
insert into utrtest__postgres_srv__0 values (2, 'qux');

-- Test the former case:
-- with a direct modification plan
-- explain (verbose, costs off)
-- update utrtest set a = 1 returning *;
--Testcase 584:
update utrtest__postgres_srv__0 set a = 1 returning *;

--Testcase 585:
delete from utrtest__postgres_srv__0;
--Testcase 586:
insert into utrtest__postgres_srv__0 values (1, 'foo');
--Testcase 587:
insert into utrtest__postgres_srv__0 values (2, 'qux');

-- with a non-direct modification plan
-- explain (verbose, costs off)
-- update utrtest set a = 1 from (values (1), (2)) s(x) where a = s.x returning *;
--Testcase 588:
update utrtest__postgres_srv__0 set a = 1 from (values (1), (2)) s(x) where a = s.x returning *;

-- Change the definition of utrtest so that the foreign partition get updated
-- after the local partition
--Testcase 589:
delete from utrtest__postgres_srv__0;
--Testcase 590:
SELECT dblink_exec('alter table utrtest detach partition remp;');
--Testcase 591:
SELECT dblink_exec('drop foreign table remp;');
drop foreign table remp;
drop foreign table remp__postgres_srv__0;
--Testcase 592:
SELECT dblink_exec('alter table loct_2 drop constraint loct_2_a_check;');
--Testcase 593:
SELECT dblink_exec('alter table loct_2 add check (a in (3));');
--Testcase 594:
SELECT dblink_exec('create foreign table remp (a int check (a in (3)), b text) 
  server postgres_srv options (table_name ''loct_2'');');
--Testcase 595:
SELECT dblink_exec('alter table utrtest attach partition remp for values in (3);');

--Testcase 596:
insert into utrtest__postgres_srv__0 values (2, 'qux');
--Testcase 597:
insert into utrtest__postgres_srv__0 values (3, 'xyzzy');

-- Test the latter case:
-- with a direct modification plan
-- explain (verbose, costs off)
-- update utrtest set a = 3 returning *;
--Testcase 598:
update utrtest__postgres_srv__0 set a = 3 returning *; -- ERROR

-- -- with a non-direct modification plan
-- explain (verbose, costs off)
-- update utrtest set a = 3 from (values (2), (3)) s(x) where a = s.x returning *;
--Testcase 599:
update utrtest__postgres_srv__0 set a = 3 from (values (2), (3)) s(x) where a = s.x returning *; -- ERROR

drop foreign table utrtest;
drop foreign table utrtest__postgres_srv__0;
--drop table loct;

-- Test copy tuple routing
---create table ctrtest (a int, b text, __spd_url text) partition by list (a);
---create table loct1 (a int check (a in (1)), b text);
create foreign table ctrtest (a int, b text, __spd_url text)
  server pgspider_srv;
create foreign table ctrtest__postgres_srv__0 (a int, b text)
  server postgres_srv options (table_name 'ctrtest');
create foreign table remp1 (a int check (a in (1)), b text, __spd_url text)
  server pgspider_srv;
create foreign table remp1__postgres_srv__0 (a int check (a in (1)), b text)
  server postgres_srv options (table_name 'loct1_4');
create foreign table remp2 (b text, a int check (a in (2)), __spd_url text)
  server pgspider_srv;
create foreign table remp2__postgres_srv__0 (b text, a int check (a in (2)))
  server postgres_srv options (table_name 'loct2_4');
--alter table ctrtest attach partition remp1 for values in (1);
--alter table ctrtest attach partition remp2 for values in (2);

copy ctrtest__postgres_srv__0 from stdin;
1	foo
2	qux
\.

--Testcase 600:
select tableoid::regclass, * FROM ctrtest;
--Testcase 601:
select tableoid::regclass, * FROM remp1;
--Testcase 602:
select tableoid::regclass, * FROM remp2;

-- Copying into foreign partitions directly should work as well
copy remp1__postgres_srv__0 from stdin;
1	bar
\.

--Testcase 603:
select tableoid::regclass, * FROM remp1;

drop foreign table remp1;
drop foreign table remp2;
drop foreign table remp1__postgres_srv__0;
drop foreign table remp2__postgres_srv__0;
drop foreign table ctrtest;
drop foreign table ctrtest__postgres_srv__0;


-- ===================================================================
-- test COPY FROM
-- ===================================================================

create foreign table rem2 (f1 int, f2 text, __spd_url text)
  server pgspider_srv;
create foreign table rem2__postgres_srv__0 (f1 int, f2 text)
  server postgres_srv options(table_name 'loc2_1');

-- Test basic functionality
copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 604:
select * from rem2;

--Testcase 605:
delete from rem2__postgres_srv__0;

-- Test check constraints
alter foreign table rem2 add constraint rem2_f1positive check (f1 >= 0);

-- check constraint is enforced on the remote side, not locally
copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
copy rem2__postgres_srv__0 from stdin; -- ERROR
-1	xyzzy
\.
--Testcase 606:
select * from rem2;

alter foreign table rem2 drop constraint rem2_f1positive;

--Testcase 607:
delete from rem2__postgres_srv__0;

-- Test local triggers
create trigger trig_stmt_before before insert on rem2__postgres_srv__0
	for each statement execute procedure trigger_func();
create trigger trig_stmt_after after insert on rem2__postgres_srv__0
	for each statement execute procedure trigger_func();
create trigger trig_row_before before insert on rem2__postgres_srv__0
	for each row execute procedure trigger_data(23,'skidoo');
create trigger trig_row_after after insert on rem2__postgres_srv__0
	for each row execute procedure trigger_data(23,'skidoo');

copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 608:
select * from rem2;

drop trigger trig_row_before on rem2__postgres_srv__0;
drop trigger trig_row_after on rem2__postgres_srv__0;
drop trigger trig_stmt_before on rem2__postgres_srv__0;
drop trigger trig_stmt_after on rem2__postgres_srv__0;

--Testcase 609:
delete from rem2__postgres_srv__0;

create trigger trig_row_before_insert before insert on rem2__postgres_srv__0
	for each row execute procedure trig_row_before_insupdate();

-- The new values are concatenated with ' triggered !'
copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 610:
select * from rem2;

drop trigger trig_row_before_insert on rem2__postgres_srv__0;

--Testcase 611:
delete from rem2__postgres_srv__0;

create trigger trig_null before insert on rem2__postgres_srv__0
	for each row execute procedure trig_null();

-- Nothing happens
copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 612:
select * from rem2;

drop trigger trig_null on rem2__postgres_srv__0;

--Testcase 613:
delete from rem2__postgres_srv__0;

-- Test remote triggers
--Testcase 614:
SELECT dblink_exec('create trigger trig_row_before_insert before insert on loc2_1
	for each row execute procedure trig_row_before_insupdate();');

-- The new values are concatenated with ' triggered !'
copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 615:
select * from rem2;

--Testcase 616:
SELECT dblink_exec('drop trigger trig_row_before_insert on loc2_1;');

--Testcase 617:
delete from rem2__postgres_srv__0;

--Testcase 618:
SELECT dblink_exec('create trigger trig_null before insert on loc2_1
	for each row execute procedure trig_null();');

-- Nothing happens
copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 619:
select * from rem2;

--Testcase 620:
SELECT dblink_exec('drop trigger trig_null on loc2_1;');

--Testcase 621:
delete from rem2__postgres_srv__0;

-- Test a combination of local and remote triggers
create trigger rem2_trig_row_before before insert on rem2__postgres_srv__0
	for each row execute procedure trigger_data(23,'skidoo');
create trigger rem2_trig_row_after after insert on rem2__postgres_srv__0
	for each row execute procedure trigger_data(23,'skidoo');
--Testcase 622:
SELECT dblink_exec('create trigger loc2_trig_row_before_insert before insert on loc2_1
	for each row execute procedure trig_row_before_insupdate();');

copy rem2__postgres_srv__0 from stdin;
1	foo
2	bar
\.
--Testcase 623:
select * from rem2;

drop trigger rem2_trig_row_before on rem2__postgres_srv__0;
drop trigger rem2_trig_row_after on rem2__postgres_srv__0;
--Testcase 624:
SELECT dblink_exec('drop trigger loc2_trig_row_before_insert on loc2_1;');

--Testcase 625:
delete from rem2__postgres_srv__0;

-- test COPY FROM with foreign table created in the same transaction
begin;
create foreign table rem3 (f1 int, f2 text, __spd_url text)
	server pgspider_srv;
create foreign table rem3__postgres_srv__0 (f1 int, f2 text)
	server postgres_srv options(table_name 'loc3_1');
copy rem3__postgres_srv__0 from stdin;
1	foo
2	bar
\.
commit;
--Testcase 626:
select * from rem3;
drop foreign table rem3;
drop foreign table rem3__postgres_srv__0;

-- ===================================================================
-- test IMPORT FOREIGN SCHEMA
-- ===================================================================

---CREATE SCHEMA import_source;
---CREATE TABLE import_source.t1 (c1 int, c2 varchar NOT NULL);
---CREATE TABLE import_source.t2 (c1 int default 42, c2 varchar NULL, c3 text collate "POSIX");
---CREATE TYPE typ1 AS (m1 int, m2 varchar);
---CREATE TABLE import_source.t3 (c1 timestamptz default now(), c2 typ1);
---CREATE TABLE import_source."x 4" (c1 float8, "C 2" text, c3 varchar(42));
---CREATE TABLE import_source."x 5" (c1 float8);
---ALTER TABLE import_source."x 5" DROP COLUMN c1;
---CREATE TABLE import_source.t4 (c1 int) PARTITION BY RANGE (c1);
---CREATE TABLE import_source.t4_part PARTITION OF import_source.t4
---  FOR VALUES FROM (1) TO (100);

CREATE TYPE typ1 AS (m1 int, m2 varchar);
CREATE SCHEMA import_dest1;
IMPORT FOREIGN SCHEMA import_source FROM SERVER postgres_srv INTO import_dest1;
--Testcase 627:
\det+ import_dest1.*
--Testcase 628:
\d import_dest1.*

-- Options
CREATE SCHEMA import_dest2;
IMPORT FOREIGN SCHEMA import_source FROM SERVER postgres_srv INTO import_dest2
  OPTIONS (import_default 'true');
--Testcase 629:
\det+ import_dest2.*
--Testcase 630:
\d import_dest2.*
CREATE SCHEMA import_dest3;
IMPORT FOREIGN SCHEMA import_source FROM SERVER postgres_srv INTO import_dest3
  OPTIONS (import_collate 'false', import_not_null 'false');
--Testcase 631:
\det+ import_dest3.*
--Testcase 632:
\d import_dest3.*

-- Check LIMIT TO and EXCEPT
CREATE SCHEMA import_dest4;
IMPORT FOREIGN SCHEMA import_source LIMIT TO (t1, nonesuch)
  FROM SERVER postgres_srv INTO import_dest4;
--Testcase 633:
\det+ import_dest4.*
IMPORT FOREIGN SCHEMA import_source EXCEPT (t1, "x 4", nonesuch)
  FROM SERVER postgres_srv INTO import_dest4;
--Testcase 634:
\det+ import_dest4.*

-- Assorted error cases
IMPORT FOREIGN SCHEMA import_source FROM SERVER postgres_srv INTO import_dest4;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER postgres_srv INTO import_dest4;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER postgres_srv INTO notthere;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER nowhere INTO notthere;

-- Check case of a type present only on the remote server.
-- We can fake this by dropping the type locally in our transaction.
CREATE TYPE "Colors" AS ENUM ('red', 'green', 'blue');
--Testcase 635:
SELECT dblink_exec('CREATE TABLE import_source.t5 (c1 int, c2 text collate "C", "Col" "Colors");');

CREATE SCHEMA import_dest5;
BEGIN;
DROP TYPE "Colors" CASCADE;
IMPORT FOREIGN SCHEMA import_source LIMIT TO (t5)
  FROM SERVER postgres_srv INTO import_dest5;  -- ERROR

ROLLBACK;

BEGIN;


CREATE SERVER fetch101 FOREIGN DATA WRAPPER postgres_fdw OPTIONS( fetch_size '101' );

--Testcase 636:
SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'fetch101'
AND srvoptions @> array['fetch_size=101'];

ALTER SERVER fetch101 OPTIONS( SET fetch_size '202' );

--Testcase 637:
SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'fetch101'
AND srvoptions @> array['fetch_size=101'];

--Testcase 638:
SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'fetch101'
AND srvoptions @> array['fetch_size=202'];

CREATE FOREIGN TABLE table30000 ( x int ) SERVER fetch101 OPTIONS ( fetch_size '30000' );

--Testcase 639:
SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30000'::regclass
AND ftoptions @> array['fetch_size=30000'];

ALTER FOREIGN TABLE table30000 OPTIONS ( SET fetch_size '60000');

--Testcase 640:
SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30000'::regclass
AND ftoptions @> array['fetch_size=30000'];

--Testcase 641:
SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30000'::regclass
AND ftoptions @> array['fetch_size=60000'];

ROLLBACK;

-- ===================================================================
-- test partitionwise joins
-- ===================================================================
SET enable_partitionwise_join=on;

CREATE TABLE fprt1 (a int, b int, c varchar) PARTITION BY RANGE(a);
CREATE FOREIGN TABLE ftprt1_p1(a int, b int, c varchar, __spd_url text)
	SERVER pgspider_srv;
CREATE FOREIGN TABLE ftprt1_p1__postgres_srv__0 PARTITION OF fprt1 FOR VALUES FROM (0) TO (250)
	SERVER postgres_srv OPTIONS (table_name 'fprt1_p1', use_remote_estimate 'true');
CREATE FOREIGN TABLE ftprt1_p2(a int, b int, c varchar, __spd_url text)
	SERVER pgspider_srv;
CREATE FOREIGN TABLE ftprt1_p2__postgres_srv__0 PARTITION OF fprt1 FOR VALUES FROM (250) TO (500)
	SERVER postgres_srv OPTIONS (TABLE_NAME 'fprt1_p2');
ANALYZE fprt1;
ANALYZE ftprt1_p1;
ANALYZE ftprt1_p2;

CREATE TABLE fprt2 (a int, b int, c varchar) PARTITION BY RANGE(b);
CREATE FOREIGN TABLE ftprt2_p1 (b int, c varchar, a int, __spd_url text)
	SERVER pgspider_srv;
CREATE FOREIGN TABLE ftprt2_p1__postgres_srv__0 (b int, c varchar, a int)
	SERVER postgres_srv OPTIONS (table_name 'fprt2_p1', use_remote_estimate 'true');
ALTER TABLE fprt2 ATTACH PARTITION ftprt2_p1__postgres_srv__0 FOR VALUES FROM (0) TO (250);
CREATE FOREIGN TABLE ftprt2_p2 (b int, c varchar, a int, __spd_url text)
	SERVER pgspider_srv;
CREATE FOREIGN TABLE ftprt2_p2__postgres_srv__0 PARTITION OF fprt2 FOR VALUES FROM (250) TO (500)
	SERVER postgres_srv OPTIONS (table_name 'fprt2_p2', use_remote_estimate 'true');

ANALYZE fprt2;
ANALYZE ftprt2_p1;
ANALYZE ftprt2_p2;

-- inner join three tables
--Testcase 642:
EXPLAIN (COSTS OFF)
SELECT t1.a,t2.b,t3.c FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) INNER JOIN fprt1 t3 ON (t2.b = t3.a) WHERE t1.a % 25 =0 ORDER BY 1,2,3;
--Testcase 643:
SELECT t1.a,t2.b,t3.c FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) INNER JOIN fprt1 t3 ON (t2.b = t3.a) WHERE t1.a % 25 =0 ORDER BY 1,2,3;

-- left outer join + nullable clause
--Testcase 644:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.a,t2.b,t2.c FROM fprt1 t1 LEFT JOIN (SELECT * FROM fprt2 WHERE a < 10) t2 ON (t1.a = t2.b and t1.b = t2.a) WHERE t1.a < 10 ORDER BY 1,2,3;
--Testcase 645:
SELECT t1.a,t2.b,t2.c FROM fprt1 t1 LEFT JOIN (SELECT * FROM fprt2 WHERE a < 10) t2 ON (t1.a = t2.b and t1.b = t2.a) WHERE t1.a < 10 ORDER BY 1,2,3;

-- with whole-row reference; partitionwise join does not apply
--Testcase 646:
EXPLAIN (COSTS OFF)
SELECT t1.wr, t2.wr FROM (SELECT t1 wr, a FROM fprt1 t1 WHERE t1.a % 25 = 0) t1 FULL JOIN (SELECT t2 wr, b FROM fprt2 t2 WHERE t2.b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY 1,2;
--Testcase 647:
SELECT t1.wr, t2.wr FROM (SELECT t1 wr, a FROM fprt1 t1 WHERE t1.a % 25 = 0) t1 FULL JOIN (SELECT t2 wr, b FROM fprt2 t2 WHERE t2.b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY 1,2;

-- join with lateral reference
--Testcase 648:
EXPLAIN (COSTS OFF)
SELECT t1.a,t1.b FROM fprt1 t1, LATERAL (SELECT t2.a, t2.b FROM fprt2 t2 WHERE t1.a = t2.b AND t1.b = t2.a) q WHERE t1.a%25 = 0 ORDER BY 1,2;
--Testcase 649:
SELECT t1.a,t1.b FROM fprt1 t1, LATERAL (SELECT t2.a, t2.b FROM fprt2 t2 WHERE t1.a = t2.b AND t1.b = t2.a) q WHERE t1.a%25 = 0 ORDER BY 1,2;

-- with PHVs, partitionwise join selected but no join pushdown
--Testcase 650:
EXPLAIN (COSTS OFF)
SELECT t1.a, t1.phv, t2.b, t2.phv FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE a % 25 = 0) t1 FULL JOIN (SELECT 't2_phv' phv, * FROM fprt2 WHERE b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY t1.a, t2.b;
--Testcase 651:
SELECT t1.a, t1.phv, t2.b, t2.phv FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE a % 25 = 0) t1 FULL JOIN (SELECT 't2_phv' phv, * FROM fprt2 WHERE b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY t1.a, t2.b;

-- test FOR UPDATE; partitionwise join does not apply
--Testcase 652:
EXPLAIN (COSTS OFF)
SELECT t1.a, t2.b FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) WHERE t1.a % 25 = 0 ORDER BY 1,2 FOR UPDATE OF t1;
--Testcase 653:
SELECT t1.a, t2.b FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) WHERE t1.a % 25 = 0 ORDER BY 1,2 FOR UPDATE OF t1;

RESET enable_partitionwise_join;


-- ===================================================================
-- test partitionwise aggregates
-- ===================================================================

CREATE TABLE pagg_tab (a int, b int, c text) PARTITION BY RANGE(a);

-- Create foreign table on pgspider node
CREATE FOREIGN TABLE fpagg_tab_p1 (a int, b int, c text, __spd_url text) 
  SERVER pgspider_srv;
CREATE FOREIGN TABLE fpagg_tab_p2 (a int, b int, c text, __spd_url text) 
  SERVER pgspider_srv;
CREATE FOREIGN TABLE fpagg_tab_p3 (a int, b int, c text, __spd_url text) 
  SERVER pgspider_srv;

-- Create foreign partitions
CREATE FOREIGN TABLE fpagg_tab_p1__postgres_srv__0 
  PARTITION OF pagg_tab FOR VALUES FROM (0) TO (10) 
  SERVER postgres_srv OPTIONS (table_name 'pagg_tab_p1');
CREATE FOREIGN TABLE fpagg_tab_p2__postgres_srv__0 
  PARTITION OF pagg_tab FOR VALUES FROM (10) TO (20) 
  SERVER postgres_srv OPTIONS (table_name 'pagg_tab_p2');;
CREATE FOREIGN TABLE fpagg_tab_p3__postgres_srv__0
  PARTITION OF pagg_tab FOR VALUES FROM (20) TO (30) 
  SERVER postgres_srv OPTIONS (table_name 'pagg_tab_p3');;

ANALYZE pagg_tab;
ANALYZE fpagg_tab_p1;
ANALYZE fpagg_tab_p2;
ANALYZE fpagg_tab_p3;

-- When GROUP BY clause matches with PARTITION KEY.
-- Plan with partitionwise aggregates is disabled
SET enable_partitionwise_aggregate TO false;
--Testcase 654:
EXPLAIN (COSTS OFF)
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- Plan with partitionwise aggregates is enabled
SET enable_partitionwise_aggregate TO true;
--Testcase 655:
EXPLAIN (COSTS OFF)
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;
--Testcase 656:
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- Check with whole-row reference
-- Should have all the columns in the target list for the given relation
--Testcase 657:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT a, count(t1) FROM pagg_tab t1 GROUP BY a HAVING avg(b) < 22 ORDER BY 1;
--Testcase 658:
SELECT a, count(t1) FROM pagg_tab t1 GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- When GROUP BY clause does not match with PARTITION KEY.
--Testcase 659:
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

CREATE FOREIGN TABLE ft1_nopw (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 user_enum
) SERVER loopback_nopw OPTIONS (schema_name 'public', table_name 'ft1');

SELECT * FROM ft1_nopw LIMIT 1;

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

SELECT * FROM ft1_nopw LIMIT 1;

-- Unpriv user cannot make the mapping passwordless
ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD password_required 'false');


SELECT * FROM ft1_nopw LIMIT 1;

RESET ROLE;

-- But the superuser can
ALTER USER MAPPING FOR regress_nosuper SERVER loopback_nopw OPTIONS (ADD password_required 'false');

SET ROLE regress_nosuper;

-- Should finally work now
SELECT * FROM ft1_nopw LIMIT 1;

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
SELECT * FROM ft1_nopw LIMIT 1;

RESET ROLE;

-- The user mapping for public is passwordless and lacks the password_required=false
-- mapping option, but will work because the current user is a superuser.
SELECT * FROM ft1_nopw LIMIT 1;

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
--Testcase 660:
SELECT dblink_disconnect();
