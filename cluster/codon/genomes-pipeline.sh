#!/bin/bash

export CWL=/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/cwl/workflows/wf-main.cwl
export YML=/nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/tests/cluster/wf-main_ena_small.yml

export SINGULARITY_HOME=/hps/nobackup/rdf/metagenomics/singularity_cache
export SINGULARITY_CACHEDIR=$SINGULARITY_HOME
export SINGULARITY_TMPDIR=$SINGULARITY_HOME/tmp
export SINGULARITY_LOCALCACHEDIR=$SINGULARITY_HOME/local_tmp
export SINGULARITY_PULLFOLDER=$SINGULARITY_HOME/pull
export SINGULARITY_BINDPATH=$SINGULARITY_HOME/scratch

export OUTDIR=result

while getopts :o:y:c: option; do
	case "${option}" in
		o) OUTDIR=${OPTARG};;
		y) YML=${OPTARG};;
		c) CWL=${OPTARG};;
	esac
done


cwltool --singularity --preserve-entire-environment --leave-container --outdir ${OUTDIR} ${CWL} ${YML}