#!/bin/bash

set -e

usage()
{
cat << EOF
usage: $0 options

Index fasta file with samtools

OPTIONS:
   -f      Input FASTA file (.fa/.fasta/.fna/..) [REQUIRED]
EOF
}


while getopts "f:" OPTION
do
     case ${OPTION} in
         f)
             FASTA=${OPTARG}
             ;;
         ?)
             usage
             exit
             ;;
     esac
done


if [[ -z ${FASTA} ]]
then
     echo "ERROR : Please supply correct arguments"
     usage
     exit 1
fi

name="$(basename -- ${FASTA})"

cp ${FASTA} cur.fasta
samtools faidx cur.fasta
mv cur.fasta.fai "${name}.fai"
rm cur.fasta
