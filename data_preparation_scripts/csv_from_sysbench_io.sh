#!/bin/bash

# sysbench 1.0.12 (using bundled LuaJIT 2.1.0-beta2)
#
# Running the test with following options:
# Number of threads: 1
# Report intermediate results every 10 second(s)
# Initializing random number generator from current time
#
#
# Extra file open flags: 3
# 64 files, 53.125GiB each
# 3.3203TiB total file size
# Block size 4KiB
# Number of IO requests: 0
# Read/Write ratio for combined random IO test: 1.50
# Calling fsync() at the end of test, Enabled.
# Using asynchronous I/O mode
# Doing random read test
# Initializing worker threads...
#
# Threads started!
#
#
# converts these lines of sysbench output: 
# [ 10s ] reads: 635.91 MiB/s writes: 0.00 MiB/s fsyncs: 0.00/s latency (ms,99%): 0.019
# [ 20s ] reads: 668.86 MiB/s writes: 0.00 MiB/s fsyncs: 0.00/s latency (ms,99%): 0.015
# [ 30s ] reads: 655.17 MiB/s writes: 0.00 MiB/s fsyncs: 0.00/s latency (ms,99%): 0.018
# [ 40s ] reads: 645.86 MiB/s writes: 0.00 MiB/s fsyncs: 0.00/s latency (ms,99%): 0.020
# [ 50s ] reads: 599.99 MiB/s writes: 0.00 MiB/s fsyncs: 0.00/s latency (ms,99%): 0.020
# [ 60s ] reads: 502.34 MiB/s writes: 0.00 MiB/s fsyncs: 0.00/s latency (ms,99%): 0.019
#
# File operations:
#    reads/s:                      121340.74
#    writes/s:                     0.00
#    fsyncs/s:                     0.00
#
# Throughput:
#    read, MiB/s:                  473.99
#    written, MiB/s:               0.00
#
# General statistics:
#    total time:                          1200.0002s
#    total number of events:              145609906
#
# Latency (ms):
#         min:                                  0.00
#         avg:                                  0.01
#         max:                                148.37
#         99th percentile:                      0.02
#         sum:                            1151102.35
#
# Threads fairness:
#    events (avg/stddev):           145609906.0000/0.00
#    execution time (avg/stddev):   1151.1024/0.00
#
#
# to these:
# 10,47332.56,13521.89,6760.89,3.49
# 20,46570.52,13303.86,6652.53,3.49
# 30,46856.61,13386.84,6693.67,3.43
# 40,46683.08,13336.62,6667.81,3.55
# 50,46942.42,13410.68,6705.99,3.49
# 60,47238.32,13496.43,6748.12,3.25


[[ $# -lt 1 || ! -r $1 ]] && {
cat <<EOF>&2
  Error: missing or invalid arguments: ($*)
  usage: $0 <file>
    where: 
     - <file> is the filename to a sysbench output file
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

file=$1

[ -z "$_NOHEADER" ] && echo "ts,reads,writes,fsyncs,response_time"
[ -n "$_ONLYHEADER" ] && exit

sed -n '/^Threads started/,/.*File operations:$/p' < $file | grep '\[' \
| sed -e 's/\[//g' -e 's/reads://g' -e 's/writes://g' -e 's/fsyncs://g' -e 's/\/s//g' -e 's/latency.*://g' -e 's/\]//g' \
| awk '{print $1","$2","$4","$6","$7}' \
| sed -E 's/([0-9]+)s/\1/g'

