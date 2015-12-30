#!/bin/bash

# converts these lines of sysbench output: 
# [  10s] threads: 16, tps: 474.30, reads: 6653.36, writes: 1897.92, response time: 39.34ms (95%), errors: 0.00, reconnects:  0.00
# to these: 
# oltp,10000,16,10,902.58,139.75,224.90

# Suggested way to invoke it for all files on a dir with files with names like this one:  
# toku.2500.oltp.io3000.tokudb_config.txt
# 
# for f in toku*; do
#     size=$(echo $f|awk -F. '{print $2}')
#     volume_type=$(echo $f|awk -F. '{print $4}')
#     test=$(echo $f|awk -F. '{print $3}')
#     ./1.sh $f $test $size $volume_type
#     echo
# done

[[ $# -lt 3 || ! -r $1 ]] && {
cat <<EOF>&2
  Error: missing or invalid arguments: ($*)
  usage: $0 <file> <bench> <size> [threads]
    where: 
     - <file> is the filename to a sysbench output file
     - <bench> is the test name (i.e. oltp, update_index, etc)
     - <size> is the table size in some multiple of rows (usually 1k)
     - [threads], optional, is the number of threads used for the test (it is also obtained from sysbench)
  Additionally, env variables control header output: 
     - If _NOHEADER is present, only data rows will be printed
     - If _ONLYHEADER is present, only the header will be printed
     - If non is present, both header and data rows will be printed
   The idea is to use _NOHEADER if you'll be concatenating the output to several captures into a single output file.  
   Bear in mind that if *both* are set, nothing will be printed. 
EOF
exit 1
}

file=$1; bench=$2; size=$3; threads=$4

header_threads=""
user_threads=""
[ -n "$threads" ] && header_threads=",user_provided_threads" && user_threads=",$threads"

[ -z "$_NOHEADER" ] && echo "workload,size,threads,ts,writes,reads,response_time,tps$header_threads"
[ -n "$_ONLYHEADER" ] && exit

sed -n '/^Threads started/,/.*test statistics:$/p' < $file | grep '\[' | awk -F ',' '{
	ts=""
        for(i=1; i<=NF; i++) {
                tmp=match($i, /\[[[:space:]]*(.*)s\]/,a)
                if(tmp) {
                        ts=a[1]
                }
                tmp=match($i, /[[:space:]]*writes:[[:space:]]+(.*)/,a)
                if(tmp) {
                        writes=a[1]
                } 
                tmp=match($i, /[[:space:]]*reads:[[:space:]]+(.*)/,a)
                if(tmp) {
                        reads=a[1]
                } 
                tmp=match($i, /[[:space:]]*response time:[[:space:]]+(.*)ms/,a)
                if(tmp) {
                        response_time=a[1]
                } 
                tmp=match($i, /[[:space:]]*tps:[[:space:]]+(.*)/,a)
                if(tmp) {
                        tps=a[1]
                }
                tmp=match($i, /[[:space:]]*threads:[[:space:]]+(.*)/,a)
                if(tmp) {
                        threads=a[1]
                }
        }
	if (ts) 
 		print bench "," size "," threads "," ts "," writes "," reads "," response_time "," tps user_threads
}' bench=$2 size=$3 workload=$4 user_threads=$user_threads

