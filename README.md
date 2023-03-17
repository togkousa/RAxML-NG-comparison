# RAxML-NG version comparison pipeline

## Setup
1. Download the code:
    ```commandline
    git clone https://github.com/tschuelia/RAxML-NG-comparison.git
    ```
2. Create a new conda environment using the provided `environment.yml` file:
    ```commandline
   conda env create -f environment.yml
   ```
3. Activate the conda environment:
    ```commandline
    conda activate comparison
    ```
4. Get all RAxML-NG versions you want to test ready to use.

## Running the Pipeline
1. Adjust the `config.yaml` file to your needs. The comments in the `config.yaml` will guide you.
2. Do a snakemake dry run to make sure everything works as expected: 
   ```commandline
   snakemake -n -p
   ```
   This will print all jobs that Snakemake will do.
3. Run the pipeline
   ```commandline
   snakemake --cores [number of cores*] -k -p
   ```
   \* you can either manually set a number of cores, or you can set `--cores all` and Snakemake will use all cores your system has.
   
   Running the pipeline on a cluster is a bit more difficult, especially when we want to run it on multiple nodes. 
   You can find detailed instructions on how to setup snakemake on a slurm cluster [here](https://github.com/tschuelia/snakemake-on-slurm-clusters).
4. Once the pipeline ran successfully, you can have a look at the results using an interactive Dash plotting website. 
You have to start the dash server manually:
   ```commandline
   python plots/index.py
   ```
5. If you ran the pipeline on you laptop, you can directly open `http://127.0.0.1:8050/` in your browser. 
In case you ran it on a remote server you first have to do port forwarding to view the website:
   ```commandline
   ssh -L 8050:localhost:8050 [address of the server]
   ```
   