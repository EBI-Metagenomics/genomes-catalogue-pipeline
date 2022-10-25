#!/bin/bash

usage()
{
cat << EOF
usage: $0 options
Run Emerald. Temporary script to replace emerald.cwl.
OPTIONS:
   -o      Path to general output catalogue directory
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -j      LSF step Job name to submit
   -z      memory in Gb
   -t      number of threads
EOF
}

while getopts ho:l:n:q:j:z:t: option; do
	case "$option" in
		h)
             usage
             exit 1
             ;;
		o)
		    OUT=${OPTARG}
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

if [[ -z $OUT ]] || [[ -z $DIRNAME ]] || [[ -z $LOGS ]]; then
  echo 'Not all of the arguments are provided'
  usage
fi

# Run Emerald on non-singleton cluster reps
while IFS= read -r i
do
  bsub -J "${JOB}.${DIRNAME}.${i}" \
      -q "${QUEUE}" \
      -e "${LOGS}"/"${JOB}"."${i}".err \
      -o "${LOGS}"/"${JOB}"."${i}".out \
      -M "${MEM}" \
      -n "${THREADS}" \
      singularity run $SINGULARITY_CACHEDIR/quay.io_microbiome-informatics_emerald-bgc:v0.2.4.1_genomes-pipeline.sif \
      emeraldbgc --ip-file "${OUT}"/"${DIRNAME}"/Foldertest_annotations/"${i}"_InterProScan.tsv \
      --outdir "${OUT}"/"${DIRNAME}"/pg/"${i}"_cluster/"${i}" "${OUT}"/"${DIRNAME}"/pg/"${i}"_cluster/"${i}"/"${i}".gbk
done < "${OUT}"/"${DIRNAME}"/cluster_reps.txt.pg

# Run Emerald on singleton cluster reps
while IFS= read -r i
do
  bsub -J "${JOB}.${DIRNAME}.${i}" \
      -q "${QUEUE}" \
      -e "${LOGS}"/"${JOB}"."${i}".err \
      -o "${LOGS}"/"${JOB}"."${i}".out \
      -M "${MEM}" \
      -n "${THREADS}" \
      singularity run $SINGULARITY_CACHEDIR/quay.io_microbiome-informatics_emerald-bgc:v0.2.4.1_genomes-pipeline.sif \
      emeraldbgc --ip-file "${OUT}"/"${DIRNAME}"/Foldertest_annotations/"${i}"_InterProScan.tsv \
      --outdir "${OUT}"/"${DIRNAME}"/sg/"${i}"_cluster/"${i}" "${OUT}"/"${DIRNAME}"/sg/"${i}"_cluster/"${i}"/"${i}".gbk
done < "${OUT}"/"${DIRNAME}"/cluster_reps.txt.sg
