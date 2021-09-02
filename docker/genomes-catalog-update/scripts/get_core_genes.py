#!/usr/bin/env python3
# coding=utf-8

import argparse


def main(infile, outfile):
    file_out = open(outfile, 'w')
    with open(infile, 'r') as file_in:
        headers = file_in.readline()
        num_genomes = len(headers.strip().split('\t')) - 1
        for line in file_in:
            fields = line.strip().split('\t')
            int_fields = [int(a) for a in fields[1:num_genomes + 1] if a != '']
            if sum(int_fields)/num_genomes >= 0.9:
                file_out.write("{}\n".format(fields[0]))
    file_out.close()


def parse_args():
    parser = argparse.ArgumentParser(description='Takes an Rtab file from Panaroo and outputs a list of core'
                                                 'genes (defined as present in >=90% of genomes)')
    parser.add_argument('-i', '--infile', required=True,
                        help='Path to the input file')
    parser.add_argument('-o', '--outfile', required=True,
                        help='Path to the output file')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.infile, args.outfile)