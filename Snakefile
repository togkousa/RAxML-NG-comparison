from rules.scripts.custom_types import *

configfile: "config.yaml"

raxmlng_versions = dict(config["executables"])

datasets = config["datasets"]
msas = dict([(pathlib.Path(msa).name, msa) for msa in datasets])
models = dict([(k, v["model"]) for k, v in datasets.items()])

command_repr_mapping = dict([(cmd.replace(" ", "").replace("-", ""), cmd) for cmd in config["commandLines"]])

dataset_dir = pathlib.Path(config["outdir"]) / "{msa}_{model}"
command_dir = dataset_dir /  "{cmd_repr}"
raxmlng_cmd_prefix = command_dir / "{raxmlng}" / "{raxmlng}"
iqtree_cmd_prefix = command_dir / "{raxmlng}" / "{raxmlng}_iqtree"


def expand_path(dir: FilePath, expand_command: bool = True):
    files = expand(
        expand(
            dir,
            zip,
            msa=msas.keys(),
            model=models.values(),
            allow_missing=True
        ),
        raxmlng=raxmlng_versions,
         allow_missing=True
    )
    if expand_command:
        files = expand(files, cmd_repr=command_repr_mapping,)

    return files


def expand_for_suffix(suffix: str, expand_command: bool = True):
    return expand_path(raxmlng_cmd_prefix.with_suffix(suffix), expand_command=expand_command)


rule all:
    input:
        #---------------------
        # Independent RAxML-NG runs and subsequent analyses
        #---------------------
        # RAxML-NG result files
        logfiles = expand_for_suffix(".raxml.log", expand_command=True),
        bestTrees = expand_for_suffix(".raxml.bestTree", expand_command=True),
        mlTrees = expand_for_suffix(".raxml.mlTrees", expand_command=True),

        # IQ-Tree significance analyses
        indiv_iqtree_results = expand_path(iqtree_cmd_prefix.with_suffix(".iqtree"), expand_command=True),

        # collected results
        general_results = expand_for_suffix(".results.parquet", expand_command=True),
        tree_results = expand_for_suffix(".results.trees.parquet", expand_command=True),

        #---------------------
        # Comparison of different RAxML-NG versions
        #---------------------
        # IQ-Tree significance analyses
        collected_trees = expand_path(command_dir / "all.mlTrees", expand_command=True),
        collected_best_tree = expand_path(command_dir / "all.bestTree", expand_command=True),
        collected_iqtree_results = expand_path(command_dir / "all.iqtree", expand_command=True),

        # collected results
        # collected_tree_results = expand_path(command_dir / "all.results.trees.parquet", expand_command=True),


include: "rules/per_version_rules.smk"
include: "rules/per_command_rules.smk"







