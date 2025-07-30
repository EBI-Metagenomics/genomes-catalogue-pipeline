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


def get_tblout_column_indices(tool):
    tool_indices = {
        "cmsearch": {
            "contig": 0,
            "gene": 2,
            "model": 3,
            "strand": 9,
            "start": 7,
            "end": 8,
        },
        "cmscan": {
            "contig": 3,
            "gene": 1,
            "model": 2,
            "strand": 11,
            "start": 9,
            "end": 10,
        },
    }
    return tool_indices.get(tool)
    
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script generates a fasta file for rRNA")
    parser.add_argument(
        "-i", "--input", dest="input", help="Input fasta", required=True
    )
    parser.add_argument(
        "-d", "--drep", dest="drep", help="tblout.deoverlapped", required=True
    )
    parser.add_argument(
        "-s", "--source", dest="source", help="Program that generated the tblout file", 
        choices=['cmsearch', 'cmscan'], required=False, default="cmsearch"
    )
    parser.add_argument(
        "-o", "--outfile", dest="outfile", help="Path to file where the output FASTA will be saved to", 
        required=False
    )
    args = parser.parse_args()
    hits = {}
    added = {}
    idx = get_tblout_column_indices(args.source)
    with open(args.drep, "r") as f:
        for line in f:
            line = line.strip("\n")
            if line.startswith("#"):
                continue
            cols = line.split()
            model = cols[idx["model"]]
            if model not in ["RF00001", "RF00177", "RF02541"]:
                continue
            contig = cols[idx["contig"]]
            gene = cols[idx["gene"]]
            strand = cols[idx["strand"]]
            if strand == "+":
                start = int(cols[idx["start"]])
                end = int(cols[idx["end"]])
            else:
                start = int(cols[idx["end"]])
                end = int(cols[idx["start"]])
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
    
    if args.outfile:
        file_out = open(args.outfile, "w")
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
                    if args.outfile:
                        file_out.write("{name}\n{seq}\n".format(name=name, seq=seq))
                    else:
                        print("{name}\n{seq}".format(name=name, seq=seq))
    if args.outfile:
        file_out.close()
