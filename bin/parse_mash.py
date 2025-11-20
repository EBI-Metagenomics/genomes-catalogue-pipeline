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


def main(mash, genomes_file, outfolder, infolder):
    scores = dict()
    # We need to use a list of genomes to check because not all query genomes will be in the mash file (everything
    # that didn't have a close enough hit is filtered out)
    if genomes_file:
        genomes = load_list(genomes_file)
    else:
        genomes = os.listdir(infolder)
    with open(mash, 'r') as infile:
        # mash output files have no heading and lines look like this:
        # MGYG000518640.fna       renamed_genomes/MGYG000535623.fa        0.0201478       0       487/1000
        for line in infile:
            if line == "\n":
                break
            catalogue_genome, query_genome_path, score, _, _ = line.strip().split()
            query_genome = os.path.basename(query_genome_path)  # get just the genome file name
            if query_genome in genomes:
                score = float(score)
                # Update only if new score is lower (or missing)
                previous_score = scores.get(query_genome)
                if previous_score is None or score < previous_score:
                    scores[query_genome] = score
    same_strains, new_strains, new_species = evaluate(genomes, scores)
    generate_output(same_strains, new_strains, new_species, outfolder, infolder)


def load_list(genomes_file, remove_ext=False):
    genomes = set()
    with open(genomes_file, 'r') as infile:
        for line in infile:
            fasta_file = os.path.basename(line.strip())
            if remove_ext:
                fasta_file = os.path.splitext(fasta_file)[0]
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
        elif scores[genome] < SAME_STRAIN_CUTOFF:
            same_strains.add(genome)
        elif scores[genome] > NEW_SPECIES_CUTOFF:
            new_species.add(genome)
        else:
            new_strains.add(genome)

    logging.info('same strain: {} new strain: {} new species: {}'.format(len(same_strains), len(new_strains), 
                                                                         len(new_species)))
    return same_strains, new_strains, new_species


def generate_output(repeat_strains, new_strains, new_species, outfolder, infolder):
    # Output paths
    new_species_folder = os.path.join(outfolder, 'New_species')
    new_strains_file = os.path.join(outfolder, 'new_strains.txt')
    repeat_strains_file = os.path.join(outfolder, 'repeat_strains.txt')
    
    # Create output root and new species folder
    os.makedirs(outfolder, exist_ok=True)
    os.makedirs(new_species_folder, exist_ok=True)
    
    # ---- Write strain lists to text files ----
    with open(new_strains_file, 'w') as out_ns:
        out_ns.write("\n".join(new_strains) + "\n" if new_strains else "")

    with open(repeat_strains_file, 'w') as out_rs:
        out_rs.write("\n".join(repeat_strains) + "\n" if repeat_strains else "")

    # ---- Copy only new species ----
    copy_file_list(new_species, infolder, new_species_folder)


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
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.mash, args.evaluate_list, args.outfolder, args.input_folder)