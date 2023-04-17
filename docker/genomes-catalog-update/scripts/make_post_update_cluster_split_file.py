#!/usr/bin/env python3
# coding=utf-8

import argparse


def main(original_clusters, new_clusters, strain_cluster_file, outfile):
    new_strains = load_new_strains(strain_cluster_file)
    with open(original_clusters, "r") as file_in, open(outfile, "w") as file_out:
        for line in file_in:
            cat, group, genomes = line.strip().split(":")
            rep = genomes.split(',')[0]
            if rep in new_strains:
                if cat == "one_genome":
                    cat = "many_genomes"
                genomes = genomes + "," + ",".join(new_strains[rep])
                line = ":".join([cat, group, genomes])
                file_out.write(line)
            else:
                file_out.write(line)
        with open(new_clusters, "r") as new_in:
            for line in new_in:
                file_out.write(line)


def load_new_strains(file):
    new_strains = dict()
    with open(file, "r") as file_in:
        for line in file_in:
            line = line.replace("fna", "fa")
            rep, strain = line.strip().split("\t")
            new_strains.setdefault(rep, list()).append(strain)
    return new_strains


def parse_args():
    parser = argparse.ArgumentParser(description='The script generates a new clusters_split.txt file '
                                                 'when the update process is complete. The file '
                                                 'is necessary to generate a metadata table and '
                                                 'run future updates.')
    parser.add_argument('-c', '--original-clusters', required=True,
                        help='Path to cluters_split.txt file from the previous version of the catalogue.')
    parser.add_argument('-n', '--new-clusters', required=False,
                        help='Path to the clusters_split.txt file for the update (would contain only '
                             'new species; if no new species in this update, skip).')
    parser.add_argument('-s', '--strain-cluster-file', required=False,
                        help='Path to the replace_species_reps_result.clusters.txt file (this is the '
                             'file generated when processing mash output to identify whether '
                             'the species rep from the existing catalogue should be replaced with '
                             'a new genome; the file is tab delimited where the first column is the '
                             'cluster rep and the second column is the genome added to the cluster)')
    parser.add_argument('-o', '--outfile', required=True,
                        help='Path to the output file')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.original_clusters, args.new_clusters, args.strain_cluster_file, args.outfile)