#!/bin/bash

DEFAULT_QUEUE="standard"
BIGQUEUE="bigmem"

STEP1="Step1.drep"
STEP2="Step2.mash"
STEP3="Step3"
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

while getopts "ht:p:n:f:c:m:x:v:b:o:q:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         t)
             THREADS=${OPTARG}
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

if [[ -z ${MAIN_PATH} ]]
then
    THREADS=4
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
    -i ${ENA_GENOMES} \
    -c ${ENA_CSV} \
    -m ${MAX_MGYG} \
    -x ${MIN_MGYG} \
    -j ${STEP1}

sleep 5
# ------------------------- Step 2 ------------------------------
echo "==== 2. Run mash2nwk ===="
echo "Submitting mash"
bsub -w "ended(${STEP1}.${NAME})" \
     -J "${STEP2}.submit.${NAME}" \
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
        -j ${STEP2} \
        -c ${STEP1}

# ------------------------- Step 3 ------------------------------
mkdir -p ${OUT}/sg ${OUT}/pg
echo "==== 3. Run cluster annotation ===="
echo "Submitting pan-genomes"
bsub \
    -J "${STEP3}.pg.${NAME}" \
    -w "ended(${STEP2}.*.${NAME})" \
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
        -j ${STEP3}

echo "Submitting singletons"
bsub \
    -J "${STEP3}.sg.${NAME}" \
    -w "ended(${STEP2}.*.${NAME})" \
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
        -j ${STEP3}

# ------------------------- Step 4 ------------------------------
echo "==== 4. Run mmseqs ===="
# TODO improve for no sg or pg
bsub \
    -J "${STEP4}.submit.${NAME}" \
    -w "ended(${STEP3}.*.${NAME})" \
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
        -j ${STEP4}

# ------------------------- Step 5 ------------------------------

echo "==== 5. Run GTDB-Tk ===="
echo "Submitting GTDB-Tk"
bsub \
    -w "ended(${STEP4}.*.${NAME})" \
    -J "${STEP5}.submit.${NAME}" \
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
        -j ${STEP5}

# ------------------------- Step 6 ------------------------------
echo "==== 6. EggNOG, IPS, rRNA ===="
#echo "Submitting annotation"
#echo bsub \
#    -J "Step7.annotation.submit.${NAME}" \
#    -w "ended(Step5*${NAME})" \
#    -q ${QUEUE} \
#    -e ${LOGS}/submit.annotation.err \
#    -o ${LOGS}/submit.annotation.out \
#    bash ${MAIN_PATH}/cluster/codon/execute/utils/6_annotation.sh \
#        -o ${OUT} \
#        -p ${MAIN_PATH} \
#        -l ${LOGS} \
#        -n ${NAME} \
#        -q ${QUEUE} \
#        -y ${YML} \
#        -i ${OUT}/${NAME}_mmseqs \
#        -r ${REPS_FILE}

# ------------------------- Step 7 ------------------------------
echo "==== 7. Metadata and phylo.tree ===="

# ------------------------- Step 8 ------------------------------
echo "==== 8. Post-processing ===="