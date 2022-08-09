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

# ------------------------- Step 4 ------------------------------
echo "==== 4. Run mmseqs ===="
# TODO improve for no sg or pg
bsub \
    -J "${STEP4}.${NAME}.submit" \
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
        -c ${STEP3}

# ------------------------- Step 5 ------------------------------

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
        -c ${STEP3}

# ------------------------- Step 6 ------------------------------
echo "==== 6. EggNOG, IPS, rRNA ===="

# ------------------------- Step 7 ------------------------------
echo "==== 7. Metadata and phylo.tree ===="

# ------------------------- Step 8 ------------------------------
echo "==== 8. Post-processing ===="