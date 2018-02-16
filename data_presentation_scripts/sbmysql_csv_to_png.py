import click
import csv
import matplotlib
import os

from matplotlib import style

# Use the Agg backend to render graphs
matplotlib.use('Agg')
style.use('ggplot')

import matplotlib.pyplot as plt


# The columns in the CSV file corresponding to the values
COLS = ['ts', 'threads', 'tps', 'qps', 'reads', 'writes', 'other', 'response_time', 'errors', 'reconnects']


@click.group(invoke_without_command=True)
@click.pass_context
def cli(ctx):
    if ctx.invoked_subcommand is None:
        print(ctx.get_help())
        exit(-1)


@cli.command()
@click.argument('csv_files', type=click.Path(exists=True, resolve_path=True), nargs=-1)
def plot_graph(csv_files):
    if len(csv_files) < 1:
        exit(-1)

    # Initialize the plot
    fig, ax = plt.subplots()

    for file_path in csv_files:
        filename = os.path.basename(file_path)
        name_parts = filename.split('.')

        ts = [0]
        tps = [0]
        response_time = [0]
        with open(file_path) as f:
            reader = csv.DictReader(f, COLS)
            for row in reader:
                ts.append(row['ts'])
                tps.append(row['tps'])
                response_time.append(row['response_time'])

        ax.plot(ts, tps, linewidth=2, alpha=0.6, label=name_parts[0])

    ax.set(xlabel='time (s)', ylabel='Transactions/second', title='MySQL TPS')
    ax.grid()
    ax.legend(loc='upper right')

    plt.tight_layout()

    fig.savefig("test.png")
    plt.close()


if __name__ == '__main__':
    cli()
