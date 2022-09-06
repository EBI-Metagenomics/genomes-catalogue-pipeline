#!/bin/bash

set -e

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
STEP9="Step9.restructure"

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
export ALL_GENOMES=${OUT}/drep-filt-list.txt
touch ${REPS_FILE} ${ALL_GENOMES}
export REPS_FA_DIR=${OUT}/reps_fa
export ALL_FNA_DIR=${OUT}/mgyg_genomes

export MEM="10G"
export THREADS="2"

export PATH="${MAIN_PATH}/cluster/codon/execute/scripts:$PATH"

# ------------------------- Step 1 ------------------------------
echo "==== 1. Run preparation and dRep steps with cwltool ===="
# TODO improve for NCBI
echo "Submitting dRep"
bash ${MAIN_PATH}/cluster/codon/execute/steps/1_drep.sh \
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
    -j ${STEP1} \
    -z ${MEM_STEP1} \
    -t ${THREADS_STEP1}

echo "==== waiting for drep.... ===="
mwait.py -w "ended(${STEP1}.${NAME})"

# ------------------------- Step 2 ------------------------------
echo "==== 2. Run mash2nwk ===="
echo "Submitting mash"
bsub \
     -J "${STEP2}.${NAME}.submit" \
     -w "ended(${STEP1}.${NAME})" \
     -q ${QUEUE} \
     -e ${LOGS}/submit."${STEP2}".err \
     -o ${LOGS}/submit."${STEP2}".out \
     bash ${MAIN_PATH}/cluster/codon/execute/steps/2_mash.sh \
        -m ${OUT}/${NAME}_drep/mash \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML} \
        -j ${STEP2} \
        -z ${MEM_STEP2} \
        -t ${THREADS_STEP2}

# ------------------------- Step 3 ------------------------------
mkdir -p ${OUT}/sg ${OUT}/pg
echo "==== 3. Run cluster annotation ===="

echo "Submitting singletons"
bsub \
    -J "${STEP3}.${NAME}.sg" \
    -w "ended(${STEP1}.${NAME})" \
    -q ${QUEUE} \
    -e ${LOGS}/submit."${STEP3}".sg.err \
    -o ${LOGS}/submit."${STEP3}".sg.out \
    bash ${MAIN_PATH}/cluster/codon/execute/steps/3_process_clusters.sh \
        -i ${OUT}/${NAME}_drep/singletons \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -t 'sg' \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML} \
        -j ${STEP3} \
        -s "${ENA_CSV}" \
        -z ${MEM_STEP3} \
        -w ${THREADS_STEP3}

echo "==== waiting for mash2nwk.... ===="
mwait.py -w "ended(${STEP2}.${NAME}.*)"

echo "Submitting pan-genomes"
bsub \
    -J "${STEP3}.${NAME}.pg" \
    -w "ended(${STEP2}.${NAME}.*)" \
    -q ${QUEUE} \
    -e ${LOGS}/submit."${STEP3}".pg.err \
    -o ${LOGS}/submit."${STEP3}".pg.out \
    bash ${MAIN_PATH}/cluster/codon/execute/steps/3_process_clusters.sh \
        -i ${OUT}/${NAME}_drep/pan-genomes \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -t 'pg' \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML} \
        -j ${STEP3} \
        -s "${ENA_CSV}" \
        -z ${MEM_STEP3} \
        -w ${THREADS_STEP3}

# ------------------------- Step 4 ------------------------------
echo "==== waiting for cluster annotations.... ===="
mwait.py -w "ended(${STEP3}.${NAME}.*)"

echo "==== 4. Run mmseqs ===="
# TODO improve for no sg or pg
bsub \
    -J "${STEP4}.${NAME}.submit" \
    -w "ended(${STEP3}.${NAME}.*)" \
    -q ${QUEUE} \
    -e ${LOGS}/submit."${STEP4}".err \
    -o ${LOGS}/submit."${STEP4}".out \
    bash ${MAIN_PATH}/cluster/codon/execute/steps/4_mmseqs.sh \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML} \
        -j ${STEP4} \
        -r ${REPS_FILE} \
        -f ${ALL_GENOMES} \
        -a ${REPS_FA_DIR} \
        -k ${ALL_FNA_DIR} \
        -d ${OUT}/${NAME}_drep \
        -z ${MEM_STEP4} \
        -t ${THREADS_STEP4}

# ------------------------- Step 5 ------------------------------
echo "==== waiting for files/folders generation.... ===="
mwait.py -w "ended(${STEP4}.${NAME}.submit)"
mwait.py -w "ended(${STEP4}.${NAME}.files)"

echo "==== 5. Run GTDB-Tk ===="
# TODO change queue to BIGMEM in production
echo "Submitting GTDB-Tk"
bsub \
    -J "${STEP5}.${NAME}.submit" \
    -q ${QUEUE} \
    -o ${LOGS}/submit."${STEP5}".out \
    -e ${LOGS}/submit."${STEP5}".err \
    bash ${MAIN_PATH}/cluster/codon/execute/steps/5_sing_gtdbtk.sh \
        -q ${BIGQUEUE} \
        -p ${MAIN_PATH} \
        -o ${OUT} \
        -l ${LOGS} \
        -n ${NAME} \
        -y ${YML} \
        -j ${STEP5} \
        -a ${REPS_FA_DIR} \
        -z ${MEM_STEP5} \
        -t ${THREADS_STEP5}

mwait.py -w "ended(${STEP4}.${NAME}.cat) && ended(${STEP4}.${NAME}.yml.*)"

# ------------------------- Step 6 ------------------------------
echo "==== waiting for mmseqs 0.9.... ===="
mwait.py -w "ended(${STEP4}.${NAME}.0.90)"

echo "==== 6. EggNOG, IPS, rRNA ===="
echo "Submitting annotation"
bsub \
    -J "${STEP6}.${NAME}.submit" \
    -q ${QUEUE} \
    -e ${LOGS}/submit."${STEP6}".err \
    -o ${LOGS}/submit."${STEP6}".out \
    bash ${MAIN_PATH}/cluster/codon/execute/steps/6_annotation.sh \
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
        -w "True"

# ------------------------- Step 7 ------------------------------
echo "==== waiting for GTDB-Tk.... ===="
mwait.py -w "ended(${STEP5}.${NAME}.submit) && ended(${STEP6}.${NAME}.submit)"
mwait.py -w "ended(${STEP5}.${NAME}.run) && ended(${STEP6}.${NAME}.run)"

echo "==== 7. Metadata and phylo.tree ===="
echo "Submitting metadata and phylo.tree generation"
bsub \
    -J "${STEP7}.${NAME}.submit" \
    -q ${QUEUE} \
    -e ${LOGS}/submit."${STEP7}".err \
    -o ${LOGS}/submit."${STEP7}".out \
    bash ${MAIN_PATH}/cluster/codon/execute/steps/7_metadata.sh \
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
mwait.py -w "ended(${STEP6}.${NAME}.submit) && ended(${STEP7}.${NAME}.submit)"
mwait.py -w "ended(${STEP6}.${NAME}.run) && ended(${STEP7}.${NAME}.run)"

echo "==== 8. Post-processing ===="
echo "Submitting post-processing"
bsub \
    -J "${STEP8}.${NAME}.submit" \
    -q ${QUEUE} \
    -e ${LOGS}/submit."${STEP8}".err \
    -o ${LOGS}/submit."${STEP8}".out \
    bash ${MAIN_PATH}/cluster/codon/execute/steps/8_post_processing.sh \
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

# ------------------------- Step 9 ------------------------------
echo "==== waiting for post-processing ===="
mwait.py -w "ended(${STEP8}.${NAME}.submit)"
mwait.py -w "ended(${STEP8}.${NAME}.run)"

echo "==== 9. Re-structure ===="
echo "Running restructure"
bsub \
    -J "${STEP9}.${NAME}.submit" \
    -q ${QUEUE} \
    -e ${LOGS}/submit."${STEP9}".err \
    -o ${LOGS}/submit."${STEP9}".out \
    bash ${MAIN_PATH}/cluster/codon/execute/steps/9_restructure.sh \
        -o ${OUT} \
        -n ${NAME}

echo "==== Final. Exit ===="