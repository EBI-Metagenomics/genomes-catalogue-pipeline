#!/bin/bash

export GUNC_DB="/hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/gunc_db_2.0.4.dmnd"

usage()
{
cat << EOF
usage: $0 options
Run genomes-pipeline cluster processing steps
OPTIONS:
   -o      Path to general output catalogue directory
   -p      Path to installed pipeline location
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -y      Path to folder to save yml file
   -i      Path to input folder with clusters(sg or pg)
   -s      Renamed CSV with completeness and contamination
   -j      LSF step Job name to submit
   -z      memory to execute
   -w      number of threads
EOF
}

while getopts hi:o:p:t:l:n:q:y:j:s:z:w: option; do
	case "${option}" in
		h)
             usage
             exit 1
             ;;
	    i)
	        INPUT=${OPTARG}
	        ;;
		o)
		    OUTDIR=${OPTARG}
		    ;;
		p)
		    P=${OPTARG}
		    ;;
		t)
		    TYPE=${OPTARG}
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
		    YML_FOLDER=${OPTARG}
		    ;;
		j)
		    JOB=${OPTARG}
		    ;;
		s)
		    INPUT_CSV=${OPTARG}
		    ;;
		z)
		    MEM=${OPTARG}
		    ;;
		w)
		    THREADS=${OPTARG}
		    ;;
		?)
		    usage
            exit
            ;;
	esac
done

ls "${INPUT}" > input_list.txt

while IFS= read -r i
do
    export YML=${YML_FOLDER}/${i}.${TYPE}.cluster.yml

    if [ "${TYPE}" == "pg" ]; then
        CWL=${P}/cwl/sub-wfs/3_process_clusters/pan-genomes/sub-wf-pan-genomes.cwl
        MASH=${OUTDIR}/mash2nwk/${i}_mashtree.nwk
        echo \
         "
cluster:
  class: Directory
  path: ${INPUT}/${i}
mash_files:
  - class: File
    path: ${MASH}
     " > "${YML}"
    else
        CWL=${P}/cwl/sub-wfs/3_process_clusters/singletons/sub-wf-singleton.cwl
        NAME="$(basename -- "${INPUT_CSV}")"
        CSV=${OUTDIR}/${DIRNAME}_drep/intermediate_files/renamed_${NAME}
        echo \
         "
cluster:
  class: Directory
  path: ${INPUT}/${i}
gunc_db_path:
  class: File
  path: ${GUNC_DB}
csv:
  class: File
  path: ${CSV}
     " > "${YML}"
    fi

    echo "Running ${i} ${TYPE} with ${YML}"
    bsub \
         -J "${JOB}.${DIRNAME}.${TYPE}.${i}" \
         -e "${LOGS}"/"${TYPE}"_"${i}".err \
         -o "${LOGS}"/"${TYPE}"_"${i}".out \
         -q "${QUEUE}" \
         -M "${MEM}" \
         -n "${THREADS}" \
         bash "${P}"/cluster/codon/run-cwltool.sh \
            -d False \
            -p "${P}" \
            -o "${OUTDIR}"/"${TYPE}" \
            -n "${i}"_cluster \
            -c "${CWL}" \
            -y "${YML}"
done < input_list.txt

rm input_list.txt