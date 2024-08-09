#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Copyright 2023 EMBL - European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import argparse
import csv
import logging
import os
import sys

logging.basicConfig(level=logging.INFO)


def main(input_folder, prokka_gff, outfile, df_version):
    gene_path, system_path = get_files(input_folder)
    prokka_data = load_prokka(prokka_gff)
    if not all([os.path.exists(gene_path), os.path.exists(system_path)]):
        sys.exit("Missing Defense Finder outputs. Exiting.")
    gene_results = load_genes(gene_path)
    print_systems_to_file(system_path, gene_results, outfile, df_version, prokka_data)


def load_prokka(prokka_gff):
    prokka_data = dict()
    with open(prokka_gff, "r") as file_in:
        for line in file_in:
            if not line.startswith("#"):
                if line.startswith(">"):
                    break
                else:
                    contig, _, _, start, end, _, strand, _, col9 = line.strip().split(
                        "\t"
                    )
                    prot_name = col9.split(";")[0].split("=")[1]
                    prokka_data[prot_name] = {
                        "contig": contig,
                        "start": start,
                        "end": end,
                        "strand": strand,
                    }
    return prokka_data


def print_systems_to_file(system_path, gene_results, outfile, df_version, prokka_data):
    with open(system_path, "r") as file_in, open(outfile, "w") as file_out:
        writer = csv.writer(file_out, delimiter="\t")
        writer.writerow(["##gff-version 3"])
        for line in file_in:
            if line.lower().startswith("sys_id"):
                (
                    sys_id_index,
                    type_index,
                    subtype_index,
                    sys_beg_index,
                    sys_end_index,
                    protein_in_syst_index,
                ) = [
                    line.strip().split().index(field)
                    for field in [
                        "sys_id",
                        "type",
                        "subtype",
                        "sys_beg",
                        "sys_end",
                        "protein_in_syst",
                    ]
                ]
            else:
                cols = line.strip().split("\t")
                start = prokka_data[cols[sys_beg_index]]["start"]
                end = prokka_data[cols[sys_end_index]]["end"]
                contig = prokka_data[cols[sys_beg_index]]["contig"]
                writer.writerow(
                    [
                        contig,
                        f"DefenseFinder:{df_version}",
                        "Anti-phage system",
                        start,
                        end,
                        ".",
                        ".",
                        ".",
                        f"ID={cols[sys_id_index]};type={cols[type_index]};subtype={cols[subtype_index]}",
                    ]
                )
                proteins = cols[protein_in_syst_index].split(",")
                for protein in proteins:
                    prot_start = prokka_data[protein]["start"]
                    prot_end = prokka_data[protein]["end"]
                    prot_strand = prokka_data[protein]["strand"]
                    writer.writerow(
                        [
                            contig,
                            f"DefenseFinder:{df_version}",
                            "gene",
                            prot_start,
                            prot_end,
                            ".",
                            prot_strand,
                            ".",
                            f"ID={protein};Parent={cols[sys_id_index]};"
                            f"gene_name={gene_results[protein]['gene_name']};"
                            f"hit_status={gene_results[protein]['hit_status']}",
                        ]
                    )


def load_genes(gene_path):
    gene_results = dict()
    with open(gene_path, "r") as file_in:
        for line in file_in:
            if line.lower().startswith("replicon"):
                # get indices of fields
                acc_index, gene_index, hit_status = [
                    line.strip().split().index(field)
                    for field in ["hit_id", "gene_name", "hit_status"]
                ]
            else:
                fields = line.strip().split()
                gene_results.setdefault(fields[acc_index], dict())
                gene_results[fields[acc_index]]["gene_name"] = fields[gene_index]
                gene_results[fields[acc_index]]["hit_status"] = fields[hit_status]
    return gene_results


def get_files(input_folder):
    gene_path = system_path = ""
    files = os.listdir(input_folder)
    for f in files:
        if f.endswith("_defense_finder_systems.tsv"):
            system_path = os.path.join(input_folder, f)
        elif f.endswith("_defense_finder_genes.tsv"):
            gene_path = os.path.join(input_folder, f)
    return gene_path, system_path


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "The script takes Defense Finder output and parses it to create a standalone GFF."
        )
    )
    parser.add_argument(
        "-i",
        dest="input_folder",
        required=True,
        help="Path to the folder with Defense Finder results.",
    )
    parser.add_argument(
        "-p",
        dest="prokka_gff",
        required=True,
        help=("Path to the Prokka GFF file."),
    )
    parser.add_argument(
        "-o",
        dest="outfile",
        required=True,
        help=("Path to the output file."),
    )
    parser.add_argument(
        "-v",
        dest="df_ver",
        required=True,
        help=("DefenseFinder version used."),
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args.input_folder, args.prokka_gff, args.outfile, args.df_ver)
