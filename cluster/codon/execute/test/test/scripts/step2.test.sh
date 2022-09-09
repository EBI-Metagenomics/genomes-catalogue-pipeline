#!/bin/bash

# -w "ended(Step1.drep.test)" \ TODO: remove

bsub \
    -J "Step2.mash.test.submit" \
    -q standard \
    -e /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step2.mash.err \
    -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step2.mash.out \
    bash /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline//cluster/codon/execute/steps/2_mash.sh \
        -m /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/test_drep/mash \
        -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test \
        -p /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/ \
        -l /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs/ \
        -n test \
        -q standard \
        -y /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/ymls \
        -j Step2.mash \
        -z 10G \
        -t 4
