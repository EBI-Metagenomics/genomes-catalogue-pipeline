#!/usr/bin/env python

import sys
import os

ranks = ["superkingdom", "phylum", "class", "order", "family", "genus", "species"]
def getTaxIncons(cat_file):
    rank_tax = {"superkingdom": ["Not classified", 0, 0, []],
                "phylum": ["Not classified", 0, 0, []],
                "class": ["Not classified", 0, 0, []],
                "order": ["Not classified", 0, 0, []],
                "family": ["Not classified", 0, 0, []],
                "genus": ["Not classified", 0, 0, []],
                "species": ["Not classified", 0, 0, []]}
    total_bp = 0
    linen = 0
    tig_score = 0.0
    exclude = ["not classified", "NA", "Viruses"]
    with open(cat_file, "r") as f:
        for line in f:
            linen += 1
            if linen == 1:
                total_bp = int(line.split()[-2])
            else:
                line = line.rstrip()
                cols = line.split("\t")
                for rank in rank_tax.keys():
                    if cols[0] == rank:
                        length = int(cols[-1])
                        taxon = cols[1]
                        cov = float(cols[4])
                        if taxon not in exclude:
                            if rank_tax[rank][0] == "Not classified":
                                rank_tax[rank][0] = taxon
                                rank_tax[rank][1] = cov/total_bp*100
                            else:
                                rank_tax[rank][-1].append(taxon)
                                rank_tax[rank][-2] += length
    for n,rank in enumerate(ranks):
        rank_tax[rank][-2] = float(rank_tax[rank][-2])/total_bp*100
        if rank_tax[rank][-2] == 0:
            rank_tax[rank][-1] = ["NA"]
        if rank != "species":
            if rank_tax[rank][-2] > tig_score:
                tig_score = rank_tax[rank][-2]
    return rank_tax, tig_score

if __name__ == "__main__":
    if len(sys.argv) == 1:
        print("usage: script.py genome.summary.txt")
        sys.exit(1)
    else:
        taxincons = getTaxIncons(sys.argv[1])
        res = taxincons[0]
        tig_score = taxincons[1]
        print("Genome\tRank\tMain taxon (coverage %)\tTaxIncons %\tSecondary taxa")
        for rank in ranks:
            print("%s\t%s\t%s (%.2f)\t%.2f\t%s" \
            % (os.path.basename(sys.argv[1]).split(".summary")[0], rank, res[rank][0], res[rank][1], res[rank][-2], ",".join(res[rank][-1])))
        print("----------\nTaxonomic inconsistency up to genus (TIG):\t%.2f" % (tig_score))
