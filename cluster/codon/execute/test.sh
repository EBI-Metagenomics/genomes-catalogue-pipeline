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

export REPS_FA_DIR=${OUT}/reps_fa
export ALL_FNA_DIR=${OUT}/all_fna


echo "==== 5. Run GTDB-Tk ===="
# TODO change queue to BIGMEM in production
echo "Submitting GTDB-Tk"
bsub \
    -J "${STEP5}.${NAME}.submit" \
    -q ${QUEUE} \
    -o ${LOGS}/submit.gtdbtk.out \
    -e ${LOGS}/submit.gtdbtk.err \
    bash ${MAIN_PATH}/cluster/codon/execute/utils/5_gtdbtk.sh \
        -q ${QUEUE} \
        -p ${MAIN_PATH} \
        -o ${OUT} \
        -l ${LOGS} \
        -n ${NAME} \
        -y ${YML} \
        -r ${REPS_FILE} \
        -j ${STEP5} \
        -a ${REPS_FA_DIR}

# ------------------------- Step 6 ------------------------------

echo "==== 6. EggNOG, IPS, rRNA ===="
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
        -b ${ALL_FNA_DIR}

# ------------------------- Step 7 ------------------------------
echo "==== waiting for GTDB-Tk.... ===="
bwait -w "ended(${STEP5}.${NAME}.*)"

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
        -g ${OUT}/gtdbtk/gtdbtk.summary.tsv \
        -r ${OUT}/${NAME}_annotations/rRNA_outs \
        -j ${STEP7} \
        -f ${ALL_FNA_DIR} \
        -s ${ENA_CSV}

# ------------------------- Step 8 ------------------------------
echo "==== waiting for metadata and protein annotations.... ===="
bwait -w "ended(${STEP6}.${NAME}.*) && ended(${STEP7}.${NAME}.*)"

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
        -a ${OUT}/${NAME}_annotations

echo "==== Final. Exit ===="