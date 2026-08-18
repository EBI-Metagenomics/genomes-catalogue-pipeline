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
import shutil

logging.basicConfig(level=logging.INFO)


def main(input_folder, checkm, output, output_csv, details_csv, remove, filter):
    genome_list = [_ for _ in os.listdir(input_folder) if _.endswith(("fa", "fna", "fasta"))]
    logging.info("Found {} input genomes. Beginning filtering.".format(len(genome_list)))
    remove_list, no_file = load_checkm(checkm, genome_list, output_csv, details_csv=details_csv)
    print_result(remove_list, output)
    output_genomes = os.path.basename(input_folder) + '_filtered'
    if filter:
        if not os.path.exists(output_genomes):
            os.mkdir(output_genomes)
        for genome in genome_list:
            if genome not in remove_list and genome not in no_file:
                shutil.copy(os.path.join(input_folder, genome), os.path.join(output_genomes, genome))
    if remove:
        for genome in remove_list:
            os.remove(os.path.join(input_folder, genome))


def load_checkm(checkm, genome_list, output_csv, details_csv=None):
    remove_list = set()
    no_file = set()  # track genomes that are not present in the fasta list but still are in the quality CSV
    details = list()
    
    # Make a list of genome accessions in the file folder (without extensions)
    genome_basenames = {os.path.splitext(g)[0] for g in genome_list}  # removes extension only (splits on the last .)
    with open(checkm, "r") as file_in, open(output_csv, "w") as file_out:
        file_out.write("genome,completeness,contamination\n")
        for line in file_in:
            line = line.strip()
            if line.startswith("genome,"):
                continue
            genome, completeness, contamination = line.split(",")
            if genome in genome_list:
                try:
                    reason = "" if qs50(float(contamination), float(completeness)) else "Failed QS50"
                except ValueError:
                    # EukCC reports NA when they can't assess a genome
                    logging.warning("Genome {} has no completeness/contamination value".format(genome))
                    reason = "Missing completeness/contamination value"
                if reason:
                    remove_list.add(genome)
                    details.append("{},{}".format(line, reason))
                else:
                    file_out.write(line + "\n")
            else:
                # Check if the genome is missing in the genomes folder because of an incorrect file extension - this
                # needs to be fixed
                if genome in genome_basenames:
                    raise ValueError(
                        f"Genome '{genome}' in the CheckM file does not match the name of the FASTA file due to "
                        "incorrect or missing file extension."
                    )
                else:
                    # Sometimes a genome might have been filtered out from the fasta set but left behind in the
                    # checkm output; log this but don't fail
                    logging.warning("Genome {} is present in the CheckM file but genome FASTA doesn't exist".format(
                        genome))
                    no_file.add(genome)
    if details_csv:
        with open(details_csv, "w") as details_out:
            for line in details:
                details_out.write(line + "\n")
    return remove_list, no_file 


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
    parser.add_argument('-o', '--output', default='QS50_failed_genomes.txt',
                        help='Name of the file to print the list of QS<50 genomes to')
    parser.add_argument('--output-csv', default='filtered_genomes.csv',
                        help='CSV with filtered genomes')
    parser.add_argument('--details-csv', required=False,
                        help='An optional path to file where completeness and contamination of removed genomes '
                             'will be printed to.')
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
    main(args.input_folder, args.checkm, args.output, args.output_csv, args.details_csv, args.remove, args.filter)
    