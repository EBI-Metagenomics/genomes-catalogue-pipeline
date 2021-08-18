#!/usr/bin/env python3

import sys
import argparse
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.Seq import translate
from Bio.SeqRecord import SeqRecord


def translate_gene(in_file, out_file):
    with open(in_file, "r") as input_name, open(out_file, "w") as output_name:
        for record in SeqIO.parse(input_name, "fasta"):
            try:
                transRecord = SeqRecord(record.seq.translate(to_stop=True, table=11), record.name)
                transRecord.description = record.description
                SeqIO.write(transRecord, output_name, "fasta")
            except:
                print("Error in translating %s" % (record.name))
                pass


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Translate DNA sequence into proteins using codon table 11")
    parser.add_argument('-i', dest='nt_fasta', help='Nucleotide FASTA file', required=True)
    parser.add_argument('-o', dest='prot_fasta', help='Output protein FASTA file', required=True)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()
        translate_gene(args.nt_fasta, args.prot_fasta)
