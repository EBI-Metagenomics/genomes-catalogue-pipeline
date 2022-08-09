#!/bin/bash

while getopts :o:r:f:a:n:d: option; do
	case "${option}" in
		o) OUT=${OPTARG};;
		r) REPS=${OPTARG};;
		f) ALL_GENOMES=${OPTARG};;
		a) REPS_FA=${OPTARG};;
		n) ALL_FNA=${OPTARG};;
		d) DREP_DIR=${OPTARG};;
	esac
done

echo "Create file with all filtered genomes ${ALL_GENOMES}"
# singletons
ls "${OUT}"/sg | tr '_' '\t' | cut -f1 > ${ALL_GENOMES}.sg

# pan-genomes
touch "${ALL_GENOMES}".pg.tmp
for i in $(ls "${OUT}"/pg); do
    echo ${i} >> "${ALL_GENOMES}".pg.tmp
    ls "${OUT}"/pg/"${i}" | grep '.gff' | tr '.' '\t' | cut -f1 >> "${ALL_GENOMES}".pg.tmp
done

cat "${ALL_GENOMES}".pg.tmp | tr '_' '\t' | cut -f1 > "${ALL_GENOMES}".pg
#cat ${ALL_GENOMES}.pg.tmp
rm "${ALL_GENOMES}".pg.tmp

cat "${ALL_GENOMES}".pg > "${ALL_GENOMES}"
#cat ${ALL_GENOMES}
cat "${ALL_GENOMES}".sg >> "${ALL_GENOMES}"
#cat ${ALL_GENOMES}


echo "Create file with cluster reps filtered genomes ${REPS}"
ls ${OUT}/sg | tr '_' '\t' | cut -f1 > "${REPS}".sg
#cat "${REPS}".sg
ls ${OUT}/pg | tr '_' '\t' | cut -f1 > "${REPS}".pg
#cat "${REPS}".pg
cat "${REPS}".sg "${REPS}".pg > "${REPS}"


echo "Create gunc-failed list of genomes"
ls ${DREP_DIR}/singletons > singletons.txt
grep -v -f "${REPS}".sg singletons.txt > ${OUT}/gunc-failed.txt
rm singletons.txt


echo "Create folder with all filtered fa-s ${REPS_FA}"
mkdir -p ${REPS_FA}

for i in $(cat ${REPS}.sg); do
    cp ${OUT}/sg/${i}_cluster/${i}/${i}.fna ${REPS_FA}/${i}.fna
done

for i in $(cat ${REPS}.pg); do
    cp ${OUT}/pg/${i}_cluster/${i}/${i}.fna ${REPS_FA}/${i}.fna
done


echo "Create all_fna ${ALL_FNA}"
mkdir -p ${ALL_FNA}
for i in $(ls ${OUT}/sg); do
    NAME="$(basename -- ${i} | tr '_' '\t' | cut -f1)"
    ln -s ${OUT}/sg/${i}/${NAME}/${NAME}.fna ${ALL_FNA}/${NAME}.fna
done

for i in $(ls ${OUT}/pg); do
    NAME="$(basename -- ${i} | tr '_' '\t' | cut -f1)"
    ln -s ${OUT}/pg/${i}/${NAME}/${NAME}.fna ${ALL_FNA}/${NAME}.fna
    ls ${OUT}/pg/${i} | grep '.fna' | tr '.' '\t' | cut -f1 > list.txt
    for j in $(cat list.txt); do
        ln -s ${OUT}/pg/${i}/${j}.fna ${ALL_FNA}/${j}.fna;
    done
done
rm list.txt