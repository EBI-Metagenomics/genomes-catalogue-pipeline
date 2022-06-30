#!/bin/bash

set -e

. /hps/software/users/rdf/metagenomics/service-team/repos/mi-automation/team_environments/codon/mitrc.sh

mitload miniconda

module load singularity-3.7.0-gcc-9.3.0-dp5ffrp
conda activate toil-5.6.0

MAIN_PATH="/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/"

JOBSTORE="/hps/nobackup/rdf/metagenomics/toil-jobstore/genomes-pipeline-test"
OUTDIR="/hps/nobackup/rdf/metagenomics/test-folder/genomes-pipeline"
TMPDIR="/hps/scratch/rdf/metagenomics/pipelines-tmp"
OUTDIRNAME="test"
MEMORY=100G
QUEUE="production"
BIG_MEM="False"


while getopts :n:y:c:m:q:b:s:p:o:t: option; do
        case "${option}" in
                n) OUTDIRNAME=${OPTARG};;
                y) YML=${OPTARG};;
                c) CWL=${OPTARG};;
                m) MEMORY=${OPTARG};;
                q) QUEUE=${OPTARG};;
                b) BIG_MEM=${OPTARG};;
                s) SINGULARUTY_ON=${OPTARG};;
                p) MAIN_PATH=${OPTARG};;
                o) OUTDIR=${OPTARG};;
                t) TMPDIR=${OPTARG};;
        esac
done


export PATH=$PATH:${MAIN_PATH}/docker/python3_scripts/
export PATH=$PATH:${MAIN_PATH}/docker/genomes-catalog-update/scripts/

chmod a+x ${MAIN_PATH}/docker/python3_scripts/*
chmod a+x ${MAIN_PATH}/docker/genomes-catalog-update/scripts/*

CWL=${MAIN_PATH}/cwl/workflows/wf-main.cwl
YML=${MAIN_PATH}/tests/cluster/wf-main_ena_verysmall.yml


export TOIL_LSF_ARGS="-q ${QUEUE}"
if [ "${BIG_MEM}" == "True" ]; then
    export TOIL_LSF_ARGS="-q ${QUEUE} -P bigmem"
fi
echo ${TOIL_LSF_ARGS}

export RUN_OUTDIR=${OUTDIR}/${OUTDIRNAME}
export LOG_DIR=${OUTDIR}/logs/${OUTDIRNAME}
export RUN_JOBSTORE=${JOBSTORE}/${OUTDIRNAME}

echo "Log-file ${LOG_DIR}/${OUTDIRNAME}.log"

echo "Toil restart start:"; date;

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
        --jobStore ${RUN_JOBSTORE} \
        --retryCount 2 \
        --defaultMemory ${MEMORY} \
        --beta-conda-dependencies \
        --beta-dependencies-directory /hps/nobackup/rdf/metagenomics/service-team/toil-conda-envs \
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
        --jobStore ${RUN_JOBSTORE} \
        --retryCount 2 \
        --defaultMemory ${MEMORY} \
        --beta-conda-dependencies \
        --beta-dependencies-directory /hps/nobackup/rdf/metagenomics/service-team/toil-conda-envs \
        ${CWL} ${YML}
fi

echo "Toil restart finish:"; date;