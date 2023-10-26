#!/usr/bin/env python3

import argparse

import pandas as pd
import requests
from retry import retry


def main(metadata_file, outfile, processed_taxonomy):
    original_df = pd.read_csv(metadata_file, sep='\t')
    filtered_df = original_df[original_df['Genome'] == original_df['Species_rep']]
    relevant_columns = ['Genome', 'N50', 'Completeness', 'Contamination', 'Sample_accession']
    reduced_df = filtered_df[relevant_columns].copy()
    reduced_df['GCA_accession'] = reduced_df['Genome'].apply(get_gca_accession, processed_taxonomy=processed_taxonomy)
    reduced_df['Taxid'] = reduced_df['Genome'].apply(get_taxid, processed_taxonomy=processed_taxonomy)
    reduced_df['Species_level'] = reduced_df['Genome'].apply(get_species_level, processed_taxonomy=processed_taxonomy)
    reduced_df = reduced_df.drop(columns=["Sample_accession"])

    # Reorder the columns
    columns = reduced_df.columns.tolist()  # Convert columns to a list
    columns.insert(1, columns.pop(4))  # Move the 5th column to the 2nd position
    reordered_df = reduced_df[columns]  # Create a new DataFrame with reordered columns
    reordered_df.to_csv(outfile, index=False, sep='\t')


def get_species_level(genome, processed_taxonomy):
    with open(processed_taxonomy) as file_in:
        for line in file_in:
            if line.startswith(genome):
                _, _, _, _, _, species_level, _ = line.strip().split("\t")
                return species_level


def get_taxid(genome, processed_taxonomy):
    with open(processed_taxonomy) as file_in:
        for line in file_in:
            if line.startswith(genome):
                _, _, _, _, taxid, _, _ = line.strip().split("\t")
                return taxid
            
    
def get_gca_accession(genome, processed_taxonomy):
    with open(processed_taxonomy) as file_in:
        for line in file_in:
            if line.startswith(genome):
                _, _, _, gca, _, _, _ = line.strip().split("\t")
                return gca


@retry(tries=5, delay=10, backoff=1.5)
def run_request(full_url):
    r = requests.get(url=full_url)
    r.raise_for_status()
    return r


def parse_args():
    parser = argparse.ArgumentParser(description="The script takes the catalogue metadata table and Uniprot "
                                                 "results folder and generates a metadata table to be submitted "
                                                 "to UniProt.")
    parser.add_argument('-m', '--metadata', required=True,
                        help='Path to the metadata table.')
    parser.add_argument('-o', '--output', required=True,
                        help='Path to the output file.')
    parser.add_argument('-p', '--processed-taxonomy', required=True,
                        help='Path to the preprocessed taxonomy file generated by preprocess_taxonomy_for_uniprot.py.')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.metadata, args.output, args.processed_taxonomy)