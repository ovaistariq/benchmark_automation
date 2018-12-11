# Benchmark Automation
Scripts to help automate the running of repeatable benchmarks. Currently only
sysbench is supported.

## Dependencies
* sysbench 1.0.13 or higher - [installation
   instructions](https://github.com/akopytov/sysbench#installing-from-binary-packages).


## Usage
### Running sysbench IO benchmark
No direct input args, behavior is controlled by the following environment
variables:
* TEST_MODE : The type of test to perform. Multiple types of tests can be
  passed as whitespace separated list. Optional, defaults to 'rndrd rndwr'
* FILE_TOTAL_SIZE : The total size of files created and used during the
  benchmark. Optionak, defaults to '600G'
* IO_REQUEST_SIZE : The size of individual IO requests. Optional, defaults to
  '16K'
* FSYNC_FREQ : The number of IO requests after which to make a fsync() call.
  Optional, defaults to '0'
* IO_MODE : The type of IO requests. Optional, defaults to 'async'
* FILE_FLAG : The flags to pass to the open() call on the benchmark files.
  Optional, defaults to 'direct' which translates to 'O_DIRECT' flag
  internally.
* BENCH_RUN_TIME : The time in seconds for how long to run the benchmark.
  Optional, defaults to '300'
* THREADS : The number of threads to use for performing the benchmark. Multiple
  thread values can be specified by passing a whitespace separated list.
  Optional, defaults to '16'
* EXP_NAME : The name of the experiment. This is used in graph legend to
  identify the series when the data collected during the benchmark is plotted.

The IO benchmark script can be run as below:
```bash
TEST_MODE=rndwr FILE_TOTAL_SIZE=3400G IO_REQUEST_SIZE=4K FSYNC_FREQ=0 IO_MODE=async FILE_FLAG=direct BENCH_RUN_TIME=1200 THREADS="1 16 64 256" EXP_NAME=async_directio_fsync_0 ./run_sbio.sh
```

#### Generating graphs
Data from the benchmark run is stored in raw format in the directory from where
the benchmark is executed.

Before generating the graph, the data must be converted to CSV format. This can
be achieved by using a utility script that is provided. Example invocation of
the script is shown below:
```bash
_NOHEADER=1 ./csv_from_sysbench_io.sh ./raw_data/sync_directio_fsync_1.thr.64.sz.3400G.test.rndwr.txt > ./csv_data/sync_directio_fsync_1.thr.64.sz.3400G.test.rndwr.csv
```

Graphs can then be generated by running the graph generation script ./sbio_csv_to_png.py
```bash
python data_presentation_scripts/sbio_csv_to_png.py plot_graph --help
Usage: sbio_csv_to_png.py plot_graph [OPTIONS] [CSV_FILES]...

Options:
  -o, --output TEXT       The directory where to output the graphs. Any
                          existing file would be overwritten
  -c, --plot-fields TEXT  The fields in the CSV file for which to plot the
                          graphs. Supported fields are: reads, writes, fsyncs,
                          response_time
  --help                  Show this message and exit.
```

An example invocation of the script is shown below:
```bash
python ./sbio_csv_to_png.py plot_graph -o ./output/experiment_name -c reads -c writes -c response_time ./csv_data/experiment_1_name.thr.64.sz.3400G.test.rndwr.csv ./csv_data/experiment_2_name.thr.64.sz.3400G.test.rndwr.csv
```

### Running sysbench MySQL benchmark
No direct input args, behavior is controlled by the following environment
variables:
* _EXP_NAME : Experiment name. Optional, defaults to 'sysbench'
* _TESTS_DIR : Directory which contains the test files
* _TESTS : Quoted list of the tests to run, i.e. "oltp_read_only oltp_read_write"
* _THREADS : Quoted list of the # of threads to use for each run, i.e. "16 32"
* _TABLES : Number of tables to use for the tests
* _SIZE : Quoted list of the table sizes to use, in rows, i.e. "100000 1000000 10000000"
* _MYSQL_USER : MySQL username to use for the benchmark run
* _MYSQL_HOST : MySQL host to connect to for the benchmark run
* _MYSQL_PASSWORD : MySQL password to use for the benchmark run
* _DURATION : Number of seconds for each benchmark run
* _LOG_QUERIES : Control slow query logging to capture queries executed during the benchmark in slow query log
* _COLLECT_MYSQL_STATS : Control collection of MySQL statistics during the benchmark run
* _COLLECT_VMSTAT : Control collection vmstat statistics during the benchmark run

Any actual input argument will be passed as is to sysbench, so you can run it
as below:
```bash
_TESTS_DIR=sysbench_tests _TESTS="oltp_read_only oltp_read_write" _THREADS="16 32" _TABLES=16 _SIZE="1000 10000" _DURATION=7200 _MYSQL_HOST=sbhost _MYSQL_USER=sysbench _MYSQL_PASSWORD=sysbench  ./run_sbmysql.sh --rand-type=pareto --mysql-db=sbtest

_EXP_NAME=sample _LOG_QUERIES=1 _COLLECT_MYSQL_STATS=1 _COLLECT_VMSTAT=1 _TESTS_DIR=sysbench_tests _TESTS=oltp_read_write _THREADS="1 2 4" _TABLES=64 _SIZE="10 100" _DURATION=60 _MYSQL_HOST=sbhost _MYSQL_USER=sysbench _MYSQL_PASSWORD=sysbench ./run_sbmysql.sh --mysql_table_engine=innodb --rand-type=pareto --mysql-db=sbtest
```

#### Generating graphs
Data from the benchmark run is stored in CSV format under directories named by
after the test names specified by `_TESTS` above.

Graphs can be generated by running the graph generation script ./sbmysql_csv_to_png.py

```bash
python ./sbmysql_csv_to_png.py plot_graph
Usage: sbmysql_csv_to_png.py plot_graph [OPTIONS] [CSV_FILES]...

Options:
  -o, --output TEXT       The directory where to output the graphs. Any
                          existing file would be overwritten
  -c, --plot-fields TEXT  The fields in the CSV file for which to plot the
                          graphs. Supported fields are: tps, qps, reads,
                          writes, response_time
  --help                  Show this message and exit.
```

An example invocation of the script is shown below
```bash
python ./sbmysql_csv_to_png.py plot_graph -o output/thr-16 -c tps -c qps -c response_time 4_4_82-sjc1.thr.16.sz.5000000.test.oltp_read_write.txt 4_4_112-sjc1.thr.16.sz.5000000.test.oltp_read_write.txt 4_4_115-sjc1.thr.16.sz.5000000.test.oltp_read_write.txt
```

The `_EXP_NAME` environment variable needs to be setup correctly to generate
mult-series graph. In the example above, `_EXP_NAME` was set to the hostname
when running the `run_sbmysql.sh` script.
