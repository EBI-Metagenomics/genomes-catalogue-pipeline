#!/usr/bin/env python3
# coding=utf-8

import argparse
import logging
import os

logging.basicConfig(level=logging.INFO)


def main(ips, eggnog, rep_list, outdir):
    if not os.path.exists(outdir):
        os.makedirs(outdir)
    # load representative accessions
    with open(rep_list, 'r') as rep_in:
        genome_list = [line.strip().replace('.fa', '') for line in rep_in]
    # initialize results dictionaries
    results_ips = {genome:list() for genome in genome_list}
    results_eggnog = {genome: list() for genome in genome_list}
    # separate annotations by genome and load into dictionaries
    header_ips = load_annotations(ips, results_ips)
    header_eggnog = load_annotations(eggnog, results_eggnog)
    # generate result files
    print_results(results_ips, header_ips, outdir, 'InterProScan')
    print_results(results_eggnog, header_eggnog, outdir, 'eggNOG')


def print_results(result_dict, header, outdir, tool):
    for acc in result_dict.keys():
        out_path = os.path.join(outdir, '{}_{}.tsv'.format(acc, tool))
        with open(out_path, 'w') as file_out:
            if header:
                file_out.write(header + '\n')
            file_out.write('\n'.join(result_dict[acc]))


def load_annotations(ann_file, ann_result):
    header = ''
    with open(ann_file, 'r') as file_in:
        for line in file_in:
            line = line.strip()
            if line.startswith('#'):
                header = line
            else:
                genome = line.split('_')[0]
                if genome not in ann_result:
                    logging.error('Genome {} is in the annotation file but not present in the representative genome '
                                 'list'.format(genome))
                else:
                    ann_result[genome].append(line)
    return header


def parse_args():
    parser = argparse.ArgumentParser(description='Takes interproscan and eggNOG results for an MMseqs catalog as well '
                                                 'as a list of representative genomes and locations where the results '
                                                 'should be stored and creates individual annotation files for each '
                                                 'representative genome')
    parser.add_argument('-i', '--ips', required=True,
                        help='Path to the interproscan input file')
    parser.add_argument('-e', '--eggnog', required=True,
                        help='Path to the eggNOG input file')
    parser.add_argument('-r', '--rep-list', required=True,
                        help='Path to a file containing species representatives')
    parser.add_argument('-o', '--outdir', required=True,
                        help='Path to the folder where the results will be stored')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.ips, args.eggnog, args.rep_list, args.outdir)