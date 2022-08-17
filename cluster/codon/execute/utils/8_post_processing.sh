#!/bin/bash

usage()
{
cat << EOF
usage: $0 options
Run genomes-pipeline post-processing steps: kegg, cog, ncRNA, populate GFF, generate genome.json
OPTIONS:
   -o      Path to general output catalogue directory
   -p      Path to installed pipeline location
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -y      Path to folder to save yml file
   -j      LSF step Job name to submit
   -c      LSF job condition
   -b      Catalogue biom
   -m      GTDB-Tk metadata
   -a      Path to directory with EggNOG and InterProScan separated files
   -z      Memory in Gb
   -t      Threads
EOF
}

while getopts ho:p:l:n:q:y:j:b:m:a:z:t: option; do
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
        b)
            BIOM=${OPTARG}
		    ;;
		m)
		    METADATA=${OPTARG}
		    ;;
		a)
		    ANNOTATIONS=${OPTARG}
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

echo "Generating yml file"
export YML_FILE="${YML}"/post-processing.yml
cp "${P}"/cluster/codon/execute/utils/8_post_processing.yml "${YML_FILE}"

bsub \
    -J "${JOB}.${DIRNAME}.yml" \
    -q "${QUEUE}" \
    -e "${LOGS}"/"${JOB}".post-processing.yml.err \
    -o "${LOGS}"/"${JOB}".post-processing.yml.out \
    bash "${P}"/cluster/codon/execute/utils/8_generate_yml.sh \
        -b "${BIOM}" \
        -m "${METADATA}" \
        -y "${YML_FILE}" \
        -o "${OUT}" \
        -a "${ANNOTATIONS}"

export CWL="${P}"/cwl/sub-wfs/wf-6-post-processing.cwl
echo "Submitting cluster post-processing"
bsub \
    -J "${JOB}.${DIRNAME}" \
    -w "${JOB}.${DIRNAME}.yml"\
    -q "${QUEUE}" \
    -e "${LOGS}"/"${JOB}".err \
    -o "${LOGS}"/"${JOB}".out \
    -M "${MEM}" \
    -n "${THREADS}" \
    bash "${P}"/cluster/codon/run-cwltool.sh \
        -d False \
        -p "${P}" \
        -o "${OUT}" \
        -n "${DIRNAME}_metadata" \
        -c "${CWL}" \
        -y "${YML_FILE}"