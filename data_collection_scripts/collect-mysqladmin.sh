#!/bin/bash

. $(dirname $0)/collect-common.sh

[ $# -ne 2 ] && {
    usage
    exit 1
}

interval=$1
duration=$2

dest=${TOOLNAME}_$(ts).gz
trap "rm -f $dest.pid" SIGINT SIGTERM SIGHUP
# get the header. -r should not be needed here, but just in case the output columns are ever different based on that option
$TOOLNAME ext -i 1 -c 1 -r|grep -v '-'|awk -F '|' '{print $2}'|grep -v ^$|sed 's/Variable_name/Timestamp/g'|tr '\n' ','|\
  sed 's/  */ /g
       s/^ //
       s/,$/\n/' > $dest.header
# now get the capture. since we're using -r, discard the first row 
read_first_row=0
ts=1
arg_duration=""
[ -n "$duration" -a $duration -gt 0 ] && arg_duration="-c $duration"
$TOOLNAME ext -i $interval $arg_duration -r | awk -F '|' '{print $3}'|sed 's/^ //g'|sed 's/  *$/ /g'|grep -v ^$|sed 's/^ $/_/g' |tr '\n' ','| sed "s/Value/|/g" | tr '|' '\n' |grep -v ^$|\
  sed 's/^  *//g
  s/  */ /g
  s/,$//'| while read row; do [ $read_first_row -gt 0 ] && echo "$ts $row"; ts=$((ts+1)); read_first_row=1; done | gzip -c >> $dest & 
echo $! > $dest.pid
pid=$!
# save the pid so we can monitor disk space while the tool runs, and
# terminate it if needed. 
monitor_disk_space $pid

rm -f $dest.pid 2>/dev/null

   

