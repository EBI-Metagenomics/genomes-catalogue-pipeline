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
    -i for mmseq
python3 generate_paths.py \
    -t mmseq \
    -p /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/RESULTS/rumen/  \
    --mmseq-one one_faas --mmseq-many many_faas
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
    parser.add_argument("-t", "--type", dest="type", choices=["one", "many", "mmseq"])
    parser.add_argument("--mmseq-one", dest="mmseq_one", required=False)
    parser.add_argument("--mmseq-many", dest="mmseq_many", required=False)

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
        if args.type == "mmseq":
            one, many = [], []
            if args.mmseq_one:
                with open(args.mmseq_one, 'r') as file_in:
                    for line in file_in:
                        one.append(line.strip())
            if args.mmseq_many:
                with open(args.mmseq_many, 'r') as file_in:
                    for line in file_in:
                        many.append(line.strip())
            all = []
            if args.input:
                with open(args.input, 'r') as file_in:
                    for line in file_in:
                        all.append(line.strip())
            if args.mmseq_one:
                included_one = one
                if all != []:
                    included_many = list(set(all).difference(set(one)))
                    print(len(included_one), len(included_many))
            if args.mmseq_many:
                included_many = many
                if all != []:
                    included_one = list(set(all).difference(set(many)))
                    print(len(included_one), len(included_many))
            with open('out_one.yml', 'w') as file_out:
                for i in included_one:
                    line = common_pattern.format("File", args.path + i)
                    file_out.write(line)
            with open('out_many.yml', 'w') as file_out:
                for i in included_many:
                    line = common_pattern.format("File", args.path + i)
                    file_out.write(line)