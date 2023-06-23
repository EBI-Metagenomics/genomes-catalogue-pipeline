#!/usr/bin/env python3
# coding=utf-8

# This file is part of MGnify genome analysis pipeline.
#
# MGnify genome analysis pipeline is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MGnify genome analysis pipeline is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with MGnify genome analysis pipeline. If not, see <https://www.gnu.org/licenses/>.


import argparse
import csv
import logging
import os
import sys
import time
from ftplib import FTP, all_errors

from utils import run_request

logging.basicConfig(level=logging.INFO)

ENA_ENDPOINT = "https://www.ebi.ac.uk/ena/portal/api/search"


def main(genome_info, study_info, outfile, genomes_dir, name_mapping):
    """Identifies isolate genomes and MAGs and creates an extra weight table for drep"""

    # If a name mapping file is provided, the code will use the names on the mapping file
    # as the expectation is that the genomes_dir will contain the MAGs/Isolates under a
    # different name space, but all the other files will use the names in the mapping file
    extra_weights, extension, name_mapping_dict = initialize_weights_dict(
        genomes_dir, name_mapping=name_mapping
    )

    if study_info:
        extra_weights = add_study_info(study_info, extra_weights)
    if genome_info:
        extra_weights = add_genome_info(genome_info, extra_weights)

    empty_ncbi_records = set()
    for record in extra_weights:
        if extra_weights[record] == "":
            if record.startswith("GC"):
                ## ADD GCF HANDLING
                empty_ncbi_records.add(record)
            elif record.startswith("CA"):
                extra_weights[record] = "0"
            else:
                # ADD ENA ISOLATES HANDLING
                logging.error(
                    "Unable to assign weight to genome {}. Assigning 0.".format(record)
                )

    if len(empty_ncbi_records) > 0:
        extra_weights = add_ncbi_information(
            extra_weights, empty_ncbi_records, extension
        )

    extra_weights = check_table(extra_weights)

    print_results(extra_weights, outfile, name_mapping_dict=name_mapping_dict)


def initialize_weights_dict(genomes_dir, name_mapping=None):
    """
    Initializes a weights dictionary for genomes in a directory.
    Args:
        genomes_dir (str): Path to the directory containing genome files.
        name_mapping (str): Path to the genome name mapping file.
    Returns:
        tuple: A tuple containing the extra weights dictionary and the extension of the genome files.
    """
    extra_weights = {}
    genomes_dir_contents = os.listdir(genomes_dir)
    extension = ""

    name_mapping_dict = {}
    if name_mapping:
        with open(name_mapping, "r") as nm_f:
            tsv_reader = csv.reader(nm_f, delimiter="\t")
            for old_name, new_name in tsv_reader:
                name_mapping_dict[new_name] = old_name

    for genome_file in genomes_dir_contents:
        # Get the new name from the mapping, otherwise keep the current one
        genome = name_mapping_dict.get(genome_file, genome_file)
        print(f"{genome_file} -> {genome}")
        if genome.strip().split(".")[-1] not in ["fa", "fasta"]:
            logging.info(f"Not analyzing {genome} - not a fasta file.")
        else:
            if not extension:
                extension = genome.strip().split(".")[-1]
            # Add to result dictionary #
            extra_weights[genome] = ""
    return extra_weights, extension, name_mapping_dict


def add_study_info(study_info_file, extra_weights):
    """Read the study information, used to override the weight"""
    with open(study_info_file, "r") as file_in:
        for line in file_in:
            study, genome_type = line.strip().split("\t")
            weight = assign_weight(genome_type)
            genomes_in_study = get_genomes_in_study(study)
            genomes_in_study = add_extension(genomes_in_study, extra_weights)
            for genome in genomes_in_study:
                if genome in extra_weights:
                    extra_weights[genome] = weight
    return extra_weights


def assign_weight(genome_type):
    if genome_type.lower().startswith("isolate"):
        weight = "1000"
    elif genome_type.upper().startswith("MAG"):
        weight = "0"
    else:
        raise ValueError("Unknown genome type: {}".format(genome_type))
    return weight


def get_genomes_in_study(study):
    genomes_in_study = set()
    if not study.startswith("PRJ"):
        raise ValueError(
            "Cannot process study accession {}. A primary accession is required.".format(
                study
            )
        )
    ena_request_result = run_ena_request(study)
    study_is_ncbi = False
    if len(ena_request_result.split("\n")) < 3:
        study_is_ncbi = True
    else:
        for line in ena_request_result.splitlines():
            if not line.startswith("accession"):
                genome = line.strip().split("\t")[-1].split("/")[-1].split(".")[0]
                if genome.startswith("C"):
                    genomes_in_study.add(genome)
                else:
                    study_is_ncbi = True
    if study_is_ncbi:
        ncbi_request_result = run_ncbi_request(study)
        for line in ncbi_request_result.splitlines():
            if not line.startswith("accession"):
                genomes_in_study.add(line.split()[0])
    if len(genomes_in_study) == 0:
        sys.exit(
            "Unable to get a list of genomes for study {} from ENA. "
            "Provided extra weight info cannot be used.".format(study)
        )
    return genomes_in_study


def run_ena_request(study):
    query = {
        "result": "wgs_set",
        "query": (
            'study_accession="{}" AND assembly_type="metagenome-assembled genome (mag)"'.format(
                study
            )
        ),
        "fields": "fasta_file",
        "format": "tsv",
    }
    r = run_request(query, ENA_ENDPOINT)
    return r.content.decode()
    

def run_ncbi_request(study):
    query = {
        "result": "assembly",
        "query": (
            'study_accession="{}"'.format(
                study
            )
        ),
        "format": "tsv",
    }
    r = run_request(query, ENA_ENDPOINT)
    return r.content.decode()


def add_extension(genomes_in_study, extra_weights):
    for full_genome_fname in extra_weights.keys():
        genome_acc = full_genome_fname.split(".")[0]
        if genome_acc in genomes_in_study:
            genomes_in_study.remove(genome_acc)
            genomes_in_study.add(full_genome_fname)
    return genomes_in_study


def add_genome_info(genome_info_file, extra_weights):
    """Get the genome info, "isolate" or "MAG"."""
    with open(genome_info_file, "r") as file_in:
        tsv_reader = csv.reader(file_in, delimiter="\t")
        for genome, genome_type in tsv_reader:
            weight = assign_weight(genome_type)
            if genome in extra_weights:
                extra_weights[genome] = weight
            else:
                sys.exit(
                    "Extra weight information for genome {} was provided but genome is"
                    " not found in the genomes folder. Check naming format - is the"
                    " extension missing? Extra weight information cannot be used.".format(
                        genome
                    )
                )
    return extra_weights


def add_ncbi_information(extra_weights, empty_ncbi_records, extension):
    ncbi_server = "ftp.ncbi.nlm.nih.gov"
    ncbi_dir = "genomes/genbank"
    ncbi_summary_file = "assembly_summary_genbank.txt"
    temp_file = "ftpout.temp"
    max_attempts = 6
    attempt = 1
    sleep_time = 10
    logging.info("Obtaining genome type information from NCBI...")
    while attempt < max_attempts:
        try:
            ftp = FTP(ncbi_server)
            ftp.login()
            ftp.cwd(ncbi_dir)
            temp_out = open(temp_file, "wb")
            ftp.retrbinary("RETR {}".format(ncbi_summary_file), temp_out.write)
            ftp.quit()
            break
        except all_errors as e:
            logging.error(e)
            logging.info("Retrying...")
            time.sleep(sleep_time)
            attempt += 1
    extra_weights = parse_ftp(extra_weights, temp_file, empty_ncbi_records, extension)
    return extra_weights


def parse_ftp(extra_weights, temp_file, empty_ncbi_records, extension):
    with open(temp_file, "rb") as ftp_in:
        for line in ftp_in:
            line = line.decode()
            if line.startswith("#"):
                pass
            else:
                acc = line.strip().split("\t")[0].split(".")[0] + "." + extension
                if acc in empty_ncbi_records:
                    if "metagenom" in line.strip().split("\t")[20]:
                        extra_weights[acc] = "0"
                    elif "isolate" in line.strip().split("\t")[20]:
                        extra_weights[acc] = "1000"
                    else:
                        # ADD SAMPLE HANDLING
                        pass
    return extra_weights


def check_table(extra_weights):
    for key, value in extra_weights.items():
        if value == "":
            logging.error(
                "Unable to assign weight to genome {}. Assigning 0.".format(key)
            )
            extra_weights[key] = "0"
    return extra_weights


def print_results(extra_weights, outfile, name_mapping_dict):
    """Generate the result tsv file."""
    with open(outfile, "w") as table_out:
        table_writer = csv.writer(table_out, delimiter="\t")
        for genome_name, weight in extra_weights.items():
            genome_name = next((key for key, value in name_mapping_dict.items() if value == genome_name), genome_name)
            table_writer.writerow([genome_name, weight])


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Identifies isolate genomes and MAGs and creates an extra"
            " weight table for drep. It is strongly suggested that if"
            " the genome list includes any known isolates, the --study-info"
            " --genome-info parameters are used to indicate that. Without them"
            " the script will try to identify isolates from metadata which is not "
            " always available."
        )
    )
    parser.add_argument(
        "-s",
        "--study-info",
        help=(
            "If the entire study includes only one type of genomes (MAGs only or"
            " isolates only) and this information is already available, provide a path"
            " to a tab-delimited file where the first column contains primary study IDs (starting with PRJ)"
            " and the second column contains the type (MAG or isolate)."
        ),
    )
    parser.add_argument(
        "-g",
        "--genome-info",
        help=(
            "If any of the studies contain a mix of isolate and MAG genomes or if"
            " information for only some of the genomes is available, provide a path to a"
            " file containing per genome information. First column should be the genome"
            " accession (original one, not MGYG), second column the type of genome (MAG or isolate)."
        ),
    )
    parser.add_argument(
        "-n",
        "--name-mapping",
        required=False,
        help=(
            "If this is provided, the genomes from the genome-info"
            " and study-info will be renamed following the mapping."
        ),
    )
    parser.add_argument(
        "-o",
        "--outfile",
        required=True,
        help="Path to the output file where the extra weight table will be stored.",
    )
    parser.add_argument(
        "-d",
        "--genomes-dir",
        required=True,
        help="Path to the directory where input genome fasta files for dereplication are stored.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.genome_info,
        args.study_info,
        args.outfile,
        args.genomes_dir,
        args.name_mapping,
    )
