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
import logging
import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests
from retry import retry

logging.basicConfig(level=logging.INFO)


def main(input_folder, remove_list_file, outfile, num_threads):
    if not outfile:
        outfile = "GENOME_CHECK_FAILED_ACCESSIONS"
    metadata_table_file = os.path.join(input_folder, "ftp", "genomes-all_metadata.tsv")
    if not os.path.isfile(metadata_table_file) and os.path.getsize(metadata_table_file) > 0:
        sys.exit("Provided input folder {} does not contain a metadata table in the expected location: "
                 "{} or the file is empty.".format(input_folder, metadata_table_file))
    if remove_list_file is not None and os.path.exists(remove_list_file):
        remove_list = load_remove_list(remove_list_file, metadata_table_file)
    else:
        remove_list = list()
    sample_mag_dictionary = load_metadata_table(metadata_table_file, remove_list)

    missing_samples = []
    missing_genomes = []

    # Multithreading for processing samples
    with ThreadPoolExecutor(max_workers=num_threads) as sample_executor:
        sample_futures = {
            sample_executor.submit(process_sample, sample, genome_list, num_threads): sample
            for sample, genome_list in sample_mag_dictionary.items() if sample != 'NA'
        }
        for future in as_completed(sample_futures):
            try:
                sample_result = future.result()
                missing_samples.extend(sample_result['missing_samples'])
                missing_genomes.extend(sample_result['missing_genomes'])
            except Exception as e:
                logging.error("Error processing sample: {}".format(e))

    if len(missing_samples) > 0 or len(missing_genomes) > 0:
        logging.info("Found genomes and/or samples from the previous catalogue version that are no longer in ENA")
        with open(outfile, "w") as file_out:
            for sample in missing_samples:
                file_out.write("{}\tsample\n".format(sample))
            for genome in missing_genomes:
                file_out.write("{}\tgenome\n".format(genome))
        logging.error("Missing genomes and samples are saved to {}. Check that these are indeed missing in ENA, "
                      "add them to the file containing a list of genomes to remove and restart the pipeline.".
                      format(outfile))
    else:
        logging.info("No missing genomes or samples found in the previous version of the catalogue")
        with open("GENOME_CHECK_ALL_GENOMES_OK", "w") as file_out:
            pass


@retry(tries=3, delay=10, backoff=1.5)
def run_full_url_request(full_url):
    r = requests.get(url=full_url)
    r.raise_for_status()
    return r


def process_sample(sample, genome_list, num_threads):
    """
    Process a single sample and its genomes.
    Returns a dictionary with missing samples and genomes.
    """
    missing_samples = []
    missing_genomes = []

    # Check if the sample exists
    try:
        run_full_url_request(f"https://www.ebi.ac.uk/ena/browser/api/xml/{sample}")
        keep_genomes = True
    except requests.exceptions.RequestException as e:
        logging.info("Sample {} not found in ENA. Error: {}".format(sample, e))
        missing_samples.append(sample)
        keep_genomes = False

    # Multithreading for processing genomes within the sample
    if keep_genomes:
        with ThreadPoolExecutor(max_workers=num_threads) as genome_executor:
            genome_futures = {
                genome_executor.submit(fetch_genome_data, genome): genome
                for genome in genome_list if not genome.startswith("GUT_")
            }
            for future in as_completed(genome_futures):
                genome = genome_futures[future]
                try:
                    future.result()
                except Exception as e:
                    logging.info("Genome {} not found in ENA. Error: {}".format(genome, e))
                    missing_genomes.append(genome)
    else:
        missing_genomes.extend(genome_list)

    return {'missing_samples': missing_samples, 'missing_genomes': missing_genomes}


def fetch_genome_data(genome):
    """Fetch genome data with the appropriate API endpoint."""
    if genome.startswith("GCA_"):
        endpoint = "xml"
    else:
        endpoint = "text"
    url = f"https://www.ebi.ac.uk/ena/browser/api/{endpoint}/{genome}"
    run_full_url_request(url)


def load_remove_list(remove_list_file, metadata_table_file):
    remove_list = list()
    translation_dict = dict()  # dictionary to translate MGYG accessions to INSDC accessions
    with open(remove_list_file, "r") as f:
        for line in f:
            col1 = line.strip().split("\t")[0]
            if col1.startswith("MGYG"):
                if not translation_dict:
                    translation_dict = load_translation(metadata_table_file, "mgyg-to-insdc")
                try:
                    acc = translation_dict[col1]
                except:
                    sys.exit("Removal of genome {} was requested but it is not present in the metadata file {}".
                             format(line, metadata_table_file))
            else:
                acc = col1
            if acc not in remove_list:
                remove_list.append(acc)
            else:
                logging.warning("Accession {} appears in file {} several times".format(acc, remove_list_file))
    return remove_list


def load_translation(metadata_table_file, direction):
    translation_dict = dict()
    with open(metadata_table_file, "r") as f:
        header = f.readline().strip()
        header_fields = header.split("\t")
        try:
            mgyg_index = header_fields.index("Genome")
            insdc_index = header_fields.index("Genome_accession")
        except ValueError:
            sys.exit("Unable to locate the genome and genome_accession fields in file {}".format(metadata_table_file))
        for line in f:
            parts = line.strip().split("\t")
            mgyg = parts[mgyg_index]
            insdc_acc = parts[insdc_index]
            if direction == "mgyg-to-insdc":
                translation_dict[mgyg] = insdc_acc
            else:
                translation_dict[insdc_acc] = mgyg
    return translation_dict


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
            sys.exit("Unable to load the metadata table. Field not found:", e)
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
    if len(remove_list) > 0:
        assert matches_in_remove_list > 0, ("None of the genomes in remove_list are present in the metadata table file "
                                            "{}. Check that the list of genomes to remove is correct".
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
            "Path to a tab-delimited file containing MAGs that should be removed from the catalogue during the update "
            "process. First column is the genome accession (MGYG or INSDC accession), second column is the reason for "
            "removal."
        ),
    )
    parser.add_argument(
        "-o",
        "--outfile",
        required=False,
        help=(
            "Path to the file where MAGs that are no longer available in ENA will be printed. If no outfile is "
            "specified, output will be saved to GENOME_CHECK_FAILED_ACCESSIONS"
        ),
    )
    parser.add_argument(
        "-t",
        "--threads",
        required=False,
        default=16,
        type=int,
        help=(
            "Number of threads to use. Default: 16"
        ),
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.input_folder,
        args.remove_list,
        args.outfile,
        args.threads,
    )
