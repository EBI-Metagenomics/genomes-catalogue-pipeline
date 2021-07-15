#!/bin/bash

# download db for GUNC
wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/gunc_db_2.0.4.dmnd.gz && gunzip gunc_db_2.0.4.dmnd.gz

# eggnog dbs
wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/eggnog_db.tgz && tar -xvzf eggnog_db.tgz

# ips dbs
wget ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/interproscan_5.52-86.0_data.tgz && tar -xvzf interproscan_5.52-86.0_data.tgz
