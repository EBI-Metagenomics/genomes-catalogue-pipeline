#!/usr/bin/env python3

import argparse
import gzip
import math
import random
from collections import Counter

# Argument parser setup
parser = argparse.ArgumentParser(description="Generates labels and legends for iTOL and existing/novel layer")
parser.add_argument("-i", "--input", dest="input", required=True,
                    help="gtdbtk.bac120.summary.tsv/gtdbtk.ar53.summary.tsv")
parser.add_argument("-t", "--taxa", dest="taxa", required=True, help="phylum/class/order/family/genus/species")
parser.add_argument("-d", "--domain", dest="domain", required=True, help="bac/arc")
parser.add_argument("-m", "--metadata", dest="metadata", required=False,
                    help="genomes metadata table with Genome and Species_rep columns; generates cluster size layers")
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


def count_cluster_sizes(metadata):
    cluster_sizes = Counter()
    opener = gzip.open if metadata.endswith(".gz") else open
    with opener(metadata, 'rt') as file_in:
        header = file_in.readline().rstrip('\n').split('\t')
        genome_index = header.index("Genome")
        rep_index = header.index("Species_rep")
        for line in file_in:
            cols = line.rstrip('\n').split('\t')
            if len(cols) <= max(genome_index, rep_index) or not cols[genome_index]:
                continue
            cluster_sizes[cols[rep_index]] += 1
    return cluster_sizes


def write_cluster_size_layer(cluster_sizes, filename, label, transform):
    with open(filename, "w") as file_out:
        file_out.write("DATASET_SIMPLEBAR\n"
                       "SEPARATOR TAB\n"
                       f"DATASET_LABEL\t{label}\n"
                       "COLOR\t#ff0000\n"
                       "WIDTH\t3\n"
                       "DATA\n")
        for rep, count in cluster_sizes.items():
            file_out.write(f"{rep}\t{transform(count)}\n")


col_dict = {}
with open(args.input, 'r') as file_in, \
    open(f"itol_gtdb-layer_{args.domain}_{args.taxa}.txt", "w") as circles, \
    open(f"itol_gtdb-legend_{args.domain}_{args.taxa}.txt", "w") as legend, \
    open(f"novel_existing_{args.domain}_{args.taxa}-layer.txt", "w") as nov_exis, \
    open(f"novel_existing_{args.domain}_{args.taxa}-legend.txt", "w") as nov_exis_legend:
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

    nov_exis.write("DATASET_COLORSTRIP\n"
                   "SEPARATOR COMMA\n"
                   "DATASET_LABEL,novelty\n"
                   "DATA\n")

    nov_exis_legend.write("TREE_COLORS\n"
                          "SEPARATOR COMMA\n"
                          "DATASET_TITLE,novelty\n"
                          "DATA\n")

    for line in file_in:
        if 'user_genome' in line:
            continue
        line = line.strip().split('\t')
        genome = line[0]
        tax_lineage = line[1]
        species = tax_lineage.split(";")[TAXA['species']]
        if species == 's__':
            nov_exis.write(f"{genome},#d9ffc1,Novel MAG\n")
            nov_exis_legend.write(f"{genome},range,#d9ffc1,Novel MAG\n")
        else:
            nov_exis.write(f"{genome},#b4c8ff,Existing MAG\n")
            nov_exis_legend.write(f"{genome},range,#b4c8ff,Existing MAG\n")

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

if args.metadata:
    cluster_sizes = count_cluster_sizes(args.metadata)
    write_cluster_size_layer(cluster_sizes, f"cluster_size_{args.domain}.txt", "cluster_size", lambda count: count)
    write_cluster_size_layer(cluster_sizes, f"cluster_size_log10_{args.domain}.txt", "cluster_size_log10",
                             lambda count: round(math.log10(count + 1), 4))
