#!/bin/bash

while getopts :o:p:l:n:q:y:r:j: option; do
	case "${option}" in
		o) OUT=${OPTARG};;
		p) P=${OPTARG};;
		l) LOGS=${OPTARG};;
		n) DIRNAME=${OPTARG};;
		q) QUEUE=${OPTARG};;
		y) YML=${OPTARG};;
		r) REPS=${OPTARG};;
		j) JOB=${OPTARG};;
	esac
done

export REFDATA="/hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/release202"

mkdir -p ${OUT}/reps

for i in $(cat ${REPS}.sg); do
    ln -s ${OUT}/sg/${i}*/${i}/${i}.fa ${OUT}/reps/${i}.fa
done

for i in $(cat ${REPS}.pg); do
    ln -s ${OUT}/pg/${i}*/${i}/${i}.fa ${OUT}/reps/${i}.fa
done

echo "Create gtdb-tk yml"
echo \
"
drep_folder:
  class: Directory
  path: ${OUT}/reps
gtdb_outfolder: gtdbtk-outdir
refdata:
  class: Directory
  path: ${REFDATA}
" > ${YML}/gtdbtk.yml

echo "Running ${DIRNAME} gtdb with"
bsub -J "${JOB}.${DIRNAME}" \
     -q ${QUEUE} \
     -e ${LOGS}/gtdbtk.err \
     -o ${LOGS}/gtdbtk.out \
     bash ${P}/cluster/codon/run-cwltool.sh \
        -d False \
        -p ${P} \
        -o ${OUT} \
        -n "gtdbtk" \
        -c ${P}/cwl/tools/gtdbtk/gtdbtk.cwl \
        -y ${YML}/gtdbtk.yml