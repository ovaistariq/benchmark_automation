#!/bin/bash

[ $# -eq 0 ] && {
    echo "usage: $0 <file>">&2
    exit 1
}

grep throughput $1|sed 's/INFO 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] //'|sed 's/ .*throughput: //'|sed 's/ .*//' > $1.csv

