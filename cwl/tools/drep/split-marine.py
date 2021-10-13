#!/usr/bin/env python

import os
import sys
import argparse
from shutil import copy


def get_scores(sdb):
    scores = {}
    with open(sdb, 'r') as file_in:
        next(file_in)
        for line in file_in:
            values = line.strip().split(',')
            scores.setdefault(values[0], values[1])
    return scores


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Split dRep results by species cluster")
    parser.add_argument('-i', dest='input', help='incorrect split.txt')
    parser.add_argument("--sdb", dest="sdb", help="dRep Sdb.csv", required=True)

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()

        # get scores for genomes
        scores = get_scores(sdb=args.sdb)
        with open(args.input, 'r') as file_in, open('split-new.txt', 'w') as file_out:
            for line in file_in:
                line = line.strip().split(':')
                name = line[0]
                cluster = line[1]
                if name == 'many_genomes':
                    genomes = line[2].split(',')
                    print(genomes)
                    genome_scores = [float(scores[genome]) for genome in genomes]
                    print(genome_scores)
                    sorted_genomes = [x for _, x in sorted(zip(genome_scores, genomes), reverse=True,
                                                           key=lambda pair: pair[0])]
                else:
                    sorted_genomes = [line[2]]
                file_out.write(name + ':' + cluster + ':' + ','.join(sorted_genomes) + '\n')