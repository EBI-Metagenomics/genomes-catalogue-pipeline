#!/bin/bash

set -e

. /hps/software/users/rdf/metagenomics/service-team/repos/mi-automation/team_environments/codon/mitrc.sh

mitload miniconda

module load singularity-3.7.0-gcc-9.3.0-dp5ffrp
conda activate toil-5.4.0

export OUTDIR=result

MAIN_PATH="/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/"
CWL=${MAIN_PATH}/cwl/workflows/wf-main.cwl
YML=${MAIN_PATH}/tests/cluster/wf-main_ena_small.yml

while getopts :o:n:y:c:p:d: option; do
    case "${option}" in
    o) OUTDIR=${OPTARG} ;;
    n) NAME=${OPTARG} ;;
    y) YML=${OPTARG} ;;
    c) CWL=${OPTARG} ;;
    p) MAIN_PATH=${OPTARG} ;;
    d) DEBUG=${OPTARG} ;;
    *)
        echo "Invalid usage"
        exit 1
        ;;
    esac
done

export PATH=$PATH:${MAIN_PATH}/docker/python3_scripts/
export PATH=$PATH:${MAIN_PATH}/docker/genomes-catalog-update/scripts/

chmod a+x ${MAIN_PATH}/docker/python3_scripts/*
chmod a+x ${MAIN_PATH}/docker/genomes-catalog-update/scripts/*

if [ "${DEBUG}" == "True" ]; then
    cwltool \
        --debug \
        --leave-tmpdir \
        --singularity \
        --preserve-entire-environment \
        --leave-container \
        --outdir ${OUTDIR}/${NAME} \
        ${CWL} ${YML}
else
    cwltool \
        --singularity \
        --preserve-entire-environment \
        --leave-container \
        --outdir ${OUTDIR}/${NAME} \
        ${CWL} ${YML}
fi
