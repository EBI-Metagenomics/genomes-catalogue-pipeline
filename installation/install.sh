#!/bin/bash

conda create -y --name genomes-pipeline python=3.7
conda activate genomes-pipeline

echo "Install InterProScan"
wget ftp://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/5.36-75.0/interproscan-5.36-75.0-64-bit.tar.gz && tar -xvzf interproscan-5.36-75.0-64-bit.tar.gz

conda update -n base conda
conda install -y -c bioconda java-jdk
conda install -c anaconda perl

echo "Install GTDB-Tk"
conda install -c bioconda gtdbtk

echo "Downloading DBs will take time"
download-db.sh