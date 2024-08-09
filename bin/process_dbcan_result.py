#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Copyright 2023-2024 EMBL - European Bioinformatics Institute
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
import logging
import os
import sys

logging.basicConfig(level=logging.INFO)


def main(input_folder, outfile, dbcan_version):
    if not check_folder_completeness(input_folder):
        sys.exit("Missing dbCAN outputs. Exiting.")
    substrates = load_substrates(input_folder)
    cgc_locations = load_cgcs(input_folder)
    print_gff(input_folder, outfile, dbcan_version, substrates, cgc_locations)


def load_cgcs(input_folder):
    cgc_locations = dict()
    with open(os.path.join(input_folder, "cgc_standard.out")) as file_in:
        for line in file_in:
            if not line.startswith("CGC#"):
                cgc, _, contig, _, start, end, _, _ = line.strip().split("\t")
                cgc_id = "{}_{}".format(contig, cgc)
                if cgc_id in cgc_locations:
                    if cgc_locations[cgc_id]["start"] > int(start):
                        cgc_locations[cgc_id]["start"] = int(start)
                    if cgc_locations[cgc_id]["end"] < int(end):
                        cgc_locations[cgc_id]["end"] = int(end)
                else:
                    cgc_locations[cgc_id] = {
                        "start": int(start),
                        "end": int(end),
                        "contig": contig,
                    }
    return cgc_locations


def print_gff(input_folder, outfile, dbcan_version, substrates, cgc_locations):
    with open(outfile, "w") as file_out:
        file_out.write("##gff-version 3\n")
        cgcs_printed = list()
        with open(os.path.join(input_folder, "cgc_standard.out")) as file_in:
            for line in file_in:
                if not line.startswith("CGC#"):
                    cgc, gene_type, contig, prot_id, start, end, strand, protein_fam = (
                        line.strip().split("\t")
                    )
                    cgc_id = "{}_{}".format(contig, cgc)
                    protein_fam = protein_fam.replace(" ", "")
                    if not cgc_id in cgcs_printed:
                        substrate = (
                            substrates[cgc_id]
                            if cgc_id in substrates
                            else "substrate_dbcan-pul=N/A;substrate_dbcan-sub=N/A"
                        )
                        file_out.write(
                            "{}\tdbCAN:{}\tpredicted PUL\t{}\t{}\t.\t.\t.\tID={};{}\n".format(
                                contig,
                                dbcan_version,
                                cgc_locations[cgc_id]["start"],
                                cgc_locations[cgc_id]["end"],
                                cgc_id,
                                substrate,
                            )
                        )
                        cgcs_printed.append(cgc_id)
                    file_out.write(
                        "{}\tdbCAN:{}\t{}\t{}\t{}\t.\t{}\t.\tID={};Parent={};protein_family={}\n".format(
                            contig,
                            dbcan_version,
                            gene_type,
                            start,
                            end,
                            strand,
                            prot_id,
                            cgc_id,
                            protein_fam,
                        )
                    )


def load_substrates(input_folder):
    substrates = dict()
    with open(os.path.join(input_folder, "substrate.out"), "r") as file_in:
        for line in file_in:
            if not line.startswith("#"):
                parts = line.strip().split("\t")
                cgc_parts = parts[0].rsplit("|", 1)
                cgc = "_".join(cgc_parts)
                try:
                    substrate_pul = parts[2]
                except IndexError:
                    substrate_pul = "N/A"
                try:
                    substrate_ecami = parts[5]
                except IndexError:
                    substrate_ecami = "N/A"
                if not substrate_pul:
                    substrate_pul = "N/A"
                if not substrate_ecami:
                    substrate_ecami = "N/A"
                substrates[cgc] = (
                    "substrate_dbcan-pul={};substrate_dbcan-sub={}".format(
                        substrate_pul, substrate_ecami
                    )
                )
    print(substrates)
    return substrates


def check_folder_completeness(input_folder):
    status = True
    for file in ["cgc_standard.out", "overview.txt", "substrate.out"]:
        if not os.path.exists(os.path.join(input_folder, file)):
            logging.error("File {} does not exist.".format(file))
            status = False
    return status


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "The script takes dbCAN output and parses it to create a standalone GFF."
        )
    )
    parser.add_argument(
        "-i",
        dest="input_folder",
        required=True,
        help="Path to the folder with dbCAN results.",
    )
    parser.add_argument(
        "-o",
        dest="outfile",
        required=True,
        help=("Path to the output file."),
    )
    parser.add_argument(
        "-v",
        dest="dbcan_ver",
        required=True,
        help=("dbCAN version used."),
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args.input_folder, args.outfile, args.dbcan_ver)
