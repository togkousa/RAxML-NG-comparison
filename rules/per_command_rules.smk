import numpy as np
import pandas as pd

from scripts.iqtree_utils import iqtree_statistical_tests
from scripts.iqtree_statstest_parser import get_iqtree_results


rule collect_trees_per_command:
    input:
        tree_results = expand_path(rules.collect_results_per_raxmlng_version.output.tree_results, expand_command=False)
    output:
        mlTrees = command_dir / "all.mlTrees",
        bestTree = command_dir / "all.bestTree"
    run:
        best_tree = None
        best_llh = -np.inf

        mlTrees = open(output.mlTrees, "a")

        for results in input.tree_results:
            results = pd.read_parquet(results)
            mlTrees.write("\n".join(results.newick.tolist()))

            best = results.sort_values(by="logLikelihood", ascending=False).head(1)
            if best.logLikelihood.item() > best_llh:
                best_llh = best.logLikelihood.item()
                best_tree = best.newick.item()

        mlTrees.close()

        open(output.bestTree, "w").write(best_tree.strip())


rule iqtree_significance_tests_per_command:
    input:
        bestTree = rules.collect_trees_per_command.output.bestTree,
        mlTrees = rules.collect_trees_per_command.output.mlTrees
    output:
        results = command_dir / "all.iqtree"
    log:
        snakelog = command_dir / "all.iqtree.snakelog"
    params:
        prefix = str(command_dir / "all")
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


rule collect_results_per_command:
    input:
        tree_results_per_version = expand_path(rules.collect_results_per_raxmlng_version.output.tree_results, expand_command=False),
        # IQTree results
        iqtree_results = rules.iqtree_significance_tests_per_command.output.results
    output:
        tree_results = command_dir / "all.results.trees.parquet"
    run:
        iqtree_results = get_iqtree_results(input.iqtree_results)
        all_tree_results = pd.concat([pd.read_parquet(f) for f in input.tree_results_per_version], ignore_index=True).reset_index(drop=True)

        collected_data = []

        for idx, row in all_tree_results.iterrows():
            print(idx)
