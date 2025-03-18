#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Copyright 2025 EMBL - European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import argparse
import os
import sys
import logging

logging.basicConfig(level=logging.INFO)


def main(input_directory, domain, outfile, extra_weight_table_user_provided):
    # define file paths
    additional_data_path = os.path.join(input_directory, "additional_data")
    genomes_path = os.path.join(additional_data_path, "mgyg_genomes")
    intermediate_files_path = os.path.join(additional_data_path, "intermediate_files")
    
    # Load data
    all_genomes = load_genomes(genomes_path)
    cluster_splits = load_cluster_splits(os.path.join(intermediate_files_path, "clusters_split.txt"))
    metadata_table_contents = load_metadata_table(os.path.join(input_directory, "genomes-all_metadata.tsv"))
    gunc_failed_list = load_gunc(os.path.join(intermediate_files_path, "gunc", "gunc_failed.txt"))


    
    # load mgyg to original accession translation
    mgyg_to_insdc, insdc_to_mgyg = load_name_conversion(os.path.join(input_directory, "additional_data", 
                                                                     "intermediate_files", 
                                                                     "renamed_genomes_name_mapping.tsv"))
    
    # Run checks
    report, issues = [], []
    # check genome counts
    logging.info("Checking genome count")
    report, issues = check_genome_counts(metadata_table_contents, cluster_splits, all_genomes, intermediate_files_path, 
                                         report, issues)
    # check cluster composition and isolates/MAGs
    # check general file presence
    report, issues = check_file_presence(input_directory, cluster_splits, report, issues)
    # Move the bit below elsewhere
    if gunc_failed_list is None:
        issues.append("FILE MISSING/CHECK NOT PERFORMED: gunc_failed.txt not found. Cannot verify genome counts.")
    
    # check geography
    report, issues = check_geography(metadata_table_contents, report, issues)
    print("REPORT")
    for message in report:
        print(message)
    print("ISSUES")
    for message in issues:
        print(message)


def check_file_presence(input_directory, cluster_splits, report, issues):
    # check the additional data folder
    additional_data_path = os.path.join(input_directory, "additional_data")
    if check_folder_existence(additional_data_path):
        issues = check_file_existence(os.path.join(additional_data_path, "combined_QC_failed_report.txt"), 
                                        issues, empty_ok=True)
        issues = check_file_existence(os.path.join(additional_data_path, "gtdbtk_results.tar.gz"), 
                                        issues, empty_ok=False)
        
        # check that genomes are never empty
        logging.info("Checking that genome files not empty")
        if check_folder_existence(os.path.join(additional_data_path, "mgyg_genomes")):
            for file in os.listdir(os.path.join(additional_data_path, "mgyg_genomes")):
                issues = check_file_existence(os.path.join(additional_data_path, "mgyg_genomes", file),
                                              issues, empty_ok=False)
        else:
            issues.append(f"FOLDER MISSING: could not find ${additional_data_path}/mgyg_genomes")
        
        # Check ncRNA results files
        logging.info("Checking ncRNA results files")
        ncrna_folder_path = os.path.join(additional_data_path, "ncrna_deoverlapped_species_reps")
        if check_folder_existence(ncrna_folder_path):
            for accession in cluster_splits:
                issues = check_file_existence(os.path.join(ncrna_folder_path, f"{accession}.ncrna.deoverlap.tbl"), 
                                              issues, empty_ok=True)
        else:
            issues.append(f"FOLDER MISSING: could not find ${ncrna_folder_path}")
        
        # Check that all pan-genomes are present for non-singletons:
        logging.info("Checking Panaroo outputs")
        panaroo_folder_path = os.path.join(additional_data_path, "panaroo_output")
        if check_folder_existence(panaroo_folder_path):
            for rep in cluster_splits:
                if len(cluster_splits[rep]) > 0:
                    issues = check_file_existence(os.path.join(panaroo_folder_path, f"{rep}_panaroo.tar.gz"), 
                                                  issues, empty_ok=False)
        else:
            issues.append(f"FOLDER MISSING: could not find ${panaroo_folder_path}")
    else:
        issues.append(f"FOLDER MISSING: could not folder ${additional_data_path}")
    return report, issues


def check_file_existence(file_path, issues, empty_ok=False):
    """Check if a file exists and is not empty (unless empty_ok=True)."""
    if not os.path.exists(file_path):
        issues.append(f"MISSING FILE: {file_path}")
    elif os.path.getsize(file_path) == 0 and not empty_ok:
        issues.append(f"EMPTY FILE: {file_path} should not be empty")
    return issues

    
def check_folder_existence(folder_path):
    return os.path.exists(folder_path)


def check_genome_counts(metadata_table, cluster_splits, all_genomes, intermediate_files_path, report, issues):
    """Ensure the number of genomes matches expected counts."""
    gunc_failed_list = load_gunc(os.path.join(intermediate_files_path, "gunc", "gunc_failed.txt"))

    if gunc_failed_list is None:
        issues.append("FILE MISSING/CHECK NOT PERFORMED: gunc_failed.txt not found. Cannot verify genome counts.")
        return report, issues

    expected_count = len(all_genomes)
    if expected_count == len(metadata_table):
        report.append("Genome count is correct")
    else:
        issues.append(f"GENOME COUNT ERROR: the number of genomes in the metadata table is "
                      f"{len(metadata_table)}, expected {expected_count} (number of genomes in "
                      f"mgyg_genomes minus number of genomes filtered out by GUNC")

    return report, issues

 
def load_gunc(gunc_path):
    gunc_failed_list = list()
    if os.path.exists(gunc_path):
        with open(gunc_path, "r") as f:
            for line in f:
                gunc_failed_list.append(line.strip())
        return gunc_failed_list
    else:
        return None
                
     
def check_geography(metadata_table_contents, report, issues):
    continents = ["Africa", "Antarctica", "Asia", "Europe", "North America", "Oceania", "South America"]
    unknown_count = 0
    for genome in metadata_table_contents:
        country = metadata_table_contents[genome]["Country"]
        continent = metadata_table_contents[genome]["Continent"]
        if continent not in continents:
            if continent.lower() == "not provided":
                if country.lower() == "not provided":
                    unknown_count = unknown_count + 1
                else:
                    # if a country is known, continent should be known
                    issues.append(f"METADATA GEOGRAPHY: (check that known country and unknown continent is expected): "
                                  f"{genome} {country} {continent}")
            else:
                issues.append(f"METADATA GEOGRAPHY: (uknown continent): {genome} {country} {continent}")
    unknown_percentage = round(100 * unknown_count / len(metadata_table_contents), 2)
    if unknown_percentage > 90:
        message = "This is high. Verify that this number is expected."
    else:
        message = ""
    report.append(f"Percentage of total genomes with unknown geography: {unknown_percentage}%. {message}")
    
    return report, issues


def load_metadata_table(metadata_table):
    fields_to_extract = ["Genome_type", "Completeness", "Contamination", "Species_rep", "Lineage", "Country",
                         "Continent", "Sample_accession", "Study_accession", "FTP_download"]
    metadata_table_contents = dict()
    with open(metadata_table, "r") as file_in:
        header = file_in.readline().strip()
        indices = {field: get_field_index(field, header.strip().split("\t")) for field in fields_to_extract}
        for line in file_in:
            fields = line.strip().split("\t")
            genome = fields[0]
            metadata_table_contents.setdefault(genome, dict())
            for field in fields_to_extract:
                metadata_table_contents[genome][field] = fields[indices[field]]
    return metadata_table_contents
            

def get_field_index(field_name, fields):
    if field_name in fields:
        return fields.index(field_name)
    else:
        sys.exit(f"Cannot find {field_name} field in the metadata_table")

        
def load_cluster_splits(filename):
    cluster_splits = dict()
    with open(filename, "r") as file_in:
        for line in file_in:
            if line.startswith("one_genome"):
                rep = line.strip().split(":")[-1].rsplit('.fa', 1)[0]
                cluster_splits[rep] = list()
            else:
                genomes = [genome.rsplit('.fa', 1)[0] for genome in line.strip().split(":")[-1].split(",")]
                rep = genomes[0]
                cluster_splits[rep] = genomes[1:]
    return cluster_splits

    
def load_name_conversion(name_mapping_file):
    mgyg_to_insdc = dict()
    insdc_to_mgyg = dict()
    with open(name_mapping_file, 'r') as file:
        for line in file:
            key, value = line.strip().split('\t')
            insdc_to_mgyg[key.rsplit('.fa', 1)[0]] = value.rsplit('.fa', 1)[0]
            mgyg_to_insdc[value.rsplit('.fa', 1)[0]] = key.rsplit('.fa', 1)[0]
    return mgyg_to_insdc, insdc_to_mgyg
   
    
def load_genomes(folder):
    return ['.'.join(f.split('.')[:-1]) for f in os.listdir(folder) if os.path.isfile(os.path.join(folder, f))]
    
    
def parse_args():
    parser = argparse.ArgumentParser(
        description="The script makes sure that the outputs of the catalogue generation pipeline are as expected."
    )
    parser.add_argument(
        "-i", "--input-directory",
        required=True,
        help="Path to the catalogue results folder",
    )
    parser.add_argument(
        "-d", "--domain",
        required=True,
        choices=['prok', 'euk'],
        help="Indicate whether the catalogue is prokaryotic or eukaryotic (prok or euk)",
    )
    parser.add_argument(
        "-o", "--outfile",
        required=False,
        help="Path to the output file. If not provided, report will be printed to STDOUT",
    )
    parser.add_argument(
        "--extra-weight-table",
        required=False,
        help="Path to the extra weight table that was given to the pipeline during catalogue generation.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args.input_directory, args.domain, args.outfile, args.extra_weight_table)

