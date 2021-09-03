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
export MEMORY=100G

while getopts :n:y:c:m: option; do
	case "${option}" in
		n) OUTDIRNAME=${OPTARG};;
		y) YML=${OPTARG};;
		c) CWL=${OPTARG};;
		m) MEMORY=${OPTARG};;
	esac
done

export TMPDIR="/tmp"

export TOIL_LSF_ARGS="-q production"

export RUN_OUTDIR=${OUTDIR}/${OUTDIRNAME}
export LOG_DIR=${OUTDIR}/logs/${OUTDIRNAME}
export RUN_JOBSTORE=${JOBSTORE}/${OUTDIRNAME}

rm -rf "${RUN_JOBSTORE}" || true
mkdir -p ${RUN_OUTDIR} ${LOG_DIR}

echo "Log-file ${LOG_DIR}/${OUTDIRNAME}.log"

toil-cwl-runner \
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