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
import os
from shutil import copy2

NEW_SPECIES_CUTOFF = 0.05
DISCARD_CUTOFF = 0.001


def main(mash, genomes_file, outfolder, infolder):
    scores = dict()
    genomes = load_list(genomes_file)
    with open(mash, 'r') as infile:
        for line in infile:
            if line == "\n":
                break
            genome_path = line.strip().split()[1]
            genome = genome_path.split('/')[-1]
            if genome in genomes:
                score = float(line.strip().split()[2])
                if genome in scores:
                    if score < scores[genome]:
                        scores[genome] = score
                else:
                    scores[genome] = score
    discard, new_strains, new_species = evaluate(genomes, scores)
    generate_output(discard, new_strains, new_species, outfolder, infolder)


def load_list(genomes_file):
    genomes = set()
    with open(genomes_file, 'r') as infile:
        for line in infile:
            genomes.add(line.strip())
    return genomes


def evaluate(genomes, scores):
    discard = set()
    new_strains = set()
    new_species = set()
    for genome in genomes:
        if genome not in scores:
            new_species.add(genome)
        elif scores[genome] < DISCARD_CUTOFF:
            discard.add(genome)
        elif scores[genome] > NEW_SPECIES_CUTOFF:
            new_species.add(genome)
        else:
            new_strains.add(genome)
    print('discard: {} new strain: {} new species: {}'.format(len(discard), len(new_strains), len(new_species)))
    return discard, new_strains, new_species


def generate_output(discard, new_strains, new_species, outfolder, infolder):
    strains_folder = os.path.join(outfolder, 'New_strains')
    species_folder = os.path.join(outfolder, 'New_species')
    for f in [outfolder, strains_folder, species_folder]:
        if not os.path.exists(f):
            os.makedirs(f)
    discard_file = os.path.join(outfolder, 'discarded_genomes.txt')
    with open(discard_file, 'w') as discard_out:
        discard_out.write('\n'.join(discard) + '\n')
    for file_name in new_species:
        original_location = os.path.join(infolder, file_name)
        copy2(original_location, species_folder)
    for file_name in new_strains:
        original_location = os.path.join(infolder, file_name)
        copy2(original_location, strains_folder)


def parse_args():
    parser = argparse.ArgumentParser(description='''
    The script parses mash output (dereplicated genomes compared against a mash sketch of the existing genome 
    catalog) and separates new genomes into 3 categories: new species, new strains, and repeat strains 
    (to be discarded). To determine the category of a new genome, the script finds the most similar genome in the 
    existing catalog (based on mash distance).
    ''')
    parser.add_argument('-m', '--mash', required=True,
                        help='Path to the mash filename')
    parser.add_argument('-e', '--evaluate-list', required=True,
                        help='List of genomes to evaluate')
    parser.add_argument('-o', '--outfolder', required=True,
                        help='Path to folder where the results will be saved to')
    parser.add_argument('-f', '--input-folder', required=True,
                        help='Path to folder where the dereplicated new genome fasta files are located')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.mash, args.evaluate_list, args.outfolder, args.input_folder)