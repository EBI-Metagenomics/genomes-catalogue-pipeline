#!/bin/bash

set -e

. /hps/software/users/rdf/metagenomics/service-team/envs/mitrc.sh

mitload miniconda

module load singularity-3.7.0-gcc-9.3.0-dp5ffrp
conda activate toil-5.4.0

CWL=/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/cwl/workflows/wf-main.cwl
YML=/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/tests/cluster/wf-main_ena_verysmall.yml

JOBSTORE="/hps/nobackup/rdf/metagenomics/toil-jobstore/genomes-pipeline-test"
OUTDIR="/hps/nobackup/rdf/metagenomics/test-folder/genomes-pipeline"
OUTDIRNAME="test"
MEMORY=100G
QUEUE="production"
BIG_MEM="False"


while getopts :n:y:c:m:q:b: option; do
        case "${option}" in
                n) OUTDIRNAME=${OPTARG};;
                y) YML=${OPTARG};;
                c) CWL=${OPTARG};;
                m) MEMORY=${OPTARG};;
                q) QUEUE=${OPTARG};;
                b) BIG_MEM=${OPTARG};;
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

echo "Log-file ${LOG_DIR}/${OUTDIRNAME}.log"

echo "Toil restart start:"; date;

set -x

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
${CWL} ${YML}

echo "Toil restart finish:"; date;