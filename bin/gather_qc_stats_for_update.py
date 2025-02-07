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
import logging
import os
import sys

logging.basicConfig(level=logging.INFO)


def main(stats_file_new, stats_file_prev_version, checkm_previous_version, checkm_new_genomes, extra_weight_new, 
         previous_catalogue_version, outfile_stats, outfile_extra_weight):
    extra_weight_previous_version = os.path.join(previous_catalogue_version, "additional_data", "intermediate_files",
                                                 "extra_weight_table.txt")
    # combine extra weight information for old and new genomes into a new file
    combine_and_print(extra_weight_previous_version, extra_weight_new, outfile_extra_weight)
    
    # combine assembly quality for old and new genomes into a new file
    extract_and_merge_stats((stats_file_prev_version, stats_file_new), (checkm_previous_version, checkm_new_genomes), 
                            outfile_stats)
    

def extract_and_merge_stats(stats_file_list, checkm_file_list, outfile_stats):
    genome_data = dict()
    # Load N50
    for file in stats_file_list:
        with open(file, "r") as file_in:
            reader = csv.DictReader(file_in, delimiter='\t')
            for row in reader:
                genome = row["Genome"]
                genome_data.setdefault(genome, dict())
                genome_data[genome]["N50"] = row["N50"]
    # Load completeness and contamination
    for file in checkm_file_list:
        with open(file, "r") as file_in:
            reader = csv.DictReader(file_in, delimiter=',')
            for row in reader:
                genome = row["genome"]
                # remove extension
                for ext in [".fa", ".fna", ".fasta"]:
                    if genome.lower().endswith(ext):
                        genome = genome[:-len(ext)]
                        break
                genome_data[genome]["Completeness"] = row["completeness"]
                genome_data[genome]["Contamination"] = row["contamination"]
    with open(outfile_stats, "w", newline="") as file_out:
        csv_writer = csv.writer(file_out, delimiter='\t')
        csv_writer.writerow(["Genome", "Completeness", "Contamination", "N50"])
        for genome, data in genome_data.items():
            try:
                csv_writer.writerow([
                    genome,
                    data['Completeness'],
                    data['Contamination'],
                    data['N50']
                    ])
            except KeyError:
                sys.exit("Unable to get gather assembly stats data for genome {}. Available data: {}".format(genome,
                                                                                                             data))
  
                
def combine_and_print(file1, file2, outfile):
    with open(outfile, 'w') as file_out:
        for file in (file1, file2):
            with open(file, 'r') as f:
                file_out.write(f.read())


def parse_args():
    parser = argparse.ArgumentParser(description='''
    The script is part of the catalogue update pipeline. It gathers QC stats (completeness, contamination, N50) 
    to recompute clusters when adding/removing genomes. It also combines old and new extra weight information 
    into a single file.
    ''')
    parser.add_argument('--stats-file-new', required=False,
                        help='A TSV file with genome ID in the first column and assembly stats in the rest of the '
                             'columns (genomes being added to the catalogue only).')
    parser.add_argument('--stats-file-prev-version', required=True,
                        help='A TSV file with genome ID in the first column and assembly stats in the rest of the '
                             'columns (genomes from the previous catalogue version).')
    parser.add_argument('--checkm-previous-version', required=True,
                        help='A CSV file with checkM2 values from the previous catalogue version')
    parser.add_argument('--checkm-new-genomes', required=False,
                        help='A CSV file with checkM2 values for any genomes being added to the catalogue')
    parser.add_argument('--extra-weight-new-genomes', required=False,
                        help='The extra weight file for the new genomes')
    parser.add_argument('--previous-version-path', required=True,
                        help='Path to the previous catalogue version')
    parser.add_argument('--outfile-stats', required=True,
                        help='Path to the file where the results will be written. The output combines genomes '
                             'in the previous catalogue with any added genomes and for each included genome lists '
                             'accession, completeness, contamination, N50')
    parser.add_argument('--outfile-extra-weight', required=True,
                        help='Path to the file where the the combined extra weight table will be printed to')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(
        args.stats_file_new, 
        args.stats_file_prev_version,
        args.checkm_previous_version, 
        args.checkm_new_genomes, 
        args.extra_weight_new_genomes,
        args.previous_version_path,
        args.outfile_stats,
        args.outfile_extra_weight,
    )
