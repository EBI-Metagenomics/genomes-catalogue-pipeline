#!/usr/bin/env python3
# coding=utf-8

# This file is part of MGnify genomes catalogue pipeline.
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
import logging
import os
import sys

import requests
from retry import retry

logging.basicConfig(level=logging.INFO)


def main(input_folder, remove_list_file, outfile):
    metadata_table_file = os.path.join(input_folder, "ftp", "genomes-all_metadata.tsv")
    if not os.path.isfile(metadata_table_file) and os.path.getsize(metadata_table_file) > 0:
        sys.exit("Provided input folder {} does not contain a metadata table in the expected location: "
                 "{} or the file is empty.".format(input_folder, metadata_table_file))
    if remove_list_file is not None:
        remove_list = load_remove_list(remove_list_file)
    else:
        remove_list = list()
    sample_mag_dictionary = load_metadata_table(metadata_table_file, remove_list)
    missing_samples = list()
    missing_genomes = list()
    for sample, genome_list in sample_mag_dictionary.items():
        if sample == 'NA':
            continue
        keep_genomes = True
        try:
            r = run_full_url_request("https://www.ebi.ac.uk/ena/browser/api/xml/{}".format(sample))
        except:
            logging.info("Sample {} not found in ENA. Error {}".format(sample, r.status_code))
            missing_samples.append(sample)
            keep_genomes = False
        for genome in genome_list:
            if keep_genomes:
                if genome.startswith("GUT_"):
                    continue
                else:
                    if genome.startswith("GCA_"):
                        endpoint = "xml"
                    else:
                        endpoint = "text"
                    try:
                        r = run_full_url_request("https://www.ebi.ac.uk/ena/browser/api/{}/{}".format(
                            endpoint, genome))
                    except:
                        logging.info("Genome {} not found in ENA. Error {}".format(genome, r.status_code))
                        missing_genomes.append(genome)
            else:
                missing_genomes.append(genome)
    if len(missing_samples) > 0 or len(missing_genomes) > 0:
        logging.info("Found genomes and/or samples from the previous catalogue version that are no longer in ENA")
        with open(outfile, "w") as file_out:
            for sample in missing_samples:
                file_out.write("{}\n".format(sample))
            for genome in missing_genomes:
                file_out.write("{}\n".format(genome))
        # Exiting because the pipeline needs to fail. The user should evaluate the missing genomes and either 
        # resolve the issue if the missing status is incorrect or add them to the list of genomes to be 
        # removed from the catalogue
        sys.exit("Missing genomes and samples are saved to {}. Check that these are indeed missing in ENA, "
                 "add them to the file containing a list of genomes to remove and restart the pipeline.".
                 format(outfile))
    else:
        logging.info("No missing genomes or samples found in the previous version of the catalogue")


def prune_mag_list(sample_mag_dictionary, remove_list):
    pruned_sample_mag_dicionary = dict()
    return pruned_sample_mag_dicionary
    
    
@retry(tries=3, delay=10, backoff=1.5)
def run_full_url_request(full_url):
    r = requests.get(url=full_url)
    r.raise_for_status()
    return r


def load_remove_list(remove_list_file):
    remove_list = list()
    with open(remove_list_file, "r") as f:
        for line in f:
            line = line.strip()
            if line not in remove_list:
                remove_list.append(line)
            else:
                logging.warning("Accession {} appears in file {} several times".format(line, remove_list_file))
    return remove_list
    

def load_metadata_table(metadata_table_file, remove_list):
    sample_mag_dictionary = dict()
    matches_in_remove_list = 0
    with open(metadata_table_file, "r") as f:
        header = f.readline().strip()
        header_fields = header.split("\t")
        try:
            acc_index = header_fields.index("Genome_accession")
            sample_index = header_fields.index("Sample_accession")
        except ValueError as e:
            print("Field not found:", e)
        for line in f:
            parts = line.strip().split("\t")
            acc = parts[acc_index]
            sample = parts[sample_index]
            if acc not in remove_list:
                sample_mag_dictionary.setdefault(sample, list()).append(acc)
            else:
                logging.info("Skipping genome {} as it is in the list of genomes to remove from catalogue.".
                             format(acc))
                matches_in_remove_list += 1
    assert len(sample_mag_dictionary) > 0, ("There was an error loading data from the metadata table {}. "
                                            "No records were obtained".format(metadata_table_file))
    assert matches_in_remove_list > 0, ("None of the genomes in remove_list are present in the metadata table file {}. "
                                        "Check that the list of genomes to remove is correct".
                                        format(metadata_table_file))
    return sample_mag_dictionary
    
    
def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "This script is part of the genome catalogue update pipeline. It checks MAGs that are present in the "
            "existing version of the catalogue to identify MAGs and samples that are no longer available "
            "in ENA. If such MAGs are found, the pipeline will quit."
        )
    )
    parser.add_argument(
        "-i",
        "--input-folder",
        required=True,
        help=(
            "Path to the results folder of the previous version of the catalogue. The path should end with the "
            "version, for example, /my/path/cataloguess/sheep-rumen/v1.0/"
        ),
    )
    parser.add_argument(
        "-r",
        "--remove-list",
        required=False,
        help=(
            "Path to the file containing a list of MAGs that should be removed from the catalogue during the update "
            "process."
        ),
    )
    parser.add_argument(
        "-o",
        "--outfile",
        required=True,
        help=(
            "Path to the file where MAGs that are no longer available in ENA will be printed."
        ),
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.input_folder,
        args.remove_list,
        args.outfile,
    )