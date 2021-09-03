#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

Cluster protein sequences at a user-defined sequence identity

OPTIONS:
   -f      Input FASTA protein file (.fa) [REQUIRED]
   -o      Output directory [REQUIRED]
   -i      Sequence identity threshold (0-1) [REQUIRED]
   -c      Coverage threshold (0-1) [REQUIRED]
   -t	   Number of threads to use for linclust [REQUIRED]
EOF
}

# variables
seq=
id=
out=
threads=
cov=

while getopts “f:i:c:o:t:” OPTION
do
     case ${OPTION} in
         f)
             seq=${OPTARG}
             ;;
         i)
             id=${OPTARG}
             ;;
         o)
             out=${OPTARG}
             ;;
         c)
             cov=${OPTARG}
             ;;
         t)
             threads=${OPTARG}
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [[ -z ${seq} ]] || [[ -z ${id} ]] || [[ -z ${out} ]] || [[ -z ${threads} ]] || [[ -z ${cov} ]]
then
     echo "ERROR : Please supply correct arguments"
     usage
     exit 1
fi

if [[ ! -d ${out} ]]
then
        mkdir ${out}
fi

timestamp() {
  date +"%H:%M:%S"
}

# prepare cluster database
echo "$(timestamp) [mmseqs script] Creating MMseqs database"
echo "command: mmseqs createdb ${seq} ${out}/mmseqs.db"
mmseqs createdb ${seq} ${out}/mmseqs.db

echo "$(timestamp) [mmseqs script] Clustering MMseqs with linclust with option -c ${id}"
echo "command: mmseqs linclust ${out}/mmseqs.db ${out}/mmseqs_cluster.db ${out}/mmseqs-tmp --min-seq-id ${id} --threads ${threads} -c ${cov} --cov-mode 1 --cluster-mode 2 --kmer-per-seq 80"
mmseqs linclust ${out}/mmseqs.db ${out}/mmseqs_cluster.db ${out}/mmseqs-tmp --min-seq-id ${id} --threads ${threads} -c ${cov} --cov-mode 1 --cluster-mode 2 --kmer-per-seq 80

echo "$(timestamp) [mmseqs script] Parsing output to create FASTA file of all sequences"
echo "command: mmseqs createseqfiledb ${out}/mmseqs.db ${out}/mmseqs_cluster.db ${out}/mmseqs_cluster_seq --threads ${threads}"
mmseqs createseqfiledb ${out}/mmseqs.db ${out}/mmseqs_cluster.db ${out}/mmseqs_cluster_seq --threads ${threads}
echo "command: mmseqs result2flat ${out}/mmseqs.db ${out}/mmseqs.db ${out}/mmseqs_cluster_seq ${out}/mmseqs_cluster.fa"
mmseqs result2flat ${out}/mmseqs.db ${out}/mmseqs.db ${out}/mmseqs_cluster_seq ${out}/mmseqs_cluster.fa

echo "$(timestamp) [mmseqs script] Parsing output to create TSV file with cluster membership"
echo "command: mmseqs createtsv ${out}/mmseqs.db ${out}/mmseqs.db ${out}/mmseqs_cluster.db ${out}/mmseqs_cluster.tsv --threads ${threads}"
mmseqs createtsv ${out}/mmseqs.db ${out}/mmseqs.db ${out}/mmseqs_cluster.db ${out}/mmseqs_cluster.tsv --threads ${threads}

echo "$(timestamp) [mmseqs script] Parsing output to create FASTA file of representative sequences"
echo "mmseqs result2repseq ${out}/mmseqs.db ${out}/mmseqs_cluster.db ${out}/mmseqs_cluster_rep --threads ${threads}"
mmseqs result2repseq ${out}/mmseqs.db ${out}/mmseqs_cluster.db ${out}/mmseqs_cluster_rep --threads ${threads}
echo "mmseqs result2flat ${out}/mmseqs.db ${out}/mmseqs.db ${out}/mmseqs_cluster_rep ${out}/mmseqs_cluster_rep.fa --use-fasta-header"
mmseqs result2flat ${out}/mmseqs.db ${out}/mmseqs.db ${out}/mmseqs_cluster_rep ${out}/mmseqs_cluster_rep.fa --use-fasta-header

# remove tmp
rm -rf ${out}/mmseqs-tmp
# remove symlinks
for f in $(find -type l);do cp --remove-destination $(readlink $f) $f;done;
