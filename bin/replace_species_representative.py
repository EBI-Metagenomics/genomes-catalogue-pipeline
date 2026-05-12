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
import copy
import csv
import logging
import math
import os
import shutil
import sys

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
    
    
def main(cluster_split_file, output_prefix, assembly_stats_file, isolates_file, checkm_file, remove_list_file, 
         new_species_split_file=None, new_strain_file=None, repeat_strain_file=None):
    report_output_file = f"{output_prefix}_cluster_rep_changes_report.tsv"
    clusters_output_file = f"{output_prefix}_clusters_split.txt"
    new_strain_placement = (
        load_strain_placement(new_strain_file, same_strain=False)  # strain_acc → Placement
        if new_strain_file else {}
    )

    repeat_strain_placement = (
        load_strain_placement(repeat_strain_file, same_strain=True)  # strain_acc → Placement
        if repeat_strain_file else {}
    )

    remove_list_raw = load_first_column_to_list(remove_list_file)
    remove_list = list(dict.fromkeys(remove_list_raw))  # deduplicate, preserve order 

    if len(remove_list) != len(remove_list_raw):
        logging.warning(f"Duplicate entries found in remove list and ignored: "
                        f"{[g for g in remove_list_raw if remove_list_raw.count(g) > 1]}")

    logging.info(f"Loaded data: {len(new_strain_placement)} new strains, {len(repeat_strain_placement)} repeat strains "
                 f"before evaluation, {len(remove_list)} genomes to remove.")
    
    # If we are not adding or removing genomes, we don't need to do anything, just output old files for 
    # everything - this is not an update, just a reannotation
    if not (new_strain_placement or remove_list or repeat_strain_placement or new_species_split_file):
        logging.info("No genomes are added or removed, printing old catalogue results and existing.")
        output_existing_drep_tables(cluster_split_file, clusters_output_file)
        write_report_tsv(dict(), report_output_file) 
        return
    
    logging.info("Evaluating changes...")
    isolates = load_isolates(isolates_file)  # all isolates (old and new)
    qs_values = load_qs(assembly_stats_file, checkm_file)  # genome → Quality
    current_clusters = load_clusters(cluster_split_file)  # species_rep → [list of non-reps]
    current_clusters_minus_removed, remove_log = remove_genomes_from_clusters(current_clusters, remove_list)
    rep_lookup_dict = invert_clusters(current_clusters)  # any_catalogue_genome → its_species_rep
    
    replacement_results, stats_to_print, report_to_print = recompute_clusters(qs_values, isolates, 
                                                                              current_clusters_minus_removed, 
                                                                              new_strain_placement, 
                                                                              repeat_strain_placement, rep_lookup_dict, 
                                                                              remove_list)

    sanity_check(replacement_results, remove_list, current_clusters, new_strain_placement, stats_to_print)
    write_report_tsv(report_to_print, report_output_file)
    write_cluster_split_file(replacement_results, clusters_output_file, new_species_split_file)


def write_cluster_split_file(replacement_results, output_file, new_species_split_file):
    counter = 0
    with open(output_file, "w") as f_out:
        # If there's an existing split file, copy it and get the last cluster number
        if new_species_split_file:
            with open(new_species_split_file, "r") as f_in:
                for line in f_in:
                    f_out.write(line)
                    # Extract cluster number from line like "one_genome:45_0:MGYG000518610.fa"
                    counter = int(line.strip().split(":")[1].split("_")[0])
        
        # Write recomputed clusters from replacement_results
        for old_rep, data in replacement_results.items():
            if data["new_rep"]:  # skips empty entries where species have been removed
                counter += 1
                genome_list = data["genome_list"]
                new_rep = data["new_rep"]
                cluster_size = "many_genomes" if len(genome_list) > 0 else "one_genome"
                genome_list_str = ",".join([f"{new_rep}.fa"] + [f"{genome}.fa" for genome in genome_list])
                line_to_print = f"{cluster_size}:{counter}_0:{genome_list_str}\n"
                f_out.write(line_to_print)
                

def write_report_tsv(report_dict, outfile):
    """
    Writes the report_to_print dictionary to a TSV.
    Only prints fields that exist in each entry (missing fields become blank).
    """

    # Define full set of expected keys in the desired order
    fieldnames = [
        "old_rep",
        "new_rep",
        "reason",
        "old_comp", "old_cont", "old_qs", "old_n50", "old_length",
        "new_comp", "new_cont", "new_qs", "new_n50", "new_length",
        "quality_improvement"
    ]

    with open(outfile, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()

        for genome_id, info in report_dict.items():
            row = {"old_rep": genome_id}
            # Add only existing fields; missing ones will be written as blanks
            for key in fieldnames[1:]:  # skip "id"
                if key in info:
                    row[key] = info[key]
            writer.writerow(row)
        
        
def recompute_clusters(qs_values, isolates, current_clusters_minus_removed, new_strain_placement, 
                       repeat_strain_placement, rep_lookup_dict, remove_list):
    replacement_results = copy.deepcopy(current_clusters_minus_removed)
    added_genomes = dict()  # cluster_rep → [list of added genomes]
    stats_to_print = dict()  # numbers of added strains and species
    report_to_print = dict()  # reasons for rep replacements
    repeat_strains_added = 0
    new_strains_added = 0
    # Step 1: add in repeat strains
    # We will only consider adding a repeat strain in the following cases:
    # 1. if it's an isolate and existing strain is not (always add)
    # 2. if new genome is better quality (according to our threshold)
    for genome, placement in repeat_strain_placement.items():
        genome_is_isolate = genome in isolates
        catalogue_match_is_isolate = placement.actual_match in isolates
        if genome_is_isolate and not catalogue_match_is_isolate:
            # Case 1: genome is an isolate, catalogue match is not → add
            replacement_results = add_to_clusters(genome, rep_lookup_dict[placement.actual_match], replacement_results)
            added_genomes.setdefault(rep_lookup_dict[placement.actual_match], []).append(genome)
            repeat_strains_added += 1
        else:
            # Case 2: add if quality is sufficiently higher
            if evaluate_quality_increase(qs_values[genome], qs_values[placement.actual_match]):
                replacement_results = add_to_clusters(genome, rep_lookup_dict[placement.actual_match], 
                                                      replacement_results)
                added_genomes.setdefault(rep_lookup_dict[placement.actual_match], []).append(genome)
                repeat_strains_added += 1
            
    # Step 2: add all new strains into the clusters
    for genome, placement in new_strain_placement.items():
        replacement_results = add_to_clusters(genome, placement.closest_rep, replacement_results)
        added_genomes.setdefault(placement.closest_rep, []).append(genome)
        new_strains_added += 1
    # Step 3: decide on rep replacement
    # TODO: add replacement for cases where no genomes were added or removed, but rep changed because of the 
    #  CheckM -> CheckM2 switch
    replacement_results, stats_to_print, report_to_print = replacement_decision(replacement_results, added_genomes, 
                                                                                qs_values, remove_list, stats_to_print, 
                                                                                report_to_print, isolates)
    
    stats_to_print["new_strains_added"] = new_strains_added
    stats_to_print["repeat_strains_added"] = repeat_strains_added
    
    # Step 4: record species that have been completely removed
    report_to_print = add_removed_species(report_to_print, replacement_results)
    
    return replacement_results, stats_to_print, report_to_print


def add_removed_species(report_to_print, replacement_results):
    for old_rep, replacement_data in replacement_results.items():
        if not replacement_results[old_rep]["new_rep"] and len(replacement_results[old_rep]["genome_list"]) == 0:
            report_to_print[old_rep] = {"reason": "Species removed from catalogue"}    
    return report_to_print


def add_to_clusters(genome, rep, replacement_results):
    replacement_results[rep]["genome_list"].append(genome)
    return replacement_results


def replacement_decision(replacement_results, added_genomes_dict, qs_values, remove_list, stats_to_print, report_to_print,
                         isolates):
    # ------------------------------------------------------------------
    # Helper: Build report entry for a replacement
    # ------------------------------------------------------------------
    def add_report_entry(old_rep, new_rep):
        if old_rep in remove_list:
            reason = "Previous species representative genome has been removed from the catalogue"
        elif old_rep not in isolates and new_rep in isolates:
            reason = "Replaced with an isolate"
        else:
            reason = "Replaced with a higher quality genome"

        report_to_print[old_rep] = {
            "new_rep": new_rep,
            "reason": reason,
            "old_comp": qs_values[old_rep].completeness,
            "old_cont": qs_values[old_rep].contamination,
            "old_qs": qs_values[old_rep].qs,
            "old_n50": qs_values[old_rep].n50,
            "old_length": qs_values[old_rep].length,
            "new_comp": qs_values[new_rep].completeness,
            "new_cont": qs_values[new_rep].contamination,
            "new_qs": qs_values[new_rep].qs,
            "new_n50": qs_values[new_rep].n50,
            "new_length": qs_values[new_rep].length,
            "quality_improvement": qs_values[new_rep].qs/qs_values[old_rep].qs
        }
        
    for old_rep, new_genome_list in added_genomes_dict.items():
        # Check if there is no rep at all because it was removed - in that case we must select new rep
        must_replace = not replacement_results[old_rep]["new_rep"]
        new_rep = select_replacement(replacement_results, old_rep, new_genome_list, qs_values, isolates, 
                                     replacement_required=must_replace)   

        if new_rep:
            replacement_results[old_rep]["new_rep"] = new_rep
            add_report_entry(old_rep, new_rep)
    
    # Go through clusters that lost species rep due to genome removal but had no new genomes added.
    # In such cases the old genome will not be in the list of keys of added_genomes_dict.
    for old_rep in replacement_results:
        if old_rep not in added_genomes_dict and not replacement_results[old_rep]["new_rep"]:
            new_rep = select_replacement(replacement_results, old_rep, [], qs_values, isolates, 
                                         replacement_required=True)
            if new_rep:
                replacement_results[old_rep]["new_rep"] = new_rep
                add_report_entry(old_rep, new_rep)
    # remove new_rep from genome lists, add in old_reps
    replacement_results = clean_up_result(replacement_results, remove_list)
    return replacement_results, stats_to_print, report_to_print
        

def clean_up_result(replacement_results, remove_list):
    for old_rep in replacement_results:
        new_rep = replacement_results[old_rep]["new_rep"]
        genome_list = replacement_results[old_rep]["genome_list"]

        # check that no new_rep assignment was missed (if there are genomes in the list, there must be a rep)
        if new_rep == "" and len(genome_list) > 0:
            sys.exit(
                f"Replacement of {old_rep} is none but genome list is not empty: {genome_list}."
            )

        # if old_rep was replaced, move it to the cluster member list
        if old_rep != new_rep:
            if new_rep and new_rep in genome_list:
                genome_list.remove(new_rep)  # the list should only contain members, not reps
            
            # Add the old rep to the genome list unless it needs to be removed from the catalogue
            if old_rep not in remove_list:
                genome_list.append(old_rep)

    return replacement_results


def select_replacement(replacement_results, old_rep, new_genome_list, qs_values, isolates, replacement_required=False):
    """
    Choose a replacement genome for old_rep.

    If replacement_required = True:
        - Look at replacement_results[old_rep]["genome_list"]
        - Choose genome with highest QS
        - Break ties using highest N50
        - If replacement_results[old_rep]["genome_list"] contains isolates, only choose among isolates

    If replacement_required = False:
        - Look at new_genome_list
        - If current rep is an isolate or there are any isolates in new_genome_list, only consider isolates as a
         replacement
        - Use evaluate_quality_increase() to see if any genome is sufficiently better
        - Among genomes that pass, choose the one with:
              1. highest QS
              2. break ties with highest N50
        - If none pass, return "" (no replacement)
    """
    old_quality = qs_values[old_rep]

    # ---------------------------------------------------------
    # STEP 1: Determine candidate genome pool to select a replacement species rep from (before isolate filtering)
    # ---------------------------------------------------------
    base_replacement_pool = (
        replacement_results[old_rep]["genome_list"]
        if replacement_required else
        new_genome_list
    )
    
    if not base_replacement_pool:
        return ""
    
    # ---------------------------------------------------------
    # STEP 2: Isolate-based filtering
    # ---------------------------------------------------------

    # Identify which members of the base pool are isolates
    replacement_pool_isolates = [g for g in base_replacement_pool if g in isolates]
    
    # If an isolate has been added and the old rep is not an isolate, replacement is required
    if replacement_pool_isolates and old_rep not in isolates:
        replacement_required = True
    
    if replacement_required:
        # If any isolates are present in the pool → only consider isolates
        if replacement_pool_isolates:
            candidate_pool = replacement_pool_isolates
        else:
            candidate_pool = base_replacement_pool

    else:
        # Replacement not required:
        # If old rep is an isolate OR pool contains isolates → restrict to isolates
        if (old_rep in isolates) or replacement_pool_isolates:
            candidate_pool = replacement_pool_isolates
        else:
            candidate_pool = base_replacement_pool

    if not candidate_pool:
        return ""

    # ---------------------------------------------------------
    # STEP 3a: replacement required → pick best by QS, then N50
    # ---------------------------------------------------------
    if replacement_required:
        return max(
            candidate_pool,
            key=lambda g: (qs_values[g].qs, qs_values[g].n50)
        )

    # ---------------------------------------------------------
    # STEP 3b: replacement_required=False → replacement only if there is a better genome → filter by quality 
    # improvement first
    # ---------------------------------------------------------
    passing = [
        genome for genome in candidate_pool
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
    
    
def output_existing_drep_tables(cluster_split_file, clusters_output_file):
    shutil.copy(cluster_split_file, clusters_output_file)
    logging.info("No changes made to the clusters. Original file contents are written to output.")


def load_first_column_to_list(file_path):
    first_column_values = []
    with open(file_path, 'r') as file_in:
        for line in file_in:
            columns = line.strip().split('\t')
            if not columns:
                continue

            value = columns[0]

            # Remove known extensions
            for ext in (".fa", ".fna", ".fasta"):
                if value.endswith(ext):
                    value = value[: -len(ext)]
                    break

            first_column_values.append(value)

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
        if not reader.fieldnames:
            return {}
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
                length=0,  # placeholder, will fill later
                n_contigs=0  # placeholder, will fill later
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
    qs = float(completeness) - float(contamination) * 5 + 0.5 * math.log10(float(n50))
    return qs


def sanity_check(replacement_results, remove_list, current_clusters, new_strain_placement, report_to_print):
    results_ok = True
    
    # Step 1: Count genomes in current_clusters (this is how many genomes we had in the old catalogue)
    current_genomes = set(current_clusters.keys())  # keys
    for genomes in current_clusters.values():  # genomes in lists
        current_genomes.update(genomes)

    total_current_genomes = len(current_genomes)

    # Step 2: Subtract genomes in remove_list and add new/repeat strains
    total_expected = (total_current_genomes - len(remove_list) + report_to_print["new_strains_added"] + 
                      report_to_print["repeat_strains_added"])

    # Step 3: Count genomes in replacement_results (ignore keys)
    seen_genomes = set()
    replacement_count = 0
    for rep in replacement_results.values():
        # Count new_rep if not None
        if rep["new_rep"]:
            if rep["new_rep"] in seen_genomes:
                logging.error(f"Genome {rep['new_rep']} appears more than once in replacement_results")
                results_ok = False
            seen_genomes.add(rep["new_rep"])
            replacement_count += 1
        # Count genomes in genome_list
        for g in rep["genome_list"]:
            if g in seen_genomes:
                logging.error(f"Genome {g} appears more than once in replacement_results")
                results_ok = False
            seen_genomes.add(g)
            replacement_count += 1

    # Step 4: Check that replacement_count equals at least the original count minus the number of removed genomes
    if replacement_count != total_expected:
        logging.error(f"Replacement results ({replacement_count}) do not match the expected number of genomes "
              f"({total_expected})")
        results_ok = False

    # Step 5: Ensure all genomes from new_strain_placement are in seen_genomes
    for genome in new_strain_placement.keys():
        if genome not in seen_genomes:
            print(f"Genome {genome} from new_strain_placement not found in replacement results")
            results_ok = False

    # Step 6: Exit if sanity check fails
    if not results_ok:
        sys.exit("Sanity check not passed")


def parse_args():
    parser = argparse.ArgumentParser(description='Checks if the species representative should be replaced')
    parser.add_argument('--cluster-split-file', required=True,
                        help='Path to the cluster split file from the previous version of the catalogue; it should '
                             'not contain any genomes that were filtered out of the catalogue')
    parser.add_argument('--new-strain-list', required=False,
                        help='Path to the file containing a list of new strains')
    parser.add_argument('--repeat-strain-list', required=False,
                        help='Path to the file containing a list of repeat strains')
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
    parser.add_argument('--new-species-split-file', required=False,
                        help='Path to the cluster split file for new species')
    args = parser.parse_args()

    # Validation
    optional_arguments = [
        args.new_species_split_file,
        args.new_strain_list,
        args.repeat_strain_list
    ]

    if any(optional_arguments) and not all(optional_arguments):
        parser.error(
            "Arguments --new-species-split-file, --new-strain-list, and --repeat-strain-list must be provided together"
        )

    return args


if __name__ == '__main__':
    args = parse_args()
    main(args.cluster_split_file, args.output_prefix, args.assembly_stats, args.isolates, args.checkm, 
         args.remove_list, args.new_species_split_file, args.new_strain_list, args.repeat_strain_list)
    