POSTGRES_HOME=/home/jenkins/postgres/postgresql-14.0/pgbuild
HOME_DIR=$(pwd)

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
# Prepare data for ported test from postgres_fdw test
command cd ${POSTGRES_HOME}/bin/
command ./dropdb -p 15432 postdb
command ./createdb -p 15432 postdb
command ./psql -p 15432 postdb -c "create user postgres with encrypted password 'postgres';"
command ./psql -p 15432 postdb -c "grant all privileges on database postgres to postgres;"
command ./psql -p 15432 postdb -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;"
command ./psql -p 15432 postdb -c "ALTER USER postgres WITH SUPERUSER;"
command ./psql -p 15432 postdb -U postgres < ${HOME_DIR}/ported_postgres.dat
