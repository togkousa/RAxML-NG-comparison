import pandas as pd
import shutil

from scripts.raxmlng_utils import *
from scripts.iqtree_utils import iqtree_statistical_tests
from scripts.iqtree_statstest_parser import get_iqtree_results


rule run_raxmlng_command:
    output:
        raxmlng_log = raxmlng_cmd_prefix.with_suffix(".raxml.log"),
        bestTree = raxmlng_cmd_prefix.with_suffix(".raxml.bestTree"),
        mlTrees = raxmlng_cmd_prefix.with_suffix(".raxml.mlTrees"),
        bestModel = raxmlng_cmd_prefix.with_suffix(".raxml.bestModel"),
    log:
        snakelog = raxmlng_cmd_prefix.with_suffix(".raxmlng.snakelog"),
    params:
        prefix = str(raxmlng_cmd_prefix)
    run:
        raxmlng = raxmlng_versions[wildcards.raxmlng]
        msa = msas[wildcards.msa]
        model = models[msa]
        cmd_base = command_repr_mapping[wildcards.cmd_repr]
        prefix = params.prefix

        cmd = f"{raxmlng} --msa {msa} --model {model} {cmd_base} --prefix {prefix} > {log.snakelog} 2>&1"

        # for Snakemake we need to escape curly braces with another curly brace
        # otherwise it will treat it as a wildcard and crash...
        cmd = cmd.replace("{", "{{").replace("}", "}}")

        shell(cmd)

        # some RAxML-NG commands, e.g. --search1 do not produce a .mlTrees file
        # -> manually create it by copying the bestTree
        if not pathlib.Path(output.mlTrees).exists():
            shutil.copy(output.bestTree, output.mlTrees)


rule iqtree_significance_tests_per_raxmlng_version:
    input:
        bestTree = rules.run_raxmlng_command.output.bestTree,
        mlTrees = rules.run_raxmlng_command.output.mlTrees
    output:
        results = iqtree_cmd_prefix.with_suffix(".iqtree")
    log:
        snakelog = iqtree_cmd_prefix.with_suffix(".iqtree.snakelog")
    params:
        prefix = str(iqtree_cmd_prefix)
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
        general_results = raxmlng_cmd_prefix.with_suffix(".results.parquet"),
        tree_results = raxmlng_cmd_prefix.with_suffix(".results.trees.parquet")
    run:
        # RF-Distance between trees
        n_ml_trees = len(read_file_contents(input.mlTrees))
        if n_ml_trees > 1:
            num_topos, rel_rfdist, abs_rfdist = raxmlng_rfdist(
                raxmlng=raxmlng_versions[wildcards.raxmlng],
                trees_file=input.mlTrees
            )
        else:
            num_topos, rel_rfdist, abs_rfdist = (1, 0.0, 0.0)

        results = {
            "bestLogLikelihood": get_raxmlng_best_llh(input.raxmlng_log),
            "runtime": get_raxmlng_elapsed_time(input.raxmlng_log),
            "numberOfInferredTrees": n_ml_trees,
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

        for i, (tree, iqt_results) in enumerate(zip(mlTrees, iqtree_resuts)):
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
