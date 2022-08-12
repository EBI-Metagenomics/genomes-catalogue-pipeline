#!/bin/bash

while getopts :o:p:l:n:q:y:i:r:j:c:b: option; do
	case "${option}" in
		o) OUT=${OPTARG};;
		p) P=${OPTARG};;
		l) LOGS=${OPTARG};;
		n) DIRNAME=${OPTARG};;
		q) QUEUE=${OPTARG};;
		y) YML=${OPTARG};;
		i) INPUT=${OPTARG};;
		r) REPS=${OPTARG};;
		j) JOB=${OPTARG};;
		c) CONDITION_JOB=${OPTARG};;
		b) ALL_FNA=${OPTARG};;
	esac
done

echo "Creating yml"
cp ${P}/cluster/codon/execute/utils/6_annotation.yml ${YML}/annotation.yml
echo \
"
mmseqs_faa:
  class: File
  path: ${INPUT}/mmseqs_cluster_rep.fa
mmseqs_tsv:
  class: File
  path: ${INPUT}/mmseqs_cluster.tsv
all_fnas_dir:
  class: Directory
  path: ${ALL_FNA}
all_reps_filtered:
  class: File
  path: ${REPS}
" >> ${YML}/annotation.yml

echo "Submitting annotations"
bsub \
    -J "${JOB}.${DIRNAME}" \
    -w ${CONDITION_JOB} \
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
