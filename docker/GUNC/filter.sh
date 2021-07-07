#!/bin/bash

while getopts :c:g: option; do
	case "${option}" in
        c) CSV=${OPTARG};;
        g) GUNC=${OPTARG};;
	esac
done


awk '{if($8 > 0.45 && $9 > 0.05 && $12 > 0.5)print$1}' ${GUNC} | grep -v "pass.GUNC" > gunc_contaminated.txt
# remove header
tail -n +2 ${CSV} > genomes.csv

grep -f gunc_contaminated.txt genomes.csv > common.csv

if [ -s common.csv  ]
then
    cat common.csv | tr ',' '\t' | awk '{if($2 > 0.9)print$1}' > completed.txt
else
    touch completed.txt
fi

# final decision
if [ -s completed.txt ]
then
    touch complete.txt
else
    touch empty.txt
fi