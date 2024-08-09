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
import sys

logging.basicConfig(level=logging.INFO)

E_VALUE_CUTOFF = 1e-10


def main(eggnog_file, outfile):
    kegg_list = list()
    with open(eggnog_file) as file_in:
        for line in file_in:
            cols = line.strip().split('\t')
            if "#query" in line:
                ko_index = find_column_index(cols, "KEGG_ko")
                evalue_index = find_column_index(cols, "evalue")
            else:
                try:
                    evalue = float(cols[evalue_index])
                except ValueError:
                    continue
                if evalue > E_VALUE_CUTOFF:
                    continue
                if not cols[ko_index] == "-":
                    kegg_list.append(cols[ko_index].replace("ko:", ""))
    
    with open(outfile, 'w') as file_out:
        file_out.write(','.join(kegg_list))
                            
                
def find_column_index(header, column_name):
    try:
        return header.index(column_name)
    except ValueError:
        sys.exit(f"Could not find the {column_name} column in eggnog_file")
                

def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "This script takes the eggNOG file and generates an input file "
            "for the kegg pathway completeness tool."
        )
    )
    parser.add_argument('-e', '--eggnog', required=True, help="eggNOG output file.")
    parser.add_argument('-o', '--outfile', required=True,
                        help="File to save the output to. ")
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.eggnog, args.outfile)