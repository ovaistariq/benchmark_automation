#!/bin/bash

# variables
TEST_MODE=${TEST_MODE:-rndrd rndwr}
FILE_TOTAL_SIZE=${FILE_TOTAL_SIZE:-600G}
IO_REQUEST_SIZE=${IO_REQUEST_SIZE:-16K}
FSYNC_FREQ=${FSYNC_FREQ:-0}
IO_MODE=${IO_MODE:-async}
FILE_FLAG=${FILE_FLAG:-direct}
BENCH_RUN_TIME=${BENCH_RUN_TIME:-300}
THREADS=${THREADS:-16}
EXP_NAME=${EXP_NAME:-sysbench}

# If set then prepare step will be skipped. This is typically used when you
# want to reuse files created in a previous test run
REUSE_FILES=${REUSE_FILES:-}

# prepare initial data set size to be used for both the tests below
echo "-- Preparing dataset of size $FILE_TOTAL_SIZE"
sysbench fileio --file-num=64 --file-total-size="${FILE_TOTAL_SIZE}" prepare

# run the benchmark now
echo "---- Benchmarking with total file size of ${FILE_TOTAL_SIZE}"
for thd in $THREADS; do
    for mode in ${TEST_MODE}; do
        echo "-- Running benchmark threads: $thd, mode: $mode"

        sysbench fileio --file-num=64 \
            --file-total-size="${FILE_TOTAL_SIZE}" \
            --file-test-mode="${mode}" --file-io-mode="${IO_MODE}" \
            --file-extra-flags="${FILE_FLAG}" \
            --file-fsync-freq="${FSYNC_FREQ}" \
            --file-block-size="${IO_REQUEST_SIZE}" \
            --time="${BENCH_RUN_TIME}" \
            --threads="${thd}" --report-interval=10 --percentile=99 run \
        | tee "$EXP_NAME.thr.$thd.sz.$FILE_TOTAL_SIZE.test.$mode.txt"
    done
done

# cleaning up initial data set
if [ -z $REUSE_FILES ]; then
    echo "-- Cleaning up dataset of size $FILE_TOTAL_SIZE"
    sysbench fileio --file-num=64 --file-total-size="${FILE_TOTAL_SIZE}" cleanup
fi
