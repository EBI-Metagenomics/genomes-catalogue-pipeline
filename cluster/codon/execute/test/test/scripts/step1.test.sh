#!/bin/bash

bash /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline//cluster/codon/execute/steps/1_drep.sh \
    -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test \
    -p /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/ \
    -l /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs/ \
    -n test \
    -q standard \
    -y /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/ymls \
    -i "" \
    -c "" \
    -m "" \
    -x "" \
    -j Step1.drep \
    -z 50G \
    -t 16
