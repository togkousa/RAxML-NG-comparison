import numpy as np
import pandas as pd

from scripts.iqtree_utils import iqtree_statistical_tests
from scripts.iqtree_statstest_parser import get_iqtree_results


rule collect_trees_per_command:
    input:
        tree_results = expand_path(rules.collect_results_per_raxmlng_version.output.tree_results, expand_command=False, expand_dataset=False),
        best_tree = expand_path(rules.run_raxmlng_command.output.bestTree, expand_command=False, expand_dataset=False)
    output:
        mlTrees = command_dir / "all.mlTrees",
        bestTree = command_dir / "all.bestTree",
        versionBestTrees = command_dir / "version.bestTrees"
    run:
        best_tree = None
        best_llh = -np.inf

        versionTrees = open(output.versionBestTrees, "a")
        for f in input.best_tree:
          tree = open(f).readline().strip()
          versionTrees.write(tree)
        versionTrees.close()

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
        iqtree, *extra = config["iqtree"]

        iqtree_statistical_tests(
            iqtree=iqtree,
            msa=msa,
            model=models[msa],
            output_prefix=params.prefix,
            mlTrees=input.mlTrees,
            bestTree=input.bestTree,
            snakelog=log.snakelog,
            cmd_extra=extra[0] if len(extra) > 0 else ""
        )

rule iqtree_significance_tests_per_command_best:
    input:
        commandBestTree = rules.collect_trees_per_command.output.bestTree,
        versionBestTrees = rules.collect_trees_per_command.output.versionBestTrees
    output:
        results = command_dir / "best.iqtree"
    log:
        snakelog = command_dir / "best.iqtree.snakelog"
    params:
        prefix = str(command_dir / "best")
    run:
        msa = msas[wildcards.msa]
        iqtree, *extra = config["iqtree"]

        m = models[msa]
        if m == "GTR+G":
          m += "+FO"

        iqtree_statistical_tests(
            iqtree=iqtree,
            msa=msa,
            model=m,
            output_prefix=params.prefix,
            mlTrees=input.versionBestTrees,
            bestTree=input.commandBestTree,
            snakelog=log.snakelog,
            cmd_extra=extra[0] if len(extra) > 0 else ""
        )


rule collect_results_per_command:
    input:
        general_results_per_version = expand_path(rules.collect_results_per_raxmlng_version.output.general_results, expand_command=False, expand_dataset=False),
#        tree_results_per_version = expand_path(rules.collect_results_per_raxmlng_version.output.tree_results, expand_command=False, expand_dataset=False),
        # IQTree results
        iqtree_results = rules.iqtree_significance_tests_per_command_best.output.results
    output:
        general_results = command_dir / "all.results.parquet"
#        tree_results = command_dir / "all.results.trees.parquet"
    run:
        iqtree_results = get_iqtree_results(input.iqtree_results)
        all_results = pd.concat([pd.read_parquet(f) for f in input.general_results_per_version], ignore_index=True).reset_index(drop=True)
#        all_tree_results = pd.concat([pd.read_parquet(f) for f in input.tree_results_per_version], ignore_index=True).reset_index(drop=True)

#        print(iqtree_results)

        baseline_ver = "raxmlng-version-1.1.0"
        baseline_idx = 0
        baseline_runtime = all_results.at[baseline_idx, "runtime"]
        baseline_loglh = all_results.at[baseline_idx, "bestLogLikelihood"]

        all_results = all_results.assign(speedup = baseline_runtime / all_results["runtime"], 
                                         absoluteLogLikelihoodDiff = all_results["bestLogLikelihood"] - baseline_loglh)

        all_results = all_results.assign(relativeLogLikelihoodDiff = -1 * all_results["absoluteLogLikelihoodDiff"] / baseline_loglh)

        all_results = all_results.assign(isPlausible = [1 if entry["plausible"] else 0 for entry in iqtree_results])

        print(all_results)

        all_results.to_parquet(output.general_results)

