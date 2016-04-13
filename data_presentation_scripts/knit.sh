#!/bin/bash
# knits an Rmd file into md and html
usage()
{
    cat <<EOF>&2
usage: $0 <Rmd file> [--debug]
Knits the input file into md and html output files. 
If --debug is present, the Rout file is not removed
EOF
    exit
}

err()
{
    echo $* >&2
    exit 
}

[ $# -eq 0 ] && usage
name=$(echo $1|sed 's/\.Rmd$//')
[ -f ${name}.Rmd ] || err "Cannot find or read ${name}.Rmd"

trap "rm -f /tmp/knit.$$.R" SIGINT SIGTERM

cat <<EOF>/tmp/knit.$$.R 
require(knitr)
require(markdown)
knit('${name}.rmd','${name}.md')
markdownToHTML('${name}.md','${name}.html')
browseURL(paste('file:///', file.path(getwd(), '${name}.html'), sep=''))
EOF

rm_Rout="knit.$$.Rout"
[ "$2" == "--debug" ] && rm_Rout=""

R CMD BATCH /tmp/knit.$$.R 
rm -f /tmp/knit.$$.R $rm_Rout 
