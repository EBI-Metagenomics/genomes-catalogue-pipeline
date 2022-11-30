#!/bin/bash

set -e

. "${PIPELINE_DIRECTORY}"/.gpenv

CWL="${PIPELINE_DIRECTORY}"/cwl/workflows/wf-main.cwl
YML="${PIPELINE_DIRECTORY}"/tests/cluster/wf-main_ena_verysmall.yml

SINGULARITY_ON="True"

while getopts :n:y:c:m:q:b:s:o:t: option; do
    case "${option}" in
    y) YML=${OPTARG} ;;
    c) CWL=${OPTARG} ;;
    m) MEMORY=${OPTARG} ;;
    q) QUEUE=${OPTARG} ;;
    s) SINGULARITY_ON=${OPTARG} ;;
    o) OUTDIR=${OPTARG} ;;
    n) OUTDIRNAME=${OPTARG} ;;
    t) TMPDIR=${OPTARG} ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
    esac
done

export PATH=$PATH:"${PIPELINE_DIRECTORY}"/containers/python3_scripts/
export PATH=$PATH:"${PIPELINE_DIRECTORY}"/containers/genomes-catalog-update/scripts/

export TOIL_LSF_ARGS="-q ${QUEUE}"

echo "${TOIL_LSF_ARGS}"

export RUN_OUTDIR=${OUTDIR}/${OUTDIRNAME}
export LOG_DIR=${OUTDIR}/logs/${OUTDIRNAME}
export RUN_TOIL_JOBSTORE=${TOIL_JOBSTORE}/${OUTDIRNAME}

rm -rf "${RUN_TOIL_JOBSTORE}" || true
mkdir -p "${RUN_OUTDIR}" "${LOG_DIR}"

echo "Log-file ${LOG_DIR}/${OUTDIRNAME}.log"

now="$(date)"
echo "Toil start: $now"

set -x

if [ "${SINGULARITY_ON}" == "True" ]; then
    toil-cwl-runner \
        --logWarning \
        --stats \
        --logDebug \
        --writeLogs "${LOG_DIR}" \
        --maxLogFileSize 50000000 \
        --outdir "${RUN_OUTDIR}" \
        --logFile "${LOG_DIR}/${OUTDIRNAME}.log" \
        --rotatingLogging \
        --singularity \
        --batchSystem lsf \
        --bypass-file-store \
        --disableCaching \
        --TOIL_JOBSTORE ${RUN_TOIL_JOBSTORE} \
        --retryCount 2 \
        --defaultMemory ${MEMORY} \
        ${CWL} ${YML} >"${LOG_DIR}/${OUTDIRNAME}.json"
else
    toil-cwl-runner \
        --logWarning \
        --stats \
        --logDebug \
        --writeLogs "${LOG_DIR}" \
        --maxLogFileSize 50000000 \
        --outdir "${RUN_OUTDIR}" \
        --logFile "${LOG_DIR}/${OUTDIRNAME}.log" \
        --rotatingLogging \
        --no-container --preserve-entire-environment \
        --batchSystem lsf \
        --bypass-file-store \
        --disableCaching \
        --TOIL_JOBSTORE ${RUN_TOIL_JOBSTORE} \
        --retryCount 2 \
        --defaultMemory ${MEMORY} \
        ${CWL} ${YML} >"${LOG_DIR}/${OUTDIRNAME}.json"
fi

now="$(date)"
echo "Toil finish: $now"
