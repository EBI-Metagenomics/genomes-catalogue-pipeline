#!/bin/bash

bsub \
    -J "Step9.restructure.test.submit" \
    -q standard \
    -e /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step9.restructure.err \
    -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step9.restructure.out \
    bash /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline//cluster/codon/execute/steps/9_restructure.sh \
    -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test \
    -n test

