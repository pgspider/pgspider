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
    For INSERT feature, PGSpider will choose 1 alive node that supports INSERT feature to INSERT data.  
    For UPDATE/DELETE feature, PGSpider will execute UPDATE/DELETE at all alive nodes that support UPDATE/DELETE feature.  
    PGSpider can support both Direct and Foreign Modification.

* Parallel processing  
    PGSpider executes queries and fetches results from child nodes in parallel.  
    PGSpider expands Multi-Tenant table to child tables, creates new threads for each child table to access corresponding data source.

* Pushdown   
    WHERE clause and aggregation functions are pushed down to child nodes.  
    Pushdown to Multi-tenant tables occur error when AVG, STDDEV and VARIANCE are used.  
    PGSPider improves this error, PGSpider can execute them.

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
CREATE SERVER parent FOREIGN DATA WRAPPER pgspider_core_fdw OPTIONS (host '127.0.0.1', port '4813');
</pre>

PostgreSQL, SQLite (Child node)  
In this example, child PostgreSQL node is localhost and port is 5432.  
SQLite node's database is /tmp/temp.db.
<pre>
CREATE SERVER postgres_svr FOREIGN DATA WRAPPER postgres_fdw OPTIONS(host '127.0.0.1', port '5432', dbname 'postgres');
CREATE SERVER sqlite_svr FOREIGN DATA WRAPPER sqlite_fdw OPTIONS(database '/tmp/temp.db');
</pre>

### Create user mapping
PGSpider (Parent node)

Create user mapping for PGSpider. User and password are for current psql user.
<pre>
CREATE USER MAPPING FOR CURRENT_USER SERVER parent OPTIONS(user 'user', password 'pass');
</pre>

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
CREATE FOREIGN TABLE t1__sqlite_svr__0(i int, t text) SERVER sqlite_svr OPTIONS (table 't1');
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
  i |  t  | __spd_url 
----+-----+----------------
  1 | aaa | /sqlite_svr/
 11 | b   | /postgres_svr/
(2 rows)

INSERT INTO t1 VALUES (4, 'c');
INSERT 0 1

SELECT * FROM t1;
  i |  t  | __spd_url 
----+-----+----------------
  1 | aaa | /sqlite_svr/
  4 | c   | /sqlite_svr/
 11 | b   | /postgres_svr/
(3 rows)

UPDATE t1 SET i = 5;
UPDATE 3

SELECT * FROM t1;
 i |  t  | __spd_url 
---+-----+----------------
 5 | aaa | /sqlite_svr/
 5 | c   | /sqlite_svr/
 5 | b   | /postgres_svr/
(3 rows)

DELETE FROM t1;
DELETE 3

SELECT * FROM t1;
 i | t | __spd_url
---+---+-----------
(0 rows)
</pre>

### Modify Multi-Tenant table using node filter
You can choose modifying node with 'IN' clause after table name.
Currently, INSERT query does not support IN clause.

<pre>
SELECT * FROM t1;
  i |  t  | __spd_url 
----+-----+----------------
  1 | aaa | /sqlite_svr/
 11 | b   | /postgres_svr/
(2 rows)

INSERT INTO t1 IN ('/postgres_svr/') VALUES (4, 'c');
ERROR:  Can not use INSERT with IN

SELECT * FROM t1;
  i |  t  | __spd_url 
----+-----+----------------
  1 | aaa | /sqlite_svr/
 11 | b   | /postgres_svr/
(2 rows)

UPDATE t1 IN ('/postgres_svr/') SET i = 5;
UPDATE 1

SELECT * FROM t1;
 i |  t  | __spd_url 
---+-----+----------------
 1 | aaa | /sqlite_svr/
 5 | b   | /postgres_svr/
(2 rows)

DELETE FROM t1 IN ('/sqlite_svr/');
DELETE 1

SELECT * FROM t1;
 i | t | __spd_url
---+---+----------------
 5 | b | /postgres_svr/
(1 rows)
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
CREATE SERVER new_root FOREIGN DATA WRAPPER pgspider_core_fdw OPTIONS (host '127.0.0.1', port '54813') ;
</pre>

PGSpider (Parent node)
<pre>
CREATE SERVER parent FOREIGN DATA WRAPPER pgspider_svr OPTIONS
(host '127.0.0.1', port '4813') ;
</pre>

### Create user mapping
PGSpider (new root node)
<pre>
CREATE USER MAPPING FOR CURRENT_USER SERVER new_root OPTIONS(user 'user', password 'pass');
</pre>

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
- Can not execute INSERT query with IN clause.
- RETURNING, WITH CHECK OPTION and ON CONFLICT are not supported with Modification.

## Contributing
Opening issues and pull requests are welcome.

## License
Portions Copyright (c) 2018, TOSHIBA CORPORATION

Permission to use, copy, modify, and distribute this software and its documentation for any purpose, without fee, and without a written agreement is hereby granted, provided that the above copyright notice and this paragraph and the following two paragraphs appear in all copies.

See the [`LICENSE`][1] file for full details.

[1]: LICENSE
