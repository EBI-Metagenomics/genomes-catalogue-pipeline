# MGnify genome analysis pipeline

[MGnify](https://www.ebi.ac.uk/metagenomics/) Pipeline to characterize a set of isolate or metagenome-assembled genomes (MAGs) using the workflow described in the following publication: 

A Almeida, S Nayfach, M Boland, F Strozzi, M Beracochea, ZJ Shi, KS Pollard, E Sakharova, DH Parks, P Hugenholtz, N Segata, NC Kyrpides and RD Finn. (2020) [A unified catalog of 204,938 reference genomes from the human gut microbiome.](https://www.nature.com/articles/s41587-020-0603-3) <i>Nature Biotechnol</i>. doi: https://doi.org/10.1038/s41587-020-0603-3

Detail information about existing MGnify catalogues: https://docs.mgnify.org/en/latest/genome-viewer.html#

# NOTE

We are working to make this pipeline portable and reproducible outside EMBL-EBI infrastructure.

## Setup 

### Environment

The pipeline is partially implemented in [CWL](https://www.commonwl.org/) and bash scripts. At the moment is meant to be used with the [LSF scheduler](https://en.wikipedia.org/wiki/IBM_Spectrum_LSF).

Requirements:
- bash
- [cwltool](https://github.com/common-workflow-language/cwltool)
- [toil-cwl](https://toil.readthedocs.io/en/3.10.1/gettingStarted/install.html)
- [singulairty](https://sylabs.io/docs/)

The current implementation uses CWL version 1.2.

#### Reference databases

The pipeline needs the following reference databases and configuration files (roughtly ~150G):

- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/gunc_db_2.0.4.dmnd.gz
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/eggnog_db.tgz
- https://data.gtdb.ecogenomic.org/releases/release207/207.0/gtdbtk_data.tar.gz
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/rfams_cms/
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/kegg_classes.tsv
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/ncrna/
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/continent_countries.csv

To download the files, use the script [download_dbs.sh](bin/download_dbs.sh).

### Containers

This pipeline requires [singularity](https://sylabs.io/docs/) as the container engine to run pipeline.

All the docker containers are stored in [quay.io/microbiome-informatics](https://quay.io/organization/microbiome-informatics) repository.

It's possible to build the containers from scratch using the following script:

```bash
cd containers && bash build.sh
```

## Running the pipeline

1. You need to pre-download your data to directoryes and make sure that all genomes are not compressed. If you have downloaded genomes from ENA and NCBI put them into different folders. If you've downloaded genomes from ENA save output CSV file with ENA genomes.

2. You will need the following information to create YML:
 - catalogue name (for example, GUT)
 - catalogue version (for example, v1.0)
 - catalogue biom (for example, Human:Gut)
 - min amd max number of accessions (only MGnify specific). Max - Min = #total number of genomes (NCBI+ENA)

### Step by step execution

At this stage the pipeline is designed to run as a set of scripts that have to be manually executed.

The entry point is [run.sh](src/run.sh). This script will create the required folders and step bash scripts to run the pipeline:

```bash
$ bash run.sh \
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

#### Example

```bash
```