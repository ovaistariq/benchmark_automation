#!/bin/bash

. $(dirname $0)/collect-common.sh

[ $# -lt 2 ] && {
    usage
    echo "Any additional arguments are passed directly to the mysql client">&2
    exit 1
}

interval=$1
duration=$2
timestamp=$(date "+%s")
shift;shift;mysql_args=$*

end_time=$(($(date "+%s") + duration))

dest=${TOOLNAME}_$(ts).gz
trap "rm -f $dest.pid" SIGINT SIGTERM SIGHUP

# get the data.
(while :; do
    [ $(date "+%s") -ge $end_time ] && exit
    mysql $mysql_args -e 'show engine innodb status\G'
    sleep $interval
done | gzip -c > $dest) &
echo $! > $dest.pid
pid=$!
# save the pid so we can monitor disk space while the tool runs, and
# terminate it if needed. 
monitor_disk_space $pid

rm -f $dest.pid 2>/dev/null

   

