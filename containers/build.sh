#!/bin/bash

set -e

export REPO="genomes-pipeline"

export DOCKERHUB_NAME="microbiomeinformatics"
export QUAY_NAME="quay.io/microbiome-informatics"

export STORAGE=${QUAY_NAME}

num_containers=14

folders=(
    'bash'
    'checkm'
    'detect_rrnas'
    'eggnog-mapper'
    'genomes-catalog-update'
    'gtdb-tk'
    'ips'
    'mash2nwk'
    'python3_scripts'
)

containers_versions=(
    'bash:v1'
    'checkm:v1'
    'detect_rrna:v3.1'
    'eggnog-mapper:v1'
    'genomes-catalog-update:v1'
    'gtdb-tk:v1'
    'ips:5.57-90.0'
    'mash2nwk:v1'
    'python3_scripts:v4'
)

for ((i = 0; i < num_containers; i++)); do
    echo "${i}"
    cd "${folders[${i}]}" && docker build -t "${STORAGE}/${REPO}.${containers_versions[${i}]}" .
done
