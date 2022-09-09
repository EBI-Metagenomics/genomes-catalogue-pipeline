#!/bin/bash

# -w "ended(Step1.drep.test)" TODO: remove

bsub \
    -J "Step3.clusters.test.sg" \
    -q standard \
    -e /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step3.clusters.sg.err \
    -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step3.clusters.sg.out \
    bash /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline//cluster/codon/execute/steps/3_process_clusters.sh \
        -i /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/test_drep/singletons \
        -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test \
        -p /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/ \
        -t 'sg' \
        -l /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs/ \
        -n test \
        -q standard \
        -y /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/ymls \
        -j Step3.clusters \
        -s "" \
        -z 50G \
        -w 8
# -w "ended(Step2.mash.test.*)" TODO: remove

bsub \
    -J "Step3.clusters.test.pg"     -q standard     -e /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step3.clusters.pg.err     -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs//submit.Step3.clusters.pg.out     bash /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline//cluster/codon/execute/steps/3_process_clusters.sh         -i /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/test_drep/pan-genomes         -o /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test         -p /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/         -t 'pg'         -l /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/logs/         -n test         -q standard         -y /home/mbc/projects/genomes-pipeline/cluster/codon/execute/test/test/ymls         -j Step3.clusters         -s ""         -z 50G         -w 8
