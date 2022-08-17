#!/bin/bash

usage()
{
cat << EOF
usage: $0 options
Run genomes-pipeline mash2nwk step
OPTIONS:
   -o      Path to general output catalogue directory
   -p      Path to installed pipeline location
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -y      Path to folder to save yml file
   -j      LSF step Job name to submit
   -r      Path to file with cluster representatives (filtered)
   -i      Path to mmseqs result directory
   -b      Path to directory with all fasta.fna (filtered)
   -z      memory in Gb
   -t      number of threads
EOF
}

export TOIL="False"

while getopts ho:p:l:n:q:y:i:r:j:b:z:t:w: option; do
	case "${option}" in
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
		i)
		    INPUT=${OPTARG}
		    ;;
		r)
		    REPS=${OPTARG}
		    ;;
		j)
		    JOB=${OPTARG}
		    ;;
		b)
		    ALL_FNA=${OPTARG}
		    ;;
        z)
		    MEM=${OPTARG}
		    ;;
		t)
		    THREADS=${OPTARG}
		    ;;
		w)
		    TOIL=${OPTARG}
		    ;;
		?)
            usage
            exit
            ;;
	esac
done

echo "Creating yml"
cp "${P}"/cluster/codon/execute/utils/6_annotation.yml "${YML}"/annotation.yml
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
" >> "${YML}"/annotation.yml

if [ "${TOIL}" == "True" ]; then
    echo "Running annotations with Toil"
    bsub \
         -J "${JOB}.${DIRNAME}.run" \
         -e "${LOGS}"/"${JOB}".err \
         -o "${LOGS}"/"${JOB}".out \
         bash "${P}"/cluster/codon/Toil/run-toil.sh \
            -n "${DIRNAME}_annotations" \
            -q "${QUEUE}" \
            -p "${P}" \
            -o "${OUT}" \
            -m "${MEM}" \
            -c "${P}"/cwl/sub-wfs/wf-4-annotation.cwl \
            -y "${YML}"/annotation.yml
else
    echo "Running annotations with cwltool"
    bsub \
        -J "${JOB}.${DIRNAME}.run" \
        -q "${QUEUE}" \
        -e "${LOGS}"/"${JOB}".err \
        -o "${LOGS}"/"${JOB}".out \
        -M "${MEM}" \
        -n "${THREADS}" \
        bash "${P}"/cluster/codon/run-cwltool.sh \
            -d False \
            -p "${P}" \
            -o "${OUT}" \
            -n "${DIRNAME}_annotations" \
            -c "${P}"/cwl/sub-wfs/wf-4-annotation.cwl \
            -y "${YML}"/annotation.yml
fi