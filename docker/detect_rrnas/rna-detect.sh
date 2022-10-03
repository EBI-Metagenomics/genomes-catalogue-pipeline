#!/bin/bash

set -e
shopt -s extglob

if [ $# -eq 0 ]; then
  echo "usage: rna-detect.sh output_folder in.fasta CM_DB_path"
  echo ""
  echo "Predict bacterial 5S, 16S, 23S rRNA and tRNA genes."
  echo "Output files will be created in the input location"
  exit 1
fi

RESULTS_FOLDER=${1}
FASTA=${2}
CM_DB=${3}

BASENAME=$(basename "${FASTA}")
FILENAME="${BASENAME%.*}"

echo "[ Detecting rRNAs ] "

for CM_FILE in "${CM_DB}"/*.cm; do
  MODEL=$(basename "${CM_FILE}")
  echo "Running cmsearch for ${MODEL}..."
  cmsearch -Z 1000 \
    --hmmonly \
    --cut_ga --cpu 4 \
    --noali \
    --tblout "${RESULTS_FOLDER}/${FILENAME}_${MODEL}.tblout" \
    "${CM_FILE}" "${FASTA}" 1>"${RESULTS_FOLDER}/${FILENAME}_${MODEL}.out"
done

echo "Concatenating results..."
cat "${RESULTS_FOLDER}/${FILENAME}"_*.tblout >"${RESULTS_FOLDER}/${FILENAME}_all.tblout"

echo "Removing overlaps..."
cmsearch-deoverlap.pl --maxkeep \
  --clanin "${CM_DB}/ribo.claninfo" \
  "${RESULTS_FOLDER}/${FILENAME}_all.tblout"

echo "Parsing final results..."
parse_rRNA-bacteria.py -i \
  "${RESULTS_FOLDER}/${FILENAME}_all.tblout.deoverlapped" 1>"${RESULTS_FOLDER}/${FILENAME}_rRNAs.out"

rRNA2seq.py -d \
  "${RESULTS_FOLDER}/${FILENAME}_all.tblout.deoverlapped" \
  -i "${FASTA}" 1>"${RESULTS_FOLDER}/${FILENAME}_rRNAs.fasta"

echo "[ Detecting tRNAs ]"
tRNAscan-SE -B -Q \
  -m "${RESULTS_FOLDER}/${FILENAME}_stats.out" \
  -o "${RESULTS_FOLDER}/${FILENAME}_trna.out" "${FASTA}"

parse_tRNA.py -i "${RESULTS_FOLDER}/${FILENAME}_stats.out" 1>"${RESULTS_FOLDER}/${FILENAME}_tRNA_20aa.out"

echo "Cleaning tmp files..."
rm \
  "${RESULTS_FOLDER}/${FILENAME}_all.tblout.deoverlapped" \
  "${RESULTS_FOLDER}/${FILENAME}_all.tblout" \
  "${RESULTS_FOLDER}/${FILENAME}_all.tblout.sort" \
  "${RESULTS_FOLDER}/${FILENAME}"_*.cm.out \
  "${RESULTS_FOLDER}/${FILENAME}_stats.out" \
  "${RESULTS_FOLDER}/${FILENAME}_trna.out"

echo "Create .out results folder"
mkdir "${FILENAME}_out-results"

for OUT_FILE in "${RESULTS_FOLDER}"/*.out; do
    echo "Moving ${OUT_FILE}"
    mv "${OUT_FILE}" "${FILENAME}_out-results/"
done

echo "Create fasta results folder"
mkdir "${FILENAME}_fasta-results"

for OUT_FASTA in "${RESULTS_FOLDER}"/*.fasta; do
    echo "Moving ${OUT_FASTA}"
    mv "${OUT_FASTA}" "${FILENAME}_fasta-results/"
done
