#!/usr/bin/python3

import argparse
import random

# Argument parser setup
parser = argparse.ArgumentParser(description="Generates labels and legends for iTOL and existing/novel layer")
parser.add_argument("-i", "--input", dest="input", required=True, help="gtdbtk.bac120.summary.tsv/gtdbtk.ar53.summary.tsv")
parser.add_argument("-t", "--taxa", dest="taxa", required=True, help="phylum/class/order/family/genus/species")
parser.add_argument("-d", "--domain", dest="domain", required=True, help="bac/arc")
args = parser.parse_args()

TAXA = {
    'phylum': 1,
    'class': 2,
    'order': 3,
    'family': 4,
    'genus': 5,
    'species': 6
}


def random_color():
    return "#{:06x}".format(random.randint(0, 0xFFFFFF))


col_dict = {}
with open(args.input, 'r') as file_in, \
    open(f"itol_gtdb-layer_{args.domain}_{args.taxa}.txt", "w") as circles, \
    open(f"itol_gtdb-legend_{args.domain}_{args.taxa}.txt", "w") as legend, \
    open(f"novel_{args.domain}_{args.taxa}.txt", "w") as novel, \
    open(f"existing_{args.domain}_{args.taxa}.txt", "w") as existing:
    # circles
    circles.write("DATASET_COLORSTRIP\n"
                  "SEPARATOR COMMA\n"
                  f"DATASET_LABEL,{args.taxa}\n"
                  "DATA\n")
    # legends
    legend.write("TREE_COLORS\n"
                 "SEPARATOR COMMA\n"
                 f"LEGEND_TITLE,{args.taxa}\n"
                 "DATA\n")

    for line in file_in:
        if 'user_genome' in line:
            continue
        line = line.strip().split('\t')
        genome = line[0]
        tax_lineage = line[1]
        species = tax_lineage.split(";")[TAXA['species']]
        if species == 's__':
            novel.write(genome + "\n")
        else:
            existing.write(genome + "\n")

        tax_unit = tax_lineage.split(";")[TAXA[args.taxa]]
        taxon = tax_unit.split("__")[-1]
        if taxon == "":
            taxon = f"{args.taxa}_unclassified"
        if tax_unit not in col_dict:
            new_color = random_color()
            # check that color is new
            while new_color in col_dict.values():
                new_color = random_color()
            col_dict[tax_unit] = new_color
        color = col_dict[tax_unit]
        circles.write("%s,%s,%s\n" % (genome, color, taxon))
        legend.write("%s,range,%s,%s\n" % (genome, color, taxon))