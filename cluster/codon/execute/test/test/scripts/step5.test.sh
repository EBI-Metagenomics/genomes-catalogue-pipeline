#!/bin/bash

bsub \
    -J "Step5.gtdbtk.test.submit" \
    -q standard \
    -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step5.gtdbtk.out \
    -e /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step5.gtdbtk.err \
    bash /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline//cluster/codon/execute/steps/5_sing_gtdbtk.sh \
        -q bigmem \
        -p /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/ \
        -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test \
        -l /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs/ \
        -n test \
        -y /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/ymls \
        -j Step5.gtdbtk \
        -a /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/reps_fa \
        -z 500G \
        -t 2

