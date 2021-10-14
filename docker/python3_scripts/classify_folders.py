#!/usr/bin/env python3

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


import os
import shutil
import argparse
import sys

NAME_MASH = "mash_folder"
NAME_MANY_GENOMES = "many_genomes"
NAME_ONE_GENOME = "one_genome"


def classify_splitted_folders(input_folder):
    if not os.path.exists(NAME_MASH):
        os.makedirs(NAME_MASH)

    drep_clusters = input_folder
    clusters = os.listdir(drep_clusters)
    for cluster in clusters:
        dir_files = os.listdir(os.path.join(drep_clusters, cluster))
        genomes = [i for i in dir_files if i.endswith('.fa')]
        number_of_genomes = len(genomes)
        path_cluster_many = os.path.join(NAME_MANY_GENOMES, cluster)
        path_cluster_one = os.path.join(NAME_ONE_GENOME, cluster)

        if number_of_genomes > 1:
            if not os.path.exists(path_cluster_many):
                os.makedirs(path_cluster_many)
            for genome in genomes:
                old_path = os.path.join(drep_clusters, cluster, genome)
                new_path = os.path.join(path_cluster_many, genome)
                shutil.copy(old_path, new_path)
            mashes = [i for i in dir_files if i.endswith('mash.tsv')]
            if len(mashes) > 0:
                mash = mashes[0]
                shutil.copy(os.path.join(drep_clusters, cluster, mash), os.path.join(NAME_MASH, mash))
        if number_of_genomes == 1:
            if not os.path.exists(path_cluster_one):
                os.makedirs(path_cluster_one)
            for genome in genomes:
                old_path = os.path.join(drep_clusters, cluster, genome)
                new_path = os.path.join(path_cluster_one, genome)
                shutil.copy(old_path, new_path)


def classify_by_file(split_text, genomes_folder):
    with open(split_text, 'r') as file_in:
        for line in file_in:
            main_folder, cluster, genomes_str = line.strip().split(':')
            genomes = genomes_str.split(',')
            cluster_name = genomes[0]  # cluster
            path_cluster = os.path.join(main_folder, cluster_name)
            if not os.path.exists(path_cluster):
                os.mkdir(path_cluster)
            for genome in genomes:
                old_path = os.path.join(genomes_folder, genome)
                new_path = os.path.join(path_cluster, genome)
                shutil.copy(old_path, new_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Moves clusters according the number of genomes")
    parser.add_argument("-i", "--input", dest="input_folder", help="drep_split out folder", required=False)
    parser.add_argument("--text-file", dest="text_file", help="drep_split out txt file", required=False)
    parser.add_argument("-g", "--genomes", dest="genomes", help="folder with all genomes", required=False)

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()
        if not (args.input_folder or args.text_file):
            print('No necessary arguments specified')
            exit(1)

        if not os.path.exists(NAME_MANY_GENOMES):
            os.makedirs(NAME_MANY_GENOMES)
        if not os.path.exists(NAME_ONE_GENOME):
            os.makedirs(NAME_ONE_GENOME)

        if args.input_folder:
            print('Classify splitted folders')
            classify_splitted_folders(args.input_folder)
        elif args.text_file:
            if args.genomes:
                classify_by_file(split_text=args.text_file, genomes_folder=args.genomes)
            else:
                print('No -g specified')

