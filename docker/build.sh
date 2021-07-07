#!/bin/bash

export NAME=genomes-pipeline

# checkm
cd  checkm && docker build -t microbiomeinformatics/${NAME}.checkm:v1.1.3 .

# drep [ pushed ]
cd drep && docker build -t microbiomeinformatics/${NAME}.drep:v1 .

# eggnog
cd eggnong && docker build -t microbiomeinformatics/${NAME}.eggnog:v1 .

# genome-catalog-update [ pushed ]
cd genome-catalog-update && docker build -t microbiomeinformatics/${NAME}.genome-catalog-update:v1 .

# mmseqs
cd  mmseqs && docker build -t microbiomeinformatics/${NAME}-mmseqs:v1 .

# python3
cd python3_scripts && docker build -t microbiomeinformatics/${NAME}.python3:v1 .

# python3
cd GUNC && docker build -t microbiomeinformatics/${NAME}.gunc:v1 .