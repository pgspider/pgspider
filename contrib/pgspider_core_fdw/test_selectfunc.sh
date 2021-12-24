#!/bin/sh

sed -i 's/REGRESS =.*/REGRESS = selectfunc\/griddb1 selectfunc\/influxdb1 selectfunc\/mysql1 selectfunc\/sqlite1 selectfunc\/griddb2 selectfunc\/influxdb2 selectfunc\/mysql2 selectfunc\/sqlite2 selectfunc\/griddb3 selectfunc\/influxdb3 selectfunc\/mysql3 selectfunc\/sqlite3 selectfunc\/griddb4 selectfunc\/influxdb4 selectfunc\/mysql4 selectfunc\/sqlite4 /' Makefile
sed -i 's/temp-install:.*/temp-install: EXTRA_INSTALL=contrib\/pgspider_core_fdw contrib\/pgspider_fdw contrib\/pgspider_keepalive /' Makefile
sed -i 's/checkprep:.*/checkprep: EXTRA_INSTALL+=contrib\/postgres_fdw contrib\/pgspider_core_fdw contrib\/file_fdw contrib\/pgspider_keepalive contrib\/pgspider_fdw contrib\/dblink contrib\/influxdb_fdw contrib\/tinybrace_fdw contrib\/sqlite_fdw contrib\/mysql_fdw contrib\/griddb_fdw/' Makefile
# run setup script
cd init
./setup_selectfunc.sh --start
cd ..
make clean
make
mkdir -p results/selectfunc
make check | tee make_check.out
