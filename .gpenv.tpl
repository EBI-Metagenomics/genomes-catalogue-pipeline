export PIPELINE_DIRECTORY=""
export DEFAULT_QUEUE="standard"
export BIGQUEUE="bigmem"

export GUNC_DB="<replace-path>/gunc_db_2.0.4.dmnd"
export GTDBTK_REF="<replace-path>/reference207"
export GEO="<replace-path>/continent_countries.csv"

export IPS_DATA="<replace-with-path>/interproscan/data"
export EGGNOG_DIAMOND_DB="<replace-with-path>/eggnog/data/eggnog_proteins.dmnd"
export EGGNOG_DB="<replace-with-path>/eggnog/data/eggnog.db"
export EGGNOG_DIR="<replace-with-path>/eggnog/data/"
export RFAMS_CMS_DIR="<replace-with-path>/rfams_cms"

export KEGG_CLASSES="<replace-with-path>/kegg_classes.tsv"
export RFAM_CLANIN="<replace-with-path>/ncrna_cms/Rfam.clanin"
export RFAM_MODEL_NCRNA="<replace-with-path>/ncrna_cms/Rfam.cm"

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

# NEEDED for GTDBtk, it has to be a short tmp path, less than 80 chars
export GTDBTK_TMP=""

# TOIL SPECIFICS #
TOIL_JOBSTORE="<path>"
OUTDIRNAME="test"
MEMORY=100G
QUEUE="production"