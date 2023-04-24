from snakemake.shell import shell

from .custom_types import *


def iqtree_statistical_tests(
    iqtree: Executable,
    msa: FilePath,
    model: str,
    output_prefix: FilePath,
    mlTrees: FilePath,
    bestTree: FilePath,
    snakelog: FilePath,
    cmd_extra: str,
):
    partitioned = pathlib.Path(model).is_file()
    model_prefix = "-p" if partitioned else "-m"

    shell(
        iqtree + f" {cmd_extra} -s {msa} "
        f"{model_prefix} {model} "
        f"-pre {output_prefix} "
        f"-z {mlTrees} "
        f"-te {bestTree} "
        "-n 0 "
        "-zb 10000 "
        "-zw "
        "-au "
        "-treediff "
        "-seed 0 "
        "-redo "
        f"> {snakelog} 2>&1"
    )
