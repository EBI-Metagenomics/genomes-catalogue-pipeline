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
EOF
}


while getopts "g:o:c:w:" OPTION
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
         ?)
             usage
             exit
             ;;
     esac
done


tar -xvzf ${GENOMES_TAR} -C genomes

dRep dereplicate \
  -p 16 \
  ${OUTPUT} \
  -pa 0.9 \
  -sa 0.95 \
  -nc 0.30 \
  -cm larger \
  -comp 50 \
  -con 5 \
  -g genomes \
  --genomeInfo ${CSV} \
  -extraW ${WEIGHTS}