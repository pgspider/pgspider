-- ===================================================================
-- create FDW objects
-- ===================================================================
--Testcase 1:
CREATE EXTENSION postgres_fdw;
--Testcase 2:
CREATE EXTENSION pgspider_core_fdw;
--Testcase 3:
CREATE EXTENSION pgspider_fdw;

--Testcase 4:
CREATE SERVER pgspider_core_srv FOREIGN DATA WRAPPER pgspider_core_fdw;
--Testcase 5:
CREATE USER MAPPING FOR public SERVER pgspider_core_srv;

DO $d$
    BEGIN
        EXECUTE $$CREATE SERVER postgres_srv1 FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (host '127.0.0.1',
                     port '15432',
                     dbname 'postgres'
            )$$;
        EXECUTE $$CREATE SERVER postgres_srv2 FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (host '127.0.0.1',
                     port '25432',
                     dbname 'postgres'
            )$$;
        EXECUTE $$CREATE SERVER postgres_srv3 FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (host '127.0.0.1',
                     port '35432',
                     dbname 'postgres'
            )$$;
    END;
$d$;
--Testcase 6:
CREATE USER MAPPING FOR public SERVER postgres_srv1
    OPTIONS (user 'postgres', password 'postgres');
--Testcase 7:
CREATE USER MAPPING FOR public SERVER postgres_srv2
    OPTIONS (user 'postgres', password 'postgres');
--Testcase 8:
CREATE USER MAPPING FOR public SERVER postgres_srv3
    OPTIONS (user 'postgres', password 'postgres');

--Testcase 9:
CREATE SERVER pgspider_srv1 FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (host '127.0.0.1', port '14813', dbname 'pgspider');
--Testcase 10:
CREATE USER MAPPING FOR public SERVER pgspider_srv1
    OPTIONS (user 'pgspider', password 'pgspider');

----------------------------------------------------------
-- abnormal case
-- all test case in this section will be ERROR
----------------------------------------------------------
-- Init foreign table
--Testcase 11:
CREATE FOREIGN TABLE test_error (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl1'
) SERVER postgres_srv1 OPTIONS (schema_name 'S 1', table_name 'test_error');
--Testcase 12:
CREATE DATASOURCE TABLE test_error;
--Testcase 13:
INSERT INTO test_error VALUES (1, 1, 'foo', '2022/10/09 12:00:00 +08', '2022/10/09 12:00:00', '0', DEFAULT);
--Testcase 14:
SELECT * FROM test_error ORDER BY c1;

--
-- Wrong key word
-- Wrong key word order
--

-- ERROR: syntax error
--Testcase 15:
MIGRATED test_error SERVER postgres_srv2; -- wrong key word
--Testcase 16:
MIGRATE FOREIGN TABLE test_error SERVER postgres_srv2; -- redundant word
--Testcase 17:
MIGRATE TABLE test_error SERVER postgres_srv2 TO ft2; -- wrong key word order
--Testcase 18:
MIGRATE TABLE test_error REPLACE TO ft2 SERVER postgres_srv2; -- redundant word

--Testcase 20:
CREATE TABLE DATASOURCE test_error; -- wrong key word order
--Testcase 21:
CREATE DATA TABLE test_error; -- wrong key word
--Testcase 22:
CREATE NEW DATASOURCE TABLE test_error; -- redundant key word
--Testcase 23:
DROP TABLE DATASOURCE test_error; -- wrong key word order
--Testcase 24:
DROP DATA TABLE test_error; -- wrong key word
--Testcase 25:
DROP NEW DATASOURCE TABLE test_error; -- redundant key word


-- dest table of MIGRATE command existed
--Testcase 26:
CREATE FOREIGN TABLE test_error2 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl1'
) SERVER postgres_srv1 OPTIONS (schema_name 'S 1', table_name 'test_error2');
--Testcase 27:
CREATE DATASOURCE TABLE test_error2;

-- ERROR: dest table existed
--Testcase 28:
MIGRATE TABLE test_error TO test_error2 SERVER postgres_srv2; -- ERROR
--Testcase 29:
DROP FOREIGN TABLE test_error2;

-- ERROR: Datasource table of dest table of MIGRATE command existed
--Testcase 30:
MIGRATE TABLE test_error TO test_error2 SERVER postgres_srv1 OPTIONS (schema_name 'S 1', table_name 'test_error2'); -- ERROR
-- drop datasource table test_error2
--Testcase 31:
CREATE FOREIGN TABLE test_error2 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl1'
) SERVER postgres_srv1 OPTIONS (schema_name 'S 1', table_name 'test_error2');
--Testcase 32:
DROP DATASOURCE TABLE test_error2;
--Testcase 33:
DROP FOREIGN TABLE test_error2;

-- ERROR: Dest server does not exist
--Testcase 34:
MIGRATE TABLE test_error TO test_error2 SERVER not_exist_server;

-- ERROR: USE_MULTITENANT_SERVER without pgspider_core_fdw extension created
--Testcase 35:
DROP EXTENSION pgspider_core_fdw CASCADE;
--Testcase 36:
MIGRATE TABLE test_error TO test_error2 OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2;

--Testcase 37:
CREATE EXTENSION pgspider_core_fdw;
--Testcase 38:
CREATE SERVER pgspider_core_srv FOREIGN DATA WRAPPER pgspider_core_fdw;
--Testcase 39:
CREATE USER MAPPING FOR public SERVER pgspider_core_srv;

-- ERROR USE_MULTITENANT_SERVER with postgres server
--Testcase 40:
MIGRATE TABLE test_error TO test_error2 OPTIONS (USE_MULTITENANT_SERVER 'postgres_srv1') SERVER postgres_srv2;

-- ERROR: Does not exist dest table option
--Testcase 41:
MIGRATE TABLE test_error TO test_error2 OPTIONS (not_existed_option 'value') SERVER postgres_srv2;

-- ERROR: Duplicate server specification, same datasource table will create in one server.
--Testcase 42:
MIGRATE TABLE test_error SERVER postgres_srv2, postgres_srv2;
--Testcase 43:
MIGRATE TABLE test_error TO test_error2 SERVER postgres_srv2 OPTIONS(table_name 'test_error_datasource'), postgres_srv2 OPTIONS(table_name 'test_error_datasource');

-- OK: Same server, different options
--Testcase 44:
MIGRATE TABLE test_error TO test_error2 SERVER postgres_srv2, postgres_srv2 OPTIONS(table_name 'test_error_2'); -- OK
--Testcase 45:
\det+
--Testcase 46:
SELECT * FROM test_error2;
--Testcase 47:
DROP DATASOURCE TABLE test_error2__postgres_srv2__0;
--Testcase 48:
DROP DATASOURCE TABLE test_error2__postgres_srv2__1;
--Testcase 49:
DROP FOREIGN TABLE test_error2__postgres_srv2__0;
--Testcase 50:
DROP FOREIGN TABLE test_error2__postgres_srv2__1;
--Testcase 51:
DROP FOREIGN TABLE test_error2;

-- CREATE DATASOURCE TABLE with unsupported FDWs
--Testcase 52:
CREATE EXTENSION file_fdw;
--Testcase 53:
CREATE SERVER file_svr FOREIGN DATA WRAPPER file_fdw;
--Testcase 54:
CREATE FOREIGN TABLE file_tbl (i int) SERVER file_svr options(filename '/tmp/pgtest.csv');
--Testcase 55:
CREATE DATASOURCE TABLE file_tbl;
--Testcase 56:
DROP EXTENSION file_fdw CASCADE;

-- CREATE DATASOURCE TABLE with postgres normal table
--Testcase 57:
CREATE TABLE post_tbl (i int);
--Testcase 58:
CREATE DATASOURCE TABLE post_tbl;
--Testcase 59:
DROP TABLE post_tbl;

-- clean-up
--Testcase 60:
DROP DATASOURCE TABLE test_error;
--Testcase 61:
DROP FOREIGN TABLE test_error;

----------------------------------------------------------
-- source structure tbl1
-- postgres normal table
----------------------------------------------------------
--Testcase 62:
CREATE PROCEDURE base_table_init()
LANGUAGE SQL
AS $$
    CREATE TABLE IF NOT EXISTS base_table (
        c1 int NOT NULL,
        c2 int NOT NULL,
        c3 text,
        c4 timestamptz,
        c5 timestamp,
        c6 varchar(10),
        c7 char(10) default 'base_table'
    );
$$;

--Testcase 63:
CALL base_table_init();

-- Init data
--Testcase 64:
INSERT INTO base_table
    SELECT id,
            id % 10,
            to_char(id, 'FM00000'),
            '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
            '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
            id % 10,
            id % 10
    FROM generate_series(1, 15) id;

--
-- MIGRATE without TO/REPLACE , single server without any SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 65:
CREATE FOREIGN TABLE base_table_datasource (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'base_table'
) SERVER postgres_srv1 OPTIONS (table_name 'base_table');

-- ERROR: datasource table does not create yet
--Testcase 66:
SELECT * FROM base_table_datasource ORDER BY c1;

--Testcase 67:
MIGRATE TABLE base_table SERVER postgres_srv1;

-- no new foreign table created
--Testcase 68:
\det+

-- OK: datasource table created
--Testcase 69:
SELECT * FROM base_table_datasource ORDER BY c1;

-- clean-up
--Testcase 70:
DROP DATASOURCE TABLE base_table_datasource;
--Testcase 71:
DROP FOREIGN TABLE base_table_datasource;

--
-- MIGRATE without TO/REPLACE , single server with SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 72:
CREATE FOREIGN TABLE base_table_datasource (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'base_table'
) SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'base_table');

-- ERROR: datasource table does not create yet
--Testcase 73:
SELECT * FROM base_table_datasource ORDER BY c1;

--Testcase 74:
MIGRATE TABLE base_table SERVER postgres_srv2 OPTIONS (schema_name 'S 2');

-- no new foreign table created
--Testcase 75:
\det+

-- OK: datasource table created
--Testcase 76:
SELECT * FROM base_table_datasource ORDER BY c1;

-- clean-up
--Testcase 77:
DROP DATASOURCE TABLE base_table_datasource;
--Testcase 78:
DROP FOREIGN TABLE base_table_datasource;

--
-- MIGRATE without TO/REPLACE , multi servers with SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 79:
CREATE FOREIGN TABLE base_table_datasource1 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'base_table'
) SERVER postgres_srv2 OPTIONS (schema_name 'S 1', table_name 'base_table');

--Testcase 80:
CREATE FOREIGN TABLE base_table_datasource2 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'base_table'
) SERVER postgres_srv3 OPTIONS (schema_name 'S 1', table_name 'base_table');

-- ERROR: datasource table does not create yet
--Testcase 81:
SELECT * FROM base_table_datasource1 ORDER BY c1;
--Testcase 82:
SELECT * FROM base_table_datasource2 ORDER BY c1;

--Testcase 83:
MIGRATE TABLE base_table SERVER postgres_srv2 OPTIONS (schema_name 'S 1'), postgres_srv3 OPTIONS (schema_name 'S 1');

-- no new foreign table created
--Testcase 84:
\det+

-- OK: datasource table created
SELECT * FROM base_table ORDER BY c1, __spd_url;
--Testcase 85:
SELECT count(*) FROM base_table_datasource1;
--Testcase 86:
SELECT count(*) FROM base_table_datasource2;

-- clean-up
--Testcase 87:
DROP DATASOURCE TABLE base_table_datasource1;
--Testcase 88:
DROP DATASOURCE TABLE base_table_datasource2;
--Testcase 89:
DROP FOREIGN TABLE base_table_datasource1;
--Testcase 90:
DROP FOREIGN TABLE base_table_datasource2;

--
-- MIGRATE REPLACE , single server without any SERVER OPTION
--

--Testcase 91:
SELECT * FROM base_table ORDER BY c1, __spd_url;

--Testcase 92:
MIGRATE TABLE base_table REPLACE SERVER postgres_srv2;

-- base_table is replace by a foreign table
--Testcase 93:
\det+

-- base_table is postgres foreign table now.
--Testcase 94:
\d base_table
--Testcase 95:
SELECT * FROM base_table ORDER BY c1;

--Testcase 96:
DROP DATASOURCE TABLE base_table;
--Testcase 97:
DROP FOREIGN TABLE base_table;

-- re-init base_table to execute test after
--Testcase 98:
CALL base_table_init();

-- Init data
--Testcase 99:
INSERT INTO base_table
    SELECT id,
            id % 10,
            to_char(id, 'FM00000'),
            '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
            '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
            id % 10,
            id % 10
    FROM generate_series(1, 15) id;

--
-- MIGRATE REPLACE , single server with SERVER OPTION
--
--Testcase 100:
SELECT * FROM base_table ORDER BY c1;
--Testcase 101:
MIGRATE TABLE base_table REPLACE SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');
-- base_table is replace by a new foreign table
--Testcase 102:
\det+

-- base_table is postgres foreign table now.
--Testcase 103:
\d base_table
--Testcase 104:
SELECT * FROM base_table ORDER BY c1;

--Testcase 105:
DROP DATASOURCE TABLE base_table;
--Testcase 106:
DROP FOREIGN TABLE base_table;

-- re-init base_table to execute test after
--Testcase 107:
CALL base_table_init();

-- Init data
--Testcase 108:
INSERT INTO base_table
    SELECT id,
            id % 10,
            to_char(id, 'FM00000'),
            '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
            '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
            id % 10,
            id % 10
    FROM generate_series(1, 15) id;

--
-- MIGRATE REPLACE , multi servers with SERVER OPTION
--
--Testcase 109:
SELECT * FROM base_table ORDER BY c1;
--Testcase 110:
MIGRATE TABLE base_table REPLACE SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 3', table_name 'T 2');
-- base_table is replace by a new multitenant table
--Testcase 111:
\det+

-- base_table is multitenant table
--Testcase 112:
\d base_table
--Testcase 113:
SELECT * FROM base_table ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 114:
SELECT count(*) FROM base_table__postgres_srv2__0;
--Testcase 115:
SELECT count(*) FROM base_table__postgres_srv3__0;

--Testcase 116:
DROP FOREIGN TABLE base_table;
--Testcase 117:
DROP DATASOURCE TABLE base_table__postgres_srv2__0;
--Testcase 118:
DROP DATASOURCE TABLE base_table__postgres_srv3__0;
--Testcase 119:
DROP FOREIGN TABLE base_table__postgres_srv2__0;
--Testcase 120:
DROP FOREIGN TABLE base_table__postgres_srv3__0;

-- re-init base_table to execute test after
--Testcase 121:
CALL base_table_init();

-- Init data
--Testcase 122:
INSERT INTO base_table
    SELECT id,
            id % 10,
            to_char(id, 'FM00000'),
            '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
            '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
            id % 10,
            id % 10
    FROM generate_series(1, 15) id;

--
-- MIGRATE TO , single server without any SERVER OPTION
--
--Testcase 123:
SELECT * FROM base_table ORDER BY c1;
--Testcase 124:
MIGRATE TABLE base_table TO base_table_new SERVER postgres_srv2;
-- new foreign table created
--Testcase 125:
\det+

-- base_table_new is postgres foreign table
--Testcase 126:
\d base_table_new
--Testcase 127:
SELECT * FROM base_table_new ORDER BY c1;
--Testcase 128:
DROP DATASOURCE TABLE base_table_new;
--Testcase 129:
DROP FOREIGN TABLE base_table_new;

--
-- MIGRATE TO , single server with SERVER OPTION
--
--Testcase 130:
SELECT * FROM base_table ORDER BY c1;
--Testcase 131:
MIGRATE TABLE base_table TO base_table_new SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');
-- new foreing table created
--Testcase 132:
\det+

-- base_table_new is postgres foreign table
--Testcase 133:
\d base_table_new
--Testcase 134:
SELECT * FROM base_table_new ORDER BY c1;
--Testcase 135:
DROP DATASOURCE TABLE base_table_new;
--Testcase 136:
DROP FOREIGN TABLE base_table_new;

--
-- MIGRATE TO , multi servers with SERVER OPTION
--
--Testcase 137:
SELECT * FROM base_table ORDER BY c1;
--Testcase 138:
MIGRATE TABLE base_table TO base_table_new SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 2', table_name 'T 2');
-- new multitenant table created
--Testcase 139:
\det+

-- base_table_new is multitenant table
--Testcase 140:
\d base_table_new
--Testcase 141:
SELECT * FROM base_table_new ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 142:
SELECT count(*) FROM base_table_new__postgres_srv2__0;
--Testcase 143:
SELECT count(*) FROM base_table_new__postgres_srv3__0;

--Testcase 144:
DROP FOREIGN TABLE base_table_new;
--Testcase 145:
DROP DATASOURCE TABLE base_table_new__postgres_srv2__0;
--Testcase 146:
DROP DATASOURCE TABLE base_table_new__postgres_srv3__0;
--Testcase 147:
DROP FOREIGN TABLE base_table_new__postgres_srv2__0;
--Testcase 148:
DROP FOREIGN TABLE base_table_new__postgres_srv3__0;

--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, single server without any SERVER OPTION
--
--Testcase 149:
SELECT * FROM base_table ORDER BY c1;
--Testcase 150:
MIGRATE TABLE base_table TO base_table_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2;
-- new multitenant table created
--Testcase 151:
\det+

-- base_table_new is multitenant table
--Testcase 152:
\d base_table_new
--Testcase 153:
SELECT * FROM base_table_new ORDER BY c1;
-- check data distribution
--Testcase 154:
SELECT * FROM base_table_new__postgres_srv2__0 ORDER BY c1;

--Testcase 155:
DROP FOREIGN TABLE base_table_new;
--Testcase 156:
DROP DATASOURCE TABLE base_table_new__postgres_srv2__0;
--Testcase 157:
DROP FOREIGN TABLE base_table_new__postgres_srv2__0;

--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, single server with SERVER OPTION
--
--Testcase 158:
SELECT * FROM base_table ORDER BY c1;
--Testcase 159:
MIGRATE TABLE base_table TO base_table_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');
-- new multitenant table created
--Testcase 160:
\det+
-- base_table_new is multitenant table
--Testcase 161:
\d base_table_new
--Testcase 162:
SELECT * FROM base_table_new ORDER BY c1;
-- check data distribution
--Testcase 163:
SELECT * FROM base_table_new__postgres_srv2__0 ORDER BY c1;

--Testcase 164:
DROP FOREIGN TABLE base_table_new;
--Testcase 165:
DROP DATASOURCE TABLE base_table_new__postgres_srv2__0;
--Testcase 166:
DROP FOREIGN TABLE base_table_new__postgres_srv2__0;

--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, multi servers with SERVER OPTION
--
--Testcase 167:
MIGRATE TABLE base_table TO base_table_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 3', table_name 'T 2');
-- new multitenant table created
--Testcase 168:
\det+
-- base_table_new is multitenant table
--Testcase 169:
\d base_table_new
--Testcase 170:
SELECT * FROM base_table_new ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 171:
SELECT count(*) FROM base_table_new__postgres_srv2__0;
--Testcase 172:
SELECT count(*) FROM base_table_new__postgres_srv3__0;

--Testcase 173:
DROP FOREIGN TABLE base_table_new;
--Testcase 174:
DROP DATASOURCE TABLE base_table_new__postgres_srv2__0;
--Testcase 175:
DROP DATASOURCE TABLE base_table_new__postgres_srv3__0;
--Testcase 176:
DROP FOREIGN TABLE base_table_new__postgres_srv2__0;
--Testcase 177:
DROP FOREIGN TABLE base_table_new__postgres_srv3__0;
-- clean-up
--Testcase 178:
DROP TABLE base_table;

----------------------------------------------------------
-- source structure tbl1
-- PGSpider Top Node -> 3 posgres data source
----------------------------------------------------------
--Testcase 179:
CREATE PROCEDURE tbl1_init()
LANGUAGE SQL
AS $$
    CREATE FOREIGN TABLE IF NOT EXISTS tbl1 (
        c1 int NOT NULL,
        c2 int NOT NULL,
        c3 text,
        c4 timestamptz,
        c5 timestamp,
        c6 varchar(10),
        c7 char(10) default 'tbl1',
        __spd_url text
    ) SERVER pgspider_core_srv;

--Testcase 180:
    CREATE FOREIGN TABLE IF NOT EXISTS tbl1__postgres_srv1__0 (
        c1 int NOT NULL,
        c2 int NOT NULL,
        c3 text,
        c4 timestamptz,
        c5 timestamp,
        c6 varchar(10),
        c7 char(10) default 'tbl1'
    ) SERVER postgres_srv1 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 181:
    CREATE DATASOURCE TABLE IF NOT EXISTS tbl1__postgres_srv1__0;

--Testcase 182:
    CREATE FOREIGN TABLE IF NOT EXISTS tbl1__postgres_srv2__0 (
        c1 int NOT NULL,
        c2 int NOT NULL,
        c3 text,
        c4 timestamptz,
        c5 timestamp,
        c6 varchar(10),
        c7 char(10) default 'tbl1'
    ) SERVER postgres_srv2 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 183:
    CREATE DATASOURCE TABLE IF NOT EXISTS tbl1__postgres_srv2__0;

--Testcase 184:
    CREATE FOREIGN TABLE IF NOT EXISTS tbl1__postgres_srv3__0 (
        c1 int NOT NULL,
        c2 int NOT NULL,
        c3 text,
        c4 timestamptz,
        c5 timestamp,
        c6 varchar(10),
        c7 char(10) default 'tbl1'
    ) SERVER postgres_srv3 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 185:
    CREATE DATASOURCE TABLE IF NOT EXISTS tbl1__postgres_srv3__0;
$$;

--Testcase 186:
CALL tbl1_init();

-- Init data
--Testcase 187:
INSERT INTO tbl1__postgres_srv1__0
    SELECT id,
            id % 10,
            to_char(id, 'FM00000'),
            '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
            '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
            id % 10,
            id % 10
    FROM generate_series(1, 5) id;

--Testcase 188:
INSERT INTO tbl1__postgres_srv2__0
    SELECT id,
            id % 10,
            to_char(id, 'FM00000'),
            '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
            '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
            id % 10,
            id % 10
    FROM generate_series(6, 10) id;

--Testcase 189:
INSERT INTO tbl1__postgres_srv3__0
    SELECT id,
            id % 10,
            to_char(id, 'FM00000'),
            '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
            '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
            id % 10,
            id % 10
    FROM generate_series(11, 15) id;

--Testcase 190:
SELECT * FROM tbl1 ORDER BY c1;

--
-- MIGRATE without TO/REPLACE , single server without any SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 191:
CREATE FOREIGN TABLE tbl1_datasource (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl1'
) SERVER postgres_srv1 OPTIONS (table_name 'tbl1');

-- ERROR: datasource table does not create yet
--Testcase 192:
SELECT * FROM tbl1_datasource ORDER BY c1;

--Testcase 193:
MIGRATE TABLE tbl1 SERVER postgres_srv1;

-- no new foreign table created
--Testcase 194:
\det+

-- OK: datasource table created
--Testcase 195:
SELECT * FROM tbl1_datasource ORDER BY c1;

-- clean-up
--Testcase 196:
DROP DATASOURCE TABLE tbl1_datasource;
--Testcase 197:
DROP FOREIGN TABLE tbl1_datasource;

--
-- MIGRATE without TO/REPLACE , single server with SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 198:
CREATE FOREIGN TABLE tbl1_datasource (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl1'
) SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'tbl1');

-- ERROR: datasource table does not create yet
--Testcase 199:
SELECT * FROM tbl1_datasource ORDER BY c1;

--Testcase 200:
MIGRATE TABLE tbl1 SERVER postgres_srv2 OPTIONS (schema_name 'S 2');

-- no new foreign table created
--Testcase 201:
\det+

-- OK: datasource table created
--Testcase 202:
SELECT * FROM tbl1_datasource ORDER BY c1;

-- clean-up
--Testcase 203:
DROP DATASOURCE TABLE tbl1_datasource;
--Testcase 204:
DROP FOREIGN TABLE tbl1_datasource;

--
-- MIGRATE without TO/REPLACE , multi servers with SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 205:
CREATE FOREIGN TABLE tbl1_datasource1 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl1'
) SERVER postgres_srv2 OPTIONS (schema_name 'S 1', table_name 'tbl1');

--Testcase 206:
CREATE FOREIGN TABLE tbl1_datasource2 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl1'
) SERVER postgres_srv3 OPTIONS (schema_name 'S 1', table_name 'tbl1');

-- ERROR: datasource table does not create yet
--Testcase 207:
SELECT * FROM tbl1_datasource1 ORDER BY c1;
--Testcase 208:
SELECT * FROM tbl1_datasource2 ORDER BY c1;

--Testcase 209:
MIGRATE TABLE tbl1 SERVER postgres_srv2 OPTIONS (schema_name 'S 1'), postgres_srv3 OPTIONS (schema_name 'S 1');

-- no new foreign table created
--Testcase 210:
\det+

-- OK: datasource table created
SELECT * FROM tbl1 ORDER BY c1, __spd_url;
--Testcase 211:
SELECT count(*) FROM tbl1_datasource1;
--Testcase 212:
SELECT count(*) FROM tbl1_datasource2;

-- clean-up
--Testcase 213:
DROP DATASOURCE TABLE tbl1_datasource1;
--Testcase 214:
DROP DATASOURCE TABLE tbl1_datasource2;
--Testcase 215:
DROP FOREIGN TABLE tbl1_datasource1;
--Testcase 216:
DROP FOREIGN TABLE tbl1_datasource2;

--
-- MIGRATE REPLACE , single server without any SERVER OPTION
--

--Testcase 217:
SELECT * FROM tbl1 ORDER BY c1;

--Testcase 218:
MIGRATE TABLE tbl1 REPLACE SERVER postgres_srv2 OPTIONS (schema_name 'S 1');

-- show datasource table and foreign table
--Testcase 219:
SELECT table_schema, table_name, table_type FROM information_schema.tables
	WHERE table_type in ('BASE TABLE', 'FOREIGN') AND table_schema NOT IN ('pg_catalog', 'information_schema');

-- tbl1 is postgres foreign table now.
--Testcase 220:
\d tbl1
--Testcase 221:
SELECT * FROM tbl1 ORDER BY c1;

--Testcase 222:
DROP DATASOURCE TABLE tbl1;
--Testcase 223:
DROP FOREIGN TABLE tbl1;

-- re-init tbl1 to execute test after
--Testcase 224:
CALL tbl1_init();

--
-- MIGRATE REPLACE , single server with SERVER OPTION
--
--Testcase 225:
SELECT * FROM tbl1 ORDER BY c1;
--Testcase 226:
MIGRATE TABLE tbl1 REPLACE SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');
-- tbl1 is replaced by a new foreign table
--Testcase 227:
\det+

-- tbl1 is postgres foreign table now.
--Testcase 228:
\d tbl1
--Testcase 229:
SELECT * FROM tbl1 ORDER BY c1;

--Testcase 230:
DROP DATASOURCE TABLE tbl1;
--Testcase 231:
DROP FOREIGN TABLE tbl1;
-- re-init tbl1 to execute test after
--Testcase 232:
CALL tbl1_init();

--
-- MIGRATE REPLACE , multi servers with SERVER OPTION
--
--Testcase 233:
SELECT * FROM tbl1 ORDER BY c1;
--Testcase 234:
MIGRATE TABLE tbl1 REPLACE SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 3', table_name 'T 2');
-- tbl1 is replaced by a new foreign table
--Testcase 235:
\det+

-- tbl1 is multitenant table
--Testcase 236:
\d tbl1
--Testcase 237:
SELECT * FROM tbl1 ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 238:
SELECT count(*) FROM tbl1__postgres_srv2__0;
--Testcase 239:
SELECT count(*) FROM tbl1__postgres_srv3__0;

--Testcase 240:
DROP FOREIGN TABLE tbl1;
--Testcase 241:
DROP DATASOURCE TABLE tbl1__postgres_srv2__0;
--Testcase 242:
DROP DATASOURCE TABLE tbl1__postgres_srv3__0;
--Testcase 243:
DROP FOREIGN TABLE tbl1__postgres_srv2__0;
--Testcase 244:
DROP FOREIGN TABLE tbl1__postgres_srv3__0;

-- re-init tbl1 to execute test after
--Testcase 245:
CALL tbl1_init();

--
-- MIGRATE TO , single server without any SERVER OPTION
--
--Testcase 246:
SELECT * FROM tbl1 ORDER BY c1;
--Testcase 247:
MIGRATE TABLE tbl1 TO tbl1_new SERVER postgres_srv2 OPTIONS(schema_name 'S 1');
-- new foreign table created
--Testcase 248:
\det+

-- tbl1_new is postgres foreign table
--Testcase 249:
\d tbl1_new
--Testcase 250:
SELECT * FROM tbl1_new ORDER BY c1;
--Testcase 251:
DROP DATASOURCE TABLE tbl1_new;
--Testcase 252:
DROP FOREIGN TABLE tbl1_new;

--
-- MIGRATE TO , single server with SERVER OPTION
--
--Testcase 253:
SELECT * FROM tbl1 ORDER BY c1;
--Testcase 254:
MIGRATE TABLE tbl1 TO tbl1_new SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');
-- new foreign table created
--Testcase 255:
\det+

-- tbl1_new is postgres foreign table
--Testcase 256:
\d tbl1_new
--Testcase 257:
SELECT * FROM tbl1_new ORDER BY c1;
--Testcase 258:
DROP DATASOURCE TABLE tbl1_new;
--Testcase 259:
DROP FOREIGN TABLE tbl1_new;

--
-- MIGRATE TO , multi servers with SERVER OPTION
--
--Testcase 260:
SELECT * FROM tbl1 ORDER BY c1;
--Testcase 261:
MIGRATE TABLE tbl1 TO tbl1_new SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 2', table_name 'T 2');
-- new multitenant table created
--Testcase 262:
\det+

-- tbl1_new is multitenant table
--Testcase 263:
\d tbl1_new
--Testcase 264:
SELECT * FROM tbl1_new ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 265:
SELECT count(*) FROM tbl1_new__postgres_srv2__0;
--Testcase 266:
SELECT count(*) FROM tbl1_new__postgres_srv3__0;

--Testcase 267:
DROP FOREIGN TABLE tbl1_new;
--Testcase 268:
DROP DATASOURCE TABLE tbl1_new__postgres_srv2__0;
--Testcase 269:
DROP DATASOURCE TABLE tbl1_new__postgres_srv3__0;
--Testcase 270:
DROP FOREIGN TABLE tbl1_new__postgres_srv2__0;
--Testcase 271:
DROP FOREIGN TABLE tbl1_new__postgres_srv3__0;

--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, single server without any SERVER OPTION
--
--Testcase 272:
SELECT * FROM tbl1 ORDER BY c1;
--Testcase 273:
MIGRATE TABLE tbl1 TO tbl1_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2 OPTIONS (schema_name 'S 1');
-- new multitenant table created
--Testcase 274:
\det+
-- tbl1_new is multitenant table
--Testcase 275:
\d tbl1_new
--Testcase 276:
SELECT * FROM tbl1_new ORDER BY c1;
-- check data distribution
--Testcase 277:
SELECT * FROM tbl1_new__postgres_srv2__0 ORDER BY c1;

--Testcase 278:
DROP FOREIGN TABLE tbl1_new;
--Testcase 279:
DROP DATASOURCE TABLE tbl1_new__postgres_srv2__0;
--Testcase 280:
DROP FOREIGN TABLE tbl1_new__postgres_srv2__0;
--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, single server with SERVER OPTION
--
--Testcase 281:
SELECT * FROM tbl1 ORDER BY c1;
--Testcase 282:
MIGRATE TABLE tbl1 TO tbl1_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');
-- new multitennant table created
--Testcase 283:
\det+
-- tbl1_new is multitenant table
--Testcase 284:
\d tbl1_new
--Testcase 285:
SELECT * FROM tbl1_new ORDER BY c1;
-- check data distribution
--Testcase 286:
SELECT * FROM tbl1_new__postgres_srv2__0 ORDER BY c1;

--Testcase 287:
DROP FOREIGN TABLE tbl1_new;
--Testcase 288:
DROP DATASOURCE TABLE tbl1_new__postgres_srv2__0;
--Testcase 289:
DROP FOREIGN TABLE tbl1_new__postgres_srv2__0;
--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, multi servers with SERVER OPTION
--
--Testcase 290:
MIGRATE TABLE tbl1 TO tbl1_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 3', table_name 'T 2');
-- new multitennant table created
--Testcase 291:
\det+
-- tbl1_new is multitenant table
--Testcase 292:
\d tbl1_new
--Testcase 293:
SELECT * FROM tbl1_new ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 294:
SELECT count(*) FROM tbl1_new__postgres_srv2__0;
--Testcase 295:
SELECT count(*) FROM tbl1_new__postgres_srv3__0;

--Testcase 296:
DROP FOREIGN TABLE tbl1_new;
--Testcase 297:
DROP DATASOURCE TABLE tbl1_new__postgres_srv2__0;
--Testcase 298:
DROP DATASOURCE TABLE tbl1_new__postgres_srv3__0;
--Testcase 299:
DROP FOREIGN TABLE tbl1_new__postgres_srv2__0;
--Testcase 300:
DROP FOREIGN TABLE tbl1_new__postgres_srv3__0;
-- clean-up
--Testcase 301:
DROP DATASOURCE TABLE tbl1__postgres_srv1__0;
--Testcase 302:
DROP DATASOURCE TABLE tbl1__postgres_srv2__0;
--Testcase 303:
DROP DATASOURCE TABLE tbl1__postgres_srv3__0;

--Testcase 304:
DROP FOREIGN TABLE tbl1__postgres_srv1__0;
--Testcase 305:
DROP FOREIGN TABLE tbl1__postgres_srv2__0;
--Testcase 306:
DROP FOREIGN TABLE tbl1__postgres_srv3__0;
--Testcase 307:
DROP FOREIGN TABLE tbl1;

----------------------------------------------------------
-- end testing for source structure tbl1
-- PGSpider Top Node -> 3 posgres data source
----------------------------------------------------------


----------------------------------------------------------
-- source structure tbl2
-- PGSpider Top Node -> pgspider_core_fdw -> PGSpider -> pgspider_core_fdw -> Postgres child node
----------------------------------------------------------
--Testcase 308:
CREATE PROCEDURE tbl2_init()
LANGUAGE SQL
AS $$
CREATE FOREIGN TABLE tbl2 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'tbl2',
	__spd_url text
) SERVER pgspider_core_srv;

--Testcase 309:
CREATE FOREIGN TABLE tbl2__pgspider_srv1__0 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl2_0',
    __spd_url text
) SERVER pgspider_srv1 OPTIONS (table_name 'tbl2');
$$;

--Testcase 310:
CALL tbl2_init();
--Testcase 311:
SELECT * FROM tbl2 ORDER BY c1;

--
-- MIGRATE without TO/REPLACE , single server without any SERVER OPTION
--
-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 312:
CREATE FOREIGN TABLE tbl2_datasource (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl2'
) SERVER postgres_srv1 OPTIONS (table_name 'tbl2');

-- ERROR: datasource table does not create yet
--Testcase 313:
SELECT * FROM tbl2_datasource ORDER BY c1;

--Testcase 314:
MIGRATE TABLE tbl2 SERVER postgres_srv1;

-- no new foreign table created
--Testcase 315:
\det+

-- OK: datasource table created
--Testcase 316:
SELECT * FROM tbl2_datasource ORDER BY c1;

-- clean-up
--Testcase 317:
DROP DATASOURCE TABLE tbl2_datasource;
--Testcase 318:
DROP FOREIGN TABLE tbl2_datasource;

--
-- MIGRATE without TO/REPLACE , single server with SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 319:
CREATE FOREIGN TABLE tbl2_datasource (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl2'
) SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'tbl2');

-- ERROR: datasource table does not create yet
--Testcase 320:
SELECT * FROM tbl2_datasource ORDER BY c1;

--Testcase 321:
MIGRATE TABLE tbl2 SERVER postgres_srv2 OPTIONS (schema_name 'S 2');

-- no new foreign table created
--Testcase 322:
\det+

-- OK: datasource table created
--Testcase 323:
SELECT * FROM tbl2_datasource ORDER BY c1;

-- clean-up
--Testcase 324:
DROP DATASOURCE TABLE tbl2_datasource;
--Testcase 325:
DROP FOREIGN TABLE tbl2_datasource;

--
-- MIGRATE without TO/REPLACE , multi servers with SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 326:
CREATE FOREIGN TABLE tbl2_datasource1 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl2'
) SERVER postgres_srv2 OPTIONS (schema_name 'S 1', table_name 'tbl2');

--Testcase 327:
CREATE FOREIGN TABLE tbl2_datasource2 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl2'
) SERVER postgres_srv3 OPTIONS (schema_name 'S 1', table_name 'tbl2');

-- ERROR: datasource table does not create yet
--Testcase 328:
SELECT * FROM tbl2_datasource1 ORDER BY c1;
--Testcase 329:
SELECT * FROM tbl2_datasource2 ORDER BY c1;

--Testcase 330:
MIGRATE TABLE tbl2 SERVER postgres_srv2 OPTIONS (schema_name 'S 1'), postgres_srv3 OPTIONS (schema_name 'S 1');

-- no new foreign table created
--Testcase 331:
\det+

-- OK: datasource table created
SELECT * FROM tbl2 ORDER BY c1, __spd_url;
--Testcase 332:
SELECT count(*) FROM tbl2_datasource1;
--Testcase 333:
SELECT count(*) FROM tbl2_datasource2;

-- clean-up
--Testcase 334:
DROP DATASOURCE TABLE tbl2_datasource1;
--Testcase 335:
DROP DATASOURCE TABLE tbl2_datasource2;
--Testcase 336:
DROP FOREIGN TABLE tbl2_datasource1;
--Testcase 337:
DROP FOREIGN TABLE tbl2_datasource2;

--
-- MIGRATE REPLACE , single server without any SERVER OPTION
--

--Testcase 338:
SELECT * FROM tbl2 ORDER BY c1;

--Testcase 339:
MIGRATE TABLE tbl2 REPLACE SERVER postgres_srv2;

-- tbl2 is replace by a foreign table
--Testcase 340:
\det+

-- tbl2 is postgres foreign table now.
--Testcase 341:
\d tbl2
--Testcase 342:
SELECT * FROM tbl2 ORDER BY c1;

--Testcase 343:
DROP DATASOURCE TABLE tbl2;
--Testcase 344:
DROP FOREIGN TABLE tbl2;

-- re-init tbl2 to execute test after
--Testcase 345:
CALL tbl2_init();

--
-- MIGRATE REPLACE , single server with SERVER OPTION
--
--Testcase 346:
SELECT * FROM tbl2 ORDER BY c1;
--Testcase 347:
MIGRATE TABLE tbl2 REPLACE SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');

-- tbl2 is replace by a foreign table
--Testcase 348:
\det+

-- tbl2 is postgres foreign table now.
--Testcase 349:
\d tbl2
--Testcase 350:
SELECT * FROM tbl2 ORDER BY c1;

--Testcase 351:
DROP DATASOURCE TABLE tbl2;
--Testcase 352:
DROP FOREIGN TABLE tbl2;
-- re-init tbl2 to execute test after
--Testcase 353:
CALL tbl2_init();

--
-- MIGRATE REPLACE , multi servers with SERVER OPTION
--
--Testcase 354:
SELECT * FROM tbl2 ORDER BY c1;
--Testcase 355:
MIGRATE TABLE tbl2 REPLACE SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 3', table_name 'T 2');

-- tbl2 is replace by a multitenant table
--Testcase 356:
\det+

-- tbl2 is multitenant table
--Testcase 357:
\d tbl2
--Testcase 358:
SELECT * FROM tbl2 ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 359:
SELECT count(*) FROM tbl2__postgres_srv2__0;
--Testcase 360:
SELECT count(*) FROM tbl2__postgres_srv3__0;

--Testcase 361:
DROP FOREIGN TABLE tbl2;
--Testcase 362:
DROP DATASOURCE TABLE tbl2__postgres_srv2__0;
--Testcase 363:
DROP DATASOURCE TABLE tbl2__postgres_srv3__0;
--Testcase 364:
DROP FOREIGN TABLE tbl2__postgres_srv2__0;
--Testcase 365:
DROP FOREIGN TABLE tbl2__postgres_srv3__0;

-- re-init tbl2 to execute test after
--Testcase 366:
CALL tbl2_init();

--
-- MIGRATE TO , single server without any SERVER OPTION
--
--Testcase 367:
SELECT * FROM tbl2 ORDER BY c1;
--Testcase 368:
MIGRATE TABLE tbl2 TO tbl2_new SERVER postgres_srv2;

-- new foreign table created
--Testcase 369:
\det+

-- tbl2_new is postgres foreign table
--Testcase 370:
\d tbl2_new
--Testcase 371:
SELECT * FROM tbl2_new ORDER BY c1;
--Testcase 372:
DROP DATASOURCE TABLE tbl2_new;
--Testcase 373:
DROP FOREIGN TABLE tbl2_new;

--
-- MIGRATE TO , single server with SERVER OPTION
--
--Testcase 374:
SELECT * FROM tbl2 ORDER BY c1;
--Testcase 375:
MIGRATE TABLE tbl2 TO tbl2_new SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');

-- new foreign table created
--Testcase 376:
\det+

-- tbl2_new is postgres foreign table
--Testcase 377:
\d tbl2_new
--Testcase 378:
SELECT * FROM tbl2_new ORDER BY c1;
--Testcase 379:
DROP DATASOURCE TABLE tbl2_new;
--Testcase 380:
DROP FOREIGN TABLE tbl2_new;

--
-- MIGRATE TO , multi servers with SERVER OPTION
--
--Testcase 381:
SELECT * FROM tbl2 ORDER BY c1;
--Testcase 382:
MIGRATE TABLE tbl2 TO tbl2_new SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 2', table_name 'T 2');

-- new multitenant table created
--Testcase 383:
\det+

-- tbl2_new is multitenant table
--Testcase 384:
\d tbl2_new
--Testcase 385:
SELECT * FROM tbl2_new ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 386:
SELECT count(*) FROM tbl2_new__postgres_srv2__0;
--Testcase 387:
SELECT count(*) FROM tbl2_new__postgres_srv3__0;

--Testcase 388:
DROP FOREIGN TABLE tbl2_new;
--Testcase 389:
DROP DATASOURCE TABLE tbl2_new__postgres_srv2__0;
--Testcase 390:
DROP DATASOURCE TABLE tbl2_new__postgres_srv3__0;
--Testcase 391:
DROP FOREIGN TABLE tbl2_new__postgres_srv2__0;
--Testcase 392:
DROP FOREIGN TABLE tbl2_new__postgres_srv3__0;

--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, single server without any SERVER OPTION
--
--Testcase 393:
SELECT * FROM tbl2 ORDER BY c1;
--Testcase 394:
MIGRATE TABLE tbl2 TO tbl2_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2;

-- new multitenant table created
--Testcase 395:
\det+

-- tbl2_new is multitenant table
--Testcase 396:
\d tbl2_new
--Testcase 397:
SELECT * FROM tbl2_new ORDER BY c1;
-- check data distribution
--Testcase 398:
SELECT * FROM tbl2_new__postgres_srv2__0 ORDER BY c1;

--Testcase 399:
DROP FOREIGN TABLE tbl2_new;
--Testcase 400:
DROP DATASOURCE TABLE tbl2_new__postgres_srv2__0;
--Testcase 401:
DROP FOREIGN TABLE tbl2_new__postgres_srv2__0;
--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, single server with SERVER OPTION
--
--Testcase 402:
SELECT * FROM tbl2 ORDER BY c1;
--Testcase 403:
MIGRATE TABLE tbl2 TO tbl2_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');

-- new multitenant table created
--Testcase 404:
\det+

-- tbl2_new is multitenant table
--Testcase 405:
\d tbl2_new
--Testcase 406:
SELECT * FROM tbl2_new ORDER BY c1;
-- check data distribution
--Testcase 407:
SELECT * FROM tbl2_new__postgres_srv2__0;

--Testcase 408:
DROP FOREIGN TABLE tbl2_new;
--Testcase 409:
DROP DATASOURCE TABLE tbl2_new__postgres_srv2__0;
--Testcase 410:
DROP FOREIGN TABLE tbl2_new__postgres_srv2__0;
--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, multi servers with SERVER OPTION
--
--Testcase 411:
MIGRATE TABLE tbl2 TO tbl2_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 3', table_name 'T 2');

-- new multitenant table created
--Testcase 412:
\det+

-- tbl2_new is multitenant table
--Testcase 413:
\d tbl2_new
--Testcase 414:
SELECT * FROM tbl2_new ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 415:
SELECT count(*) FROM tbl2_new__postgres_srv2__0;
--Testcase 416:
SELECT count(*) FROM tbl2_new__postgres_srv3__0;

--Testcase 417:
DROP FOREIGN TABLE tbl2_new;
--Testcase 418:
DROP DATASOURCE TABLE tbl2_new__postgres_srv2__0;
--Testcase 419:
DROP DATASOURCE TABLE tbl2_new__postgres_srv3__0;
--Testcase 420:
DROP FOREIGN TABLE tbl2_new__postgres_srv2__0;
--Testcase 421:
DROP FOREIGN TABLE tbl2_new__postgres_srv3__0;

-- clean-up
--Testcase 422:
DROP FOREIGN TABLE tbl2__pgspider_srv1__0;
--Testcase 423:
DROP FOREIGN TABLE tbl2;
----------------------------------------------------------
-- end source structure tbl2
-- PGSpider Top Node -> pgspider_core_fdw -> PGSpider -> pgspider_core_fdw -> Postgres child node
----------------------------------------------------------

----------------------------------------------------------
-- source structure tbl3
-- PGSpider Top Node --|-> Postgres child node
--                     |-> Postgres child node
--                     |-> pgspider_core_fdw -> PGSpider |-> pgspider_core_fdw |-> Postgres child node
--                                                                             |-> Postgres child node
----------------------------------------------------------
--Testcase 424:
CREATE PROCEDURE tbl3_init()
LANGUAGE SQL
AS $$
    CREATE FOREIGN TABLE tbl3 (
        c1 int NOT NULL,
        c2 int NOT NULL,
        c3 text,
        c4 timestamptz,
        c5 timestamp,
        c6 varchar(10),
        c7 char(10) default 'tbl2',
        __spd_url text
    ) SERVER pgspider_core_srv;

    -- postgres child node 1
--Testcase 425:
    CREATE FOREIGN TABLE IF NOT EXISTS tbl3__postgres_srv1__0 (
        c1 int NOT NULL,
        c2 int NOT NULL,
        c3 text,
        c4 timestamptz,
        c5 timestamp,
        c6 varchar(10),
        c7 char(10) default 'tbl1'
    ) SERVER postgres_srv1 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 426:
    CREATE DATASOURCE TABLE IF NOT EXISTS tbl3__postgres_srv1__0;

    -- postgres child node 2
--Testcase 427:
    CREATE FOREIGN TABLE IF NOT EXISTS tbl3__postgres_srv2__0 (
        c1 int NOT NULL,
        c2 int NOT NULL,
        c3 text,
        c4 timestamptz,
        c5 timestamp,
        c6 varchar(10),
        c7 char(10) default 'tbl1'
    ) SERVER postgres_srv2 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 428:
    CREATE DATASOURCE TABLE IF NOT EXISTS tbl3__postgres_srv2__0;

    -- pgspider child node1
--Testcase 429:
    CREATE FOREIGN TABLE tbl3__pgspider_srv1__0 (
        c1 int NOT NULL,
        c2 int NOT NULL,
        c3 text,
        c4 timestamptz,
        c5 timestamp,
        c6 varchar(10),
        c7 char(10) default 'tbl3_0',
        __spd_url text
    ) SERVER pgspider_srv1 OPTIONS (table_name 'tbl3');
$$;

--Testcase 430:
CALL tbl3_init();
-- init postgres note data
--Testcase 431:
INSERT INTO tbl3__postgres_srv1__0 VALUES (0, 0, 'foo', '2022/10/09 12:00:00 +08', '2022/10/09 12:00:00', '0', DEFAULT);
--Testcase 432:
INSERT INTO tbl3__postgres_srv1__0 VALUES (1, 1, 'bar', '2022/10/08 12:00:00 +08', '2022/10/08 12:00:00', '1', DEFAULT);
--Testcase 433:
INSERT INTO tbl3__postgres_srv2__0 VALUES (10, 0, 'foo', '2022/10/06 12:00:00 +08', '2022/10/06 12:00:00', '0', DEFAULT);
--Testcase 434:
INSERT INTO tbl3__postgres_srv2__0 VALUES (11, 1, 'bar', '2022/10/07 12:00:00 +08', '2022/10/07 12:00:00', '1', DEFAULT);

--Testcase 435:
SELECT * FROM tbl3 ORDER BY c1;
--
-- MIGRATE without TO/REPLACE , single server without any SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 436:
CREATE FOREIGN TABLE tbl3_datasource (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl3'
) SERVER postgres_srv1 OPTIONS (table_name 'tbl3');

-- ERROR: datasource table does not create yet
--Testcase 437:
SELECT * FROM tbl3_datasource ORDER BY c1;

--Testcase 438:
MIGRATE TABLE tbl3 SERVER postgres_srv1;

-- no new foreign table created
--Testcase 439:
\det+

-- OK: datasource table created
--Testcase 440:
SELECT * FROM tbl3_datasource ORDER BY c1;

-- clean-up
--Testcase 441:
DROP DATASOURCE TABLE tbl3_datasource;
--Testcase 442:
DROP FOREIGN TABLE tbl3_datasource;

--
-- MIGRATE without TO/REPLACE , single server with SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 443:
CREATE FOREIGN TABLE tbl3_datasource (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl3'
) SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'tbl3');

-- ERROR: datasource table does not create yet
--Testcase 444:
SELECT * FROM tbl3_datasource ORDER BY c1;

--Testcase 445:
MIGRATE TABLE tbl3 SERVER postgres_srv2 OPTIONS (schema_name 'S 2');

-- no new foreign table created
--Testcase 446:
\det+

-- OK: datasource table created
--Testcase 447:
SELECT * FROM tbl3_datasource ORDER BY c1;

-- clean-up
--Testcase 448:
DROP DATASOURCE TABLE tbl3_datasource;
--Testcase 449:
DROP FOREIGN TABLE tbl3_datasource;

--
-- MIGRATE without TO/REPLACE , multi servers with SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 450:
CREATE FOREIGN TABLE tbl3_datasource1 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl3'
) SERVER postgres_srv2 OPTIONS (schema_name 'S 1', table_name 'tbl3');

--Testcase 451:
CREATE FOREIGN TABLE tbl3_datasource2 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl3'
) SERVER postgres_srv3 OPTIONS (schema_name 'S 1', table_name 'tbl3');

-- ERROR: datasource table does not create yet
--Testcase 452:
SELECT * FROM tbl3_datasource1 ORDER BY c1;
--Testcase 453:
SELECT * FROM tbl3_datasource2 ORDER BY c1;

--Testcase 454:
MIGRATE TABLE tbl3 SERVER postgres_srv2 OPTIONS (schema_name 'S 1'), postgres_srv3 OPTIONS (schema_name 'S 1');

-- no new foreign table created
--Testcase 455:
\det+

-- OK: datasource table created
SELECT * FROM tbl3 ORDER BY c1, __spd_url;
--Testcase 456:
SELECT count(*) FROM tbl3_datasource1;
--Testcase 457:
SELECT count(*) FROM tbl3_datasource2;

-- clean-up
--Testcase 458:
DROP DATASOURCE TABLE tbl3_datasource1;
--Testcase 459:
DROP DATASOURCE TABLE tbl3_datasource2;
--Testcase 460:
DROP FOREIGN TABLE tbl3_datasource1;
--Testcase 461:
DROP FOREIGN TABLE tbl3_datasource2;

--
-- MIGRATE REPLACE , single server without any SERVER OPTION
--

--Testcase 462:
SELECT * FROM tbl3 ORDER BY c1;

--Testcase 463:
MIGRATE TABLE tbl3 REPLACE SERVER postgres_srv2;

-- tbl3 is replaced by a foreign table
--Testcase 464:
\det+

-- tbl3 is postgres foreign table now.
--Testcase 465:
\d tbl3
--Testcase 466:
SELECT * FROM tbl3 ORDER BY c1;

--Testcase 467:
DROP DATASOURCE TABLE tbl3;
--Testcase 468:
DROP FOREIGN TABLE tbl3;

-- re-init tbl3 to execute test after
--Testcase 469:
CALL tbl3_init();

--
-- MIGRATE REPLACE , single server with SERVER OPTION
--
--Testcase 470:
SELECT * FROM tbl3 ORDER BY c1;
--Testcase 471:
MIGRATE TABLE tbl3 REPLACE SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');

-- tbl3 is replaced by a foreign table
--Testcase 472:
\det+

-- tbl3 is postgres foreign table now.
--Testcase 473:
\d tbl3
--Testcase 474:
SELECT * FROM tbl3 ORDER BY c1;

--Testcase 475:
DROP DATASOURCE TABLE tbl3;
--Testcase 476:
DROP FOREIGN TABLE tbl3;
-- re-init tbl3 to execute test after
--Testcase 477:
CALL tbl3_init();

--
-- MIGRATE REPLACE , multi servers with SERVER OPTION
--
--Testcase 478:
SELECT * FROM tbl3 ORDER BY c1;
--Testcase 479:
MIGRATE TABLE tbl3 REPLACE SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 3', table_name 'T 2');

-- tbl3 is replaced by a multitenant table
--Testcase 480:
\det+

-- tbl3 is multitenant table
--Testcase 481:
\d tbl3
--Testcase 482:
SELECT * FROM tbl3 ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 483:
SELECT count(*) FROM tbl3__postgres_srv2__0;
--Testcase 484:
SELECT count(*) FROM tbl3__postgres_srv3__0;

--Testcase 485:
DROP FOREIGN TABLE tbl3;
--Testcase 486:
DROP DATASOURCE TABLE tbl3__postgres_srv2__0;
--Testcase 487:
DROP DATASOURCE TABLE tbl3__postgres_srv3__0;
--Testcase 488:
DROP FOREIGN TABLE tbl3__postgres_srv2__0;
--Testcase 489:
DROP FOREIGN TABLE tbl3__postgres_srv3__0;

-- re-init tbl3 to execute test after
--Testcase 490:
CALL tbl3_init();

--
-- MIGRATE TO , single server without any SERVER OPTION
--
--Testcase 491:
SELECT * FROM tbl3 ORDER BY c1;
--Testcase 492:
MIGRATE TABLE tbl3 TO tbl3_new SERVER postgres_srv2;

-- new foreign table created
--Testcase 493:
\det+

-- tbl3_new is postgres foreign table
--Testcase 494:
\d tbl3_new
--Testcase 495:
SELECT * FROM tbl3_new ORDER BY c1;
--Testcase 496:
DROP DATASOURCE TABLE tbl3_new;
--Testcase 497:
DROP FOREIGN TABLE tbl3_new;

--
-- MIGRATE TO , single server with SERVER OPTION
--
--Testcase 498:
SELECT * FROM tbl3 ORDER BY c1;
--Testcase 499:
MIGRATE TABLE tbl3 TO tbl3_new SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');

-- new foreign table created
--Testcase 500:
\det+

-- tbl3_new is postgres foreign table
--Testcase 501:
\d tbl3_new
--Testcase 502:
SELECT * FROM tbl3_new ORDER BY c1;
--Testcase 503:
DROP DATASOURCE TABLE tbl3_new;
--Testcase 504:
DROP FOREIGN TABLE tbl3_new;

--
-- MIGRATE TO , multi servers with SERVER OPTION
--
--Testcase 505:
SELECT * FROM tbl3 ORDER BY c1;
--Testcase 506:
MIGRATE TABLE tbl3 TO tbl3_new SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 2', table_name 'T 2');

-- new multitenant table created
--Testcase 507:
\det+

-- tbl3_new is multitenant table
--Testcase 508:
\d tbl3_new
--Testcase 509:
SELECT * FROM tbl3_new ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 510:
SELECT count(*) FROM tbl3_new__postgres_srv2__0;
--Testcase 511:
SELECT count(*) FROM tbl3_new__postgres_srv3__0;

--Testcase 512:
DROP FOREIGN TABLE tbl3_new;
--Testcase 513:
DROP DATASOURCE TABLE tbl3_new__postgres_srv2__0;
--Testcase 514:
DROP DATASOURCE TABLE tbl3_new__postgres_srv3__0;
--Testcase 515:
DROP FOREIGN TABLE tbl3_new__postgres_srv2__0;
--Testcase 516:
DROP FOREIGN TABLE tbl3_new__postgres_srv3__0;

--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, single server without any SERVER OPTION
--
--Testcase 517:
SELECT * FROM tbl3 ORDER BY c1;
--Testcase 518:
MIGRATE TABLE tbl3 TO tbl3_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2;

-- new multitenant table created
--Testcase 519:
\det+
-- tbl3_new is multitenant table
--Testcase 520:
\d tbl3_new
--Testcase 521:
SELECT * FROM tbl3_new ORDER BY c1;
-- check data distribution
--Testcase 522:
SELECT * FROM tbl3_new__postgres_srv2__0 ORDER BY c1;

--Testcase 523:
DROP FOREIGN TABLE tbl3_new;
--Testcase 524:
DROP DATASOURCE TABLE tbl3_new__postgres_srv2__0;
--Testcase 525:
DROP FOREIGN TABLE tbl3_new__postgres_srv2__0;
--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, single server with SERVER OPTION
--
--Testcase 526:
SELECT * FROM tbl3 ORDER BY c1;
--Testcase 527:
MIGRATE TABLE tbl3 TO tbl3_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');
-- new multitenant table created
--Testcase 528:
\det+
-- tbl3_new is multitenant table
--Testcase 529:
\d tbl3_new
--Testcase 530:
SELECT * FROM tbl3_new ORDER BY c1;
-- check data distribution
--Testcase 531:
SELECT * FROM tbl3_new__postgres_srv2__0 ORDER BY c1;

--Testcase 532:
DROP FOREIGN TABLE tbl3_new;
--Testcase 533:
DROP DATASOURCE TABLE tbl3_new__postgres_srv2__0;
--Testcase 534:
DROP FOREIGN TABLE tbl3_new__postgres_srv2__0;
--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, multi servers with SERVER OPTION
--
--Testcase 535:
MIGRATE TABLE tbl3 TO tbl3_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 3', table_name 'T 2');
-- new multitenant table created
--Testcase 536:
\det+
-- tbl3_new is multitenant table
--Testcase 537:
\d tbl3_new
--Testcase 538:
SELECT * FROM tbl3_new ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 539:
SELECT count(*) FROM tbl3_new__postgres_srv2__0;
--Testcase 540:
SELECT count(*) FROM tbl3_new__postgres_srv3__0;

--Testcase 541:
DROP FOREIGN TABLE tbl3_new;
--Testcase 542:
DROP DATASOURCE TABLE tbl3_new__postgres_srv2__0;
--Testcase 543:
DROP DATASOURCE TABLE tbl3_new__postgres_srv3__0;
--Testcase 544:
DROP FOREIGN TABLE tbl3_new__postgres_srv2__0;
--Testcase 545:
DROP FOREIGN TABLE tbl3_new__postgres_srv3__0;

-- clean-up
--Testcase 546:
DROP DATASOURCE TABLE tbl3__postgres_srv1__0;
--Testcase 547:
DROP DATASOURCE TABLE tbl3__postgres_srv2__0;
--Testcase 548:
DROP FOREIGN TABLE tbl3__postgres_srv1__0;
--Testcase 549:
DROP FOREIGN TABLE tbl3__postgres_srv2__0;

--Testcase 550:
DROP FOREIGN TABLE tbl3__pgspider_srv1__0;
--Testcase 551:
DROP FOREIGN TABLE tbl3;
----------------------------------------------------------
-- end source structure tbl3
-- PGSpider Top Node --|-> Postgres child node
--                     |-> Postgres child node
--                     |-> pgspider_core_fdw -> PGSpider |-> pgspider_core_fdw  |-> Postgres child node
--                                                                             |-> Postgres child node
----------------------------------------------------------

----------------------------------------------------------
-- source table 'replace'
-- table name same as keyword
----------------------------------------------------------
--Testcase 552:
CREATE PROCEDURE replace_init()
LANGUAGE SQL
AS $$
    CREATE FOREIGN TABLE IF NOT EXISTS replace (
            c1 int NOT NULL,
            c2 int NOT NULL,
            c3 text,
            c4 timestamptz,
            c5 timestamp,
            c6 varchar(10),
            c7 char(10) default 'tbl1'
        ) SERVER postgres_srv1 OPTIONS (schema_name 'S 1', table_name 'replace');
--Testcase 553:
    CREATE DATASOURCE TABLE IF NOT EXISTS replace;
$$;

--Testcase 554:
CALL replace_init();

--Testcase 555:
INSERT INTO replace
    SELECT id,
            id % 10,
            to_char(id, 'FM00000'),
            '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
            '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
            id % 10,
            id % 10
    FROM generate_series(1, 10) id;
--
-- MIGRATE without TO/REPLACE , single server without any SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 556:
CREATE FOREIGN TABLE replace_datasource (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'replace'
) SERVER postgres_srv1 OPTIONS (table_name 'replace');

-- ERROR: datasource table does not create yet
--Testcase 557:
SELECT * FROM replace_datasource ORDER BY c1;

--Testcase 558:
MIGRATE TABLE replace SERVER postgres_srv1;

-- no new foreign table created
--Testcase 559:
\det+

-- OK: datasource table created
--Testcase 560:
SELECT * FROM replace_datasource ORDER BY c1;

-- clean-up
--Testcase 561:
DROP DATASOURCE TABLE replace_datasource;
--Testcase 562:
DROP FOREIGN TABLE replace_datasource;

--
-- MIGRATE without TO/REPLACE , single server with SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 563:
CREATE FOREIGN TABLE replace_datasource (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'replace'
) SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'replace');

-- ERROR: datasource table does not create yet
--Testcase 564:
SELECT * FROM replace_datasource ORDER BY c1;

--Testcase 565:
MIGRATE TABLE replace SERVER postgres_srv2 OPTIONS (schema_name 'S 2');

-- no new foreign table created
--Testcase 566:
\det+

-- OK: datasource table created
--Testcase 567:
SELECT * FROM replace_datasource ORDER BY c1;

-- clean-up
--Testcase 568:
DROP DATASOURCE TABLE replace_datasource;
--Testcase 569:
DROP FOREIGN TABLE replace_datasource;

--
-- MIGRATE without TO/REPLACE , multi servers with SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 570:
CREATE FOREIGN TABLE replace_datasource1 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'replace'
) SERVER postgres_srv2 OPTIONS (schema_name 'S 1', table_name 'replace');

--Testcase 571:
CREATE FOREIGN TABLE replace_datasource2 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'replace'
) SERVER postgres_srv3 OPTIONS (schema_name 'S 1', table_name 'replace');

-- ERROR: datasource table does not create yet
--Testcase 572:
SELECT * FROM replace_datasource1 ORDER BY c1;
--Testcase 573:
SELECT * FROM replace_datasource2 ORDER BY c1;

--Testcase 574:
MIGRATE TABLE replace SERVER postgres_srv2 OPTIONS (schema_name 'S 1'), postgres_srv3 OPTIONS (schema_name 'S 1');

-- no new foreign table created
--Testcase 575:
\det+

-- OK: datasource table created
--Testcase 576:
SELECT * FROM replace_datasource1 ORDER BY c1;
--Testcase 577:
SELECT * FROM replace_datasource2 ORDER BY c1;

-- clean-up
--Testcase 578:
DROP DATASOURCE TABLE replace_datasource1;
--Testcase 579:
DROP DATASOURCE TABLE replace_datasource2;
--Testcase 580:
DROP FOREIGN TABLE replace_datasource1;
--Testcase 581:
DROP FOREIGN TABLE replace_datasource2;

--
-- MIGRATE REPLACE , single server without any SERVER OPTION
--

--Testcase 582:
SELECT * FROM replace ORDER BY c1;

--Testcase 583:
MIGRATE TABLE replace REPLACE SERVER postgres_srv2;

-- no new foreign table created
--Testcase 584:
\det+

-- replace is postgres foreign table now.
--Testcase 585:
\d replace
--Testcase 586:
SELECT * FROM replace ORDER BY c1;

--Testcase 587:
DROP DATASOURCE TABLE replace;
--Testcase 588:
DROP FOREIGN TABLE replace;

-- re-init replace to execute test after
--Testcase 589:
CALL replace_init();

--
-- MIGRATE REPLACE , single server with SERVER OPTION
--
--Testcase 590:
SELECT * FROM replace ORDER BY c1;
--Testcase 591:
MIGRATE TABLE replace REPLACE SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');

-- new foreign table created
--Testcase 592:
\det+

-- replace is postgres foreign table now.
--Testcase 593:
\d replace
--Testcase 594:
SELECT * FROM replace ORDER BY c1;

--Testcase 595:
DROP DATASOURCE TABLE replace;
--Testcase 596:
DROP FOREIGN TABLE replace;
-- re-init replace to execute test after
--Testcase 597:
CALL replace_init();

--
-- MIGRATE REPLACE , multi servers with SERVER OPTION
--
--Testcase 598:
SELECT * FROM replace ORDER BY c1;
--Testcase 599:
MIGRATE TABLE replace REPLACE SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 3', table_name 'T 2');

-- new foreign table created
--Testcase 600:
\det+

-- replace is multitenant table
--Testcase 601:
\d replace
--Testcase 602:
SELECT * FROM replace ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 603:
SELECT count(*) FROM replace__postgres_srv2__0;
--Testcase 604:
SELECT count(*) FROM replace__postgres_srv3__0;

--Testcase 605:
DROP FOREIGN TABLE replace;
--Testcase 606:
DROP DATASOURCE TABLE replace__postgres_srv2__0;
--Testcase 607:
DROP DATASOURCE TABLE replace__postgres_srv3__0;
--Testcase 608:
DROP FOREIGN TABLE replace__postgres_srv2__0;
--Testcase 609:
DROP FOREIGN TABLE replace__postgres_srv3__0;

-- re-init replace to execute test after
--Testcase 610:
CALL replace_init();

--
-- MIGRATE TO , single server without any SERVER OPTION
--
--Testcase 611:
SELECT * FROM replace ORDER BY c1;
--Testcase 612:
MIGRATE TABLE replace TO replace_new SERVER postgres_srv2;

-- new foreign table created
--Testcase 613:
\det+

-- replace_new is postgres foreign table
--Testcase 614:
\d replace_new
--Testcase 615:
SELECT * FROM replace_new ORDER BY c1;
--Testcase 616:
DROP DATASOURCE TABLE replace_new;
--Testcase 617:
DROP FOREIGN TABLE replace_new;

--
-- MIGRATE TO , single server with SERVER OPTION
--
--Testcase 618:
SELECT * FROM replace ORDER BY c1;
--Testcase 619:
MIGRATE TABLE replace TO replace_new SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');

-- new foreign table created
--Testcase 620:
\det+

-- replace_new is postgres foreign table
--Testcase 621:
\d replace_new
--Testcase 622:
SELECT * FROM replace_new ORDER BY c1;
--Testcase 623:
DROP DATASOURCE TABLE replace_new;
--Testcase 624:
DROP FOREIGN TABLE replace_new;

--
-- MIGRATE TO , multi servers with SERVER OPTION
--
--Testcase 625:
SELECT * FROM replace ORDER BY c1;
--Testcase 626:
MIGRATE TABLE replace TO replace_new SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 2', table_name 'T 2');

-- new multitenant table created
--Testcase 627:
\det+

-- replace_new is multitenant table
--Testcase 628:
\d replace_new
--Testcase 629:
SELECT * FROM replace_new ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 630:
SELECT count(*) FROM replace_new__postgres_srv2__0;
--Testcase 631:
SELECT count(*) FROM replace_new__postgres_srv3__0;

--Testcase 632:
DROP FOREIGN TABLE replace_new;
--Testcase 633:
DROP DATASOURCE TABLE replace_new__postgres_srv2__0;
--Testcase 634:
DROP DATASOURCE TABLE replace_new__postgres_srv3__0;
--Testcase 635:
DROP FOREIGN TABLE replace_new__postgres_srv2__0;
--Testcase 636:
DROP FOREIGN TABLE replace_new__postgres_srv3__0;

--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, single server without any SERVER OPTION
--
--Testcase 637:
SELECT * FROM replace ORDER BY c1;
--Testcase 638:
MIGRATE TABLE replace TO replace_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2;
-- new multitenant table created
--Testcase 639:
\det+
-- replace_new is multitenant table
--Testcase 640:
\d replace_new
--Testcase 641:
SELECT * FROM replace_new ORDER BY c1;
-- check data distribution
--Testcase 642:
SELECT * FROM replace_new__postgres_srv2__0 ORDER BY c1;

--Testcase 643:
DROP FOREIGN TABLE replace_new;
--Testcase 644:
DROP DATASOURCE TABLE replace_new__postgres_srv2__0;
--Testcase 645:
DROP FOREIGN TABLE replace_new__postgres_srv2__0;
--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, single server with SERVER OPTION
--
--Testcase 646:
SELECT * FROM replace ORDER BY c1;
--Testcase 647:
MIGRATE TABLE replace TO replace_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2');
-- new multitenant table created
--Testcase 648:
\det+
-- replace_new is multitenant table
--Testcase 649:
\d replace_new
--Testcase 650:
SELECT * FROM replace_new ORDER BY c1;
-- check data distribution
--Testcase 651:
SELECT * FROM replace_new__postgres_srv2__0 ORDER BY c1;

--Testcase 652:
DROP FOREIGN TABLE replace_new;
--Testcase 653:
DROP DATASOURCE TABLE replace_new__postgres_srv2__0;
--Testcase 654:
DROP FOREIGN TABLE replace_new__postgres_srv2__0;
--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, multi servers with SERVER OPTION
--
--Testcase 655:
MIGRATE TABLE replace TO replace_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_srv2 OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 3', table_name 'T 2');
-- new multitenant table created
--Testcase 656:
\det+
-- replace_new is multitenant table
--Testcase 657:
\d replace_new
--Testcase 658:
SELECT * FROM replace_new ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 659:
SELECT count(*) FROM replace_new__postgres_srv2__0;
--Testcase 660:
SELECT count(*) FROM replace_new__postgres_srv3__0;

--Testcase 661:
DROP FOREIGN TABLE replace_new;
--Testcase 662:
DROP DATASOURCE TABLE replace_new__postgres_srv2__0;
--Testcase 663:
DROP DATASOURCE TABLE replace_new__postgres_srv3__0;
--Testcase 664:
DROP FOREIGN TABLE replace_new__postgres_srv2__0;
--Testcase 665:
DROP FOREIGN TABLE replace_new__postgres_srv3__0;
-- clean-up
--Testcase 666:
DROP DATASOURCE TABLE replace;
--Testcase 667:
DROP FOREIGN TABLE replace;


----------------------------------------------------------
-- source structure tbl4
-- PGSpider Top Node -> 3 posgres data source
----------------------------------------------------------
--Testcase 668:
CREATE SERVER replace FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host '127.0.0.1',
        port '25432',
        dbname 'postgres');
--Testcase 669:
CREATE USER MAPPING FOR public SERVER replace
    OPTIONS (user 'postgres', password 'postgres');

--Testcase 670:
CREATE PROCEDURE tbl4_init()
LANGUAGE SQL
AS $$
    CREATE FOREIGN TABLE IF NOT EXISTS tbl4 (
        c1 int NOT NULL,
        c2 int NOT NULL,
        c3 text,
        c4 timestamptz,
        c5 timestamp,
        c6 varchar(10),
        c7 char(10) default 'tbl4',
        __spd_url text
    ) SERVER pgspider_core_srv;

--Testcase 671:
    CREATE FOREIGN TABLE IF NOT EXISTS tbl4__postgres_srv1__0 (
        c1 int NOT NULL,
        c2 int NOT NULL,
        c3 text,
        c4 timestamptz,
        c5 timestamp,
        c6 varchar(10),
        c7 char(10) default 'tbl4'
    ) SERVER postgres_srv1 OPTIONS (schema_name 'S 1', table_name 'T 4');
--Testcase 672:
    CREATE DATASOURCE TABLE IF NOT EXISTS tbl4__postgres_srv1__0;

--Testcase 673:
    CREATE FOREIGN TABLE IF NOT EXISTS tbl4__postgres_srv2__0 (
        c1 int NOT NULL,
        c2 int NOT NULL,
        c3 text,
        c4 timestamptz,
        c5 timestamp,
        c6 varchar(10),
        c7 char(10) default 'tbl4'
    ) SERVER postgres_srv2 OPTIONS (schema_name 'S 1', table_name 'T 4');
--Testcase 674:
    CREATE DATASOURCE TABLE IF NOT EXISTS tbl4__postgres_srv2__0;
$$;

--Testcase 675:
CALL tbl4_init();

-- Init data
--Testcase 676:
INSERT INTO tbl4__postgres_srv1__0
    SELECT id,
            id % 10,
            to_char(id, 'FM00000'),
            '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
            '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
            id % 10,
            id % 10
    FROM generate_series(1, 5) id;

--Testcase 677:
INSERT INTO tbl4__postgres_srv2__0
    SELECT id,
            id % 10,
            to_char(id, 'FM00000'),
            '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
            '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
            id % 10,
            id % 10
    FROM generate_series(6, 10) id;

--Testcase 678:
SELECT * FROM tbl4 ORDER BY c1;

--
-- MIGRATE without TO/REPLACE , single server without any SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 679:
CREATE FOREIGN TABLE tbl4_datasource (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl4'
) SERVER postgres_srv1 OPTIONS (table_name 'tbl4');

-- ERROR: datasource table does not create yet
--Testcase 680:
SELECT * FROM tbl4_datasource ORDER BY c1;

--Testcase 681:
MIGRATE TABLE tbl4 SERVER postgres_srv1;

-- no new foreign table created
--Testcase 682:
\det+

-- OK: datasource table created
--Testcase 683:
SELECT * FROM tbl4_datasource ORDER BY c1;

-- clean-up
--Testcase 684:
DROP DATASOURCE TABLE tbl4_datasource;
--Testcase 685:
DROP FOREIGN TABLE tbl4_datasource;

--
-- MIGRATE without TO/REPLACE , single server with SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 686:
CREATE FOREIGN TABLE tbl4_datasource (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl4'
) SERVER replace OPTIONS (schema_name 'S 2', table_name 'tbl4');

-- ERROR: datasource table does not create yet
--Testcase 687:
SELECT * FROM tbl4_datasource ORDER BY c1;

--Testcase 688:
MIGRATE TABLE tbl4 SERVER replace OPTIONS (schema_name 'S 2');

-- no new foreign table created
--Testcase 689:
\det+

-- OK: datasource table created
--Testcase 690:
SELECT * FROM tbl4_datasource ORDER BY c1;

-- clean-up
--Testcase 691:
DROP DATASOURCE TABLE tbl4_datasource;
--Testcase 692:
DROP FOREIGN TABLE tbl4_datasource;

--
-- MIGRATE without TO/REPLACE , multi servers with SERVER OPTION
--

-- Only datasource table will be created, so using an temporary foreign table to check this data
--Testcase 693:
CREATE FOREIGN TABLE tbl4_datasource1 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl4'
) SERVER replace OPTIONS (schema_name 'S 1', table_name 'tbl4');

--Testcase 694:
CREATE FOREIGN TABLE tbl4_datasource2 (
    c1 int NOT NULL,
    c2 int NOT NULL,
    c3 text,
    c4 timestamptz,
    c5 timestamp,
    c6 varchar(10),
    c7 char(10) default 'tbl4'
) SERVER postgres_srv3 OPTIONS (schema_name 'S 1', table_name 'tbl4');

-- ERROR: datasource table does not create yet
--Testcase 695:
SELECT * FROM tbl4_datasource1 ORDER BY c1;
--Testcase 696:
SELECT * FROM tbl4_datasource2 ORDER BY c1;

--Testcase 697:
MIGRATE TABLE tbl4 SERVER replace OPTIONS (schema_name 'S 1'), postgres_srv3 OPTIONS (schema_name 'S 1');

-- no new foreign table created
--Testcase 698:
\det+

-- OK: datasource table created
SELECT * FROM tbl4 ORDER BY c1, __spd_url;
--Testcase 699:
SELECT count(*) FROM tbl4_datasource1;
--Testcase 700:
SELECT count(*) FROM tbl4_datasource2;

-- clean-up
--Testcase 701:
DROP DATASOURCE TABLE tbl4_datasource1;
--Testcase 702:
DROP DATASOURCE TABLE tbl4_datasource2;
--Testcase 703:
DROP FOREIGN TABLE tbl4_datasource1;
--Testcase 704:
DROP FOREIGN TABLE tbl4_datasource2;

--
-- MIGRATE REPLACE , single server without any SERVER OPTION
--

--Testcase 705:
SELECT * FROM tbl4 ORDER BY c1;

--Testcase 706:
MIGRATE TABLE tbl4 REPLACE SERVER replace;

-- new foreign table created
--Testcase 707:
\det+

-- tbl4 is postgres foreign table now.
--Testcase 708:
\d tbl4
--Testcase 709:
SELECT * FROM tbl4 ORDER BY c1;

--Testcase 710:
DROP DATASOURCE TABLE tbl4;
--Testcase 711:
DROP FOREIGN TABLE tbl4;

-- re-init tbl4 to execute test after
--Testcase 712:
CALL tbl4_init();

--
-- MIGRATE REPLACE , single server with SERVER OPTION
--
--Testcase 713:
SELECT * FROM tbl4 ORDER BY c1;
--Testcase 714:
MIGRATE TABLE tbl4 REPLACE SERVER replace OPTIONS (schema_name 'S 2', table_name 'T 2');

-- new foreign table created
--Testcase 715:
\det+

-- tbl4 is postgres foreign table now.
--Testcase 716:
\d tbl4
--Testcase 717:
SELECT * FROM tbl4 ORDER BY c1;

--Testcase 718:
DROP DATASOURCE TABLE tbl4;
--Testcase 719:
DROP FOREIGN TABLE tbl4;
-- re-init tbl4 to execute test after
--Testcase 720:
CALL tbl4_init();

--
-- MIGRATE REPLACE , multi servers with SERVER OPTION
--
--Testcase 721:
SELECT * FROM tbl4 ORDER BY c1;
--Testcase 722:
MIGRATE TABLE tbl4 REPLACE SERVER replace OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 3', table_name 'T 2');

-- new multitenant table created
--Testcase 723:
\det+

-- tbl4 is multitenant table
--Testcase 724:
\d tbl4
--Testcase 725:
SELECT * FROM tbl4 ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 726:
SELECT count(*) FROM tbl4__replace__0;
--Testcase 727:
SELECT count(*) FROM tbl4__postgres_srv3__0;

--Testcase 728:
DROP FOREIGN TABLE tbl4;
--Testcase 729:
DROP DATASOURCE TABLE tbl4__replace__0;
--Testcase 730:
DROP DATASOURCE TABLE tbl4__postgres_srv3__0;
--Testcase 731:
DROP FOREIGN TABLE tbl4__replace__0;
--Testcase 732:
DROP FOREIGN TABLE tbl4__postgres_srv3__0;

-- re-init tbl4 to execute test after
--Testcase 733:
CALL tbl4_init();

--
-- MIGRATE TO , single server without any SERVER OPTION
--
--Testcase 734:
SELECT * FROM tbl4 ORDER BY c1;
--Testcase 735:
MIGRATE TABLE tbl4 TO tbl4_new SERVER replace;

-- new foreign table created
--Testcase 736:
\det+

-- tbl4_new is postgres foreign table
--Testcase 737:
\d tbl4_new
--Testcase 738:
SELECT * FROM tbl4_new ORDER BY c1;
--Testcase 739:
DROP DATASOURCE TABLE tbl4_new;
--Testcase 740:
DROP FOREIGN TABLE tbl4_new;

--
-- MIGRATE TO , single server with SERVER OPTION
--
--Testcase 741:
SELECT * FROM tbl4 ORDER BY c1;
--Testcase 742:
MIGRATE TABLE tbl4 TO tbl4_new SERVER replace OPTIONS (schema_name 'S 2', table_name 'T 2');

-- new foreign table created
--Testcase 743:
\det+

-- tbl4_new is postgres foreign table
--Testcase 744:
\d tbl4_new
--Testcase 745:
SELECT * FROM tbl4_new ORDER BY c1;
--Testcase 746:
DROP DATASOURCE TABLE tbl4_new;
--Testcase 747:
DROP FOREIGN TABLE tbl4_new;

--
-- MIGRATE TO , multi servers with SERVER OPTION
--
--Testcase 748:
SELECT * FROM tbl4 ORDER BY c1;
--Testcase 749:
MIGRATE TABLE tbl4 TO tbl4_new SERVER replace OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 2', table_name 'T 2');

-- new multitenant table created
--Testcase 750:
\det+

-- tbl4_new is multitenant table
--Testcase 751:
\d tbl4_new
--Testcase 752:
SELECT * FROM tbl4_new ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 753:
SELECT count(*) FROM tbl4_new__replace__0;
--Testcase 754:
SELECT count(*) FROM tbl4_new__postgres_srv3__0;

--Testcase 755:
DROP FOREIGN TABLE tbl4_new;
--Testcase 756:
DROP DATASOURCE TABLE tbl4_new__replace__0;
--Testcase 757:
DROP DATASOURCE TABLE tbl4_new__postgres_srv3__0;
--Testcase 758:
DROP FOREIGN TABLE tbl4_new__replace__0;
--Testcase 759:
DROP FOREIGN TABLE tbl4_new__postgres_srv3__0;

--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, single server without any SERVER OPTION
--
--Testcase 760:
SELECT * FROM tbl4 ORDER BY c1;
--Testcase 761:
MIGRATE TABLE tbl4 TO tbl4_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER replace;
-- new multitenant table created
--Testcase 762:
\det+
-- tbl4_new is multitenant table
--Testcase 763:
\d tbl4_new
--Testcase 764:
SELECT * FROM tbl4_new ORDER BY c1;
-- check data distribution
--Testcase 765:
SELECT * FROM tbl4_new__replace__0 ORDER BY c1;

--Testcase 766:
DROP FOREIGN TABLE tbl4_new;
--Testcase 767:
DROP DATASOURCE TABLE tbl4_new__replace__0;
--Testcase 768:
DROP FOREIGN TABLE tbl4_new__replace__0;
--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, single server with SERVER OPTION
--
--Testcase 769:
SELECT * FROM tbl4 ORDER BY c1;
--Testcase 770:
MIGRATE TABLE tbl4 TO tbl4_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER replace OPTIONS (schema_name 'S 2', table_name 'T 2');
-- new multitenant table created
--Testcase 771:
\det+
-- tbl4_new is multitenant table
--Testcase 772:
\d tbl4_new
--Testcase 773:
SELECT * FROM tbl4_new ORDER BY c1;
-- check data distribution
--Testcase 774:
SELECT * FROM tbl4_new__replace__0 ORDER BY c1;

--Testcase 775:
DROP FOREIGN TABLE tbl4_new;
--Testcase 776:
DROP DATASOURCE TABLE tbl4_new__replace__0;
--Testcase 777:
DROP FOREIGN TABLE tbl4_new__replace__0;
--
-- MIGRATE TO has USE_MULTITENANT_SERVER option, multi servers with SERVER OPTION
--
--Testcase 778:
MIGRATE TABLE tbl4 TO tbl4_new OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER replace OPTIONS (schema_name 'S 2', table_name 'T 2'), postgres_srv3 OPTIONS (schema_name 'S 3', table_name 'T 2');
-- new multitenant table created
--Testcase 779:
\det+
-- tbl4_new is multitenant table
--Testcase 780:
\d tbl4_new
--Testcase 781:
SELECT * FROM tbl4_new ORDER BY c1, __spd_url;
-- check data distribution
--Testcase 782:
SELECT count(*) FROM tbl4_new__replace__0;
--Testcase 783:
SELECT count(*) FROM tbl4_new__postgres_srv3__0;

--Testcase 784:
DROP FOREIGN TABLE tbl4_new;
--Testcase 785:
DROP DATASOURCE TABLE tbl4_new__replace__0;
--Testcase 786:
DROP DATASOURCE TABLE tbl4_new__postgres_srv3__0;
--Testcase 787:
DROP FOREIGN TABLE tbl4_new__replace__0;
--Testcase 788:
DROP FOREIGN TABLE tbl4_new__postgres_srv3__0;
-- clean-up
--Testcase 789:
DROP DATASOURCE TABLE tbl4__postgres_srv1__0;
--Testcase 790:
DROP DATASOURCE TABLE tbl4__postgres_srv2__0;

--Testcase 791:
DROP FOREIGN TABLE tbl4__postgres_srv1__0;
--Testcase 792:
DROP FOREIGN TABLE tbl4__postgres_srv2__0;
--Testcase 793:
DROP FOREIGN TABLE tbl4;

----------------------------------------------------------
-- end testing for source structure tbl4
-- PGSpider Top Node -> 3 posgres data source
----------------------------------------------------------
