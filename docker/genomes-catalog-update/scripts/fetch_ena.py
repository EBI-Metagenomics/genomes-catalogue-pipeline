#!/usr/bin/env python3
# coding=utf-8

# This file is part of MGnify genome analysis pipeline.
#
# MGnify genome analysis pipeline is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MGnify genome analysis pipeline is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with MGnify genome analysis pipeline. If not, see <https://www.gnu.org/licenses/>.


import argparse
import logging
import os
import sys

from get_ENA_metadata import get_contamination_completeness
from utils import download_fasta, qs50, run_request


logging.basicConfig(level=logging.INFO)

API_ENDPOINT = 'https://www.ebi.ac.uk/ena/portal/api/search'


def main(input_file, directory, unzip):
    metadata = list()
    studies = get_studies(input_file)
    if not studies:
        logging.error('There are no studies to fetch')
        sys.exit(1)
    else:
        for study_acc in studies:
            metadata.extend(load_study(study_acc, directory, unzip))
    if not os.path.exists(directory):
        os.makedirs(directory)
    print_metadata(metadata, args.dir)


def get_studies(input_file):
    biomes = set()
    studies = set()
    with open(input_file, 'r') as infile:
        for record in infile:
            record = record.strip()
            if record.startswith('PRJ'):
                studies.add(record)
            elif record.startswith(('ERP', 'DRP', 'SRP')):
                logging.error('Cannot process accession {} - primary study accession must be provided'.format(record))
            else:
                biomes.add(record)
    if biomes:
        studies_in_biome = get_biome_studies(biomes)
        studies.update(studies_in_biome)
    return studies


def get_biome_studies(biomes):
    studies_to_add = set()
    query = {
        'result': 'wgs_set',
        'query': 'assembly_type="metagenome-assembled genome (mag)"',
        'fields': 'study_accession,metagenome_source',
        'format': 'tsv'
    }
    logging.info('Requesting a list of projects for biomes {} from ENA...'.format(biomes))
    r = run_request(query, API_ENDPOINT)

    for line in r.text.splitlines():
        if not line.startswith('accession'):
            study, biome = line.split('\t')[1:]
            if biome in biomes:
                studies_to_add.add(study)
    return studies_to_add


def load_study(acc, directory, unzip):
    query = {
        'result': 'wgs_set',
        'query': 'study_accession="{}" AND assembly_type="metagenome-assembled genome (mag)"'.format(acc),
        'fields': 'accession,assembly_type,study_accession,sample_accession,fasta_file',
        'format': 'tsv'
    }

    r = run_request(query, API_ENDPOINT)

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
                    logging.info('Successfully fetched {}'.format(mag_acc))
            else:
                logging.info('MAG did not pass QC: {}, {}, {}'.format(line.strip().split('\t')[3], completeness,
                                                                      contamination))
    return study_metadata


def print_metadata(data, directory):
    metadata_file = 'genome_stats.txt'
    metadata_path = os.path.join(directory, metadata_file)
    with open(metadata_path, 'w') as meta_out:
        meta_out.write('genome,completeness,contamination\n')
        for record in data:
            meta_out.write(record + '\n')


def parse_args():
    parser = argparse.ArgumentParser(description='Takes a list of ENA project accessions and fetches MAGs from ENA.'
                                                 'The script also create a metadata file (genome_stats.txt) in the same'
                                                 'directory')
    parser.add_argument('-i', '--infile', required=True,
                        help='A file containing a list of ENA project accessions, one accession per line, or'
                             'a list of biomes, one biome per line, to fetch all MAGs belonging to the '
                             'specified biomes')
    parser.add_argument('-d', '--dir', required=True,
                        help='A path to a local directory where MAGs will be downloaded to')
    parser.add_argument('-u', '--unzip', action='store_true',
                        help='Store unzipped fasta files. Default = False')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.infile, args.dir, args.unzip)

