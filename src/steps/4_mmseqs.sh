#!/bin/bash

MMSEQS_LIMIT_I=(1.0 0.95 0.90 0.50)
MMSEQS_LIMIT_C=0.8

usage() {
    cat <<EOF
usage: $0 options
Run genomes-pipeline mmseqs annotations
OPTIONS:
   -o      Path to general output catalogue directory
   -p      Path to installed pipeline location
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -y      Path to folder to save yml file
   -j      LSF step Job name to submit
   -r      Path to file with cluster representatives (filtered after GUNC)
   -f      Path to file with all genomes (filtered after GUNC)
   -a      Path to folder with fasta.fna representatives (filtered after GUNC)
   -k      Path to folder with all fasta.fna (filtered after GUNC)
   -d      Path to dRep output folder
   -z      memory to execute
   -t      number of threads
EOF
}

while getopts ho:p:l:n:q:y:j:r:f:a:k:d:z:t: option; do
    case "${option}" in
    h)
        usage
        exit 1
        ;;
    o)
        OUT=${OPTARG}
        ;;
    p)
        PIPELINE_DIRECTORY=${OPTARG}
        ;;
    l)
        LOGS=${OPTARG}
        ;;
    n)
        DIRNAME=${OPTARG}
        ;;
    q)
        QUEUE=${OPTARG}
        ;;
    y)
        YML=${OPTARG}
        ;;
    j)
        JOB=${OPTARG}
        ;;
    r)
        REPS=${OPTARG}
        ;;
    f)
        ALL_GENOMES=${OPTARG}
        ;;
    a)
        REPS_FA=${OPTARG}
        ;;
    k)
        ALL_FNA=${OPTARG}
        ;;
    d)
        DREP_DIR=${OPTARG}
        ;;
    z)
        MEM=${OPTARG}
        ;;
    t)
        THREADS=${OPTARG}
        ;;
    ?)
        usage
        exit
        ;;
    esac
done

echo "Create files and folders with fna-reps"
bsub \
    -J "${JOB}.${DIRNAME}.files" \
    -q "${QUEUE}" \
    -e "${LOGS}"/"${JOB}".files.err \
    -o "${LOGS}"/"${JOB}".files.out \
    bash "${PIPELINE_DIRECTORY}"/src/steps/4_create_files.sh \
        -o "${OUT}" \
        -r "${REPS}" \
        -f "${ALL_GENOMES}" \
        -a "${REPS_FA}" \
        -n "${ALL_FNA}" \
        -d "${DREP_DIR}"

echo "Concatenate prokka.faa-s"
bsub \
    -J "${JOB}.${DIRNAME}.cat" \
    -w "ended(${JOB}.${DIRNAME}.files)" \
    -q "${QUEUE}" \
    -e "${LOGS}"/"${JOB}".cat.err \
    -o "${LOGS}"/"${JOB}".cat.out \
    "cat ${OUT}/pg/MGYG*_cluster/MGYG*.faa ${OUT}/pg/MGYG*_cluster/MGYG*/MGYG*.faa ${OUT}/sg/MGYG*_cluster/MGYG*/MGYG*.faa > ${OUT}/prokka.cat.faa"

echo "Prepare yml for mmseqs"
for i in ${MMSEQS_LIMIT_I[@]}; do
    bsub \
        -J "${JOB}.${DIRNAME}.yml.${i}" \
        -w "ended(${JOB}.${DIRNAME}.cat)" \
        -q "${QUEUE}" \
        -e "${LOGS}"/"${JOB}".mmseqs.yml.err \
        -o "${LOGS}"/"${JOB}".mmseqs.yml.out \
        "echo \
        '
input_fasta:
  class: File
  path: ${OUT}/prokka.cat.faa
limit_i: ${i}
limit_c: ${MMSEQS_LIMIT_C}
        ' > ${YML}/${i}.mmseqs.yml"
done

echo "Submitting mmseqs"
for i in ${MMSEQS_LIMIT_I[@]}; do
    bsub \
        -J "${JOB}.${DIRNAME}.${i}" \
        -w "ended(${JOB}.${DIRNAME}.yml.*)" \
        -q "${QUEUE}" \
        -e "${LOGS}"/"${JOB}"."${i}".err \
        -o "${LOGS}"/"${JOB}"."${i}".out \
        -M "${MEM}" \
        -n "${THREADS}" \
        bash "${PIPELINE_DIRECTORY}"/bin/run-cwltool.sh \
            -d False \
            -p "${PIPELINE_DIRECTORY}" \
            -o "${OUT}" \
            -n "${DIRNAME}_mmseqs_${i}" \
            -c "${PIPELINE_DIRECTORY}"/src/cwl/tools/mmseqs/mmseqs.cwl \
            -y "${YML}"/"${i}".mmseqs.yml
done
