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


def classify_split_folders(input_folder):
    os.makedirs(NAME_MASH, exist_ok=True)

    drep_clusters = input_folder
    clusters = os.listdir(drep_clusters)
    for cluster in clusters:
        dir_files = os.listdir(os.path.join(drep_clusters, cluster))
        genomes = [i for i in dir_files if i.endswith((".fa", ".fna"))]
        number_of_genomes = len(genomes)
        path_cluster_many = os.path.join(NAME_MANY_GENOMES, cluster)
        path_cluster_one = os.path.join(NAME_ONE_GENOME, cluster)

        if number_of_genomes > 1:
            os.makedirs(path_cluster_many, exist_ok=True)
            for genome in genomes:
                old_path = os.path.join(drep_clusters, cluster, genome)
                new_path = os.path.join(path_cluster_many, genome)
                shutil.copy(old_path, new_path)
            mashes = [i for i in dir_files if i.endswith("mash.tsv")]
            if len(mashes) > 0:
                mash = mashes[0]
                shutil.copy(
                    os.path.join(drep_clusters, cluster, mash),
                    os.path.join(NAME_MASH, mash),
                )
        if number_of_genomes == 1:
            os.makedirs(path_cluster_one, exist_ok=True)
            for genome in genomes:
                old_path = os.path.join(drep_clusters, cluster, genome)
                new_path = os.path.join(path_cluster_one, genome)
                shutil.copy(old_path, new_path)


def index_genomes(genomes_folder):
    index = {}
    for f in os.listdir(genomes_folder):
        base, _ = os.path.splitext(f)
        index[base] = f
    return index


def classify_by_file(split_text, genomes_folder):
    genome_index = index_genomes(genomes_folder)
    with open(split_text, "r") as file_in:
        for line in file_in:
            main_folder, cluster, genomes_str = line.strip().split(":")
            genomes = genomes_str.split(",")
            cluster_name = genomes[0].rsplit(".", 1)[0]  # cluster
            path_cluster = os.path.join(main_folder, cluster_name)
            if not os.path.exists(path_cluster):
                os.mkdir(path_cluster)
            for genome in genomes:
                base_name, _ = os.path.splitext(genome)  # remove extension from genome filename in cluster split file
                if base_name in genome_index:
                    old_path = os.path.join(genomes_folder, genome_index[base_name])
                    new_path = os.path.join(path_cluster, genome_index[base_name])
                    shutil.copy(old_path, new_path)
                else:
                    sys.exit("Cannot find expected genome {}".format(genome))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Moves clusters according the number of genomes"
    )
    parser.add_argument(
        "-i",
        "--input",
        dest="input_folder",
        help="drep_split out folder",
        required=False,
    )
    parser.add_argument(
        "--text-file", dest="text_file", help="drep_split out txt file", required=False
    )
    parser.add_argument(
        "-g",
        "--genomes",
        dest="genomes",
        help="folder with all genomes",
        required=False,
    )

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()
        if not (args.input_folder or args.text_file):
            print("No necessary arguments specified")
            exit(1)

        os.makedirs(NAME_MANY_GENOMES, exist_ok=True)
        os.makedirs(NAME_ONE_GENOME, exist_ok=True)

        if args.input_folder:
            print("Classify split folders")
            classify_split_folders(args.input_folder)
        elif args.text_file:
            if args.genomes:
                classify_by_file(split_text=args.text_file, genomes_folder=args.genomes)
            else:
                print("No -g specified")
