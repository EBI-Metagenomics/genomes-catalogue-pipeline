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


def main(remove_list_file, add_list_file, message, output_file):
    already_in_remove_list = set()
    if os.path.isfile(remove_list_file):
        with open(remove_list_file, 'r') as file_in, open(output_file, "w") as file_out:
            for line in file_in:
                if line.startswith("MGYG"):
                    file_out.write(line)
                    already_in_remove_list.add(line.split('\t')[0].strip())
    
    with open(add_list_file, 'r') as file_in, open(output_file, 'a') as file_out:
        for line in file_in:
            accession = line.strip()
            if accession not in already_in_remove_list:
                file_out.write(f"{accession}\t{message}\n")
                

def parse_args():
    parser = argparse.ArgumentParser(description='Script adds genomes that existed in the previous version of a '
                                                 'catalogue but failed QC checks during the update to the remove '
                                                 'list. Only genomes that are not already present in the remove '
                                                 'list are added.')
    parser.add_argument('-r', '--remove-list', required=True,
                        help='Path to the file containing the list of genomes to remove. File should be tab-delimited '
                             'with the MGYG accession in the first column and reason for removal in the second.')
    parser.add_argument('-a', '--add-list', required=True,
                        help='Path to the file containing the list of genomes to add to the remove list.')
    parser.add_argument('-m', '--message', required=True,
                        help='Reason for removal that will be printed to the remove file.')
    parser.add_argument('-o', '--output', required=True,
                        help='Name of the output file.')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.remove_list, args.add_list, args.message, args.output)