import re
import subprocess

from tempfile import TemporaryDirectory

from .custom_types import *
from .utils import *


def get_raxmlng_best_llh(raxmlng_file: FilePath) -> float:
    STR = "Final LogLikelihood:"
    return get_single_value_from_file(raxmlng_file, STR)


def get_raxmlng_likelihoods(raxmlng_file: FilePath) -> List[float]:
    # [00:00:27] [worker #4] ML tree search #13, logLikelihood: -6485.304526
    llh_regex = re.compile("\[\d+:\d+:\d+\]\s*(\[worker\s+#\d+\])?\s+ML\s+tree\s+search\s+#(\d+),\s+logLikelihood")
    likelihoods = []

    for line in read_file_contents(raxmlng_file):
        if "logLikelihood" in line:
            m = llh_regex.search(line)
            if m:
                tree_id = int(m.groups()[1])
                _, llh = line.rsplit(":", 1)
                llh = float(llh)
                likelihoods.append((tree_id, llh))

    likelihoods.sort()

    return [llh for _, llh in likelihoods]

def get_raxmlng_bootstrap_likelihoods(raxmlng_file: FilePath) -> List[float]:
    # [00:00:00] [worker #0] Bootstrap tree #1, logLikelihood: -2746.271209
    llh_regex = re.compile("\[\d+:\d+:\d+\]\s*(\[worker\s+#\d+\])?\s+Bootstrap\s+tree\s+#(\d+),\s+logLikelihood")
    likelihoods = []

    for line in read_file_contents(raxmlng_file):
        if "logLikelihood" in line:
            m = llh_regex.search(line)
            if m:
                tree_id = int(m.groups()[1])
                _, llh = line.rsplit(":", 1)
                llh = float(llh)
                likelihoods.append((tree_id, llh))

    likelihoods.sort()

    return [llh for _, llh in likelihoods]

def get_raxmlng_bootstrap_supports(support_file: FilePath) -> List[float]:
    supports = re.findall("\)(\d+):", open(support_file).readline().strip())

    return [float(x) for x in supports]

def get_raxmlng_time_from_line(line: str) -> float:
    # two cases now:
    # either the run was cancelled an rescheduled
    if "restarts" in line:
        # line looks like this: "Elapsed time: 5562.869 seconds (this run) / 91413.668 seconds (total with restarts)"
        _, right = line.split("/")
        value = right.split(" ")[1]
        return float(value)

    # ...or the run ran in one sitting...
    else:
        # line looks like this: "Elapsed time: 63514.086 seconds"
        value = line.split(" ")[2]
        return float(value)


def get_raxmlng_elapsed_time(log_file: FilePath) -> float:
    content = read_file_contents(log_file)

    for line in content:
        if "Elapsed time:" not in line:
            continue
        else:
            return get_raxmlng_time_from_line(line)

    raise ValueError(
        f"The given input file {log_file} does not contain the elapsed time."
    )


def raxmlng_rfdist(raxmlng: Executable, trees_file: FilePath) -> Tuple[float, float, float]:
    with TemporaryDirectory() as tmpdir:
        prefix = pathlib.Path(tmpdir) / "rfdist"

        cmd = [
            raxmlng,
            "--rfdist",
            trees_file,
            "--prefix",
            prefix,
        ]

        subprocess.check_output(cmd)

        log_file = pathlib.Path(f"{prefix}.raxml.log")

        abs_rfdist = None
        rel_rfdist = None
        num_topos = None

        for line in read_file_contents(log_file):
            if "Average absolute RF distance in this tree set:" in line:
                abs_rfdist = get_value_from_line(
                    line, "Average absolute RF distance in this tree set:"
                )
            elif "Average relative RF distance in this tree set:" in line:
                rel_rfdist = get_value_from_line(
                    line, "Average relative RF distance in this tree set:"
                )
            elif "Number of unique topologies in this tree set:" in line:
                num_topos = get_value_from_line(
                    line, "Number of unique topologies in this tree set:"
                )

        if abs_rfdist is None or rel_rfdist is None or num_topos is None:
            raise ValueError(f"Error parsing raxml-ng logfile {log_file.name}.")

        return num_topos, rel_rfdist, abs_rfdist
