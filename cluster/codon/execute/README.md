# Instructions how to run genomes-pipeline with bash script on CODON

### Description

Bash script *run.sh* runs basic steps as depending lsf jobs.
There are 8 steps:
- data preparation + dRep
- mash2nwk
- process clusters (in parallel by each cluster)
- mmseqs (in parallel by each limit_i)
- GTDB-Tk
- annotations (EggNOG, IPS, rRNA)
- metadata + phylo.tree generation
- post-processing (as one job for all clusters) : kegg, cog,.. , genome.json, gff population

Each step runs submit job first. Each submit job generates input yml-file and runs cwltool.

### How to run

1) Prepare folder with genomes 
2) Prepare genomes.csv file (make sure it has a header: genome,completeness,contamination)
3) Fill in command
(no need to run this as separate bsub)
```
bash run.sh \
  -p <path to genomes pipeline installation (make sure that branch is correct)> \
  -n test_oral \
  -o <path to output directory> \
  -f <path to genomes folder> \
  -c <path to genomes.csv> \
  -x <min MGYG> \
  -m <max MGYG> \
  -v <version ex. "v1.0"> \
  -b <biom ex. "Test:test">
```

### Logging
Basic run.sh logging:
```
==== 1. Run preparation and dRep steps with cwltool ====
Submitting dRep
Creating yml for drep
Running dRep
Job <> is submitted to queue <>.
==== 2. Run mash2nwk ====
Submitting mash
Job <> is submitted to queue <>.
==== 3. Run cluster annotation ====
Submitting pan-genomes
Job <> is submitted to queue <>.
Submitting singletons
Job <> is submitted to queue <>.
==== 4. Run mmseqs ====
Job <> is submitted to queue <>.
==== 5. Run GTDB-Tk ====
Submitting GTDB-Tk
Job <> is submitted to queue <>.
==== 6. EggNOG, IPS, rRNA ====
Submitting annotation
Job <> is submitted to queue <>.
==== 7. Metadata and phylo.tree ====
Submitting metadata and phylo.tree generation
Job <> is submitted to queue <>.
==== 8. Post-processing ====
Submitting post-processing
Job <> is submitted to queue <>.
==== Final ====
```

Log files: < path to output directory >/logs
  
Yml files: < path to output directory >/ymls
