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


def main(qc, gunc, gtdb, outfile):
    with open(outfile, 'w') as file_out:
        with open(qc, 'r') as file_in:
            for line in file_in:
                file_out.write("{}\tDid not pass the QS50 filter\n".format(line.strip()))
        with open(gunc, 'r') as file_in:
            for line in file_in:
                file_out.write("{}\tDid not pass GUNC\n".format(line.strip()))
        with open(gtdb, 'r') as file_in:
            for line in file_in:
                parts = line.strip().split(',')
                if parts[1] == "Undefined":
                    file_out.write("{}\tUnknown taxonomic domain\n".format(parts[0]))



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
