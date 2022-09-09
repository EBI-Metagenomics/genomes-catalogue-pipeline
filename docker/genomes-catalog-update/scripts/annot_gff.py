#!/usr/bin/env python3

import argparse
from argparse import RawTextHelpFormatter
import sys
import os


def get_iprs(ipr_annot):
    iprs = {}
    with open(ipr_annot, "r") as f:
        for line in f:
            cols = line.strip().split("\t")
            protein = cols[0]
            if protein not in iprs:
                iprs[protein] = [set(), set()]
            if cols[3] == "Pfam":
                pfam = cols[4]
                iprs[protein][0].add(pfam)
            if len(cols) > 12:
                ipr = cols[11]
                iprs[protein][1].add(ipr)
    return iprs


def get_eggnog(eggnog_annot):
    eggnogs = {}
    with open(eggnog_annot, "r") as f:
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


def get_emerald(emerald_file, prokka_gff):
    cluster_positions = dict()
    emerald_result = dict()
    bgc_annotations = dict()
    # save positions of each BGC cluster annotated by Emerald to dictionary cluster_positions
    # and save the annotations to dictionary emerald_result
    with open(emerald_file, "r") as emerald_in:
        for line in emerald_in:
            if not line.startswith("#"):
                cols = line.strip().split("\t")
                contig= cols[0]
                for a in cols[8].split(';'):  # go through all parts of the Emerald annotation field
                    if a.startswith("nearest_MiBIG_class="):
                        class_value = a.split("=")[1]
                    elif a.startswith("nearest_MiBIG="):
                        mibig_value = a.split("=")[1]
                # save cluster positions to a dictionary where key = contig name,
                # value = list of position pairs (list of lists)
                cluster_positions.setdefault(contig, list()).append([int(cols[3]), int(cols[4])])
                # save emerald annotations to dictionary where key = contig, value = dictionary, where
                # key = 'start_end' of BGC, value = dictionary, where key = feature type, value = description
                emerald_result.setdefault(contig, dict()).setdefault("_".join([cols[3], cols[4]]),
                                                                     {"nearest_MiBIG_class": class_value,
                                                                      "nearest_MiBIG": mibig_value})
    # identify CDSs that fall into each of the clusters annotated by Emerald
    with open(prokka_gff, "r") as gff_in:
        for line in gff_in:
            if not line.startswith("#"):
                matching_interval = ""
                cols = line.strip().split("\t")
                if cols[0] in cluster_positions:
                    for i in cluster_positions[cols[0]]:
                        if int(cols[3]) in range(i[0], i[1] + 1) and int(cols[4]) in range(i[0], i[1] + 1):
                            matching_interval = "_".join([str(i[0]), str(i[1])])
                            break
                # if the CDS is in an interval, save cluster's annotation to this CDS
                if matching_interval:
                    cds_id = cols[8].split(";")[0].split("=")[1]
                    bgc_annotations.setdefault(cds_id, {
                        "nearest_MiBIG": emerald_result[cols[0]][matching_interval]["nearest_MiBIG"],
                        "nearest_MiBIG_class": emerald_result[cols[0]][matching_interval]["nearest_MiBIG_class"],
                    })
    return bgc_annotations


def get_eggnog_fields(line):
    cols = line.strip().split("\t")
    if cols[8] == "KEGG_ko" and cols[15] == "CAZy":
        eggnog_fields = {"KEGG_ko": 8, "cog_func": 20}
    elif cols[11] == "KEGG_ko" and cols[18] == "CAZy":
        eggnog_fields = {"KEGG_ko": 11, "cog_func": 6}
    else:
        sys.exit("Cannot parse eggNOG - unexpected field order or naming")
    return eggnog_fields


def add_gff(in_gff, eggnog_file, ipr_file, emerald_file):
    eggnogs = get_eggnog(eggnog_file)
    iprs = get_iprs(ipr_file)
    emerald_bgcs = get_emerald(emerald_file, in_gff)
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
                                    added_annot[protein]["eggNOG"] = a
                                elif pos == 2:
                                    added_annot[protein]["COG"] = a
                                elif pos == 3:
                                    added_annot[protein]["KEGG"] = a
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
                                    added_annot[protein]["Pfam"] = a
                                elif pos == 2:
                                    added_annot[protein]["InterPro"] = a
                    except:
                        pass
                    try:
                        emerald_bgcs[protein]
                        for key, value in emerald_bgcs[protein].items():
                            added_annot[protein][key] = value
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


def get_rnas(ncrnas_file):
    ncrnas = {}
    counts = 0
    with open(ncrnas_file, "r") as f:
        for line in f:
            if not line.startswith("#"):
                cols = line.strip().split()
                counts += 1
                contig = cols[3]
                locus = "{}_ncRNA{}".format(contig, counts)
                product = " ".join(cols[26:])
                model = cols[2]
                strand = cols[11]
                if strand == "+":
                    start = int(cols[9])
                    end = int(cols[10])
                else:
                    start = int(cols[10])
                    end = int(cols[9])
                ncrnas.setdefault(contig, list()).append([locus, start, end, product, model, strand])
    return ncrnas


def add_ncrnas_to_gff(gff_outfile, ncrnas, res):
    gff_out = open(gff_outfile, 'w')
    added = set()
    for line in res:
        cols = line.strip().split("\t")
        if line[0] != "#" and len(cols) == 9:
            if cols[2] == "CDS":
                contig = cols[0]
                if contig in ncrnas:
                    for c in ncrnas[contig]:
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
                            gff_out.write("\t".join(newLine) + "\n")
                gff_out.write("{}\n".format(line))
#            else:
#                gff_out.write("{}\n".format(line))
        else:
            gff_out.write("{}\n".format(line))
    gff_out.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='''
    Add functional annotation to GFF file''', formatter_class=RawTextHelpFormatter)
    parser.add_argument('-i', dest='input_dir', required=True,
                        help='Directory with faa, fna, gff,.. and ips, eggnog if -a is not presented')
    parser.add_argument('-a', dest='annotations', help='IPS and EggNOG files', required=False, nargs='+')
    parser.add_argument('-r', dest='rfam', help='Rfam results', required=True)
    parser.add_argument('-e', dest='emerald', help='emerald result gff', required=True)
    parser.add_argument('-o', dest='outfile', help='Outfile name', required=False)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()
        input_files = os.listdir(args.input_dir)
        if args.annotations:
            annotations_list = args.annotations
        else:
            # search in input directory
            annotations_list = input_files
        eggnog_name = [cur_file for cur_file in annotations_list if cur_file.endswith('eggNOG.tsv')][0]
        eggnog_results = eggnog_name if args.annotations else os.path.join(args.input_dir, eggnog_name)
        ips_name = [cur_file for cur_file in annotations_list if cur_file.endswith('InterProScan.tsv')][0]
        ipr_results = ips_name if args.annotations else os.path.join(args.input_dir, ips_name)

        gff = [cur_file for cur_file in input_files if cur_file.endswith(".gff")][0]
        res = add_gff(in_gff=os.path.join(args.input_dir, gff),
                      eggnog_file=eggnog_results,
                      ipr_file=ipr_results,
                      emerald_file=args.emerald)
        ncRNAs = get_rnas(args.rfam)
        if not args.outfile:
            outfile = gff.split(".gff")[0]+"_annotated.gff"
        else:
            outfile = args.outfile
        with open(outfile, "w") as fout:
            fout.write("\n".join(res))
        add_ncrnas_to_gff(outfile, ncRNAs, res)
