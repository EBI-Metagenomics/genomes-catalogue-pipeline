#!/usr/bin/env python3
# coding=utf-8

import argparse
import logging
import time
import urllib.request as request
import urllib.error as error
from utils import download_fasta

LINKS = 'https://ftp.ncbi.nlm.nih.gov/genomes/genbank/assembly_summary_genbank.txt'

logging.basicConfig(level=logging.INFO)

#Add checksums


def main():
    parser = argparse.ArgumentParser(description='Takes a list of accessions and fetches genomes from NCBI')
    parser.add_argument('-i', '--infile', required=True, help='A file containing a list of GenBank accessions,'
                                                              'one accession per line')
    parser.add_argument('-d', '--dir', required=True, help='A path to a local directory where MAGs will be '
                                                           'downloaded to')
    parser.add_argument('-u', '--unzip', action='store_true', help='Store unzipped fasta files. Default = False')
    args = parser.parse_args()

    failed = 0
    complete = 0
    no_url = 0

    # save accessions to dictionary
    accession_dict = load_accessions(args.infile)
    assert len(accession_dict) > 0, 'No accessions were loaded from infile'
    # add GenBank file locations as arguments to the accessions dictionary
    success = load_locations(accession_dict)
    if not success:
        logging.error('Failed to load the FTP locations')
    else:
        # go through accessions and download the fasta files
        logging.info('Loaded FTP locations, proceeding to download...')
        for a in accession_dict:
            if not accession_dict[a]:
                no_url += 1
            else:
                logging.info('Downloading {}...'.format(a))
                result = download_fasta(accession_dict[a], args.dir, a, args.unzip, '')
                if result:
                    complete += 1
                else:
                    failed += 1
                    logging.error('Could not download {}'.format(accession_dict[a]))

    logging.info('Total number of accessions provided: {}'.format(len(accession_dict)))
    logging.info('Successfully downloaded {} files'.format(complete))
    logging.info('Download failed for {} files'.format(failed))
    logging.info('No URL retrieved for {} files'.format(no_url))


def load_accessions(infile):
    accessions = dict()
    with open(infile, 'r') as acc_in:
        for line in acc_in:
            accessions[line.strip().split('.')[0]] = ''
    return accessions


def load_locations(accessions):
    max_attempts = 6
    attempt = 1
    sleep_time = 10
    flag = False  # used to check if any lines were successfully read
    while attempt < max_attempts:
        logging.info('Downloading FTP locations...')
        logging.info('Attempt {}'.format(attempt))
        try:
            response = request.urlopen(LINKS)
            while True:
                content = response.readline()
                if not content:
                    break
                line = content.decode('utf-8')
                if line.startswith('#') or line.isspace():
                    pass
                else:
                    acc = line.split()[0].split('.')[0]
                    if acc in accessions:
                        path = line.split('\t')[19]
                        file_name = '{}_genomic.fna.gz'.format(path.split('/')[-1])
                        full_url = '/'.join([path, file_name])
                        accessions[acc] = full_url
                    flag = True
            break
        except error.HTTPError as e:
            logging.error(e.reason)
            attempt += 1
            time.sleep(sleep_time)
    if attempt == max_attempts and not flag:
        return False
    else:
        return True


if __name__ == '__main__':
    main()
