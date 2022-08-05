#!/bin/bash

while getopts :o:p:m:l:n:q: option; do
	case "${option}" in
		o) OUT=${OPTARG};;
		p) P=${OPTARG};;
		m) MASH=${OPTARG};;
		l) LOGS=${OPTARG};;
		n) DIRNAME=${OPTARG};;
		q) QUEUE=${OPTARG};;
	esac
done

for i in $(ls ${MASH}); do
    NAME="$(basename -- ${MASH}/${i})"
    export YML=${OUT}/ymls/${NAME}.yml
    echo "input_mash: " > ${YML}
    echo "  class: File" >> ${YML}
    echo "  path: ${MASH}/${i}" >> ${YML}

    echo "Running ${NAME} mash with ${YML}"
    bsub -J "Step3.mash.${i}.${DIRNAME}" \
         -q ${QUEUE} \
         -e ${LOGS}/${i}.mash.err \
         -o ${LOGS}/${i}.mash.out \
         bash ${P}/cluster/codon/run-cwltool.sh \
            -d False \
            -p ${P} \
            -o ${OUT} \
            -n "mash2nwk" \
            -c ${P}/cwl/tools/mash2nwk/mash2nwk.cwl \
            -y ${YML};
done