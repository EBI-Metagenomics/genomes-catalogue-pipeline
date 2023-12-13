#!/usr/bin/env bash

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


function GenerateDirectories {
  if [[ -d "${SAVE_TO_PATH}" ]]
  then
      if [[ ! -d "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}" ]]
      then
          mkdir ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}
      fi
      if [[ -d "${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}" ]]
      then
          echo "Directory ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION} already exists. Exiting."
          exit 1
      fi
      mkdir -p ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/
      mkdir -p ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/
  fi
}


function GenerateRNACentralJSON {
    echo "Generating RNAcentral JSON. This could take a while..."
    mkdir -p ${RESULTS_PATH}/additional_data/rnacentral
    mkdir -p ${RESULTS_PATH}/additional_data/rnacentral/GFFs
    
    echo "Copying GFFs"
    for R in $REPS
    do
        mkdir -p ${RESULTS_PATH}/all_genomes/${R::-2}/${R}/genomes1/
        mv ${RESULTS_PATH}/all_genomes/${R::-2}/${R}/*.gff* ${RESULTS_PATH}/all_genomes/${R::-2}/${R}/genomes1/
        cp ${RESULTS_PATH}/all_genomes/${R::-2}/${R}/genomes1/${R}.gff* ${RESULTS_PATH}/additional_data/rnacentral/GFFs/
    done
    
    echo "Running JSON generation"
    mitload miniconda && conda activate pybase
    python3 /nfs/production/rdf/metagenomics/pipelines/prod/genomes-pipeline/helpers/database-import-scripts/rnacentral/generate_rnacentral_json.py \
    -r /nfs/production/rdf/metagenomics/pipelines/prod/genomes-pipeline/helpers/database-import-scripts/rnacentral/rfam_model_lengths_14.9.txt \
    -m ${RESULTS_PATH}/genomes-all_metadata.tsv -o ${RESULTS_PATH}/additional_data/rnacentral/${CATALOGUE_FOLDER}-rnacentral.json \
    -d ${RESULTS_PATH}/additional_data/ncrna_deoverlapped_species_reps/ -g ${RESULTS_PATH}/additional_data/rnacentral/GFFs/ \
     -f ${RESULTS_PATH}/additional_data/mgyg_genomes/
     
    echo "Removing GFFs"
    rm -r ${RESULTS_PATH}/additional_data/rnacentral/GFFs/
    
    if [[ ! -f "${RESULTS_PATH}/additional_data/rnacentral/${CATALOGUE_FOLDER}-rnacentral.json" ]]
    then
        echo "Did not generate the RNAcentral JSON successfully"
        exit 1   
    fi
    
}


function CheckRNACentralErrors {
    # Read the file line by line, check specific lines, and extract second column
    value_3=$(awk -F '\t' 'NR==3 {print $2}' ${RESULTS_PATH}/additional_data/rnacentral/${CATALOGUE_FOLDER}-rnacentral.json.report)
    value_5=$(awk -F '\t' 'NR==5 {print $2}' ${RESULTS_PATH}/additional_data/rnacentral/${CATALOGUE_FOLDER}-rnacentral.json.report)
    value_6=$(awk -F '\t' 'NR==6 {print $2}' ${RESULTS_PATH}/additional_data/rnacentral/${CATALOGUE_FOLDER}-rnacentral.json.report)

    # Check if any of the values are greater than 0
    if (( value_3 > 0 || value_5 > 0 || value_6 > 0 )); then
        echo "Warning: the RNAcentral script had to skip some records. Make sure this is what is expected. If not, 
        abort execution of the script and investigate."
        cat ${RESULTS_PATH}/additional_data/rnacentral/${CATALOGUE_FOLDER}-rnacentral.json.report
        
        while true; do
            read -p "Do you want to abort? (yes/no): " answer
            case "$answer" in
                no)
                    break
                    ;;
                yes)
                    echo "Aborted."
                    exit 1
                    ;;
                *)
                    echo "Invalid response. Please enter 'yes' or 'no'."
                    ;;
            esac
        done
    fi
}


function RunRNACentralValidator {
    echo "Running RNAcentral validator"
    mitload miniconda && conda activate pybase
    cd /nfs/production/rdf/metagenomics/pipelines/prod/rnacentral-data-schema/
    python3 /nfs/production/rdf/metagenomics/pipelines/prod/rnacentral-data-schema/validate.py \
    ${RESULTS_PATH}/additional_data/rnacentral/${CATALOGUE_FOLDER}-rnacentral.json > \
    ${RESULTS_PATH}/additional_data/rnacentral/validator_output.txt
    
    cd ${RESULTS_PATH}
    
    if [ -s "${RESULTS_PATH}/additional_data/rnacentral/validator_output.txt" ]; then
    echo "RNAcentral validator found issues. Aborting."
    cat ${RESULTS_PATH}/additional_data/rnacentral/validator_output.txt
    exit 1
    fi
}


function GenerateWebsiteGFFs {
    echo "Generating GFFs for the website"
    cd ${RESULTS_PATH}/species_catalogue
    for R in ${REPS}
    do 
        while read line
        do 
            if [[ ${line} == "##FASTA" ]]
            then 
                break
            else 
                echo "$line"
            fi 
        done < ${R::-2}/${R}/genome/${R}_annotated_with_mobilome.gff > ${R::-2}/${R}/${R}.gff.noseq
    done    
}


function CopyWebsiteFiles {
    echo "Copying files to the website folder"
    cd ${RESULTS_PATH}
    cp phylo_tree.json ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/
    for R in ${REPS}
    do
        cp -r species_catalogue/${R::-2}/${R} ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/
    done
    echo "Cleaning up website folders"
    for R in ${REPS}
    do
        rm ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}_annotated.gff
        rm ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}_annotated_with_mobilome.gff
        mv ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/${R}.gff.noseq ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/website/${R}/genome/${R}.gff
    done
}


function CopyFTPFiles {
    echo "Copying files to the FTP folder"
    cd ${RESULTS_PATH}
    cp -r all_genomes* ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/
    cp -r gene_catalogue ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/
    cp -r genomes-all_metadata.tsv ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/
    cp -r kraken2_db* ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/
    cp -r phylogenies ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/
    cp -r protein_catalogue ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/
    cp -r README.txt ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/README_${CATALOGUE_VERSION}.txt
    cp -r species_catalogue ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/
    for R in ${REPS}
    do
        rm ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/genome/${R}_annotated.gff
        mv ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/genome/${R}_annotated_with_mobilome.gff \
        ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/genome/${R}.gff
        rm ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/species_catalogue/${R::-2}/${R}/${R}.gff.noseq
    done
}


function CopyAdditionalFiles {
    echo "Copying additional files"
    cd ${RESULTS_PATH}
    cp -r additional_data ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/
    cd ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/additional_data
    bsub -q production -M 1G -n 1 -o /dev/null "tar -czvf mgyg_genomes.tar.gz mgyg_genomes && rm -r mgyg_genomes"
    cd ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/gene_catalogue
    bsub -q production -M 1G -n 1 -o /dev/null "gzip gene_catalogue-100.ffn"
}


function ZipAllGenomes {
    echo "Zipping files in the all_genomes folder"
    cd ${SAVE_TO_PATH}/${CATALOGUE_FOLDER}/${CATALOGUE_VERSION}/ftp/all_genomes
    FOLDERS=$(ls -d MGYG*)
    for F in $FOLDERS
    do
        cd $F
        SUBFOLDERS=$(ls -d MGYG*)
        for S in $SUBFOLDERS
        do
            bsub -q production -M 1G -n 1 -o /dev/null "gzip ${S}/genomes1/MGYG*gff"
        done
        cd ..
    done  
}


while getopts 'd:f:v:r:' flag; do
    case "${flag}" in
        d) export SAVE_TO_PATH=$OPTARG ;;
        f) export CATALOGUE_FOLDER=$OPTARG ;;
        v) export CATALOGUE_VERSION=$OPTARG ;;
        r) export RESULTS_PATH=$OPTARG ;;
    esac
done

if [[ -z $SAVE_TO_PATH ]] || [[ -z $CATALOGUE_FOLDER ]] || [[ -z $RESULTS_PATH ]] || [[ -z $CATALOGUE_VERSION ]]; then
  echo 'Not all of the arguments are provided'
  Usage
fi


GenerateDirectories
cd ${RESULTS_PATH}
export REPS=$(cut -f14 genomes-all_metadata.tsv | grep -v "Species" | sort -u)
GenerateRNACentralJSON
CheckRNACentralErrors
RunRNACentralValidator
GenerateWebsiteGFFs
CopyWebsiteFiles
CopyFTPFiles
CopyAdditionalFiles
ZipAllGenomes
cd ${RESULTS_PATH}
echo "Script is done working. Wait for all cluster jobs to complete."