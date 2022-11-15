#!/bin/bash

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

. "/hps/software/users/rdf/metagenomics/service-team/repos/mi-automation/team_environments/codon/mitrc.sh"

#------------------- Make a mash sketch -------------------#

cd "${OUT}"/mgyg_genomes
bsub -q "${QUEUE}" -M 100G -o "${LOGS}"/mash_sketch.log \
"/hps/software/users/rdf/metagenomics/service-team/software/mash/mash-2.3/mash sketch -o "${OUT}"/all_genomes.msh *fna"
cd "${OUT}"

#------------------- Generate a tree -------------------#

mkdir "${OUT}"/IQtree
if [ -f "${OUT}"/gtdbtk/gtdbtk-outdir/gtdbtk.bac120.user_msa.fasta ]; then
  bsub -q "${QUEUE}" -n 16 -M 50000 -o "${LOGS}"/iqtree-bacteria.log \
  "/hps/software/users/rdf/metagenomics/service-team/software/iqtree/iqtree-2.1.3-Linux/bin/iqtree2 -nt 16 \
  -s "${OUT}"/gtdbtk/gtdbtk-outdir/gtdbtk.bac120.user_msa.fasta --prefix "${OUT}"/IQtree/iqtree.bacteria"
fi

if [ -f "${OUT}"/gtdbtk/gtdbtk-outdir/gtdbtk.ar122.user_msa.fasta ]; then
  bsub -q "${QUEUE}" -n 16 -M 50000 -o "${LOGS}"/iqtree-archaea.log \
  "/hps/software/users/rdf/metagenomics/service-team/software/iqtree/iqtree-2.1.3-Linux/bin/iqtree2 -nt 16 \
  -s "${OUT}"/gtdbtk/gtdbtk-outdir/gtdbtk.ar122.user_msa.fasta --prefix "${OUT}"/IQtree/iqtree.archaea"
fi

#------------------- Run virify -------------------#

#------------------- Make kraken and bracken dbs -------------------#

export KRAKENDB=$(echo 'kraken2_db_'${DIRNAME}'_'${VERSION} | tr '[:upper:]' '[:lower:]')

echo "Kraken DB ${KRAKENDB}\n"

# Prepare GTDB input
cat "${OUT}"/gtdbtk/gtdbtk-outdir/gtdbtk.ar122.summary.tsv "${OUT}"/gtdbtk/gtdbtk-outdir/gtdbtk.bac120.summary.tsv | \
grep -v "user_genome" | cut -f1-2 | sed "s/o__;/o__Unknown order;/g" | sed "s/f__;/f__Unknown family;/g" | \
sed "s/g__;/g__Unknown genus;/g" | sed "s/s__$/s__Unknown species/g" > "${OUT}"/gtdbtk/gtdbtk-outdir/kraken_taxonomy.tsv

# Make dmp files
echo "Making dmp files"
singularity exec $SINGULARITY_CACHEDIR/quay.io_microbiome-informatics_genomes-pipeline.gtdb-tax-dump:1.0.sif perl \
/opt/gtdbToTaxonomy.pl --infile "${OUT}"/gtdbtk/gtdbtk-outdir/kraken_taxonomy.tsv --sequence-dir "${OUT}"/reps_fa/ \
--output-dir "${OUT}"/Kraken_intermediate

# Generate kraken2 db
echo "Generating kraken2 db"
echo "export PATH=\${PATH}:/hps/software/users/rdf/metagenomics/service-team/software/edirect/edirect" >> $HOME/.bashrc
export PATH=$PATH:/hps/software/users/rdf/metagenomics/service-team/software/ncbi-blast+/ncbi-blast-2.12.0+

echo "Adding files to library"
cd "${OUT}"
for i in "${OUT}"/reps_fa/gtdb/*.fna; do \
/hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/kraken2-build  --add-to-library \
$i --db "${KRAKENDB}"; done

mv -v Kraken_intermediate/taxonomy "${KRAKENDB}"

echo "Building library"
/hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/kraken2-build --build \
--db "${KRAKENDB}" --threads "${THREADS}"

echo "Making Braken dbs"
bsub -J "bracken_${KRAKENDB}_50" -q production -n "${THREADS}" -M "${MEM}" -o bracken-build50.log \
/hps/software/users/rdf/metagenomics/service-team/software/bracken/Bracken-2.6.2/bracken-build -t "${THREADS}" \
-d "${KRAKENDB}" -l 50 -x /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/

bsub -J "bracken_${KRAKENDB}_100" -q production -n "${THREADS}" -M "${MEM}" -o bracken-build100.log \
/hps/software/users/rdf/metagenomics/service-team/software/bracken/Bracken-2.6.2/bracken-build -t "${THREADS}" \
-d "${KRAKENDB}" -l 100 -x /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/

bsub -J "bracken_${KRAKENDB}_150" -q production -n "${THREADS}" -M "${MEM}" -o bracken-build150.log \
/hps/software/users/rdf/metagenomics/service-team/software/bracken/Bracken-2.6.2/bracken-build -t "${THREADS}" \
-d "${KRAKENDB}" -l 150 -x /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/

bsub -J "bracken_${KRAKENDB}_200" -q production -n "${THREADS}" -M "${MEM}" -o bracken-build200.log \
/hps/software/users/rdf/metagenomics/service-team/software/bracken/Bracken-2.6.2/bracken-build -t "${THREADS}" \
-d "${KRAKENDB}" -l 200 -x /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/

bsub -J "bracken_${KRAKENDB}_250" -q production -n "${THREADS}" -M "${MEM}" -o bracken-build250.log \
/hps/software/users/rdf/metagenomics/service-team/software/bracken/Bracken-2.6.2/bracken-build -t "${THREADS}" \
-d "${KRAKENDB}" -l 250 -x /hps/software/users/rdf/metagenomics/service-team/software/kraken2/kraken2-2.1.2/

# Wait for jobs to finish
python3 "${P}"/cluster/codon/scripts/mwait.py -w "ended(bracken_${KRAKENDB}_50)"
python3 "${P}"/cluster/codon/scripts/mwait.py -w "ended(bracken_${KRAKENDB}_100)"
python3 "${P}"/cluster/codon/scripts/mwait.py -w "ended(bracken_${KRAKENDB}_150)"
python3 "${P}"/cluster/codon/scripts/mwait.py -w "ended(bracken_${KRAKENDB}_200)"
python3 "${P}"/cluster/codon/scripts/mwait.py -w "ended(bracken_${KRAKENDB}_250)"

echo "Post processing"
# change the library directory contents
cd "${KRAKENDB}"/library/added
cat *.fna > ../library.fna
cd ..
rm -r added
cp "${KRAKENDB}"/taxonomy/prelim_map.txt .

# Cleanup
echo "Cleaning up"
rm "${OUT}"/gtdbtk/gtdbtk-outdir/kraken_taxonomy.tsv
rm -r "${OUT}"/Kraken_intermediate
rm -r "${OUT}"/reps_fa/gtdb

#------------------- Make a gene db -------------------#