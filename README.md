# MGnify genome analysis pipeline

[MGnify](https://www.ebi.ac.uk/metagenomics/) [CWL](https://www.commonwl.org/) pipeline to characterize a set of isolate or metagenome-assembled genomes (MAGs) using the workflow described in the following publication: 

A Almeida, S Nayfach, M Boland, F Strozzi, M Beracochea, ZJ Shi, KS Pollard, E Sakharova, DH Parks, P Hugenholtz, N Segata, NC Kyrpides and RD Finn. (2020) [A unified catalog of 204,938 reference genomes from the human gut microbiome.](https://www.nature.com/articles/s41587-020-0603-3) <i>Nature Biotechnol</i>. doi: https://doi.org/10.1038/s41587-020-0603-3

Detail information about existing MGnify catalogues: https://docs.mgnify.org/en/latest/genome-viewer.html#

## Pipeline structure

![Pipeline overview](pipeline_overview.png)

## Installation 

### CWL
Genome pipeline was implemented on [Common Workflow Language (CWL)](https://www.commonwl.org/). 
Install [CWL](https://github.com/common-workflow-language/cwltool).
The current implementation uses CWL version 1.2. It was tested using [Toil](https://toil.readthedocs.io/en/3.10.1/gettingStarted/install.html) version 5.3.0 as the workflow engine and [conda](https://docs.conda.io/en/latest/) to manage the software dependencies.

### Docker
Our team kindly recommend to use [docker](https://www.docker.com/) containers to run pipeline.
All dockers were pushed on [quay.io/microbiome-informatics](https://quay.io/organization/microbiome-informatics). If you want to re-build dockers *(it will take a while)* use script:
```bash
cd docker && bash build.sh
```
### Download databases
Pipeline execution requires memory ~150G for necessary databases.
```bash
bash download_db.sh
```

### Add custom python3 scripts to PATH
```bash
export PATH=${PATH}:docker/python3_scripts:docker/genomes-catalog-update/scripts
```

### In addition do this if you will not use Docker or Singularity

1. Install the necessary dependencies:
- [R](https://www.r-project.org/) (tested v3.5.2). Packages: reshape2, fastcluster, optparse, data.table and ape.
- [Python](https://www.python.org/) v3.6+
- [Perl](https://www.perl.org/get.html)
- [CheckM](https://github.com/Ecogenomics/CheckM) (tested v1.0.11)
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
export PATH=${PATH}:docker/bash
export PATH=${PATH}:docker/detect_rrnas
export PATH=${PATH}:docker/gunc
export PATH=${PATH}:docker/mash2nwk
export PATH=${PATH}:docker/mmseqs
```


## Run

**Note 1**: You can manually change parameters of MMseqs2 for protein clustering in your YML file (arguments mmseqs_limit_i, mmseq_limit_annotation, mmseqs_limit_c)</b>

**Note 2**: Pipeline currently doesn't support GTDB-Tk and will skip this step. 

1. You need to pre-download your data to directory/ies and make sure that all genomes are not compressed. If you have downloaded genomes from ENA and NCBI put them into different folders. If you've downloaded genomes from ENA save output CSV file with ENA genomes.
2. You will need the following information to create YML:
 - catalogue name (for example, GUT)
 - catalogue version (for example, v1.0)
 - catalogue biom (for example, Human:Gut)
 - min amd max number of accessions (only MGnify specific). Max - Min = #total number of genomes (NCBI+ENA)
3. Create YML file with our help-script:
```bash
export ENA_GENOMES=
export ENA_GENOMES_CSV=
export NCBI_GENOMES=
export BIOM=
export NAME=
export VERSION=
export OUTPUT=  # output.yml
export MIN=
export MAX

python3 installation/create_yml.py \
        -y pattern.yml -o ${OUTPUT} \
        -m ${MAX} -n ${MIN} -v ${VERSION} -b ${BIOM} -c ${NAME} \
        # for ENA genomes
        -e ${ENA_GENOMES} -s ${ENA_GENOMES_CSV}
        # for NCBI genomes
        -a ${NCBI_GENOMES}
```
4. Simple run 
```
cwltool cwl/wfs/wf-main.cwl ${OUTPUT}
```
Add all necessary cwltool/Toil arguments for run.


## Output

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

