#!/bin/bash

set -e

export NAME=genomes-pipeline

# checkm
cd  checkm && docker build -t microbiomeinformatics/${NAME}.checkm:v1 .

# drep
cd drep && docker build -t microbiomeinformatics/${NAME}.drep:v1 .

# eggnog
cd eggnong && docker build -t microbiomeinformatics/${NAME}.eggnog-mapper:v1 .

# genome-catalog-update
cd genomes-catalog-update && docker build -t microbiomeinformatics/${NAME}.genome-catalog-update:v1 .

# GUNC
cd GUNC && docker build -t microbiomeinformatics/${NAME}.gunc:v2 .

# GTDB-Tk
cd gtdb-tk && docker build -t microbiomeinformatics/${NAME}.gtdb-tk:v1 .

# index fasta and pigz
cd bash && docker build -t microbiomeinformatics/${NAME}.bash:v1 .

# IPS
cd IPS && docker build -t microbiomeinformatics/${NAME}.interproscan:v1 .

# mash2nwk
cd mash2nwk && docker build -t microbiomeinformatics/${NAME}.mash2nwk:v1 .

# mmseqs
cd  mmseqs && docker build -t microbiomeinformatics/${NAME}.mmseqs:v1 .

# panaroo
cd panaroo && docker build -t microbiomeinformatics/${NAME}.panaroo:v1 .

# prokka
cd prokka && docker build -t microbiomeinformatics/${NAME}.prokka:v1 .

# python3
cd python3_scripts && docker build -t microbiomeinformatics/${NAME}.python3:v3 .

