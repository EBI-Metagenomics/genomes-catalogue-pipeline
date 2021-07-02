#!/usr/bin/env python3

import os
import shutil
import argparse
import sys

NAME_MANY_GENOMES = "many_genomes"
NAME_ONE_GENOME = "one_genome"
NAME_MASH = "mash_folder"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Moves clusters according the number of genomes")
    parser.add_argument("-i", "--input", dest="input_folder", help="drep_split out folder", required=True)

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()
        if not os.path.exists(NAME_MANY_GENOMES):
            os.makedirs(NAME_MANY_GENOMES)
        if not os.path.exists(NAME_ONE_GENOME):
            os.makedirs(NAME_ONE_GENOME)
        if not os.path.exists(NAME_MASH):
            os.makedirs(NAME_MASH)

        drep_clusters = args.input_folder
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

