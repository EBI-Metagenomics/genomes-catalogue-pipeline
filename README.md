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
- [toil-cwl](https://toil.readthedocs.io/l) - >= 5.7.1
- [cwltool](https://github.com/common-workflow-language/cwltool)
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

1. You need to pre-download your data to directories and make sure that all genomes are not compressed. Scripts to fetch genomes from ENA ([fetch_ena.py](https://github.com/EBI-Metagenomics/genomes-pipeline/blob/master/containers/genomes-catalog-update/scripts/fetch_ena.py)) and NCBI ([fetch_ncbi.py](https://github.com/EBI-Metagenomics/genomes-pipeline/blob/master/containers/genomes-catalog-update/scripts/fetch_ncbi.py)) are provided and need to be executed separately from the pipeline. If you have downloaded genomes from both ENA and NCBI put them into different folders.

2. When genomes are fetched from ENA using the `fetch_ena.py` script, a CSV file with contamination and completeness statistics is also created in the same directory where genomes are saved to. If you are downloading genomes differently, a CSV file needs to be created manually (each line should be genome accession, % completeness, % contamination). The ENA fetching script also pre-filters genomes to satisfy the QS50 cut-off (QS = % completeness - 5 * % contamination). If you obtain genomes from NCBI or another source, pre-filtering needs to be done before starting the pipeline unless lower quality genomes are acceptable in the final catalogue. The pipeline will automatically remove genomes with completeness <50% and/or contamination >5%.

3. You will need the following information to create YML:
 - catalogue name (for example, GUT)
 - catalogue version (for example, 1.0)
 - catalogue biome (for example, root:Host-associated:Human:Digestive system:Large intestine:Fecal)
 - min and max number of accessions (only MGnify specific). Max - Min = #total number of genomes (NCBI+ENA)

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
  -v <version ex. "1.0"> \
  -b <biom ex. "Test:test">
```

#### Example

```bash
./run.sh \
  -p $(pwd) \
  -n test_catalogue \
  -o $(pwd)/test_output \
  -f $(pwd)/test_input \
  -c $(pwd)/test_input/input_genomes.csv \
  -x 1 \
  -m 1000 \
  -v "v1.0" \
  -b "Test:test"

==== 1. dRep steps with cwltool [/test_output/test_catalogue/scripts/step1.test_catalogue.sh] ====
==== 2. mash2nwk submission script [/test_output/test_catalogue/scripts/step2.test_catalogue.sh] ====
==== 3. Cluster annotation [/test_output/test_catalogue/scripts/step3.test_catalogue.sh] ====
==== 4. mmseqs [/test_output/test_catalogue/scripts/step4.test_catalogue.sh] ====
==== 5. GTDB-Tk [/test_output/test_catalogue/scripts/step5.test_catalogue.sh] ====
==== 6. EggNOG, IPS, rRNA [/test_output/test_catalogue/scripts/step6.test_catalogue.sh] ====
==== 6a. Sanntis [/test_output/test_catalogue/scripts/step6a.test_catalogue.sh] ====
==== 7. Metadata and phylo.tree [/test_output/test_catalogue/scripts/step7.test_catalogue.sh] ====
==== 8. Post-processing [/test_output/test_catalogue/scripts/step8.test_catalogue.sh] ====
==== 9. Databases [/test_output/test_catalogue/scripts/step9.test_catalogue.sh] ====
==== 10. Re-structure [/test_output/test_catalogue/scripts/step10.test_catalogue.sh] ====
==== Final. Exit ====
```
