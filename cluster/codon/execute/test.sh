#!/bin/bash

DEFAULT_QUEUE="standard"
BIGQUEUE="bigmem"

STEP1="Step1.drep"
STEP2="Step2.mash"
STEP3="Step3.clusters"
STEP4="Step4.mmseqs"
STEP5="Step5.gtdbtk"
STEP6="Step6.annotation"
STEP7="Step7.metadata"
STEP8="Step8.postprocessing"

MEM_STEP1="50G"
MEM_STEP2="10G"
MEM_STEP3="50G"
MEM_STEP4="150G"
MEM_STEP5="500G"
MEM_STEP6="50G"
MEM_STEP7="5G"
MEM_STEP8="5G"

THREADS_STEP1="16"
THREADS_STEP2="4"
THREADS_STEP3="8"
THREADS_STEP4="32"
THREADS_STEP5="2"
THREADS_STEP6="16"
THREADS_STEP7="1"
THREADS_STEP8="1"

usage()
{
cat << EOF
usage: $0 options
Run genomes-pipeline with cwltool by parts
OPTIONS:
   -h      Show help message
   -t      Threads. Default=4 [OPTIONAL]
   -p      Path to installed pipeline location
   -n      Catalogue name
   -o      Output location
   -f      Folder with ENA genomes
   -c      ENA genomes csv
   -x      Min MGYG
   -m      Max MGYG
   -v      Catalogue version
   -b      Catalogue Biome
EOF
}

while getopts "h:p:n:f:c:m:x:v:b:o:q:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         p)
             MAIN_PATH=${OPTARG}
             ;;
         n)
             NAME=${OPTARG}
             ;;
         f)
             ENA_GENOMES=${OPTARG}
             ;;
         c)
             ENA_CSV=${OPTARG}
             ;;
         m)
             MAX_MGYG=${OPTARG}
             ;;
         x)
             MIN_MGYG=${OPTARG}
             ;;
         v)
             CATALOGUE_VERSION=${OPTARG}
             ;;
         b)
             BIOM=${OPTARG}
             ;;
         o)
             OUTPUT=${OPTARG}
             ;;
         q)
             QUEUE=${OPTARG}
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [[ -z ${MAIN_PATH} ]]
then
    MAIN_PATH="/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/"
fi

if [[ -z ${NAME} ]]
then
    NAME="test"
fi

if [[ -z ${OUTPUT} ]]
then
    OUTPUT=${MAIN_PATH}
fi

if [[ -z ${CATALOGUE_VERSION} ]]
then
    CATALOGUE_VERSION="v1.0"
fi

if [[ -z ${QUEUE} ]]
then
    QUEUE=${DEFAULT_QUEUE}
fi

export OUT=${OUTPUT}/${NAME}
export LOGS=${OUT}/logs/
export YML=${OUT}/ymls
mkdir -p ${OUT} ${LOGS} ${YML}

export REPS_FILE=${OUT}/cluster_reps.txt
export ALL_GENOMES=${OUT}/all_cluster_filt.txt
touch ${REPS_FILE} ${ALL_GENOMES}
export REPS_FA_DIR=${OUT}/reps_fa
export ALL_FNA_DIR=${OUT}/all_fna

export MEM="10G"
export THREADS="2"

echo "Submitting annotation"
bsub \
    -J "${STEP6}.${NAME}.submit" \
    -q ${QUEUE} \
    -e ${LOGS}/submit.annotation.err \
    -o ${LOGS}/submit.annotation.out \
    bash ${MAIN_PATH}/cluster/codon/execute/utils/6_annotation.sh \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML} \
        -i ${OUT}/${NAME}_mmseqs_0.90/mmseqs_0.9_outdir \
        -r ${REPS_FILE} \
        -j ${STEP6} \
        -b ${ALL_FNA_DIR} \
        -z ${MEM_STEP6} \
        -t ${THREADS_STEP6} \
        -w "False"

# ------------------------- Step 7 ------------------------------
echo "==== waiting for GTDB-Tk.... ===="
bwait -w "ended(${STEP6}.${NAME}.submit) "
bwait -w "ended(${STEP6}.${NAME}.run)"

echo "==== 7. Metadata and phylo.tree ===="
echo "Submitting metadata and phylo.tree generation"
bsub \
    -J "${STEP7}.${NAME}.submit" \
    -q ${QUEUE} \
    -e ${LOGS}/submit.metadata.err \
    -o ${LOGS}/submit.metadata.out \
    bash ${MAIN_PATH}/cluster/codon/execute/utils/7_metadata.sh \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML} \
        -v ${CATALOGUE_VERSION} \
        -i ${OUT}/${NAME}_drep/intermediate_files \
        -g ${OUT}/gtdbtk/gtdbtk-outdir \
        -r ${OUT}/${NAME}_annotations/rRNA_outs \
        -j ${STEP7} \
        -f ${ALL_FNA_DIR} \
        -s "${ENA_CSV}" \
        -z ${MEM_STEP7} \
        -t ${THREADS_STEP7}

# ------------------------- Step 8 ------------------------------
echo "==== waiting for metadata and protein annotations.... ===="
bwait -w "ended(${STEP6}.${NAME}.submit) && ended(${STEP7}.${NAME}.submit)"
bwait -w "ended(${STEP6}.${NAME}.run) && ended(${STEP7}.${NAME}.run)"

echo "==== 8. Post-processing ===="
echo "Submitting post-processing"
bsub \
    -J "${STEP8}.${NAME}.submit" \
    -q ${QUEUE} \
    -e ${LOGS}/submit.post-processing.err \
    -o ${LOGS}/submit.post-processing.out \
    bash ${MAIN_PATH}/cluster/codon/execute/utils/8_post_processing.sh \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML} \
        -j ${STEP8} \
        -b "${BIOM}" \
        -m ${OUT}/${NAME}_metadata/genomes-all_metadata.tsv \
        -a ${OUT}/${NAME}_annotations \
        -z ${MEM_STEP8} \
        -t ${THREADS_STEP8}

echo "==== Final. Exit ===="