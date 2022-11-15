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
   -a      Path to directory with fasta.fna cluster representatives (filtered)
   -z      memory in Gb
   -t      number of threads
   -r      run with Toil
EOF
}

set -e

export REFDATA="/hps/nobackup/rdf/metagenomics/service-team/production/ref-dbs/genomes-pipeline/release207_v2"
export TOIL=False

while getopts ho:p:l:n:q:y:j:a:z:t:r: option; do
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
		    TOIL=${OPTARG}
		    ;;
		?)
            usage
            exit
            ;;
	esac
done

. /hps/software/users/rdf/metagenomics/service-team/repos/mi-automation/team_environments/codon/mitrc.sh
mitload miniconda
module load singularity-3.7.0-gcc-9.3.0-dp5ffrp
export TMPDIR="/hps/scratch/rdf/metagenomics/pipelines-tmp"

mkdir -p ${OUT}/gtdbtk
bsub \
    -J "${JOB}.${DIRNAME}.run" \
    -e "${LOGS}"/"${JOB}".err \
    -o "${LOGS}"/"${JOB}".out \
    -M "${MEM}" \
    -n "${THREADS}" \
    -q "${QUEUE}"  \
    singularity \
        --quiet \
        run \
        --contain \
        --ipc \
        --pid \
        --bind \
        "${OUT}"/gtdbtk:/tmp:rw \
        --bind \
        "${REFDATA}":/refdata:ro \
        --bind \
        "${REPS_FA}":/data:ro \
        --pwd \
        /GFpZec \
        /hps/nobackup/rdf/metagenomics/singularity_cache/quay.io_microbiome-informatics_genomes-pipeline.gtdb-tk:v2.1.0.sif \
        gtdbtk \
        classify_wf \
        --cpus \
        32 \
        --genome_dir \
        /data \
        --out_dir \
        /tmp/gtdbtk-outdir \
        -x fna
