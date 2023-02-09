#!/bin/bash

usage() {
    cat <<EOF
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
   -g      path to GUNC DB (gunc_db_2.0.4.dmnd)
EOF
}

while getopts hi:o:p:t:l:n:q:y:j:s:z:w:g: option; do
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
        PIPELINE_DIRECTORY=${OPTARG}
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
    g) 
        GUNC_DB=${OPTARG}
        ;;
    ?)
        usage
        exit
        ;;
    esac
done

ls "${INPUT}" >"step3_input_list_${TYPE}.txt"

while IFS= read -r i; do
    YML=${YML_FOLDER}/${i}.${TYPE}.cluster.yml

    if [ "${TYPE}" == "pg" ]; then
        CWL=${PIPELINE_DIRECTORY}/src/cwl/sub-wfs/3_process_clusters/pan-genomes/sub-wf-pan-genomes.cwl
        MASH=${OUTDIR}/mash2nwk/${i}_mashtree.nwk
        echo \
            "
cluster:
  class: Directory
  path: ${INPUT}/${i}
mash_files:
  - class: File
    path: ${MASH}
     " >"${YML}"
    else
        CWL=${PIPELINE_DIRECTORY}/src/cwl/sub-wfs/3_process_clusters/singletons/sub-wf-singleton.cwl
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
     " >"${YML}"
    fi

    echo "Running ${i} ${TYPE} with ${YML}"
    bsub \
        -J "${JOB}.${DIRNAME}.${TYPE}.${i}" \
        -e "${LOGS}"/"${JOB}"."${TYPE}"_"${i}".err \
        -o "${LOGS}"/"${JOB}"."${TYPE}"_"${i}".out \
        -q "${QUEUE}" \
        -M "${MEM}" \
        -n "${THREADS}" \
        bash "${PIPELINE_DIRECTORY}"/bin/run-cwltool.sh \
            -d False \
            -p "${PIPELINE_DIRECTORY}" \
            -o "${OUTDIR}"/"${TYPE}" \
            -n "${i}"_cluster \
            -c "${CWL}" \
            -y "${YML}"

done <"step3_input_list_${TYPE}.txt"

rm "step3_input_list_${TYPE}.txt"
