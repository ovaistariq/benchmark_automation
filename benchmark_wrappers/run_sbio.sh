$ cat sysbench.sh
#!/bin/bash

# variables
FILE_TOTAL_SIZE=${FILE_TOTAL_SIZE:-600G}
IO_REQUEST_SIZE=${IO_REQUEST_SIZE:-16K}
FSYNC_FREQ=${FSYNC_FREQ:-0}
BENCH_RUN_TIME=${BENCH_RUN_TIME:-300}
THREADS=${THREADS:-16}
EXP_NAME=${EXP_NAME:-sysbench}

# helper functions
prepare_benchmark() {
    echo "-- Preparing dataset of size $FILE_TOTAL_SIZE"
    sysbench --test=fileio --file-num=64 \
        --file-total-size=${FILE_TOTAL_SIZE} prepare
}

cleanup_benchmark() {
    echo "-- Cleaning up dataset of size $FILE_TOTAL_SIZE"
    sysbench --test=fileio --file-num=64 \
        --file-total-size=${FILE_TOTAL_SIZE} cleanup
}

run_benchmark() {
    for thd in $THREADS; do
        for mode in rndrd rndwr; do
            echo "-- Running benchmark threads: $thd, mode: $mode"
            sysbench --test=fileio --file-num=64 \
                --file-total-size=${FILE_TOTAL_SIZE} \
                --file-test-mode=${mode} --file-io-mode=async \
                --file-extra-flags=direct \
                --file-fsync-freq=${FSYNC_FREQ} \
                --file-block-size=${IO_REQUEST_SIZE} \
                --time=${BENCH_RUN_TIME} \
                --threads=${thd} --report-interval=10 --percentile=99 run \
            | tee $EXP_NAME.thr.$thd.sz.$FILE_TOTAL_SIZE.test.$mode.txt
        done
    done
}

# prepare initial data set size to be used for both the tests below
prepare_benchmark

echo "---- Benchmarking with total file size of ${FILE_TOTAL_SIZE}"
run_benchmark

# cleaning up initial data set
cleanup_benchmark
