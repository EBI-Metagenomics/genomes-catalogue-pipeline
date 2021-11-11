#!/bin/bash

set -e

docker login quay.io

export REPO="genomes-pipeline"

export DOCKERHUB_NAME="microbiomeinformatics"
export QUAY_NAME="quay.io/microbiome-informatics"

export STORAGE=${QUAY_NAME}

num_containers=14

containers_versions=(
        'bash_genomes_pipeline:v1'
        'checkm:v1'
        'detect_rrna:v2'
        'drep:v2'
        'eggnog-mapper_genomes_pipeline:v1'
        'genomes-catalog-update:v1'
        'gtdb-tk:v1'
        'gunc:v4'
        'ips_genomes_pipeline:v1'
        'mash2nwk:v1'
        'mmseqs:v2'
        'panaroo:v1'
        'prokka:v1'
        'python3_scripts_genomes_pipeline:v4'
)

for ((i=0;i<${num_containers};i++)) do
    echo ${containers_versions[${i}]}
    docker push ${STORAGE}/${REPO}.${containers_versions[${i}]}
done
