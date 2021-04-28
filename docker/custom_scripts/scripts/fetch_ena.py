#!/usr/bin/env python3
# coding=utf-8

import argparse
import logging
import requests
import os
from get_ENA_metadata import get_contamination_completeness
from utils import download_fasta, qs50
import urllib.parse

logging.basicConfig(level=logging.INFO)

API_ENDPOINT = 'https://www.ebi.ac.uk/ena/portal/api/search'


def main(accession_list_file, directory, unzip):
    metadata = list()
    with open(accession_list_file, 'r') as infile:
        for study_acc in infile:
            metadata.extend(load_study(study_acc.strip(), directory, unzip))
    print_metadata(metadata, args.dir)


def load_study(acc, directory, unzip):
    query = {
        'result': 'wgs_set',
        'query': 'study_accession="{}" AND assembly_type="metagenome-assembled genome (mag)"'.format(acc),
        'fields': 'accession,assembly_type,study_accession,sample_accession,fasta_file',
        'format': 'tsv'
    }

    r = requests.get(API_ENDPOINT, params=urllib.parse.urlencode(query))
    assert r.ok, 'Cannot get FTP links from ENA for study {}'.format(acc)

    study_metadata = list()
    for line in r.text.splitlines():
        if not line.startswith('accession'):
            contamination, completeness = get_contamination_completeness(line.strip().split('\t')[3])
            if not all([contamination, completeness]):
                logging.error('Missing contamination and/or completeness for MAG {}'.
                              format(line.strip().split('\t')[3]))
            if qs50(float(contamination), float(completeness)):
                ftp_location = line.strip().split('\t')[4]
                if not ftp_location.startswith('ftp://'):
                    ftp_location = 'ftp://' + ftp_location
                mag_acc = ftp_location.split('/')[-1].split('.')[0]
                saved_fasta = download_fasta(ftp_location, directory, mag_acc, unzip, '')
                if not saved_fasta:
                    logging.error('Unable to fetch', mag_acc)
                else:
                    study_metadata.append('{},{},{}'.format(saved_fasta, completeness, contamination))
            else:
                logging.info("MAG did not pass QC:", line.strip().split('\t')[3], contamination, completeness)
    return study_metadata


def print_metadata(data, directory):
    metadata_file = 'genome_stats.txt'
    metadata_path = os.path.join(directory, metadata_file)
    with open(metadata_path, 'w') as meta_out:
        meta_out.write('genome,completeness,contamination\n')
        for record in data:
            meta_out.write(record + '\n')


def parse_args():
    parser = argparse.ArgumentParser(description='Takes a list of ENA project accessions and fetches MAGs from ENA')
    parser.add_argument('-i', '--infile', required=True,
                        help='A file containing a list of ENA project accessions, one accession per line')
    parser.add_argument('-d', '--dir', required=True,
                        help='A path to a local directory where MAGs will be downloaded to')
    parser.add_argument('-u', '--unzip', action='store_true',
                        help='Store unzipped fasta files. Default = False')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.infile, args.dir, args.unzip)

