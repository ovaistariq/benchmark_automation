#!/bin/bash
# this is needed because mongostat does not (currently) support fixing the unit for measurements, so
# it adds it as the suffix. This means something is needed before values like 20b and 1M can be used coherently. 
# the collect-mongostat.sh script replaces each unit suffix for the corresponding multiplier (i.e. *1024 for k), and
# this script uses R to eval those math expressions and save a new csv with the normalized values (normalized for unit 'bytes'). 

[ ! -r $1 ] && {
    cat <<EOF>&2
   usage: $0 <file>
   uses R to evaluate any math expressions in <file> (i.e. 12*1024) and create a new csv file with the results
EOF
    exit 1 
}

trap "rm -f /tmp/script.$$.R" SIGHUP SIGINT SIGTERM
output=$(echo $1|sed 's/csv/postproc.csv/')
cat <<EOF>/tmp/script.$$.R

df <- read.csv("$1",header=T,stringsAsFactors=F)

for (row in 1:nrow(df)) {
   for (col in 1:ncol(df)) {
       if (length(grep("[0-9][0-9]:[0-9][0-9]", df[row,col])) == 0) {
           df[row,col] <- eval(parse(text=as.character(df[row,col])))
       }
   }
}

write.csv(df,"$output",row.names = FALSE)

EOF

R CMD BATCH /tmp/script.$$.R
rm -f /tmp/script.$$.R script*Rout
