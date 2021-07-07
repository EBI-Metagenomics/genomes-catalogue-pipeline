#!/usr/bin/env python3
# coding=utf-8

import argparse
import logging
import os
import shutil

logging.basicConfig(level=logging.INFO)


def main(new_strain_dir, current_representatives_dir, mash_result, checkm_result, isolates_file, outfile, replace):
    for directory in [new_strain_dir, current_representatives_dir]:
        assert(os.path.exists(directory)), 'Directory {} does not exist'.format(directory)
    current_list = os.listdir(current_representatives_dir)
    new_strain_list = os.listdir(new_strain_dir)
    outfile_extension = outfile.split('.')[-1]
    clusters_outfile = outfile.replace(outfile_extension, 'clusters.{}'.format(outfile_extension))
    clusters = get_mash_clusters(mash_result, current_list, new_strain_list)
    isolates = load_isolates(isolates_file)
    qs_values = load_qs(checkm_result)
    replace_results = replacement_decision(clusters, qs_values, isolates)
    save_clusters_to_file(clusters, replace_results, clusters_outfile)
    with open(outfile, 'w') as outfile_out:
        for key, value in replace_results.items():
            outfile_out.write('\t'.join([key, value]) + '\n')
    if replace:
        make_replacements(replace_results, current_representatives_dir, new_strain_dir)


def replacement_decision(clusters, qs_values, isolates):
    replace_results = dict()
    replaced_with_isolates = 0
    replaced_with_better_qs = 0
    for representative in clusters.keys():
        logging.info('##### EVALUATING {}'.format(representative))
        isolate_representative = False
        if representative in isolates:
            logging.info('{} is an isolate, QS {}'.format(representative, qs_values[representative]))
            isolate_representative = True
        substitute_genome = ''
        substitute_score = 0.0
        isolate_score = 0.0
        score_to_beat = float(qs_values[representative]) * 1.1
        for candidate in clusters[representative]:
            if candidate in isolates:
                logging.info('{} is a candidate and an isolate, QS {}'.format(candidate, float(qs_values[candidate])))
                if isolate_representative:
                    if float(qs_values[candidate]) > isolate_score and float(qs_values[candidate]) > score_to_beat:
                        substitute_genome = candidate
                        isolate_score = float(qs_values[candidate])
                elif float(qs_values[candidate]) > isolate_score:
                    substitute_genome = candidate
                    isolate_score = float(qs_values[candidate])
            else:
                if isolate_representative:
                    pass
                else:
                    logging.info('Evaluating {}, {}; score to beat is {}'.format(
                        candidate, qs_values[candidate], score_to_beat))
                    if float(qs_values[candidate]) > score_to_beat and float(qs_values[candidate]) > substitute_score \
                            and isolate_score == 0.0:
                        logging.info('Score is beat {} {}'.format(qs_values[candidate], candidate))
                        substitute_genome = candidate
                        substitute_score = float(qs_values[candidate])
        if substitute_genome:
            logging.info('Replacing {} with {}'.format(representative, substitute_genome))
            replace_results[representative] = substitute_genome
            if isolate_score > 0:
                replaced_with_isolates += 1
            else:
                replaced_with_better_qs += 1
    logging.info('Number of genomes replaced with an isolate: {}'.format(replaced_with_isolates))
    logging.info('Number of genomes replaced with a MAG with better qs: {}'.format(replaced_with_better_qs))
    return replace_results


def make_replacements(replace_results, current_representatives_dir, new_strain_dir):
    for key, value in replace_results.items():
        old = os.path.join(current_representatives_dir, key)
        new = os.path.join(new_strain_dir, value)
        logging.info('Replacing {} with {}'.format(old, new))
        try:
            shutil.copy(new, current_representatives_dir)
        except IOError as e:
            logging.error('Unable to copy file {}: {}'.format(new, e))

        if os.path.isfile(old):
            try:
                os.remove(old)
            except OSError as e:
                logging.error('Unable to delete {}: {}'.format(old, e))
        else:
            logging.error('Cannot remove file {}. File does not exist'.format(old))


def load_isolates(isolates_file):
    isolates = set()
    with open(isolates_file, 'r') as isolates_in:
        for line in isolates_in:
            genome, score = line.strip().split()[0:2:1]
            if int(score) > 0:
                isolates.add(genome)
    return isolates


def load_qs(checkm_result):
    checkm_values = dict()
    with open(checkm_result, 'r') as checkm_in:
        for line in checkm_in:
            if line.startswith('genome'):
                pass
            else:
                genome, completeness, contamination = line.strip().split(',')[0:4:1]
                checkm_values[genome] = calc_qs(completeness, contamination)
    return checkm_values


def calc_qs(completeness, contamination):
    qs = float(completeness) - float(contamination) * 5
    return qs


def get_mash_clusters(mash_result, current_list, new_strain_list):
    clusters = dict()
    cluster_filter = dict()  # used to sort out situations when the same genome is in multiple clusters
    with open(mash_result, 'r') as mash_in:
        for line in mash_in:
            if line == "\n":
                break
            genome = line.strip().split()[1].split('/')[-1]
            species_rep = line.strip().split()[0].split('/')[-1]
            score = line.strip().split()[2]
            if species_rep in current_list and genome in new_strain_list and 0.05 >= float(score) >= 0.001:
                if genome not in cluster_filter:
                    clusters.setdefault(species_rep, []).append(genome)
                    cluster_filter.setdefault(genome, dict())
                    cluster_filter[genome]['match'] = species_rep
                    cluster_filter[genome]['score'] = float(score)
                else:
                    if float(score) < cluster_filter[genome]['score']:
                        logging.info('Removing genome {} from {}. New score is {}'.format(
                            genome, cluster_filter[genome]['match'], float(score)))
                        clusters[cluster_filter[genome]['match']].remove(genome)
                        clusters.setdefault(species_rep, []).append(genome)
                        cluster_filter[genome]['match'] = species_rep
                        cluster_filter[genome]['score'] = float(score)
                        logging.info('Reassigned genome {} to {}'.format(genome, cluster_filter[genome]['match']))
    return clusters


def save_clusters_to_file(clusters, replace_results, clusters_outfile):
    with open(clusters_outfile, 'w') as clusters_out:
        for key in clusters:
            if key in replace_results:
                rep = replace_results[key]
            else:
                rep = key
            for g in clusters[key]:
                if g == rep:
                    clusters_out.write('\t'.join([rep, key]) + '\n')
                else:
                    clusters_out.write('\t'.join([rep, g]) + '\n')


def parse_args():
    parser = argparse.ArgumentParser(description='Checks if the species representative should be replaced')
    parser.add_argument('-d', '--new-strain-directory', required=True,
                        help='Path to the directory containing new strains to be added to the catalog')
    parser.add_argument('-c', '--current-representatives', required=True,
                        help='Path to the directory containing the current species representatives')
    parser.add_argument('-m', '--mash-result', required=True,
                        help='Path to the mash results file')
    parser.add_argument('-o', '--outfile', required=True,
                        help='Path to the output file')
    parser.add_argument('--checkm-result', required=True,
                        help='Path to the checkm results file for all species that will be analyzed')
    parser.add_argument('--isolates', required=True,
                        help='Path to the extra weight file used for drep; the file format is tab delimited,'
                             'first column = genome file name; second column = 0 if not isolate, 1000 if'
                             'isolate')
    parser.add_argument('--replace', action='store_true',
                        help='If the flag is on, the species representatives in the folder will be replaced with'
                             'new representative genomes where necessary. Otherwise, only a table with results'
                             'will be printed')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.new_strain_directory, args.current_representatives, args.mash_result, args.checkm_result,
         args.isolates, args.outfile, args.replace)