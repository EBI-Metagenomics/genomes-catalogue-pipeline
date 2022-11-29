#!/bin/bash

usage()
{
cat << EOF
usage: $0 options
Restructure output folders
OPTIONS:
   -o      Path to general output catalogue directory
   -n      Catalogue name
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

cd "${OUT}"/reps_fa
REPS=$(ls *fna | cut -d '.' -f1)
cd "${OUT}"

# Rename SanntiS files in the annotations folder
for R in ${REPS}
do
  if [ -s "${OUT}"/"${NAME}"_annotations/"${R}".gbk.sanntis.full.gff ]; then
    mv "${OUT}"/"${NAME}"_annotations/"${R}".gbk.sanntis.full.gff "${OUT}"/"${NAME}"_annotations/"${R}"_sanntis.gff
    if [[ "$(wc -l < ${OUT}/${NAME}_annotations/${R}_sanntis.gff)" -eq 1 ]]; then
      rm ${OUT}/${NAME}_annotations/${R}_sanntis.gff
    fi
  else
     echo "ERROR: file ${R}.gbk.sanntis.full.gff does not exist in the annotations folder"
  fi
done

# Rename Sanntis files in the metadata folder
for R in ${REPS}
do
  if [ -s "${OUT}"/"${NAME}"_metadata/"${R}"/genome/"${R}".gbk.sanntis.full.gff ]; then
    mv "${OUT}"/"${NAME}"_metadata/"${R}"/genome/"${R}".gbk.sanntis.full.gff "${OUT}"/"${NAME}"_metadata/"${R}"/genome/"${R}"_sanntis.gff
    if [[ "$(wc -l < ${OUT}/${NAME}_metadata/"${R}"/genome/${R}_sanntis.gff)" -eq 1 ]]; then
      rm ${OUT}/${NAME}_metadata/"${R}"/genome/${R}_sanntis.gff
    fi
  else
     echo "ERROR: file ${R}.gbk.sanntis.full.gff does not exist in the _metadata folder"
  fi
done

# Clean and move VIRify output
for R in ${REPS}
do
  if [ -d "${OUT}"/Virify/"${R}"/08-final/gff ]; then
    if [ -s "${OUT}"/Virify/"${R}"/08-final/gff/"${R}"_virify.gff ]; then
      cp "${OUT}"/Virify/"${R}"/08-final/gff/"${R}"_virify.gff "${OUT}"/"${NAME}"_metadata/"${R}"/genome/
      cp "${OUT}"/Virify/"${R}"/08-final/gff/"${R}"_virify.gff "${OUT}"/"${NAME}"_annotations/
      cp "${OUT}"/Virify/"${R}"/08-final/gff/"${R}"_virify_contig_viewer_metadata.tsv "${OUT}"/"${NAME}"_metadata/"${R}"/genome/"${R}"_virify_metadata.tsv
      cp "${OUT}"/Virify/"${R}"/08-final/gff/"${R}"_virify_contig_viewer_metadata.tsv "${OUT}"/"${NAME}"_annotations/"${R}"_virify_metadata.tsv
    fi
  fi
done

# Modify pan-genome folders inside the metadata folder
PGS=$(cat "${OUT}"/cluster_reps.txt.pg)
for PG in ${PGS}
do
  mv "${OUT}"/"${NAME}"_metadata/"${PG}"/pan-genome/"${PG}".core_genes.txt "${OUT}"/"${NAME}"_metadata/"${PG}"/pan-genome/core_genes.txt
  mv "${OUT}"/"${NAME}"_metadata/"${PG}"/pan-genome/"${PG}"_mashtree.nwk "${OUT}"/"${NAME}"_metadata/"${PG}"/pan-genome/mashtree.nwk
  mv "${OUT}"/"${NAME}"_metadata/"${PG}"/pan-genome/"${PG}".pan-genome.fna "${OUT}"/"${NAME}"_metadata/"${PG}"/pan-genome/pan-genome.fna
  cp "${OUT}"/pg/"${PG}"_cluster/"${PG}"_panaroo/gene_presence_absence.Rtab "${OUT}"/"${NAME}"_metadata/"${PG}"/pan-genome/
done

# Add a gff to be used on the website (without a fasta sequence at the end)
for R in ${REPS}
do
  while read line; do if [[ ${line} == "##FASTA" ]]; then break; else echo "$line"; fi; done < "${OUT}"/"${NAME}"_metadata/"${R}".gff > "${OUT}"/"${NAME}"_metadata/"${R}".gff.noseq
done

echo "Creating ${RESULTS}"
# --- PROTEIN CATALOGUE ---
# move mmseqs
echo "Creating protein_catalogue"
mkdir -p "${RESULTS}"/protein_catalogue
ls "${OUT}" | grep "${NAME}_mmseqs" > "${OUT}"/mmseqs_list
while IFS= read -r i
do
    mv "${OUT}"/"${i}"/*_outdir "${RESULTS}"/protein_catalogue/
done < "${OUT}"/mmseqs_list
rm "${OUT}"/mmseqs_list

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
ls "${RESULTS}"/GFF > "${OUT}"/gffs
while IFS= read -r i
do
    gzip "${RESULTS}"/GFF/"${i}"
done < "${OUT}"/gffs
rm "${OUT}"/gffs

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
mv "${OUT}"/"${NAME}"_metadata/genomes-all_metadata.tsv "${RESULTS}"/

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

# --- gene catalogue ---
echo "Organising gene catalogue"
mv "${OUT}"/gene_catalogue/ffn_files "${RESULTS}"/intermediate_files/
rm "${OUT}"/gene_catalogue/rep_list.txt
mv "${OUT}"/gene_catalogue/ "${RESULTS}"/

# --- phylogeny ---
echo "Moving phylogenetic trees"
mkdir -p "${RESULTS}"/phylogenies
mv "${OUT}"/IQtree/gtdbtk.bac120.user_msa.fasta "${RESULTS}"/phylogenies/bac120_alignment.faa
mv "${OUT}"/IQtree/iqtree.bacteria.treefile "${RESULTS}"/phylogenies/bac120_iqtree.nwk
gzip "${RESULTS}"/phylogenies/bac120_alignment.faa

if [ -f "${OUT}"/IQtree/gtdbtk.ar53.user_msa.fasta ]
then
  mv "${OUT}"/IQtree/gtdbtk.ar53.user_msa.fasta "${RESULTS}"/phylogenies/ar53_alignment.faa
  mv "${OUT}"/IQtree/iqtree.archaea.treefile "${RESULTS}"/phylogenies/ar53_iqtree.nwk
  gzip "${RESULTS}"/phylogenies/ar53_alignment.faa
fi

# --- Make the all_genomes file ---
mkdir -p "${RESULTS}"/all_genomes
# Add singleton genomes
while read line
do
  mkdir -p "${RESULTS}"/all_genomes/${line::-2} "${RESULTS}"/all_genomes/${line::-2}/${line} \
  "${RESULTS}"/all_genomes/${line::-2}/${line}/genomes1
  cp "${RESULTS}"/GFF/${line}.gff.gz "${RESULTS}"/all_genomes/${line::-2}/${line}/genomes1/
done < "${OUT}"/cluster_reps.txt.sg

# Add genomes that have pan-genomes
while read line
do
  mkdir -p "${RESULTS}"/all_genomes/${line::-2} "${RESULTS}"/all_genomes/${line::-2}/${line} \
  "${RESULTS}"/all_genomes/${line::-2}/${line}/genomes1
  CLUSTER=$(grep $line "${RESULTS}"/intermediate_files/clusters_split.txt | cut -d ':' -f3 | sed "s/\.fa//g" | sed "s/\,/ /g")
  for C in $CLUSTER
  do
    cp "${RESULTS}"/GFF/${C}.gff.gz "${RESULTS}"/all_genomes/${line::-2}/${line}/genomes1/
  done
done < "${OUT}"/cluster_reps.txt.pg

# --- Make species catalogue ---
mkdir -p "${RESULTS}"/species_catalogue
while read line
do
  mkdir -p "${RESULTS}"/species_catalogue/"${line::-2}"
  cp -r "${RESULTS}"/clusters/"${line}" "${RESULTS}"/species_catalogue/"${line::-2}"/
  cp "${RESULTS}"/rRNA_fastas/"${line}"_fasta-results/"${line}"_rRNAs.fasta "${RESULTS}"/species_catalogue/"${line::-2}"/"${line}"/genome/
done < "${OUT}"/cluster_reps.txt

echo "Done. Bye"