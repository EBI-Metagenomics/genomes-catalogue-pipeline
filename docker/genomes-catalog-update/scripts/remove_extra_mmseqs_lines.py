#!/usr/bin/env python3
# coding=utf-8

import argparse
import logging

logging.basicConfig(level=logging.INFO)


def main(infile, outfile):
    with open(infile, "r") as file_in, open(outfile, "w") as file_out:
        line = file_in.readline()
        previous_line = ""
        while line:
            if line.startswith(">"):
                if previous_line.startswith(">"):
                    file_out.write(line)
                    previous_line = ""
                else:
                    previous_line = line
            else:
                if previous_line.startswith(">"):
                    file_out.write(previous_line)
                    previous_line = ""
                file_out.write(line)
            line = file_in.readline()


def parse_args():
    parser = argparse.ArgumentParser(description='Prepares a protein fasta file for mmseqs db update. The input'
                                                 'should be the mmseqs_cluster.fa clustered at 100% amino acid'
                                                 'identity. The script removed extra fasta headers (some entries'
                                                 'have a header but no sequence).')
    parser.add_argument('-i', '--infile', required=True,
                        help='Path to the mmseqs_cluster.fa file from 100% amino acid identity db.')
    parser.add_argument('-o', '--outfile', required=True,
                        help='Path to the outfile')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.infile, args.outfile)
