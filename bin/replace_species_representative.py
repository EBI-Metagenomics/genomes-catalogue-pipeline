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
from typing import Optional

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
    
    
def main(
    cluster_split_file: str,
    output_prefix: str,
    assembly_stats_file: str,
    isolates_file: str,
    checkm_file: str,
    remove_list_file: str,
    checkm2_switch: bool,
    new_species_split_file: Optional[str] = None,
    new_strain_file: Optional[str] = None,
    repeat_strain_file: Optional[str] = None,
) -> None:
    """
    Main entry point for updating species cluster representatives.

    Loads all input data, evaluates which genomes should be added or removed,
    recomputes cluster memberships and representative assignments, runs a sanity
    check, and writes the updated cluster split file and a report TSV.

    Args:
        cluster_split_file: Path to the cluster split file from the previous catalogue version.
        output_prefix: Prefix used for all output file names.
        assembly_stats_file: Path to the TSV file containing N50, length, %GC, N_contigs.
        isolates_file: Path to the isolates weight file (genome + weight columns).
        checkm_file: Path to the CheckM2 CSV file with completeness and contamination values.
        remove_list_file: Path to a tab-delimited file listing genomes to remove (column 1).
        checkm2_switch: If True, all clusters are reassessed because CheckM version changed.
        new_species_split_file: Path to the cluster split file for newly discovered species (optional).
        new_strain_file: Path to the file listing new strains and their closest species rep (optional).
        repeat_strain_file: Path to the file listing repeat strains and their catalogue match (optional).
    """
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
    
    # If we are not adding or removing genomes, and we didn't switch from CheckM1 to CheckM2, we don't need to do 
    # anything, just output old files for everything - this is not an update, just a reannotation
    if not (new_strain_placement or remove_list or repeat_strain_placement or new_species_split_file or checkm2_switch):
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
    
    replacement_results, stats_to_print, report_to_print, repeat_strains_discarded = recompute_clusters(
        qs_values, isolates, current_clusters_minus_removed, new_strain_placement, repeat_strain_placement, 
        rep_lookup_dict, remove_list, checkm2_switch)

    sanity_check(replacement_results, remove_list, current_clusters, new_strain_placement, stats_to_print)
    write_report_tsv(report_to_print, report_output_file)
    write_cluster_split_file(replacement_results, clusters_output_file, new_species_split_file)
    write_discarded_strains(repeat_strains_discarded, "discarded_repeat_strains.txt")


def write_discarded_strains(repeat_strains_discarded, outfile):
    with open(outfile, "w") as f_out:
        for strain in repeat_strains_discarded:
            f_out.write(strain + "\n")
            

def write_cluster_split_file(
    replacement_results: dict[str, dict],
    output_file: str,
    new_species_split_file: Optional[str],
) -> None:
    """
    Write the updated cluster split file, prepending new-species entries if present.

    Each line follows the format:
        <cluster_size>:<counter>_0:<rep>.fa,<member1>.fa,...

    If a new-species split file is provided, its lines are written first and the
    counter is initialised from the last cluster number found there.

    Args:
        replacement_results: Mapping of old representative genome ID to a dict with
            keys ``new_rep`` (str) and ``genome_list`` (list[str]).
        output_file: Destination path for the cluster split file.
        new_species_split_file: Optional path to an existing split file for new species
            whose lines should be prepended.
    """
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
                

def write_report_tsv(report_dict: dict[str, dict], outfile: str) -> None:
    """
    Write the replacement report to a TSV file.

    Only fields that exist in each entry are written; missing fields are left blank.
    The column order is fixed regardless of which fields are present in any given row.

    Args:
        report_dict: Mapping of genome ID to a dict of report fields such as
            ``new_rep``, ``reason``, quality metrics, and ``quality_improvement``.
        outfile: Destination path for the TSV report file.
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
        
        
def recompute_clusters(
    qs_values: dict[str, Quality],
    isolates: set[str],
    current_clusters_minus_removed: dict[str, dict],
    new_strain_placement: dict[str, Placement],
    repeat_strain_placement: dict[str, Placement],
    rep_lookup_dict: dict[str, str],
    remove_list: list[str],
    checkm2_switch: bool,
) -> tuple[dict[str, dict], dict[str, int], dict[str, dict]]:
    """
    Add new and repeat strains to clusters and decide on representative replacements.

    Proceeds in four steps:
        1. Conditionally add repeat strains (isolate priority or quality improvement).
        2. Unconditionally add all new strains.
        3. Run representative-replacement logic across all affected clusters.
        4. Record species that have been completely removed.

    Args:
        qs_values: Mapping of genome ID to its Quality metrics.
        isolates: Set of genome IDs that are isolates.
        current_clusters_minus_removed: Clusters after genomes on the remove list have
            been stripped out; maps old rep → ``{new_rep, genome_list}``.
        new_strain_placement: Mapping of new-strain genome ID to its Placement.
        repeat_strain_placement: Mapping of repeat-strain genome ID to its Placement.
        rep_lookup_dict: Mapping of any catalogue genome ID to its species representative.
        remove_list: List of genome IDs to be removed from the catalogue.
        checkm2_switch: If True, all clusters are re-evaluated for representative change.

    Returns:
        A tuple of:
            - replacement_results: Updated cluster dict (old rep → ``{new_rep, genome_list}``).
            - stats_to_print: Counts of added new and repeat strains.
            - report_to_print: Per-representative report entries for the TSV output.
    """
    replacement_results = copy.deepcopy(current_clusters_minus_removed)
    added_genomes = dict()  # cluster_rep → [list of added genomes]
    stats_to_print = dict()  # numbers of added strains and species
    report_to_print = dict()  # reasons for rep replacements
    repeat_strains_added = 0
    new_strains_added = 0
    repeat_strains_discarded = list()
    
    # Step 1: add in repeat strains
    # We will only consider adding a repeat strain in the following cases:
    # 1. if it's an isolate and existing strain is not (always add)
    # 2. If the genome that was matched has been removed from the catalogue (always add)
    # 3. if new genome is better quality (according to our threshold)
    for genome, placement in repeat_strain_placement.items():
        matched_cluster = rep_lookup_dict[placement.actual_match]
        genome_is_isolate = genome in isolates
        matched_genome_was_removed = placement.actual_match in remove_list
        catalogue_match_is_isolate = placement.actual_match in isolates
        if (genome_is_isolate and not catalogue_match_is_isolate) or matched_genome_was_removed:
            # Case 1: genome is an isolate, catalogue match is not → add
            # Case 2: the matched genome has been removed from the catalogue → add
            replacement_results = add_to_clusters(genome, matched_cluster, replacement_results)
            added_genomes.setdefault(matched_cluster, []).append(genome)
            repeat_strains_added += 1
        else:
            # Case 3: add if quality is sufficiently higher
            if evaluate_quality_increase(qs_values[genome], qs_values[placement.actual_match]):
                replacement_results = add_to_clusters(genome, matched_cluster, 
                                                      replacement_results)
                added_genomes.setdefault(matched_cluster, []).append(genome)
                repeat_strains_added += 1
            else:
                repeat_strains_discarded.append(genome)
            
    # Step 2: add all new strains into the clusters
    for genome, placement in new_strain_placement.items():
        replacement_results = add_to_clusters(genome, placement.closest_rep, replacement_results)
        added_genomes.setdefault(placement.closest_rep, []).append(genome)
        new_strains_added += 1
    
    # Step 3: decide on rep replacement
    replacement_results, stats_to_print, report_to_print = replacement_decision(replacement_results, added_genomes, 
                                                                                qs_values, remove_list, stats_to_print, 
                                                                                report_to_print, isolates, 
                                                                                checkm2_switch)
    
    stats_to_print["new_strains_added"] = new_strains_added
    stats_to_print["repeat_strains_added"] = repeat_strains_added
    
    # Step 4: record species that have been completely removed
    report_to_print = add_removed_species(report_to_print, replacement_results)
    
    return replacement_results, stats_to_print, report_to_print, repeat_strains_discarded


def add_removed_species(
    report_to_print: dict[str, dict],
    replacement_results: dict[str, dict],
) -> dict[str, dict]:
    """
    Record species that have been entirely removed from the catalogue.

    A species is considered fully removed when its entry in ``replacement_results``
    has no new representative and an empty genome list.

    Args:
        report_to_print: Existing report dict that will be updated in place.
        replacement_results: Current cluster state mapping old rep → ``{new_rep, genome_list}``.

    Returns:
        The updated ``report_to_print`` dict with fully-removed species appended.
    """
    for old_rep, replacement_data in replacement_results.items():
        if not replacement_results[old_rep]["new_rep"] and len(replacement_results[old_rep]["genome_list"]) == 0:
            report_to_print[old_rep] = {"reason": "Species removed from catalogue"}    
    return report_to_print


def add_to_clusters(
    genome: str,
    rep: str,
    replacement_results: dict[str, dict],
) -> dict[str, dict]:
    """
    Append a genome to the member list of an existing cluster.

    Args:
        genome: Genome ID to add as a cluster member.
        rep: Species representative genome ID identifying the target cluster.
        replacement_results: Current cluster state mapping old rep → ``{new_rep, genome_list}``.

    Returns:
        The updated ``replacement_results`` dict with ``genome`` added to the
        ``genome_list`` of the cluster keyed by ``rep``.
    """
    replacement_results[rep]["genome_list"].append(genome)
    return replacement_results


def replacement_decision(
    replacement_results: dict[str, dict],
    added_genomes_dict: dict[str, list[str]],
    qs_values: dict[str, Quality],
    remove_list: list[str],
    stats_to_print: dict[str, int],
    report_to_print: dict[str, dict],
    isolates: set[str],
    checkm2_switch: bool,
) -> tuple[dict[str, dict], dict[str, int], dict[str, dict]]:
    """
    Decide whether each cluster's representative genome should be replaced.

    For each cluster, determines the pool of candidates to evaluate and calls
    ``select_replacement``. If a replacement is chosen, updates ``replacement_results``
    and appends an entry to ``report_to_print``. Finishes by calling
    ``clean_up_result`` to move old representatives into member lists.

    Args:
        replacement_results: Current cluster state mapping old rep → ``{new_rep, genome_list}``.
        added_genomes_dict: Mapping of species rep → list of genomes newly added to that cluster.
        qs_values: Mapping of genome ID to its Quality metrics.
        remove_list: List of genome IDs to be removed from the catalogue.
        stats_to_print: Running stats dict (updated in place but returned for clarity).
        report_to_print: Running report dict (updated in place).
        isolates: Set of genome IDs that are isolates.
        checkm2_switch: If True, all cluster members are considered as replacement candidates.

    Returns:
        A tuple of the (possibly mutated) ``replacement_results``, ``stats_to_print``,
        and ``report_to_print``.
    """

    # ------------------------------------------------------------------
    # Helper: Build report entry for a replacement
    # ------------------------------------------------------------------
    def add_report_entry(old_rep: str, new_rep: str) -> None:
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
            "quality_improvement": qs_values[new_rep].qs / qs_values[old_rep].qs
        }
        
    for old_rep in replacement_results:
        # Check if there is no rep at all because it was removed - in that case we must select a new rep
        must_replace = not replacement_results[old_rep]["new_rep"]
        # If in this catalogue we switched from CheckM1 to CheckM2 or if old rep was removed, we need to consider all 
        # genomes in the cluster for a possible new rep; in other cases, only consider clusters with new genomes added
        if checkm2_switch or must_replace:
            genome_list_to_evaluate = (
                    replacement_results[old_rep]["genome_list"] + added_genomes_dict.get(old_rep, []))
        else: 
            genome_list_to_evaluate = added_genomes_dict.get(old_rep, [])
        if genome_list_to_evaluate:
            new_rep = select_replacement(old_rep, genome_list_to_evaluate, qs_values, isolates,
                                         replacement_required=must_replace)

            if new_rep:
                replacement_results[old_rep]["new_rep"] = new_rep
                add_report_entry(old_rep, new_rep)
            
    replacement_results = clean_up_result(replacement_results, remove_list)
    return replacement_results, stats_to_print, report_to_print
        

def clean_up_result(
    replacement_results: dict[str, dict],
    remove_list: list[str],
) -> dict[str, dict]:
    """
    Finalise cluster membership after representative assignments have been made.

    For each cluster:
    - Exits with an error if a non-empty genome list has no assigned representative.
    - Removes the new representative from the member list (it should not appear there).
    - Moves the old representative into the member list unless it is on the remove list.

    Args:
        replacement_results: Current cluster state mapping old rep → ``{new_rep, genome_list}``.
        remove_list: List of genome IDs to be excluded from the catalogue entirely.

    Returns:
        The cleaned-up ``replacement_results`` dict.
    """
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


def select_replacement(
    old_rep: str,
    genome_list_to_evaluate: list[str],
    qs_values: dict[str, Quality],
    isolates: set[str],
    replacement_required: bool = False,
) -> str:
    """
    Choose the best replacement representative from a list of candidate genomes.

    If replacement_required is True:
        - Choose genome with highest QS
        - Break ties using highest N50
        - If replacement_results[old_rep]["genome_list"] contains isolates, only choose among isolates

    If replacement_required is False:
        - If current rep is an isolate or there are any isolates in genome_list_to_evaluate, only consider isolates as a
         replacement
        - Use evaluate_quality_increase() to see if any genome is sufficiently better
        - Among genomes that pass, choose the one with:
              1. highest QS
              2. break ties with highest N50
        - If none pass, return "" (no replacement)

    Args:
        old_rep: Genome ID of the current species representative.
        genome_list_to_evaluate: Candidate genome IDs to consider as replacements.
        qs_values: Mapping of genome ID to its Quality metrics.
        isolates: Set of genome IDs that are isolates.
        replacement_required: If True, a replacement must be chosen even if no candidate
            is strictly better quality than the current representative.

    Returns:
        The genome ID of the chosen replacement, or ``""`` if no suitable replacement
        was found.
    """
    old_quality = qs_values[old_rep]
    
    # ---------------------------------------------------------
    # STEP 1: Isolate-based filtering
    # ---------------------------------------------------------

    # Identify which members of the base pool are isolates
    replacement_pool_isolates = [g for g in genome_list_to_evaluate if g in isolates]
    
    # If an isolate has been added and the old rep is not an isolate, replacement is required
    if replacement_pool_isolates and old_rep not in isolates:
        replacement_required = True
    
    if replacement_required:
        # If any isolates are present in the pool → only consider isolates
        candidate_pool = replacement_pool_isolates or genome_list_to_evaluate

    else:
        # Replacement not required:
        # If old rep is an isolate OR pool contains isolates → restrict to isolates
        if (old_rep in isolates) or replacement_pool_isolates:
            candidate_pool = replacement_pool_isolates
        else:
            candidate_pool = genome_list_to_evaluate

    if not candidate_pool:
        return ""

    # ---------------------------------------------------------
    # STEP 2a: replacement required → pick best by QS, then N50
    # ---------------------------------------------------------
    if replacement_required:
        return max(
            candidate_pool,
            key=lambda g: (qs_values[g].qs, qs_values[g].n50)
        )

    # ---------------------------------------------------------
    # STEP 2b: replacement_required=False → replacement only if there is a better genome → filter by quality 
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


def evaluate_quality_increase(quality_new_genome: Quality, quality_catalogue_genome: Quality) -> bool:
    """
    Determine whether a new genome is sufficiently better than the catalogue genome.

    Uses a 10 % QS improvement threshold. When the threshold would exceed 100 (i.e.
    the catalogue genome already has a very high QS), falls back to the stricter
    contiguity-based check in ``new_genome_more_contiguous``.

    Args:
        quality_new_genome: Quality metrics for the candidate genome.
        quality_catalogue_genome: Quality metrics for the current catalogue genome.

    Returns:
        True if the new genome meets the improvement threshold, False otherwise.
    """
    threshold = quality_catalogue_genome.qs * 1.1
    if threshold <= 100.0:
        return quality_new_genome.qs >= threshold
    else:
        return new_genome_more_contiguous(quality_new_genome, quality_catalogue_genome)


def new_genome_more_contiguous(new: Quality, old: Quality) -> bool:
    """
    Check whether a new genome is strictly more contiguous than an existing one.

    Used as a fallback when both genomes already have very high QS scores (>100),
    where percentage-based QS improvement would be hard to achieve.

    # The logic is:
    # do not make completeness and contamination worse
    # n50 should increase not only in percentage but also in absolute value (to avoid minor increases of low n50s)
    # tolerate some total length loss
    # qs increase should be at least x1.001 to avoid tiny overall improvements (this looks small but at very high
    # quality values the qs change is small, for example:
    # old: comp=99.99, cont=0.08, n50=231,146, length=2,719,680, qs=102.2719
    # new: comp=100.00, cont=0.08, n50=414,451, length=2,724,065, qs=102.408
    # qs fold increase is only 1.0013 but n50 in the new genome is nearly double compared to the old genome)
    # These parameters do mean that at higher qs values we will be switching species rep more often

    Args:
        new: Quality metrics for the candidate genome.
        old: Quality metrics for the current catalogue genome.

    Returns:
        True if the new genome passes all contiguity and quality criteria, False otherwise.
    """
    return (
        new.qs >= old.qs and
        new.completeness >= old.completeness and
        new.contamination <= old.contamination and
        new.n50 >= old.n50 + 10000 and
        new.n50 >= old.n50 * 1.1 and
        new.length >= old.length * 0.90 and
        new.qs / old.qs >= 1.001
    )
    

def invert_clusters(clusters: dict[str, list[str]]) -> dict[str, str]:
    """
    Build a reverse lookup mapping every catalogue genome to its species representative.

    The representative itself is also included in the returned dict, mapped to itself.

    Args:
        clusters: Mapping of species representative genome ID → list of member genome IDs.

    Returns:
        A flat dict mapping every genome ID (rep or member) to its species representative.
    """
    rep_lookup_dict = dict()
    for rep, genome_list in clusters.items():
        rep_lookup_dict[rep] = rep
        for genome in genome_list:
            rep_lookup_dict[genome] = rep
    return rep_lookup_dict


def remove_genomes_from_clusters(
    current_clusters: dict[str, list[str]],
    remove_list: list[str],
) -> tuple[dict[str, dict], dict[str, list[str]]]:
    """
    Strip genomes on the remove list from all clusters.

    Produces an updated cluster dict where removed representatives are recorded
    with an empty ``new_rep`` string (signalling that a replacement must be found)
    and removed members are simply excluded from the ``genome_list``.

    Args:
        current_clusters: Mapping of species representative genome ID → list of member genome IDs.
        remove_list: List of genome IDs to be removed from the catalogue.

    Returns:
        A tuple of:
            - current_clusters_minus_removed: Updated clusters mapping old rep →
              ``{new_rep, genome_list}`` with removed genomes excluded.
            - remove_log: Dict with keys ``"reps"`` and ``"members"`` listing which
              representatives and members were removed respectively.
    """
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
    
    
def output_existing_drep_tables(cluster_split_file: str, clusters_output_file: str) -> None:
    """
    Copy the existing cluster split file to the output path without modification.

    Used when no genomes are being added or removed and no CheckM version switch
    occurred, so the catalogue content is unchanged (reannotation only).

    Args:
        cluster_split_file: Path to the source cluster split file.
        clusters_output_file: Destination path where the file should be copied.
    """
    shutil.copy(cluster_split_file, clusters_output_file)
    logging.info("No changes made to the clusters. Original file contents are written to output.")


def load_first_column_to_list(file_path: str) -> list[str]:
    """
    Read the first column of a tab-delimited file into a list of strings.

    Common genome file extensions (``.fa``, ``.fna``, ``.fasta``) are stripped from
    each value before it is added to the list.

    Args:
        file_path: Path to the input file.

    Returns:
        A list of values from the first column, in file order, with extensions removed.
    """
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


def load_strain_placement(file_path: str, same_strain: bool = False) -> dict[str, Placement]:
    """
    Parse a strain placement TSV into a dict mapping genome ID to Placement.

    The column names used for the representative and distance score differ depending
    on whether the file describes repeat strains (same strain) or new strains:
    - same_strain=True  → uses ``Hit_rep`` and ``Score_to_hit_rep``
    - same_strain=False → uses ``Closest_rep`` and ``Score_to_closest_rep``

    # If we are loading repeat genomes from the same strain, we put them in the same cluster as their match
    # regardless of how well they matched to the species rep of that cluster
    # If it's a new strain, we load it into the closest species rep even if the distance to that rep is > 0.05

    Args:
        file_path: Path to the placement TSV file.
        same_strain: If True, load as repeat-strain placements; otherwise as new-strain.

    Returns:
        A dict mapping each accession string to its corresponding Placement dataclass.

    Raises:
        ValueError: If required header columns are missing from the file.
    """
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


def load_isolates(isolates_file: str) -> set[str]:
    """
    Load the set of isolate genome IDs from the isolates weight file.

    Each line is expected to contain at least two whitespace-separated fields:
    a genome ID and an integer score. Genomes with a score greater than 0 are
    considered isolates.

    Args:
        isolates_file: Path to the isolates weight file.

    Returns:
        A set of genome IDs that are classified as isolates (score > 0).
    """
    isolates = set()
    with open(isolates_file, 'r') as isolates_in:
        for line in isolates_in:
            genome, score = line.strip().split()[0:2:1]
            for ext in (".fa", ".fna", ".fasta"):
                if genome.endswith(ext):
                    genome = genome[:-len(ext)]
                    break
            if int(score) > 0:
                isolates.add(genome)
    return isolates


def load_qs(stats_file: str, checkm_file: str) -> dict[str, Quality]:
    """
    Build a Quality metrics dict for all genomes from assembly stats and CheckM output.

    Reads completeness and contamination from the CheckM CSV, then enriches each
    entry with N50, total length, and contig count from the assembly stats TSV.
    Finally, computes the QS score for every genome.

    Args:
        stats_file: Path to the assembly stats TSV with columns:
            ``Genome``, ``N50``, ``Length``, ``GC_content``, ``N_contigs``.
        checkm_file: Path to the CheckM CSV with columns:
            ``genome``, ``completeness``, ``contamination``.

    Returns:
        A dict mapping genome ID (extension stripped) to its fully populated Quality dataclass.
    """
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


def calc_qs(completeness: float, contamination: float, n50: int) -> float:
    """
    Calculate the Quality Score (QS) for a genome assembly.

    The formula is:
        QS = completeness - (contamination × 5) + 0.5 × log10(N50)

    Args:
        completeness: Genome completeness percentage (0–100).
        contamination: Genome contamination percentage (0–100).
        n50: N50 contig length in base pairs.

    Returns:
        The computed QS as a float.
    """
    qs = float(completeness) - float(contamination) * 5 + 0.5 * math.log10(float(n50))
    return qs


def sanity_check(
    replacement_results: dict[str, dict],
    remove_list: list[str],
    current_clusters: dict[str, list[str]],
    new_strain_placement: dict[str, Placement],
    report_to_print: dict,
) -> None:
    """
    Validate that replacement_results is internally consistent.

    Performs the following checks:
        1. Counts genomes in the old catalogue.
        2. Computes the expected total after removals and additions.
        3. Counts unique genomes in replacement_results and flags duplicates.
        4. Confirms the count matches the expectation.
        5. Ensures every genome from new_strain_placement appears in the results.
        6. Exits with an error if any check fails.

    Args:
        replacement_results: Updated cluster dict (old rep → ``{new_rep, genome_list}``).
        remove_list: List of genome IDs removed from the catalogue.
        current_clusters: Original cluster state before any changes.
        new_strain_placement: Mapping of new-strain genome ID to its Placement.
        report_to_print: Stats dict containing ``new_strains_added`` and
            ``repeat_strains_added`` counts.
    """
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
    parser.add_argument('--checkm2_switch', action='store_true',
                        help='Use this flag if the completeness/contamination in the old catalogue were recomputed with'
                             ' CheckM2 during the update process. All clusters will be reassessed to check if the '
                             'species representative genome should change.')
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
         args.remove_list, args.checkm2_switch, args.new_species_split_file, args.new_strain_list, 
         args.repeat_strain_list)
    