#!/bin/bash

# SOFTWARE
# /hps/software/users/rdf/metagenomics/service-team/software/mash/mash-2.3/
# /hps/software/users/rdf/metagenomics/service-team/software/iqtree/iqtree-2.1.3-Linux/bin/
# virify.nf
# /hps/software/users/rdf/metagenomics/service-team/software/edirect/edirect
# /hps/software/users/rdf/metagenomics/service-team/software/ncbi-blast+/ncbi-blast-2.12.0+
# /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/kraken2-build

usage() {
  cat <<EOF
usage: $0 options
Generates kraken2 db
OPTIONS:
   -o      Path to general output catalogue directory
   -p      Path to installed pipeline location
   -n      Catalogue name
   -l      Path to logs folder
   -v      Catalogue version
   -q      LSF queue to run in
   -j      LSF step Job name to submit
   -z      memory in Gb
   -t      number of threads
EOF
}

while getopts ho:p:n:l:v:q:j:z:t: option; do
  case "$option" in
  h)
    usage
    exit 1
    ;;
  o)
    OUT=${OPTARG}
    ;;
  p)
    P=${OPTARG}
    ;;
  n)
    DIRNAME=${OPTARG}
    ;;
  l)
    LOGS=${OPTARG}
    ;;
  v)
    VERSION=${OPTARG}
    ;;
  q)
    QUEUE=${OPTARG}
    ;;
  j)
    JOB=${OPTARG}
    ;;
  z)
    MEM=${OPTARG}
    ;;
  t)
    THREADS=${OPTARG}
    ;;
  ?)
    usage
    exit
    ;;
  esac
done

if [[ -z $DIRNAME ]] || [[ -z $VERSION ]] || [[ -z $OUT ]] || [[ -z JOB ]]; then
  echo 'Not all of the arguments are provided'
  usage
fi

#------------------- Make a mash sketch -------------------#

cd "${OUT}"/mgyg_genomes

bsub -J "${DIRNAME}"_mash_sketch \
-q "${QUEUE}" -M 100G \
-o "${LOGS}"/mash_sketch.log \
"mash sketch -o "${OUT}"/all_genomes.msh *fna"

cd "${OUT}"

#------------------- Generate a tree -------------------#

mkdir -p "${OUT}"/IQtree
if [ -f "${OUT}"/gtdbtk/gtdbtk-outdir/align/gtdbtk.bac120.user_msa.fasta.gz ]; then

  cp "${OUT}"/gtdbtk/gtdbtk-outdir/align/gtdbtk.bac120.user_msa.fasta.gz "${OUT}"/IQtree && gunzip \
    "${OUT}"/IQtree/gtdbtk.bac120.user_msa.fasta.gz

  bsub -J "${DIRNAME}"_iqtree_bact \
  -q "${QUEUE}" \
  -n 16 -M 50000 \
  -o "${LOGS}"/iqtree-bacteria.log \
  "/hps/software/users/rdf/metagenomics/service-team/software/iqtree/iqtree-2.1.3-Linux/bin/iqtree2 -nt 16 \
  -s "${OUT}"/IQtree/gtdbtk.bac120.user_msa.fasta --prefix "${OUT}"/IQtree/iqtree.bacteria"
fi

if [ -f "${OUT}"/gtdbtk/gtdbtk-outdir/align/gtdbtk.ar53.user_msa.fasta* ]; then
  cp "${OUT}"/gtdbtk/gtdbtk-outdir/align/gtdbtk.ar53.user_msa.fasta* "${OUT}"/IQtree && gunzip \
    "${OUT}"/IQtree/gtdbtk.ar53.user_msa.fasta.gz

  gunzip "${OUT}"/gtdbtk/gtdbtk-outdir/align/gtdbtk.ar53.user_msa.fasta.gz

  bsub -J "${DIRNAME}"_iqtree_arch \
  -q "${QUEUE}" \
  -n 16 -M 50000 \
  -o "${LOGS}"/iqtree-archaea.log \
  "iqtree2 -nt 16 -s "${OUT}"/gtdbtk/gtdbtk-outdir/align/gtdbtk.ar53.user_msa.fasta --prefix ${OUT}/IQtree/iqtree.archaea"
fi

#------------------- Run virify -------------------#

mkdir -p "${OUT}"/Virify "${LOGS}"/Virify

cd "${OUT}"/reps_fa
REPS=$(ls *fna)

cd ..

mkdir -p "${OUT}"/Virify_starts/

for R in $REPS; do
  NAME=$(echo $R | cut -d '.' -f1)
  mkdir -p "${OUT}"/Virify_starts/"${NAME}"
  cd "${OUT}"/Virify_starts/"${NAME}"

  bsub -J "${NAME}"_virify \
  -q "${QUEUE}" \
  -o "${LOGS}"/Virify/"${NAME}".virify.log \
  -M 10G \
  nextflow run \
    virify.nf \
    -profile ebi,singularity \
    --fasta "${OUT}"/reps_fa/"${NAME}".fna \
    --output "${OUT}"/Virify/

  sleep 3
done

cd "${OUT}"

#------------------- Make kraken and bracken dbs -------------------#

export KRAKENDB=$(echo 'kraken2_db_'${DIRNAME}'_v'${VERSION} | tr '[:upper:]' '[:lower:]')

echo "Kraken DB ${KRAKENDB}"

# Prepare GTDB input
cat "${OUT}"/gtdbtk/gtdbtk-outdir/gtdbtk.ar53.summary.tsv "${OUT}"/gtdbtk/gtdbtk-outdir/gtdbtk.bac120.summary.tsv |
  grep -v "user_genome" | cut -f1-2 >"${OUT}"/gtdbtk/gtdbtk-outdir/kraken_taxonomy_temp.tsv

while read line; do
  NAME=$(echo $line | cut -d ' ' -f1 | cut -d '.' -f1)
  echo $line | sed "s/__\;/__$NAME\;/g" |
    sed "s/s__$/s__$NAME/g"
done <"${OUT}"/gtdbtk/gtdbtk-outdir/kraken_taxonomy_temp.tsv >"${OUT}"/gtdbtk/gtdbtk-outdir/kraken_taxonomy.tsv

sed -i "s/ /\t/" "${OUT}"/gtdbtk/gtdbtk-outdir/kraken_taxonomy.tsv

# Make dmp files
echo "Making dmp files"
bsub -J "${KRAKENDB}"_dmp \
-q "${QUEUE}" \
-o "${LOGS}"/"${KRAKENDB}".dmp.log \
-M 5G \
  singularity exec \
  $SINGULARITY_CACHEDIR/quay.io_microbiome-informatics_genomes-pipeline.gtdb-tax-dump:1.0.sif perl \
  /opt/gtdbToTaxonomy.pl --infile "${OUT}"/gtdbtk/gtdbtk-outdir/kraken_taxonomy.tsv --sequence-dir "${OUT}"/reps_fa/ \
  --output-dir "${OUT}"/Kraken_intermediate

bwait -w "ended(${KRAKENDB}_dmp)"

# Generate kraken2 db
echo "Generating kraken2 db"
# FIXME: ?
# echo "export PATH=\${PATH}:/hps/software/users/rdf/metagenomics/service-team/software/edirect/edirect" >>$HOME/.bashrc
# export PATH=$PATH:/hps/software/users/rdf/metagenomics/service-team/software/ncbi-blast+/ncbi-blast-2.12.0+

echo "Adding files to library"
cd "${OUT}"
for i in "${OUT}"/reps_fa/gtdb/*.fna; do
  /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/kraken2-build --add-to-library \
    $i --db "${KRAKENDB}"
done

mv -v Kraken_intermediate/taxonomy "${KRAKENDB}"

echo "Building library"
bsub -J "${KRAKENDB}"_build \
-q "${QUEUE}" \
-o "${LOGS}"/"${KRAKENDB}".build.log \
-M "${MEM}" -n "${THREADS}" \
  /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/kraken2-build --build \
  --db "${KRAKENDB}" --threads "${THREADS}"

bwait -w "ended(${KRAKENDB}_build)"

echo "Making Braken dbs"
bsub -J "bracken_${KRAKENDB}_50" \
-q "${QUEUE}" \
-n "${THREADS}" \
-M "${MEM}" \
-o "${LOGS}"/bracken-build50.log \
  /hps/software/users/rdf/metagenomics/service-team/software/bracken/Bracken-2.6.2/bracken-build -t "${THREADS}" \
  -d "${KRAKENDB}" -l 50 -x /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/

bsub -J "bracken_${KRAKENDB}_100" \
-q "${QUEUE}" -n \
"${THREADS}" \
-M "${MEM}" \
-o "${LOGS}"/bracken-build100.log \
  /hps/software/users/rdf/metagenomics/service-team/software/bracken/Bracken-2.6.2/bracken-build -t "${THREADS}" \
  -d "${KRAKENDB}" -l 100 -x /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/

bsub -J "bracken_${KRAKENDB}_150" \
-q "${QUEUE}" \
-n "${THREADS}" \
-M "${MEM}" \
-o "${LOGS}"/bracken-build150.log \
  /hps/software/users/rdf/metagenomics/service-team/software/bracken/Bracken-2.6.2/bracken-build -t "${THREADS}" \
  -d "${KRAKENDB}" -l 150 -x /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/

bsub -J "bracken_${KRAKENDB}_200" \
-q "${QUEUE}" \
-n "${THREADS}" \
-M "${MEM}" \
-o "${LOGS}"/bracken-build200.log \
  /hps/software/users/rdf/metagenomics/service-team/software/bracken/Bracken-2.6.2/bracken-build -t "${THREADS}" \
  -d "${KRAKENDB}" -l 200 -x /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/

bsub -J "bracken_${KRAKENDB}_250" \
-q "${QUEUE}" \
-n "${THREADS}" \
-M "${MEM}" \
-o "${LOGS}"/bracken-build250.log \
  /hps/software/users/rdf/metagenomics/service-team/software/bracken/Bracken-2.6.2/bracken-build -t "${THREADS}" \
  -d "${KRAKENDB}" -l 250 -x /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/

# Wait for jobs to finish
bwait -w "ended(bracken_${KRAKENDB}_50)"
bwait -w "ended(bracken_${KRAKENDB}_100)"
bwait -w "ended(bracken_${KRAKENDB}_150)"
bwait -w "ended(bracken_${KRAKENDB}_200)"
bwait -w "ended(bracken_${KRAKENDB}_250)"

echo "Post processing"
# change the library directory contents
cd "${OUT}"/"${KRAKENDB}"/library/added
cat *.fna >../library.fna
cd ..

rm -r added
cp "${OUT}"/"${KRAKENDB}"/taxonomy/prelim_map.txt .
cd "${OUT}"

# Cleanup
echo "Cleaning up"
rm "${OUT}"/gtdbtk/gtdbtk-outdir/kraken_taxonomy.tsv
rm -r "${OUT}"/Kraken_intermediate
rm -r "${OUT}"/reps_fa/gtdb

#------------------- Make a gene catalogue -------------------#

# Prepare the input file
mkdir "${OUT}"/gene_catalogue "${OUT}"/gene_catalogue/ffn_files
find "${OUT}"/sg/ -type f -name "*ffn" >"${OUT}"/gene_catalogue/sg_ffn_list.txt
find "${OUT}"/pg/ -type f -name "*ffn" >"${OUT}"/gene_catalogue/pg_ffn_list.txt

while read line; do
  mv $line "${OUT}"/gene_catalogue/ffn_files/
done <"${OUT}"/gene_catalogue/sg_ffn_list.txt

while read line; do
  mv $line "${OUT}"/gene_catalogue/ffn_files/
done <"${OUT}"/gene_catalogue/pg_ffn_list.txt

find "${OUT}"/gene_catalogue/ffn_files/ -type f -exec cat {} \+ >"${OUT}"/gene_catalogue/concatenated.ffn

# Get the cluster rep list
cut -f1 "${OUT}"/"${DIRNAME}"_mmseqs_1.0/mmseqs_1.0_outdir/mmseqs_cluster.tsv | sort -u >"${OUT}"/gene_catalogue/rep_list.txt
cp "${OUT}"/"${DIRNAME}"_mmseqs_1.0/mmseqs_1.0_outdir/mmseqs_cluster.tsv "${OUT}"/gene_catalogue/clusters.tsv

# Make the catalogue
/hps/software/users/rdf/metagenomics/service-team/software/seqtk/seqtk-1.3/seqtk subseq \
  "${OUT}"/gene_catalogue/concatenated.ffn "${OUT}"/gene_catalogue/rep_list.txt > \
  "${OUT}"/gene_catalogue/gene_catalogue-100.ffn

# Cleanup
rm "${OUT}"/gene_catalogue/concatenated.ffn
rm "${OUT}"/gene_catalogue/*_ffn_list.txt
