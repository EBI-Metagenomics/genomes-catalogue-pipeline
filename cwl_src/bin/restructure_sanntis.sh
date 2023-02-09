#!/bin/bash

usage() {
  cat <<EOF
usage: $0 options
Script restructures Sanntis output in preparation for annot_gff.py.
OPTIONS:
   -o      Path to general output catalogue directory
   -n      Catalogue name
EOF
}

while getopts ho:l:n:q:j:z:t: option; do
  case "$option" in
  h)
    usage
    exit 1
    ;;
  o)
    OUT=${OPTARG}
    ;;
  n)
    DIRNAME=${OPTARG}
    ;;
  ?)
    usage
    exit
    ;;
  esac
done

SANNTIS_LIST=$(ls -d "${OUT}"/"${DIRNAME}"_annotations/*sanntis)

echo "Restructuring SanntiS output"
for SANNTIS_FOLDER in $SANNTIS_LIST; do
  mv $SANNTIS_FOLDER/*sanntis.full.gff "${OUT}"/"${DIRNAME}"_annotations/
  rm -r $SANNTIS_FOLDER
done
echo "Done restructuring SanntiS output"
