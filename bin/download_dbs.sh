#!/bin/bash

mkdir dbs && cd dbs

# GUNC database
wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/gunc_db_2.0.4.dmnd.gz && gunzip gunc_db_2.0.4.dmnd.gz

# EGGnog database
wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/eggnog_db.tgz && tar -xvzf eggnog_db.tgz
mkdir -p eggnog/data && mv eggnog_proteins.dmnd eggnog.db eggnog/data

# InterProScan database
mkdir ips && cd ips
wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/interproscan-5.52-86.0_data.tgz && tar -xvzf interproscan-5.52-86.0_data.tgz
cd ..

# GTDB-Tk Database
wget https://data.gtdb.ecogenomic.org/releases/release207/auxillary_files/gtdbtk_data.tar.gz && tar -zxvf gtdbtk_data.tar.gz

# cmsearch models
mkdir -p rfams_cms && wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/rfams_cms/* -P rfams_cms

# kegg classes
wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/kegg_classes.tsv

# GEO mapping
wget http://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/continent_countries.csv

# cmscan ncRNA models
mkdir -p ncrna_cms && wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/ncrna/* -P ncrna_cms
