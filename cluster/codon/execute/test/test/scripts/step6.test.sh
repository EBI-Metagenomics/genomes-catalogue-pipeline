#!/bin/bash

bsub \
    -J "Step6.annotation.test.submit" \
    -q standard \
    -e /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step6.annotation.err \
    -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step6.annotation.out \
    bash /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline//cluster/codon/execute/steps/6_annotation.sh \
    -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test \
    -p /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/ \
    -l /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs/ \
    -n test \
    -q standard \
    -y /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/ymls \
    -i /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/test_mmseqs_0.90/mmseqs_0.9_outdir \
    -r /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/cluster_reps.txt \
    -j Step6.annotation \
    -b /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/mgyg_genomes \
    -z 50G \
    -t 16 \
    -w "True"

