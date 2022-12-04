#!/bin/bash

usage() {
    cat <<EOF
usage: $0 options
Run genomes-pipeline GTDTK step using singularity.
OPTIONS:
   -o      Path to general output catalogue directory
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -j      LSF step Job name to submit
   -a      Path to directory with fasta.fna cluster representatives (filtered)
   -z      Memory in Gb
   -t      Number of threads
   -r      GTDBtk REF db (releases202/)
   -p      Pipeline repo directory
EOF
}

set -e

GTDBTK_REFDATA=""

while getopts ho:l:n:q:j:a:z:t:r:p: option; do
    case "${option}" in
    h)
        usage
        exit 1
        ;;
    o)
        OUT=${OPTARG}
        ;;
    l)
        LOGS=${OPTARG}
        ;;
    n)
        DIRNAME=${OPTARG}
        ;;
    q)
        QUEUE=${OPTARG}
        ;;
    j)
        JOB=${OPTARG}
        ;;
    a)
        REPS_FA=${OPTARG}
        ;;
    z)
        MEM=${OPTARG}
        ;;
    t)
        THREADS=${OPTARG}
        ;;
    r)
        GTDBTK_REFDATA=${OPTARG}
        ;;
    p)
        PIPELINE_DIRECTORY=${OPTARG}
        ;;
    ?)
        usage
        exit
        ;;
    esac
done

. "${PIPELINE_DIRECTORY}/.gpenv"

######################################
## GTDBtk needs a short TMP directory
#####################################

export TMPDIR="${GTDBTK_TMP}"

mkdir -p "${OUT}"/gtdbtk

bsub \
    -J "${JOB}.${DIRNAME}.run" \
    -e "${LOGS}"/"${JOB}".err \
    -o "${LOGS}"/"${JOB}".out \
    -M "${MEM}" \
    -n "${THREADS}" \
    -q "${QUEUE}" \
    singularity \
        --quiet \
        run \
        --bind \
        "${GTDBTK_REFDATA}":/refdata:ro \
        "${SINGULARITY_CACHEDIR}"/quay.io_microbiome-informatics_genomes-pipeline.gtdb-tk:v2.1.0.sif \
        gtdbtk \
        classify_wf \
        --cpus \
        32 \
        --genome_dir \
        "${REPS_FA}" \
        --out_dir \
        "${OUT}"/gtdbtk/gtdbtk-outdir \
        -x fna
