#!/bin/bash

MMSEQS_LIMIT_I=(1.0 0.95 0.90 0.50)
MMSEQS_LIMIT_C=0.8

while getopts :o:p:l:n:q:y:i:r:f:j: option; do
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
	esac
done

echo "Create file with all filtered genomes"
touch ${ALL_GENOMES}.sg.tmp ${ALL_GENOMES}.pg.tmp

ls ${OUT}/sg | tr '_' '\t' | cut -f1 >> ${ALL_GENOMES}.sg

for i in $(ls ${OUT}/pg); do
    echo ${i} >> ${ALL_GENOMES}.pg.tmp
    ls ${OUT}/pg/${i} | grep '.gff' | tr '.' '\t' | cut -f1 >> ${ALL_GENOMES}.pg.tmp
done

cat ${ALL_GENOMES}.pg.tmp | tr '_' '\t' | cut -f1 > ${ALL_GENOMES}.pg
rm ${ALL_GENOMES}.pg.tmp
cat ${ALL_GENOMES}.pg > ${ALL_GENOMES}
cat ${ALL_GENOMES}.sg.tmp | tr '_' '\t' | cut -f1 > ${ALL_GENOMES}.sg
rm ${ALL_GENOMES}.sg.tmp
cat ${ALL_GENOMES}.sg >> ${ALL_GENOMES}

echo "Create file with cluster reps filtered genomes"
ls ${OUT}/sg | tr '_' '\t' | cut -f1 > ${REPS}
ls ${OUT}/pg | tr '_' '\t' | cut -f1 >> ${REPS}

echo "Concatenate prokka.faa-s"
bsub \
    -J "${JOB}.cat.${DIRNAME}" \
    -q ${QUEUE} \
    -e ${LOGS}/cat.err \
    -o ${LOGS}/cat.out \
    "cat ${OUT}/pg/MGYG*_cluster/MGYG*.faa ${OUT}/pg/MGYG*_cluster/MGYG*/MGYG*.faa ${OUT}/sg/MGYG*_cluster/MGYG*/MGYG*.faa > ${OUT}/prokka.cat.faa"

echo "Prepare yml for mmseqs"
for i in ${MMSEQS_LIMIT_I[@]}; do
    bsub \
        -J "${JOB}.yml.${i}.${DIRNAME}" \
        -w "ended(${JOB}.cat.${DIRNAME})" \
        -q ${QUEUE} \
        -e ${LOGS}/mmseqs.yml.err \
        -o ${LOGS}/mmseqs.yml.out \
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
        -J "${JOB}.${i}.${DIRNAME}" \
        -w "ended(${JOB}.yml.*.${DIRNAME})" \
        -q ${QUEUE} \
        -e ${LOGS}/mmseqs.${i}.err \
        -o ${LOGS}/mmseqs.${i}.out \
        bash ${P}/cluster/codon/run-cwltool.sh \
            -d False \
            -p ${P} \
            -o ${OUT} \
            -n "${DIRNAME}_mmseqs" \
            -c ${P}/cwl/tools/mmseqs/mmseqs.cwl \
            -y ${YML}/${i}.mmseqs.yml
done