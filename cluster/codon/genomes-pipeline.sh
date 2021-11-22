#!/bin/bash

set -e

. /hps/software/users/rdf/metagenomics/service-team/envs/mitrc.sh

mitload miniconda

module load singularity-3.7.0-gcc-9.3.0-dp5ffrp
conda activate toil-5.4.0

#export SINGULARITY_HOME=/hps/nobackup/rdf/metagenomics/singularity_cache
#export SINGULARITY_CACHEDIR=$SINGULARITY_HOME
#export SINGULARITY_TMPDIR=$SINGULARITY_HOME/tmp
#export SINGULARITY_LOCALCACHEDIR=$SINGULARITY_HOME/local_tmp
#export SINGULARITY_PULLFOLDER=$SINGULARITY_HOME/pull
#export SINGULARITY_BINDPATH=$SINGULARITY_HOME/scratch

export OUTDIR=result

MAIN_PATH="/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/"
CWL=${MAIN_PATH}/cwl/workflows/wf-main.cwl
YML=${MAIN_PATH}/tests/cluster/wf-main_ena_small.yml

while getopts :n:y:c:p:d: option; do
	case "${option}" in
		n) OUTDIR=${OPTARG};;
		y) YML=${OPTARG};;
		c) CWL=${OPTARG};;
		p) MAIN_PATH=${OPTARG};;
	    d) DEBUG=${OPTARG};;
	esac
done

export PATH=$PATH:${MAIN_PATH}/docker/python3_scripts/
export PATH=$PATH:${MAIN_PATH}/docker/genomes-catalog-update/scripts/

chmod a+x ${MAIN_PATH}/docker/python3_scripts/*
chmod a+x ${MAIN_PATH}/docker/genomes-catalog-update/scripts/*

if [ "${DEBUG}" == "True" ]; then
    cwltool --singularity --preserve-entire-environment --debug --leave-container --outdir ${OUTDIR} ${CWL} ${YML}
else
    cwltool --singularity --preserve-entire-environment --leave-container --outdir ${OUTDIR} ${CWL} ${YML}
fi