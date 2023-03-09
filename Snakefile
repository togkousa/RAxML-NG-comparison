import pathlib

import pandas as pd

from scripts.raxmlng_utils import *
from scripts.iqtree_utils import *
from scripts.iqtree_statstest_parser import get_iqtree_results

configfile: "config.yaml"

raxmlng_versions = dict(config["executables"])

datasets = config["datasets"]
msas = dict([(pathlib.Path(msa).name, msa) for msa in datasets])
models = dict([(k, v["model"]) for k, v in datasets.items()])

command_repr_mapping = dict([(cmd.replace(" ", "").replace("-", ""), cmd) for cmd in config["commandLines"]])

raxmlng_cmd_prefixes = pathlib.Path(config["outdir"]) / "{cmd_repr}" / "{raxmlng}" / "{msa}_{model}"


def expand_for_suffix(suffix: str, expand_raxmlng: bool = True):
    files = expand(
        expand(
            str(raxmlng_cmd_prefixes) + suffix,
            zip,
            msa=msas.keys(),
            model=models.values(),
            allow_missing=True
        ),
        cmd_repr=command_repr_mapping, allow_missing=True
    )
    if expand_raxmlng:
        files = expand(files, raxmlng=raxmlng_versions)

    return files


rule all:
    input:
        #---------------------
        # Independent RAxML-NG runs and subsequent analyses
        #---------------------
        # RAxML-NG result files
        logfiles = expand_for_suffix(".raxml.log", expand_raxmlng=True),
        bestTrees = expand_for_suffix(".raxml.bestTree", expand_raxmlng=True),
        mlTrees = expand_for_suffix(".raxml.mlTrees", expand_raxmlng=True),

        # IQ-Tree significance analyses
        indiv_iqtree_results = expand_for_suffix(".iqtree.iqtree", expand_raxmlng=True),

        # collected results
        general_results = expand_for_suffix(".results.parquet", expand_raxmlng=True),
        tree_results = expand_for_suffix(".results.trees.parquet", expand_raxmlng=True)

        #---------------------
        # Comparison of different RAxML-NG versions
        #---------------------
        # IQ-Tree significance analyses

        # collected results


rule run_raxmlng_command:
    output:
        raxmlng_log = str(raxmlng_cmd_prefixes) + ".raxml.log",
        bestTree = str(raxmlng_cmd_prefixes) + ".raxml.bestTree",
        mlTrees = str(raxmlng_cmd_prefixes) + ".raxml.mlTrees",
        bestModel = str(raxmlng_cmd_prefixes) + ".raxml.bestModel",
    log:
        snakelog = str(raxmlng_cmd_prefixes) + ".raxmlng.snakelog"
    params:
        prefix = str(raxmlng_cmd_prefixes)
    run:
        raxmlng = raxmlng_versions[wildcards.raxmlng]
        msa = msas[wildcards.msa]
        model = models[msa]
        cmd_base = command_repr_mapping[wildcards.cmd_repr]
        prefix = params.prefix

        cmd = f"{raxmlng} --msa {msa} --model {model} {cmd_base} --prefix {prefix} > {log.snakelog} 2>&1"

        shell(cmd)


rule iqtree_significance_tests_per_raxmlng_version:
    input:
        bestTree = rules.run_raxmlng_command.output.bestTree,
        mlTrees = rules.run_raxmlng_command.output.mlTrees
    output:
        results = str(raxmlng_cmd_prefixes) + ".iqtree",
    log:
        snakelog = str(raxmlng_cmd_prefixes) + ".iqtree.snakelog"
    params:
        prefix = str(raxmlng_cmd_prefixes) + ".iqtree"
    run:
        msa = msas[wildcards.msa]

        iqtree_statistical_tests(
            iqtree=config["iqtree"],
            msa=msa,
            model=models[msa],
            output_prefix=params.prefix,
            mlTrees=input.mlTrees,
            bestTree=input.bestTree,
            snakelog=log.snakelog
        )


rule collect_results_per_raxmlng_version:
    input:
        # RAxML-NG results
        raxmlng_log = rules.run_raxmlng_command.output.raxmlng_log,
        bestTree = rules.run_raxmlng_command.output.bestTree,
        mlTrees = rules.run_raxmlng_command.output.mlTrees,
        bestModel = rules.run_raxmlng_command.output.bestModel,

        # IQTree results
        iqtree_results = rules.iqtree_significance_tests_per_raxmlng_version.output.results
    output:
        general_results = str(raxmlng_cmd_prefixes) + ".results.parquet",
        tree_results = str(raxmlng_cmd_prefixes) + ".results.trees.parquet"
    run:
        # parse Likelihood etc. from Log
        slow, fast = get_raxmlng_num_spr_rounds(input.raxmlng_log)

        # RF-Distance between trees
        n_ml_trees = len(read_file_contents(input.mlTrees))
        if n_ml_trees > 1:
            num_topos, rel_rfdist, abs_rfdist = raxmlng_rfdist(
                raxmlng=raxmlng,
                trees_file=input.mlTrees
            )
        else:
            num_topos, rel_rfdist, abs_rfdist = (1, 0.0, 0.0)

        results = {
            "bestLogLikelihood": get_raxmlng_best_llh(input.raxmlng_log),
            "runtime": get_raxmlng_elapsed_time(input.raxmlng_log),
            "numberOfInferredTrees": n_ml_trees,
            "nSlowSPRRounds": slow,
            "nFastPRRounds": fast,
            "uniqueTopologiesMLTrees": num_topos,
            "relativeRFDistanceMLTrees": rel_rfdist,
            "absoluteRFDistanceMLTrees": abs_rfdist,
        }
        # TODO: what other information do we want to retrieve from the log?

        general_results = pd.DataFrame(data=results, index=[0])
        general_results.to_parquet(output.general_results)

        # store ML Trees and bestTree Flag + iqtree significance results
        bestTree = open(input.bestTree).readline().strip()
        mlTrees = read_file_contents(input.mlTrees)
        iqtree_resuts = get_iqtree_results(input.iqtree_results)

        tree_results = []
        likelihoods = get_raxmlng_likelihoods(input.raxmlng_log)

        for i, tree, iqt_results in enumerate(zip(mlTrees, iqtree_resuts)):
            is_best = tree == bestTree

            # Plausible trees
            tests = iqt_results["tests"]

            tree_results.append(
                {
                    "newick": tree,
                    "logLikelihood": likelihoods[i],
                    "isBest": is_best,
                    "plausible": iqt_results["plausible"],
                    "bpRell": tests["bp-RELL"]["score"],
                    "bpRell_significant": bool(tests["bp-RELL"]["significant"]),
                    "pKH": tests["p-KH"]["score"],
                    "pKH_significant": bool(tests["p-KH"]["significant"]),
                    "pSH": tests["p-SH"]["score"],
                    "pSH_significant": bool(tests["p-SH"]["significant"]),
                    "pWKH": tests["p-WKH"]["score"],
                    "pWKH_significant": bool(tests["p-WKH"]["significant"]),
                    "pWSH": tests["p-WSH"]["score"],
                    "pWSH_significant": bool(tests["p-WSH"]["significant"]),
                    "cELW": tests["c-ELW"]["score"],
                    "cELW_significant": bool(tests["c-ELW"]["significant"]),
                    "pAU": tests["p-AU"]["score"],
                    "pAU_significant": bool(tests["p-AU"]["significant"]),
                }
            )

        tree_results = pd.DataFrame(data=tree_results)
        tree_results.to_parquet(output.tree_results)


rule collect_trees_of_all_raxmlng_versions_per_command:
    input:
        mlTrees = expand_for_suffix(".raxml.mlTrees", expand_raxmlng=False)









