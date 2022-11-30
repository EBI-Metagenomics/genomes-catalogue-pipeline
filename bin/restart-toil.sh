#!/bin/bash

set -e

. "${PIPELINE_DIRECTORY}"/.gpenv

CWL="${PIPELINE_DIRECTORY}"/cwl/workflows/wf-main.cwl
YML="${PIPELINE_DIRECTORY}"/tests/cluster/wf-main_ena_verysmall.yml

OUTDIR="/hps/nobackup/rdf/metagenomics/test-folder/genomes-pipeline"
TMPDIR="/hps/scratch/rdf/metagenomics/pipelines-tmp"

MEMORY=100G
QUEUE="production"

while getopts :n:y:c:m:q:b:s:p:o:t: option; do
    case "${option}" in
    n) OUTDIRNAME=${OPTARG} ;;
    y) YML=${OPTARG} ;;
    c) CWL=${OPTARG} ;;
    m) MEMORY=${OPTARG} ;;
    q) QUEUE=${OPTARG} ;;
    s) SINGULARUTY_ON=${OPTARG} ;;
    p) MAIN_PATH=${OPTARG} ;;
    o) OUTDIR=${OPTARG} ;;
    t) TMPDIR=${OPTARG} ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
    esac
done

export PATH=$PATH:${MAIN_PATH}/docker/python3_scripts/
export PATH=$PATH:${MAIN_PATH}/docker/genomes-catalog-update/scripts/

CWL=${PIPELINE_DIRECTORY}/src/cwl/workflows/wf-main.cwl

export TOIL_LSF_ARGS="-q ${QUEUE}"
echo ${TOIL_LSF_ARGS}

export RUN_OUTDIR=${OUTDIR}/${OUTDIRNAME}
export LOG_DIR=${OUTDIR}/logs/${OUTDIRNAME}
export RUN_TOIL_JOBSTORE=${TOIL_JOBSTORE}/${OUTDIRNAME}

echo "Log-file ${LOG_DIR}/${OUTDIRNAME}.log"

echo "Toil restart start:"
date

set -x

if [ "${SINGULARUTY_ON}" == "True" ]; then
    toil-cwl-runner \
        --stats \
        --logDebug \
        --restart \
        --logWarning \
        --writeLogs "${LOG_DIR}" \
        --maxLogFileSize 50000000 \
        --outdir "${RUN_OUTDIR}" \
        --logFile "${LOG_DIR}/${OUTDIRNAME}.log" \
        --rotatingLogging \
        --singularity \
        --batchSystem lsf \
        --disableCaching \
        --TOIL_JOBSTORE ${RUN_TOIL_JOBSTORE} \
        --retryCount 2 \
        --defaultMemory ${MEMORY} \
        ${CWL} ${YML}
else
    toil-cwl-runner \
        --stats \
        --logDebug \
        --restart \
        --logWarning \
        --writeLogs "${LOG_DIR}" \
        --maxLogFileSize 50000000 \
        --outdir "${RUN_OUTDIR}" \
        --logFile "${LOG_DIR}/${OUTDIRNAME}.log" \
        --rotatingLogging \
        --no-container --preserve-entire-environment \
        --batchSystem lsf \
        --disableCaching \
        --TOIL_JOBSTORE ${RUN_TOIL_JOBSTORE} \
        --retryCount 2 \
        --defaultMemory ${MEMORY} \
        ${CWL} ${YML}
fi

echo "Toil restart finish:"
date
