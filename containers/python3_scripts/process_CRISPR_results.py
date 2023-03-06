#!/usr/bin/env python3

import argparse

from Bio import SeqIO


def main(tsv_report, gffs, tsv_output, gff_output, gff_output_hq, fasta):
    hits, hq_hits = process_tsv(tsv_report, tsv_output)
    create_gff(gffs, gff_output, hits, fasta, hq_hits, gff_output_hq)


def create_gff(gffs, gff_output, hits, fasta, high_qual_hits, gff_output_high_qual):
    with open(gff_output, "w") as gff_out:
        for gff in gffs:
            filename_base = gff.split("/")[-1].split(".")[0]
            if filename_base in hits:
                with open(gff, "r") as gff_in:
                    for line in gff_in:
                        if not line.startswith("#") and not len(line.strip()) == 0:
                            parts = line.strip().split("\t")
                            # fix the GFF feature if it extends outside a contig (CRISPRCasFinder bug)
                            if not all(x > 0 for x in [int(parts[3]), int(parts[4])]) or "sequence=UNKNOWN" in line:
                                line = fix_gff_line(line, fasta)
                            gff_out.write(line)


def fix_gff_line(line, fasta):
    contig, tool, feature, start, end, blank1, blank2, blank3, annotation = line.strip().split("\t")
    if int(start) < 1:
        start = 1
    if "sequence=UNKNOWN" in annotation:
        seq_records = SeqIO.to_dict(SeqIO.parse(fasta, "fasta"))
        end = check_end_position(contig, end, seq_records)
        feature_seq = seq_records[contig][start-1:end].seq
        at_percentage = calc_at_percentage(feature_seq)
        print("before", annotation)
        annotation = fix_annotation(feature_seq, at_percentage, annotation)
        print("after", annotation)
    return "\t".join([contig, tool, feature, str(start), str(end), blank1, blank2, blank3, annotation])    
    

def fix_annotation(feature_seq, at_percentage, annotation):
    annotation = annotation.replace("at%=0;", "at%={};".format(at_percentage))
    annotation = annotation.replace("sequence=UNKNOWN", "sequence={}".format(feature_seq))
    return annotation


def calc_at_percentage(feature_seq):
    a = feature_seq.upper().count("A")
    t = feature_seq.upper().count("T")
    return str(int((round((a+t)*100/len(feature_seq),0))))


def check_end_position(contig, end, seq_records):
    # CRISPRCasFinder has a bug where it doesn't check how long the contig is to identify
    # flanking sequence positions. Adjust the end position if it extends past the edge of the contig.
    if int(end) > len(seq_records[contig].seq):
        return len(seq_records[contig].seq)
    else:
        return int(end)


def process_tsv(tsv_report, tsv_output):
    hits = list()
    hq_hits = list()
    with open(tsv_output, "w") as tsv_out:
        with open(tsv_report, "r") as tsv_in:
            for line in tsv_in:
                if not len(line.strip()) == 0:
                    tsv_out.write(line)
                    if not line.startswith("Strain"):
                        hits.append(line.strip().split("\t")[2])
                        if line.strip().split("\t")[-1] in ["3", "4"]:
                            hq_hits.append(line.strip().split("\t")[2])
    return list(set(hits)), list(set(hq_hits))


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
    parser.add_argument('--gff-output-hq', required=True,
                        help='Name of GFF file (with path if needed) where the script will save processed GFF '
                             'information for high quality hits (EL 3 and 4)'
                             '(one GFF will be produced for the entire genome)')
    parser.add_argument('--fasta', required=True,
                        help='Path to the genome Fasta file')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.tsv_report, args.gffs, args.tsv_output, args.gff_output, args.gff_output_hq, args.fasta)