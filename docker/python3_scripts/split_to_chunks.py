#!/usr/bin/env python3

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
import sys
from Bio import SeqIO
import os

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Split to chunks")
    parser.add_argument("-i", "--input", dest="input", help="Input fasta file", required=True)
    parser.add_argument("-s", "--size", dest="size", help="Chunk size")
    parser.add_argument("-f", "--file_format", dest="file_format", required=False, help="fasta or fastq")

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()
        if not args.file_format:
            file_format = 'fasta'
        else:
            file_format = args.file_format
        cur_number = 0
        currentSequences = []
        ext = os.path.splitext(args.input)[1]
        if ext == '':
            ext = '.' + file_format

        for record in SeqIO.parse(args.input, file_format):
            cur_number += 1
            currentSequences.append(record)
            if len(currentSequences) == int(args.size):
                fileName = str(cur_number - int(args.size) + 1) + "_" + str(cur_number) + ext
                SeqIO.write(currentSequences, fileName, file_format)
                currentSequences = []

        # write any remaining sequences
        if len(currentSequences) > 0:
            fileName = str(cur_number - len(currentSequences)) + "_" + str(cur_number) + ext
            SeqIO.write(currentSequences, fileName, file_format)
        if cur_number == 0:
            fileName = '0_0' + ext
            with open(fileName, 'w') as empty_file:
                empty_file.close()