#!/usr/bin/env python3
# coding=utf-8

import argparse
import logging
import os
import pandas as pd
import re
import sys

import requests
from retry import retry

from assembly_stats import run_assembly_stats
from get_ENA_metadata import get_location, load_xml

logging.basicConfig(level=logging.INFO)


def main(genomes_dir, extra_weight_table, checkm_results, rna_results, naming_file, clusters_file, taxonomy_file,
         geofile, outfile, ftp_name, ftp_version):
    #table_columns = ['Genome', 'Genome_type', 'Length', 'N_contigs', 'N50',	'GC_content',
    #           'Completeness', 'Contamination', 'rRNA_5S', 'rRNA_16S', 'rRNA_23S', 'tRNAs', 'Genome_accession',
    #           'Species_rep', 'MGnify_accession', 'Lineage', 'Sample_accession', 'Study_accession', 'Country',
    #           'Continent', 'FTP_download']
    genome_list = load_genome_list(genomes_dir)
    df = pd.DataFrame(genome_list, columns=['Genome'])
    df = add_genome_type(df, extra_weight_table)
    df = add_stats(df, genomes_dir)
    df = add_checkm(df, checkm_results)
    df = add_rna(df, genome_list, rna_results)
    df, original_accessions = add_original_accession(df, naming_file)
    df, reps = add_species_rep(df, clusters_file)
    df = add_taxonomy(df, taxonomy_file, genome_list, reps)
    df = add_sample_project_loc(df, original_accessions, geofile)
    df = add_ftp(df, genome_list, ftp_name, ftp_version, reps)
    df.set_index('Genome', inplace=True)
    df.to_csv(outfile, sep='\t')


def add_ftp(df, genome_list, catalog_ftp_name, catalog_version, species_reps):
    ftp_res = dict()
    url = 'ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/mgnify_genomes/{}/{}/all_genomes'.format(
        catalog_ftp_name, catalog_version)
    for genome in genome_list:
        subfolder = species_reps[genome][:-3]
        ftp_res[genome] = '{}/{}/{}/genomes1/{}.gff.gz'.format(url, subfolder, species_reps[genome], genome)
    df['FTP_download'] = df['Genome'].map(ftp_res)
    return df


def add_sample_project_loc(df, original_accessions, geofile):
    countries_continents = load_geography(geofile)
    metadata = dict()
    for col_name in ['Sample_accession', 'Study_accession', 'Country', 'Continent']:
        metadata.setdefault(col_name, dict())
    for new_acc, original_acc in original_accessions.items():
        sample, project, loc = get_metadata(original_acc)
        metadata['Sample_accession'][new_acc] = sample
        metadata['Study_accession'][new_acc] = project
        metadata['Country'][new_acc] = loc
        if loc in countries_continents:
            metadata['Continent'][new_acc] = countries_continents[loc]
        else:
            metadata['Continent'][new_acc] = 'not provided'
    for col_name in ['Sample_accession', 'Study_accession', 'Country', 'Continent']:
        df[col_name] = df['Genome'].map(metadata[col_name])
    return df


def load_geography(geofile):
    geography = dict()
    with open(geofile, 'r') as file_in:
        for line in file_in:
            if not line.startswith('Continent'):
                fields = line.strip().split(',')
                geography[fields[1]] = fields[0]
    return geography


def get_metadata(acc):
    if acc.startswith('CA'):
        acc = acc + '0' * 7
    r = run_request(acc, 'https://www.ebi.ac.uk/ena/browser/api/embl')
    if r.ok:
        match_pr = re.findall('PR +Project: *(PRJ[A-Z0-9]+)', r.text)
        if match_pr:
            project = match_pr[0]
        else:
            project = ''
        match_samp = re.findall('DR +BioSample; ([A-Z0-9]+)', r.text)
        if match_samp:
            biosample = match_samp[0]
        else:
            biosample = ''
    else:
        logging.error('Cannot obtain metadata from ENA')
        sys.exit()
    location = get_location(biosample)
    if not location:
        location = 'not provided'
    json_data_sample = load_xml(biosample)
    converted_sample = json_data_sample['SAMPLE_SET']['SAMPLE']['IDENTIFIERS']['PRIMARY_ID']
    if not converted_sample:
        converted_sample = biosample
    json_data_project = load_xml(project)
    converted_project = json_data_project['PROJECT_SET']['PROJECT']['IDENTIFIERS']['SECONDARY_ID']
    if not converted_project:
        converted_project = project
    return converted_sample, converted_project, location


@retry(tries=5, delay=10, backoff=1.5)
def run_request(acc, url):
    r = requests.get('{}/{}'.format(url, acc))
    r.raise_for_status()
    return r


def add_taxonomy(df, taxonomy_file, genome_list, reps):
    taxonomy_result = dict()
    with open(taxonomy_file, 'r') as file_in:
        for line in file_in:
            if not line.startswith('user_genome'):
                fields = line.strip().split('\t')
                taxonomy_result[fields[0]] = fields[1]
    for genome in genome_list:
        if genome not in taxonomy_result:
            taxonomy_result[genome] = taxonomy_result[reps[genome]]
    df['Lineage'] = df['Genome'].map(taxonomy_result)
    return df


def add_species_rep(df, clusters_file):
    reps = dict()
    with open(clusters_file, 'r') as file_in:
        for line in file_in:
            if line.startswith('one_genome'):
                genome = line.strip().split(':')[-1].split('.')[0]
                reps[genome] = genome
            elif line.startswith('many_genomes'):
                fields = line.strip().split(':')
                rep = fields[2].split('.')[0]
                cluster_members = fields[2].split(',')
                for i in range(0, len(cluster_members)):
                    reps[cluster_members[i].split('.')[0]] = rep
            else:
                if not line.strip() == '':
                    logging.error('Unknown clusters file format: {}'.format(line))
                    sys.exit()
    df['Species_rep'] = df['Genome'].map(reps)
    return df, reps


def add_original_accession(df, naming_file):
    conversion_table = dict()
    with open(naming_file, 'r') as file_in:
        for line in file_in:
            fields = line.strip().split('\t')
            old, new = fields[0].split('.')[0], fields[1].split('.')[0]
            conversion_table[new] = old
    df['Genome_accession'] = df['Genome'].map(conversion_table)
    return df, conversion_table


def add_rna(df, genome_list, rna_folder):
    rna_results = dict()
    for key in ['rRNA_5S', 'rRNA_16S', 'rRNA_23S', 'tRNAs']:
        rna_results.setdefault(key, dict())
    for genome in genome_list:
        rrna_file = os.path.join(rna_folder, '{}_out-results'.format(genome), '{}_rRNAs.out'.format(genome))
        trna_file = os.path.join(rna_folder, '{}_out-results'.format(genome), '{}_tRNA_20aa.out'.format(genome))
        rna_results['tRNAs'][genome] = load_trna(trna_file)
        rna_results['rRNA_5S'][genome], rna_results['rRNA_16S'][genome], rna_results['rRNA_23S'][genome] = load_rrna(
            rrna_file)
    for key in ['rRNA_5S', 'rRNA_16S', 'rRNA_23S', 'tRNAs']:
        df[key] = df['Genome'].map(rna_results[key])
    return df


def load_rrna(rrna_file):
    with open(rrna_file, 'r') as file_in:
        for line in file_in:
            fields = line.strip().split('\t')
            if fields[1].startswith('SSU_rRNA'):
                rRNA_16S = fields[2]
            elif fields[1].startswith('5S_rRNA'):
                rRNA_5S = fields[2]
            elif fields[1].startswith('LSU_rRNA'):
                rRNA_23S = fields[2]
            else:
                logging.error('Unexpected file format: {}'.format(rrna_file))
                sys.exit()
    return rRNA_5S, rRNA_16S, rRNA_23S


def load_trna(trna_file):
    with open(trna_file, 'r') as file_in:
        return file_in.readline().strip().split('\t')[1]


def add_checkm(df, checkm_results):
    checkm_compl = dict()
    checkm_contam = dict()
    with open(checkm_results, 'r') as file_in:
        for line in file_in:
            if not line.startswith('genome,'):
                fields = line.strip().split(',')
                checkm_compl[fields[0].split('.')[0]] = fields[1]
                checkm_contam[fields[0].split('.')[0]] = fields[2]
    df['Completeness'] = df['Genome'].map(checkm_compl)
    df['Contamination'] = df['Genome'].map(checkm_contam)
    return df


def add_stats(df, genomes_dir):
    new_df = df.apply(lambda x: calc_assembly_stats(genomes_dir, x['Genome']), axis=1)
    return pd.concat([df, new_df], axis=1)


def calc_assembly_stats(genomes_dir, acc):
    file_path = os.path.join(genomes_dir, '{}.fa'.format(acc))
    stats = run_assembly_stats(file_path)
    return pd.Series([int(stats['Length']), int(stats['N_contigs']), int(stats['N50']), str(round(stats['GC_content'],2))],
                     index=['Length', 'N_contigs', 'N50', 'GC_content'])


def add_genome_type(df, extra_weight_table):
    result = dict()
    with open(extra_weight_table, 'r') as file_in:
        for line in file_in:
            fields = line.strip().split('\t')
            genome = fields[0].split('.')[0]
            if fields[1] == '0':
                result[genome] = 'MAG'
            elif int(fields[1]) > 0:
                result[genome] = 'Isolate'
            else:
                logging.error('Genome {} was not found in the extra weight table'.format(genome))
                result[genome] = ''
    df['Genome_type'] = df['Genome'].map(result)
    return df


def load_genome_list(genomes_dir):
    genome_list = [filename.split('.')[0] for filename in os.listdir(genomes_dir)]
    return sorted(genome_list)


def parse_args():
    parser = argparse.ArgumentParser(description='Creates a metadata table for all new genomes to be added '
                                                 'to the catalog')
    parser.add_argument('-c', '--clusters-table',
                         help='A path to the table containing cluster information (clusters_split.txt)')
    parser.add_argument('-e', '--extra-weight-table',
                        help='Path to the extra weight table')
    parser.add_argument('-n', '--naming-table',
                        help='Path to the names.tsv file. The file should be tab delimited with first column '
                             'containing the original accession and the second column contatming the assigned '
                             'accession')
    parser.add_argument('-o', '--outfile', required=True,
                         help='Path to the output file where the metadata table will be stored')
    parser.add_argument('-d', '--genomes-dir', required=True,
                         help='A space delimited list of paths to the directory where genomes are stored')
    parser.add_argument('-r', '--rna-results', required=True,
                         help='Path to the folder with the RNA detection results (rRNA_outs)')
    parser.add_argument('--checkm-results', required=True,
                         help='Path to the file containing checkM results')
    parser.add_argument('--geo', required=True,
                         help='Path to the countries and continents file (continent_countries.csv from'
                              'https://raw.githubusercontent.com/dbouquin/IS_608/master/NanosatDB_munging/Countries-Continents.csv)')
    parser.add_argument('--taxonomy', required=True,
                        help='Path to the file generated by GTDB-tk (parser.add_argument(gtdbtk.bac120.summary.tsv)')
    parser.add_argument('--ftp-name', required=True,
                        help='The name of the FTP folder containing the catalog')
    parser.add_argument('--ftp-version', required=True,
                        help='Catalog version for the ftp (for example, v1.0')
    # parser.add_argument('--update', action='store_true',
    #                     help='Specify this flag if generating a metadata table for results that were not generated by '
    #                          'the genomes pipeline')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.genomes_dir, args.extra_weight_table, args.checkm_results, args.rna_results, args.naming_table,
         args.clusters_table, args.taxonomy, args.geo, args.outfile, args.ftp_name, args.ftp_version)
