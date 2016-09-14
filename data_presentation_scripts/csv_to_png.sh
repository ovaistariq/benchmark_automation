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
     - _AXIS_HAVE_0 : should the axis be forced to include 0 as a value (default is yes)
     - _FACET_X  : if set, facet X on this variable
     - _FACET_Y  : if set, facet Y on this variable
     - _GRAPH_TITLE : the graph title
     - _R_EXP : if set, add this R expression to the generated script, after reading the csv file, and before generating the graph
       The csv file is loaded into the 'data' variable. Remember to use single quotes or otherwise escape '$' for this variable. 
     - _DRY_RUN : if set, don't do anything, just print the generated R script to stdout

Examples: 

env _INPUT_FILE=alldata.csv _OUTPUT_FILE=genplot.png _FACTOR=workload _FACTOR_LABEL="Workload" _X_AXIS=ts _X_AXIS_LABEL="Time in secs (10 sec increment)" _Y_AXIS=writes _Y_AXIS_LABEL="write throughput" _Y_AXIS_COERCE_INT=1 _GRAPH_TITLE="TokuDB Write Throughput" ./csv_to_png.sh

env _FACET_X=size _INPUT_FILE=alldata.csv _OUTPUT_FILE=genplot.png _FACTOR=workload _FACTOR_LABEL="Workload" _X_AXIS=ts _X_AXIS_LABEL="Time in secs (10 sec increment)" _Y_AXIS=writes _Y_AXIS_LABEL="write throughput" _Y_AXIS_COERCE_INT=1 _GRAPH_TITLE="TokuDB Write Throughput" ./csv_to_png.sh

env _FACET_X=size _INPUT_FILE=alldata.csv _OUTPUT_FILE=genplot.png _FACTOR=workload _FACTOR_LABEL="Workload" _X_AXIS=ts _X_AXIS_LABEL="Time in secs (10 sec increment)" _Y_AXIS=writes _Y_AXIS_LABEL="write throughput" _Y_AXIS_COERCE_INT=1 _GRAPH_TITLE="TokuDB Write Throughput" _R_EXP='data <- data[data$size == 1000,]' ./csv_to_png.sh

env _FACET_X=size _INPUT_FILE=alldata.csv _OUTPUT_FILE=genplot.png _FACTOR=workload _FACTOR_LABEL="Workload" _X_AXIS=ts _X_AXIS_LABEL="Time in secs (10 sec increment)" _Y_AXIS=writes _Y_AXIS_LABEL="write throughput" _Y_AXIS_COERCE_INT=1 _GRAPH_TITLE="TokuDB Write Throughput" _R_EXP='data <- subset(subset(data, size == 1000), workload %in% c("update_index", "update_non_index"))' ./csv_to_png.sh

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

facet="+ facet_grid($facet_x ~ $facet_y, labeller = label_custom)"
[ "$facet_x" == "." -a "$facet_y" == "." ] && facet=""

colour=""
scale_colour=""
[ -n "$factor" ] && {
    colour=", colour=as.factor($factor)"
    scale_colour="+ scale_colour_discrete(name = \"$factor_label\")"
}

axis_at_0=" expand_limits(x=0, y=0) + "
[ "$_AXIS_HAVE_0" == "no" ] && axis_at_0=""

trap "rm -f /tmp/csv_to_png.$$.r" SIGINT SIGTERM

cat <<EOF>/tmp/csv_to_png.$$.r
require(ggplot2)
#require(ggthemes) # for extended_range_breaks()
require(plyr) # to rename columns

## the next functions copied from ggthemes, with just a minor change to 
## extended_range_breaks_

# Much of this code is copied from the labeling package.
.simplicity <- function(q, Q, j, lmin, lmax, lstep) {
  eps <- .Machine\$double.eps * 100

  n <- length(Q)
  i <- match(q, Q)[1]
  v <- ifelse( (lmin %% lstep < eps ||
                 lstep - (lmin %% lstep) < eps) &&
                lmin <= 0 && lmax >= 0, 1, 0)
  1 - (i - 1) / (n - 1) - j + v
}

.simplicity.max <- function(q, Q, j) {
  n <- length(Q)
  i <- match(q, Q)[1]
  v <- 1

  1 - (i - 1) / (n - 1) - j + v
}

.coverage <- function(dmin, dmax, lmin, lmax) {
  range <- dmax - dmin
  1 - 0.5 * ( (dmax - lmax) ^ 2 + (dmin - lmin) ^ 2) / ( (0.1 * range) ^ 2)
}

.coverage.max <- function(dmin, dmax, span) {
  range <- dmax - dmin
  if (span > range) {
    half <- (span - range) / 2
    1 - 0.5 * (half ^ 2 + half ^ 2) / ( (0.1 * range) ^ 2)
  }
  else {
    1
  }
}

.density <- function(k, m, dmin, dmax, lmin, lmax) {
  r <- (k - 1) / (lmax - lmin)
  rt <- (m - 1) / (max(lmax, dmax) - min(dmin, lmin))
  2 - max( r / rt, rt / r )
}

.density.max <- function(k, m) {
  if (k >= m)
    2 - (k - 1) / (m - 1)
  else
    1
}

.legibility <- function(lmin, lmax, lstep) {
  1      ## did all the legibility tests in C#, not in R.
}

# from scales package
zero_range <- function(x, tol = 1000 * .Machine\$double.eps) {
  if (length(x) == 1)
    return(TRUE)
  if (length(x) != 2)
    stop("x must be length 1 or 2")
  if (any(is.na(x)))
    return(NA)
  if (x[1] == x[2])
    return(TRUE)
  if (all(is.infinite(x)))
    return(FALSE)
  m <- min(abs(x))
  if (m == 0)
    return(FALSE)
  abs( (x[1] - x[2]) / m) < tol
}

# from scales package
precision <- function(x) {
  rng <- range(x, na.rm = TRUE)
  span <- if (zero_range(rng))
    abs(rng[1])
  else diff(rng)
  10 ^ floor(log10(span))
}

smart_digits <- function(x, ...) {
  if (length(x) == 0)
    return(character())
  accuracy <- precision(x)
  x <- round(x / accuracy) * accuracy
  format(x, ...)
}

smart_digits_format <- function(x, ...) {
    function(x) smart_digits(x, ...)
}

extended_range_breaks_ <- function(dmin, dmax, n = 5,
                                   Q = c(1, 5, 2, 2.5, 4, 3),
                                   w = c(0.25, 0.2, 0.5, 0.05)) {
  eps <- .Machine\$double.eps * 100

  if (dmin > dmax) {
    temp <- dmin
    dmin <- dmax
    dmax <- temp
  }

  if (dmax - dmin < eps) {
    #if the range is near the floating point limit,
    #let seq generate some equally spaced steps.
    return(seq(from = dmin, to = dmax, length.out = n))
  }

  n <- length(Q)

  best <- list()
  best\$score <- -2

  j <- 1
  while (j < Inf) {
    for (q in Q) {
      sm <- .simplicity.max(q, Q, j)

      if ( (w[1] * sm + w[2] + w[3] + w[4]) < best\$score) {
        j <- Inf
        break
      }

      k <- 2
      while (k < Inf) {
        dm <- .density.max(k, n)
        if ( (w[1] * sm + w[2] + w[3] * dm + w[4]) < best\$score)
          break

        delta <- (dmax - dmin) / (k + 1) / j / q
        z <- ceiling(log(delta, base = 10))

        while (z < Inf) {
          step <- j * q * 10 ^ z

          cm <- .coverage.max(dmin, dmax, step * (k - 1))

          if ( (w[1] * sm + w[2] * cm + w[3] * dm + w[4]) < best\$score)
            break

          min_start <- floor(dmax / (step)) * j - (k - 1) * j
          max_start <- ceiling(dmin / (step)) * j

          if (min_start > max_start) {
            z <- z + 1
            next
          }

          for (start in min_start:max_start) {
            lmin <- start * (step / j)
            lmax <- lmin + step * (k - 1)
            lstep <- step

            s <- .simplicity(q, Q, j, lmin, lmax, lstep)
            c <- .coverage(dmin, dmax, lmin, lmax)
            g <- .density(k, n, dmin, dmax, lmin, lmax)
            l <- .legibility(lmin, lmax, lstep)

            score <- w[1] * s + w[2] * c + w[3] * g + w[4] * l

            if (score > best\$score
               && lmin >= dmin
               && lmax <= dmax) {
                best <- list(lmin = lmin,
                             lmax = lmax,
                             lstep = lstep,
                             score = score)
            }
          }
          z <- z + 1
        }
        k <- k + 1
      }
    }
    j <- j + 1
  }
  breaks <- seq(from = best\$lmin, to = best\$lmax, by = best\$lstep)
  if (length(breaks) >= 2) {
      breaks[1] <- dmin
      breaks[length(breaks)] <- dmax
  }
  rbind(0,breaks)
}

#' @rdname range_breaks
#' @param ... other arguments passed to \code{extended_range_breaks_}
#' @return A function which returns breaks given a vector.
#' @export
extended_range_breaks <- function(n = 5, ...)  {
    function(x) {
        extended_range_breaks_(min(x), max(x), n, ...)
    }
}

## end of functions copied from ggthemes

label_custom <- function(variable, value) {
    if (variable=="size") {
        return (paste(variable,":",value))
    } else if (variable=="engine"){
        return (as.character(value))
    } else {
	return (value)
    }
}

data <- read.csv("$input", header=TRUE)

# some duplication here with the goal of making script generation simpler ...
data\$display_y_axis <- data\$$y_axis

if ($coerce_y == 1) { 
   data\$display_y_axis <- as.integer(data\$$y_axis)
} 

$_R_EXP

ggplot(data, aes(x=$x_axis, y=$y_axis$colour)) + geom_jitter() $scale_colour $facet + xlab("$_X_AXIS_LABEL") + ylab("$_Y_AXIS_LABEL") + ggtitle("$_GRAPH_TITLE") + scale_y_continuous(breaks = extended_range_breaks()(data\$display_y_axis))  + $axis_at_0 theme_bw() + theme(panel.grid = element_line(colour="#010101",size=1), panel.background = element_rect(colour="#000000"), plot.background = element_rect(colour="#000000"), strip.background = element_rect(colour="#010101"), text=element_text(size=20), strip.text=element_text(size=24))
ggsave("$output",scale=$ratio)

EOF

[ -n "$_DRY_RUN" ] && cat /tmp/csv_to_png.$$.r || {
    R CMD BATCH /tmp/csv_to_png.$$.r && rm -f *Rout || cat /tmp/csv_to_png.$$.r # print the generated script if it fails, for debugging
}
rm -f /tmp/csv_to_png.$$.r
