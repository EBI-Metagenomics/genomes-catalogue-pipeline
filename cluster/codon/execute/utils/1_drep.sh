#!/bin/bash

while getopts :o:p:l:n:q:y:i:c:m:x:j: option; do
	case "${option}" in
		o) OUT=${OPTARG};;
		p) P=${OPTARG};;
		l) LOGS=${OPTARG};;
		n) DIRNAME=${OPTARG};;
		q) QUEUE=${OPTARG};;
		y) YML=${OPTARG};;
		i) INPUT=${OPTARG};;
		c) CSV=${OPTARG};;
		m) MAX_MGYG=${OPTARG};;
		x) MIN_MGYG=${OPTARG};;
		j) JOB_NAME=${OPTARG};;
	esac
done

export CWL=${P}/cluster/codon/execute/cwl/1_drep.cwl
export YML_FILE=${YML}/drep.yml

echo "Creating yml for drep"
echo \
"
skip_drep_step: False
max_accession_mgyg: ${MAX_MGYG}
min_accession_mgyg: ${MIN_MGYG}
genomes_ena:
  class: Directory
  path: ${INPUT}
ena_csv:
  class: File
  path: ${CSV}
" > ${YML_FILE}

echo "Running dRep"
bsub \
    -J "${JOB_NAME}.${DIRNAME}" \
    -q ${QUEUE} \
    -o ${LOGS}/drep.out \
    -e ${LOGS}/drep.err \
    bash ${P}/cluster/codon/run-cwltool.sh \
        -d False \
        -p ${P} \
        -o ${OUT} \
        -n "${DIRNAME}_drep" \
        -c ${CWL} \
        -y ${YML_FILE}

