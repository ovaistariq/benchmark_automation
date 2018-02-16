#!/bin/bash

# converts these lines of sysbench output: 
# sysbench 1.0.12 (using bundled LuaJIT 2.1.0-beta2)
#
# Running the test with following options:
# Number of threads: 8
# Report intermediate results every 10 second(s)
# Initializing random number generator from current time
#
#
# Initializing worker threads...
#
# Threads started!
#
# 10,8,3379.90,67615.35,47332.56,13521.89,6760.89,3.49,0.30,0.00
# 20,8,3326.02,66526.92,46570.52,13303.86,6652.53,3.49,0.50,0.00
# 30,8,3346.74,66937.12,46856.61,13386.84,6693.67,3.43,0.20,0.00
# 40,8,3333.41,66687.51,46683.08,13336.62,6667.81,3.55,1.00,0.00
# 50,8,3352.89,67059.08,46942.42,13410.68,6705.99,3.49,0.20,0.00
# 60,8,3373.96,67482.87,47238.32,13496.43,6748.12,3.25,0.20,0.00
# SQL statistics:
#    queries performed:
#        read:                            2816366
#        write:                           804615
#        other:                           402314
#        total:                           4023295
#    transactions:                        201145 (3352.13 per sec.)
#    queries:                             4023295 (67049.12 per sec.)
#    ignored errors:                      24     (0.40 per sec.)
#    reconnects:                          0      (0.00 per sec.)
#
# General statistics:
#    total time:                          60.0025s
#    total number of events:              201145
#
# Latency (ms):
#         min:                                  1.84
#         avg:                                  2.38
#         max:                                 17.75
#         99th percentile:                      3.49
#         sum:                             479672.29
#
# Threads fairness:
#    events (avg/stddev):           25143.1250/42.69
#    execution time (avg/stddev):   59.9590/0.00
#
# to these:
# oltp,10000,10,8,3379.90,67615.35,47332.56,13521.89,6760.89,3.49,0.30,0.00
# oltp,10000,20,8,3326.02,66526.92,46570.52,13303.86,6652.53,3.49,0.50,0.00
# oltp,10000,30,8,3346.74,66937.12,46856.61,13386.84,6693.67,3.43,0.20,0.00
# oltp,10000,40,8,3333.41,66687.51,46683.08,13336.62,6667.81,3.55,1.00,0.00
# oltp,10000,50,8,3352.89,67059.08,46942.42,13410.68,6705.99,3.49,0.20,0.00
# oltp,10000,60,8,3373.96,67482.87,47238.32,13496.43,6748.12,3.25,0.20,0.00

# Suggested way to invoke it for all files on a dir with files with names like this one:  
# sysbench.thr.8.sz.10000.test.oltp_read_write.txt
# 
# for f in sysbench*; do
#     size=$(echo $f|awk -F. '{print $5}')
#     test=$(echo $f|awk -F. '{print $7}')
#     ./1.sh $f $test $size
#     echo
# done

[[ $# -lt 3 || ! -r $1 ]] && {
cat <<EOF>&2
  Error: missing or invalid arguments: ($*)
  usage: $0 <file> <bench> <size>
    where: 
     - <file> is the filename to a sysbench output file
     - <bench> is the test name (i.e. oltp, update_index, etc)
     - <size> is the table size in some multiple of rows (usually 1k)
  Additionally, env variables control header output: 
     - If _NOHEADER is present, only data rows will be printed
     - If _ONLYHEADER is present, only the header will be printed
     - If non is present, both header and data rows will be printed
   The idea is to use _NOHEADER if you'll be concatenating the output to
   several captures into a single output file.  
   Bear in mind that if *both* are set, nothing will be printed. 
EOF
exit 1
}

file=$1; bench=$2; size=$3

[ -z "$_NOHEADER" ] && echo "workload,size,ts,threads,tps,qps,reads,writes,other,response_time,errors,reconnects"
[ -n "$_ONLYHEADER" ] && exit

output_start=$(grep -n "Threads started\!" $file | awk -F: '{print $1}')
output_end=$(grep -n "SQL statistics:" $file | awk -F: '{print $1}')

awk 'NR=='$((${output_start}+2))',NR=='$((${output_end}-1))' {print "'$bench','$size',"$0}' $file

