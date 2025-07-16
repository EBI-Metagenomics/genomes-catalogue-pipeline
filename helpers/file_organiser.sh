#!/usr/bin/env bash

set -e

# The script organises output from the catalogue generation + Virify + Mobilome annotation pipeline to prepare it for upload to MGnify

function Usage {
    echo "Usage: $0 [-d /path/to/new/output/location] [-f ftp-folder-name] [-v catalogue-version] [-r /path/to/results/folder]"
    echo "Options:"
    echo "-d   Directory to save results to (FULL PATH)"
    echo "-f   FTP name of the catalogue, for example, human-oral or non-model-fish-gut"
    echo "-v   Catalogue version, for example, v1.0"
    echo "-r   Full path to nextflow pipeline results folder"
    exit 1
}

GET_REPS() {
    cut -f14 "${RESULTS_PATH}"/genomes-all_metadata.tsv | grep -v "Species" | sort -u
}

function GenerateDirectories {
  if [[ -d "${SAVE_TO_PATH}" ]]
  then
      if [[ ! -d "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}" ]]
      then
          mkdir "${SAVE_TO_PATH}"/"${CATALOGUE_FOLDER}"
      fi
      if [[ -d "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}" ]]
      then
          echo "Directory ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION} already exists. Exiting."
          exit 1
      fi
      mkdir -p "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
      mkdir -p "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/"
  fi
}


function GenerateWebsiteGFFs {
    echo "Generating GFFs for the website"
    cd "${RESULTS_PATH}/species_catalogue"
    for R in $(GET_REPS)
    do
        while read -r line
        do
            if [[ ${line} == "##FASTA" ]]
            then
                break
            else
                echo "$line"
            fi
        done < "${R::-2}/${R}/genome/${R}_annotated_with_mobilome.gff" > "${R::-2}/${R}/${R}.gff.noseq"
    done
}


function CopyWebsiteFiles {
    echo "Copying files to the website folder"
    cd "${RESULTS_PATH}"
    cp phylo_tree.json "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/"
    cp catalogue_summary.json "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/"
    for R in $(GET_REPS)
    do
        cp -r "species_catalogue/${R::-2}/${R}" "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/"
    done
    echo "Cleaning up website folders"
    for R in $(GET_REPS)
    do
        rm "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}_annotated.gff"
        rm "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}_annotated_with_mobilome.gff"
        mv "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/${R}.gff.noseq" "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}.gff"
    done
}


function CopyFTPFiles {
    echo "Copying files to the FTP folder"
    cd "${RESULTS_PATH}"
    cp -r all_genomes* "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    cp -r gene_catalogue "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    cp -r genomes-all_metadata.tsv "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    cp -r kraken2_db* "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    cp -r phylogenies "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    cp -r protein_catalogue "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    cp -r README.txt "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/README_${CATALOGUE_VERSION}.txt"
    cp -r species_catalogue "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/"
    for R in $(GET_REPS)
    do
        rm "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/genome/${R}_annotated.gff"
        mv "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/genome/${R}_annotated_with_mobilome.gff" \
        "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/genome/${R}.gff"
        rm "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/${R}.gff.noseq"
        # Replace the all_genomes GFF with a GFF that includes the mobilome
        rm "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/all_genomes/${R::-2}/${R}/genomes1/${R}.gff"
        cp "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/genome/${R}.gff" \
        "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/all_genomes/${R::-2}/${R}/genomes1/"
    done
}


function CopyAdditionalFiles {
    echo "Copying additional files"
    cd "${RESULTS_PATH}"
    cp -r additional_data "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/"
    rm "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/additional_data/intermediate_files/ena_location_warnings.txt"
    cd "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/additional_data"
    sbatch -p production --mem=1G -t 20:00:00 --ntasks=1 -o /dev/null -J gzip_mgyg_genomes --wrap="tar -czvf mgyg_genomes.tar.gz mgyg_genomes && rm -r mgyg_genomes"
    cd "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/gene_catalogue"
    sbatch -p production --mem=1G -t 10:00:00 --ntasks=1 -o /dev/null -J gzip_gene_catalogue --wrap="gzip gene_catalogue-100.ffn"
}


function ZipAllGenomes {
    echo "Zipping files in the all_genomes folder"
    cd "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/all_genomes"
    FOLDERS=$(ls -d MGYG*)
    for F in $FOLDERS
    do
        cd "$F"
        SUBFOLDERS=$(ls -d MGYG*)
        for S in $SUBFOLDERS
        do
            sbatch -p production --mem=1G --ntasks=1 -t 05:00:00 -o /dev/null -J gzip_${S}_gffs --wrap="gzip ${S}/genomes1/MGYG*gff"
        done
        cd ..
    done
}


while getopts 'd:f:v:r:j:' flag; do
    case "${flag}" in
        d) export SAVE_TO_PATH=$OPTARG ;;
        f) export CATALOGUE_FOLDER=$OPTARG ;;
        v) export CATALOGUE_VERSION=$OPTARG ;;
        r) export RESULTS_PATH=$OPTARG ;;
        j) PREV_JSON_PATH=$OPTARG ;;
        *) Usage exit 1 ;;
    esac
done

if [[ -z $SAVE_TO_PATH ]] || [[ -z $CATALOGUE_FOLDER ]] || [[ -z $RESULTS_PATH ]] || [[ -z $CATALOGUE_VERSION ]]; then
  echo 'Not all of the arguments are provided'
  Usage
fi

if [[ -n "$PREV_JSON_PATH" ]]; then
    export PREV_JSON_PATH
fi

GenerateDirectories
cd "${RESULTS_PATH}"
GenerateWebsiteGFFs
CopyWebsiteFiles
CopyFTPFiles
CopyAdditionalFiles
ZipAllGenomes
cd "${RESULTS_PATH}"
echo "Script is done working. Wait for all cluster jobs to complete."
