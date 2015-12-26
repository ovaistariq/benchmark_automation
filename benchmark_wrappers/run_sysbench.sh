#!/bin/bash

[ -z "$_TESTS" -o \
  -z "$_THREADS" -o \
  -z "$_SIZE" ] && {
cat <<EOF>&2

   usage: [env var1=val1 var2=val2 ...] $0
   No direct input args, behavior is controlled by the following environment variables: 
     - _EXP_NAME : Experiment name. Optional, defaults to 'sysbench'
     - _TESTS : Quoted list of the tests to run, i.e. "oltp update_index"
     - _TESTS_PATH : The path where to look for the lua scripts defining the tests. Optional, no default value. Must include trailing '/'
     - _THREADS : Quoted list of the # of threads to use for each run, i.e. "16 32 64"
     - _SIZE : Quoted list of the table sizes to use, in rows, i.e. "100000 1000000 10000000" 
   
   Any actual input argument will be passed as is to sysbench, so you can run this like so: 

   env _TESTS="oltp update_index" _THREADS="16 32" _SIZE="1000 10000" $0 --rand-type=pareto --rand-init=on --report-interval=10 --mysql-host=sbhost --mysql-db=sbtest --max-time=7200 --max-requests=0

EOF

exit 1

}

[ -z "$_EXP_NAME" ] && _EXP_NAME="sysbench"

for test in $_TESTS; do
    mkdir $test 2>/dev/null #ignore if it exists
    pushd $test
    for threads in $_THREADS; do
	for size in $_SIZE; do
	    sysbench --test=$_TESTS_PATH$test --num-threads=$threads --oltp-table-size=$size $* prepare
	    sysbench --test=$_TESTS_PATH$test --num-threads=$threads --oltp-table-size=$size $* run | tee $_EXP_NAME.thr$threads.sz$size.test$test.txt 
	    sysbench --test=$_TESTS_PATH$test --num-threads=$threads --oltp-table-size=$size $* cleanup
        done
    done
done
