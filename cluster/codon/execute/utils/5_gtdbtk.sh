#!/bin/bash

while getopts :o:p:l:n:q:y:r:j:a: option; do
	case "${option}" in
		o) OUT=${OPTARG};;
		p) P=${OPTARG};;
		l) LOGS=${OPTARG};;
		n) DIRNAME=${OPTARG};;
		q) QUEUE=${OPTARG};;
		y) YML=${OPTARG};;
		r) REPS=${OPTARG};;
		j) JOB=${OPTARG};;
		a) REPS_FA=${OPTARG};;
	esac
done

export REFDATA="/hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/release202"

echo "Create gtdb-tk yml"
echo \
"
drep_folder:
  class: Directory
  path: ${REPS_FA}
gtdb_outfolder: gtdbtk-outdir
refdata:
  class: Directory
  path: ${REFDATA}
" > ${YML}/gtdbtk.yml

echo "Running ${DIRNAME} gtdb with ${YML}/gtdbtk.yml"

bsub \
     -J "${JOB}.${DIRNAME}.run" \
     -q ${QUEUE} \
     -e ${LOGS}/gtdbtk.err \
     -o ${LOGS}/gtdbtk.out \
     bash ${P}/cluster/codon/run-cwltool.sh \
        -d False \
        -p ${P} \
        -o ${OUT} \
        -n "gtdbtk" \
        -c ${P}/cwl/sub-wfs/5_gtdb/gtdbtk.cwl \
        -y ${YML}/gtdbtk.yml