#!/bin/bash

if [ $# -eq 0 ]; then
    echo "usage: rna-detect.sh in.fasta cm_db_path"
    echo ""
    echo "Predict bacterial 5S, 16S, 23S rRNA and tRNA genes."
    echo "Output files will be created in the input location"
    exit 1
fi

fasta=${1}
cm_db=${2}  #"/nfs/production/interpro/metagenomics/mags-scripts/rfams_cms"

mkdir results
export BASENAME=$(basename ${fasta})
export FILENAME="${BASENAME%.*}"
echo ${FILENAME}

echo "[ Detecting rRNAs ]"
for f in ${cm_db}/*.cm
do
    export MODEL=$(basename ${f})
    echo "Running cmsearch for ${MODEL}..."
    cmsearch -Z 1000 --hmmonly --cut_ga --cpu 4 --noali --tblout results/${FILENAME}"_"${MODEL}.tblout ${f} ${fasta} > results/${FILENAME}"_"${MODEL}.out
done

echo "Concatenating results..."
cat results/${FILENAME}"_"*.tblout > results/${FILENAME}"_"all.tblout

echo "Removing overlaps..."
cmsearch-deoverlap.pl --maxkeep --clanin ${cm_db}/ribo.claninfo results/${FILENAME}"_"all.tblout

echo "Parsing final results..."
parse_rRNA-bacteria.py results/${FILENAME}"_"all.tblout.deoverlapped > results/${FILENAME}"_"rRNAs.out
rRNA2seq.py results/${FILENAME}"_"all.tblout.deoverlapped ${fasta} > results/${FILENAME}"_"rRNAs.fasta

echo "[ Detecting tRNAs ]"
tRNAscan-SE -B -Q -m results/${FILENAME}_stats.out -o results/${FILENAME}_trna.out ${fasta}
parse_tRNA.py results/${FILENAME}_stats.out > results/${FILENAME}_tRNA_20aa.out

echo "Cleaning tmp files..."
rm results/${FILENAME}"_"all.tblout.deoverlapped results/${FILENAME}"_"all.tblout results/${FILENAME}"_"all.tblout.sort results/${FILENAME}"_"*.cm.*out results/${FILENAME}_stats.out results/${FILENAME}_trna.out