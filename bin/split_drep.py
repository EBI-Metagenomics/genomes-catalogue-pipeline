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
import sys
import argparse
from shutil import copy


def get_scores(sdb):
    scores = {}
    with open(sdb, "r") as file_in:
        next(file_in)
        for line in file_in:
            values = line.strip().split(",")
            scores.setdefault(values[0], values[1])
    return scores


def get_clusters(cluster_file):
    clusters = {}
    with open(cluster_file, "r") as f:
        next(f)
        for line in f:
            genome, cluster_number, _, _, _, _ = line.rstrip().split(",")
            clusters.setdefault(cluster_number, []).append(genome)
    return clusters


def parse_mashfile(mash_dist, outname, genome_list):
    header = "genome1,genome2,dist,similarity"
    with open(mash_dist, "r") as infile, open(outname, "w") as outfile:
        outfile.write(f"{header}\n")
        next(infile)  # Skip header
        for line in infile:
            cols = line.strip().split(",")
            if {cols[0], cols[1]}.issubset(genome_list):
                outfile.write(line)


def split_mash(mash_dist, genome_list, outdir, cluster_name):
    cluster_dir = os.path.join(outdir, cluster_name)
    os.makedirs(cluster_dir, exist_ok=True)
    outname = os.path.join(cluster_dir, f"{cluster_name}_mash.tsv")
    parse_mashfile(mash_dist, outname, genome_list)


def generate_mash_folder(mash_dist, out_mash_folder, cluster_name, genome_list):
    outname = os.path.join(out_mash_folder, f"{cluster_name}_mash.tsv")
    parse_mashfile(mash_dist, outname, genome_list)


def create_cluster_folders(out_folder, cluster, genomes, fasta_folder):
    cluster_output = os.path.join(out_folder, "clusters", cluster)
    os.makedirs(cluster_output, exist_ok=True)

    fasta_abs = os.path.abspath(fasta_folder)
    for genome in genomes:
        src = os.path.join(fasta_abs, genome)
        dst = os.path.join(cluster_output, genome)
        copy(src, dst)
        

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
            print("--create-clusters option requires -f argument presented")
            exit(1)
        clusters = get_clusters(cluster_file=args.cdb)

        if not os.path.isdir(args.output_folder):
            os.makedirs(args.output_folder)

        with open(
            os.path.join(args.output_folder, "clusters_split.txt"), "w"
        ) as split_file:
            if args.create_clusters and args.fasta_folder:
                for c in clusters:
                    genomes = clusters[c]
                    create_cluster_folders(
                        out_folder=args.output_folder,
                        cluster=c,
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
                    split_file.write(f"{names[len(genomes) == 1]}:{c}:{','.join(sorted_genomes)}\n")
                    main_rep_name = sorted_genomes[0].split(".")[0]
                    if args.mdb:
                        split_mash(
                            mash_dist=args.mdb,
                            genome_list=genomes,
                            outdir=args.output_folder,
                            cluster_name=main_rep_name,
                        )
            else:
                if args.mdb:
                    out_mash_folder = os.path.join(args.output_folder, "mash_folder")
                    if not os.path.exists(out_mash_folder):
                        os.makedirs(out_mash_folder)
                for c in clusters:
                    genomes = clusters[c]
                    genome_scores = [float(scores[genome]) for genome in genomes]
                    sorted_genomes = [
                        x
                        for _, x in sorted(
                            zip(genome_scores, genomes),
                            reverse=True,
                            key=lambda pair: pair[0],
                        )
                    ]
                    split_file.write(f"{names[len(genomes) == 1]}:{c}:{','.join(sorted_genomes)}\n")
                    if args.mdb:
                        main_rep_name = sorted_genomes[0].split(".")[0]
                        if len(genomes) > 1:
                            generate_mash_folder(
                                mash_dist=args.mdb,
                                out_mash_folder=out_mash_folder,
                                cluster_name=main_rep_name,
                                genome_list=genomes,
                            )
