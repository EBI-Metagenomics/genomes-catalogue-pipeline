#!/bin/bash

set -e

. /hps/software/users/rdf/metagenomics/service-team/envs/mitrc.sh

mitload miniconda

module load singularity-3.7.0-gcc-9.3.0-dp5ffrp
conda activate toil-5.4.0

export PATH=$PATH:/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/docker/python3_scripts/
chmod a+x /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/docker/python3_scripts/*

CWL=/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/cwl/workflows/wf-main.cwl
YML=/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/tests/cluster/wf-main_ena_verysmall.yml

JOBSTORE="/hps/nobackup/rdf/metagenomics/toil-jobstore/genomes-pipeline-test"
OUTDIR="/hps/nobackup/rdf/metagenomics/test-folder/genomes-pipeline"
OUTDIRNAME="test"
MEMORY=100G
QUEUE="production"
BIG_MEM="False"
SINGULARUTY_ON="True"


while getopts :n:y:c:m:q:b:s: option; do
        case "${option}" in
                n) OUTDIRNAME=${OPTARG};;
                y) YML=${OPTARG};;
                c) CWL=${OPTARG};;
                m) MEMORY=${OPTARG};;
                q) QUEUE=${OPTARG};;
                b) BIG_MEM=${OPTARG};;
                s) SINGULARUTY_ON=${OPTARG};;
        esac
done

export TMPDIR="/tmp"

export TOIL_LSF_ARGS="-q ${QUEUE}"
if [ "${BIG_MEM}" == "True" ]; then
    export TOIL_LSF_ARGS="-q ${QUEUE} -P bigmem"
fi
echo ${TOIL_LSF_ARGS}

export RUN_OUTDIR=${OUTDIR}/${OUTDIRNAME}
export LOG_DIR=${OUTDIR}/logs/${OUTDIRNAME}
export RUN_JOBSTORE=${JOBSTORE}/${OUTDIRNAME}

rm -rf "${RUN_JOBSTORE}" || true
mkdir -p ${RUN_OUTDIR} ${LOG_DIR}

echo "Log-file ${LOG_DIR}/${OUTDIRNAME}.log"

echo "Toil start:"; date;

set -x

if [ "${SINGULARUTY_ON}" == "True" ]; then
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
        --disableCaching \
        --jobStore ${RUN_JOBSTORE} \
        --retryCount 2 \
        --defaultMemory ${MEMORY} \
        ${CWL} ${YML}
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
        --disableCaching \
        --jobStore ${RUN_JOBSTORE} \
        --retryCount 2 \
        --defaultMemory ${MEMORY} \
        ${CWL} ${YML}
fi

echo "Toil finish:"; date;