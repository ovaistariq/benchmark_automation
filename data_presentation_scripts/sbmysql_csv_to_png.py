import click
import csv
import matplotlib
import os

from matplotlib import style

# Use the Agg backend to render graphs
matplotlib.use('Agg')
style.use('ggplot')

# Importing the plotting library after setting the backend otherwise it tries to load with default backend and fails
import matplotlib.pyplot as plt


# The columns in the CSV file corresponding to the values
CSV_FIELDS = ['ts', 'threads', 'tps', 'qps', 'reads', 'writes', 'other', 'response_time', 'errors', 'reconnects']

# The columns that can be plotted on the graphs
GRAPH_FIELDS = ['tps', 'qps', 'reads', 'writes', 'response_time']

# The labels of the co
GRAPH_FIELD_LABELS = {
    'tps': {'xlabel': 'time (s)', 'ylabel': 'Transactions/second', 'title': 'MySQL TPS'},
    'qps': {'xlabel': 'time (s)', 'ylabel': 'Queries/second', 'title': 'MySQL QPS'},
    'reads': {'xlabel': 'time (s)', 'ylabel': 'Reads/second', 'title': 'MySQL RPS'},
    'writes': {'xlabel': 'time (s)', 'ylabel': 'Writes/second', 'title': 'MySQL WPS'},
    'response_time': {'xlabel': 'time (s)', 'ylabel': 'P99 Latency (ms)', 'title': 'MySQL P99 Latency (ms)'}
}


@click.group(invoke_without_command=True)
@click.pass_context
def cli(ctx):
    if ctx.invoked_subcommand is None:
        print(ctx.get_help())
        exit(-1)


@cli.command()
@click.pass_context
@click.option('--output', '-o', default='output', help='The directory where to output the graphs. Any existing file '
                                                       'would be overwritten')
@click.option('--plot-fields', '-c', default=['tps', 'qps', 'response_time'], multiple=True,
              help='The fields in the CSV file for which to plot the graphs. '
                   'Supported fields are: %s' % ', '.join(GRAPH_FIELDS))
@click.argument('csv_files', type=click.Path(exists=True, resolve_path=True), nargs=-1)
def plot_graph(ctx, output, plot_fields, csv_files):
    if len(csv_files) < 1:
        print(ctx.get_help())
        exit(-1)

    if len(plot_fields) < 1:
        print(ctx.get_help())
        exit(-1)

    # Setup the plotting data for each of the files provided as well as each of the supported graph fields
    plot_data = {}
    for col in GRAPH_FIELDS:
        if col not in plot_fields:
            continue

        plot_data[col] = {
            'series': {}
        }

    for file_path in csv_files:
        filename = os.path.basename(file_path)
        name_parts = filename.split('.')

        # The first part of the filename is the series name for the purpose of the graph
        series_name = name_parts[0]

        with open(file_path) as f:
            reader = csv.DictReader(f, CSV_FIELDS)
            for row in reader:
                for col, val in row.iteritems():
                    # We ignore the columns that are not to be plotted
                    if col not in plot_fields:
                        continue

                    # Initialize the series data if the series is seen for the first time for a particular column
                    if series_name not in plot_data[col]['series']:
                        plot_data[col]['series'][series_name] = {
                            'x': [],
                            'y': [],
                            'label': ''
                        }

                    plot_data[col]['series'][series_name]['x'].append(float(row['ts']))
                    plot_data[col]['series'][series_name]['y'].append(float(val))
                    plot_data[col]['series'][series_name]['label'] = series_name

    # Setup the output directory
    if not os.path.exists(output):
        os.makedirs(output)

    # Plot and save the graphs
    for col_name, col_data in plot_data.iteritems():
        # Initialize the plot
        fig, ax = plt.subplots()

        for _, series in col_data['series'].iteritems():
            ax.plot(series['x'], series['y'], linewidth=2, alpha=0.6, label=series['label'])

        ax.set(xlabel=GRAPH_FIELD_LABELS[col_name]['xlabel'], ylabel=GRAPH_FIELD_LABELS[col_name]['ylabel'],
               title=GRAPH_FIELD_LABELS[col_name]['title'])
        ax.grid()
        ax.legend(loc='best')

        plt.tight_layout()

        fig.savefig(os.path.join(output, '%s.png' % col_name))
        plt.close()


if __name__ == '__main__':
    cli()
