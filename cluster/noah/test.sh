#!/bin/bash

# max limit of memory that would be used by toil to restart
export MEMORY=20G
# number of cores to run toil
export NUM_CORES=8
# clone of pipeline-v5 repo
export PIPELINE_FOLDER=/hps/nobackup2/production/metagenomics/databases/human-gut_resource/cwl_pipeline/genomes-pipeline
export CUR_DIR=${PIPELINE_FOLDER}/test

export CWL=${PIPELINE_FOLDER}/workflows/wf-main.cwl
export YML=${PIPELINE_FOLDER}/tests/cwltest/wfs/wf-main/wf-main-ena.yml

while getopts :m:n:c:a:l:y: option; do
	case "${option}" in
		m) MEMORY=${OPTARG};;
		n) NUM_CORES=${OPTARG};;
		c) CUR_DIR=${OPTARG};;
		a) NAME_RUN=${OPTARG};;
		l) CWL=${OPTARG};;
		y) YML=${OPTARG};;
	esac
done

# --------------------------------- 1 ---------------------------------
echo "Activating envs"
source /hps/nobackup/production/metagenomics/software/toil-20200722/v3nv/bin/activate
source /nfs/production/interpro/metagenomics/mags-scripts/annot-config
export PATH=$PATH:/homes/emgpr/.nvm/versions/node/v12.10.0/bin/

echo "Set folders"
export WORK_DIR=${CUR_DIR}/work-dir
export JOB_TOIL=${WORK_DIR}/job-store
export OUT_DIR=${CUR_DIR}
export LOG_DIR=${OUT_DIR}/log-dir/${NAME_RUN}
export TMPDIR=${WORK_DIR}/temp-dir/${NAME_RUN}
export OUT_TOOL=${OUT_DIR}/results/${NAME_RUN}

echo "Create empty ${LOG_DIR} and YML-file"

mkdir -p ${LOG_DIR} ${OUT_TOOL}

echo "Set TOIL_LSF_ARGS"
export JOB_GROUP=genome_pipeline
bgadd -L 50 /${USER}_${JOB_GROUP} > /dev/null
bgmod -L 50 /${USER}_${JOB_GROUP} > /dev/null
export TOIL_LSF_ARGS="-g /${USER}_${JOB_GROUP} -P bigmem"  #-q production-rh74

# --------------------------------- 2 ---------------------------------
echo "Out json would be in ${NAME_RUN}/out.json"

rm -rf ${JOB_TOIL}/${NAME_RUN} && mkdir -p ${TMPDIR} && \
cd ${WORK_DIR} && \
time toil-cwl-runner \
  --no-container \
  --batchSystem lsf --disableCaching \
  --preserve-entire-environment \
  --enable-dev \
  --disableChaining \
  --defaultMemory ${MEMORY} \
  --defaultCores ${NUM_CORES} \
  --jobStore ${JOB_TOIL}/${NAME_RUN} \
  --outdir ${OUT_TOOL} \
  --retryCount 3 \
  --logFile ${LOG_DIR}/${NAME_RUN}.log \
${CWL} ${YML} > ${OUT_TOOL}/out.json
