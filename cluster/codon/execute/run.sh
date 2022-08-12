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
touch ${REPS_FILE} ${ALL_GENOMES}
export REPS_FA_DIR=${OUT}/reps_fa
export ALL_FNA_DIR=${OUT}/all_fna

# ------------------------- Step 1 ------------------------------
echo "==== 1. Run preparation and dRep steps with cwltool ===="
# TODO improve for NCBI
echo "Submitting dRep"
bash ${MAIN_PATH}/cluster/codon/execute/utils/1_drep.sh \
    -o ${OUT} \
    -p ${MAIN_PATH} \
    -l ${LOGS} \
    -n ${NAME} \
    -q ${QUEUE} \
    -y ${YML} \
    -i "${ENA_GENOMES}" \
    -c "${ENA_CSV}" \
    -m "${MAX_MGYG}" \
    -x "${MIN_MGYG}" \
    -j ${STEP1}

# ------------------------- Step 2 ------------------------------
echo "==== 2. Run mash2nwk ===="
echo "Submitting mash"
bsub \
     -J "${STEP2}.${NAME}.submit" \
     -w "ended(${STEP1}.${NAME})" \
     -q ${QUEUE} \
     -e ${LOGS}/submit.mash.err \
     -o ${LOGS}/submit.mash.out \
     bash ${MAIN_PATH}/cluster/codon/execute/utils/2_mash.sh \
        -m ${OUT}/${NAME}_drep/mash \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML} \
        -j ${STEP2} \
        -c "ended(${STEP1}.${NAME})"

# ------------------------- Step 3 ------------------------------
mkdir -p ${OUT}/sg ${OUT}/pg
echo "==== 3. Run cluster annotation ===="
echo "Submitting pan-genomes"
bsub \
    -J "${STEP3}.${NAME}.pg" \
    -w "ended(${STEP1}.${NAME}) && ended(${STEP2}.${NAME}.*)" \
    -q ${QUEUE} \
    -e ${LOGS}/submit.pg.err \
    -o ${LOGS}/submit.pg.out \
    bash ${MAIN_PATH}/cluster/codon/execute/utils/3_process_clusters.sh \
        -i ${OUT}/${NAME}_drep/pan-genomes \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -t 'pg' \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML} \
        -j ${STEP3} \
        -c "ended(${STEP2}.${NAME}.*)" \
        -s ${ENA_CSV}

echo "Submitting singletons"
bsub \
    -J "${STEP3}.${NAME}.sg" \
    -w "ended(${STEP1}.${NAME})" \
    -q ${QUEUE} \
    -e ${LOGS}/submit.sg.err \
    -o ${LOGS}/submit.sg.out \
    bash ${MAIN_PATH}/cluster/codon/execute/utils/3_process_clusters.sh \
        -i ${OUT}/${NAME}_drep/singletons \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -t 'sg' \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML} \
        -j ${STEP3} \
        -c "ended(${STEP1}.${NAME})" \
        -s ${ENA_CSV}

# ------------------------- Step 4 ------------------------------
echo "==== 4. Run mmseqs ===="
# TODO improve for no sg or pg
bsub \
    -J "${STEP4}.${NAME}.submit" \
    -w "ended(${STEP3}.${NAME}.*)" \
    -q ${QUEUE} \
    -e ${LOGS}/submit.mmseq.err \
    -o ${LOGS}/submit.mmseq.out \
    bash ${MAIN_PATH}/cluster/codon/execute/utils/4_mmseqs.sh \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML} \
        -r ${REPS_FILE} \
        -f ${ALL_GENOMES} \
        -j ${STEP4} \
        -c "ended(${STEP3}.${NAME}.*" \
        -a ${REPS_FA_DIR} \
        -b ${ALL_FNA_DIR}

# ------------------------- Step 5 ------------------------------

echo "==== 5. Run GTDB-Tk ===="
# TODO change queue to BIGMEM in production
echo "Submitting GTDB-Tk"
bsub \
    -J "${STEP5}.${NAME}.submit" \
    -w "ended(${STEP3}.${NAME}.*)" \
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
        -c "ended(${STEP3}.${NAME}.*) && ended(${STEP4}.${NAME}.cat) && ended(${STEP4}.${NAME}.files)" \
        -a ${REPS_FA_DIR}

# ------------------------- Step 6 ------------------------------
echo "==== 6. EggNOG, IPS, rRNA ===="
echo "Submitting annotation"
bsub \
    -J "${STEP6}.${NAME}.submit" \
    -w "ended(${STEP1}.${NAME}) && ended(${STEP2}.${NAME}.*) && ended(${STEP3}.${NAME}.*) && ended(${STEP4}.${NAME}.*)" \
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
        -c "ended(${STEP4}.${NAME}.*)" \
        -b ${ALL_FNA_DIR}

# ------------------------- Step 7 ------------------------------
echo "==== 7. Metadata and phylo.tree ===="
echo "Submitting metadata and phylo.tree generation"
bsub \
    -J "${STEP7}.${NAME}.submit" \
    -w "ended(${STEP5}.${NAME}.*) && ended(${STEP6}.${NAME}.*)" \
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
        -c "ended(${STEP5}.${NAME}.*) && ended(${STEP6}.${NAME}.*)" \
        -f ${ALL_FNA_DIR} \
        -s ${ENA_CSV}

# ------------------------- Step 8 ------------------------------
echo "==== 8. Post-processing ===="
echo "Submitting post-processing"
bsub \
    -J "${STEP8}.${NAME}.submit" \
    -w "ended(${STEP6}.${NAME}.*) && ended(${STEP7}.${NAME}.*)" \
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
        -c "ended(${STEP6}.${NAME}.*) && ended(${STEP7}.${NAME}.*)" \
        -b "${BIOM}" \
        -m ${OUT}/${NAME}_metadata/genomes-all_metadata.tsv \
        -a ${OUT}/${NAME}_annotations

echo "==== Final ===="