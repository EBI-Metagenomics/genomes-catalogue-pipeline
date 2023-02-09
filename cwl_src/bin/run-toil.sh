#!/bin/bash

set -e

PIPELINE_DIRECTORY=""
CWL=""
YML=""

SINGULARITY_ON="True"

while getopts :n:y:c:m:q:b:s:o:t:p: option; do
    case "${option}" in
    y) YML=${OPTARG} ;;
    c) CWL=${OPTARG} ;;
    m) MEMORY=${OPTARG} ;;
    q) QUEUE=${OPTARG} ;;
    s) SINGULARITY_ON=${OPTARG} ;;
    o) OUTDIR=${OPTARG} ;;
    n) JOB_NAME=${OPTARG} ;;
    t) TMPDIR=${OPTARG} ;;
    p) PIPELINE_DIRECTORY=${OPTARG} ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
    esac
done

. "${PIPELINE_DIRECTORY}/.gpenv"

export TOIL_LSF_ARGS="-q ${QUEUE}"

echo "${TOIL_LSF_ARGS}"

export RUN_OUTDIR=${OUTDIR}
export LOG_DIR=${OUTDIR}/logs/${JOB_NAME}
export RUN_TOIL_JOBSTORE=${TOIL_JOBSTORE}/${JOB_NAME}

rm -rf "${RUN_TOIL_JOBSTORE}" || true
mkdir -p "${RUN_OUTDIR}" "${LOG_DIR}"

echo "Log-file ${LOG_DIR}/${JOB_NAME}.log"

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
        --logFile "${LOG_DIR}/${JOB_NAME}.log" \
        --rotatingLogging \
        --singularity \
        --batchSystem lsf \
        --bypass-file-store \
        --disableCaching \
        --jobStore "${RUN_TOIL_JOBSTORE}" \
        --retryCount 2 \
        --defaultMemory ${MEMORY} \
        "${CWL}" "${YML}" >"${LOG_DIR}/${JOB_NAME}.json"
else
    toil-cwl-runner \
        --logWarning \
        --stats \
        --logDebug \
        --writeLogs "${LOG_DIR}" \
        --maxLogFileSize 50000000 \
        --outdir "${RUN_OUTDIR}" \
        --logFile "${LOG_DIR}/${JOB_NAME}.log" \
        --rotatingLogging \
        --no-container --preserve-entire-environment \
        --batchSystem lsf \
        --bypass-file-store \
        --disableCaching \
        --jobStore "${RUN_TOIL_JOBSTORE}" \
        --retryCount 2 \
        --defaultMemory ${MEMORY} \
        "${CWL}" "${YML}" >"${LOG_DIR}/${JOB_NAME}.json"
fi

now="$(date)"
echo "Toil finish: $now"
