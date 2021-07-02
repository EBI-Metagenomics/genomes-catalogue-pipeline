#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

Classify contigs using CAT and determine genome % with inconsistent taxonomy.

OPTIONS:
   -t      Number of threads
   -c      Input multi-fasta file (.fa)
   -d      Output directory
   -o      Prefix for output files
EOF
}

contigs=
outprefix=
outdir=
threads=

### CUSTOM DIRECTORIES
diamond_path="/nfs/production/interpro/metagenomics/mags-scripts/dependencies/CAT/diamond"
cat_db_path="/nfs/production/interpro/metagenomics/mags-scripts/CAT_db/2019-07-19_CAT_database"
cat_tax_path="/nfs/production/interpro/metagenomics/mags-scripts/CAT_db/2019-07-19_taxonomy"

while getopts “t:c:d:o:” OPTION
do
     case $OPTION in
         t)
             threads=$OPTARG
             ;;
         c)
             contigs=$OPTARG
             ;;
         d)
             outdir=$OPTARG
             ;;
         o)
             outprefix=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

timestamp() {
  date +"%H:%M:%S"
}

echo "$(timestamp) [taxcheck] Parsing command-line"
if [[ -z ${threads} ]] || [[ -z ${contigs} ]] || [[ -z ${outprefix} ]] || [[ -z ${outdir} ]]
then
     echo "ERROR : Please supply the appropriate arguments"
     usage
     exit 1
fi

prefix=${outdir}/${outprefix}

if [[ ! -d ${outdir} ]]
then
    mkdir ${outdir}
fi

if [[ ! -s "${prefix}.summary.txt" ]]
then
    echo "$(timestamp) [taxcheck] Analysing contigs with CAT"
    CAT contigs -n ${threads} -c ${contigs} --path_to_diamond ${diamond_path} -d ${cat_db_path} -t ${cat_tax_path} --out_prefix ${prefix}

    echo "$(timestamp) [taxcheck] Adding taxonomy names"
    CAT add_names -i ${prefix}.contig2classification.txt -o ${prefix}.contig2classification.official_names.txt -t ${cat_tax_path} --only_official

    echo "$(timestamp) [taxcheck] Summarizing output"
    CAT summarise -c ${contigs} -i ${prefix}.contig2classification.official_names.txt -o ${prefix}.summary.txt

    echo "$(timestamp) [taxcheck] Detecting taxonomy inconsistency"
    ../custom_scripts/taxcheck_parser.py ${prefix}.summary.txt > ${prefix}.tax-stats.tsv
else
    echo "$(timestamp) [taxcheck] Summary file detected, skipping to detection of taxonomy inconsistency"
    ../custom_scripts/taxcheck_parser.py ${prefix}.summary.txt > ${prefix}.tax-stats.tsv
fi
