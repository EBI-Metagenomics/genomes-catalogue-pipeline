#!/bin/bash

set -e

docker login quay.io

export REPO="genomes-pipeline"

export DOCKERHUB_NAME="microbiomeinformatics"
export QUAY_NAME="quay.io/microbiome-informatics"

export STORAGE=${QUAY_NAME}

num_containers=9

containers_versions=(
    'bash:v1'
    'checkm:v1'
    'detect_rrna:v3.1'
    'eggnog-mapper:v1'
    'genomes-catalog-update:v1'
    'gtdb-tk:v1'
    'ips:5.57-90.0'
    'mash2nwk:v1'
    'python3base:v1.0'
)

for ((i = 0; i < num_containers; i++)); do
    echo "${containers_versions[${i}]}"
    docker push "${STORAGE}/${REPO}.${containers_versions[${i}]}"
done
