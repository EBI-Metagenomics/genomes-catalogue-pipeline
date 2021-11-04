#!/usr/bin/env python3

import os
import sys
import argparse
from argparse import RawTextHelpFormatter


def get_kegg_cats(kegg):
    kegg_cats = {}
    with open(kegg, "r") as f:
        for line in f:
            cols = line.strip("\n").split("\t")
            ko = cols[3].split()[0]
            subcat_id = cols[1].split()[0]
            if ko not in kegg_cats.keys():
                kegg_cats[ko] = [subcat_id]
            else:
                kegg_cats[ko].append(subcat_id)
    return kegg_cats


def get_proteins(fasta):
    proteins = set()
    with open(fasta, "r") as f:
       for line in f:
           if line[0] == ">":
               protein = line.split()[0].split(">")[1]
               proteins.add(protein)
    return proteins 


def parse_eggnog(eggnog_results):
    CL = ["do", "co", "SL"]
    cazy_counts = {"GH": 0, "PL": 0, "CE": 0, "AA": 0, "CB": 0, "GT": 0, "CL": 0}
    kegg_cats = get_kegg_cats(kegg_classes)
    kegg_counts = {}
    keggM_counts = {}
    cog_counts = {}
    kegg_coverage = 0
    cog_coverage = 0
    eggnog_hits = set()
    with open(eggnog_results, "r") as f:
        for line in f:
            if line.startswith('#'):
                eggnog_fields = get_eggnog_fields(line)
            else:
                cols = line.strip("\n").split("\t")
                eggnog_hits.add(cols[0])
                ko = cols[eggnog_fields["KEGG_ko"]].split(",")
                ko_mod = cols[eggnog_fields["KEGG_Module"]].split(",")
                try:
                    cog_func = cols[eggnog_fields["cog_func"]]
                except:
                    cog_func = ""
                cazy = cols[eggnog_fields["CAZy"]].split(",")
                if cazy[0] not in ("", "-"):
                    for c in cazy:
                        gene = c[:2]
                        if gene in CL:
                            gene = "CL"
                        cazy_counts.setdefault(gene, 0)
                        cazy_counts[gene] += 1
                if len(cog_func) > 0:
                    cog_coverage += 1
                if ko[0] != "":
                    kegg_coverage += 1
                for k in ko:
                    if "K0" in k:
                        try:
                            k = k.split(":")[-1]
                            for subcat in kegg_cats[k]:
                                kegg_counts.setdefault(subcat, 0)
                                kegg_counts[subcat] += 1
                        except:
                            continue
                for k in ko_mod:
                    if "M0" in k:
                        keggM_counts.setdefault(k, 0)
                        keggM_counts[k] += 1
                for subcat in cog_func:
                    if subcat != "":
                        cog_counts.setdefault(subcat, 0)
                        cog_counts[subcat] += 1
        return kegg_counts, keggM_counts, cog_counts, kegg_coverage, cog_coverage, eggnog_hits, cazy_counts


def get_eggnog_fields(line):
    cols = line.strip().split("\t")
    if cols[8] == "KEGG_ko" and cols[15] == "CAZy":
        eggnog_fields = {"KEGG_ko": 8, "KEGG_Module": 10, "CAZy": 15, "cog_func": 20}
    elif cols[11] == "KEGG_ko" and cols[18] == "CAZy":
        eggnog_fields = {"KEGG_ko": 11, "KEGG_Module": 13, "CAZy": 18, "cog_func": 6}
    else:
        sys.exit("Cannot parse eggNOG - unexpected field order or naming")
    return eggnog_fields


def parse_ipr(ipr_results):
    with open(ipr_results, "r") as f:
        ipr_hits = set()
        for line in f:
            cols = line.strip("\n").split("\t")
            ipr_hits.add(cols[0])
        return ipr_hits


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='''
    Generate function summary stats

    Output files created:
    - annotation_coverage.tsv
    - kegg_classes.tsv
    - kegg_modules.tsv
    - cazy_summary.tsv
    - cog_summary.tsv''', formatter_class=RawTextHelpFormatter)
    #parser.add_argument('-e', dest='eggnog_results', help='EggNOG results file [REQUIRED]', required=True)
    #parser.add_argument('-i', dest='ipr_results', help='InterProScan results file [REQUIRED]', required=True)
    #parser.add_argument('-f', dest='fasta', help='Protein FASTA file [REQUIRED]', required=True)
    parser.add_argument('-i', dest='input_dir', help='Directory with protein.fasta, eggnog, ips', required=True)
    parser.add_argument('-k', dest='kegg_classes', help='KEGG orthology classes DB [REQUIRED]', required=True)
    parser.add_argument('-o', dest='out_folder', help='Output folder [REQUIRED]', required=True)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()
        if not os.path.exists(args.out_folder):
            os.makedirs(args.out_folder)
        input_files = os.listdir(args.input_dir)
        fasta_protein = [cur_file for cur_file in input_files if cur_file.endswith('.faa')][0]
        fasta_in = os.path.join(args.input_dir, fasta_protein)
        species_name = fasta_in.split("/")[-1].split(".")[0]

        eggnog_name = [cur_file for cur_file in input_files if cur_file.endswith('eggNOG.tsv')][0]
        eggnog_results = os.path.join(args.input_dir, eggnog_name)

        ips_name = [cur_file for cur_file in input_files if cur_file.endswith('InterProScan.tsv')][0]
        ipr_results = os.path.join(args.input_dir, ips_name)

        kegg_classes = args.kegg_classes
        eggnog_data = parse_eggnog(eggnog_results)
        ipr_hits = parse_ipr(ipr_results)
        eggnog_hits = eggnog_data[5]
        with open("{}/{}_annotation_coverage.tsv".format(args.out_folder, species_name), "w") as summ_out:
            missing = set()
            proteins = get_proteins(fasta_in)
            total_proteins = float(len(proteins))
            for p in proteins:
                if p not in ipr_hits and p not in eggnog_hits:
                    missing.add(p)
            summ_out.write("Genome\tAnnotation\tCounts\tCoverage\n")
            summ_out.write("{}\tInterProScan\t{}\t{:.2f}\n".format(
                species_name, len(ipr_hits), len(ipr_hits)/total_proteins*100))
            summ_out.write("{}\teggNOG\t{}\t{:.2f}\n".format(
                species_name, len(eggnog_hits), len(eggnog_hits)/total_proteins*100))
            summ_out.write("{}\tCOG\t{}\t{:.2f}\n".format(
                species_name, eggnog_data[4], eggnog_data[4]/total_proteins*100))
            summ_out.write("{}\tKEGG\t{}\t{:.2f}\n".format(
                species_name, eggnog_data[3], eggnog_data[3]/total_proteins*100))
            summ_out.write("{}\tMissing\t{}\t{:.2f}\n".format(
                species_name, len(missing), len(missing)/total_proteins*100))
        kegg_classes = eggnog_data[0]
        with open("{}/{}_kegg_classes.tsv".format(args.out_folder, species_name), "w") as kegg_out:
            kegg_out.write("Genome\tKEGG_class\tCounts\n")
            for kegg in kegg_classes:
                kegg_out.write("{}\t{}\t{}\n".format(species_name, kegg, kegg_classes[kegg]))
        kegg_modules = eggnog_data[1]
        with open("{}/{}_kegg_modules.tsv".format(args.out_folder, species_name), "w") as kegg_out:
            kegg_out.write("Genome\tKEGG_module\tCounts\n")
            for kegg in kegg_modules:
                kegg_out.write("{}\t{}\t{}\n".format(species_name, kegg, kegg_modules[kegg]))
        cog_summary = eggnog_data[2]
        with open("{}/{}_cog_summary.tsv".format(args.out_folder, species_name), "w") as cog_out:
            cog_out.write("Genome\tCOG_category\tCounts\n")
            for cog in cog_summary:
                cog_out.write("{}\t{}\t{}\n".format(species_name, cog, cog_summary[cog]))
        cazy_summary = eggnog_data[-1]
        with open("{}/{}_cazy_summary.tsv".format(args.out_folder, species_name), "w") as cazy_out:
            cazy_out.write("Genome\tCAZy_category\tCounts\n")
            for cazy in cazy_summary:
                cazy_out.write("{}\t{}\t{}\n".format(species_name, cazy, cazy_summary[cazy]))
