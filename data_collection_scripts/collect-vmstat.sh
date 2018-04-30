#!/bin/bash

. $(dirname $0)/collect-common.sh

[ $# -lt 3 ] && {
    usage
    exit 1
}

interval=$1
duration=$2
output_prefix=$3

dest="${output_prefix}.${TOOLNAME}_$(ts).gz"
trap "rm -f $dest.pid" SIGINT SIGTERM SIGHUP

vmstat_to_csv()
{
while read line; do
    [ -z "$printed_header" ] && {
	printed_header=1
	read line
	echo "ts,$(echo $line|sed 's/ /,/g'|sed 's/,$//')"
	continue
    }
    echo "$(date '+%H:%M:%S'),$(echo $line|sed 's/ /,/g'|sed 's/,$//')"
done
}

# get the data.
vmstat $interval $(( $duration/$interval )) | vmstat_to_csv | gzip -c > $dest &
echo $! > $dest.pid
pid=$!
# save the pid so we can monitor disk space while the tool runs, and
# terminate it if needed. 
monitor_disk_space $pid

rm -f $dest.pid 2>/dev/null

