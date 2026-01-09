#!/usr/bin/env python3
# coding=utf-8

# This file is part of MGnify genomes catalogue pipeline.
#
# MGnify genomes catalogue pipeline is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MGnify genomes catalogue pipeline is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with MGnify genomes catalogue pipeline. If not, see <https://www.gnu.org/licenses/>.


import argparse
import os


def main(qc, gunc, gtdb, outfile):
    header_written = False
    
    with open(outfile, 'w') as file_out:
        header_written = process_file(qc, file_out, header_written, "QS50 failed")
        header_written = process_file(gunc, file_out, header_written, "GUNC failed")

        with open(gtdb, 'r') as file_in:
            for line in file_in:
                parts = line.strip().split(',')
                if parts[1] == "Undefined":
                    header_written = write_header(file_out, header_written)
                    file_out.write(f"{parts[0]}\tUnknown taxonomic domain\n")


def process_file(file_path, file_out, header_written, message, delimiter='\t'):
    if not os.path.exists(file_path):
        return header_written  # Skip if the file doesn't exist

    with open(file_path, 'r') as file_in:
        for line in file_in:
            header_written = write_header(file_out, header_written)
            file_out.write(f"{line.strip()}{delimiter}{message}\n")
    return header_written


def write_header(file_out, header_written):
    if not header_written:
        file_out.write("Genome\tReason\n")
        return True
    return header_written


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "The script combines three sources of filtered out genomes (initial QC, GUNC, GTDB-Tk) into a single "
            "report."
        )
    )
    parser.add_argument('--qc', required=True, help="File containing a list of genomes that didn't pass QS50 filter")
    parser.add_argument('--gunc', required=True, help="File containing a list of genomes that didn't pass GUNC")
    parser.add_argument('--gtdb', required=True, help="A CSV file with genome accession in the first column and "
                                                      "taxonomic domain in the second column")
    parser.add_argument('-o', '--outfile', required=False, help="Output file name; default: "
                                                                "combined_removed_genomes_report.txt", 
                        default="combined_removed_genomes_report.txt")
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.qc, args.gunc, args.gtdb, args.outfile)
