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
import shutil

from parse_domain import load_clusters

logging.basicConfig(level=logging.INFO)


def main(cluster_split_file, new_strain_file, mash_result, previous_drep_dir, output_prefix, assembly_stats_file, 
         isolates_file, checkm_file, remove_list_file):
    # The script is currently only intended for genome reannotation. 
    # Commented out sections are WIP for genome removal/addition
    
    new_strain_list = load_first_column_to_list(new_strain_file)
    isolates = load_isolates(isolates_file)
    remove_list = load_first_column_to_list(remove_list_file)
    # qs_values = load_qs(assembly_stats_file)  # rewrite to load checkm from a separate file
    
    
    # if new strain list is empty and remove list is empty, we don't need to do anything, just output old files for 
    # everything - this is not an update, just a reannotation
    if len(new_strain_list) == 0 and len(remove_list) == 0:
        output_existing_drep_tables(previous_drep_dir, cluster_split_file, output_prefix)
    #else:
    #    if len(remove_list) > 0:
    #        remove_genomes_from_clusters(previous_drep_dir, cluster_split_file, remove_list)
    
    # when reassigning rep to a cluster that had the existing rep completely removed, don't stick with the 10% increase rule
    # assign the best genome there is
    # add existing strains to this
    # previous code to change to handle clusters
    #current_list = os.listdir(current_representatives_dir)
    #clusters_outfile = outfile.replace(outfile_extension, 'clusters.{}'.format(outfile_extension))
    #clusters = get_mash_clusters(mash_result, current_list, new_strain_list)
    
    #replace_results = replacement_decision(clusters, qs_values, isolates)
    #save_clusters_to_file(clusters, replace_results, clusters_outfile)
    #with open(outfile, 'w') as outfile_out:
    #    for key, value in replace_results.items():
    #        outfile_out.write('\t'.join([key, value]) + '\n')    


def remove_genomes_from_clusters(previous_drep_dir, cluster_split_file, remove_list):
    clusters = load_clusters(cluster_split_file)
    # singletons are saved as key=rep, value=""; for non-singletons value=list of members
    
    singletons_removed, cluster_rep_removed, cluster_member_removed = identify_genome_cluster_position(clusters, 
                                                                                                       remove_list)
    

def identify_genome_cluster_position(clusters, remove_list):
    singletons_removed = list()
    cluster_rep_removed = list()
    cluster_member_removed = dict()

    # generate a reverse dictionary where keys are non-reps and values are their corresponding reps
    reverse_lookup_nonreps = dict()
    for species_rep, members in clusters.items():
        if isinstance(members, list):
            for acc in members:
                reverse_lookup_nonreps[acc] = species_rep
    print(reverse_lookup_nonreps)
    return singletons_removed, cluster_rep_removed, cluster_member_removed
    
    
def output_existing_drep_tables(previous_drep_dir, cluster_split_file, output_prefix):
    drep_files = os.listdir(previous_drep_dir)
    for file in drep_files:
        new_filename = f"{output_prefix}_{file}"
        shutil.copy(os.path.join(previous_drep_dir, file), new_filename)
    updated_cluster_split_file = f"{output_prefix}_{os.path.basename(cluster_split_file)}"
    shutil.copy(cluster_split_file, updated_cluster_split_file)
    logging.info("No changes made to the clusters. Original file contents are written to output.")
    
    
def load_first_column_to_list(file_path):
    first_column_values = []
    with open(file_path, 'r') as file_in:
        for line in file_in:
            columns = line.strip().split('\t')
            if columns:  # line is not empty
                first_column_values.append(columns[0])
    return first_column_values
    

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


def load_isolates(isolates_file):
    isolates = set()
    with open(isolates_file, 'r') as isolates_in:
        for line in isolates_in:
            genome, score = line.strip().split()[0:2:1]
            if int(score) > 0:
                isolates.add(genome)
    return isolates


def load_qs(qs_file):
    checkm_values = dict()
    with open(qs_file, 'r') as checkm_in:
        for line in checkm_in:
            if line.lower().startswith('genome'):
                pass
            else:
                genome, completeness, contamination, n50 = line.strip().split("\t")[0:5:1]
                checkm_values[genome] = calc_qs(completeness, contamination, n50)
    return checkm_values


def calc_qs(completeness, contamination, n50):
    qs = float(completeness) - float(contamination) * 5 + 0.5 * float(n50)
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
            # the actual similarity interval we need to place a strain into its cluster is between 0.05 and 0.001
            # the interval below is extended because mash is not sufficiently accurate. It might have had a match
            # with a genome that is not a species rep that was within the interval while its match with the
            # species rep falls outside the interval
            if species_rep in current_list and genome in new_strain_list and 0.1 >= float(score) >= 0.0001:
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
    logging.info("------------------> Final cluster placement <--------------------")
    logging.info("New strain\tAssigned cluster\tDistance from current species rep")
    for genome in cluster_filter.keys():
        logging.info("{}\t{}\t{}".format(genome, cluster_filter[genome]['match'], cluster_filter[genome]['score']))
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
    parser.add_argument('--cluster-split-file', required=True,
                        help='Path to the cluster split file from the previous version of the catalogue')
    parser.add_argument('--new-strain-list', required=False,
                        help='Path to the file containing a list of new strains')
    parser.add_argument('-m', '--mash-result', required=False,
                        help='Path to the mash results file')
    parser.add_argument('--previous-drep-dir', required=False,
                        help='Path to the drep_data_tables folder for the previous catalogues')
    parser.add_argument('-o', '--output-prefix', required=True,
                        help='Prefix to use for the output files')
    parser.add_argument('--assembly-stats', required=True,
                        help='Path to the file containing completeness, contamination and N50 values for all '
                             'genomes (old and new)')
    parser.add_argument('--isolates', required=True,
                        help='Path to the extra weight file used for drep; the file format is tab delimited,'
                             'first column = genome file name; second column = 0 if not isolate, 1000 if'
                             'isolate')
    parser.add_argument('--checkm', required=True,
                        help='Path to the CheckM2 CSV file for all genomes (old and new)')
    parser.add_argument('--remove-list', required=False,
                        help='Path to the tab-delimited file containing a list of genomes (MGYG) to remove in column 1')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.cluster_split_file, args.new_strain_list, args.mash_result, args.previous_drep_dir, args.output_prefix, 
         args.assembly_stats, args.isolates, args.checkm, args.remove_list)
    