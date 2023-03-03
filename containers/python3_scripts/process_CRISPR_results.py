#!/usr/bin/env python3

import argparse


def main(tsv_report, gffs, tsv_output, gff_output, fasta):
    hits = process_tsv(tsv_report, tsv_output)
    create_gff(gffs, gff_output, hits, fasta)
    # add additional output where we will save high quality crisprs only (as gff)


def create_gff(gffs, gff_output, hits, fasta):
    with open(gff_output, "w") as gff_out:
        for gff in gffs:
            filename_base = gff.split("/")[-1].split(".")[0]
            if filename_base in hits:
                with open(gff, "r") as gff_in:
                    for line in gff_in:
                        if not line.startswith("#"):
                            parts = line.strip().split("\t")
                            # fix the GFF feature if it extends outside a contig (CRISPRCasFinder bug)
                            if not all(x > 0 for x in [int(parts[3]), int(parts[4])]) or "sequence=UNKNOWN" in line:
                                line = fix_gff_line(line)
                            gff_out.write(line)


def process_tsv(tsv_report, tsv_output):
    hits = list()
    with open(tsv_output, "w") as tsv_out:
        with open(tsv_report, "r") as tsv_in:
            for line in tsv_in:
                if not len(line.strip()) == 0:
                    tsv_out.write(line)
                    if not line.startswith("Strain"):
                        hits.append(line.strip().split("\t")[2])
    return list(set(hits))


def parse_args():
    parser = argparse.ArgumentParser(description="Script processes the results of CRISPRCasFinder to produce files"
                                                 "for genomes pipeline output directory.")
    parser.add_argument('--tsv-report', required=True,
                        help='TSV report file produced by CRISPRCasFinder')
    parser.add_argument('--gffs', nargs="+", required=True,
                        help='A list of GFFs produced by CRISPRCasFinder (full paths)')
    parser.add_argument('--tsv-output', required=True,
                        help='Name of TSV file (with path if needed) where the script will save processed TSV '
                             'information')
    parser.add_argument('--gff-output', required=True,
                        help='Name of GFF file (with path if needed) where the script will save processed GFF '
                             'information (one GFF will be produced for the entire genome)')
    parser.add_argument('--fasta', required=True,
                        help='Path to the genome Fasta file')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.tsv_report, args.gffs, args.tsv_output, args.gff_output, args.fasta)