# MGnify genomes analysis pipeline

[MGnify](https://www.ebi.ac.uk/metagenomics/) Pipeline to characterize a set of isolate or metagenome-assembled genomes (MAGs) using the workflow described in the following publication:

A Almeida, S Nayfach, M Boland, F Strozzi, M Beracochea, ZJ Shi, KS Pollard, E Sakharova, DH Parks, P Hugenholtz, N Segata, NC Kyrpides and RD Finn. (2020) [A unified catalog of 204,938 reference genomes from the human gut microbiome.](https://www.nature.com/articles/s41587-020-0603-3) <i>Nature Biotechnol</i>. doi: https://doi.org/10.1038/s41587-020-0603-3

Detail information about existing MGnify catalogues: https://docs.mgnify.org/en/latest/genome-viewer.html#

## Setup

### Environment

The pipeline is implemented in [Nextflow](https://www.nextflow.io/).

Requirements:
- [singulairty](https://sylabs.io/docs/) or [docker](https://www.docker.com/)

#### Reference databases

The pipeline needs the following reference databases and configuration files (roughtly ~150G):

- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/gunc_db_2.0.4.dmnd.gz
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/eggnog_db.tgz
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/rfams_cms/
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/kegg_classes.tsv
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/ncrna/
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/continent_countries.csv
- https://data.gtdb.ecogenomic.org/releases/release207/207.0/gtdbtk_data.tar.gz

### Containers

This pipeline requires [singularity](https://sylabs.io/docs/) or [docker](https://www.docker.com/) as the container engine to run pipeline.

The containers are hosted in [biocontainers](https://biocontainers.pro/) and [quay.io/microbiome-informatics](https://quay.io/organization/microbiome-informatics) repository.

It's possible to build the containers from scratch using the following script:

```bash
cd containers && bash build.sh
```

## Running the pipeline

## Data preparation

1. You need to pre-download your data to directories and make sure that all genomes are not compressed. Scripts to fetch genomes from ENA ([fetch_ena.py](https://github.com/EBI-Metagenomics/genomes-pipeline/blob/master/containers/genomes-catalog-update/scripts/fetch_ena.py)) and NCBI ([fetch_ncbi.py](https://github.com/EBI-Metagenomics/genomes-pipeline/blob/master/containers/genomes-catalog-update/scripts/fetch_ncbi.py)) are provided and need to be executed separately from the pipeline. If you have downloaded genomes from both ENA and NCBI put them into different folders.

2. When genomes are fetched from ENA using the `fetch_ena.py` script, a CSV file with contamination and completeness statistics is also created in the same directory where genomes are saved to. If you are downloading genomes differently, a CSV file needs to be created manually (each line should be genome accession, % completeness, % contamination). The ENA fetching script also pre-filters genomes to satisfy the QS50 cut-off (QS = % completeness - 5 * % contamination). If you obtain genomes from NCBI or another source, pre-filtering needs to be done before starting the pipeline unless lower quality genomes are acceptable in the final catalogue. The pipeline will automatically remove genomes with completeness <50% and/or contamination >5%.

3. You will need the following information to create YML:
 - catalogue name (for example, GUT)
 - catalogue version (for example, 1.0)
 - catalogue biome (for example, root:Host-associated:Human:Digestive system:Large intestine:Fecal)
 - min and max number of accessions (only MGnify specific). Max - Min = #total number of genomes (NCBI+ENA)

### Execution

The pipeline is built in [Nextflow](https://www.nextflow.io), and utilized containers to run the software (we don't support conda ATM).
In order to run the pipeline it's required that the user creates a profile that suits their needs, there is an `ebi` profile in `nexflow.config` that can be used as tempalte.

After downloading the databases and adjusting the config file:

```bash
nextflow run EBI-Metagenomics/genomes-pipeline -c <custom.config> -profile <profile> \
--genome-prefix=MGYG \
--biome="root:Host-associated:Fish:Digestive system" \
--ena_genomes=<path to genomes> \
--ena_genomes_checkm=<path to genomes quality data> \
--mgyg_start=0 \
--mgyg_end=10 \
--catalogue_name=zebrafish \
--catalogue_version="1.0" \
--ftp_name="zebrafish" \
--ftp_version="v1.0" \
--outdir="<path-to-results>"
```

### Development

Install development tools (including pre-commit hooks to run Black code formatting).

```bash
pip install -r requirements-dev.txt
pre-commit install
```

#### Code style

Use Black, this tool is configured if you install the pre-commit tools as above.

To manually run them: black .

### Testing

This repo has 2 set of tests, python unit tests for some of the most critial python scripts and [nf-test](https://github.com/askimed/nf-test) scripts for the nextflow code.

To run the python tests

```bash
pip install -r requirements-test.txt
pytest
```

To run the nextflow ones the databases have to downloaded manually, we are working to improve this.

```bash
nf-test test tests/*
```
