#!/usr/bin/env python3
# coding=utf-8

import os
import urllib.request as request
import urllib.parse
import urllib.error as error
import gzip
import time

import requests
from retry import retry


def download_fasta(url, folder, accession, unzip, checksum):
    if not url.lower().startswith('ftp'):
        print(url, 'is not an URL\n')
        return False
    else:
        max_attempts = 5
        attempt = 1
        sleep_time = 15
        outfile = '{}.fa.gz'.format(accession)
        if unzip:
            outfile = outfile[:-3]
        outpath = os.path.join(folder, outfile)
        if not os.path.exists(folder):
            os.makedirs(folder)
        while attempt <= max_attempts:
            try:
                response = request.urlopen(url)
                content = response.read()
                if unzip:
                    with open(outpath, 'w') as out:
                        out.write(gzip.decompress(content).decode('utf-8'))
                else:
                    with open(outpath, 'wb') as out:
                        out.write(content)
                break
            except (error.HTTPError, error.URLError) as e:
                print('Could not retrieve URL', url, ' Reason:', e.reason)
                print('Retrying...')
                attempt += 1
                time.sleep(sleep_time)
        if not os.path.exists(outpath) or os.path.getsize(outpath) == 0:
            return None
        else:
            return outfile


def qs50(contamination, completeness):
    contam_cutoff = 5.0
    qs_cutoff = 50.0

    if contamination > contam_cutoff:
        return False
    elif completeness - contamination * 5 < qs_cutoff:
        return False
    else:
        return True


@retry(tries=5, delay=10, backoff=1.5)
def run_request(query, api_endpoint):
    r = requests.get(api_endpoint, params=urllib.parse.urlencode(query))
    r.raise_for_status()
    return r
