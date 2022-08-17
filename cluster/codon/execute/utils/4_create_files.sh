#!/bin/bash

usage()
{
cat << EOF
usage: $0 options
Run genomes-pipeline step to create folders with reps and filtered fasta.fna-s [intermediate step]
OPTIONS:
   -o      Path to general output catalogue directory
   -r      File with cluster representatives (filtered)
   -f      File with all fasta.fna (filtered)
   -a      Directory with cluater reps
   -n      Directory with all fna-s
   -d      Directory with dRep result
EOF
}

while getopts ho:r:f:a:n:d: option; do
	case "${option}" in
	    h)
             usage
             exit 1
             ;;
		o)
		    OUT=${OPTARG}
		    ;;
		r)
		    REPS=${OPTARG}
		    ;;
		f)
		    ALL_GENOMES=${OPTARG}
		    ;;
		a)
		    REPS_FA=${OPTARG}
		    ;;
		n)
		    ALL_FNA=${OPTARG}
		    ;;
		d)
		    DREP_DIR=${OPTARG}
		    ;;
		?)
		    usage
            exit
            ;;
	esac
done

echo "Create file with all filtered genomes ${ALL_GENOMES}"
# singletons
ls "${OUT}"/sg | tr '_' '\t' | cut -f1 > "${ALL_GENOMES}".sg

# pan-genomes
touch "${ALL_GENOMES}".pg.tmp

ls "${OUT}"/pg > list_pg.txt
ls "${OUT}"/sg > list_sg.txt

while IFS= read -r i
do
    echo "${i}" >> "${ALL_GENOMES}".pg.tmp
    ls "${OUT}"/pg/"${i}" | grep '.gff' | tr '.' '\t' | cut -f1 >> "${ALL_GENOMES}".pg.tmp
done < list_pg.txt


cat "${ALL_GENOMES}".pg.tmp | tr '_' '\t' | cut -f1 > "${ALL_GENOMES}".pg
rm "${ALL_GENOMES}".pg.tmp

cat "${ALL_GENOMES}".pg > "${ALL_GENOMES}"
cat "${ALL_GENOMES}".sg >> "${ALL_GENOMES}"


echo "Create file with cluster reps filtered genomes ${REPS}"
ls "${OUT}"/sg | tr '_' '\t' | cut -f1 > "${REPS}".sg
ls "${OUT}"/pg | tr '_' '\t' | cut -f1 > "${REPS}".pg
cat "${REPS}".sg "${REPS}".pg > "${REPS}"


echo "Create gunc-failed list of genomes"
ls "${DREP_DIR}"/singletons > singletons.txt
grep -v -f "${REPS}".sg singletons.txt > "${OUT}"/gunc-failed.txt
rm singletons.txt


echo "Create folder with all filtered fa-s ${REPS_FA}"
mkdir -p "${REPS_FA}"

while IFS= read -r i
do
    cp "${OUT}"/sg/"${i}"_cluster/"${i}"/"${i}".fna "${REPS_FA}"/"${i}".fna
done < "${REPS}".sg

while IFS= read -r i
do
    cp "${OUT}"/pg/"${i}"_cluster/"${i}"/"${i}".fna "${REPS_FA}"/"${i}".fna
done < "${REPS}".pg


echo "Create all_fna ${ALL_FNA}"
mkdir -p "${ALL_FNA}"

while IFS= read -r i
do
    NAME="$(basename -- "${i}" | tr '_' '\t' | cut -f1)"
    cp "${OUT}"/sg/"${i}"/"${NAME}"/"${NAME}".fna "${ALL_FNA}"/"${NAME}".fna
    #ln -s "${OUT}"/sg/"${i}"/"${NAME}"/"${NAME}".fna "${ALL_FNA}"/"${NAME}".fna
done < list_sg.txt

while IFS= read -r i
do
    NAME="$(basename -- "${i}" | tr '_' '\t' | cut -f1)"
    cp "${OUT}"/pg/"${i}"/"${NAME}"/"${NAME}".fna "${ALL_FNA}"/"${NAME}".fna
    #ln -s "${OUT}"/pg/"${i}"/"${NAME}"/"${NAME}".fna "${ALL_FNA}"/"${NAME}".fna
    ls "${OUT}"/pg/"${i}" | grep '.fna' | tr '.' '\t' | cut -f1 > list.txt
    while IFS= read -r j
    do
        cp "${OUT}"/pg/"${i}"/"${j}".fna "${ALL_FNA}"/"${j}".fna;
        #ln -s "${OUT}"/pg/"${i}"/"${j}".fna "${ALL_FNA}"/"${j}".fna;
    done < list.txt
done < list_pg.txt

rm list.txt list_pg.txt list_sg.txt