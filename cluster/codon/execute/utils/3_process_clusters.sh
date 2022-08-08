#!/bin/bash

export GUNC_DB="/hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/gunc_db_2.0.4.dmnd"

while getopts :i:o:p:t:l:n:q:y:j: option; do
	case "${option}" in
	    i) INPUT=${OPTARG};;
		o) OUTDIR=${OPTARG};;
		p) P=${OPTARG};;
		t) TYPE=${OPTARG};;
		l) LOGS=${OPTARG};;
		n) DIRNAME=${OPTARG};;
		q) QUEUE=${OPTARG};;
		y) YML_FOLDER=${OPTARG};;
		j) JOB=${OPTARG};;
	esac
done

for i in $(ls ${INPUT}); do

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
     " > ${YML}
    else
        CWL=${P}/cwl/sub-wfs/3_process_clusters/singletons/sub-wf-singleton.cwl
        CSV=${OUTDIR}/${DIRNAME}_drep/intermediate_files/renamed_download.csv
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
     " > ${YML}
    fi

    echo "Running ${i} ${TYPE} with ${YML}"
    bsub -J "${JOB}.${TYPE}.${i}.${DIRNAME}" \
         -e ${LOGS}/${TYPE}_${i}.err \
         -o ${LOGS}/${TYPE}_${i}.out \
         -q ${QUEUE} \
         bash ${P}/cluster/codon/run-cwltool.sh \
            -d False \
            -p ${P} \
            -o ${OUTDIR}/${TYPE} \
            -n ${i}_cluster \
            -c ${CWL} \
            -y ${YML}
done