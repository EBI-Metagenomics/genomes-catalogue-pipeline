#!/bin/bash

set -e

export REPO="genomes-pipeline"

export DOCKERHUB_NAME="microbiomeinformatics"
export QUAY_NAME="quay.io/microbiome-informatics"

export STORAGE=${QUAY_NAME}

NUM_CONTAINERS=16

folders=(
        'bash'
        'checkm'
        'detect_rrnas'
        'drep'
        'eggnog-mapper'
        'genomes-catalog-update'
        'gtdb-tk/v1.5.1'
        'gtdb-tk/v2.1.0'
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
        'detect_rrna:v3.1'
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
        echo "Building container ${REPO}.${containers_versions[${i}]}"
        FOLDER=${folders[${i}]}
        docker build -t "${STORAGE}/${REPO}.${containers_versions[${i}]}" --file "${FOLDER}/Dockerfile" "${FOLDER}"
        echo "########"
done

# Special case
docker build ../cwl/tools/virify_gff -f virify_gff/Dockerfile -t "quay.io/microbiome-informatics/genomes-pipeline.virify-gff:v1"