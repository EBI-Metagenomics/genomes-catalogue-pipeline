#!/bin/bash

while getopts hb:m:y:o:a: option; do
	case "$option" in
	    h)
             usage
             exit 1
             ;;
		b)
		    BIOM=${OPTARG}
		    ;;
		m)
		    METADATA=${OPTARG}
		    ;;
		y)
		    YML_FILE=${OPTARG}
		    ;;
		o)
		    OUT=${OPTARG}
		    ;;
		a)
		    ANNOTATIONS=${OPTARG}
		    ;;
		?)
		    usage
            exit
            ;;
	esac
done


echo \
"
biom: ${BIOM}
metadata:
  class: File
  path: ${METADATA}
annotations:
" >> ${YML_FILE}

ls ${ANNOTATIONS} | grep 'MGYG' > list_annotations.txt
for i in $(cat list_annotations.txt); do
    echo \
"
  - class: File
    path: ${ANNOTATIONS}/${i}
" >> ${YML_FILE}
done
rm list_annotations.txt

echo \
"
clusters:
" >> ${YML_FILE}

for i in $(ls ${OUT}/sg); do
    NAME="$(basename -- ${i} | tr '_' '\t' | cut -f1)"
    echo \
"
  - class: Directory
    path: ${OUT}/sg/${i}/${NAME}
" >> ${YML_FILE}
done

for i in $(ls ${OUT}/pg); do
    NAME="$(basename -- ${i} | tr '_' '\t' | cut -f1)"
    echo \
"
  - class: Directory
    path: ${OUT}/pg/${i}/${NAME}
" >> ${YML_FILE}
done