#!/bin/bash

usage()
{
cat << EOF
usage: $0 options
Run genomes-pipeline mash2nwk step
OPTIONS:
   -o      Path to general output catalogue directory
   -p      Path to installed pipeline location
   -m      Path to mash.tsv file
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -y      Path to folder to save yml file
   -j      LSF step Job name to submit
   -z      memory in Gb
   -t      number of threads
EOF
}

while getopts ho:p:m:l:n:q:y:j:z:t: option; do
	case "$option" in
		h)
             usage
             exit 1
             ;;
		o)
		    OUT=${OPTARG}
		    ;;
		p)
		    P=${OPTARG}
		    ;;
		m)
		    MASH=${OPTARG}
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

ls "${MASH}" > list_mash.txt

while IFS= read -r i
do
    NAME="$(basename -- "${MASH}"/"${i}")"
    export YML_FILE=${YML}/${NAME}.yml
    echo "input_mash: " > "${YML_FILE}"
    echo "  class: File" >> "${YML_FILE}"
    echo "  path: ${MASH}/${i}" >> "${YML_FILE}"

    echo "Running ${NAME} mash with ${YML_FILE}"
    bsub -J "${JOB}.${DIRNAME}.${i}" \
         -q "${QUEUE}" \
         -e "${LOGS}"/"${JOB}"."${i}".err \
         -o "${LOGS}"/"${JOB}"."${i}".out \
         -M "${MEM}" \
         -n "${THREADS}" \
         bash "${P}"/cluster/codon/run-cwltool.sh \
            -d False \
            -p "${P}" \
            -o "${OUT}" \
            -n "mash2nwk" \
            -c "${P}"/cwl/tools/mash2nwk/mash2nwk.cwl \
            -y "${YML_FILE}"
done < list_mash.txt

rm list_mash.txt