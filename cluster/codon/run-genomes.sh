#!/bin/bash
#BSUB -n 1
#BSUB -R "rusage[mem=4096]"
#BSUB -J genomes-pipeline
#BSUB -o output.txt
#BSUB -e error.txt

# CONSTANTS
# Wrapper for genomes-pipeline.sh
WORKDIR="/hps/nobackup/rdf/metagenomics/toil-workdir"

# Production scripts and env
GENOMES_SH="/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/cluster/codon/genomes-pipeline.sh"
#ENV_FILE="/nfs/production/rdf/metagenomics/pipelines/prod/emg-viral-pipeline/cwl/ebi/virify-env.sh"

set -e

usage () {
    echo ""
    echo "MAGs pipeline BSUB"
    echo ""
    echo "-o output folder [mandatory]"
    echo ""
    echo "Example:"
    echo ""
    echo "run-genomes.sh -o test-run "
    echo ""
}

# PARAMS
RESULTS_FOLDER=""

while getopts ":o:" opt; do
  case $opt in
    o)
        RESULTS_FOLDER="$OPTARG"
        ;;
    :)
        usage;
        exit 1
        ;;
    \?)
        usage;
        exit 1;
    ;;
  esac
done

if ((OPTIND == 1))
then
    echo ""
    echo "ERROR! No options specified"
    usage;
    exit 1
fi

${GENOMES_SH} \
-o ${RESULTS_FOLDER} \
