-- ===================================================================
-- create FDW objects
-- ===================================================================

--Testcase 1:
CREATE EXTENSION postgres_fdw;
--Testcase 2:
CREATE EXTENSION pgspider_core_fdw;

--Testcase 3:
CREATE SERVER pgspider_core_svr FOREIGN DATA WRAPPER pgspider_core_fdw;

--Testcase 4:
CREATE SERVER server1 FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host '127.0.0.1',
		 port '15432',
		 dbname 'postgres');
--Testcase 5:
CREATE SERVER server2 FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host '127.0.0.1',
		 port '25432',
		 dbname 'postgres');
--Testcase 6:
CREATE SERVER server3 FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host '127.0.0.1',
		 port '35432',
		 dbname 'postgres');

--Testcase 7:
CREATE USER MAPPING FOR public SERVER pgspider_core_svr;

--Testcase 8:
CREATE USER MAPPING FOR public SERVER server1 OPTIONS (user 'postgres', password 'postgres');
--Testcase 9:
CREATE USER MAPPING FOR public SERVER server2 OPTIONS (user 'postgres', password 'postgres');
--Testcase 10:
CREATE USER MAPPING FOR public SERVER server3 OPTIONS (user 'postgres', password 'postgres');

-- ===================================================================
-- CREATE DATASOURCE TABLE
-- ===================================================================

--Testcase 11:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 2', table_name 'new_datasource_tbl');

--Testcase 12:
SELECT * FROM ft1; -- ERROR: datasource table does not exist

-- test for creating datasource table
--Testcase 13:
CREATE DATASOURCE TABLE ft1;
--Testcase 14:
SELECT * FROM ft1; -- OK with no data

--Testcase 15:
INSERT INTO ft1 VALUES (1, 2, 'foo', 'Fri Jan 02 00:00:00 1970 PST', 'Fri Jan 02 00:00:00 1970', '1', '2', 'baz');
--Testcase 16:
SELECT * FROM ft1;

-- check default value:
--Testcase 17:
INSERT INTO ft1 (c1, c2, c7) VALUES (2, 3, default);
--Testcase 18:
SELECT * FROM ft1;

-- check not null constrain
--Testcase 19:
INSERT INTO ft1 (c1, c2, c7) VALUES (default, default, default); -- ERROR
--Testcase 20:
SELECT * FROM ft1;

-- should fail: new_datasource_tbl already created
--Testcase 21:
CREATE DATASOURCE TABLE ft1;

-- CREATE IF NOT EXISTS
--Testcase 22:
CREATE DATASOURCE TABLE IF NOT EXISTS ft1; -- OK

--Testcase 23:
DROP DATASOURCE TABLE ft1;
--Testcase 24:
SELECT * FROM ft1; -- ERROR: datasource table is dropped

-- should fail: new_datasource_tbl already dropped
--Testcase 25:
DROP DATASOURCE TABLE ft1;

-- DROP IF EXISTS
--Testcase 26:
DROP DATASOURCE TABLE IF EXISTS ft1; -- OK

--
-- Test for wrong syntax
--

--Testcase 27:
CREATE TABLE base_table (i int);
--Testcase 28:
CREATE DATASOURCE TABLE base_table; -- ERROR: target is not a foreign table
--Testcase 29:
DROP TABLE base_table;

-- wrong syntax
--Testcase 30:
CREATE DATASOURCE TABLE IF EXISTS ft1; -- should fail
--Testcase 31:
DROP DATASOURCE TABLE IF NOT EXISTS ft1; -- should fail
--Testcase 32:
DROP DATASOURCE ft1; -- should fail
--Testcase 33:
CREATE DATASOURCE ft1; -- should fail

--Testcase 34:
DROP FOREIGN TABLE ft1;

-- ===================================================================
-- MIGRATE TABLE foreign table
-- ===================================================================

--
-- MIGRATE TABLE ft1 SERVER server2
--
--Testcase 35:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 36:
CREATE DATASOURCE TABLE ft1;
--Testcase 37:
INSERT INTO ft1
	SELECT id,
	       id % 10,
	       to_char(id, 'FM00000'),
	       '1970-01-01'::timestamptz + ((id % 100) || ' days')::interval,
	       '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
	       id % 10,
	       id % 10,
	       'foo'
	FROM generate_series(1, 1000) id;

--Testcase 38:
SELECT * FROM ft1 LIMIT 1;


--Testcase 39:
CREATE FOREIGN TABLE ft1_new (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server2 OPTIONS (table_name 'T 1');

--Testcase 40:
SELECT * FROM ft1_new LIMIT 1; -- ERROR datasource table does not create

-- datasource table will be created in public schema
--Testcase 41:
MIGRATE TABLE ft1 SERVER server2;

-- Does not create new foreign table
--Testcase 42:
\det+

--Testcase 43:
SELECT * FROM ft1_new LIMIT 1;
--Testcase 44:
SELECT count(*) FROM ft1_new;
--Testcase 45:
DROP DATASOURCE TABLE ft1_new;
--Testcase 46:
DROP FOREIGN TABLE ft1_new;


--Testcase 47:
CREATE FOREIGN TABLE ft1_new (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server2 OPTIONS (schema_name 'S 2', table_name 'T 1');

--Testcase 48:
SELECT * FROM ft1_new LIMIT 1; -- ERROR: datasource table does not exist.

-- migrate data to "S 2"."T 1"
--Testcase 49:
MIGRATE TABLE ft1 SERVER server2 OPTIONS (schema_name 'S 2');
-- Does not create new foreign table
--Testcase 50:
\det+

--Testcase 51:
SELECT * FROM ft1_new LIMIT 1;
--Testcase 52:
SELECT count(*) FROM ft1_new;
--Testcase 53:
DROP DATASOURCE TABLE ft1_new;
--Testcase 54:
DROP FOREIGN TABLE ft1_new;
--Testcase 55:
DROP FOREIGN TABLE ft1;

--
-- MIGRATE TABLE t1 REPLACE SERVER server2
--
--Testcase 56:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');

--Testcase 57:
SELECT * FROM ft1 LIMIT 1;

--
-- dest server has no option
--
--Testcase 58:
MIGRATE TABLE ft1 REPLACE SERVER server2;

-- ft1 is connect to server2 now.
--Testcase 59:
\det+
-- ft1 has server is server2 and no schema option
--Testcase 60:
\d ft1

--Testcase 61:
SELECT * FROM ft1 LIMIT 1;

--Testcase 62:
SELECT count(*) FROM ft1;
--Testcase 63:
DROP DATASOURCE TABLE ft1;
--Testcase 64:
DROP FOREIGN TABLE ft1;

--
-- dest server has option
--
--Testcase 65:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 66:
SELECT * FROM ft1 LIMIT 1;

--Testcase 67:
MIGRATE TABLE ft1 REPLACE SERVER server2 OPTIONS (schema_name 'S 2', table_name 'T 2');
-- ft1 is connect to server2 now.
--Testcase 68:
\det+
--Testcase 69:
\d ft1
-- datasource table is created in "S 2" schema

--Testcase 70:
SELECT * FROM ft1 LIMIT 1;
--Testcase 71:
SELECT count(*) FROM ft1;
--Testcase 72:
DROP DATASOURCE TABLE ft1;
--Testcase 73:
DROP FOREIGN TABLE ft1;

--
-- MIGRATE TABLE t1 TO t2 SERVER server1
--
--Testcase 74:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 75:
SELECT * FROM ft1 LIMIT 1;

--
-- dest server has no option
--
--Testcase 76:
MIGRATE TABLE ft1 TO ft2 SERVER server2;

--Testcase 77:
SELECT * FROM ft1 LIMIT 1;
--Testcase 78:
SELECT * FROM ft2 LIMIT 1;

-- foreign table of source server is kept
-- foreign table of destination server is created
--Testcase 79:
\det+
-- ft1 has server is server1 and no schema option
--Testcase 80:
\d ft1
-- ft2 has server is server2 and no schema option
--Testcase 81:
\d ft2

--Testcase 82:
SELECT count(*) FROM ft2;
--Testcase 83:
DROP DATASOURCE TABLE ft2;
--Testcase 84:
DROP FOREIGN TABLE ft2;

--
-- dest server has option
--
--Testcase 85:
MIGRATE TABLE ft1 TO ft2 SERVER server3 OPTIONS (schema_name 'S 2', table_name 'T 2');
--Testcase 86:
SELECT * FROM ft1 LIMIT 1;
--Testcase 87:
SELECT * FROM ft2 LIMIT 1;

-- foreign table of source server is kept
-- foreign table of destination server is created
--Testcase 88:
\det+
-- ft2 has server is server3
--Testcase 89:
\d ft2

--Testcase 90:
SELECT count(*) FROM ft2;
--Testcase 91:
DROP DATASOURCE TABLE ft2;
--Testcase 92:
DROP FOREIGN TABLE ft1;
--Testcase 93:
DROP FOREIGN TABLE ft2;


-- ===================================================================
-- MIGRATE TABLE multitenant table
-- ===================================================================

--
-- MIGRATE TABLE ft1 SERVER server1
--

--Testcase 94:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10),
	__spd_url text
) SERVER pgspider_core_svr;

--Testcase 95:
CREATE FOREIGN TABLE ft1__server1__0 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');

--Testcase 96:
SELECT * FROM ft1 LIMIT 1;

--Testcase 97:
CREATE FOREIGN TABLE ft1_new (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server2 OPTIONS (table_name 'ft1');

--Testcase 98:
SELECT * FROM ft1_new LIMIT 1; -- ERROR: datasource table does not exist

-- datasource table will be created in public schema
--Testcase 99:
MIGRATE TABLE ft1 SERVER server2;
-- no new foreign table created
--Testcase 100:
\det+

--Testcase 101:
SELECT * FROM ft1_new LIMIT 1;
--Testcase 102:
SELECT count(*) FROM ft1_new;
--Testcase 103:
DROP DATASOURCE TABLE ft1_new;
--Testcase 104:
DROP FOREIGN TABLE ft1_new;


--Testcase 105:
CREATE FOREIGN TABLE ft1_new (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server2 OPTIONS (table_name 'ft1', schema_name 'S 2');

--Testcase 106:
SELECT * FROM ft1_new LIMIT 1; -- ERROR: datasource table does not exist

-- migrate data to "S 2"."T 1"
--Testcase 107:
MIGRATE TABLE ft1 SERVER server2 OPTIONS (schema_name 'S 2');
--Testcase 108:
SELECT * FROM ft1 LIMIT 1;

-- no new foreign table created
--Testcase 109:
\det+
--Testcase 110:
SELECT * FROM ft1_new LIMIT 1;
--Testcase 111:
SELECT count(*) FROM ft1_new;
--Testcase 112:
DROP DATASOURCE TABLE ft1_new;
--Testcase 113:
DROP FOREIGN TABLE ft1_new;

--
-- MIGRATE TABLE t1 REPLACE SERVER server2
--

--
-- dest server has no option
--
-- migrate try to create new table ft1 in public schema
--Testcase 114:
MIGRATE TABLE ft1 REPLACE SERVER server2;
--Testcase 115:
\det+

--Testcase 116:
SELECT * FROM ft1 LIMIT 1;
--Testcase 117:
SELECT count(*) FROM ft1;
--Testcase 118:
DROP DATASOURCE TABLE ft1;
--Testcase 119:
DROP FOREIGN TABLE ft1;

--
-- MIGRATE TABLE t1 TO t2 SERVER server1
--

--Testcase 120:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10),
	__spd_url text
) SERVER pgspider_core_svr;
--Testcase 121:
CREATE FOREIGN TABLE ft1__server1__0 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 122:
SELECT * FROM ft1 LIMIT 1;

--
-- dest server has option
--
--Testcase 123:
MIGRATE TABLE ft1 REPLACE SERVER server2 OPTIONS (schema_name 'S 2', table_name 'T 2');
--Testcase 124:
SELECT * FROM ft1 LIMIT 1;

-- ft1 has server is server2
--Testcase 125:
\det+

--Testcase 126:
SELECT * FROM ft1 LIMIT 1;
--Testcase 127:
SELECT count(*) FROM ft1;
--Testcase 128:
DROP DATASOURCE TABLE ft1;
--Testcase 129:
DROP FOREIGN TABLE ft1;

--
-- MIGRATE TABLE t1 TO t2 SERVER server1
--

--Testcase 130:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10),
	__spd_url text
) SERVER pgspider_core_svr;
--Testcase 131:
CREATE FOREIGN TABLE ft1__server1__0 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 132:
SELECT * FROM ft1 LIMIT 1;

--
-- dest server has no option
--
--Testcase 133:
MIGRATE TABLE ft1 TO ft2 SERVER server2;
--Testcase 134:
SELECT * FROM ft1 LIMIT 1;
--Testcase 135:
SELECT * FROM ft2 LIMIT 1;

-- datasource table is created in public schema
--Testcase 136:
\det+
-- ft1 has server is multitenant table
--Testcase 137:
\d ft1
-- ft2 has server is server2 and no schema option
--Testcase 138:
\d ft2

--Testcase 139:
SELECT count(*) FROM ft2;
--Testcase 140:
DROP DATASOURCE TABLE ft2;
--Testcase 141:
DROP FOREIGN TABLE ft2;

--
-- dest server has option
--
--Testcase 142:
MIGRATE TABLE ft1 TO ft2 SERVER server3 OPTIONS (schema_name 'S 2', table_name 'T 2');
--Testcase 143:
SELECT * FROM ft1 LIMIT 1;
--Testcase 144:
SELECT * FROM ft2 LIMIT 1;
-- new foreign table ft2 created
--Testcase 145:
\det+
-- ft2 has server is server3
--Testcase 146:
\d ft2

--Testcase 147:
SELECT count(*) FROM ft2;
--Testcase 148:
DROP DATASOURCE TABLE ft2;
--Testcase 149:
DROP FOREIGN TABLE ft2;
--Testcase 150:
DROP FOREIGN TABLE ft1;
--Testcase 151:
DROP FOREIGN TABLE ft1__server1__0;


-- ===================================================================
-- MIGRATE with multi destination server
-- ===================================================================

--
-- MIGRATE TABLE ft1 SERVER server1, server2, server3
--

--Testcase 152:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 153:
SELECT * FROM ft1 LIMIT 1;

--Testcase 154:
CREATE FOREIGN TABLE ft1_server1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'ft1_src');

--Testcase 155:
CREATE FOREIGN TABLE ft1_server2 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server2 OPTIONS (schema_name 'S 2', table_name 'T 1');

--Testcase 156:
CREATE FOREIGN TABLE ft1_server3 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server3 OPTIONS (schema_name 'S 3', table_name 'T 1');

--Testcase 157:
SELECT * FROM ft1_server1; -- ERROR: datasource table does not exist
--Testcase 158:
SELECT * FROM ft1_server2; -- ERROR: datasource table does not exist
--Testcase 159:
SELECT * FROM ft1_server3; -- ERROR: datasource table does not exist

-- datasource table will be created in public schema
--Testcase 160:
MIGRATE TABLE ft1 SERVER server1 OPTIONS (schema_name 'S 1', table_name 'ft1_src'), server2 OPTIONS (schema_name 'S 2'), server3 OPTIONS (schema_name 'S 3');

-- ft1 is postgres foreign table, only data source table created
--Testcase 161:
\det+

-- even distribution of data
--Testcase 162:
SELECT * FROM ft1_server1 LIMIT 1;
--Testcase 163:
SELECT count(*) FROM ft1_server1;
--Testcase 164:
SELECT * FROM ft1_server2 LIMIT 1;
--Testcase 165:
SELECT count(*) FROM ft1_server2;
--Testcase 166:
SELECT * FROM ft1_server3 LIMIT 1;
--Testcase 167:
SELECT count(*) FROM ft1_server3;

--Testcase 168:
DROP DATASOURCE TABLE ft1_server1;
--Testcase 169:
DROP DATASOURCE TABLE ft1_server2;
--Testcase 170:
DROP DATASOURCE TABLE ft1_server3;
--Testcase 171:
DROP FOREIGN TABLE ft1_server1;
--Testcase 172:
DROP FOREIGN TABLE ft1_server2;
--Testcase 173:
DROP FOREIGN TABLE ft1_server3;

--Testcase 174:
DROP FOREIGN TABLE ft1;

--
-- MIGRATE TABLE t1 REPLACE SERVER server1, server2, server3
--
--Testcase 175:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 176:
SELECT * FROM ft1 LIMIT 1;

--
-- dest server has no option
--
--Testcase 177:
MIGRATE TABLE ft1 REPLACE SERVER
	server1, server2, server3;

-- only child table was created
--Testcase 178:
\det+
-- multitenant table
--Testcase 179:
\d ft1
--Testcase 180:
SELECT count(*) FROM ft1;
--Testcase 181:
SELECT * FROM ft1  ORDER BY 1 LIMIT 1;

-- even distribution of data
--Testcase 182:
SELECT * FROM ft1__server1__0 LIMIT 1;
--Testcase 183:
SELECT count(*) FROM ft1__server1__0;
--Testcase 184:
SELECT * FROM ft1__server2__0 LIMIT 1;
--Testcase 185:
SELECT count(*) FROM ft1__server2__0;
--Testcase 186:
SELECT * FROM ft1__server3__0 LIMIT 1;
--Testcase 187:
SELECT count(*) FROM ft1__server3__0;

--Testcase 188:
DROP DATASOURCE TABLE ft1__server1__0;
--Testcase 189:
DROP DATASOURCE TABLE ft1__server2__0;
--Testcase 190:
DROP DATASOURCE TABLE ft1__server3__0;

--Testcase 191:
DROP FOREIGN TABLE ft1;
--Testcase 192:
DROP FOREIGN TABLE ft1__server1__0;
--Testcase 193:
DROP FOREIGN TABLE ft1__server2__0;
--Testcase 194:
DROP FOREIGN TABLE ft1__server3__0;

--
-- MIGRATE TABLE t1 TO t2 SERVER server1, server2, server3
--

--Testcase 195:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 196:
SELECT * FROM ft1 LIMIT 1;

--
-- MIGRATE data from postgres foreign table to multitenant table
-- ft1: postgre_fdw
-- new ft2: pgspider_core_fdw
--
--Testcase 197:
MIGRATE TABLE ft1 TO ft2 SERVER server1 OPTIONS (schema_name 'S 1', table_name 'ft2_src'), server2 OPTIONS (schema_name 'S 2'), server3 OPTIONS (schema_name 'S 3');

-- ft2 and its child tables were created
-- ft2, ft2__server1__0, ft2__server2__0, ft2__server3__0
--Testcase 198:
\det+

-- simple check data existed in new table
--Testcase 199:
SELECT count(*) FROM ft2;
--Testcase 200:
SELECT * FROM ft2 ORDER BY 1 LIMIT 1;

--Testcase 201:
SELECT count(*) FROM ft1;
--Testcase 202:
SELECT * FROM ft1 LIMIT 1;

-- even distribution of data
--Testcase 203:
SELECT * FROM ft2__server1__0 LIMIT 1;
--Testcase 204:
SELECT count(*) FROM ft2__server1__0;
--Testcase 205:
SELECT * FROM ft2__server2__0 LIMIT 1;
--Testcase 206:
SELECT count(*) FROM ft2__server2__0;
--Testcase 207:
SELECT * FROM ft2__server3__0 LIMIT 1;
--Testcase 208:
SELECT count(*) FROM ft2__server3__0;

--Testcase 209:
DROP DATASOURCE TABLE ft2__server1__0;
--Testcase 210:
DROP DATASOURCE TABLE ft2__server2__0;
--Testcase 211:
DROP DATASOURCE TABLE ft2__server3__0;

--Testcase 212:
DROP FOREIGN TABLE ft1;
--Testcase 213:
DROP FOREIGN TABLE ft2;
--Testcase 214:
DROP FOREIGN TABLE ft2__server1__0;
--Testcase 215:
DROP FOREIGN TABLE ft2__server2__0;
--Testcase 216:
DROP FOREIGN TABLE ft2__server3__0;

-- ===================================================================
-- MIGRATE TABLE multitenant table
-- ===================================================================
--Testcase 217:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10),
	__spd_url text
) SERVER pgspider_core_svr;

--Testcase 218:
CREATE FOREIGN TABLE ft1__server1__0 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');

--Testcase 219:
CREATE FOREIGN TABLE ft1_server1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'ft1_src');

--Testcase 220:
CREATE FOREIGN TABLE ft1_server2 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server2 OPTIONS (schema_name 'S 2', table_name 'ft1');

--Testcase 221:
CREATE FOREIGN TABLE ft1_server3 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server3 OPTIONS (schema_name 'S 3', table_name 'ft1');

--Testcase 222:
SELECT * FROM ft1_server1; -- ERROR: datasource table does not exist
--Testcase 223:
SELECT * FROM ft1_server2; -- ERROR: datasource table does not exist
--Testcase 224:
SELECT * FROM ft1_server3; -- ERROR: datasource table does not exist

-- datasource table will be created in public schema
--Testcase 225:
MIGRATE TABLE ft1 SERVER server1 OPTIONS (schema_name 'S 1', table_name 'ft1_src'), server2 OPTIONS (schema_name 'S 2'), server3 OPTIONS (schema_name 'S 3');

-- check again no foreign table is created
-- datasource table name is multitenant table name
--Testcase 226:
\det+

-- check data in datasource table
-- even distribution of data also
--Testcase 227:
SELECT * FROM ft1_server1 LIMIT 1;
--Testcase 228:
SELECT count(*) FROM ft1_server1;
--Testcase 229:
SELECT * FROM ft1_server2 LIMIT 1;
--Testcase 230:
SELECT count(*) FROM ft1_server2;
--Testcase 231:
SELECT * FROM ft1_server3 LIMIT 1;
--Testcase 232:
SELECT count(*) FROM ft1_server3;

--Testcase 233:
DROP DATASOURCE TABLE ft1_server1;
--Testcase 234:
DROP DATASOURCE TABLE ft1_server2;
--Testcase 235:
DROP DATASOURCE TABLE ft1_server3;
--Testcase 236:
DROP FOREIGN TABLE ft1_server1;
--Testcase 237:
DROP FOREIGN TABLE ft1_server2;
--Testcase 238:
DROP FOREIGN TABLE ft1_server3;

--Testcase 239:
DROP FOREIGN TABLE ft1;
--Testcase 240:
DROP FOREIGN TABLE ft1__server1__0;

--
-- MIGRATE TABLE t1 TO t2 SERVER server1
--

--Testcase 241:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10),
	__spd_url text
) SERVER pgspider_core_svr;

--Testcase 242:
CREATE FOREIGN TABLE ft1__server1__0 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');

--Testcase 243:
SELECT * FROM ft1 ORDER BY 1 LIMIT 1;

-- not allow duplicated table name
--Testcase 244:
MIGRATE TABLE ft1 TO ft1 SERVER server1; -- should fail

--
-- dest server has option
--
--Testcase 245:
MIGRATE TABLE ft1 TO ft2 SERVER
	server1 OPTIONS (schema_name 'S 1', table_name 'ft2_src'), server2 OPTIONS (schema_name 'S 2'), server3 OPTIONS (schema_name 'S 3');
-- check if ft2 is created, ft1 is not replaced
--Testcase 246:
\det+

--Testcase 247:
SELECT count(*) FROM ft2;
--Testcase 248:
SELECT * FROM ft2 ORDER BY 1 LIMIT 1;

--Testcase 249:
SELECT count(*) FROM ft1;
--Testcase 250:
SELECT * FROM ft1 ORDER BY 1 LIMIT 1;

--Testcase 251:
SELECT count(*) FROM ft2__server1__0;
--Testcase 252:
SELECT * FROM ft2__server1__0 LIMIT 1;

--Testcase 253:
SELECT count(*) FROM ft2__server2__0;
--Testcase 254:
SELECT * FROM ft2__server2__0 LIMIT 1;

--Testcase 255:
SELECT count(*) FROM ft2__server3__0;
--Testcase 256:
SELECT * FROM ft2__server3__0 LIMIT 1;

--Testcase 257:
DROP DATASOURCE TABLE ft2__server1__0;
--Testcase 258:
DROP DATASOURCE TABLE ft2__server2__0;
--Testcase 259:
DROP DATASOURCE TABLE ft2__server3__0;

--Testcase 260:
DROP FOREIGN TABLE ft1;
--Testcase 261:
DROP FOREIGN TABLE ft1__server1__0;
--Testcase 262:
DROP FOREIGN TABLE ft2;
--Testcase 263:
DROP FOREIGN TABLE ft2__server1__0;
--Testcase 264:
DROP FOREIGN TABLE ft2__server2__0;
--Testcase 265:
DROP FOREIGN TABLE ft2__server3__0;

--
-- dest server has same server
--
--Testcase 266:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10),
	__spd_url text
) SERVER pgspider_core_svr;
--Testcase 267:
CREATE FOREIGN TABLE ft1__server1__0 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 268:
SELECT * FROM ft1 ORDER BY 1 LIMIT 1;

--Testcase 269:
MIGRATE TABLE ft1 TO ft2 SERVER
server1 OPTIONS (schema_name 'S 1', table_name 'ft2_src_1'),
server1 OPTIONS (schema_name 'S 1', table_name 'ft2_src_2'),
server2 OPTIONS (schema_name 'S 2', table_name 'ft2_src_1'),
server2 OPTIONS (schema_name 'S 2', table_name 'ft2_src_2'),
server3 OPTIONS (schema_name 'S 3', table_name 'ft2_src_1');

-- datasource tables are created, ft2 is created, ft1 is not replaced
--Testcase 270:
\det+
-- details of multitenant tables
--Testcase 271:
\d ft2
--Testcase 272:
\d ft1

--Testcase 273:
SELECT count(*) FROM ft2;
--Testcase 274:
SELECT * FROM ft2 ORDER BY 1 LIMIT 1;

--Testcase 275:
SELECT count(*) FROM ft1;
--Testcase 276:
SELECT * FROM ft1 ORDER BY 1 LIMIT 1;

--Testcase 277:
SELECT count(*) FROM ft1__server1__0;
--Testcase 278:
SELECT * FROM ft1__server1__0 LIMIT 1;

--Testcase 279:
SELECT count(*) FROM ft2__server1__1;
--Testcase 280:
SELECT * FROM ft2__server1__1 LIMIT 1;

--Testcase 281:
SELECT count(*) FROM ft2__server2__0;
--Testcase 282:
SELECT * FROM ft2__server2__0 LIMIT 1;

--Testcase 283:
SELECT count(*) FROM ft2__server2__1;
--Testcase 284:
SELECT * FROM ft2__server2__1 LIMIT 1;

--Testcase 285:
SELECT count(*) FROM ft2__server3__0;
--Testcase 286:
SELECT * FROM ft2__server3__0 LIMIT 1;

--Testcase 287:
DROP DATASOURCE TABLE ft2__server1__1;
--Testcase 288:
DROP DATASOURCE TABLE ft2__server2__0;
--Testcase 289:
DROP DATASOURCE TABLE ft2__server2__1;
--Testcase 290:
DROP DATASOURCE TABLE ft2__server3__0;

--Testcase 291:
DROP FOREIGN TABLE ft1;
--Testcase 292:
DROP FOREIGN TABLE ft1__server1__0;
--Testcase 293:
DROP FOREIGN TABLE ft2;
--Testcase 294:
DROP FOREIGN TABLE ft2__server1__0;
--Testcase 295:
DROP FOREIGN TABLE ft2__server1__1;
--Testcase 296:
DROP FOREIGN TABLE ft2__server2__0;
--Testcase 297:
DROP FOREIGN TABLE ft2__server2__1;
--Testcase 298:
DROP FOREIGN TABLE ft2__server3__0;

/*
 *	Use option USE_MULTITENANT_SERVER
 */

--
-- MIGRATE TABLE t1 TO t2 OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER server1
--

--Testcase 299:
CREATE FOREIGN TABLE ft1 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 char(10)
) SERVER server1 OPTIONS (schema_name 'S 1', table_name 'T 1');
--Testcase 300:
SELECT * FROM ft1 LIMIT 1;

--
-- Treat single server as multitenant server by using option USE_MULTITENANT_SERVER
--
--Testcase 301:
MIGRATE TABLE ft1 TO ft2 OPTIONS (USE_MULTITENANT_SERVER 'new_pgspider_core_svr') SERVER server2;

-- Check tables
--Testcase 302:
\det+
-- multitenant table
--Testcase 303:
\d ft2
-- Postgre foreign table
--Testcase 304:
\d ft1

-- simple check data existed in new table
--Testcase 305:
SELECT count(*) FROM ft2;
--Testcase 306:
SELECT * FROM ft2 ORDER BY 1 LIMIT 1;

--Testcase 307:
SELECT count(*) FROM ft1;
--Testcase 308:
SELECT * FROM ft1 LIMIT 1;

--Testcase 309:
DROP DATASOURCE TABLE ft1;
--Testcase 310:
DROP FOREIGN TABLE ft1;
--Testcase 311:
DROP FOREIGN TABLE ft2;
--Testcase 312:
DROP DATASOURCE TABLE ft2__server2__0;
--Testcase 313:
DROP FOREIGN TABLE ft2__server2__0;

/* Clean all */
--Testcase 314:
DROP EXTENSION postgres_fdw CASCADE;
--Testcase 315:
DROP EXTENSION pgspider_core_fdw CASCADE;
