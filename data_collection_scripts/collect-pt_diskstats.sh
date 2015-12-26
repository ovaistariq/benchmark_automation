#!/bin/bash

. $(dirname $0)/collect-common.sh

[ $# -ne 2 ] && {
    usage
    exit 1
}

interval=$1
duration=$2
timestamp=$(date "+%s")

dest=${TOOLNAME}_$(ts).gz
trap "rm -f $dest.pid" SIGINT SIGTERM SIGHUP
# get the header.
pt-diskstats --iterations=$duration --interval=$interval | gzip -c > $dest &
echo $! > $dest.pid
pid=$!
# save the pid so we can monitor disk space while the tool runs, and
# terminate it if needed. 
monitor_disk_space $pid

rm -f $dest.pid 2>/dev/null

   

