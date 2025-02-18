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
import os
import sys

from check_sample_and_mag_validity import load_translation


def main(input_folder, remove_list, outfile):
    metadata_table_file = os.path.join(input_folder, "ftp", "genomes-all_metadata.tsv")
    translation_dict = dict()
    with open(remove_list, "r") as file_in, open(outfile, "w") as file_out:
        for line in file_in:
            if line.startswith("MGYG"):
                file_out.write(line)
            else:
                insdc_acc, description = line.strip().split("\t")
                if len(translation_dict) == 0:
                    translation_dict = load_translation(metadata_table_file, to_insdc=False)
                try:
                    file_out.write(f"{translation_dict[insdc_acc]}\t{description}\n")
                except KeyError:
                    sys.exit(f"Unable to find the MGYG accession for accession {insdc_acc} in the remove list file.")
    

def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "The script uses the metadata table to look up MGYG accessions for any of the genomes that "
            "we are removing that have their original accessions provided. The output is a file with all "
            "accessions converted to MGYG."
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
        required=True,
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
        default="remove_list_mgyg.txt",
        help=(
            "Path to the file where the output will be saved to. Default: remove_list_mgyg.txt"
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

