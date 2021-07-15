# MGnify genome analysis pipeline

MGnify CWL pipeline to characterize a set of isolate or metagenome-assembled genomes (MAGs) using the workflow described in the following publication: 

A Almeida, S Nayfach, M Boland, F Strozzi, M Beracochea, ZJ Shi, KS Pollard, E Sakharova, DH Parks, P Hugenholtz, N Segata, NC Kyrpides and RD Finn. (2020) [A unified catalog of 204,938 reference genomes from the human gut microbiome.](https://www.nature.com/articles/s41587-020-0603-3) <i>Nature Biotechnol</i>. doi: https://doi.org/10.1038/s41587-020-0603-3

## Installation with Docker

1. Install all necessary tools:
- [cwltool](https://github.com/common-workflow-language/cwltool) (tested v1.0.2)
- [Docker](https://www.docker.com/)
- [conda](https://docs.conda.io/en/latest/)
- run installation script 
```bash
bash installation/install.sh
```

## Installation without Docker

1. Install the necessary dependencies:
- [cwltool](https://github.com/common-workflow-language/cwltool) (tested v1.0.2)
- [R](https://www.r-project.org/) (tested v3.5.2). Packages: reshape2, fastcluster, optparse, data.table and ape.
- [Python](https://www.python.org/) v2.7 and v3.6
- [CheckM](https://github.com/Ecogenomics/CheckM) (tested v1.0.11)
- [CAT](https://github.com/dutilh/CAT) (tested v5.0)
- [GTDB-Tk](https://github.com/Ecogenomics/GTDBTk) (tested v0.3.1 and v1.0.2)
- [dRep](https://drep.readthedocs.io/en/latest/) (tested v2.2.4)
- [Prokka](https://github.com/tseemann/prokka) (tested 1.14.0)
- [MMseqs2](https://github.com/soedinglab/MMseqs2) (tested v8-fac81)
- [InterProScan](https://github.com/ebi-pf-team/interproscan/wiki) (tested v5.35-74.0 and v5.38-76.0)
- [eggNOG-mapper](https://github.com/eggnogdb/eggnog-mapper/wiki/eggNOG-mapper-v2) (tested v2.0)

2. Make sure all these tools, as well as the <b>custom_scripts/</b> folder, are added to your `$PATH` environment.

3. Edit <b>custom_scripts/taxcheck.sh</b> to point CAT to the installed diamond and database paths (variables `$diamond_path`, `$cat_db_path` and `$cat_tax_path`)


## Download databases 
```bash
git clone https://github.com/EBI-Metagenomics/genomes-pipeline.git
cd genomes-pipeline
bash download_db.sh
```

## Run


Note: You can manually change parameters of MMseqs2 for protein clustering in <b>workflows/yml_patterns/wf-2.yml</b>

Output files/folders:
- checkm_quality.csv
- gtdb-tk_output/
- taxcheck_output/
- mmseqs_output/
- mash_trees/
- cluster__X
- cluster__...

## Pipeline structure

![Pipeline overview](pipeline_overview.png)

### Tool description
- CheckM: Estimate genome completeness and contamination.
- GTDB-Tk: Genome taxonomic assignment using the GTDB framework.
- dRep: Genome de-replication.
- Mash2Nwk: Generate Mash distance tree of conspecific genomes.
- Prokka: Predict protein-coding sequences from genome assembly.
- MMseqs2: Cluster protein-coding sequences.
- InterProScan: Protein functional annotation using the InterPro database.
- eggNOG-mapper: Protein functional annotation using the eggNOG database.

