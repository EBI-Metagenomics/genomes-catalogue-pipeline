#!/bin/bash

usage()
{
cat << EOF
usage: $0 options
Run genomes-pipeline preparation and dRep part
OPTIONS:
   -o      Path to general output catalogue directory
   -p      Path to installed pipeline location
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -y      Path to folder to save yml file
   -i      Path to input ENA genomes folder
   -c      Path to input genomes csv
   -m      Max MGYG
   -x      Min MGYG
   -j      LSF step Job name to submit
   -z      memory to execute
   -t      number of threads
EOF
}

while getopts ho:p:l:n:q:y:i:c:m:x:j:z:t: option; do
	case "$option" in
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
		i)
		    INPUT=${OPTARG}
		    ;;
		c)
		    CSV=${OPTARG}
		    ;;
		m)
		    MAX_MGYG=${OPTARG}
		    ;;
		x)
		    MIN_MGYG=${OPTARG}
		    ;;
		j)
		    JOB_NAME=${OPTARG}
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

export CWL=${PIPELINE_DIRECTORY}/src/cwl/1_drep.cwl
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
" > "${YML_FILE}"

echo "Running dRep"
bsub \
    -J "${JOB_NAME}.${DIRNAME}" \
    -q "${QUEUE}" \
    -o "${LOGS}"/"${JOB_NAME}".out \
    -e "${LOGS}"/"${JOB_NAME}".err \
    -M "${MEM}" \
    -n "${THREADS}" \
    bash "${PIPELINE_DIRECTORY}"/bin/run-cwltool.sh \
        -d False \
        -p "${PIPELINE_DIRECTORY}" \
        -o "${OUT}" \
        -n "${DIRNAME}_drep" \
        -c "${CWL}" \
        -y "${YML_FILE}"