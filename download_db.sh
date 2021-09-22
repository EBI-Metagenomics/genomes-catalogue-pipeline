#!/bin/bash

# GUNC database
wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/gunc_db_2.0.4.dmnd.gz && gunzip gunc_db_2.0.4.dmnd.gz

# EGGnog database
wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/eggnog_db.tgz && tar -xvzf eggnog_db.tgz

# InterProScan database
wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/interproscan-5.52-86.0_data.tgz && tar -xvzf interproscan-5.52-86.0_data.tgz

# GTDB-Tk Database
wget https://data.gtdb.ecogenomic.org/releases/latest/auxillary_files/gtdbtk_data.tar.gz && tar -zxvf gtdbtk_data.tar.gz

# GTDB-Tk Database
mkdir rfams_cms && wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/rfams_cms/* -P rfams_cms