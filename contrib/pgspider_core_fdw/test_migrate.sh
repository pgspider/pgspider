#!/bin/sh
sed -i 's/REGRESS =.*/REGRESS = migrate_command migrate_command_enhance /' Makefile
sed -i 's/temp-install:.*/temp-install: EXTRA_INSTALL=contrib\/pgspider_core_fdw contrib\/pgspider_fdw contrib\/pgspider_keepalive /' Makefile
sed -i 's/checkprep:.*/checkprep: EXTRA_INSTALL+=contrib\/postgres_fdw contrib\/pgspider_core_fdw contrib\/file_fdw contrib\/pgspider_keepalive contrib\/pgspider_fdw /' Makefile

# run setup script
cd init/migrate
./setup_migrate_test.sh --start
cd ../..

make clean
make
make check | tee make_check.out
