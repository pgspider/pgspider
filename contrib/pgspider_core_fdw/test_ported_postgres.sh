#!/bin/sh
# run setup script
cd init
./ported_postgres_setup.sh --start
cd ..

sed -i 's/REGRESS =.*/REGRESS = ported_postgres_fdw /' Makefile
sed -i 's/temp-install:.*/temp-install: EXTRA_INSTALL=contrib\/pgspider_core_fdw contrib\/postgres_fdw contrib\/pgspider_keepalive contrib\/dblink /' Makefile
sed -i 's/checkprep:.*/checkprep: EXTRA_INSTALL+=contrib\/pgspider_core_fdw contrib\/postgres_fdw contrib\/pgspider_keepalive contrib\/dblink /' Makefile

make clean
make
make check | tee make_check.out
