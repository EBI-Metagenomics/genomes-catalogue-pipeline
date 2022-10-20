#!/bin/bash

set -e

docker login quay.io

export REPO="genomes-pipeline"

export DOCKERHUB_NAME="microbiomeinformatics"
export QUAY_NAME="quay.io/microbiome-informatics"

export STORAGE=${QUAY_NAME}

NUM_CONTAINERS=15

CONTAINERS_VERSIONS=(
        'bash:v1'
        'checkm:v1'
        'detect_rrna:v3'
        'drep:v2'
        'eggnog-mapper:v1'
        'genomes-catalog-update:v1'
        'gtdb-tk:v1'
        'gtdb-tk:v2.1.0'
        'gunc:v4'
        'ips:v1'
        'mash2nwk:v1'
        'mmseqs:v2'
        'panaroo:v1'
        'prokka:v1'
        'python3_scripts:v4'
)

for ((i = 0; i < NUM_CONTAINERS; i++)); do
        echo "########"
        echo "pushing the container ${REPO}.${CONTAINERS_VERSIONS[${i}]}"
        docker push "${STORAGE}/${REPO}.${CONTAINERS_VERSIONS[${i}]}"
        echo "########"
done
