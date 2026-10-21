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
import io
import logging
import os
import sys
import time

import requests
from retry import retry

logging.basicConfig(level=logging.INFO)

# -----------------------------
# Networking setup
# -----------------------------

session = requests.Session()

last_request_time = 0
MIN_INTERVAL = 0.5

PORTAL_BATCH_SIZE_MAGS = 250
PORTAL_BATCH_SIZE_SAMPLES = 50


@retry(tries=3, delay=10, backoff=2)
def run_full_url_request(full_url):

    global last_request_time

    elapsed = time.time() - last_request_time
    if elapsed < MIN_INTERVAL:
        time.sleep(MIN_INTERVAL - elapsed)
    last_request_time = time.time()

    r = session.get(full_url)

    # Handle too many requests
    if r.status_code == 429:
        retry_after = r.headers.get("Retry-After")
        wait = int(retry_after) if retry_after else 60
        logging.warning(f"Rate limited. Sleeping {wait}s")
        time.sleep(wait)
        raise Exception("Retry after rate limit")

    r.raise_for_status()
    return r


# -----------------------------
# Utility helpers
# -----------------------------

def chunk_list(data, size):
    for i in range(0, len(data), size):
        yield data[i:i + size]
        

# -----------------------------
# Portal API batch checks
# -----------------------------

def check_accessions_portal(accessions, result_field, result_table):
    missing = []

    portal_batch_size = PORTAL_BATCH_SIZE_SAMPLES if result_table == "sample" else PORTAL_BATCH_SIZE_MAGS
    for batch in chunk_list(accessions, portal_batch_size):
        # Decide which fields to use - samples can appear in two different fields in ENA
        if result_table == "sample" and result_field == "sample_accession":
            query_fields = ["sample_accession", "secondary_sample_accession"]
        else:
            query_fields = [result_field]

        # Build query
        if len(query_fields) == 1:
            # The query is not a sample
            accession_list = ",".join(f'"{x}"' for x in batch)
            query = f"{query_fields[0]} IN ({accession_list})"
        else:
            # The query is a sample: expand each accession
            query_parts = []
            for acc in batch:
                sub_parts = [f'{field}="{acc}"' for field in query_fields]
                query_parts.append(f"({' OR '.join(sub_parts)})")
            query = " OR ".join(query_parts)

        fields_param = ",".join(query_fields)
        url = (
            "https://www.ebi.ac.uk/ena/portal/api/search?"
            f"result={result_table}"
            f"&fields={fields_param}"
            "&format=tsv"
            f"&query={query}"
        )
        r = run_full_url_request(url)
        reader = csv.DictReader(io.StringIO(r.text), delimiter="\t")
        returned = set()
        for row in reader:
            for field in query_fields:
                if row.get(field):
                    returned.add(row[field].strip())

        for acc in batch:
            if acc not in returned:
                missing.append(acc)

    return missing


# -----------------------------
# Main workflow
# -----------------------------

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
    sample_mag_dictionary = load_metadata_table(metadata_table_file, remove_list)  # key=sample;val=list of mgygs

    all_samples = []
    erz_genomes = []
    gca_genomes = []
    wgs_set_genomes = []

    for sample, genomes in sample_mag_dictionary.items():

        if sample != "NA":
            all_samples.append(sample)

        for g in genomes:
            if not g.startswith("GUT_"):
                if g.startswith("ERZ"):
                    erz_genomes.append(g)
                elif g.startswith("GCA"):
                    gca_genomes.append(g)
                else:
                    wgs_set_genomes.append(g)
                    
    logging.info(f"Checking {len(all_samples)} samples")
    logging.info(f"Checking {len(erz_genomes) + len(gca_genomes) + len(wgs_set_genomes)} genomes")

    portal_checks = [
        (all_samples, "sample_accession", "sample"),
        (erz_genomes, "accession", "analysis"),
        (gca_genomes, "accession", "assembly"),
        (wgs_set_genomes, "wgs_set", "wgs_set"),
    ]

    # Run portal checks
    missing_lists = [check_accessions_portal(acc_list, field, table) for acc_list, field, table in portal_checks]
    
    # Split missing accessions into samples and genomes
    missing_samples = missing_lists[0]
    missing_genomes = sum(missing_lists[1:], [])  # combine ERZ + GCA + WGS
    
    if missing_samples or missing_genomes:
        logging.info("Found genomes and/or samples from the previous catalogue version that are no longer in ENA")
        with open(outfile, "w") as file_out:
            for sample in missing_samples:
                file_out.write(f"{sample}\tsample\n")
            for genome in missing_genomes:
                file_out.write(f"{genome}\tgenome\n")
        # Todo: if a sample is missing, report the associated genomes as genomes associated with missing sample

        logging.error(f"Missing genomes and samples are saved to {outfile}. Check that these are indeed missing in ENA, "
                      "add them to the file containing a list of genomes to remove and restart the pipeline. If a "
                      "sample is missing, all of the associated genomes have been added to the file and should be "
                      "removed from the catalogue. If the sample is found in ENA but some of the genomes are missing, "
                      "only the missing genomes will be saved to this file to be removed.")

    else:
        logging.info("No missing genomes or samples found in the previous version of the catalogue")
        with open("GENOME_CHECK_ALL_GENOMES_OK", "w"):
            pass


def load_remove_list(remove_list_file, metadata_table_file):
    remove_list = list()
    translation_dict = dict()  # dictionary to translate MGYG accessions to INSDC accessions
    with open(remove_list_file, "r") as f:
        for line in f:
            col1 = line.strip().split("\t")[0]
            if col1.startswith("MGYG"):
                if not translation_dict:
                    translation_dict = load_translation(metadata_table_file, to_insdc=True)
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


def load_translation(metadata_table_file, to_insdc):
    """
    Function loads INSDC/MGYG pairs from the metadata table
    @param metadata_table_file: path to the metadata table
    @param to_insdc: if True, translation dictionary will be from MGYG to INSDC; if False -  from INSDC to MGYG
    @return: translation_dict where the MGYG and INSDC accessions are key/value pairs  
    """
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
            if to_insdc:
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
            sys.exit(f"Unable to load the metadata table. Field not found: {e}")
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
