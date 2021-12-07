# MGnify genome analysis pipeline

MGnify CWL pipeline to characterize a set of isolate or metagenome-assembled genomes (MAGs) using the workflow described in the following publication: 

A Almeida, S Nayfach, M Boland, F Strozzi, M Beracochea, ZJ Shi, KS Pollard, E Sakharova, DH Parks, P Hugenholtz, N Segata, NC Kyrpides and RD Finn. (2020) [A unified catalog of 204,938 reference genomes from the human gut microbiome.](https://www.nature.com/articles/s41587-020-0603-3) <i>Nature Biotechnol</i>. doi: https://doi.org/10.1038/s41587-020-0603-3


## Clone repo
```bash
git clone https://github.com/EBI-Metagenomics/genomes-pipeline.git
cd genomes-pipeline
```

## Installation with Docker

1. Install all necessary tools (better use separate env):
- [cwltool](https://github.com/common-workflow-language/cwltool) (tested v1.0.2) or [toil](https://toil.readthedocs.io/en/3.10.1/gettingStarted/install.html)
- [Docker](https://www.docker.com/) or [Singularity](https://sylabs.io/guides/3.0/user-guide/installation.html)
- [conda](https://docs.conda.io/en/latest/)
2. Add python scripts to PATH
```bash
export PATH=${PATH}:docker/python3_scripts:docker/genomes-catalog-update/scripts
```
All dockers were pushed on DockerHub. If you want to re-build dockers:
```bash
cd docker
bash build.sh
```


## Installation without Docker

1. Install the necessary dependencies:
- [cwltool](https://github.com/common-workflow-language/cwltool) (tested v1.0.2) or [toil](https://toil.readthedocs.io/en/3.10.1/gettingStarted/install.html)
- [R](https://www.r-project.org/) (tested v3.5.2). Packages: reshape2, fastcluster, optparse, data.table and ape.
- [Python](https://www.python.org/) v3.6+
- [Perl](https://www.perl.org/get.html)
- [CheckM](https://github.com/Ecogenomics/CheckM) (tested v1.0.11)
- [CAT](https://github.com/dutilh/CAT) (tested v5.0)
- [cmsearch](https://manpages.ubuntu.com/manpages/xenial/man1/cmsearch.1.html)
- [dRep](https://drep.readthedocs.io/en/latest/) (tested v2.2.4)
- [eggNOG-mapper](https://github.com/eggnogdb/eggnog-mapper/wiki/eggNOG-mapper-v2) (tested v2.0)
- [GTDB-Tk](https://github.com/Ecogenomics/GTDBTk) (tested v0.3.1 and v1.0.2)
- [GUNC](https://github.com/grp-bork/gunc)
- [InterProScan](https://github.com/ebi-pf-team/interproscan/wiki) (tested v5.35-74.0 and v5.38-76.0)
- [MMseqs2](https://github.com/soedinglab/MMseqs2) (tested v8-fac81)
- [Panaroo](https://github.com/gtonkinhill/panaroo)
- [Prokka](https://github.com/tseemann/prokka) (tested 1.14.0)
- [samtools](https://github.com/samtools/samtools/releases/download)
- [tRNAscan-SE](http://lowelab.ucsc.edu/tRNAscan-SE/)

2. Add custom scripts to your `$PATH` environment. 
```bash
export PATH=${PATH}:docker/genomes-catalog-update/scriptsexport 
export PATH=${PATH}:docker/python3_scripts
export PATH=${PATH}:docker/bash
export PATH=${PATH}:docker/detect_rrnas
export PATH=${PATH}:docker/gunc
export PATH=${PATH}:docker/mash2nwk
export PATH=${PATH}:docker/mmseqs
```

## Download databases 
```bash
bash download_db.sh
```

## Run

Note: You can manually change parameters of MMseqs2 for protein clustering in your YML file (arguments mmseqs_limit_i, mmseq_limit_annotation, mmseqs_limit_c)</b>
1. You need to pre-download your data to directory (GENOMES) and make sure that all genomes are not compressed
2. Create YML file with our help-script:
```bash
export GENOMES=


python3 installation/create_yml.py \
        -d ${GENOMES} ...
```
## Pipeline structure

![Pipeline overview](pipeline_overview.png)


Output files/folders:
```
MGYG...NUM
         --- genome
              --- fa
              --- fa.fai
              --- faa (main rep)
              --- gff (main rep)
         --- pan-genome
              --- core_genes.txt
              --- <cluster>_mashtree.nwk
              --- pan_genome_reference.fa
              --- gene_presence_absence.Rtab
   MGYG...NUM
         --- genome
              --- fa
              --- fa.fai
              --- gff
              --- faa
  mmseqs_cluster_rep.emapper.annotations 
  mmseqs_cluster_rep.emapper.seed_orthologs
  mmseqs_cluster_rep.IPS.tsv

  intermediate_files/
         --- clusters_split.txt
         --- drep-filt-list.txt
         --- extra_weight_table.txt
         --- gunc_report_completed.txt
         --- names.tsv
         --- renamed_download.csv
         --- Sdb.csv
         --- mmseq.tsv
  gtdb-tk_output/ ( commented yet)
  rRNA_fastas/
  rRNA_outs/
  GFFs/
  mmseqs_output/
        mmseqs_0.5_outdir.tar.gz
        mmseqs_0.95_outdir.tar.gz
        mmseqs_0.9_outdir.tar.gz
        mmseqs_1.0_outdir.tar.gz
  panaroo_output/
        MGYG.._panaroo.tar.gz
        ...
  per-genome-annotations/ (for post-processing)
  drep_genomes/                   (for GTDB-Tk)
```

### Tool description
- CheckM: Estimate genome completeness and contamination.
- GTDB-Tk: Genome taxonomic assignment using the GTDB framework.
- dRep: Genome de-replication.
- Mash2Nwk: Generate Mash distance tree of conspecific genomes.
- Prokka: Predict protein-coding sequences from genome assembly.
- MMseqs2: Cluster protein-coding sequences.
- InterProScan: Protein functional annotation using the InterPro database.
- eggNOG-mapper: Protein functional annotation using the eggNOG database.

