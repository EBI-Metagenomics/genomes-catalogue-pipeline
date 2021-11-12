#!/bin/bash

set -e

docker login quay.io

export REPO="genomes-pipeline"

export DOCKERHUB_NAME="microbiomeinformatics"
export QUAY_NAME="quay.io/microbiome-informatics"

export STORAGE=${QUAY_NAME}

num_containers=14

folders=(
        'bash'
        'checkm'
        'detect_rrna'
        'drep'
        'eggnog-mapper'
        'genomes-catalog-update'
        'gtdb-tk'
        'gunc'
        'ips'
        'mash2nwk'
        'mmseqs'
        'panaroo'
        'prokka'
        'python3_scripts'
)

containers_versions=(
        'bash:v1'
        'checkm:v1'
        'detect_rrna:v2'
        'drep:v2'
        'eggnog-mapper:v1'
        'genomes-catalog-update:v1'
        'gtdb-tk:v1'
        'gunc:v4'
        'ips:v1'
        'mash2nwk:v1'
        'mmseqs:v2'
        'panaroo:v1'
        'prokka:v1'
        'python3_scripts:v4'
)

for ((i=0;i<${num_containers};i++)) do
    echo ${containers_versions[${i}]}
    #cd ${folders[${i}]} &&
    # docker build -t ${STORAGE}/${REPO}.${containers_versions[${i}]} . &&
    # cd .. &&
    docker push ${STORAGE}/${REPO}.${containers_versions[${i}]}
done
