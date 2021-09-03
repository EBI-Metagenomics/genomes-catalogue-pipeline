#!/usr/bin/env python3
# coding=utf-8

import argparse
import os
from shutil import copy


def parse_args():
    parser = argparse.ArgumentParser(description='This script copies genomes from ENA and NCBI folders '
                                                 'to common folder. It also unites csv files')
    parser.add_argument('--ena', required=False,
                        help='path to folder with ENA genomes')
    parser.add_argument('--ncbi', required=False,
                        help='path to folder with NCBI genomes')
    parser.add_argument('--ena-csv', required=False,
                        help='ena csv file with completeness and contamination')
    parser.add_argument('--ncbi-csv', required=False,
                        help='ncbi csv file with completeness and contamination')
    parser.add_argument('--outname', required=False,
                        help='name of output folder', default='genomes')
    return parser.parse_args()


def create_folder(data, outname):
    for item in os.listdir(data):
        if item.endswith('fa') or item.endswith('fa.gz') or item.endswith('fasta') or item.endswith('fasta.gz'):
            copy(os.path.join(data,item), os.path.join(outname, os.path.basename(item)))


def process_csv(csv, out_csv):
    with open(csv, 'r') as input_csv:
        for line in input_csv:
            if len(line.split('ompleteness')) == 1:
                if not line.endswith('\n'):
                    line += '\n'
                out_csv.write(line)
    return out_csv


def main(args):
    if not args.ena and not args.ncbi:
        print('No input data')
        exit(1)
    else:
        # directory
        if not os.path.exists(args.outname):
            os.mkdir(args.outname)
        if args.ena:
            create_folder(args.ena, args.outname)
        if args.ncbi:
            create_folder(args.ncbi, args.outname)
        # csv
        out_csv = args.outname + '.csv'
        with open(out_csv, 'w') as output:
            output.write("genome,completeness,contamination\n")
            if args.ena_csv:
                output = process_csv(args.ena_csv, output)
            if args.ncbi_csv:
                output = process_csv(args.ncbi_csv, output)


if __name__ == '__main__':
    main(parse_args())