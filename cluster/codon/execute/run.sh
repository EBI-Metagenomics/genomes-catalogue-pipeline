#!/bin/bash

set -e

DEFAULT_QUEUE="standard"
BIGQUEUE="bigmem"
RUN=0

STEP1="Step1.drep"
STEP2="Step2.mash"
STEP3="Step3.clusters"
STEP4="Step4.mmseqs"
STEP5="Step5.gtdbtk"
STEP6="Step6.annotation"
STEP6a="Step6a.emerald"
STEP7="Step7.metadata"
STEP8="Step8.postprocessing"
STEP9="Step9.restructure"

MEM_STEP1="50G"
MEM_STEP2="10G"
MEM_STEP3="50G"
MEM_STEP4="150G"
MEM_STEP5="500G"
MEM_STEP6="50G"
MEM_STEP6a="5G"
MEM_STEP7="5G"
MEM_STEP8="5G"

THREADS_STEP1="16"
THREADS_STEP2="4"
THREADS_STEP3="8"
THREADS_STEP4="32"
THREADS_STEP5="2"
THREADS_STEP6="16"
THREADS_STEP6a="1"
THREADS_STEP7="1"
THREADS_STEP8="1"

usage() {
    cat <<EOF
usage: $0 options
Generate the genomes-pipeline bsub submission scripts.
The generated scripts will run the pipeline step by step using cwltool / toil.
Use the -r option to generate and run the scripts (using bwait between steps).

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
   -r      Run the generated bsub scripts
EOF
}

while getopts "h:p:n:f:c:m:x:v:b:o:q:r" OPTION; do
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
    r)
        RUN=1
        ;;
    ?)
        usage
        exit 1
        ;;
    esac
done

if [[ -z ${MAIN_PATH} ]]; then
    MAIN_PATH="/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/"
fi

if [[ -z ${NAME} ]]; then
    NAME="test"
fi

if [[ -z ${OUTPUT} ]]; then
    OUTPUT=${MAIN_PATH}
fi

if [[ -z ${CATALOGUE_VERSION} ]]; then
    CATALOGUE_VERSION="v1.0"
fi

if [[ -z ${QUEUE} ]]; then
    QUEUE=${DEFAULT_QUEUE}
fi

OUT=${OUTPUT}/${NAME}
LOGS=${OUT}/logs/
YML=${OUT}/ymls
SUBMIT_SCRIPTS=${OUT}/scripts
mkdir -p ${OUT} ${LOGS} ${YML} ${SUBMIT_SCRIPTS}

REPS_FILE=${OUT}/cluster_reps.txt
ALL_GENOMES=${OUT}/drep-filt-list.txt
touch ${REPS_FILE} ${ALL_GENOMES}

REPS_FA_DIR=${OUT}/reps_fa
ALL_FNA_DIR=${OUT}/mgyg_genomes

MEM="10G"
THREADS="2"

export PATH="${MAIN_PATH}/cluster/codon/execute/scripts:$PATH"

# ------------------------- Step 1 -------------------------------------------------
echo "==== 1. dRep steps with cwltool [step1.${NAME}.sh] ===="

# TODO improve for NCBI
cat <<EOF >${SUBMIT_SCRIPTS}/step1.${NAME}.sh
#!/bin/bash

bash ${MAIN_PATH}/cluster/codon/execute/steps/1_drep.sh \\
    -o ${OUT} \\
    -p ${MAIN_PATH} \\
    -l ${LOGS} \\
    -n ${NAME} \\
    -q ${QUEUE} \\
    -y ${YML} \\
    -i "${ENA_GENOMES}" \\
    -c "${ENA_CSV}" \\
    -m "${MAX_MGYG}" \\
    -x "${MIN_MGYG}" \\
    -j ${STEP1} \\
    -z ${MEM_STEP1} \\
    -t ${THREADS_STEP1}
EOF

if [[ $RUN == 1 ]]; then
    echo "Running dRep [${SUBMIT_SCRIPTS}/step1.${NAME}.sh]"
    bash ${SUBMIT_SCRIPTS}/step1.${NAME}.sh
    sleep 10 # let's give LSF time to catch up
    mwait.py -w "ended(${STEP1}.${NAME})"
fi

# ------------------------- Step 2 ------------------------------------
echo "==== 2. mash2nwk submission script [${SUBMIT_SCRIPTS}/step2.${NAME}.sh] ===="

cat <<EOF >${SUBMIT_SCRIPTS}/step2.${NAME}.sh
#!/bin/bash

bsub \\
    -J "${STEP2}.${NAME}.submit" \\
    -q ${QUEUE} \\
    -e ${LOGS}/submit.${STEP2}.err \\
    -o ${LOGS}/submit.${STEP2}.out \\
    bash ${MAIN_PATH}/cluster/codon/execute/steps/2_mash.sh \\
        -m ${OUT}/${NAME}_drep/mash \\
        -o ${OUT} \\
        -p ${MAIN_PATH} \\
        -l ${LOGS} \\
        -n ${NAME} \\
        -q ${QUEUE} \\
        -y ${YML} \\
        -j ${STEP2} \\
        -z ${MEM_STEP2} \\
        -t ${THREADS_STEP2}
EOF

if [[ $RUN == 1 ]]; then
    echo "Running mash2nwk ${SUBMIT_SCRIPTS}/step2.${NAME}.sh"
    bash ${SUBMIT_SCRIPTS}/step2.${NAME}.sh
fi

# ------------------------- Step 3 ------------------------------
mkdir -p ${OUT}/sg ${OUT}/pg
echo "==== 3. Cluster annotation [${SUBMIT_SCRIPTS}/step3.${NAME}.sh] ===="

cat <<EOF >${SUBMIT_SCRIPTS}/step3.${NAME}.sh
#!/bin/bash

bsub \\
    -J "${STEP3}.${NAME}.sg" \\
    -q ${QUEUE} \\
    -e ${LOGS}/submit.${STEP3}.sg.err \\
    -o ${LOGS}/submit.${STEP3}.sg.out \\
    bash ${MAIN_PATH}/cluster/codon/execute/steps/3_process_clusters.sh \\
        -i ${OUT}/${NAME}_drep/singletons \\
        -o ${OUT} \\
        -p ${MAIN_PATH} \\
        -t "sg" \\
        -l ${LOGS} \\
        -n ${NAME} \\
        -q ${QUEUE} \\
        -y ${YML} \\
        -j ${STEP3} \\
        -s "${ENA_CSV}" \\
        -z ${MEM_STEP3} \\
        -w ${THREADS_STEP3}

bsub \\
    -J "${STEP3}.${NAME}.pg" \\
    -q ${QUEUE} \\
    -e ${LOGS}/submit.${STEP3}.pg.err \\
    -o ${LOGS}/submit.${STEP3}.pg.out \\
    bash ${MAIN_PATH}/cluster/codon/execute/steps/3_process_clusters.sh \\
        -i ${OUT}/${NAME}_drep/pan-genomes \\
        -o ${OUT} \\
        -p ${MAIN_PATH} \\
        -t "pg" \\
        -l ${LOGS} \\
        -n ${NAME} \\
        -q ${QUEUE} \\
        -y ${YML} \\
        -j ${STEP3} \\
        -s "${ENA_CSV}" \\
        -z ${MEM_STEP3} \\
        -w ${THREADS_STEP3}
EOF

if [[ $RUN == 1 ]]; then
    echo "==== Running step 3 ===="
    mwait.py -w "ended(${STEP2}.${NAME}.*)"
    echo "Running Cluster annotation [${SUBMIT_SCRIPTS}/step3.${NAME}.sh]"
    bash ${SUBMIT_SCRIPTS}/step3.${NAME}.sh
fi

# ------------------------- Step 4 ------------------------------

echo "==== 4. mmseqs [${SUBMIT_SCRIPTS}/step4.${NAME}.sh] ===="
# TODO improve for no sg or pg
cat <<EOF >${SUBMIT_SCRIPTS}/step4.${NAME}.sh
#!/bin/bash

bsub \\
    -J "${STEP4}.${NAME}.submit" \\
    -q ${QUEUE} \\
    -e ${LOGS}/submit.${STEP4}.err \\
    -o ${LOGS}/submit.${STEP4}.out \\
    bash ${MAIN_PATH}/cluster/codon/execute/steps/4_mmseqs.sh \\
        -o ${OUT} \\
        -p ${MAIN_PATH} \\
        -l ${LOGS} \\
        -n ${NAME} \\
        -q ${QUEUE} \\
        -y ${YML} \\
        -j ${STEP4} \\
        -r ${REPS_FILE} \\
        -f ${ALL_GENOMES} \\
        -a ${REPS_FA_DIR} \\
        -k ${ALL_FNA_DIR} \\
        -d ${OUT}/${NAME}_drep \\
        -z ${MEM_STEP4} \\
        -t ${THREADS_STEP4}
EOF

if [[ $RUN == 1 ]]; then
    echo "==== Running step 4 [${SUBMIT_SCRIPTS}/step4.${NAME}.sh] ===="
    echo "===== waiting for cluster annotations (step3).... ===="
    mwait.py -w "ended(${STEP3}.${NAME}.*)"
    bash ${SUBMIT_SCRIPTS}/step4.${NAME}.sh
fi

# ------------------------- Step 5 ------------------------------
echo "==== 5. GTDB-Tk [${SUBMIT_SCRIPTS}/step5.${NAME}.sh] ===="

if [[ $RUN == 1 ]]; then
    echo "==== waiting for files/folders generation.... ===="
    mwait.py -w "ended(${STEP4}.${NAME}.submit)"
    mwait.py -w "ended(${STEP4}.${NAME}.files)"
fi

# TODO change queue to BIGMEM in production
cat <<EOF >${SUBMIT_SCRIPTS}/step5.${NAME}.sh
#!/bin/bash

bsub \\
    -J "${STEP5}.${NAME}.submit" \\
    -q ${QUEUE} \\
    -o ${LOGS}/submit.${STEP5}.out \\
    -e ${LOGS}/submit.${STEP5}.err \\
    bash ${MAIN_PATH}/cluster/codon/execute/steps/5_sing_gtdbtk.sh \\
        -q ${BIGQUEUE} \\
        -p ${MAIN_PATH} \\
        -o ${OUT} \\
        -l ${LOGS} \\
        -n ${NAME} \\
        -y ${YML} \\
        -j ${STEP5} \\
        -a ${REPS_FA_DIR} \\
        -z ${MEM_STEP5} \\
        -t ${THREADS_STEP5}

EOF

if [[ $RUN == 1 ]]; then
    echo "==== Running step 5 [${SUBMIT_SCRIPTS}/step5.${NAME}.sh] ===="
    bash ${SUBMIT_SCRIPTS}/step5.${NAME}.sh
    mwait.py -w "ended(${STEP4}.${NAME}.cat) && ended(${STEP4}.${NAME}.yml.*)"
fi

# ------------------------- Step 6 ------------------------------
if [[ $RUN == 1 ]]; then
    echo "==== waiting for mmseqs 0.9.... ===="
    mwait.py -w "ended(${STEP4}.${NAME}.0.90)"
fi

echo "==== 6. EggNOG, IPS, rRNA [${SUBMIT_SCRIPTS}/step6.${NAME}.sh] ===="

cat <<EOF >${SUBMIT_SCRIPTS}/step6.${NAME}.sh
#!/bin/bash

bsub \\
    -J "${STEP6}.${NAME}.submit" \\
    -q ${QUEUE} \\
    -e ${LOGS}/submit.${STEP6}.err \\
    -o ${LOGS}/submit.${STEP6}.out \\
    bash ${MAIN_PATH}/cluster/codon/execute/steps/6_annotation.sh \\
        -o ${OUT} \\
        -p ${MAIN_PATH} \\
        -l ${LOGS} \\
        -n ${NAME} \\
        -q ${QUEUE} \\
        -y ${YML} \\
        -i ${OUT}/${NAME}_mmseqs_0.90/mmseqs_0.9_outdir \\
        -r ${REPS_FILE} \\
        -j ${STEP6} \\
        -b ${ALL_FNA_DIR} \\
        -z ${MEM_STEP6} \\
        -t ${THREADS_STEP6} \\
        -w "True"
EOF

if [[ $RUN == 1 ]]; then
    echo "==== Running step 6 [${SUBMIT_SCRIPTS}/step6.${NAME}.sh] ===="
fi

# ------------------------- Step 6a ------------------------------
echo "==== 6a. Emerald [${SUBMIT_SCRIPTS}/step6a.${NAME}.sh] ===="

cat <<EOF >${SUBMIT_SCRIPTS}/step6a.${NAME}.sh
#!/bin/bash

bsub \\
    -J "${STEP6a}.${NAME}.submit" \\
    -q ${QUEUE} \\
    -e ${LOGS}/submit.${STEP6a}.err \\
    -o ${LOGS}/submit.${STEP6a}.out \\
    bash ${MAIN_PATH}/cluster/codon/execute/steps/6a_run_emerald.sh \\
    -o ${OUT} \\
    -l ${LOGS} \\
    -n ${NAME} \\
    -q ${QUEUE} \\
    -j ${STEP6a} \\
    -z ${MEM_STEP6a} \\
    -t ${THREADS_STEP6a} \\

EOF

# ------------------------- Step 7 ------------------------------
if [[ $RUN == 1 ]]; then
    echo "==== waiting for GTDB-Tk.... ===="
    mwait.py -w "ended(${STEP5}.${NAME}.submit) && ended(${STEP6}.${NAME}.submit)"
    mwait.py -w "ended(${STEP5}.${NAME}.run) && ended(${STEP6}.${NAME}.run)"
fi

echo "==== 7. Metadata and phylo.tree [${SUBMIT_SCRIPTS}/step7.${NAME}.sh] ===="

cat <<EOF >${SUBMIT_SCRIPTS}/step7.${NAME}.sh
#!/bin/bash

bsub \\
    -J "${STEP7}.${NAME}.submit" \\
    -q ${QUEUE} \\
    -e ${LOGS}/submit.${STEP7}.err \\
    -o ${LOGS}/submit.${STEP7}.out \\
    bash ${MAIN_PATH}/cluster/codon/execute/steps/7_metadata.sh \\
        -o ${OUT} \\
        -p ${MAIN_PATH} \\
        -l ${LOGS} \\
        -n ${NAME} \\
        -q ${QUEUE} \\
        -y ${YML} \\
        -v ${CATALOGUE_VERSION} \\
        -i ${OUT}/${NAME}_drep/intermediate_files \\
        -g ${OUT}/gtdbtk/gtdbtk-outdir \\
        -r ${OUT}/${NAME}_annotations/rRNA_outs \\
        -j ${STEP7} \\
        -f ${ALL_FNA_DIR} \\
        -s "${ENA_CSV}" \\
        -z ${MEM_STEP7} \\
        -t ${THREADS_STEP7}
EOF

if [[ $RUN == 1 ]]; then
    echo "==== Running step 7 [${SUBMIT_SCRIPTS}/step7.${NAME}.sh] ===="
    bash ${SUBMIT_SCRIPTS}/step7.${NAME}.sh
    sleep 10
    echo "==== waiting for metadata and protein annotations.... ===="
    mwait.py -w "ended(${STEP6}.${NAME}.submit) && ended(${STEP7}.${NAME}.submit)"
    mwait.py -w "ended(${STEP6}.${NAME}.run) && ended(${STEP7}.${NAME}.run)"
fi

# ------------------------- Step 8 ------------------------------
echo "==== 8. Post-processing [${SUBMIT_SCRIPTS}/step8.${NAME}.sh] ===="

cat <<EOF >${SUBMIT_SCRIPTS}/step8.${NAME}.sh
#!/bin/bash

bsub \\
    -J "${STEP8}.${NAME}.submit" \\
    -q ${QUEUE} \\
    -e ${LOGS}/submit.${STEP8}.err \\
    -o ${LOGS}/submit.${STEP8}.out \\
    bash ${MAIN_PATH}/cluster/codon/execute/steps/8_post_processing.sh \\
        -o ${OUT} \\
        -p ${MAIN_PATH} \\
        -l ${LOGS} \\
        -n ${NAME} \\
        -q ${QUEUE} \\
        -y ${YML} \\
        -j ${STEP8} \\
        -b "${BIOM}" \\
        -m ${OUT}/${NAME}_metadata/genomes-all_metadata.tsv \\
        -a ${OUT}/${NAME}_annotations \\
        -z ${MEM_STEP8} \\
        -t ${THREADS_STEP8}
EOF

if [[ $RUN == 1 ]]; then
    echo "==== Running step 8 [${SUBMIT_SCRIPTS}/step8.${NAME}.sh] ===="
    bash ${SUBMIT_SCRIPTS}/step8.${NAME}.sh
    sleep 10
    echo "==== waiting for post-processing ===="
    mwait.py -w "ended(${STEP8}.${NAME}.submit)"
    mwait.py -w "ended(${STEP8}.${NAME}.run)"
fi

# ------------------------- Step 9 ------------------------------

echo "==== 9. Re-structure [${SUBMIT_SCRIPTS}/step9.${NAME}.sh] ===="

cat <<EOF >${SUBMIT_SCRIPTS}/step8.${NAME}.sh
#!/bin/bash

bsub \\
    -J "${STEP9}.${NAME}.submit" \\
    -q ${QUEUE} \\
    -e ${LOGS}/submit.${STEP9}.err \\
    -o ${LOGS}/submit.${STEP9}.out \\
    bash ${MAIN_PATH}/cluster/codon/execute/steps/9_restructure.sh \\
        -o ${OUT} \\
        -n ${NAME}
EOF

if [[ $RUN == 1 ]]; then
    echo "==== Running step 9 [${SUBMIT_SCRIPTS}/step9.${NAME}.sh] ===="
    bash ${SUBMIT_SCRIPTS}/step9.${NAME}.sh
    sleep 10
fi

echo "==== Final. Exit ===="
