#!/usr/bin/env python3

import argparse
from argparse import RawTextHelpFormatter
import sys
import os


def get_iprs(ipr_annot):
    iprs = {}
    with open(ipr_annot, "r") as f:
        for line in f:
            line = line.rstrip()
            cols = line.split("\t")
            protein = cols[0]
            if protein not in iprs:
                iprs[protein] = [set(),set()]
            if cols[3] == "Pfam":
                pfam = cols[4]
                iprs[protein][0].add(pfam)
            if len(cols) > 12:
                ipr = cols[11]
                iprs[protein][1].add(ipr)
    return iprs


def get_eggnog(eggnot_annot):
    eggnogs = {}
    with open(eggnot_annot, "r") as f:
        for line in f:
            line = line.rstrip()
            cols = line.split("\t")
            if line.startswith("#"):
                eggnog_fields = get_eggnog_fields(line)
            else:
                protein = cols[0]
                eggnog = [cols[1]]
                try:
                    cog = cols[eggnog_fields["cog_func"]]
                    cog = cog.split()
                    if len(cog) > 1:
                        cog = ["R"]
                except:
                    cog = ["NA"]
                kegg = cols[eggnog_fields["KEGG_ko"]].split(",")
                eggnogs[protein] = [eggnog, cog, kegg]
    return eggnogs


def get_eggnog_fields(line):
    cols = line.strip().split("\t")
    if cols[8] == "KEGG_ko" and cols[15] == "CAZy":
        eggnog_fields = {"KEGG_ko": 8, "cog_func": 20}
    elif cols[11] == "KEGG_ko" and cols[18] == "CAZy":
        eggnog_fields = {"KEGG_ko": 11, "cog_func": 6}
    else:
        sys.exit("Cannot parse eggNOG - unexpected field order or naming")
    return eggnog_fields


def add_gff(in_gff, eggnog_file, ipr_file):
    eggnogs = get_eggnog(eggnog_file)
    iprs = get_iprs(ipr_file)
    added_annot = {}
    out_gff = []
    with open(in_gff, "r") as f:
        for line in f:
            line = line.strip()
            if line[0] != "#":
                cols = line.split("\t")
                if len(cols) == 9:
                    annot = cols[8]
                    protein = annot.split(";")[0].split("=")[-1]
                    added_annot[protein] = {}
                    try:
                        eggnogs[protein]
                        pos = 0
                        for a in eggnogs[protein]:
                            pos += 1
                            if a != [""] and a != ["NA"]:
                                if pos == 1:
                                    added_annot[protein]['eggNOG'] = a
                                elif pos == 2:
                                    added_annot[protein]['COG'] = a
                                elif pos == 3:
                                    added_annot[protein]['KEGG'] = a
                    except:
                        pass
                    try:
                        iprs[protein]
                        pos = 0
                        for a in iprs[protein]:
                            pos += 1
                            a = list(a)
                            if a != [""] and a:
                                if pos == 1:
                                    added_annot[protein]['Pfam'] = a
                                elif pos == 2:
                                    added_annot[protein]['InterPro'] = a
                    except:
                        pass
                    for a in added_annot[protein]:
                        value = added_annot[protein][a]
                        if type(value) is list:
                            value = ",".join(value)
                        cols[8] = "{};{}={}".format(cols[8], a, value)
                    line = "\t".join(cols)
            out_gff.append(line)
    return out_gff


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='''
    Add functional annotation to GFF file''', formatter_class=RawTextHelpFormatter)
    parser.add_argument('-i', dest='input_dir', help='Directory with eggnog, ips, gff', required=True)
    parser.add_argument('-o', dest='outfile', help='Outfile name', required=False)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()
        input_files = os.listdir(args.input_dir)
        ips = [cur_file for cur_file in input_files if cur_file.endswith('InterProScan.tsv')][0]
        eggnog = [cur_file for cur_file in input_files if cur_file.endswith('eggNOG.tsv')][0]
        gff = [cur_file for cur_file in input_files if cur_file.endswith('.gff')][0]
        print(ips, eggnog, gff)
        res = add_gff(in_gff=os.path.join(args.input_dir, gff),
                      eggnog_file=os.path.join(args.input_dir, eggnog),
                      ipr_file=os.path.join(args.input_dir, ips))
        if not args.outfile:
            outfile = gff.split(".gff")[0]+"_annotated.gff"
        else:
            outfile = args.outfile
        print(outfile)
        with open(outfile, "w") as fout:
            fout.write("\n".join(res))
