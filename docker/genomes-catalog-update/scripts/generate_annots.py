#!/usr/bin/env python3

import os
import sys
import argparse
import glob
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
            if line[0] != "#":
                cols = line.strip("\n").split("\t")
                eggnog_hits.add(cols[0])
                ko = cols[8].split(",")
                ko_mod = cols[10].split(",")
                try:
                    cog_func = cols[20]
                except:
                    cog_func = ""
                cazy = cols[15].split(",")
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
                                if subcat not in kegg_counts.keys():
                                    kegg_counts[subcat] = 1
                                else:
                                    kegg_counts[subcat] += 1
                        except:
                            continue
                for k in ko_mod:
                    if "M0" in k:
                        if k not in keggM_counts.keys():
                            keggM_counts[k] = 1
                        else:
                            keggM_counts[k] += 1
                for subcat in cog_func:
                    if subcat != "":
                        if subcat not in cog_counts.keys():
                            cog_counts[subcat] = 1
                        else:
                            cog_counts[subcat] += 1
        return kegg_counts, keggM_counts, cog_counts, kegg_coverage, cog_coverage, eggnog_hits, cazy_counts


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
        
    Input/Output folder must contain:
    - *eggNOG.tsv: eggNOG results
    - *InterProScan.tsv: IPRScan results

    Output files created:
    - annotation_coverage.tsv
    - kegg_classes.tsv
    - kegg_modules.tsv
    - cazy_summary.tsv
    - cog_summary.tsv''', formatter_class=RawTextHelpFormatter)
    parser.add_argument('-i', dest='in_folder', help='Input/Output folder [REQUIRED]', required=True)
    parser.add_argument('-s', dest='species_name', help='Species accession [REQUIRED]', required=True)
    parser.add_argument('-f', dest='fasta', help='Protein FASTA file [REQUIRED]', required=True)
    parser.add_argument('-k', dest='kegg_classes', help='KEGG orthology classes DB [REQUIRED]', required=True)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()
        eggnog_results = glob.glob(os.path.join(args.in_folder, "*eggNOG.tsv"))[0]
        ipr_results = glob.glob(os.path.join(args.in_folder, "*InterProScan.tsv"))[0]
        fasta_in = args.fasta
        kegg_classes = args.kegg_classes
        eggnog_data = parse_eggnog(eggnog_results)
        ipr_hits = parse_ipr(ipr_results)
        eggnog_hits = eggnog_data[5]
        with open(args.in_folder+"/annotation_coverage.tsv", "w") as summ_out:
            missing = set()
            proteins = get_proteins(fasta_in)
            total_proteins = float(len(proteins))
            for p in proteins:
                if p not in ipr_hits and p not in eggnog_hits:
                    missing.add(p)
            summ_out.write("Genome\tAnnotation\tCounts\tCoverage\n")
            summ_out.write("%s\tInterProScan\t%i\t%.2f\n" % (args.species_name, len(ipr_hits), len(ipr_hits)/total_proteins*100))
            summ_out.write("%s\teggNOG\t%i\t%.2f\n" % (args.species_name, len(eggnog_hits), len(eggnog_hits)/total_proteins*100))
            summ_out.write("%s\tCOG\t%i\t%.2f\n" % (args.species_name, eggnog_data[4], eggnog_data[4]/total_proteins*100))
            summ_out.write("%s\tKEGG\t%i\t%.2f\n" % (args.species_name, eggnog_data[3], eggnog_data[3]/total_proteins*100))
            summ_out.write("%s\tMissing\t%i\t%.2f\n" % (args.species_name, len(missing), len(missing)/total_proteins*100))
        kegg_classes = eggnog_data[0]
        with open(args.in_folder+"/kegg_classes.tsv", "w") as kegg_out:
            kegg_out.write("Genome\tKEGG_class\tCounts\n")
            for kegg in kegg_classes:
                kegg_out.write("%s\t%s\t%i\n" % (args.species_name, kegg, kegg_classes[kegg]))
        kegg_modules = eggnog_data[1]
        with open(args.in_folder+"/kegg_modules.tsv", "w") as kegg_out:
            kegg_out.write("Genome\tKEGG_module\tCounts\n")
            for kegg in kegg_modules:
                kegg_out.write("%s\t%s\t%i\n" % (args.species_name, kegg, kegg_modules[kegg]))
        cog_summary = eggnog_data[2]
        with open(args.in_folder+"/cog_summary.tsv", "w") as cog_out:
            cog_out.write("Genome\tCOG_category\tCounts\n")
            for cog in cog_summary:
                cog_out.write("%s\t%s\t%i\n" % (args.species_name, cog, cog_summary[cog]))
        cazy_summary = eggnog_data[-1]
        with open(args.in_folder+"/cazy_summary.tsv", "w") as cazy_out:
            cazy_out.write("Genome\tCAZy_category\tCounts\n")
            for cazy in cazy_summary:
                cazy_out.write("%s\t%s\t%i\n" % (args.species_name, cazy, cazy_summary[cazy]))
