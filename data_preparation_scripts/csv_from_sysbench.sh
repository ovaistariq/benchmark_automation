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

[[ $# -ne 3 || ! -r $1 ]] && {
cat <<EOF>&2
  Error: missing or invalid arguments: ($*)
  usage: $0 <file> <bench> <size>
    where: 
     - <file> is the filename to a sysbench output file
     - <bench> is the test name (i.e. oltp, update_index, etc)
     - <size> is the table size in some multiple of rows (usually 1k)

EOF
exit 1
}

file=$1; bench=$2; size=$3

echo "workload,size,threads,ts,writes,reads,response_time,tps"

cat $file | awk -F ',' '{
	f1=""
        for(i=1; i<=NF; i++) {
                tmp=match($i, /\[[[:space:]]*(.*)s\]/,a)
                if(tmp) {
                        ts=a[1]
                }
                tmp=match($i, /[[:space:]]*writes:[[:space:]]+(.*)/,b)
                if(tmp) {
                        writes=b[1]
                }
                tmp=match($i, /[[:space:]]*reads:[[:space:]]+(.*)/,b)
                if(tmp) {
                        reads=b[1]
                }
                tmp=match($i, /[[:space:]]*response time:[[:space:]]+(.*)ms/,b)
                if(tmp) {
                        response_time=b[1]
                }
                tmp=match($i, /[[:space:]]*tps:[[:space:]]+(.*)/,b)
                if(tmp) {
                        tps=b[1]
                }
                tmp=match($i, /[[:space:]]*threads:[[:space:]]+(.*)/,b)
                if(tmp) {
                        threads=b[1]
                }
        }
	if (ts)
	print bench","size","threads","ts","writes","reads","response_time","tps
}' bench=$bench size=$size 
