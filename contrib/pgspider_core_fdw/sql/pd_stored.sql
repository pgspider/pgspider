-- Memorize the current database name in order to reconnect to it later after connecting to the other databases.
\set firstdb :DBNAME

-- Data preparation: Child 1
CREATE DATABASE db1;
\c db1
CREATE TABLE tbl_child1 (val text);
INSERT INTO tbl_child1 VALUES('A');
INSERT INTO tbl_child1 VALUES('BB');
INSERT INTO tbl_child1 VALUES('CCC');
INSERT INTO tbl_child1 VALUES('DD');
INSERT INTO tbl_child1 VALUES('E');
CREATE TABLE tbl_upsert (val1 text, val2 integer);
-- Data preparation: Child 2
CREATE DATABASE db2;
\c db2
CREATE TABLE tbl_child2 (val text);
INSERT INTO tbl_child2 VALUES('F');
INSERT INTO tbl_child2 VALUES('GGG');
INSERT INTO tbl_child2 VALUES('HHHHH');
CREATE TABLE tbl_upsert (val1 text, val2 integer);

-- Back to the original database.
\c :firstdb

-- Datasource configuration
CREATE EXTENSION postgres_fdw;

DO $d$
    BEGIN
        EXECUTE $$CREATE SERVER loopback1 FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (dbname 'db1',
                     port '$$||current_setting('port')||$$'
            )$$;
        EXECUTE $$CREATE SERVER loopback2 FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (dbname 'db2',
                     port '$$||current_setting('port')||$$'
            )$$;
    END;
$d$;
CREATE USER MAPPING FOR CURRENT_USER SERVER loopback1;
CREATE USER MAPPING FOR CURRENT_USER SERVER loopback2;
CREATE FOREIGN TABLE tbl__loopback1__0(val text) SERVER loopback1 OPTIONS (table_name 'tbl_child1');
CREATE FOREIGN TABLE tbl__loopback2__0(val text) SERVER loopback2 OPTIONS (table_name 'tbl_child2');
CREATE FOREIGN TABLE tbl_upsert__loopback1__0(val1 text, val2 integer) SERVER loopback1 OPTIONS (table_name 'tbl_upsert');
CREATE FOREIGN TABLE tbl_upsert__loopback2__0(val1 text, val2 integer) SERVER loopback2 OPTIONS (table_name 'tbl_upsert');

-- Multitenant table configuration
CREATE EXTENSION pgspider_core_fdw;
CREATE SERVER pgspider FOREIGN DATA WRAPPER pgspider_core_fdw;
CREATE USER MAPPING FOR public SERVER pgspider;
CREATE FOREIGN TABLE tbl (val text, __spd_url text) SERVER pgspider;
CREATE FOREIGN TABLE tbl_upsert (val1 text, val2 integer, __spd_url text) SERVER pgspider;

--Testcase 1: Argument type of distributed function is same as that of parent function
-- Child function
CREATE OR REPLACE FUNCTION trans_child (internal text, col text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
BEGIN
    return internal || col;
END;
$$;
CREATE OR REPLACE AGGREGATE agg_child (col text) (sfunc = trans_child, stype = text, INITCOND = '');
-- Parent function
CREATE OR REPLACE FUNCTION trans_parent (internal text, col text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
BEGIN
    return internal || '_' || col;
END;
$$;
CREATE OR REPLACE AGGREGATE agg_parent (col text) (sfunc = trans_parent, stype = text, INITCOND = '');
-- Distributed function
CREATE OR REPLACE DISTRIBUTED_FUNC agg_dist (col text) PARENT agg_parent(text) CHILD agg_child(col text);

SELECT agg_dist(val) FROM tbl;


--Testcase 2: Argument type of distributed function is different from that of parent function
-- Child function
CREATE OR REPLACE FUNCTION trans_child2 (internal integer, col text) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
BEGIN
    return internal + length(col);
END;
$$;
CREATE OR REPLACE AGGREGATE agg_child2 (col text) (sfunc = trans_child2, stype = integer, INITCOND = '0');
-- Parent function
CREATE OR REPLACE FUNCTION trans_parent2 (internal integer, len integer) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
BEGIN
    return internal + len;
END;
$$;
CREATE OR REPLACE AGGREGATE agg_parent2 (col integer) (sfunc = trans_parent2, stype = integer, INITCOND = '0');

-- Distributed function
CREATE OR REPLACE DISTRIBUTED_FUNC agg_dist2 (col text) PARENT agg_parent2(integer) CHILD agg_child2(col text);

-- This distributed function calculates a total character length of column. The result is same as "SELECT sum(length(val)) FROM tbl"
SELECT agg_dist2(val) FROM tbl;


--Testcase 3: Create a function which behaves like UPSERT
-- Child function
CREATE OR REPLACE FUNCTION upsert_child_trans (internal integer, col text) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
BEGIN
    IF col = 'data1' THEN
      return internal + 1;
    ELSE
      return internal;
    END IF;
END;
$$;
CREATE OR REPLACE FUNCTION upsert_child_final (internal integer) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
BEGIN
    IF internal <> 0 THEN
      UPDATE public.tbl_upsert SET val2 = val2 + 1 WHERE val1 = 'data1';
      return 'updated';
    ELSE
      INSERT INTO public.tbl_upsert VALUES('data1', 1);
      return 'inserted';
    END IF;
END;
$$;
CREATE OR REPLACE AGGREGATE upsert_child (col text) (sfunc = upsert_child_trans, FINALFUNC = upsert_child_final, stype = integer, INITCOND = '0');
-- Parent function
CREATE OR REPLACE FUNCTION upsert_parent_trans (internal text, ret text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
BEGIN
    return internal || '_' || ret;
END;
$$;
CREATE OR REPLACE AGGREGATE upsert_parent (col text) (sfunc = upsert_parent_trans, stype = text, INITCOND = '');

-- Distributed function
CREATE OR REPLACE DISTRIBUTED_FUNC upsert (col text) PARENT upsert_parent(text) CHILD upsert_child(col text);

SELECT upsert(val1) FROM tbl_upsert;
SELECT * FROM tbl_upsert ORDER BY __spd_url;
SELECT upsert(val1) FROM tbl_upsert;
SELECT * FROM tbl_upsert ORDER BY __spd_url;
SELECT upsert(val1) FROM tbl_upsert;
SELECT * FROM tbl_upsert ORDER BY __spd_url;

