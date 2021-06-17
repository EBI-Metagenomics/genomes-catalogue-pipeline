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
db=

while getopts “f:i:c:o:t:d:” OPTION
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
         d)
             db=${OPTARG}
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


echo "$(timestamp) [mmseqs script] Clustering MMseqs with linclust with option -c ${id}"
echo "command: mmseqs linclust ${out}/mmseqs.db ${out}/mmseqs_cluster.db ${out}/mmseqs-tmp --min-seq-id ${id} --threads ${threads} -c ${cov} --cov-mode 1 --cluster-mode 2 --kmer-per-seq 80"

mmseqs linclust ${db} ${out}/mmseqs_cluster.db ${out}/mmseqs-tmp --min-seq-id ${id} --threads ${threads} -c ${cov} --cov-mode 1 --cluster-mode 2 --kmer-per-seq 80

