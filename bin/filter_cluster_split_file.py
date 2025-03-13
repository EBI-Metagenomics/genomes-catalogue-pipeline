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

logging.basicConfig(level=logging.INFO)


def main(infile, metadata_table, output):
    genome_list = load_existing_genomes(metadata_table)
    with open(infile, "r") as file_in, open(output, "w") as file_out:
        for line in file_in:
            # We only need to check singletons because clusters would not have been filtered
            if line.startswith("one_genome"):
                name = line.strip().split(":")[-1]  # genome file name
                name_without_ext = '.'.join(name.split('.')[:-1])
                if name_without_ext in genome_list:
                    file_out.write(line)
                else:
                    logging.info(f"Removing {name_without_ext} from the cluster split file of the previous catalogue "
                                 f"version. Reason: it is not present in the metadata table.")
            else:
                file_out.write(line)


def load_existing_genomes(metadata_table):
    """Load accessions from column 1 the metadata table into a list."""
    genome_list = []
    with open(metadata_table, 'r') as file:
        next(file)  # Skip the header
        for line in file:
            genome_list.append(line.strip().split('\t')[0])
    return genome_list


def parse_args():
    parser = argparse.ArgumentParser(description='Removes singleton genomes from the cluster split file if they '
                                                 'are not present in the metadata table.')
    parser.add_argument('-i', '--infile', required=True,
                        help='Path to the cluster split file.')
    parser.add_argument('-m', '--metadata-table', required=True,
                        help='Path to the metadata table.')
    parser.add_argument('-o', '--output', required=True,
                        help='Name of the output file where the filtered cluster split file will be written.')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.infile, args.metadata_table, args.output)