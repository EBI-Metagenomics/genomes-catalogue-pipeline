#!/usr/bin/env python

import sys
import argparse

"""
    -i for many
1048_1_mash.tsv
180_1_mash.tsv
339_1_mash.tsv
...
    -i for one
1_0
10_0
100_0
1000_1
...
python3 generate_paths.py \
    -t one \
    -p /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/RESULTS/marine/clusters/  \
    -i one_clusters.txt 
"""

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script")
    parser.add_argument("-i", "--input", dest="input")
    parser.add_argument("-p", "--path", dest="path")
    parser.add_argument("-t", "--type", dest="type", choices=["one", "many"])

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()
        common_pattern = "  - class: {}\n    path: {} \n"
        folders = []
        if args.type == "many":
            with open(args.input, 'r') as file_in:
                for line in file_in:
                    line = line.strip()
                    fields = line.split('_')
                    folders.append('_'.join(fields[:2]))
            with open('out.yml', 'w') as file_out:
                file_out.write("input_clusters:\n")
                for folder in folders:
                    line = common_pattern.format("Directory", args.path+folder)
                    file_out.write(line)
                file_out.write("mash_folder:\n")
                for folder in folders:
                    line = common_pattern.format("File", args.path+"mash_folder/"+folder+"_mash.tsv")
                    file_out.write(line)
        if args.type == "one":
            with open(args.input, 'r') as file_in, open('out.yml', 'w') as file_out:
                file_out.write("input_cluster:\n")
                for line in file_in:
                    line = line.strip()
                    fields = line.split('_')
                    name = '_'.join(fields[:2])
                    line = common_pattern.format("Directory", args.path+name)
                    file_out.write(line)
