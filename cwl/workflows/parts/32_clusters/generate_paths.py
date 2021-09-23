#!/usr/bin/env python

import sys
import argparse


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script")
    parser.add_argument("-i", "--input", dest="input")
    parser.add_argument("-p", "--path", dest="path")

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()
        common_pattern = "  - class: {}\n    path: {} \n"
        folders = []
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
