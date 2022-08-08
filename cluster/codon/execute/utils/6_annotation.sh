#!/bin/bash

while getopts :o:p:l:n:q:y:i:r: option; do
	case "${option}" in
		o) OUT=${OPTARG};;
		p) P=${OPTARG};;
		l) LOGS=${OPTARG};;
		n) DIRNAME=${OPTARG};;
		q) QUEUE=${OPTARG};;
		y) YML=${OPTARG};;
		i) INPUT=${OPTARG};;
		r) REPS=${OPTARG};;
	esac
done

echo "Creating all_fna"
mkdir -p ${OUT}/all_fna
for i in $(cat ${OUT}/sg); do
    NAME="$(basename -- ${i} | tr '_' '\t' | cut -f1)"
    ln -s ${OUT}/sg/${i}/${NAME}/${NAME}.fna ${OUT}/all_fna/${NAME}.fna
done

for i in $(cat ${OUT}/pg); do
    NAME="$(basename -- ${i} | tr '_' '\t' | cut -f1)"
    ln -s ${OUT}/pg/${i}/${NAME}/${NAME}.fna ${OUT}/all_fna/${NAME}.fna
    ls ${OUT}/pg/${i} | grep '.fna' > list.txt
    for j in $(cat list.txt); do
        ln -s ${OUT}/pg/${i}/${j}.fna ${OUT}/all_fna/${j}.fna;
    done
done

echo "Creating yml"
cp ${P}/cluster/codon/execute/utils/6_annotation.yml ${YML}/annotation.yml
echo \
"
mmseqs_faa:
  class: File
  path: ${INPUT}/mmseqs_09/faa
mmseqs_tsv:
  class: File
  path: ${INPUT}/mmseqs_09/tsv
all_fnas_dir:
  class: Directory
  path: ${OUT}/all_fna
all_reps_filtered:
  class: File
  path: ${REPS}
" >> ${YML}/annotation.yml

echo "Submitting annotations"
bsub \
    -J "Step7.annotation.${DIRNAME}" \
    -q ${QUEUE} \
    -e ${LOGS}/annotation.err \
    -o ${LOGS}/annotation.out \
    bash ${P}/cluster/codon/run-cwltool.sh \
        -d False \
        -p ${P} \
        -o ${OUT} \
        -n "${DIRNAME}_annotations" \
        -c ${P}/cwl/sub-wfs/wf-4-annotation.cwl \
        -y ${YML}/annotation.yml
