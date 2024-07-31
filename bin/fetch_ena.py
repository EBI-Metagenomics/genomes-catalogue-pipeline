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

API_ENDPOINT = 'https://www.ebi.ac.uk/ena/portal/api/search'


def main(input_file, directory, unzip, bins, ignore_metadata, do_not_filter):
    metadata = list()
    studies = get_studies(input_file)
    logging.debug(f"Got {len(studies)} studies")
    if not os.path.exists(directory):
        os.makedirs(directory)
    if not studies:
        logging.error('There are no studies to fetch')
        sys.exit(1)
    else:
        for study_acc in studies:
            logging.debug(f"Processing {study_acc}")
            number_of_mags, study_metadata = load_study(study_acc, directory, unzip, bins, ignore_metadata,
                                                        do_not_filter)
            metadata.extend(study_metadata)
            logging.debug(f"Found {str(number_of_mags)} MAGs in study {study_acc}")
    if not ignore_metadata:
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


def load_study(acc, directory, unzip, bins, ignore_metadata, do_not_filter):
    already_fetched = [i.split('.')[0] for i in os.listdir(directory)]
    number_of_mags = 0
    if bins:
        query = {
            'result': 'analysis',
            'query': 'study_accession="{}" AND assembly_type="binned metagenome"'.format(acc),
            'fields': 'accession,assembly_type,study_accession,sample_accession,generated_ftp',
            'format': 'tsv'
        }
        sample_field = 3
        ftp_field = 4

    else:
        query = {
            'result': 'wgs_set',
            'query': 'study_accession="{}" AND assembly_type="metagenome-assembled genome (mag)"'.format(acc),
            'fields': 'accession,assembly_type,study_accession,sample_accession,set_fasta_ftp',
            'format': 'tsv'
        }
        sample_field = 3
        ftp_field = 4

    r = run_request(query, API_ENDPOINT)

    study_metadata = list()
    for line in r.text.splitlines():
        if not line.startswith(('accession', 'analysis_accession')):
            number_of_mags += 1
            if not ignore_metadata:
                contamination, completeness = get_contamination_completeness(line.strip().split('\t')[sample_field])
                if not all([contamination, completeness]):
                    logging.error('Missing contamination and/or completeness for MAG {}. Run with --ignore-metadata '
                                  'flag to download files without metadata.'.
                                  format(line.strip().split('\t')[sample_field]))
                    sys.exit(1)
            if not ignore_metadata and not qs50(float(contamination), float(completeness)) and not do_not_filter:
                logging.info('MAG did not pass QC: {}, {}, {}'.
                             format(line.strip().split('\t')[sample_field], completeness, contamination))
            else:
                ftp_location = line.strip().split('\t')[ftp_field]
                if not ftp_location.startswith('ftp://'):
                    ftp_location = 'ftp://' + ftp_location
                if bins:
                    mag_acc = line.strip().split('\t')[0]
                else:
                    mag_acc = ftp_location.split('/')[-1].split('.')[0]
                if mag_acc in already_fetched:
                    logging.info(f'Skipping MAG {mag_acc} because it already exists')
                    # saving metadata for that MAG
                    if not ignore_metadata:
                        study_metadata.append('{},{},{}'.format('{}.fa.gz'.format(mag_acc), completeness, contamination))
                else:
                    saved_fasta = download_fasta(ftp_location, directory, mag_acc, unzip, '')
                    if not saved_fasta:
                        logging.error('Unable to fetch', mag_acc)
                    else:
                        if not ignore_metadata:
                            study_metadata.append('{},{},{}'.format(saved_fasta, completeness, contamination))
                        logging.info('Successfully fetched {}'.format(mag_acc))
    return number_of_mags, study_metadata


def print_metadata(data, directory):
    metadata_file = 'genome_stats.txt'
    metadata_path = os.path.join(directory, metadata_file)
    with open(metadata_path, 'w') as meta_out:
        meta_out.write('genome,completeness,contamination\n')
        for record in data:
            meta_out.write(record + '\n')


def parse_args():
    parser = argparse.ArgumentParser(description='Takes a list of ENA project accessions and fetches MAGs from ENA.'
                                                 'The script also creates a metadata file (genome_stats.txt) in the '
                                                 'same directory')
    parser.add_argument('-i', '--infile', required=True,
                        help='A file containing a list of ENA project accessions, one accession per line, or '
                             'a list of biomes, one biome per line, to fetch all MAGs belonging to the '
                             'specified biomes')
    parser.add_argument('-d', '--dir', required=True,
                        help='A path to a local directory where MAGs will be downloaded to')
    parser.add_argument('-u', '--unzip', action='store_true',
                        help='Store unzipped fasta files. Default = False')
    parser.add_argument('-b', '--bins', action='store_true',
                        help='Download bins instead of MAGs. Does not work if biomes rather than accessions are '
                             'provided in the input file. Default = False')
    parser.add_argument('--ignore-metadata', action='store_true',
                        help='Download bins instead of MAGs. Does not work if biomes rather than accessions are '
                             'provided in the input file. Default = False')
    parser.add_argument('--do-not-filter', action='store_true', help='Do not skip genomes that fail QS50 check. '
                                                                     'Default = False')
    parser.add_argument('--debug', action='store_true', help='set logging to DEBUG')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)
        
    main(args.infile, args.dir, args.unzip, args.bins, args.ignore_metadata, args.do_not_filter)
