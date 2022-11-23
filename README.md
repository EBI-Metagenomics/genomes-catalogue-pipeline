# MGnify genome analysis pipeline

[MGnify](https://www.ebi.ac.uk/metagenomics/) Pipeline to characterize a set of isolate or metagenome-assembled genomes (MAGs) using the workflow described in the following publication: 

A Almeida, S Nayfach, M Boland, F Strozzi, M Beracochea, ZJ Shi, KS Pollard, E Sakharova, DH Parks, P Hugenholtz, N Segata, NC Kyrpides and RD Finn. (2020) [A unified catalog of 204,938 reference genomes from the human gut microbiome.](https://www.nature.com/articles/s41587-020-0603-3) <i>Nature Biotechnol</i>. doi: https://doi.org/10.1038/s41587-020-0603-3

Detail information about existing MGnify catalogues: https://docs.mgnify.org/en/latest/genome-viewer.html#

## Pipeline

![Pipeline overview](pipeline_overview.png)

UPDATE

## Setup 

### Environment

The pipeline is partially implemented in [CWL](https://www.commonwl.org/) and bash scripts. At the moment is meant to be used with the [LSF scheduler](https://en.wikipedia.org/wiki/IBM_Spectrum_LSF).

Requirements:
- bash
- [cwltool](https://github.com/common-workflow-language/cwltool)
- [toil-cwl](https://toil.readthedocs.io/en/3.10.1/gettingStarted/install.html)
- [docker](https://www.docker.com/) or (singulairty)[https://sylabs.io/docs/]

The current implementation uses CWL version 1.2.

#### Reference databases

The pipeline needs the following reference databases and configuration files (roughtly ~150G):

- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/gunc_db_2.0.4.dmnd.gz
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/eggnog_db.tgz
- https://data.gtdb.ecogenomic.org/releases/latest/auxillary_files/gtdbtk_data.tar.gz
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/rfams_cms/
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/kegg_classes.tsv
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/ncrna/

To download the files, use the script (download_db.sh)[installation/download_db.sh].

### Containers

Our team recommend to use [docker](https://www.docker.com/) or [singularity](PATH) as the container engine to run pipeline.

All the docker containers are stored in [quay.io/microbiome-informatics](https://quay.io/organization/microbiome-informatics) repository.

It's possible to build the containers from scratch using the following script:

```bash
cd containers && bash build.sh
```

<!-- ### Add custom python3 scripts to PATH
```bash
export PATH=${PATH}:docker/python3_scripts:docker/genomes-catalog-update/scripts
``` -->

## Run

**Note 1**: You can manually change parameters of MMseqs2 for protein clustering in your YML file (arguments mmseqs_limit_i, mmseq_limit_annotation, mmseqs_limit_c)</b>

**Note 2**: Pipeline currently doesn't support GTDB-Tk and will skip this step. 

1. You need to pre-download your data to directory/ies and make sure that all genomes are not compressed. If you have downloaded genomes from ENA and NCBI put them into different folders. If you've downloaded genomes from ENA save output CSV file with ENA genomes.

2. You will need the following information to create YML:
 - catalogue name (for example, GUT)
 - catalogue version (for example, v1.0)
 - catalogue biom (for example, Human:Gut)
 - min amd max number of accessions (only MGnify specific). Max - Min = #total number of genomes (NCBI+ENA)


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
