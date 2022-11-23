#!/bin/bash

set -e

usage()
{
cat << EOF
usage: $0 options
Drep tar.gz folder of genomes
OPTIONS:
   -g      Input genomes.tar.gz folder with genomes to dereplicate [REQUIRED]
   -o      Name of output folder [REQUIRED]
   -c      Input csv file with completeness and contamination [REQUIRED]
   -w      Input file with extra weights [REQUIRED]
   -n      Name of input folder without .tar.gz [REQUIRED]
EOF
}


while getopts "g:o:c:w:n:" OPTION
do
     case ${OPTION} in
         g)
             GENOMES_TAR=${OPTARG}
             ;;
         o)
             OUTPUT=${OPTARG}
             ;;
         c)
             CSV=${OPTARG}
             ;;
         w)
             WEIGHTS=${OPTARG}
             ;;
         n)
             NAME=${OPTARG}
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

echo "--> make dir genomes"
mkdir -p genomes

echo "--> untar"
tar -xvzf ${GENOMES_TAR} -C genomes/

GENOMES=$(find -name ${NAME})
echo "Path to folder: ${GENOMES}"

LIST_GENOMES=$(ls ${GENOMES} | tr ' ' '\n')

for i in ${LIST_GENOMES}; do
    echo "${GENOMES}/${i}" >> list_files.txt;
done

echo "--> list of genomes:"
less list_files.txt

echo "--> dRep"
dRep dereplicate \
  -p 16 \
  ${OUTPUT} \
  -pa 0.9 \
  -sa 0.95 \
  -nc 0.30 \
  -cm larger \
  -comp 50 \
  -con 5 \
  -g list_files.txt \
  --genomeInfo ${CSV} \
  -extraW ${WEIGHTS}