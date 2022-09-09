#!/bin/bash

bsub \
    -J "Step4.mmseqs.test.submit" \
    -w "ended(Step3.clusters.test.*)" \
    -q standard \
    -e /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step4.mmseqs.err \
    -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step4.mmseqs.out     bash /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline//cluster/codon/execute/steps/4_mmseqs.sh \
        -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test \
        -p /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/ \
        -l /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs/ \
        -n test \
        -q standard \
        -y /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/ymls \
        -j Step4.mmseqs \
        -r /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/cluster_reps.txt \
        -f /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/drep-filt-list.txt \
        -a /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/reps_fa \
        -k /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/mgyg_genomes \
        -d /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/test_drep \
        -z 150G \
        -t 32
