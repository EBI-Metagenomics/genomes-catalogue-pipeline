#!/bin/bash

# max limit of memory that would be used by toil to restart
export MEMORY=20G
# number of cores to run toil
export NUM_CORES=8
# clone of pipeline-v5 repo
export PIPELINE_FOLDER=/hps/nobackup2/production/metagenomics/databases/human-gut_resource/cwl_pipeline/genomes-pipeline

while getopts :m:n:c:a:g: option; do
	case "${option}" in
		m) MEMORY=${OPTARG};;
		n) NUM_CORES=${OPTARG};;
		c) CUR_DIR=${OPTARG};;
		a) NAME_RUN=${OPTARG};;
		g) GENOMES=${OPTARG};;
	esac
done

# --------------------------------- 1 ---------------------------------
echo "Activating envs"
source /hps/nobackup/production/metagenomics/software/toil-venv/bin/activate
source /nfs/production/interpro/metagenomics/mags-scripts/annot-config
export PATH=$PATH:/homes/emgpr/.nvm/versions/node/v12.10.0/bin/

echo "Set folders"
export WORK_DIR=${CUR_DIR}/work-dir
export JOB_TOIL_FOLDER_1=${WORK_DIR}/job-store-wf-1
export JOB_TOIL_FOLDER_2=${WORK_DIR}/job-store-wf-2
export OUT_DIR=${CUR_DIR}
export LOG_DIR=${OUT_DIR}/log-dir/${NAME_RUN}
export TMPDIR=${WORK_DIR}/temp-dir/${NAME_RUN}
export OUT_DIR_FINAL=${OUT_DIR}/results/${NAME_RUN}

echo "Create empty ${LOG_DIR} and YML-file"
export OUT_TOOL_1=${OUT_DIR_FINAL}_1

mkdir -p $LOG_DIR ${OUT_TOOL_1}

cp $PIPELINE_FOLDER/workflows/yml_patterns/wf-1.yml ${OUT_TOOL_1}
export YML_1=${OUT_TOOL_1}/wf-1.yml
echo " ${GENOMES}" >> ${YML_1}

echo "First part result would be in ${OUT_TOOL_1}"
echo "Set TOIL_LSF_ARGS"
export JOB_GROUP=genome_pipeline
bgadd -L 50 /${USER}_${JOB_GROUP} > /dev/null
bgmod -L 50 /${USER}_${JOB_GROUP} > /dev/null
export TOIL_LSF_ARGS="-g /${USER}_${JOB_GROUP} -P bigmem"  #-q production-rh74

export CWL=$PIPELINE_FOLDER/workflows/wf-1.cwl
export CWL_BOTH=$PIPELINE_FOLDER/workflows/wf-exit-1.cwl
export CWL_MANY=$PIPELINE_FOLDER/workflows/wf-exit-2.cwl
export CWL_ONE=$PIPELINE_FOLDER/workflows/wf-exit-3.cwl

# --------------------------------- 2 ---------------------------------
echo " === Running first part === "
echo "Out json would be in ${OUT_TOOL_1}/out.json"

mkdir -p $JOB_TOIL_FOLDER_1 $TMPDIR && \
cd $WORK_DIR && \
time cwltoil \
  --no-container \
  --batchSystem LSF \
  --disableCaching \
  --defaultMemory $MEMORY \
  --defaultCores $NUM_CORES \
  --jobStore $JOB_TOIL_FOLDER_1/${NAME_RUN} \
  --outdir $OUT_TOOL_1 \
  --retryCount 3 \
  --logFile $LOG_DIR/${NAME_RUN}_1.log \
${CWL} ${YML_1} > ${OUT_TOOL_1}/out1.json

# --------------------------------- 3 ---------------------------------
echo " === Parsing first output folder === "

cp $PIPELINE_FOLDER/workflows/yml_patterns/wf-2.yml ${OUT_TOOL_1}
export YML_2=${OUT_TOOL_1}/wf-2.yml

python3 $PIPELINE_FOLDER/utils/parser_yml.py -j ${OUT_TOOL_1}/out1.json -y ${YML_2}
export EXIT_CODE=$?
echo ${EXIT_CODE}

echo "Yml file: ${YML_2}"

export NAME_RUN_2=${NAME_RUN}_2
export OUT_TOOL_2=${OUT_DIR_FINAL}_2

mkdir -p ${OUT_TOOL_2} ${JOB_TOIL_FOLDER_2}

# --------------------------------- 4 ---------------------------------

if [ ${EXIT_CODE} -eq 1 ]
then
    echo "=== Running many and one genomes sub-wf ==="
    time cwltoil \
        --no-container \
        --batchSystem LSF \
        --disableCaching \
        --defaultMemory $MEMORY \
        --jobStore $JOB_TOIL_FOLDER_2/${NAME_RUN} \
        --outdir $OUT_TOOL_2 \
        --logFile $LOG_DIR/${NAME_RUN}_2.log \
        --defaultCores $NUM_CORES \
        --writeLogs ${LOG_DIR} \
    ${CWL_BOTH} ${YML_2} > ${OUT_TOOL_2}/out2.json
fi
if [ ${EXIT_CODE} -eq 2 ]
then
    echo " === Running many genomes sub-wf === "
    time cwltoil \
        --no-container \
        --batchSystem LSF \
        --disableCaching \
        --defaultMemory $MEMORY \
        --jobStore $JOB_TOIL_FOLDER_2/${NAME_RUN} \
        --outdir $OUT_TOOL_2 \
        --logFile $LOG_DIR/${NAME_RUN}_2.log \
        --defaultCores $NUM_CORES \
        --writeLogs ${LOG_DIR} \
    ${CWL_MANY} ${YML_2} > ${OUT_TOOL_2}/out2.json
fi
if [ ${EXIT_CODE} -eq 3 ]
then
    echo " === Running one genome sub-wf ==="
    time cwltoil \
        --no-container \
        --batchSystem LSF \
        --disableCaching \
        --defaultMemory $MEMORY \
        --jobStore $JOB_TOIL_FOLDER_2/${NAME_RUN} \
        --outdir $OUT_TOOL_2 \
        --logFile $LOG_DIR/${NAME_RUN}_2.log \
        --defaultCores $NUM_CORES \
        --writeLogs ${LOG_DIR} \
    ${CWL_ONE} ${YML_2} > ${OUT_TOOL_2}/out2.json
fi
if [ ${EXIT_CODE} -eq 4 ]
then
    echo "??????? Something very strange happened ????????"
fi

# --------------------------------- 5 ---------------------------------

echo "Moving results"
mkdir -p ${OUT_DIR_FINAL}
if [ -d ${OUT_TOOL_1} ]
then
    mv ${OUT_TOOL_1}/wf-1.yml ${OUT_TOOL_1}/out1.json ${OUT_TOOL_1}/checkm_quality.csv ${OUT_TOOL_1}/taxcheck_output ${OUT_TOOL_1}/gtdb-tk_output ${OUT_DIR_FINAL}
fi
if [ -d ${OUT_TOOL_2} ]
then
    mv ${OUT_TOOL_2}/* ${OUT_DIR_FINAL}
fi