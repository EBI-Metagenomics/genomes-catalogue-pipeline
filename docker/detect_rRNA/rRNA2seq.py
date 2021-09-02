#!/usr/bin/env python3

import os
import sys
from Bio import SeqIO

if len(sys.argv) < 3:
    print("usage: script.py tblout.deoverlapped in.fasta")
    sys.exit()

hits = {}
added = {}
with open(sys.argv[1], "r") as f:
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
        contig = "{contig}__{gene}_hit-{added}__{start}-{end}_len={len}".format(contig=contig, gene=gene,
                                                                                added=str(added[contig]), start=start,
                                                                                end=end, len=end-start+1)
        hits[contig] = [start, end]

with open(sys.argv[2], "r") as f:
    for record in SeqIO.parse(f, "fasta"):
        for contig in hits.keys():
            if contig.split("__")[0] == record.id:
                start = hits[contig][0]-1
                end = hits[contig][1]
                length = end-start
                seq = record.seq[start:end]
                name = ">"+os.path.basename(sys.argv[2]).split(".")[0]+"__"+contig
                print("{name}\n{seq}".format(name=name, seq=seq))
