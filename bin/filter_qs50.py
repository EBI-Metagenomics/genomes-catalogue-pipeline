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
import shutil


def main(input_folder, checkm, output, output_csv, remove, filter):
    genome_list = [_ for _ in os.listdir(input_folder) if _.endswith(("fa", "fna"))]
    remove_list = load_checkm(checkm, genome_list, output_csv)
    print_result(remove_list, output)
    output_genomes = os.path.basename(input_folder) + '_filtered'
    if filter:
        if not os.path.exists(output_genomes):
            os.mkdir(output_genomes)
        for genome in genome_list:
            if genome not in remove_list:
                shutil.copy(os.path.join(input_folder, genome), os.path.join(output_genomes, genome))
    if remove:
        for genome in remove_list:
            os.remove(os.path.join(input_folder, genome))


def load_checkm(checkm, genome_list, output_csv):
    remove_list = set()
    with open(checkm, "r") as file_in, open(output_csv, "w") as file_out:
        file_out.write("genome,completeness,contamination\n")
        for line in file_in:
            fields = line.strip().split(",")
            if fields[0] in genome_list:
                if not qs50(float(fields[2]), float(fields[1])): 
                    remove_list.add(fields[0])
                else:
                    file_out.write(line)
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
    parser.add_argument('--output-csv', default='filtered_genomes.csv',
                        help='CSV with filtered genomes')
    parser.add_argument('--remove', action='store_true',
                        help='If the flag is used, the script will delete the genomes from the input folder, '
                             'otherwise it will only print a list of genomes that failed QC')
    parser.add_argument('--filter', action='store_true',
                        help='If the flag is used, the script will create a new folder with filtered genomes')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    if args.filter and args.remove:
        print('Please specify --filter OR --remove')
        sys.exit(1)
    main(args.input_folder, args.checkm, args.output, args.output_csv, args.remove, args.filter)