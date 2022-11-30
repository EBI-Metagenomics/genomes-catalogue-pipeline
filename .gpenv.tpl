export PIPELINE_DIRECTORY=""
export DEFAULT_QUEUE="standard"
export BIGQUEUE="bigmem"

export GUNC_DB="<replace-path>/gunc_db_2.0.4.dmnd"
export GTDBTK_REF="<replace-path>/reference202"
export GEO="<replace-path/"

# Scripts #
export PATH="${PIPELINE_DIRECTORY}/src/scripts:$PATH"

export TMPDIR="<replace-with-tmp>"

# TOIL SPECIFICS #
TOIL_JOBSTORE="<path>"
TOIL_OUTDIR="<path>"

OUTDIRNAME="test"
MEMORY=100G
QUEUE="production"

# ANY OTHER ENV setup required
mitload miniconda

module load singularity-3.7.0-gcc-9.3.0-dp5ffrp

conda activate toil-5.7.1