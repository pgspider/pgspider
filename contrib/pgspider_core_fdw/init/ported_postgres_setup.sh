source $(pwd)/environment_variable.config

# Install postgres_fdw extension
cd $POSTGRES_HOME/../contrib/postgres_fdw
make && make install

if [[ "--start" == $1 ]]
then
  # Start PostgreSQL
  cd ${POSTGRES_HOME}/bin/
  if ! [ -d "../databases" ];
  then
    ./initdb ../databases
    sed -i 's/#port = 5432.*/port = 15432/' ../databases/postgresql.conf
    ./pg_ctl -D ../databases start
    sleep 2
  fi
  if ! ./pg_isready -p 15432
  then
    echo "Start PostgreSQL"
    ./pg_ctl -D ../databases start
    sleep 2
  fi
fi

cd $CURR_PATH

# Prepare data for ported test from postgres_fdw test
$POSTGRES_HOME/bin/dropdb -p 15432 postdb
$POSTGRES_HOME/bin/createdb -p 15432 postdb
$POSTGRES_HOME/bin/psql -p 15432 postdb -c "create user postgres with encrypted password 'postgres';"
$POSTGRES_HOME/bin/psql -p 15432 postdb -c "grant all privileges on database postgres to postgres;"
$POSTGRES_HOME/bin/psql -p 15432 postdb -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;"
$POSTGRES_HOME/bin/psql -p 15432 postdb -c "GRANT ALL PRIVILEGES ON SCHEMA public TO postgres;"
$POSTGRES_HOME/bin/psql -p 15432 postdb -c "ALTER USER postgres WITH SUPERUSER;"
$POSTGRES_HOME/bin/psql postdb -p 15432  -U postgres < ported_postgres.dat
