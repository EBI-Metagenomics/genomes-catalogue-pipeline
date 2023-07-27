#!/usr/bin/env python3

import argparse
import os
import sys


def main(cdb_chunked, sdb_chunked, cdb_second_run, output):
    if not os.path.exists(output):
        os.makedirs(output)
    # find species reps that belong to the same species clusters and should be merged
    clusters_to_merge, primary_clusters = save_clusters_to_merge(cdb_second_run)
    # print new Sdb.csv to the output directory and get genome scores
    process_sdb(sdb_chunked, output)
    process_cdb(cdb_chunked, clusters_to_merge, primary_clusters, output)


def process_cdb(cdb_chunked, clusters_to_merge, primary_clusters, output):
    """
    Processes chunked Cdb.csv files, merges clusters and prints them to a new Cdb.csv file.
    :param cdb_chunked: a list of Cdb.csv files from all drep chunks.
    :param clusters_to_merge: a dictionary of lists of genomes that should be merged.
    :param primary_clusters: a dictionary of lists of genomes that should be in the same primary cluster.
    :param output: path to the output directory.
    """
    outfile = os.path.join(output, "Cdb.csv")
    genome_assignments = dict()  # the cluster where each genome is assigned to based on the first drep pass
    results = dict()
    primary_counter = 0  # new primary cluster assignment
    secondary_counter = 0  # new secondary cluster assignment
    for infile in cdb_chunked:
        previous_primary = ""
        previous_secondary = ""
        with open(infile, "r") as file_in:
            for line in file_in:
                if not line.startswith("genome"):
                    genome, current_secondary, a, b, c, current_primary = line.strip().split(",")
                    if current_primary != previous_primary:
                        primary_counter += 1
                        secondary_counter = 0
                    elif current_secondary != previous_secondary:
                        secondary_counter += 1
                    new_secondary_cluster = "{}_{}".format(str(primary_counter), str(secondary_counter))
                    previous_primary = current_primary
                    previous_secondary = current_secondary
                    results.setdefault(primary_counter, dict())
                    results[primary_counter].setdefault(new_secondary_cluster, list()).append(
                        ",".join([genome, new_secondary_cluster, a, b, c, str(primary_counter)]))
                    genome_assignments[genome] = new_secondary_cluster
    merged_clusters = merge_clusters(results, clusters_to_merge, primary_clusters, genome_assignments)
    with open(outfile, "w") as file_out:
        file_out.write("genome,secondary_cluster,threshold,cluster_method,comparison_algorithm,primary_cluster\n")
        for key, nested_dict in merged_clusters.items():
            for nested_key, values in nested_dict.items():
                for value in values:
                    file_out.write(value + "\n")


def merge_clusters(results, clusters_to_merge, primary_clusters, genome_assignments):
    """
    Performs cluster merging.
    :param results: cluster assignment in the chunked drep.
    :param clusters_to_merge: a dictionary of lists of genomes that should be merged.
    :param primary_clusters: a dictionary of lists of genomes that should be in the same primary cluster.
    :param genome_assignments: a dictionary where the key = genome, value = secondary_cluster based on chunked drep.
    :return: results where clusters have been merged.
    """
    for genomes in clusters_to_merge.values():
        # find the cluster numbers to merge
        primary_clusters_sorter = dict()  # finding the cluster with the lowest number
        for genome in genomes:
            primary = int(genome_assignments[genome].split("_")[0])
            # save as - key: primary cluster from drep1, value: secondary cluster from drep1
            primary_clusters_sorter.setdefault(primary, list()).append(genome_assignments[genome])
        lowest_cluster = sorted(primary_clusters_sorter.keys())[0]  # lowest primary cluster
        chosen_secondary_cluster = sorted(primary_clusters_sorter[lowest_cluster])[0]
        # now merge all clusters these genomes belong to into the lowest cluster
        for primary, secondary_values in primary_clusters_sorter.items():
            for secondary in secondary_values:
                if not secondary == chosen_secondary_cluster:
                    results[lowest_cluster][chosen_secondary_cluster].extend(results[primary][secondary])
                    del results[primary][secondary]
    # check if any genomes were assigned to the same primary cluster during the second drep but not the same
    # secondary cluster
    for primary_cluster, genomes in primary_clusters.items():
        reassignment = need_primary_reassignemnt(genomes, results)
        if reassignment:
            # identify the largest cluster and merge into it
            largest_set = find_largest_set(reassignment, results)
            for primary_key in reassignment:
                if not primary_key == largest_set:
                    # do the reassignment
                    for key, value in results[primary_key].items():
                        results[largest_set][key] = value
                    del results[primary_key]
    # remove empty keys and correct the numbering
    clean_results = cleanup_results(results)
    return clean_results


def cleanup_results(results):
    clean_results = dict()
    assign_primary_cluster = 0
    for key in results:
        if len(results[key]) > 0:
            assign_primary_cluster += 1
            assign_secondary_cluster = 0
            for existing_secondary_cluster in results[key]:
                assign_full_cluster = "{}_{}".format(str(assign_primary_cluster), str(assign_secondary_cluster))
                for line in results[key][existing_secondary_cluster]:
                    a, _, c, d, e, _ = line.strip().split(",")
                    new_line = ",".join([a, assign_full_cluster, c, d, e, str(assign_primary_cluster)])
                    clean_results.setdefault(assign_primary_cluster, dict())
                    clean_results[assign_primary_cluster].setdefault(assign_full_cluster, list()).append(new_line)
                assign_secondary_cluster += 1
    return clean_results


def find_largest_set(reassignment, results):
    largest_set_size = 0
    largest_set_key = ""
    for primary_key in reassignment:
        if len(results[primary_key]) > largest_set_size:
            largest_set_size = len(results[primary_key])
            largest_set_key = primary_key
    return largest_set_key


def need_primary_reassignemnt(genomes, results):
    current_primary_clusters = list()
    for genome in genomes:
        for primary_key, nested_dict in results.items():
            for secondary_key, genome_strings in nested_dict.items():
                for genome_string in genome_strings:
                    if genome in genome_string:
                        current_primary_clusters.append(primary_key)
    current_primary_clusters = list(set(current_primary_clusters))
    # check if all genomes are already in the same primary cluster
    if len(current_primary_clusters) > 1:  # meaning there are still multiple primary clusters
        return sorted(current_primary_clusters)
    else:
        return False


def process_sdb(sdb_chunked, output):
    outfile = os.path.join(output, "Sdb.csv")
    with open(outfile, "w") as file_out:
        file_out.write("genome,score\n")
        for sdb_file in sdb_chunked:
            with open(sdb_file, "r") as file_in:
                for line in file_in:
                    if not line.startswith("genome"):
                        file_out.write(line)


def save_clusters_to_merge(cdb_second_run):
    all_clusters = dict()
    primary_clusters = dict()  # genomes that have the same primary cluster
    with open(cdb_second_run, "r") as file_in:
        for line in file_in:
            if not line.startswith("genome"):
                genome, cluster, _, _, _, _ = line.strip().split(",")
                all_clusters.setdefault(cluster, list()).append(genome)
                primary_cluster = cluster.split("_")[0]
                primary_clusters.setdefault(primary_cluster, list()).append(genome)
    filtered_dict = all_clusters.copy()
    for key, value in all_clusters.items():
        if len(value) < 2:
            del filtered_dict[key]
    return filtered_dict, primary_clusters


def parse_args():
    parser = argparse.ArgumentParser(description='The script is used for extra large catalogues that '
                                                 'require chunked dereplication. It takes in data tables '
                                                 'from the first (chunked) and second (species reps from all chunks) '
                                                 'dereplication rounds and outputs the data table that would have been '
                                                 'created if dereplication was carried out in one go.')
    parser.add_argument('--cdb-chunked', required=True, nargs='+',
                        help='A list of paths to Cdb.csv files from all chunks.')
    parser.add_argument('--sdb-chunked', required=True, nargs='+',
                        help='A list of paths to Sdb.csv files from all chunks.')
    parser.add_argument('--cdb-second-run', required=True,
                        help='The path to the Cdb.csv file from the second drep execution.')
    parser.add_argument('-o', '--output', required=True,
                        help='The path to the output directory')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.cdb_chunked, args.sdb_chunked, args.cdb_second_run, args.output)