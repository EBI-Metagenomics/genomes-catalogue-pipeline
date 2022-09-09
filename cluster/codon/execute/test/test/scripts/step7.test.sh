#!/bin/bash

bsub \
    -J "Step7.metadata.test.submit" \
    -q standard \
    -e /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step7.metadata.err \
    -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step7.metadata.out \
    bash /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline//cluster/codon/execute/steps/7_metadata.sh \
    -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test \
    -p /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/ \
    -l /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs/ \
    -n test \
    -q standard \
    -y /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/ymls \
    -v v1.0 \
    -i /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/test_drep/intermediate_files \
    -g /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/gtdbtk/gtdbtk-outdir \
    -r /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/test_annotations/rRNA_outs \
    -j Step7.metadata \
    -f /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/mgyg_genomes \
    -s "" \
    -z 5G \
    -t 1

