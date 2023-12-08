# MGnify genomes analysis pipeline

[MGnify](https://www.ebi.ac.uk/metagenomics/) A pipeline to perform taxonomic and functional annotation and to generate a catalogue from a set of isolate and/or metagenome-assembled genomes (MAGs) using the workflow described in the following publication:

Gurbich TA, Almeida A, Beracochea M, Burdett T, Burgin J, Cochrane G, Raj S, Richardson L, Rogers AB, Sakharova E, Salazar GA and Finn RD. (2023) [MGnify Genomes: A Resource for Biome-specific Microbial Genome Catalogues.](https://www.sciencedirect.com/science/article/pii/S0022283623000724) <i>J Mol Biol</i>. doi: https://doi.org/10.1016/j.jmb.2023.168016

Detailed information about existing MGnify catalogues: https://docs.mgnify.org/src/docs/genome-viewer.html

### Tools used in the pipeline
| Tool/Database                    | Version          | Purpose |
|----------------------------------|------------------|----------- |
| CheckM                           | 1.1.3            | Determining genome quality       |
| dRep                             | 3.2.2            | Genome clustering       |
| Mash                             | 2.3              | Sketch for the catalogue; placement of genomes into clusters (update only); strain tree      |
| GUNC                             | 1.0.3            | Quality control       |
| GUNC DB                          | 2.0.4            | Database for GUNC       |
| GTDB-Tk                          | 2.3.0            | Assigning taxonomy; generating alignments       |
| GTDB                             | r214             | Database for GTDB-Tk       |
| Prokka                           | 1.14.6           | Protein annotation       |
| IQ-TREE 2                        | 2.2.0.3          | Generating a phylogenetic tree       |
| Kraken 2                         | 2.1.2            | Generating a kraken database       |
| Bracken                          | 2.6.2            | Generating a bracken database       |
| MMseqs2                          | 13.45111         | Generating a protein catalogue       |
| eggNOG-mapper                    | 2.1.11           | Protein annotation (eggNOG, KEGG, COG,  CAZy)       |
| eggNOG DB                        | 5.0              | Database for eggNOG-mapper       |
| Diamond                          | 2.0.11           | Protein annotation (eggNOG)       |
| InterProScan                     | 5.62-94.0        | Protein annotation (InterPro, Pfam)       |
| CRISPRCasFinder                  | 4.3.2            | Annotation of CRISPR arrays       |
| AMRFinderPlus                    | 3.11.4           |   Antimicrobial resistance gene annotation; virulence factors, biocide, heat, acid, and metal resistance gene annotation     |
| AMRFinderPlus DB                 | 3.11 2023-02-23.1 | Database for AMRFinderPlus      |
| SanntiS                          | 0.9.3.2          | Biosynthetic gene cluster annotation       |
| Infernal                         | 1.1.4            | RNA predictions       |
| tRNAscan-SE                      | 2.0.9            | tRNA predictions       |
| Rfam                             | 14.9             | Identification of SSU/LSU rRNA and other ncRNAs       |
| Panaroo                          | 1.3.2            | Pan-genome computation       |
| Seqtk                            | 1.3              | Generating a gene catalogue       |
| VIRify                           | 2.0.0            | Viral sequence annotation       |
| [Mobilome annotation pipeline](https://github.com/EBI-Metagenomics/mobilome-annotation-pipeline) | 2.0.0-rc.1       | Mobilome annotation       |
| samtools                         | 1.15             | FASTA indexing       |

## Setup

### Environment

The pipeline is implemented in [Nextflow](https://www.nextflow.io/).

Requirements:
- [singulairty](https://sylabs.io/docs/) or [docker](https://www.docker.com/)

#### Reference databases

The pipeline needs the following reference databases and configuration files (roughtly ~150G):

- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/gunc_db_2.0.4.dmnd.gz
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/eggnog_db.tgz
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/rfam_14.9/
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/kegg_classes.tsv
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/continent_countries.csv
- https://data.ace.uq.edu.au/public/gtdb/data/releases/release214/214.0/auxillary_files/gtdbtk_r214_data.tar.gz
- ftp://ftp.ncbi.nlm.nih.gov/pathogen/Antimicrobial_resistance/AMRFinderPlus/database/3.11/2023-02-23.1

### Containers

This pipeline requires [singularity](https://sylabs.io/docs/) or [docker](https://www.docker.com/) as the container engine to run pipeline.

The containers are hosted in [biocontainers](https://biocontainers.pro/) and [quay.io/microbiome-informatics](https://quay.io/organization/microbiome-informatics) repository.

It's possible to build the containers from scratch using the following script:

```bash
cd containers && bash build.sh
```

## Running the pipeline

## Data preparation

1. You need to pre-download your data to directories and make sure that genomes are uncompressed. Scripts to fetch genomes from ENA ([fetch_ena.py](https://github.com/EBI-Metagenomics/genomes-pipeline/blob/master/bin/fetch_ena.py)) and NCBI ([fetch_ncbi.py](https://github.com/EBI-Metagenomics/genomes-pipeline/blob/master/bin/fetch_ncbi.py)) are provided and need to be executed separately from the pipeline. If you have downloaded genomes from both ENA and NCBI, put them into separate folders.

2. When genomes are fetched from ENA using the `fetch_ena.py` script, a CSV file with contamination and completeness statistics is also created in the same directory where genomes are saved to. If you are downloading genomes using a different approach, a CSV file needs to be created manually (each line should be genome accession, % completeness, % contamination). The ENA fetching script also pre-filters genomes to satisfy the QS50 cut-off (QS = % completeness - 5 * % contamination).

3. You will need the following information to run the pipeline:
 - catalogue name (for example, zebrafish-faecal)
 - catalogue version (for example, 1.0)
 - catalogue biome (for example, root:Host-associated:Human:Digestive system:Large intestine:Fecal)
 - min and max accession number to be assigned to the genomes (only MGnify specific). Max - Min = #total number of genomes (NCBI+ENA)

### Execution

The pipeline is built in [Nextflow](https://www.nextflow.io), and utilized containers to run the software (we don't support conda ATM).
In order to run the pipeline it's required that the user creates a profile that suits their needs, there is an `ebi` profile in `nexflow.config` that can be used as template.

After downloading the databases and adjusting the config file:

```bash
nextflow run EBI-Metagenomics/genomes-pipeline -c <custom.config> -profile <profile> \
--genome-prefix=MGYG \
--biome="root:Host-associated:Fish:Digestive system" \
--ena_genomes=<path to genomes> \
--ena_genomes_checkm=<path to genomes quality data> \
--mgyg_start=0 \
--mgyg_end=10 \
--catalogue_name=zebrafish-faecal \
--catalogue_version="1.0" \
--ftp_name="zebrafish-faecal" \
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

This repo has 2 set of tests, python unit tests for some of the most critical python scripts and [nf-test](https://github.com/askimed/nf-test) scripts for the nextflow code.

To run the python tests

```bash
pip install -r requirements-test.txt
pytest
```

To run the nextflow ones the databases have to downloaded manually, we are working to improve this.

```bash
nf-test test tests/*
```
