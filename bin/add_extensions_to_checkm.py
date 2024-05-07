#!/usr/bin/env python3

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


def main(fasta_file_directory, checkm_directory):
    fasta_dict = load_file_list(fasta_file_directory)
    checkm_path = os.path.join(checkm_directory, "quality_report.tsv")
    assert os.path.isfile(checkm_path), "CheckM2 input doesn't exist"
    contents = ""
    with open(checkm_path, "r") as file_in:
        for line in file_in:
            if "Completeness" in line:
                contents += line
            else:
                genome_name = line.split("\t")[0]
                genome_with_ext = fasta_dict[genome_name]
                line = line.replace(genome_name, genome_with_ext)
                contents += line
    with open(checkm_path, "w") as file_out:
        file_out.write(contents)
        
    
def load_file_list(fasta_file_directory):
    fasta_dict = dict()
    file_list = os.listdir(fasta_file_directory)
    for file in file_list:
        name = file.rsplit(".", 1)[0]
        fasta_dict[name] = file
    return fasta_dict
        
    
def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "The script processes CheckM2 output to put the genome file extensions back in."
        )
    )
    parser.add_argument(
        "-d",
        dest="fasta_file_directory",
        required=True,
        help="Input directory containing FASTA files",
    )
    parser.add_argument(
        "-i",
        dest="checkm_directory",
        help=(
            "Folder containing output of checkm2"
        ),
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.fasta_file_directory,
        args.checkm_directory,
    )
