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

diskstats_to_csv()
{
printed_header=0
while read line; do
    [ $(echo $line|grep -c '#ts') -gt 0 ] && {
       [ $printed_header -eq 0 ] && {
	    printed_header=1
	    echo $line|sed 's/^ *#//
			    s/  */,/g'
       }
       continue
    }
    echo $line|grep ^$>/dev/null && continue
    echo $line|sed 's/^ *//
		    s/%//g
		    s/  */,/g'
done
}

# get the data.
pt-diskstats --iterations=$duration --interval=$interval | diskstats_to_csv | gzip -c > $dest &
echo $! > $dest.pid
pid=$!
# save the pid so we can monitor disk space while the tool runs, and
# terminate it if needed. 
monitor_disk_space $pid

rm -f $dest.pid 2>/dev/null

   

