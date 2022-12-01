export PIPELINE_DIRECTORY=""
export DEFAULT_QUEUE="standard"
export BIGQUEUE="bigmem"

export GUNC_DB="<replace-path>/gunc_db_2.0.4.dmnd"
export GTDBTK_REF="<replace-path>/reference207"
export GEO="<replace-path>/continent_countries.csv"
export KEGG_CLASSES="<replace-path>/kegg_classes.tsv"
export CLANIN="<replace-path>/ncrna_cms/Rfam.clanin"
export RFAM="<replace-path>/ncrna_cms/Rfam.cm"

# Software & Scripts #
export SINGULARITY_CACHEDIR="<replace-path>"
export PATH="${PIPELINE_DIRECTORY}/src/scripts:$PATH"

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