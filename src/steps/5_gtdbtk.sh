#!/bin/bash

usage()
{
cat << EOF
usage: $0 options
Run genomes-pipeline GTDTK step using singularity.
OPTIONS:
   -o      Path to general output catalogue directory
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -y      Path to folder to save yml file
   -j      LSF step Job name to submit
   -a      Path to directory with fasta.fna cluster representatives (filtered)
   -z      Memory in Gb
   -t      Number of threads
   -r      GTDBtk REF db (releases202/)
EOF
}

set -e

GTDBTK_REFDATA=""

while getopts ho:p:l:n:q:j:a:z:t:r: option; do
	case "${option}" in
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
		a)
		    REPS_FA=${OPTARG}
		    ;;
        z)
		    MEM=${OPTARG}
		    ;;
		t)
		    THREADS=${OPTARG}
		    ;;
        r)
            GTDBTK_REFDATA=${OPTARG}
            ;;
		?)
            usage
            exit
            ;;
	esac
done

mkdir -p "${OUT}"/gtdbtk

bsub \
    -J "${JOB}.${DIRNAME}.run" \
    -e "${LOGS}"/"${JOB}".err \
    -o "${LOGS}"/"${JOB}".out \
    -M "${MEM}" \
    -n "${THREADS}" \
    -q "${QUEUE}"  \
    singularity \
        --quiet \
        exec \
        --contain \
        --ipc \
        --pid \
        --bind \
        "${OUT}"/gtdbtk:/tmp:rw \
        --bind \
        "${GTDBTK_REFDATA}":/refdata:ro \
        --bind \
        "${REPS_FA}":/data:ro \
        --pwd \
        /GFpZec \
        "$SINGULARITY_CACHE"/quay.io_microbiome-informatics_genomes-pipeline.gtdb-tk:v1.sif \
        gtdbtk \
        classify_wf \
        --cpus \
        32 \
        --genome_dir \
        /data \
        --out_dir \
        /tmp/gtdbtk-outdir \
        -x fna
