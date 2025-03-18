# PGSpider
PGSpider is High-Performance SQL Cluster Engine for distributed big data.  
PGSpider can access a number of data sources using Foreign Data Wrapper(FDW) and retrieves the distributed data source vertically.  
Usage of PGSpider is the same as PostgreSQL except its program name is `pgspider` and default port number is `4813`. You can use any client applications such as libpq and psql.

## Features
* Multi-Tenant  
    User can get records in multi tables by one SQL easily.  
    If there are tables with similar schema in each data source, PGSpider can view them as a single virtual table: We call it as Multi-Tenant table.  

* Modification  
    User can modify data at Multi-Tenant table by using INSERT/UPDATE/DELETE query.  
    For INSERT feature, PGSpider will use round robin method to choose 1 alive node that supports INSERT feature and is the next to the previous target as rotation to INSERT data.  
    For UPDATE/DELETE feature, PGSpider will execute UPDATE/DELETE at all alive nodes that support UPDATE/DELETE feature.  
    PGSpider supports both Direct and Foreign Modification.  
    PGSpider supports bulk INSERT by using batch_size option.  
    - If user specifies batch size option, we can get batch size from foreign table or foreign server option.
    - If batch_size is 1, tell child nodes to execute simple insert. Otherwise, execute batch insert if child node can do.
    - If batch_size is not specified by user on multi-tenant table, automatically calculation based on batch size of child tables and the number of child nodes using LCM method (Least Common Multiple).  
      If batch size is too large, we use the limited value (6553500) as batch size.  
      PGSpider distributes records to data sources evenly, not only for one query but also for many queries.

* Parallel processing  
    PGSpider executes queries and fetches results from child nodes in parallel.  
    PGSpider expands Multi-Tenant table to child tables, creates new threads for each child table to access corresponding data source.

* Pushdown   
    WHERE clause and aggregation functions are pushed down to child nodes.  
    Pushdown to Multi-tenant tables occur error when AVG, STDDEV and VARIANCE are used.  
    PGSPider improves this error, PGSpider can execute them.
  
* Data Compression Transfer
    PGSpider support transferring data to other datasource via Cloud Function.  
    Data will be compressed, transmitted to Cloud Function, and then transfered to data source.  
    This feature helps PGSpider control and reduce the size of transferred data between PGSpider and destination data source, lead to reduce the usage fee on cloud service

## How to build PGSpider

Clone PGSpider source code.
<pre>
git clone https://github.com/pgspider/pgspider.git
</pre>

Build and install PGSpider and extensions.
<pre>
cd pgspider
./configure
make
sudo make install
cd contrib/pgspider_core_fdw
make
sudo make install
cd ../pgspider_fdw
make
sudo make install
</pre>

Default install directory is /usr/local/pgspider.

## Usage
For example, we will create 2 different child nodes, SQLite and PostgreSQL. They are accessed by PGSpider as root node.
Please install SQLite and PostgreSQL for child nodes. 

After that, we install PostgreSQL FDW and SQLite FDW into PGSpider. 

Install SQLite FDW 
<pre>
cd ../
git clone https://github.com/pgspider/sqlite_fdw.git
cd sqlite_fdw
make
sudo make install
</pre>
Install PostgreSQL FDW 
<pre>
cd ../postgres_fdw
make
sudo make install
</pre>

### Start PGSpider
PGSpider binary name is same as PostgreSQL.  
Default install directory is changed. 
<pre>
/usr/local/pgspider
</pre>

Create database cluster and start server.
<pre>
cd /usr/local/pgspider/bin
./initdb -D ~/pgspider_db
./pg_ctl -D ~/pgspider_db start
./createdb pgspider
</pre>

Connect to PGSpider.
<pre>
./psql pgspider
</pre>

### Load extension
PGSpider (Parent node)
<pre>
CREATE EXTENSION pgspider_core_fdw;
</pre>

PostgreSQL, SQLite (Child node)
<pre>
CREATE EXTENSION postgres_fdw;
CREATE EXTENSION sqlite_fdw;
</pre>

### Create server
PGSpider (Parent node)
<pre>
CREATE SERVER parent FOREIGN DATA WRAPPER pgspider_core_fdw;
</pre>

PostgreSQL, SQLite (Child node)  
In this example, child PostgreSQL node is localhost and port is 5432.  
SQLite node's database is /tmp/temp.db.
<pre>
CREATE SERVER postgres_svr FOREIGN DATA WRAPPER postgres_fdw OPTIONS(host '127.0.0.1', port '5432', dbname 'postgres');
CREATE SERVER sqlite_svr FOREIGN DATA WRAPPER sqlite_fdw OPTIONS(database '/tmp/temp.db');
</pre>

### Create user mapping
PostgreSQL (Child node)
<pre>
CREATE USER MAPPING FOR CURRENT_USER SERVER postgres_svr OPTIONS(user 'user', password 'pass');
</pre>
SQLite (Child node)  
No need to create user mapping.

### Create Multi-Tenant table
PGSpider (Parent node)  
You need to declare a column named "__spd_url" on parent table.  
This column is node location in PGSpider. It allows you to know where the data is comming from node.  
In this example, we define 't1' table to get data from PostgreSQL node and SQLite node.
<pre>
CREATE FOREIGN TABLE t1(i int, t text, __spd_url text) SERVER parent;
</pre>

When expanding Multi-Tenant table to data source tables, PGSpider searches child node tables by name having [Multi-Tenant table name]__[data source name]__0.  

PostgreSQL, SQLite (Child node)
<pre>
CREATE FOREIGN TABLE t1__postgres_svr__0(i int, t text) SERVER postgres_svr OPTIONS (table_name 't1');
CREATE FOREIGN TABLE t1__sqlite_svr__0(i int OPTIONS (key 'true'), t text) SERVER sqlite_svr OPTIONS (table 't1');
</pre>

### Access Multi-Tenant table
<pre>
SELECT * FROM t1;
  i |  t  | __spd_url 
----+-----+----------------
  1 | aaa | /sqlite_svr/
  2 | bbb | /sqlite_svr/
 10 | a   | /postgres_svr/
 11 | b   | /postgres_svr/
(4 rows)
</pre>

### Access Multi-Tenant table using node filter
You can choose getting node with 'IN' clause after FROM items (Table name).

<pre>
SELECT * FROM t1 IN ('/postgres_svr/');
  i | t | __spd_url 
----+---+----------------
 10 | a | /postgres_svr/
 11 | b | /postgres_svr/
(2 rows)
</pre>

### Modify Multi-Tenant table
<pre>
SELECT * FROM t1;
 i  |  t  |   __spd_url
----+-----+----------------
  1 | aaa | /sqlite_svr/
 10 | a   | /postgres_svr/
  2 | bbb | /sqlite_svr/
 11 | b   | /postgres_svr/
(4 rows)

INSERT INTO t1 VALUES (4, 'c');
INSERT 0 1

SELECT * FROM t1;
 i  |  t  |   __spd_url
----+-----+----------------
 10 | a   | /postgres_svr/
 11 | b   | /postgres_svr/
  1 | aaa | /sqlite_svr/
  2 | bbb | /sqlite_svr/
  4 | c   | /postgres_svr/
(5 rows)

UPDATE t1 SET t = 'nn';
UPDATE 5

SELECT * FROM t1;
 i  | t  |   __spd_url
----+----+----------------
 10 | nn | /postgres_svr/
 11 | nn | /postgres_svr/
  1 | nn | /sqlite_svr/
  2 | nn | /sqlite_svr/
  4 | nn | /postgres_svr/
(5 rows)

DELETE FROM t1;
DELETE 5

SELECT * FROM t1;
 i | t | __spd_url
---+---+-----------
(0 rows)
</pre>

### Modify Multi-Tenant table using node filter
You can choose modifying node with 'IN' clause after table name.

<pre>
INSERT INTO t1 VALUES (1, 'aaa'), (11, 'b');

SELECT * FROM t1;
  i |  t  | __spd_url 
----+-----+----------------
  1 | aaa | /sqlite_svr/
 11 | b   | /postgres_svr/
(2 rows)

INSERT INTO t1 IN ('/postgres_svr/') VALUES (4, 'c');

SELECT * FROM t1;
  i |  t  | __spd_url 
----+-----+----------------
  1 | aaa | /sqlite_svr/
  4 | c   | /postgres_svr/
 11 | b   | /postgres_svr/
(3 rows)

UPDATE t1 IN ('/postgres_svr/') SET t = 'xxx';
UPDATE 2

SELECT * FROM t1;
 i  |  t  |   __spd_url
----+-----+----------------
 11 | xxx | /postgres_svr/
  1 | aaa | /sqlite_svr/
  4 | xxx | /postgres_svr/
(3 rows)

DELETE FROM t1 IN ('/sqlite_svr/');
DELETE 1

SELECT * FROM t1;
 i  |  t  |   __spd_url
----+-----+----------------
 11 | xxx | /postgres_svr/
  4 | xxx | /postgres_svr/
(2 rows)
</pre>

## Tree Structure
PGSpider can get data from child PGSpider, it means PGSpider can create tree structure.  
For example, we will create a new PGSpider as root node which connects to PGSpider of previous example.  
The new root node is parent of previous PGSpider node.

### Start new root PGSpider
Create new database cluster with initdb and change port number.  
After that, start and connect to new root node.

### Load extension
PGSpider (new root node)  
If child node is PGSpider, PGSpider use pgspider_fdw.

<pre>
CREATE EXTENSION pgspider_core_fdw;
CREATE EXTENSION pgspider_fdw;
</pre>

### Create server
PGSpider (new root node)
<pre>
CREATE SERVER new_root FOREIGN DATA WRAPPER pgspider_core_fdw;
</pre>

PGSpider (Parent node)
<pre>
CREATE SERVER parent FOREIGN DATA WRAPPER pgspider_svr OPTIONS
(host '127.0.0.1', port '4813') ;
</pre>

### Create user mapping
PGSpider (Parent node)
<pre>
CREATE USER MAPPING FOR CURRENT_USER SERVER parent OPTIONS(user 'user', password 'pass');
</pre>

### Create Multi-Tenant table
PGSpider (new root node)  
<pre>
CREATE FOREIGN TABLE t1(i int, t text, __spd_url text) SERVER new_root;
</pre>

PGSpider (Parent node)  
<pre>
CREATE FOREIGN TABLE t1__parent__0(i int, t text, __spd_url text) SERVER parent;
</pre>

### Access Multi-Tenant table

<pre>
SELECT * FROM t1;

  i |  t  |      __spd_url 
----+-----+-----------------------
  1 | aaa | /parent/sqlite_svr/
  2 | bbb | /parent/sqlite_svr/
 10 | a   | /parent/postgres_svr/
 11 | b   | /parent/postgres_svr/
(4 rows)
</pre>

### Create/Drop datasource table
According to the information of a foreign table, you can create/drop a table on remote database.   
  - The query syntax:
    <pre>
    CREATE DATASOURCE TABLE [ IF NOT EXISTS ] table_name;
    DROP DATASOURCE TABLE [ IF EXISTS ] table_name;
    </pre>
  - Parameters:
    - IF NOT EXISTS (in CREATE DATASOURCE TABLE)   
      Do not throw any error if a relation/table with the same name with datasource table already exists in remote server. Note that there is no guarantee that the existing datasouce table is anything like the one that would have been created.
    - IF EXISTS (in DROP DATASOURCE TABLE)   
      Do not throw any error if the datasource table does not exist.
    - table_name   
      The name (optionally schema-qualified) of the foreign table that we can derive the datasource table need to be created.

  - Examples:
    ```sql
    CREATE FOREIGN TABLE ft1(i int, t text) SERVER postgres_svr OPTIONS (table_name 't1');
    CREATE DATASOURCE TABLE ft1; -- new datasource table `t1` is created in remote server
    DROP DATASOURCE TABLE ft1 -- datasource table `t1` is dropped in remote server
    ```

### Migrate table
You can migrate data from source tables to destination tables.   
Source table can be local table, foreign table or multi-tenant table. Destination table can be foreign table or multi-tenant table.

  - The query syntax:
    <pre>
    MIGRATE TABLE source_table
    [REPLACE|TO dest_table OPTIONS (USE_MULTITENANT_SERVER <multitenant_server_name>)]
    SERVER [dest_server OPTIONS ( option 'value' [, ...] ), dest_server OPTIONS ( option 'value' [, ...] ),...]
    </pre>
  - Parameters:
    - source_table   
      The name (optionally schema-qualified) of the source table. Source table can be local table, foreign table or multi-tenant table.
    - REPLACE (optional)   
      If this option is specified, destination table must not be specified, source table will be replaced by a new foreign table/multi-tenant table (with the name sane as source table) remoting to a new data source table. It means source table no longer exists.
    - TO (optional)   
      If it is specified, destination table must be specified. And the name of destination table must be different from the name of source table. After migration, source table is kept, new destination foreign table will be created to remoting to new data source table.   
      - dest_table   
        The name (optionally schema-qualified) of destination table. If destination table already exists, an error will be reported.
        Destination table can be specified with option `USE_MULTITENANT_SERVER`, a multi-tenant destination table will be created same as the destination table.
    - dest_server   
      Foreign server of destination server. If there are many destination servers or there is a signle destination server with `USE_MULTITENANT_SERVER` option is specified, a multi-tenant destination table will be created same as the destination table name.
      - OPTIONS ( option 'value' [, ...] )   
        destination server options, foreign table will be created with these options and datasource table will be created in remote server based on these options.

  - Examples:
    ```sql
    MIGRATE TABLE t1 SERVER postgres_svr;

    MIGRATE TABLE t1 REPLACE SERVER postgres_svr;

    MIGRATE TABLE t1 REPLACE SERVER postgres_svr, postgres_svr;

    MIGRATE TABLE t1 TO t2 SERVER postgres_svr;

    MIGRATE TABLE t1 TO t2 SERVER postgres_svr, postgres_svr;

    MIGRATE TABLE t1 to t2 OPTIONS (USE_MULTITENANT_SERVER 'pgspider_core_svr') SERVER postgres_svr;
    ```

#### Data compression transfer
You can migrate data from source tables to destination tables of other datasources via a cloud function.  
A pgspider_fdw server is required to act as a relay server to transmit data to cloud function.
It is required to provide`endpoint` and `relay` options to active this feature.  

#### Current supported datasources:  
- **PostgreSQL**  
- **MySQL**  
- **Oracle**  
- **GridDB**  
- **PGSpider**  
- **InfluxDB (only support migrating to InfluxDB v2.0)**
- **ObjStorage (only support migrating to AmazonS3 and parquet file)**
#### Options supported:  
- **relay** as *string*, required 
      Specifies foreign server of PGSpider FDW which is used to support Data Compression Transfer Feature.  
- **endpoint** as *string*, required  
      Specifies the endpoint address of cloud service.  
- **socket_port** as *interger*, required, default `4814`  
      Specifies the port number of Socket server  
- **function_timeout**  as *interger*, required, default `900` seconds  
      A socket is opened in FDW to get connection from Function, send data and receive finished notification.  
      If a finished notification of Function does not arrive before timeout expires, or no client connects to the server socket  
      the server socket is closed, and an error is shown.
- **batch_size**  as *interger*, optional, default `1000`  
      batch_size determines the number of records that will be sent to Function each time.
- **proxy** as *string*, optional  
      Proxy for cURL request.  
      If value is set by 'no', disable the use of proxy.  
      If value is not set, cURL uses environmental variables.  
- **org** as *string*, optional  
      The organization name of data store of InfluxDB server v2.0.  
      This option is only used when migrating to InfluxDB server v2.0.  
      If migrating to InfluxDB server v2.0 without org option, error will be raise.  
- **public_host** as *string*, optional  
      The hostname or endpoint of host server.  
      This option is use only in Data Compression Transfer Feature.  
      If PGSPider is behide the NAT, specify host help relay to known host IP address.  
      **public_host** is conflict with **ifconfig_service**, specify both options will raise error.  
- **public_port** as *interger*, optional, default equal to **socket_port**  
      The public port of PGSpider.  
      This option is use only in Data Compression Transfer Feature.  
      If PGSPider is behide the NAT, specify forward port help connection through NAT.  
- **ifconfig_service** as *string*, optional  
      The public service to lookup host ip (Example: ifconfig.me, ifconfig.co).  
      This option is use only in Data Compression Transfer Feature.  
      If PGSPider is behide the NAT, server can request external service to get host IP.  
      **ifconfig_service** is conflict with **public_host**, specify both options will raise error.

Examples:
  ```sql
  -- Create SERVER
  CREATE SERVER cloudfunc FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (endpoint 'http://cloud.example.com:8080', proxy 'no', batch_size '1000');

  CREATE SERVER postgres FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'postgres.example.com', port '5432', dbname 'test');
  CREATE SERVER pgspider FOREIGN DATA WRAPPER pgspider_fdw OPTIONS (host 'pgspider.example.com', port '4813', dbname 'test');
  CREATE SERVER mysql FOREIGN DATA WRAPPER mysql_fdw OPTIONS (host 'mysql.example.com', port '3306');
  CREATE SERVER griddb FOREIGN DATA WRAPPER griddb_fdw OPTIONS (host 'griddb.example.com', port '20002', clustername 'GridDB');
  CREATE SERVER oracle FOREIGN DATA WRAPPER oracle_fdw OPTIONS (dbserver 'oracle.example.com:1521/XE');
  CREATE SERVER influx FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (host 'influxdb.example.com', port '38086', dbname 'test', version '2');
  CREATE SERVER objstorage_with_endpoint FOREIGN DATA WRAPPER objstorage_fdw OPTIONS (endpoint 'http://cloud.example.com:9000', storage_type 's3');
  CREATE SERVER objstorage_with_region FOREIGN DATA WRAPPER objstorage_fdw OPTIONS (region 'us-west-1', storage_type 's3');

  -- MIGRATE NONE
  MIGRATE TABLE ft1 OPTIONS (socket_port '4814', function_timeout '800') SERVER 
          postgres OPTIONS (table_name 'table', relay 'cloudfunc'),
          pgspider OPTIONS (table_name 'table', relay 'cloudfunc'), 
          mysql OPTIONS (dbname 'test', table_name 'table', relay 'cloudfunc'),
          griddb OPTIONS (table_name 'table', relay 'cloudfunc'),
          oracle OPTIONS (table 'table', relay 'cloudfunc'),
          influx OPTIONS (table 'table', relay 'cloudfunc', org 'myorg'),
          objstorage_with_endpoint OPTION (filename 'bucket/file1.parquet', format 'parquet'),
          objstorage_with_endpoint OPTION (dirname 'bucket', format 'parquet');

  -- MIGRATE TO
  MIGRATE TABLE ft1 TO ft2 OPTIONS (socket_port '4814', function_timeout '800') SERVER 
          postgres OPTIONS (table_name 'table', relay 'cloudfunc'),
          pgspider OPTIONS (table_name 'table', relay 'cloudfunc'), 
          mysql OPTIONS (dbname 'test', table_name 'table', relay 'cloudfunc'),
          griddb OPTIONS (table_name 'table', relay 'cloudfunc'),
          oracle OPTIONS (table 'table', relay 'cloudfunc'),
          influx OPTIONS (table 'table', relay 'cloudfunc', org 'myorg'),
          objstorage_with_region OPTION (filename 'bucket/file1.parquet', format 'parquet'),
          objstorage_with_region OPTION (dirname 'bucket', format 'parquet');

  -- MIGRATE REPLACE
  MIGRATE TABLE ft1 REPLACE OPTIONS (socket_port '4814', function_timeout '800') SERVER 
          postgres OPTIONS (table_name 'table', relay 'cloudfunc'),
          pgspider OPTIONS (table_name 'table', relay 'cloudfunc'), 
          mysql OPTIONS (dbname 'test', table_name 'table', relay 'cloudfunc'),
          griddb OPTIONS (table_name 'table', relay 'cloudfunc'),
          oracle OPTIONS (table 'table', relay 'cloudfunc'),
          influx OPTIONS (table 'table', relay 'cloudfunc', org 'myorg');
          objstorage_with_endpoint OPTION (filename 'bucket/file1.parquet', format 'parquet'),
          objstorage_with_region OPTION (dirname 'bucket', format 'parquet');
  ```

## Note
When a query to foreign tables fails, you can find why it fails by seeing a query executed in PGSpider with `EXPLAIN (VERBOSE)`.  
PGSpider has a table option: `disable_transaction_feature_check`:  
- When disable_transaction_feature_check is false:  
  All child nodes will be checked. If there is any child node that does not support transaction, an error will be raised, and the modification will be stopped.
- When disable_transaction_feature_check is true:  
  The modification can be proceeded without checking.

## Limitation
Limitation with modification and transaction:
- Sometimes, PGSpider cannot read modified data in a transaction.
- It is recommended to execute a modify query(INSERT/UPDATE/DELETE) in auto-commit mode. If not, a warning "Modification query is executing in non-autocommit mode. PGSpider might get inconsistent data." is shown.
- RETURNING, WITH CHECK OPTION and ON CONFLICT are not supported with Modification.
- COPY and modify (INSERT/UPDATE/DELETE) foreign partition are not supported.
- "Tree Structure" feature is not tested enough. This feature is in beta. 

## Contributing
Opening issues and pull requests are welcome.

## License
Portions Copyright (c) 2018, TOSHIBA CORPORATION

Permission to use, copy, modify, and distribute this software and its documentation for any purpose, without fee, and without a written agreement is hereby granted, provided that the above copyright notice and this paragraph and the following two paragraphs appear in all copies.

See the [`LICENSE`][1] file for full details.

[1]: LICENSE
