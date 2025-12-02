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
from shutil import copy2

logging.basicConfig(level=logging.INFO)

NEW_SPECIES_CUTOFF = 0.05
SAME_STRAIN_CUTOFF = 0.001


def main(mash, genomes_file, outfolder, infolder, metadata_table):
    scores = dict()  # query_genome → (best_hit, best_score)
    distances_to_reps = dict()  # query_genome → (best_rep_hit, best_rep_score)
    # We need to use a list of genomes to check because not all query genomes will be in the mash file (everything
    # that didn't have a close enough hit is filtered out)
    if genomes_file:
        genomes = load_list(genomes_file)
    else:
        genomes = os.listdir(infolder)
    
    rep_to_member, member_to_rep = load_metadata_table(metadata_table)
    species_reps = set(rep_to_member.keys())  # for faster lookup
    
    with open(mash, 'r') as infile:
        # mash output files have no heading and lines look like this:
        # MGYG000518640.fna       renamed_genomes/MGYG000535623.fa        0.0201478       0       487/1000
        for line in infile:
            if line == "\n":
                break
            catalogue_genome, query_genome_path, score, _, _ = line.strip().split()
            query_genome = os.path.basename(query_genome_path)  # get just the genome file name
            
            if query_genome not in genomes:
                continue
            score = float(score)
            
            # ---------------------------
            # 1. Track best genome hit overall
            # ---------------------------
            # Update only if new score is lower (or missing)
            previous_record = scores.get(query_genome)
            if previous_record is None or score < previous_record[1]:
                scores[query_genome] = (catalogue_genome, score)
            
            # ---------------------------
            # 2. Track distance if it's a species rep
            # ---------------------------
            if remove_extension(catalogue_genome) in species_reps:
                distances_to_reps.setdefault(query_genome, []).append((catalogue_genome, score))

    same_strains, new_strains, new_species = evaluate(genomes, scores)
    generate_output(same_strains, new_strains, new_species, scores, distances_to_reps, member_to_rep, outfolder, infolder)


def load_metadata_table(metadata_table_file):
    rep_to_member = dict()
    member_to_rep = dict()
    with open(metadata_table_file, "r") as f:
        header = f.readline().strip()
        header_fields = header.split("\t")
        try:
            acc_index = header_fields.index("Genome")
            rep_index = header_fields.index("Species_rep")
        except ValueError as e:
            raise RuntimeError(f"Missing required field: {e}")
        for line in f:
            parts = line.strip().split("\t")
            rep = parts[rep_index]
            acc = parts[acc_index]
            rep_to_member.setdefault(rep, list()).append(acc)
            member_to_rep[acc] = rep
    return rep_to_member, member_to_rep
        
            
def load_list(genomes_file, remove_ext=False):
    genomes = set()
    with open(genomes_file, 'r') as infile:
        for line in infile:
            fasta_file = os.path.basename(line.strip())
            if remove_ext:
                fasta_file = remove_extension(fasta_file)
            genomes.add(fasta_file)
    return genomes


def copy_file_list(names, infolder, outfolder):
    """Copies each file in `names` from `infolder` to `outfolder`."""
    for name in names:
        src = os.path.join(infolder, name)
        dst = os.path.join(outfolder, name)
        copy2(src, dst)


def evaluate(genomes, scores):
    same_strains = set()
    new_strains = set()
    new_species = set()
    for genome in genomes:
        if genome not in scores:
            new_species.add(genome)
            continue
        _, score_value = scores[genome]
        if score_value < SAME_STRAIN_CUTOFF:
            same_strains.add(genome)
        elif score_value > NEW_SPECIES_CUTOFF:
            new_species.add(genome)
        else:
            new_strains.add(genome)

    logging.info('same strain: {} new strain: {} new species: {}'.format(len(same_strains), len(new_strains), 
                                                                         len(new_species)))
    return same_strains, new_strains, new_species


def remove_extension(acc):
    for ext in (".fa", ".fna", ".fasta"):
        if acc.endswith(ext):
            return acc.removesuffix(ext)
    return acc 
    

def generate_output(repeat_strains, new_strains, new_species, scores, distances_to_reps, member_to_rep, outfolder, 
                    infolder):
    # Output paths
    new_species_folder = os.path.join(outfolder, 'New_species')
    new_strains_file = os.path.join(outfolder, 'new_strains.tsv')
    repeat_strains_file = os.path.join(outfolder, 'repeat_strains.tsv')
    
    # Create output root and new species folder
    os.makedirs(outfolder, exist_ok=True)
    os.makedirs(new_species_folder, exist_ok=True)

    # ---- Copy only new species ----
    copy_file_list(new_species, infolder, new_species_folder)
    
    # ---- Header for the output tables ----
    header = [
        "Accession",
        "Nearest_hit",
        "Nearest_hit_score",
        "Hit_rep",
        "Score_for_hit_rep",
        "Closest_rep",
        "Score_to_closest_rep",
        "Closest_rep_matches_hit_rep"
    ]
    header_line = "\t".join(header) + "\n"

    # ---- Helper to compute table for a list of accessions ----
    def build_rows(accession_list):
        rows = []

        for acc in accession_list:
            # nearest genome hit
            hit, hit_score = scores.get(acc, (None, None))

            # get the species representative for this catalogue genome
            hit_rep = member_to_rep.get(remove_extension(hit))

            # get all hits to species reps for this query
            all_rep_hits = distances_to_reps.get(acc, [])
            rep_score_for_hit = None
            # find if the species rep for the cluster the best hit belongs to is there and record distance to it
            for species_rep, distance_to_rep in all_rep_hits:
                if remove_extension(species_rep) == hit_rep:
                    rep_score_for_hit = distance_to_rep
                    break

            # best rep overall for this accession
            if all_rep_hits:
                best_rep, best_rep_score = min(all_rep_hits, key=lambda x: x[1])
            else:
                best_rep, best_rep_score = None, None

            # YES/NO whether the rep for the hit matches the accession's best rep
            matches = "YES" if remove_extension(hit_rep) == remove_extension(best_rep) and best_rep is not None else "NO"

            row = [
                acc,
                hit,
                str(hit_score) if hit_score is not None else "NA",
                hit_rep if hit_rep else "NA",
                str(rep_score_for_hit) if rep_score_for_hit is not None else "NA",
                best_rep if best_rep else "NA",
                str(best_rep_score) if best_rep_score is not None else "NA",
                matches
            ]

            rows.append("\t".join(row))

        return rows

    # ---- Write new strain table ----
    with open(new_strains_file, 'w') as out_ns:
        out_ns.write(header_line)
        out_ns.write("\n".join(build_rows(new_strains)) + "\n")

    # ---- Write repeat strain table ----
    with open(repeat_strains_file, 'w') as out_rs:
        out_rs.write(header_line)
        out_rs.write("\n".join(build_rows(repeat_strains)) + "\n")
        
    
def parse_args():
    parser = argparse.ArgumentParser(description='''
    The script parses mash output (dereplicated genomes compared against a mash sketch of the existing genome 
    catalog) and separates new genomes into 3 categories: new species, new strains, and repeat strains 
    (to be discarded). To determine the category of a new genome, the script finds the most similar genome in the 
    existing catalog (based on mash distance).
    ''')
    parser.add_argument('-m', '--mash', required=True,
                        help='Path to the mash filename')
    parser.add_argument('-e', '--evaluate-list', required=False,
                        help='List of genomes to evaluate. Include extensions (same as mash query genomes)')
    parser.add_argument('-o', '--outfolder', required=True,
                        help='Path to folder where the results will be saved to')
    parser.add_argument('-f', '--input-folder', required=True,
                        help='Path to folder where the deduplicated new genome fasta files are located')
    parser.add_argument('--metadata-table', required=True,
                        help='Path to metadata table of the previous catalogue version')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.mash, args.evaluate_list, args.outfolder, args.input_folder, args.metadata_table)