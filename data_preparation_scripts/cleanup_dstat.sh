#!/bin/bash

[ $# -eq 0 ] && {
    cat <<EOF>&2
   usage: $0 <file>
Optionally set one of the following env variables: 
   _NOHEADER (do not print the header line)
   _ONLYHEADER (only print the header line)
EOF
    echo "usage: $0 <file>">&2
    exit 1
}

fn="$1"
printheader=1
onlyheader=0
[ -n "$_NOHEADER" ] && printheader=0
[ -n "$_ONLYHEADER" ] && onlyheader=1

sed -n '/^$/,//p' < "$fn" | grep -v ^$ | (
	i=0
	while read l; do
	    if [ $i -eq 0 ]; then
	       [ $printheader -eq 1 ] && echo -n "i,$l"
	    elif [ $i -eq 1 ]; then
		[ $printheader -eq 1 ] && echo "$i,$l"
	    else
		[ $onlyheader -eq 1 ] && break
		echo "$i,$l"
	    fi
	    i=$((i+1))
	done
)

