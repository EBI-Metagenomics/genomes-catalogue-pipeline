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
import os

from assembly_stats import run_assembly_stats


def main(input_folder, outfile):
    genome_list = [filename for filename in os.listdir(input_folder)]
    with open(outfile, "w") as file_out:
        csv_writer = csv.writer(file_out, delimiter='\t')
        csv_writer.writerow(["Genome", "Length", "N50", "GC_content", "N_contigs"])
        for filename in genome_list:
            genome_accession = filename.rsplit(".", 1)[0]
            contig_stats = run_assembly_stats(os.path.join(input_folder, filename))
            csv_writer.writerow([genome_accession, contig_stats["Length"], contig_stats["N50"], 
                                 contig_stats["GC_content"], contig_stats["N_contigs"]])
        
    
def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "This script is part of the genome catalogue pipeline. It computes N50 for genomes and saves the results "
            "into a CSV file."
        )
    )
    parser.add_argument(
        "-i",
        "--input-folder",
        required=True,
        help=(
            "Path to the folder containing genome FASTA files"
        ),
    )
    parser.add_argument(
        "-o",
        "--outfile",
        required=False,
        help=(
            "Path to the file where the stats will be saved to"
        ),
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.input_folder,
        args.outfile,
    )
