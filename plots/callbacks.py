import pandas as pd
from dash.dependencies import Output, Input
from plotly import graph_objects as go

from app import app
from definitions import *


def get_plot_options(plot_type, df, metric):
    plot_data = df[metric]

    if plot_type == go.Box:
        plot_options = {
            "y": plot_data,
            "boxpoints": "all",
            "showlegend": False,
        }
        xtitle = "RAxML-NG version"
        ytitle = metric
    elif plot_type == go.Bar:
        plot_options = {
            "x": plot_data.value_counts().index,
            "y": plot_data.value_counts().values,
            "showlegend": True
        }
        xtitle = metric
        ytitle = "Number of trees"
    elif plot_type == go.Scatter:
        plot_options = {
            "y": plot_data,
            "marker": dict(size=10),
            "showlegend": True,
        }
        xtitle = "meaningless x-Axis"
        ytitle = metric
    else:
        plot_options = {}
        xtitle = ""
        ytitle = ""

    return plot_options, xtitle, ytitle


@app.callback(
    Output("metricEntireRunComparison", "figure"),
    Input("datasetSelector", "value"),
    Input("commandSelector", "value"),
    Input("resultMetricSelector", "value")
)
def plot_per_command_comparison(dataset, command, metric):
    results_dir = RESULTS_BASE / dataset / command
    raxmlng_versions = [d for d in results_dir.iterdir() if d.is_dir()]

    fig = go.Figure()

    for version in raxmlng_versions:
        df = pd.read_parquet(version / (version.name + ".results.parquet"))
        plot_type = VERSION_COMPARISON_PLOT_METRICS_ENTIRE_RUN[metric]

        plot_options, xtitle, ytitle = get_plot_options(plot_type, df, metric)

        fig.add_trace(
            plot_type(
                name=version.name,
                **plot_options
            )
        )

        fig.update_xaxes(title=xtitle)
        fig.update_yaxes(title=ytitle)

    fig.update_layout(template=TEMPLATE)
    return fig


@app.callback(
    Output("metricAllTreesComparison", "figure"),
    Input("datasetSelector", "value"),
    Input("commandSelector", "value"),
    Input("resultMetricAllTreesSelector", "value")
)
def plot_per_command_comparison(dataset, command, metric):
    results_dir = RESULTS_BASE / dataset / command
    raxmlng_versions = [d for d in results_dir.iterdir() if d.is_dir()]

    fig = go.Figure()

    for version in raxmlng_versions:
        df = pd.read_parquet(version / (version.name + ".results.trees.parquet"))
        plot_type = VERSION_COMPARISON_PLOT_METRICS_ALL_TREES[metric]

        plot_options, xtitle, ytitle = get_plot_options(plot_type, df, metric)

        fig.add_trace(
            plot_type(
                name=version.name,
                **plot_options
            )
        )

        fig.update_xaxes(title=xtitle)
        fig.update_yaxes(title=ytitle)

    fig.update_layout(template=TEMPLATE)
    return fig