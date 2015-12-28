#!/bin/bash

# this exports the env variables _threads, _size and _workload from file captures created with run_sysbench.sh, as 
# described in the help output 
export_fields_from_sysbench_wrapper_generated_file()
{
    [ -z "$1" -o -z "$2" ] && {
	cat <<EOF>&2
   usage: $0 <filename> "<experiment name>"
   Where 
    - <filename> is the name of a capture created by run_sysbench.sh (i.e. sample.thr1.sz10.testoltp.txt)
    - <experiment name> is the value for _EXP_NAME used when running run_sysbench.sh (i.e. 'test' in the above example)
EOF

    return 1	
    }
    unset _threads _size _workload
    export _threads=$(echo $1|awk -F. '{print $2}'|sed 's/thr//')
    export _size=$(echo $1|awk -F. '{print $3}'|sed 's/sz//')
    export _workload=$(echo $1|awk -F. '{print $4}'|sed "s/$2//")
}
