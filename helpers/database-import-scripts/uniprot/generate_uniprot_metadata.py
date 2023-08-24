#!/usr/bin/env python3

import argparse

import pandas as pd
import requests
from retry import retry


def main(metadata_file, outfile):
    with open(metadata_file, "r") as file_in:
        original_df = pd.read_csv(metadata_file, sep='\t')
        filtered_df = original_df[original_df['Genome'] == original_df['Species_rep']]
        relevant_columns = ['Genome', 'N50', 'Completeness', 'Contamination', 'Sample_accession']
        reduced_df = filtered_df[relevant_columns].copy()
        reduced_df['GCA_accession'] = reduced_df['Sample_accession'].apply(get_gca_accession)
        reduced_df = reduced_df.drop(columns=["Sample_accession"])

        # Reorder the columns
        columns = reduced_df.columns.tolist()  # Convert columns to a list
        columns.insert(1, columns.pop(4))  # Move the 5th column to the 2nd position
        reordered_df = reduced_df[columns]  # Create a new DataFrame with reordered columns
        reordered_df.to_csv(outfile, index=False, sep='\t')


def get_gca_accession(sample):
    api_endpoint = "https://www.ebi.ac.uk/ena/portal/api/filereport"
    full_url = "{}?accession={}&result=assembly&fields=accession".format(api_endpoint, sample)
    r = run_request(full_url)
    if r.ok:
        lines = r.text.split('\n')
        try:
            gca_line = next(line for line in lines if line.startswith("GCA"))
        except:
            gca_line = "N/A"
        return gca_line
    else:
        return "N/A"


@retry(tries=5, delay=10, backoff=1.5)
def run_request(full_url):
    r = requests.get(url=full_url)
    r.raise_for_status()
    return r


def parse_args():
    parser = argparse.ArgumentParser(description="The script takes the catalogue metadata table and "
                                                 "generates a metadata table to be submitted to UniProt.")
    parser.add_argument('-m', '--metadata', required=True,
                        help='Path to the metadata table.')
    parser.add_argument('-o', '--output', required=True,
                        help='Path to the output file.')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.metadata, args.output)