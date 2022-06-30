#!/usr/bin/env python

import sys
import os
import argparse

def getRNAs(ncRNAs):
    ncrnas = {}
    counts = 0
    with open(ncRNAs) as f:
        for line in f:
            if line[0] != "#":
                line = line.rstrip()
                cols = line.split()
                #print(cols)
                counts += 1
                contig = cols[3].split('-')[0]
                locus = "%s_ncRNA%i" % (contig, counts)
                product = " ".join(cols[26:])
                model = cols[2]
                strand = cols[11]
                if strand == "+":
                    start = int(cols[9])
                    end = int(cols[10])
                else:
                    start = int(cols[10])
                    end = int(cols[9])
                if contig not in ncrnas:
                    ncrnas[contig] = [[locus, start, end, product, model, strand]]
                else:
                    ncrnas[contig].append([locus, start, end, product, model, strand])
    return ncrnas


def addGFF(gff, ncRNAs):
    added = set()
    with open(gff) as f:
        for line in f:
            line = line.rstrip()
            cols = line.split("\t")
            if line[0] != "#" and len(cols) == 9:
                if cols[2] == "CDS":
                    print(line)
                    contig = cols[0]
                    for r in ncRNAs.keys():
                        if r == contig:
                            for c in ncRNAs[r]:
                                locus = c[0]
                                start = str(c[1])
                                end = str(c[2])
                                product = c[3]
                                model = c[4]
                                strand = c[5]
                                if locus not in added:
                                    added.add(locus)
                                    annot = ["ID="+locus,
                                         "inference=Rfam:14.6",
                                         "locus_tag="+locus,
                                         "product="+product,
                                         "rfam="+model]
                                    annot = ";".join(annot)
                                    newLine = [contig,
                                          "INFERNAL:1.1.2",
                                          "ncRNA",
                                          start, end,
                                          ".",
                                          strand, ".",
                                          annot]
                                    print("\t".join(newLine))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Add Rfam annotation to GFF file')
    parser.add_argument('-g', dest='gff', help='Input GFF file [REQUIRED]', required=True)
    parser.add_argument('-r', dest='rfam', help='Rfam results [REQUIRED]', required=True)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()
        ncRNAs = getRNAs(args.rfam)
        addGFF(args.gff, ncRNAs)