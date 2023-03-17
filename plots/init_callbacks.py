import json
from dash.dependencies import Output, Input

from app import app
from definitions import *


@app.callback(
    Output("datasetSelector", "options"),
    Output("datasetSelector", "value"),
    Input("_dummy", "children"),
)
def populate_dataset_selector(_):
    options = [{"label": dataset.name, "value": dataset.name} for dataset in DATASETS]
    return options, options[0]["value"]


@app.callback(
    Output("commandSelector", "options"),
    Output("commandSelector", "value"),
    Input("datasetSelector", "value"),
)
def populate_command_selector(dataset):
    with open(RESULTS_BASE / "cmd_mapping.json") as f:
        CMD_MAPPING = json.load(f)
    dataset_dir = RESULTS_BASE / dataset

    options = [{"label": CMD_MAPPING[cmd.name], "value": cmd.name} for cmd in dataset_dir.iterdir()]
    return options, options[0]["value"]


@app.callback(
    Output("resultMetricSelector", "options"),
    Output("resultMetricSelector", "value"),
    Input("_dummy", "children"),
)
def populate_entire_run_comparison_metric_selector(_):
    options = [{"label": col, "value": col} for col in VERSION_COMPARISON_PLOT_METRICS_ENTIRE_RUN]
    return options, options[0]["value"]


@app.callback(
    Output("resultMetricAllTreesSelector", "options"),
    Output("resultMetricAllTreesSelector", "value"),
    Input("_dummy", "children"),
)
def populate_all_tree_comparison_metric_selector(_):
    options = [{"label": col, "value": col} for col in VERSION_COMPARISON_PLOT_METRICS_ALL_TREES]
    return options, options[0]["value"]