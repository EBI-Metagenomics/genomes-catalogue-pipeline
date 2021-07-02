#!/bin/bash

while getopts :c:g: option; do
	case "${option}" in
        c) CSV=${OPTARG};;
        g) GUNC=${OPTARG};;
	esac
done


awk '{if($8 > 0.45 && $9 > 0.05 && $12 > 0.5)print$1}' ${GUNC} | grep -v "pass.GUNC" > gunc_contaminated.txt

grep -f gunc_contaminated.txt ${CSV} | tr ',' '\t' | awk '{if($3 > 0.9)}print$1' > completed.txt

if [ -s completed.txt ]
then
    touch complete.txt
else
    touch empty.txt
fi