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

logging.basicConfig(level=logging.INFO)


def main(input_folder, metadata_table, output_folder):
    os.makedirs(output_folder, exist_ok=True)
    genome_list = load_existing_genomes(metadata_table)
    for file in ["Cdb.csv", "Sdb.csv"]:
        file_path = os.path.join(input_folder, file)
        if not os.path.exists(file_path):
            sys.exit(f"File {file_path} does not exist.")
        else:
            outfile_path = os.path.join(output_folder, file)
            with open(file_path, "r") as file_in, open(outfile_path, "w") as file_out:
                for line in file_in:
                    if not line.startswith("MGYG"):
                        # this is the header
                        file_out.write(line)
                    else:
                        accession = line.split(",")[0]
                        accession_without_ext = '.'.join(accession.split('.')[:-1])
                        if accession_without_ext in genome_list:
                            file_out.write(line)
                        else:
                            logging.info(f"Removing {accession_without_ext} from the {file} of the previous catalogue "
                                         f"version. Reason: it is not present in the metadata table.")
    mdb_path = os.path.join(output_folder, "Mdb.csv")
    if not os.path.exists(mdb_path):
        sys.exit(f"File {mdb_path} does not exist.")
    else:
        outfile_path = os.path.join(output_folder, "Mdb.csv")
        with open(mdb_path, "r") as file_in, open(outfile_path, "w") as file_out:
            for line in file_in:
                if not line.startswith("MGYG"):
                    file_out.write(line)
                else:
                    acc1, acc2, *_ = line.split(",")
                    acc1_without_ext, acc2_without_ext = map(lambda acc: acc.rsplit('.', 1)[0], (acc1, acc2))
                    if all(acc in genome_list for acc in (acc1_without_ext, acc2_without_ext)):
                        file_out.write(line)
                    else:
                        logging.info(f"Removing line {line.strip()} from the {file} of the previous catalogue version. "
                                     "Reason: at least one accession is not present in the metadata table.")


def load_existing_genomes(metadata_table):
    """Load accessions from column 1 the metadata table into a list."""
    genome_list = []
    with open(metadata_table, 'r') as file:
        next(file)  # Skip the header
        for line in file:
            genome_list.append(line.strip().split('\t')[0])
    return genome_list


def parse_args():
    parser = argparse.ArgumentParser(description='Removes singleton genomes from the drep files if they '
                                                 'are not present in the metadata table.')
    parser.add_argument('-i', '--input-folder', required=True,
                        help='Path to the drep folder containing Mdb.csv, Cdb.csv, Sdb.csv.')
    parser.add_argument('-m', '--metadata-table', required=True,
                        help='Path to the metadata table.')
    parser.add_argument('-o', '--output-folder', required=True,
                        help='Name of the output folder where the filtered files will be written.')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.input_folder, args.metadata_table, args.output_folder)