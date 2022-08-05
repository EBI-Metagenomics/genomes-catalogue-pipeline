#!/bin/bash

DEFAULT_QUEUE="standard"
BIGQUEUE="bigmem"

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

# ------------------------- Step 1-2 ------------------------------
echo "==== 1-2. Run preparation and dRep steps with cwltool ===="
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
    -x ${MIN_MGYG}
sleep 5
# ------------------------- Step 3 ------------------------------
echo "==== 3. Run mash2nwk ===="
echo "Submitting mash"
bsub -w "ended(Step2.drep*${NAME})" \
     -J "Step3.mash.submit.${NAME}" \
     -q ${QUEUE} \
     -e ${LOGS}/mash.err \
     -o ${LOGS}/mash.out \
     bash ${MAIN_PATH}/cluster/codon/execute/utils/3_mash.sh \
        -m ${OUT}/${NAME}_drep/mash \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE}

# ------------------------- Step 4 ------------------------------
mkdir -p ${OUT}/sg ${OUT}/pg
echo "==== 4. Run cluster annotation ===="
echo "Submitting pan-genomes"
bsub \
    -J "Step4.1.pg.${NAME}" \
    -w "ended(Step3.mash.*${NAME})" \
    -q ${QUEUE} \
    -e ${LOGS}/pg.err \
    -o ${LOGS}/pg.out \
    bash ${MAIN_PATH}/cluster/codon/execute/utils/4_process_clusters.sh \
        -i ${OUT}/${NAME}_drep/pan-genomes \
        -o ${OUT}/pg \
        -p ${MAIN_PATH} \
        -t 'pg' \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML}

echo "Submitting singletons"
bsub \
    -J "Step4.2.sg.${NAME}" \
    -w "ended(Step2.drep*${NAME})" \
    -q ${QUEUE} \
    -e ${LOGS}/sg.err \
    -o ${LOGS}/sg.out \
    bash ${MAIN_PATH}/cluster/codon/execute/utils/4_process_clusters.sh \
        -i ${OUT}/${NAME}_drep/singletons \
        -o ${OUT}/sg \
        -p ${MAIN_PATH} \
        -t 'sg' \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE}

# ------------------------- Step 5 ------------------------------
echo "==== 5. Run mmseqs ===="
# TODO improve for no sg or pg
bsub \
    -J "Step5.mmseqs.submit.${NAME}" \
    -w "ended(Step4*${NAME})" \
    -q ${QUEUE} \
    -e ${LOGS}/mmseq.submit.err \
    -o ${LOGS}/mmseq.submit.out \
    bash ${MAIN_PATH}/cluster/codon/execute/utils/5_mmseqs.sh \
        -o ${OUT} \
        -p ${MAIN_PATH} \
        -l ${LOGS} \
        -n ${NAME} \
        -q ${QUEUE} \
        -y ${YML} \
        -r ${REPS_FILE} \
        -f ${ALL_GENOMES}

# ------------------------- Step 6 ------------------------------

echo "==== 6. Run GTDB-Tk ===="
echo "Submitting GTDB-Tk"
bsub \
    -w "ended(Step5.mmseqs.submit.${NAME})" \
    -J "Step6.gtdbtk.submit.${NAME}" \
    -q ${QUEUE} \
    -o ${LOGS}/gtdbtk.submit.out \
    -e ${LOGS}/gtdbtk.submit.err \
    bash ${MAIN_PATH}/cluster/codon/execute/utils/6_gtdbtk.sh \
        -q ${QUEUE} \
        -p ${MAIN_PATH} \
        -o ${OUT} \
        -l ${LOGS} \
        -n ${NAME} \
        -y ${YML} \
        -r ${REPS_FILE}

# ------------------------- Step 7 ------------------------------
echo "==== 7. EggNOG, IPS, rRNA ===="
#echo "Submitting annotation"
#echo bsub \
#    -J "Step7.annotation.submit.${NAME}" \
#    -w "ended(Step5*${NAME})" \
#    -q ${QUEUE} \
#    -e ${LOGS}/annotation.submit.err \
#    -o ${LOGS}/annotation.submit.out \
#    bash ${MAIN_PATH}/cluster/codon/execute/utils/7_annotation.sh \
#        -o ${OUT} \
#        -p ${MAIN_PATH} \
#        -l ${LOGS} \
#        -n ${NAME} \
#        -q ${QUEUE} \
#        -y ${YML} \
#        -i ${OUT}/${NAME}_mmseqs \
#        -r ${REPS_FILE}

# ------------------------- Step 8 ------------------------------
echo "==== 8. Metadata and phylo.tree ===="

# ------------------------- Step 9 ------------------------------
echo "==== 9. Post-processing ===="