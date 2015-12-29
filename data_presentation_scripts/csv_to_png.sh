#!/bin/bash

[ -z "$_INPUT_FILE" -o \
  -z "$_X_AXIS" -o \
  -z "$_Y_AXIS" -o \
  -z "$_X_AXIS_LABEL" -o \
  -z "$_Y_AXIS_LABEL" -o \
  -z "$_GRAPH_TITLE" ] && {
cat <<EOF>&2
   usage: [env var1=val1 var2=val2 ...] $0 
   No input args, behavior is controlled by the following environment variables:
     - _INPUT_FILE : the input (csv) file name
     - _OUTPUT_FILE : the output (image) file name
     - _OUTPUT_RATIO : the ratio to use for ggsave
     - _FACTOR : the variable name to use for factoring (optional) 
     - _FACTOR_LABEL : the label to print for the factoring variable (only if _FACTOR is set
     - _X_AXIS : the variable name to use for the X axis
     - _Y_AXIS : the same, for the Y axis
     - _X_AXIS_LABEL : the label to use for the X axis
     - _Y_AXIS_LABEL : the same, for the Y axis
     - _Y_AXIS_COERCE_INT : should the varialbe used for the Y axis be coerced to an integer? (default is no)
     - _FACET_X  : if set, facet X on this variable
     - _FACET_Y  : if set, facet Y on this variable
     - _GRAPH_TITLE : the graph title

Examples: 

env _INPUT_FILE=alldata.csv _OUTPUT_FILE=genplot.png _FACTOR=workload _FACTOR_LABEL="Workload" _X_AXIS=ts _X_AXIS_LABEL="Time in secs (10 sec increment)" _Y_AXIS=writes _Y_AXIS_LABEL="write throughput" _Y_AXIS_COERCE_INT=1 _GRAPH_TITLE="TokuDB Write Throughput" ./csv_to_png.sh

env _FACET_X=size _INPUT_FILE=alldata.csv _OUTPUT_FILE=genplot.png _FACTOR=workload _FACTOR_LABEL="Workload" _X_AXIS=ts _X_AXIS_LABEL="Time in secs (10 sec increment)" _Y_AXIS=writes _Y_AXIS_LABEL="write throughput" _Y_AXIS_COERCE_INT=1 _GRAPH_TITLE="TokuDB Write Throughput" ./csv_to_png.sh

EOF
exit 1
}

input=$_INPUT_FILE
output=${_OUTPUT_FILE:-"~/genplot.png"}
ratio=${_OUTPUT_RATIO:-2}
factor=$_FACTOR
factor_label=$_FACTOR_LABEL
x_axis=$_X_AXIS
y_axis=$_Y_AXIS
facet_x=${_FACET_X:-"."}
facet_y=${_FACET_Y:-"."}
coerce_y=${_Y_AXIS_COERCE_INT:-0}

facet="+ facet_grid($facet_x ~ $facet_y, labeller = label_both)"
[ "$facet_x" == "." -a "$facet_y" == "." ] && facet=""

colour=""
scale_colour=""
[ -n "$factor" ] && {
    colour=", colour=as.factor($factor)"
    scale_colour="+ scale_colour_discrete(name = \"$factor_label\")"
}

trap "rm -f /tmp/csv_to_png.$$.r" SIGINT SIGTERM

cat <<EOF>/tmp/csv_to_png.$$.r
require(ggplot2)
require(ggthemes) # for extended_range_breaks()
require(plyr) # to rename columns

data <- read.csv("$input", header=TRUE)

# some duplication here with the goal of making script generation simpler ...
data\$display_y_axis <- data\$$y_axis

if ($coerce_y == 1) { 
   data\$display_y_axis <- as.integer(data\$$y_axis)
} 

ggplot(data, aes(x=$x_axis, y=$y_axis$colour)) + geom_jitter() $scale_colour $facet + xlab("$_X_AXIS_LABEL") + ylab("$_Y_AXIS_LABEL") + ggtitle("$_GRAPH_TITLE") + scale_y_continuous(breaks = extended_range_breaks()(rbind(0,data\$display_y_axis)))  + expand_limits(x=0, y=0)  + theme_bw() + theme(panel.grid = element_line(colour="#010101",size=1), panel.background = element_rect(colour="#000000"), plot.background = element_rect(colour="#000000"), strip.background = element_rect(colour="#010101"))
ggsave("$output",scale=$ratio)

EOF

R CMD BATCH /tmp/csv_to_png.$$.r && rm -f *Rout || cat /tmp/csv_to_png.$$.r # print the generated script if it fails, for debugging

rm -f /tmp/csv_to_png.$$.r
