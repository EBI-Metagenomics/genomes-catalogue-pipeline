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


def main(input_folder, checkm, output, remove):
    genome_list = [_ for _ in os.listdir(input_folder) if _.endswith(("fa", "fna"))]
    remove_list = load_checkm(checkm, genome_list)
    print_result(remove_list, output)
    if remove:
        for genome in remove_list:
            os.remove(os.path.join(input_folder, genome))


def load_checkm(checkm, genome_list):
    remove_list = set()
    with open(checkm, "r") as file_in:
        for line in file_in:
            fields = line.strip().split(",")
            if fields[0] in genome_list:
                if not qs50(float(fields[2]), float(fields[1])):
                    remove_list.add(fields[0])
    return remove_list


def print_result(remove_list, output):
    with open(output, "w") as file_out:
        for genome in remove_list:
            file_out.write('{}\n'.format(genome))


def qs50(contamination, completeness):
    contam_cutoff = 5.0
    qs_cutoff = 50.0
    if contamination > contam_cutoff:
        return False
    elif completeness - contamination * 5 < qs_cutoff:
        return False
    else:
        return True


def parse_args():
    parser = argparse.ArgumentParser(description='Remove downloaded NCBI genomes that have QS<50')
    parser.add_argument('-i', '--input-folder', required=True,
                        help='Path to the folder containing genomes downloaded from NCBI')
    parser.add_argument('-c', '--checkm', required=True,
                        help='Path to the CheckM results file')
    parser.add_argument('-o', '--output', default='QC_failed_genomes.txt',
                        help='Name of the file to print the list of QS<50 genomes to')
    parser.add_argument('--remove', action='store_true',
                        help='If the flag is used, the script will delete the genomes from the input folder, '
                             'otherwise it will only print a list of genomes that failed QC')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.input_folder, args.checkm, args.output, args.remove)