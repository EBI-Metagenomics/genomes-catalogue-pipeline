#!/usr/bin/env python

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

from Bio import SeqIO

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script detects rRNA")
    parser.add_argument(
        "-i", "--input", dest="input", help="Input fasta", required=True
    )
    parser.add_argument(
        "-d", "--drep", dest="drep", help="tblout.deoverlapped", required=True
    )
    args = parser.parse_args()
    hits = {}
    added = {}
    with open(args.drep, "r") as f:
        for line in f:
            line = line.strip("\n")
            cols = line.split()
            contig = cols[0]
            gene = cols[2]
            strand = cols[9]
            if strand == "+":
                start = int(cols[7])
                end = int(cols[8])
            else:
                start = int(cols[8])
                end = int(cols[7])
            if contig not in added.keys():
                added[contig] = 1
            else:
                added[contig] += 1
            contig = "{contig}__{gene}_hit-{added}__{start}-{end}_len={len}".format(
                contig=contig,
                gene=gene,
                added=str(added[contig]),
                start=start,
                end=end,
                len=end - start + 1,
            )
            hits[contig] = [start, end]

    with open(args.input, "r") as f:
        for record in SeqIO.parse(f, "fasta"):
            for contig in hits.keys():
                if contig.split("__")[0] == record.id:
                    start = hits[contig][0] - 1
                    end = hits[contig][1]
                    length = end - start
                    seq = record.seq[start:end]
                    name = (
                        ">"
                        + os.path.basename(sys.argv[2]).split(".")[0]
                        + "__"
                        + contig
                    )
                    print("{name}\n{seq}".format(name=name, seq=seq))
