#!/bin/bash

. $(dirname $0)/collect-common.sh

[ $# -ne 2 ] && {
    usage
    exit 1
}

interval=$1
duration=$2
timestamp=$(date "+%s")
shift;shift;

# telecaster:lab fernandoipar$ mongostat
# insert query update delete getmore command flushes mapped vsize   res faults qr|qw ar|aw netIn netOut conn     time
#     *0    *0     *0     *0       0     1|0       0  80.0M  2.6G 45.0M      0   0|0   0|0   79b    10k    1 09:28:41
#     *0    *0     *0     *0       0     1|0       0  80.0M  2.6G 45.0M      0   0|0   0|0   79b    10k    1 09:28:42
#     *0    *0     *0     *0       0     1|0       0  80.0M  2.6G 45.0M      0   0|0   0|0   79b    10k    1 09:28:43
#     *0    *0     *0     *0       0     1|0       0  80.0M  2.6G 45.0M      0   0|0   0|0   79b    10k    1 09:28:49
#     *0    *0     *0     *0       0     2|0       0  80.0M  2.6G 45.0M      0   0|0   0|0  133b    10k    1 09:28:50
# insert query update delete getmore command flushes mapped vsize   res faults qr|qw ar|aw netIn netOut conn     time
#     *0    *0     *0     *0       0     1|0       0  80.0M  2.6G 45.0M      0   0|0   0|0   79b    10k    1 09:28:51
#     *0    *0     *0     *0       0     1|0       0  80.0M  2.6G 45.0M      0   0|0   0|0   79b    10k    1 09:28:52
#     *0    *0     *0     *0       0     1|0       0  80.0M  2.6G 45.0M      0   0|0   0|0   79b    10k    1 09:28:53
#     *0    *0     *0     *0       0     1|0       0  80.0M  2.6G 45.0M      0   0|0   0|0   79b    10k    1 09:28:54

mongostat_to_csv()
{
printed_header=0
while read line; do
    [ $(echo $line|grep -c 'insert') -gt 0 ] && {
	[ $printed_header -eq 0 ] && {
	    printed_header=1
	    echo $line|sed 's/  */,/g
                            s/|/,/g
			    s/command/command_local,command_replicated/'
	}
	continue
    }
    echo $line | tr -d '*' | sed 's/|/,/g
                                  s/ /,/g
                                  s/b//g
                                  s/k/*1024/g
                                  s/M/*1048576/g
                                  s/G/*1073741824/g'
done
}

dest=${TOOLNAME}_$(ts).gz
trap "rm -f $dest.pid" SIGINT SIGTERM SIGHUP
$TOOLNAME -n $duration $interval $* | mongostat_to_csv | gzip -c > $dest & 
echo $! > $dest.pid
pid=$!
# save the pid so we can monitor disk space while the tool runs, and
# terminate it if needed. 
monitor_disk_space $pid

rm -f $dest.pid 2>/dev/null

   

