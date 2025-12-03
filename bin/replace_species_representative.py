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
import csv
import glob
import logging
import math
import os
import shutil

from dataclasses import dataclass

from parse_domain import load_clusters

logging.basicConfig(level=logging.INFO)


@dataclass
class Placement:
    closest_rep: str
    distance: float
    actual_match: str
    
    
@dataclass
class Quality:
    completeness: float
    contamination: float
    n50: int
    qs: float
    length: int
    n_contigs: int
    
    
def main(cluster_split_file, new_strain_file, repeat_strain_file, previous_drep_dir, output_prefix, assembly_stats_file, 
         isolates_file, checkm_file, remove_list_file):
    
    new_strain_placement = load_strain_placement(new_strain_file, same_strain=False)  # strain_acc → Placement
    repeat_strain_placement = load_strain_placement(repeat_strain_file, same_strain=True)  # strain_acc → Placement
    remove_list = load_first_column_to_list(remove_list_file)
    
    # If we are not adding or removing genomes, we don't need to do anything, just output old files for 
    # everything - this is not an update, just a reannotation
    if not (new_strain_placement or remove_list or repeat_strain_placement):  # TODO: add new species here too
        output_existing_drep_tables(previous_drep_dir, cluster_split_file, output_prefix)
        return
    
    isolates = load_isolates(isolates_file)  # all isolates (old and new)
    qs_values = load_qs(assembly_stats_file, checkm_file)  # genome → Quality
    current_clusters = load_clusters(cluster_split_file)  # species_rep → [list of non-reps]
    current_clusters_minus_removed, remove_log = remove_genomes_from_clusters(current_clusters, remove_list)
    rep_lookup_dict = invert_clusters(current_clusters)  # any_catalogue_genome → its_species_rep
    
    replacement_results = recompute_clusters(current_clusters, qs_values, isolates, current_clusters_minus_removed, 
                                             new_strain_placement, repeat_strain_placement, rep_lookup_dict)

    
    # when reassigning rep to a cluster that had the existing rep completely removed, don't stick with the 10% increase rule
    # assign the best genome there is
    # add existing strains to this
    # previous code to change to handle clusters

    #clusters_outfile = outfile.replace(outfile_extension, 'clusters.{}'.format(outfile_extension))
    # The script goes over the mash results again to identify which species rep the genome fits in best
    # This is done because dRep uses centrality when choosing the species rep; if a new strain is close to a strain 
    # if might not necessarily be best placed with the species rep of that strain
    
    #replace_results = replacement_decision_old(clusters, qs_values, isolates)
    #save_clusters_to_file(clusters, replace_results, clusters_outfile)
    #with open(outfile, 'w') as outfile_out:
    #    for key, value in replace_results.items():
    #        outfile_out.write('\t'.join([key, value]) + '\n')    


def recompute_clusters(current_clusters, qs_values, isolates, current_clusters_minus_removed, new_strain_placement, 
                         repeat_strain_placement, rep_lookup_dict):
    replacement_results = dict()
    added_genomes = dict()  # cluster_rep → [list of added genomes]
    
    # Step 1: add in repeat strains
    # We will only consider adding a repeat strain in the following cases:
    # 1. if it's an isolate and existing strain is not (always add)
    # 2. if new genome is better quality (according to our threshold)
    for genome, placement in repeat_strain_placement.items():
        genome_is_isolate = genome in isolates
        catalogue_match_is_isolate = placement.actual_match in isolates
        if genome_is_isolate and not catalogue_match_is_isolate:
            # Case 1: genome is an isolate, catalogue match is not → add
            #add_to_clusters(genome)
            added_genomes.setdefault(placement.closest_rep, []).append(genome)
            pass  # Todo: implement actual addition
        else:
            # Case 2: add if quality is sufficiently higher
            if evaluate_quality_increase(qs_values[genome], qs_values[placement.actual_match]):
                #add_to_clusters(genome)
                added_genomes.setdefault(placement.closest_rep, []).append(genome)
                pass
            
    # Step 2: add all new strains into the clusters
    for genome, placement in new_strain_placement.items():
        # add_to_clusters(genome)
        added_genomes.setdefault(placement.closest_rep, []).append(genome)
        pass
    
    # Step 3: decide on rep replacement
    replacement_results = replacement_decision(replacement_results, added_genomes, qs_values)
    
    return replacement_results


def replacement_decision(replacement_results, added_genomes, qs_values):
    for old_rep, new_genome_list in added_genomes.items():
        # Check if there is no rep at all because if was removed - in that case we must select new rep
        if not replacement_results[old_rep]["new_rep"]:
            new_rep = select_replacement(replacement_results, old_rep, new_genome_list, qs_values, 
                                         replacement_required=True)
        else:
            new_rep = select_replacement(replacement_results, old_rep, new_genome_list, qs_values,
                                         replacement_required=False)
        replacement_results[old_rep]["new_rep"] = new_rep
    # Go through clusters that lost species rep due to genome removal but had no new genomes added
    for old_rep in replacement_results:
        if old_rep not in added_genomes and not replacement_results[old_rep]["new_rep"]:
            new_rep = select_replacement(replacement_results, old_rep, [], qs_values,
                                         replacement_required=True)            
    return replacement_results


def select_replacement(replacement_results, old_rep, new_genome_list, qs_values, replacement_required=False):
    """
    Choose a replacement genome for old_rep.

    If replacement_required = True:
        - Look at replacement_results[old_rep]["genome_list"]
        - Choose genome with highest QS
        - Break ties using highest N50

    If replacement_required = False:
        - Look at new_genome_list
        - Use evaluate_quality_increase() to see if any genome is sufficiently better
        - Among genomes that pass, choose the one with:
              1. highest QS
              2. break ties with highest N50
        - If none pass, return "" (no replacement)
    """
    old_quality = qs_values[old_rep]

    # Determine candidate pool
    replacement_pool = (
        replacement_results[old_rep]["genome_list"]
        if replacement_required else
        new_genome_list
    )

    # CASE 1: replacement required → pick best by QS, then N50
    if replacement_required:
        return max(
            replacement_pool,
            key=lambda g: (qs_values[g].qs, qs_values[g].n50)
        )

    # CASE 2: replacement only if there is a better genome → filter by quality improvement first
    passing = [
        genome for genome in replacement_pool
        if evaluate_quality_increase(qs_values[genome], old_quality)
    ]

    # If no passing candidates → no replacement
    if not passing:
        return ""

    # Pick best passing genome
    return max(
        passing,
        key=lambda g: (qs_values[g].qs, qs_values[g].n50)
    )


def evaluate_quality_increase(quality_new_genome, quality_catalogue_genome):
    threshold = quality_catalogue_genome.qs * 1.1
    if threshold <= 100.0:
        return quality_new_genome.qs >= threshold
    else:
        return new_genome_more_contiguous(quality_new_genome, quality_catalogue_genome)


def new_genome_more_contiguous(new, old):
    # The logic is:
    # do not make completeness and contamination worse
    # n50 should increase not only in percentage but also in absolute value (to avoid minor increases of low n50s)
    # tolerate some total length loss
    return (
        new.qs >= old.qs and
        new.completeness >= old.completeness and
        new.contamination <= old.contamination and
        new.n50 >= old.n50 + 10000 and
        new.n50 >= old.n50 * 1.1 and
        new.length >= old.length * 0.90
    )
    

def invert_clusters(clusters):
    rep_lookup_dict = dict()
    for rep, genome_list in clusters.items():
        rep_lookup_dict[rep] = rep
        for genome in genome_list:
            rep_lookup_dict[genome] = rep
    return rep_lookup_dict
    

def remove_genomes_from_clusters(current_clusters, remove_list):
    current_clusters_minus_removed = dict()
    remove_log = {"reps": [], "members": []} 
    for rep, genome_list in current_clusters.items():
        filtered_genomes = [g for g in genome_list if g not in remove_list]
        removed_genomes = [g for g in genome_list if g in remove_list]
        current_clusters_minus_removed[rep] = {
            "new_rep": "" if rep in remove_list else rep,
            "genome_list": filtered_genomes
        }
        if rep in remove_list:
            # Log removed species rep
            remove_log["reps"].append(rep)
        remove_log["members"].extend(removed_genomes)

    return current_clusters_minus_removed, remove_log
    

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
    all_paths = glob.glob(os.path.join(previous_drep_dir, '**', '*'), recursive=True)
    drep_files = [f for f in all_paths if os.path.isfile(f)]
    for file in drep_files:
        new_filename = f"{output_prefix}_{os.path.basename(file)}"
        shutil.copy(file, new_filename)
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


def load_strain_placement(file_path, same_strain=False):
    strain_placement: dict[str, Placement] = {}
    # If we are loading repeat genomes from the same strain, we put them in the same cluster as their match
    # regardless of how well they matched to the species rep of that cluster
    # If it's a new strain, we load it into the closest species rep even if the distance to that rep is > 0.05
    rep_col = "Hit_rep" if same_strain else "Closest_rep"
    score_col = "Score_to_hit_rep" if same_strain else "Score_to_closest_rep"
    with open(file_path, 'r') as file_in:
        reader = csv.DictReader(file_in, delimiter="\t")
        required_fields = {"Accession", rep_col, score_col}
        missing = required_fields - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Missing required header(s): {', '.join(missing)}")
        for row in reader:
            accession = row["Accession"]
            nearest_hit = row["Nearest_hit"]
            closest_rep = row[rep_col]
            distance = float(row[score_col])

            strain_placement[accession] = Placement(
                closest_rep=closest_rep,
                distance=distance,
                actual_match=nearest_hit,
            )
    return strain_placement
    

def replacement_decision_old(clusters, qs_values, isolates, current_clusters_minus_removed):
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


def load_qs(stats_file, checkm_file):
    # Load CheckM values
    genome_stats: dict[str, Quality] = {}
    with open(checkm_file, "r") as f:
        # genome,completeness,contamination
        # MGYG000518600.fna,99.99,0.23
        reader = csv.DictReader(f)
        for row in reader:
            genome = os.path.splitext(row["genome"])[0]
            genome_stats[genome] = Quality(
                completeness=float(row["completeness"]),
                contamination=float(row["contamination"]),
                n50=0,  # placeholder, will fill later
                qs=0.0,  # placeholder, will calculate later
                length=0, # placeholder, will calculate later
                n_contigs=0 # placeholder, will calculate later
            )
            
    # Load N50        
    with open(stats_file, "r") as f:
        # Genome	N50	Length	GC_content	N_contigs
        # MGYG000518600	165301	5147576	37.85	66
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            genome = row["Genome"]
            if genome not in genome_stats:
                # If CheckM data missing, create with placeholders
                genome_stats[genome] = Quality(completeness=0.0, contamination=0.0, n50=0, qs=0.0, length=0, 
                                               n_contigs=0)
            genome_stats[genome].n50 = int(row["N50"])
            genome_stats[genome].length = int(row["Length"])
            genome_stats[genome].n_contigs = int(row["N_contigs"])

    for genome, q in genome_stats.items():
        q.qs = calc_qs(q.completeness, q.contamination, q.n50)
    return genome_stats


def calc_qs(completeness, contamination, n50):
    qs = float(completeness) - float(contamination) * 5 + 0.5 * math.log(float(n50))
    return qs


def get_mash_clusters(mash_result, current_species_rep_list, new_strain_list):
    new_strain_mash_clusters = dict()
    cluster_filter = dict()  # used to sort out situations when the same genome is in multiple clusters
    with open(mash_result, 'r') as mash_in:
        for line in mash_in:
            if line == "\n":
                break
            catalogue_genome, query_genome_path, score, _, _ = line.strip().split()
            query_genome = os.path.basename(query_genome_path)  # get just the genome file name
            score = float(score)

            # the actual similarity interval we need to place a strain into its cluster is between 0.05 and 0.001
            # the interval below is extended because mash is not sufficiently accurate. It might have had a match
            # with a genome that is not a species rep that was within the interval while its match with the
            # species rep falls outside the interval
            if (
                catalogue_genome in current_species_rep_list
                and query_genome in new_strain_list
                and 0.0001 <= score <= 0.1
            ):
                existing = cluster_filter.get(query_genome)
                # Case 1: query_genome is not yet assigned to any catalogue species rep genome
                if existing is None:
                    new_strain_mash_clusters.setdefault(catalogue_genome, []).append(query_genome)
                    cluster_filter[query_genome] = {
                        "match": catalogue_genome,
                        "score": score
                    }

                # Case 2: query_genome is assigned, but this score is better (smaller)
                elif score < existing["score"]:
                    old_match = existing["match"]

                    logging.info(
                        f"Removing genome {query_genome} from {old_match}. New score is {score}"
                    )

                    new_strain_mash_clusters[old_match].remove(query_genome)
                    new_strain_mash_clusters.setdefault(catalogue_genome, []).append(query_genome)

                    existing["match"] = catalogue_genome
                    existing["score"] = score

                    logging.info(
                        f"Reassigned genome {query_genome} to {catalogue_genome}"
                    )
    logging.info("------------------> Final cluster placement <--------------------")
    logging.info("New strain\tAssigned cluster\tDistance from current species rep")
    for genome in cluster_filter.keys():
        logging.info("{}\t{}\t{}".format(genome, cluster_filter[genome]['match'], cluster_filter[genome]['score']))
    return new_strain_mash_clusters


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
                        help='Path to the cluster split file from the previous version of the catalogue; it should '
                             'not contain any genomes that were filtered out of the catalogue')
    parser.add_argument('--new-strain-list', required=False,
                        help='Path to the file containing a list of new strains')
    parser.add_argument('--repeat-strain-list', required=False,
                        help='Path to the file containing a list of repeat strains')
    parser.add_argument('--previous-drep-dir', required=False,
                        help='Path to the drep_data_tables folder for the previous catalogues')
    parser.add_argument('-o', '--output-prefix', required=True,
                        help='Prefix to use for the output files')
    parser.add_argument('--assembly-stats', required=True,
                        help='Path to the file containing completeness, contamination and N50 values for all '
                             'genomes (old and new)')
    parser.add_argument('--isolates', required=True,
                        help='Path to the extra weight file used for drep for all genomes (old and new); '
                             'the file format is tab delimited, first column = genome file name; '
                             'second column = 0 if not isolate, 1000 if isolate')
    parser.add_argument('--checkm', required=True,
                        help='Path to the CheckM2 CSV file for all genomes (old and new)')
    parser.add_argument('--remove-list', required=False,
                        help='Path to the tab-delimited file containing a list of genomes (MGYG) to remove in column 1')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.cluster_split_file, args.new_strain_list, args.repeat_strain_list, args.previous_drep_dir, args.output_prefix, 
         args.assembly_stats, args.isolates, args.checkm, args.remove_list)
    