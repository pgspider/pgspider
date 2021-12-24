PGS1_DIR=/home/jenkins/PGSpider/PGS
PGS1_PORT=5433
PGS1_DB=pg1db
PGS2_DIR=/home/jenkins/PGSpider/PGS
PGS2_PORT=5434
PGS2_DB=pg2db
DB_NAME=postgres
GRIDDB_CLIENT=/home/jenkins/src/griddb
GRIDDB_HOME=/home/jenkins/src/griddb-4.6.1

CURR_PATH=$(pwd)

if [[ "--start" == $1 ]]
then
  #Start PGS1
  cd ${PGS1_DIR}/bin/
  if ! [ -d "../${PGS1_DB}" ];
  then
    ./initdb ../${PGS1_DB}
    sed -i "s~#port = 4813.*~port = $PGS1_PORT~g" ../${PGS1_DB}/postgresql.conf
    ./pg_ctl -D ../${PGS1_DB} start #-l ../log.pg1
    sleep 2
    ./createdb -p $PGS1_PORT postgres
  fi
  if ! ./pg_isready -p $PGS1_PORT
  then
    echo "Start PG1"
    ./pg_ctl -D ../${PGS1_DB} start #-l ../log.pg1
    sleep 2
  fi
  #Start PGS2
  if ! [ -d "../${PGS2_DB}" ];
  then
    ./initdb ../${PGS2_DB}
    sed -i "s~#port = 4813.*~port = $PGS2_PORT~g" ../${PGS2_DB}/postgresql.conf
    ./pg_ctl -D ../${PGS2_DB} start #-l ../log.pg2
    sleep 2
    ./createdb -p $PGS2_PORT postgres
  fi
  if ! ./pg_isready -p $PGS2_PORT
  then
    echo "Start PG2"
    ./pg_ctl -D ../${PGS2_DB} start #-l ../log.pg2
    sleep 2
  fi
  # Start MySQL
  if ! [[ $(systemctl status mysqld.service) == *"active (running)"* ]]
  then
    echo "Start MySQL Server"
    systemctl start mysqld.service
    sleep 2
  fi
  # Start InfluxDB server
  if ! [[ $(systemctl status influxdb) == *"active (running)"* ]]
  then
    echo "Start InfluxDB Server"
    systemctl start influxdb
    sleep 2
  fi
  # Start GridDB server
  if [[ ! -d "${GRIDDB_HOME}" ]];
  then
    echo "GRIDDB_HOME environment variable not set"
    exit 1
  fi
  export GS_HOME=${GRIDDB_HOME}
  export GS_LOG=${GRIDDB_HOME}/log
  export no_proxy=127.0.0.1
  if pgrep -x "gsserver" > /dev/null
  then
    ${GRIDDB_HOME}/bin/gs_leavecluster -w -f -u admin/testadmin
    ${GRIDDB_HOME}/bin/gs_stopnode -w -u admin/testadmin
    sleep 1
  fi
  rm -rf ${GS_HOME}/data/* ${GS_LOG}/*
  sed -i 's/\"clusterName\":.*/\"clusterName\":\"griddbfdwTestCluster\",/' ${GRIDDB_HOME}/conf/gs_cluster.json
  echo "Starting GridDB server..."
  ${GRIDDB_HOME}/bin/gs_startnode -w -u admin/testadmin
  ${GRIDDB_HOME}/bin/gs_joincluster -w -c griddbfdwTestCluster -u admin/testadmin
fi

cd $CURR_PATH

# Setup GridDB
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${GRIDDB_CLIENT}/bin
cp -a griddb_selectfunc.dat /tmp/
cp -a griddb_selectfunc1.dat /tmp/
cp -a griddb_selectfunc2.dat /tmp/
gcc griddb_init.c -o griddb_init -I${GRIDDB_CLIENT}/client/c/include -L${GRIDDB_CLIENT}/bin -lgridstore
./griddb_init 239.0.0.1 31999 griddbfdwTestCluster admin testadmin 1

# Setup SQLite
rm /tmp/pgtest.db
sqlite3 /tmp/pgtest.db < sqlite_selectfunc.dat

# Setup Mysql
mysql -uroot -pMysql_1234 < mysql_selectfunc.dat
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -uroot -pMysql_1234 mysql

# Setup InfluxDB
influx -import -path=./influx_selectfunc.data -precision=ns

# Setup PGSpider1
$PGS1_DIR/bin/psql -p $PGS1_PORT $DB_NAME < pgspider_selectfunc1.dat

# Setup PGSpider2
$PGS2_DIR/bin/psql -p $PGS2_PORT $DB_NAME < pgspider_selectfunc2.dat
