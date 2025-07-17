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


import csv
import os
import sys
import argparse
from shutil import copy
from collections import defaultdict


def get_scores(sdb):
    scores = {}
    with open(sdb, "r") as file_in:
        next(file_in)  # skip header
        for line in file_in:
            genome, score = line.strip().split(",")
            scores.setdefault(genome, score)
    return scores


def get_clusters(clst_file):
    clusters = {}
    with open(clst_file, "r") as f:
        next(f)  # skip header
        for line in f:
            genome, cluster = line.strip().split(",")[:2]
            clusters.setdefault(cluster, []).append(genome)
    return clusters


def parse_mashfile(mash_dist, outname, genlist):
    header = "genome1,genome2,dist,similarity"
    with open(mash_dist, "r") as f, open(outname, "w") as fout:
        fout.write("%s\n" % (header))
        next(f)
        for line in f:
            line = line.rstrip()
            cols = line.split(",")
            if cols[0] in genlist and cols[1] in genlist:
                fout.write("%s\n" % (line))


def split_mash(mash_dist, genlist, outdir, cluster_name):
    outname = "%s/%s/%s_mash.tsv" % (outdir, cluster_name, cluster_name)
    print(outname)
    if not os.path.isdir(os.path.join(outdir, cluster_name)):
        os.makedirs(os.path.join(outdir, cluster_name))
    parse_mashfile(mash_dist, outname, genlist)


def generate_mash_folder(mash_dist, out_mash_folder, cluster_name, genlist):
    outname = os.path.join(out_mash_folder, cluster_name + "_mash.tsv")
    parse_mashfile(mash_dist, outname, genlist)


def create_cluster_folders(out_folder, cluster, genomes, fasta_folder):
    cluster_output = "%s/%s/%s" % (out_folder, "clusters", cluster)
    if not os.path.isdir(cluster_output):
        os.makedirs(cluster_output)
    for genome in genomes:
        src = "%s/%s" % (os.path.abspath(fasta_folder), genome)
        dst = "%s/%s" % (cluster_output, genome)
        copy(src, dst)


def stream_and_split_mdb(mdb_file, genome_to_cluster_rep, output_folder):
    print("Streaming Mdb and writing Mash files per cluster...")
    
    flush_threshold = 1000
    buffer = defaultdict(list)
    
    def flush_cluster(cluster_rep):
        out_path = os.path.join(output_folder, f"{cluster_rep}_mash.tsv")
        write_header = not os.path.exists(out_path)
        with open(out_path, "a", newline='') as out_f:
            writer = csv.writer(out_f)
            if write_header:
                writer.writerow(["genome1", "genome2", "dist", "similarity"])
            writer.writerows(buffer[cluster_rep])
        buffer[cluster_rep].clear()

    with open(mdb_file, "r") as f:
        reader = csv.reader(f)
        next(reader)  # Skip header

        for cols in reader:
            g1, g2 = cols[0], cols[1]

            # check that both genomes in line are in the same species cluster
            c1 = genome_to_cluster_rep.get(g1)
            c2 = genome_to_cluster_rep.get(g2)

            if c1 and c1 == c2:
                cluster_rep = c1
                buffer[cluster_rep].append(cols)

                if len(buffer[cluster_rep]) >= flush_threshold:
                    flush_cluster(cluster_rep)

    # Final flush
    for cluster_rep in buffer:
        if buffer[cluster_rep]:
            flush_cluster(cluster_rep)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Split dRep results by species cluster"
    )
    parser.add_argument("-f", dest="fasta_folder", help="FASTA folder", required=False)
    parser.add_argument(
        "-o", dest="output_folder", help="Output folder [REQUIRED]", required=True
    )
    parser.add_argument(
        "--cdb",
        dest="cdb",
        help="dRep output folder/data_tables/Cdb.csv",
        required=True,
    )
    parser.add_argument(
        "--mdb",
        dest="mdb",
        help="dRep output folder/data_tables/Mdb.csv",
        required=False,
    )
    parser.add_argument("--sdb", dest="sdb", help="dRep Sdb.csv", required=True)
    parser.add_argument(
        "--create-clusters",
        action="store_true",
        help=(
            "Set this flag to generate folders with genomes and mash-files inside for"
            " each cluster"
        ),
    )

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()

        # get scores for genomes
        scores = get_scores(sdb=args.sdb)

        names = {True: "one_genome", False: "many_genomes"}
        if args.create_clusters and not args.fasta_folder:
            print("--create-clusters option requires -f argument provided")
            exit(1)
        clusters = get_clusters(clst_file=args.cdb)

        if not os.path.isdir(args.output_folder):
            os.makedirs(args.output_folder)

        with open(
            os.path.join(args.output_folder, "clusters_split.txt"), "w"
        ) as split_file:
            if args.create_clusters and args.fasta_folder:
                for cluster_id in clusters:
                    genomes = clusters[cluster_id]
                    create_cluster_folders(
                        out_folder=args.output_folder,
                        cluster=cluster_id,
                        genomes=genomes,
                        fasta_folder=args.fasta_folder,
                    )

                    genome_scores = [float(scores[genome]) for genome in genomes]
                    sorted_genomes = [
                        x
                        for _, x in sorted(
                            zip(genome_scores, genomes),
                            reverse=True,
                            key=lambda pair: pair[0],
                        )
                    ]
                    split_file.write(
                        names[len(genomes) == 1]
                        + ":"
                        + cluster_id
                        + ":"
                        + ",".join(sorted_genomes)
                        + "\n"
                    )
                    main_rep_name = sorted_genomes[0].split(".")[0]
                    if args.mdb:
                        split_mash(
                            mash_dist=args.mdb,
                            genlist=genomes,
                            outdir=args.output_folder,
                            cluster_name=main_rep_name,
                        )
            else:
                genome_to_cluster_rep = dict()
                for cluster_id in clusters:
                    genomes = clusters[cluster_id]
                    genome_scores = [float(scores[genome]) for genome in genomes]
                    sorted_genomes = [
                        x
                        for _, x in sorted(
                            zip(genome_scores, genomes),
                            reverse=True,
                            key=lambda pair: pair[0],
                        )
                    ]
                    split_file.write(
                        names[len(genomes) == 1]
                        + ":"
                        + cluster_id
                        + ":"
                        + ",".join(sorted_genomes)
                        + "\n"
                    )
                    if len(genomes) > 1:
                        for g in genomes:
                            main_rep_name = sorted_genomes[0].split(".")[0]
                            genome_to_cluster_rep[g] = main_rep_name
        
        if args.mdb and not args.create_clusters:
            out_mash_folder = os.path.join(args.output_folder, "mash_folder")
            if not os.path.exists(out_mash_folder):
                os.makedirs(out_mash_folder)
            stream_and_split_mdb(
                mdb_file=args.mdb,
                genome_to_cluster_rep=genome_to_cluster_rep,
                output_folder=out_mash_folder,
            )