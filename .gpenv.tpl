export PIPELINE_DIRECTORY=""
export DEFAULT_QUEUE="standard"
export BIGQUEUE="bigmem"

export GUNC_DB="<replace-path>/gunc_db_2.0.4.dmnd"
export GTDBTK_REF="<replace-path>/reference207"
export GEO="<replace-path>/continent_countries.csv"

# Software & Scripts #
export SINGULARITY_CACHEDIR="<replace-path>"
export PATH="${PIPELINE_DIRECTORY}/containers/python3_scripts:$PATH"
export PATH="${PIPELINE_DIRECTORY}/containers/genomes-catalog-update/scripts/:$PATH"
export PATH="${PIPELINE_DIRECTORY}/containers/bash/:$PATH"

export MASH_2_3=""
export IQTREE_2_1_3=""
export ENTEREZ_DIRECT=""
export NCBI_2_12_0=""
export KRAKEN_2_1_2_FOLDER=""
export BRAKEN_2_6_2_FOLDER=""
export SEQTK_1_3=""

export TMPDIR="<replace-with-tmp>"

# TOIL SPECIFICS #
TOIL_JOBSTORE="<path>"
TOIL_OUTDIR="<path>"
OUTDIRNAME="test"
MEMORY=100G
QUEUE="production"