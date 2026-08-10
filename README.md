# MGnify genomes catalogue pipeline

[MGnify](https://www.ebi.ac.uk/metagenomics/) A pipeline to perform taxonomic and functional annotation and to generate a catalogue from a set of isolate and/or metagenome-assembled genomes (MAGs) using the workflow described in the following publication:

Gurbich TA, Almeida A, Beracochea M, Burdett T, Burgin J, Cochrane G, Raj S, Richardson L, Rogers AB, Sakharova E, Salazar GA and Finn RD. (2023) [MGnify Genomes: A Resource for Biome-specific Microbial Genome Catalogues.](https://www.sciencedirect.com/science/article/pii/S0022283623000724) <i>J Mol Biol</i>. doi: https://doi.org/10.1016/j.jmb.2023.168016

Detailed information about existing MGnify catalogues: https://docs.mgnify.org/src/docs/genome-viewer.html

### Tools used in the pipeline
| Tool/Database                                                                                    | Version          | Purpose                                                                                                                |
|--------------------------------------------------------------------------------------------------|------------------|------------------------------------------------------------------------------------------------------------------------|
| CheckM2                                                                                          | 1.1.0            | Determining genome quality                                                                                             |
| CheckM2 DB                                                                                       | V3               | DIAMOND database for CheckM2                                                                                           |
| dRep                                                                                             | 3.2.2            | Genome clustering                                                                                                      |
| Mash                                                                                             | 2.3              | Sketch for the catalogue; placement of genomes into clusters (update only); strain tree                                |
| GUNC                                                                                             | 1.0.6            | Quality control                                                                                                        |
| GUNC DB                                                                                          | 2.0.4            | Database for GUNC                                                                                                      |
| GTDB-Tk                                                                                          | 2.7.1            | Assigning taxonomy; generating alignments                                                                              |
| GTDB                                                                                             | r232             | Database for GTDB-Tk                                                                                                   |
| Prokka                                                                                           | 1.14.6           | Protein annotation                                                                                                     |
| IQ-TREE 2                                                                                        | 2.2.0.3          | Generating a phylogenetic tree                                                                                         |
| Kraken 2                                                                                         | 2.1.2            | Generating a kraken database                                                                                           |
| Bracken                                                                                          | 2.6.2            | Generating a bracken database                                                                                          |
| MMseqs2                                                                                          | 18.8cc5c         | Generating a protein catalogue; pan-genome computation for clusters ≥1000 genomes                                      |
| eggNOG-mapper                                                                                    | 2.1.11           | Protein annotation (eggNOG, KEGG, COG,  CAZy)                                                                          |
| eggNOG DB                                                                                        | 5.0.2            | Database for eggNOG-mapper                                                                                             |
| DIAMOND                                                                                          | 2.0.11           | Protein annotation (eggNOG)                                                                                            |
| InterProScan                                                                                     | 5.77-108.0       | Protein annotation (InterPro, Pfam)                                                                                    |
| kegg-pathways-completeness tool                                                                  | 1.4.3            | Computes KEGG pathway completeness                                                                                     |
| CRISPRCasFinder                                                                                  | 4.3.2            | Annotation of CRISPR arrays                                                                                            |
| AMRFinderPlus                                                                                    | 4.2.7            | Antimicrobial resistance gene annotation; virulence factors, biocide, heat, acid, and metal resistance gene annotation |
| AMRFinderPlus DB                                                                                 | 4.2 2026-03-24.1 | Database for AMRFinderPlus                                                                                             |
| antiSMASH                                                                                        | 8.0.1            | Biosynthetic gene cluster annotation                                                                                   |
| mgnify-pipelines-toolkit                                                                         | 1.5.1            | Post-process antiSMASH results                                                                                         |
| GECCO                                                                                            | 0.9.8            | Biosynthetic gene cluster annotation                                                                                   |
| SanntiS                                                                                          | 0.9.3.2          | Biosynthetic gene cluster annotation                                                                                   |
| DefenseFinder                                                                                    | 2.0.1            | Annotation of anti-phage and anti-defense systems                                                                      |
| DefenseFinder models                                                                             | 2.0.2            | Database for DefenseFinder                                                                                             |
| CasFinder                                                                                        | 3.1.0            | Database for DefenseFinder                                                                                             |
| run_dbCAN                                                                                        | 4.1.4            | Polysaccharide utilization loci prediction                                                                             |
| dbCAN DB                                                                                         | V13              | Database for run_dbCAN                                                                                                 |
| Infernal                                                                                         | 1.1.4            | RNA predictions                                                                                                        |
| tRNAscan-SE                                                                                      | 2.0.9            | tRNA predictions                                                                                                       |
| Rfam                                                                                             | 15.1             | Identification of SSU/LSU rRNA and other ncRNAs                                                                        |
| Panaroo                                                                                          | 1.3.2            | Pan-genome computation for clusters smaller than 1000 genomes                                                          |
| CGT (CELEBRIMBOR)                                                                                | 0.1.1            | Pan-genome gene frequency correction based on genome completeness                                                                      |
| Seqtk                                                                                            | 1.3              | Generating a gene catalogue                                                                                            |
| VIRify                                                                                           | 4.0.0            | Viral sequence annotation (executed as a separate step and uses VirSorter v1)                                          |
| [Mobilome annotation pipeline](https://github.com/EBI-Metagenomics/mobilome-annotation-pipeline) | 5.0.0            | Mobilome annotation (executed as a separate step)                                                                      |
| samtools                                                                                         | 1.15             | FASTA indexing                                                                                                         |
| EukCC                                                                                            | 2.1.3            | Completeness and contamination of eukaryotic genomes                                                                   |
| BUSCO                                                                                            | 5.8.0            | Eukaryotic genome quality                                                                                              |
| RepeatModeler                                                                                    | 2.0.6            | Identification of repeat elements in eukaryotic genomes                                                                |
| RepeatMasker                                                                                     | 4.1.7            | Repeat masking in eukaryotic genomes                                                                                   |
| Braker                                                                                           | 3.0.8            | Gene calling in eukaryotic genomes                                                                                     |

## Setup

### Environment

The pipeline is implemented in [Nextflow](https://www.nextflow.io/).

Requirements:
- [singulairty](https://sylabs.io/docs/) or [docker](https://www.docker.com/)

#### Reference databases

The pipeline needs the following reference databases and configuration files (roughtly ~150G):

- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/gunc_db_2.0.4.dmnd.gz
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/eggnog_db_5.0.2.tgz
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/rfam_15.0/
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/kegg_classes.tsv
- ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/genomes-pipeline/continent_countries.csv
- https://data.ace.uq.edu.au/public/gtdb/data/releases/release226/226.0/auxillary_files/gtdbtk_package/full_package/gtdbtk_r226_data.tar.gz
- ftp://ftp.ncbi.nlm.nih.gov/pathogen/Antimicrobial_resistance/AMRFinderPlus/database/3.12/2024-01-31.1/
- https://zenodo.org/records/4626519/files/uniref100.KO.v1.dmnd.gz

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

## Execution

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
--preassigned_accessions=<path to file with preassigned accessions if using>
--catalogue_name=zebrafish-faecal \
--catalogue_version="1.0" \
--ftp_name="zebrafish-faecal" \
--ftp_version="v1.0" \
--outdir="<path-to-results>"
```

## Catalogue update process

The pipeline has an update functionality, triggered by the `--update_catalogue_path` argument. The update process
performs the following:
- removes genomes (if a list of accessions to remove is provided or any of the existing genomes are no longer present in the ENA or fail QC)
- adds genomes (if a list of genomes to add is specified)
- reannotates new and existing genomes and recomputes associated databases (in all cases)

While a regular pipeline execution uses dRep to cluster genomes, **the clustering during the update process is different in the following ways**:

- existing clustering from the previous catalogue version is preserved 
- the genomes that are flagged for removal (by the user or the pipeline) are removed without disrupting the existing clusters
- if new genomes are being added, their placement is determined using [Mash](https://github.com/marbl/Mash) and the following rules:
  1. if the smallest Mash distance between the new genome and any of the existing catalogue genomes is less than 0.001, the new genome is classified as a repeat strain
  2. if the smallest distance is greater than 0.05, the new genome is classified as a new species
  3. all other new genomes are classified as new strains
  4. a repeat strain is only added to the catalogue in the following cases: 1) if it is an isolate while the closest match in the catalogue is a MAG OR 2) if the quality improvement of the new strain compared to the one in the catalogue is at least 10% (see notes on quality comparison below)
  5. new strains and new species are always added to the catalogue, as long as they pass the general quality control checks used for new genomes

### Quality comparisons for new genomes
During the catalogue cluster update process, the quality scores for all genomes are calculated as:  
`QS = % completeness – 5 * % contamination + 0.5 * log(N50)`  
A 10% quality improvement is computed as `threshold = QS * 1.1`.  
The quality score improvement is used to decide:
- if a repeat strain should be added to the catalogue
- if the species representative genome should be re-assigned.

For threshold values <= 100, the highest quality genome above the threshold is chosen as the new representative.  
If threshold > 100, the decision process changes to prioritise genome contiguity. The species representative is replaced if there is a genome that satisfies the following conditions:
- QS and completeness is same or higher than the existing rep
- Contamination is the same or less than the existing rep
- N50 is at least 10% AND 10,000bp higher than that of the existing species rep (to account for small increases to an already low N50 - only a significant increase should justify a replacement)
- The length of the new representative should be at least 90% of the length of the old represenative

An isolate genome is always prioritised over a MAG. That means, if the current representative is an isolate, it can only be replaced with a better quality isolate. If the current species rep is a MAG and an isolate has been added to the cluster, a species representative replacement will be made even if the new genome has lower quality.


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
