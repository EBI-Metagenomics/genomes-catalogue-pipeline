#!/bin/bash

set -e

# Input GUNC file should have 2 lines: header+genome annotation
# Because we are running GUNC on each genome separately in pipeline
while getopts "cgn" option; do
	case "${option}" in
        c) CSV=${OPTARG};;
        g) GUNC=${OPTARG};;
        n) NAME=${OPTARG};;
        *) echo "usage: $0 [-c] [-g] [-n]" >&2
           exit 1 ;;
	esac
done

### check GUNC
# gunc contaminated genomes
awk '{if($8 > 0.45 && $9 > 0.05 && $12 > 0.5)print$1}' "${GUNC}" | grep -v "pass.GUNC" > gunc_contaminated.txt
# gunc_contaminated.txt could be empty - that means genome is OK
# gunc_contaminated.txt could have this genome inside - that means gunc filtered this genome

### check completeness
# remove header
tail -n +2 "${CSV}" > genomes.csv
# get notcompleted genomes
cat genomes.csv | tr ',' '\t' | awk '{if($2 < 90)print$1}' > notcompleted.txt

grep -f gunc_contaminated.txt notcompleted.txt > bad.txt
# if bad.txt is not empty - that means genome didnt pass completeness and gunc filters

# final decision
if [ -s bad.txt ]
then
    # not empty
    touch "${NAME}_empty.txt"
else
    touch "${NAME}_complete.txt"
fi