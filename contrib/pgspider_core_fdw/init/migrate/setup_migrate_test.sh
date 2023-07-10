source $(pwd)/../environment_variable.config

# Start PostgreSQL $1 server name, $2 port, $3 init data file .dat
function start_postgres()
{
  echo ==============================================
  echo Start postgres server: $1, at port: $2
  echo ==============================================

  cd ${POSTGRES_HOME}/bin/

  # init if not exist
  if ! [ -d "../${1}" ];
  then
    ./initdb ../${1} > /dev/null
    sed -i "s~#port = 5432.*~port = $2~g" ../${1}/postgresql.conf
    ./pg_ctl -D ../${1} -l ../${1}.log  start
    sleep 2
  fi

  # check db is started
  if ! ./pg_isready -p $2 -d postgres
  then
    echo "Start PostgreSQL"
    ./pg_ctl -D ../${1} -l ../${1}.log start
    sleep 2
  fi

  ./dropdb -p $2 postgres
  ./createdb -p $2 postgres
  # Create user
  ./psql -p $2 postgres -c "CREATE USER postgres WITH  ENCRYPTED PASSWORD 'postgres';"
  ./psql -p $2 postgres -c "GRANT ALL PRIVILEGES ON DATABASE postgres TO postgres;"
  ./psql -p $2 postgres -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;"
  ./psql -p $2 postgres -c "GRANT ALL PRIVILEGES ON SCHEMA public TO postgres;"
  ./psql -p $2 postgres -c "ALTER DATABASE postgres SET timezone TO 'UTC';"

  # init data
  cd $CURR_PATH
  $POSTGRES_HOME/bin/psql -p $2 postgres -U postgres < $3
}


# Start PGSpider $1 server name, $2 port, $3 init data file .dat
function start_pgspider()
{
  echo ==============================================
  echo Start pgspider server: $1, at port: $2
  echo ==============================================

  cd ${PGSPIDER_HOME}/bin/

  # init if not exist
  if ! [ -d "../${1}" ];
  then
    ./initdb ../${1} > /dev/null
    sed -i "s~#port = 4813.*~port = $2~g" ../${1}/postgresql.conf
    ./pg_ctl -D ../${1} -l ../${1}.log  start
    sleep 2
  fi

  # check db is started
  if ! ./pg_isready -p $2 -d pgspider
  then
    echo "Start PGSpider"
    ./pg_ctl -D ../${1} -l ../${1}.log start
    sleep 2
  fi

  ./dropdb -p $2 pgspider
  ./createdb -p $2 pgspider
  # Create user
  ./psql -p $2 pgspider -c "CREATE USER pgspider WITH ENCRYPTED PASSWORD 'pgspider';"
  ./psql -p $2 pgspider -c "GRANT ALL PRIVILEGES ON DATABASE pgspider TO pgspider;"
  ./psql -p $2 pgspider -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO pgspider;"
  ./psql -p $2 pgspider -c "GRANT ALL PRIVILEGES ON SCHEMA public TO pgspider;"
  ./psql -p $2 pgspider -c "ALTER USER pgspider SUPERUSER;"
  ./psql -p $2 pgspider -c "ALTER DATABASE pgspider SET timezone TO 'UTC';"

  # init data
  cd $CURR_PATH
  $PGSPIDER_HOME/bin/psql -p $2 pgspider -U pgspider < $3
}

#
# Main script
#
if [[ "--start" == $1 ]]
then
  start_postgres postdb1 15432 ./post1.dat
  start_postgres postdb2 25432 ./post2.dat
  start_postgres postdb3 35432 ./post3.dat

  start_pgspider pgsdb1 14813 ./pgs.dat
fi
