#!/bin/bash

. $(dirname $0)/collect-common.sh

[ $# -ne 3 ] && {
    usage
    exit 1
}

interval=$1
duration=$2
output_prefix=$3

dest="${output_prefix}.${TOOLNAME}_$(ts).gz"
trap "rm -f $dest.pid" SIGINT SIGTERM SIGHUP
# get the header. -r should not be needed here, but just in case the output columns are ever different based on that option
$TOOLNAME ext -i 1 -c 1 -r | grep -v Variable_name | grep "|" | awk -F '|' '{gsub(/ /, "", $2); print $2}' | tr '\n' ',' > $dest.header

# now get the capture. since we're using -r, discard the first row 
arg_duration=""
[ -n "$duration" -a $duration -gt 0 ] && arg_duration="-c $(( $duration/$interval ))"

read_first_row=0

$TOOLNAME ext -i $interval $arg_duration -r | grep -v Variable_name \
    | grep "|" | awk -F '|' '{gsub(/ /, "", $3); print $3}' | tr '\n' ',' \
    | while read row; do [ $read_first_row -gt 0 ] && echo "$row"; read_first_row=1; done | gzip -c >> $dest &

echo $! > $dest.pid
pid=$!
# save the pid so we can monitor disk space while the tool runs, and
# terminate it if needed. 
monitor_disk_space $pid

rm -f $dest.pid 2>/dev/null

