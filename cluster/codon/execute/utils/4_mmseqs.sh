#!/bin/bash

MMSEQS_LIMIT_I=(1.0 0.95 0.90 0.50)
MMSEQS_LIMIT_C=0.8

while getopts :o:p:l:n:q:y:i:r:f:j:c:a:b: option; do
	case "${option}" in
		o) OUT=${OPTARG};;
		p) P=${OPTARG};;
		l) LOGS=${OPTARG};;
		n) DIRNAME=${OPTARG};;
		q) QUEUE=${OPTARG};;
		y) YML=${OPTARG};;
		r) REPS=${OPTARG};;
		f) ALL_GENOMES=${OPTARG};;
		j) JOB=${OPTARG};;
		c) CONDITION_JOB=${OPTARG};;
		a) REPS_FA=${OPTARG};;
		b) ALL_FNA=${OPTARG};;
	esac
done

echo "Create files and folders with reps"
bsub \
     -J "${JOB}.${DIRNAME}.files" \
     -w "ended(${CONDITION_JOB}.${DIRNAME}.*)" \
     -q "${QUEUE}" \
     -e "${LOGS}"/create_files.err \
     -o "${LOGS}"/create_files.out \
     bash ${P}/cluster/codon/execute/utils/4_create_files.sh \
        -o ${OUT} \
        -r ${REPS} \
        -f ${ALL_GENOMES} \
        -a ${REPS_FA} \
        -n ${ALL_FNA} \
        -d ${OUT}/${DIRNAME}_drep

echo "Concatenate prokka.faa-s"
bsub \
    -J "${JOB}.${DIRNAME}.cat" \
    -w "ended(${JOB}.${DIRNAME}.files)" \
    -q "${QUEUE}" \
    -e "${LOGS}"/cat.err \
    -o "${LOGS}"/cat.out \
    "cat ${OUT}/pg/MGYG*_cluster/MGYG*.faa ${OUT}/pg/MGYG*_cluster/MGYG*/MGYG*.faa ${OUT}/sg/MGYG*_cluster/MGYG*/MGYG*.faa > ${OUT}/prokka.cat.faa"

echo "Prepare yml for mmseqs"
for i in ${MMSEQS_LIMIT_I[@]}; do
    bsub \
        -J "${JOB}.${DIRNAME}.yml.${i}" \
        -w "ended(${JOB}.${DIRNAME}.cat)" \
        -q "${QUEUE}" \
        -e "${LOGS}"/mmseqs.yml.err \
        -o "${LOGS}"/mmseqs.yml.out \
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
        -e "${LOGS}"/mmseqs."${i}".err \
        -o "${LOGS}"/mmseqs."${i}".out \
        bash "${P}"/cluster/codon/run-cwltool.sh \
            -d False \
            -p "${P}" \
            -o "${OUT}" \
            -n "${DIRNAME}_mmseqs_${i}" \
            -c "${P}"/cwl/tools/mmseqs/mmseqs.cwl \
            -y "${YML}"/"${i}".mmseqs.yml
done