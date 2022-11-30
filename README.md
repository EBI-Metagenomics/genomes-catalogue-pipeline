# MGnify genome analysis pipeline

[MGnify](https://www.ebi.ac.uk/metagenomics/) Pipeline to characterize a set of isolate or metagenome-assembled genomes (MAGs) using the workflow described in the following publication: 

A Almeida, S Nayfach, M Boland, F Strozzi, M Beracochea, ZJ Shi, KS Pollard, E Sakharova, DH Parks, P Hugenholtz, N Segata, NC Kyrpides and RD Finn. (2020) [A unified catalog of 204,938 reference genomes from the human gut microbiome.](https://www.nature.com/articles/s41587-020-0603-3) <i>Nature Biotechnol</i>. doi: https://doi.org/10.1038/s41587-020-0603-3

Detail information about existing MGnify catalogues: https://docs.mgnify.org/en/latest/genome-viewer.html#

## Setup 

### Environment

The pipeline is partially implemented in [CWL](https://www.commonwl.org/) and bash scripts. At the moment is meant to be used with the [LSF scheduler](https://en.wikipedia.org/wiki/IBM_Spectrum_LSF).

Requirements:
- bash
- [cwltool](https://github.com/common-workflow-language/cwltool)
- [toil-cwl](https://toil.readthedocs.io/en/3.10.1/gettingStarted/install.html)
- [docker](https://www.docker.com/) or [singulairty](https://sylabs.io/docs/)

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

## Running the pipeline

1. You need to pre-download your data to directoryes and make sure that all genomes are not compressed. If you have downloaded genomes from ENA and NCBI put them into different folders. If you've downloaded genomes from ENA save output CSV file with ENA genomes.

2. You will need the following information to create YML:
 - catalogue name (for example, GUT)
 - catalogue version (for example, v1.0)
 - catalogue biom (for example, Human:Gut)
 - min amd max number of accessions (only MGnify specific). Max - Min = #total number of genomes (NCBI+ENA)


# Instructions how to run genomes-pipeline

### Description

Bash script *run.sh* runs basic steps as depending lsf jobs.

There are 9 steps:
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

1) Prepare the input files and configuration files
  a) Download the databases using the [download_db.sh](installation/download_db.sh)
  b) Remove the .tpl from the templates in [src/templates](src/templates) and replace the paths accordigly
  c) Create a .gpenv file in the root of the folder that contains this repo. Use [.gpenv.tpl](.gpenv.tpl) as a template
2) Prepare genomes.csv file (make sure it has a header: genome,completeness,contamination)
3) Run the [run.sh](src/run.sh) script

```
bash run.sh \
  -p <path to genomes pipeline source code> \
  -n catalogue_name \
  -o <path to output directory> \
  -f <path to genomes folder> \
  -c <path to genomes.csv> \
  -x <min MGYG> \
  -m <max MGYG> \
  -v <version ex. "v1.0"> \
  -b <biom ex. "Test:test">
```
