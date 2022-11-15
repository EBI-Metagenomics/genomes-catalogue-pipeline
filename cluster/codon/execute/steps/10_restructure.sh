#!/bin/bash

usage()
{
cat << EOF
usage: $0 options
Restructure output folders
OPTIONS:
   -o      Path to general output catalogue directory
   -p      Path to installed pipeline location
   -l      Path to logs folder
   -n      Catalogue name
   -q      LSF queue to run in
   -j      LSF step Job name to submit
EOF
}

while getopts ho:n: option; do
	case "$option" in
	    h)
             usage
             exit 1
             ;;
		o)
		    OUT=${OPTARG}
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
export RESULTS="${OUT}"/results
mkdir -p "${RESULTS}"
echo "Creating ${RESULTS}"
# --- PROTEIN CATALOGUE ---
# move mmseqs
echo "Creating protein_catalogue"
mkdir -p "${RESULTS}"/protein_catalogue
ls "${OUT}" | grep "${NAME}_mmseqs" > mmseqs_list
while IFS= read -r i
do
    mv "${OUT}"/"${i}"/*_outdir "${RESULTS}"/protein_catalogue/
done < mmseqs_list
rm mmseqs_list

# move EggNOG and IPS annotations
echo "moving EggNOG and IPS annotations"
[ -f "${OUT}"/"${NAME}"_annotations/mmseqs_cluster_rep.emapper.annotations ] && \
mv "${OUT}"/"${NAME}"_annotations/mmseqs_cluster_rep.emapper.annotations \
"${RESULTS}"/protein_catalogue/mmseqs_0.9_outdir/protein_catalogue-90_eggNOG.tsv

[ -f "${OUT}"/"${NAME}"_annotations/mmseqs_cluster_rep.IPS.tsv ] && \
mv "${OUT}"/"${NAME}"_annotations/mmseqs_cluster_rep.IPS.tsv \
"${RESULTS}"/protein_catalogue/mmseqs_0.9_outdir/protein_catalogue-90_InterProScan.tsv

# --- GFFs ---
echo "Creating GFF folder"
mkdir -p "${RESULTS}"/GFF
# move annotated
mv "${OUT}"/"${NAME}"_metadata/*.gff "${RESULTS}"/GFF
# move non-cluster reps for pan-genomes
mv "${OUT}"/pg/*/*.gff "${RESULTS}"/GFF
# compress
echo "Compressing gff"
ls "${RESULTS}"/GFF > gffs
while IFS= read -r i
do
    gzip "${RESULTS}"/GFF/"${i}"
done < gffs
rm gffs

# --- PANAROO ---
echo "Creating panaroo_output"
mkdir -p "${RESULTS}"/panaroo_output
mv "${OUT}"/pg/*/*_panaroo "${RESULTS}"/panaroo_output

# --- rRNA out ---
echo "Creating rRNA out"
mv "${OUT}"/"${NAME}"_annotations/rRNA_outs "${RESULTS}"/

# --- rRNA_fasta ---
echo "Creating rRNA fasta"
mv "${OUT}"/"${NAME}"_annotations/rRNA_fastas "${RESULTS}"/

# --- GTDB-Tk ---
echo "Creating GTDB-Tk"
mv "${OUT}"/gtdbtk/gtdbtk-outdir "${RESULTS}"/gtdb-tk_output

# --- metadata ---
echo "Creating metadata.txt"
mv "${OUT}"/"${NAME}"_metadata/genomes-all_metadata.tsv "${RESULTS}"/metadata.txt

# --- intermediate files ---
echo "Creating intermediate files"
mv "${OUT}"/"${NAME}"_drep/intermediate_files "${RESULTS}"/
mv "${OUT}"/drep-filt-list.txt "${RESULTS}"/intermediate_files/
mv "${OUT}"/gunc-failed.txt  "${RESULTS}"/intermediate_files/gunc_report_failed.txt
grep -v -f "${RESULTS}"/intermediate_files/gunc_report_failed.txt "${RESULTS}"/intermediate_files/drep-filt-list.txt > "${RESULTS}"/intermediate_files/gunc_report_completed.txt

# --- phylo_tree.json ---
echo "Moving phylo_tree.json"
mv "${OUT}"/"${NAME}"_metadata/phylo_tree.json "${RESULTS}"/

# --- singletons and pan-genomes ---
echo "Moving singletons and pan-genomes"
mkdir -p "${RESULTS}"/clusters
mv "${OUT}"/"${NAME}"_metadata/* "${RESULTS}"/clusters/
# --- pan-genomes add panaroo ---
echo "Adding panaroo files"
for i in $(ls "${RESULTS}"/panaroo_output);
do
    CLUSTER="$(basename -- "${i}" | tr '_' '\t' | cut -f1)"
    cp "${RESULTS}"/panaroo_output/"${i}"/gene_presence_absence.Rtab "${RESULTS}"/clusters/"${CLUSTER}"/pan-genome/gene_presence_absence.Rtab
    cp "${RESULTS}"/panaroo_output/"${i}"/pan_genome_reference.fa "${RESULTS}"/clusters/"${CLUSTER}"/pan-genome/"${CLUSTER}".pan_genome_reference.fa
done

echo "Done. Bye"