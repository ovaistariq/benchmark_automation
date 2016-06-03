#!/bin/bash

[ $# -eq 0 ] && {
    echo "usage: $0 <file>">&2
    exit 1
}

fn="$1"

sed -n '/^$/,//p' < "$fn" | grep -v ^$ | (
	i=0
	while read l; do
	    [ $i -eq 0 ] && echo -n "i,$l" || echo "$i,$l"
	    i=$((i+1))
	done
)

