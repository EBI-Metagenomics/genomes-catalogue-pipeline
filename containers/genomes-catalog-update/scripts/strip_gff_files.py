#!/usr/bin/env python3
# coding=utf-8

import argparse


def main(infile, outfile, keep_infernal, keep_crispr):
    with open(infile, "r") as file_in, open(outfile, "w") as file_out:
        for line in file_in:
            if line.startswith("MGYG"):
                _, tool, ann_type, _, _, _, _, _, annotation = line.strip().split("\t")
                if ann_type == "CDS":
                    stripped_line = strip_line(line)
                    file_out.write(stripped_line)
                else:
                    if tool.startswith("INFERNAL") and keep_infernal:
                        file_out.write(line)
                    elif tool.startswith("CRISPR") and keep_crispr:
                        file_out.write(line)
                    else:
                        pass
            else:
                file_out.write(line)


def strip_line(line):
    parts = line.strip().split("\t")
    annotation_elements = parts[-1].split(";")
    saved_fields = list()
    for a in annotation_elements:
        if a.split("=")[0] in ["ID", "Name", "eC_number", "db_xref", "gene", "inference", "locus_tag", "product",
                               "note"]:
            saved_fields.append(a)
        else:
            pass
    parts[-1] = ";".join(saved_fields)
    return "\t".join(parts) + "\n"


def parse_args():
    parser = argparse.ArgumentParser(description='''
    The script is part of the catalogue update pipeline and removes non-prokka annotations from a GFF file.
    The purpose of the script is to simulate a Prokka GFF file to add updated annotations to it.
    ''')
    parser.add_argument('-i', '--infile', required=True,
                        help='Path to annotated GFF file generated for the previous catalogue version.')
    parser.add_argument('-o', '--outfile', required=True,
                        help='Path to the output file where the stripped GFF will be saved to.')
    parser.add_argument('--keep-infernal', action='store_true',
                        help='If this flag is on, the ncRNA results called by Infernal will not be stripped. '
                             'These are separate annotation lines and are normally added to Prokka results '
                             'by annotate_gff.py script. If during the update process ncRNA was not recalculated, '
                             'these lines can be retained by using this flag. Default: False.')
    parser.add_argument('--keep-crispr', action='store_true',
                        help='If this flag is on, the CRISPRCasFinder results will not be stripped. '
                             'These are separate annotation lines and are normally added to Prokka results '
                             'by annotate_gff.py script. If during the update process CRISPRs were not recalculated, '
                             'these lines can be retained by using this flag. Default: False.')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.infile, args.outfile, args.keep_infernal, args.keep_crispr)