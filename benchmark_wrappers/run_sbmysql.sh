#!/bin/bash

[ -z "$_TESTS" -o \
  -z "$_THREADS" -o \
  -z "$_TABLES" -o \
  -z "$_SIZE" -o \
  -z "$_MYSQL_USER" -o \
  -z "$_MYSQL_HOST" -o \
  -z "$_MYSQL_PASSWORD" ] && {
cat <<EOF>&2

   usage: [env var1=val1 var2=val2 ...] $0
   No direct input args, behavior is controlled by the following environment
   variables: 
     - _EXP_NAME : Experiment name. Optional, defaults to 'sysbench'
     - _TESTS_DIR : The directory containing the test files. Optional, defaults
       to current directory
     - _TESTS : Quoted list of the tests to run, i.e. "oltp_read_only
       oltp_read_write".
     - _THREADS : Quoted list of the # of threads to use for each run, i.e.
       "16 32 64"
     - _TABLES : Number of tables to use for the tests
     - _SIZE : Quoted list of the table sizes to use, in rows, i.e.
       "100000 1000000 10000000"
     - _MYSQL_USER : MySQL username to use for the benchmark run
     - _MYSQL_HOST : MySQL host to connect to for the benchmark run
     - _MYSQL_PASSWORD : MySQL password to use for the benchmark run
     - _LOG_QUERIES : Control slow query logging to capture queries executed
       during the benchmark in slow query log
   
   Any actual input argument will be passed as is to sysbench, so you can run
   this like so:

   _TESTS_DIR=sysbench_tests _TESTS="oltp_read_only oltp_read_write" _THREADS="16 32" _TABLES=16 _SIZE="1000 10000" ./run_sbmysql.sh --rand-type=pareto --mysql-db=sbtest --time=7200

   _EXP_NAME=sample _LOG_QUERIES=1 _TESTS_DIR=sysbench_tests _TESTS="oltp_read_only oltp_read_write" _THREADS="1 2 4" _TABLES=64 _SIZE="10 100" _MYSQL_USER=sysbench _MYSQL_PASSWORD=sysbench _MYSQL_HOST=localhost ./run_sbmysql.sh --mysql_table_engine=innodb --rand-type=pareto --mysql-db=sbtest --time=60


EOF

exit 1

}

[ -z "$_EXP_NAME" ] && _EXP_NAME="sysbench"


PREPARE_THREADS=8
MYSQL_CMD="mysql --host=$_MYSQL_HOST --user=$_MYSQL_USER --password=$_MYSQL_PASSWORD"
MYSQL_VERSION=$($MYSQL_CMD -NB -e "SELECT VERSION()" | awk -F. '{print $1"."$2}')

if [[ "$MYSQL_VERSION" == "5.6" ]]; then
    MYSQL_DATETIME_FUNC="NOW"
else
    MYSQL_DATETIME_FUNC="UTC_TIMESTAMP"
fi

for test in $_TESTS; do
    if [ -z "$_TESTS_DIR" ]; then
        _TESTS_DIR=$(pwd)
    fi

    test_path=${_TESTS_DIR}/${test}.lua
    if [[ ! -f ${test_path} ]]; then
        echo "Skipping test ${test}, as it is not yet supported"
        continue
    fi

    # Set the LUA search path
    export LUA_PATH="${_TESTS_DIR}/?.lua;;"

    mkdir $test 2>/dev/null #ignore if it exists
    pushd $test
    for size in $_SIZE; do
        echo "Starting sysbench for exp=$_EXP_NAME, test=$test, size=$size"

        sysbench ${test_path} --db-driver=mysql --threads=$PREPARE_THREADS \
            --tables=$_TABLES --table-size=$size --mysql-host=$_MYSQL_HOST \
            --mysql-user=$_MYSQL_USER --mysql-password=$_MYSQL_PASSWORD "$@" cleanup

        sysbench ${test_path} --db-driver=mysql --threads=$PREPARE_THREADS \
            --tables=$_TABLES --table-size=$size --mysql-host=$_MYSQL_HOST \
            --mysql-user=$_MYSQL_USER --mysql-password=$_MYSQL_PASSWORD "$@" prepare

        for threads in $_THREADS; do
            echo "Running sysbench for exp=$_EXP_NAME, test=$test, threads=$threads, size=$size"

            if [[ ! -z $_LOG_QUERIES ]]; then
                START_TIME=$($MYSQL_CMD -NB -e "SELECT ${MYSQL_DATETIME_FUNC}()")
                $MYSQL_CMD -e "SET GLOBAL slow_query_log=1, GLOBAL long_query_time=0"
            fi

            sysbench ${test_path} --db-driver=mysql --threads=$threads \
                --tables=$_TABLES --table-size=$size --mysql-host=$_MYSQL_HOST \
                --mysql-user=$_MYSQL_USER --mysql-password=$_MYSQL_PASSWORD \
                --verbosity=0 --report-interval=10 "$@" run | tee $_EXP_NAME.thr.$threads.sz.$size.test.$test.txt


            if [[ ! -z $_LOG_QUERIES ]]; then
                $MYSQL_CMD -e "SET GLOBAL slow_query_log=0, GLOBAL long_query_time=10"
                END_TIME=$($MYSQL_CMD -NB -e "SELECT ${MYSQL_DATETIME_FUNC}()")

                echo "$START_TIME,$END_TIME" > $_EXP_NAME.thr.$threads.sz.$size.test.$test.info.txt
            fi
        done

        sysbench ${test_path} --db-driver=mysql --threads=$PREPARE_THREADS \
            --tables=$_TABLES --table-size=$size --mysql-host=$_MYSQL_HOST \
            --mysql-user=$_MYSQL_USER --mysql-password=$_MYSQL_PASSWORD "$@" cleanup
    done
    popd
done
