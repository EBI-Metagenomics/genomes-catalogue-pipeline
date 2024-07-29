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


def main(infile, outfile):
    with open(infile, "r") as file_in, open(outfile, "w") as file_out:
        for line in file_in:
            if line.startswith("user_genome"):
                pass
            else:
                # Parse GTDB output lines where the first 2 fields look like this:
                # MGYG000300003\td__Bacteria;p__Pseudomonadota;c__Gammaproteobacteria;o__Chromatiales;f__Sedimenticolaceae;g__;s__
                genome, taxonomy = line.strip().split("\t")[0], line.strip().split("\t")[1]
                first_segment = taxonomy.split(";")[0]
                if first_segment.lower().endswith("bacteria"):
                    domain = "Bacteria"
                elif first_segment.lower().endswith("archaea"):
                    domain = "Archaea"
                else:
                    domain = "Undefined"
                file_out.write("{},{}\n".format(genome, domain))


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "This script takes the output of GTDB-Tk (tsv file) and returns the domain detected by GTDB-Tk"
            "in a text file."
        )
    )
    parser.add_argument('-i', '--infile', required=True, help="TSV file generated by GTDB-Tk.")
    parser.add_argument('-o', '--outfile', required=False, default="domains.txt",
                        help="File to save the output to. Default: domains.txt")
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.infile, args.outfile)