import pathlib
import yaml

from plotly import graph_objects as go


config = yaml.load(open("config.yaml"), yaml.Loader)

RESULTS_BASE = pathlib.Path(config["outdir"])
DATASETS = sorted([d for d in RESULTS_BASE.iterdir() if d.is_dir()])
CMD_MAPPINGS = None

# plot definitions
TEMPLATE = "plotly_white"

VERSION_COMPARISON_PLOT_METRICS_SUMMARY = {
    "speedup": go.Box,
    "absoluteLogLikelihoodDiff": go.Box,
    "relativeLogLikelihoodDiff": go.Box,
    "relativeRFDistanceMLTrees": go.Scatter,
    "numberOfInferredTrees": go.Scatter,
    "uniqueTopologiesMLTrees": go.Scatter,
    "isPlausible" : go.Box,
}

VERSION_COMPARISON_PLOT_METRICS_ENTIRE_RUN = {
    "bestLogLikelihood": go.Scatter,
    "runtime": go.Scatter,
    "speedup": go.Scatter,
    "numberOfInferredTrees": go.Scatter,
    "uniqueTopologiesMLTrees": go.Scatter,
    "relativeRFDistanceMLTrees": go.Scatter,
    "absoluteRFDistanceMLTrees": go.Scatter,
    "absoluteLogLikelihoodDiff": go.Scatter,
    "relativeLogLikelihoodDiff": go.Scatter,
}

VERSION_COMPARISON_PLOT_METRICS_ALL_TREES = {
    "logLikelihood": go.Box,
    "plausible": go.Bar,
    "bpRell": go.Box,
    "bpRell_significant": go.Bar,
    "pKH": go.Box,
    "pKH_significant": go.Bar,
    "pSH": go.Box,
    "pSH_significant": go.Bar,
    "pWKH": go.Box,
    "pWKH_significant": go.Bar,
    "pWSH": go.Box,
    "pWSH_significant": go.Bar,
    "cELW": go.Box,
    "cELW_significant": go.Bar,
    "pAU": go.Box,
    "pAU_significant": go.Bar,
}
