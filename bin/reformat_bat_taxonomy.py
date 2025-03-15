#!/usr/bin/env python3
import os
import argparse


##### This script generates the final output of taxonomy annotation for eukaryotic MAGs from BAT outputs
##### Alejandra Escobar & Varsha Kale, EMBL-EBI
##### March 15th, 2025

tax_domain = "d__"
tax_phylum = "p__"
tax_class = "c__"
tax_order = "o__"
tax_family = "f__"
tax_genus = "g__"
tax_species = "s__"

def taxo_reporter( out_file, bat_file ):
    with open(out_file, 'w') as to_print, open('all_bin2classification.txt', 'w') as to_concat:
        to_print.write("\t".join(
            [
                'user_genome',
                'classification',
                'lineage_taxids'
            ])+'\n')
        to_concat.write("\t".join(
            [
                '# bin',
                'classification',
                'reason',
                'lineage',
                'lineage scores'
            ])+'\n')
        with open(bat_file, 'r') as file_in:
            header = file_in.readline()
            for line in file_in:
                data = line.rstrip().split('\t')
                genome,classification,reason,lineage,lineage_scores = data[:5]
                genome_name = genome.split('.')[0]
                to_concat.write("\t".join(data[:5])+'\n')
                
                clean_lineage = []
                d = data[5].split(':')[0].replace('no support', '').replace("'", '')
                p = data[6].split(':')[0].replace('no support', '').replace("'", '')
                c = data[7].split(':')[0].replace('no support', '').replace("'", '')
                o = data[8].split(':')[0].replace('no support', '').replace("'", '')
                f = data[9].split(':')[0].replace('no support', '').replace("'", '')
                g = data[10].split(':')[0].replace('no support', '').replace("'", '')
                s = data[11].split(':')[0].replace('no support', '').replace("'", '')
                clean_lineage = f"{tax_domain}{d};{tax_phylum}{p};{tax_class}{c};{tax_order}{o};{tax_family}{f};{tax_genus}{g};{tax_species}{s}"
                to_print.write(f"{genome_name}\t{clean_lineage}\t{lineage}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="This script generates the final output of taxonomy annotation for eukaryotic MAGs from BAT outputs"
    )
    parser.add_argument(
        "--output", 
        help="path for the output table", 
        default="euk_taxonomy.csv", 
        type=str
    )
    parser.add_argument(
        "--bat_names", 
        help="BAT names file (*.BAT_run.bin2classification.names.txt)", 
        required=True
    )
    args = parser.parse_args()

    taxo_reporter( args.output, args.bat_names )