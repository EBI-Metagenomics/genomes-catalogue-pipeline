#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Copyright 2023-2025 EMBL - European Bioinformatics Institute
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
import re
import sys

logging.basicConfig(level=logging.INFO)


def main(input_folder, genome_gff, outfile, dbcan_version):
    if not check_folder_completeness(input_folder):
        sys.exit("Missing dbCAN outputs. Exiting.")
    substrates = load_substrates(input_folder)
    genome_gff_lines = load_gff(genome_gff)
    print_gff(input_folder, outfile, dbcan_version, substrates, genome_gff_lines)


def load_gff(gff):
    genome_gff_lines = dict()
    with open(gff, 'r') as gff:
        for line in gff:
            if line.startswith("##FASTA"):
                return genome_gff_lines
            
            fields = line.strip().split("\t")
            if len(fields) != 9 or fields[2] != "CDS":
                continue
            
            # Get transcript name from the 9th column
            match = re.search(r'Parent=([^;]+)', fields[8])
            transcript_name = match.group(1)
            genome_gff_lines.setdefault(transcript_name, []).append(line)
    return genome_gff_lines
                    

def print_gff(input_folder, outfile, dbcan_version, substrates, genome_gff_lines):
    with open(outfile, "w") as file_out:
        file_out.write("##gff-version 3\n")
        with open(os.path.join(input_folder, "overview.txt")) as file_in:
            for line in file_in:
                if line.startswith("MGYG"):
                    transcript, ec_number_raw, dbcan_hmmer, dbcan_sub_ecami, diamond, num_of_tools = (
                        line.strip().split("\t")
                    )
                    # EC is reported as 2.4.99.-:5 with :5 meaning 5 proteins in the subfamily have EC 2.4.99.-
                    ec_number = ec_number_raw.split(":")[0] 
                    
                    # Dbcan recommends to use subfamily preference as dbcan_hmmer > dbcan_sub_ecami > diamond
                    # diamond is messier, so we don't report it here
                    if dbcan_hmmer != "-":
                        # the field dbcan_hmmer reports match positions in parentheses, clear them out first:
                        subfamily = dbcan_hmmer.split("(")[0]
                    elif dbcan_sub_ecami != "-":
                        subfamily = dbcan_sub_ecami
                    else:
                        continue
                        
                    # Assemble information to add to the 9th column    
                    col9_parts = [
                        f"protein_family={subfamily}",
                        f"substrate_dbcan-sub={substrates.get(transcript, 'N/A')}"
                    ]

                    if ec_number != "-":
                        col9_parts.append(f"eC_number={ec_number}")

                    col9_parts.append(f"num_tools={num_of_tools}")
                    col9_text = ";".join(col9_parts)
                    
                    for gff_line in genome_gff_lines[transcript]:
                        fields = gff_line.strip().split("\t")
                        # Replace the tool
                        fields[1] = f"dbCAN:{dbcan_version}"
                        # Replace the feature
                        fields[2] = "CAZyme"
                        # Replace the confidence value
                        fields[5] = "."
                        # Keep only the ID in the 9th column
                        attributes = fields[8].split(';')[0]
                        # Add dbcan information to the 9th column
                        attributes = f"{attributes};{col9_text};"
                        fields[8] = attributes
                        file_out.write("\t".join(fields) + "\n")
                        

def load_substrates(input_folder):
    substrates = dict()
    with open(os.path.join(input_folder, "dbcan-sub.hmm.out"), "r") as file_in:
        header = next(file_in)
        header_fields = header.strip().split("\t")
        substrate_idx = header_fields.index("Substrate")
        gene_idx = header_fields.index("Gene ID")
        evalue_idx = header_fields.index("E Value")
        for line in file_in:
            fields = line.strip().split("\t")
            if float(fields[evalue_idx]) < 1e-15:  # evalue is the default from dbcan
                substrate = fields[substrate_idx]
                if not substrate == "-":
                    gene_id = fields[gene_idx]
                    substrates.setdefault(gene_id, []).append(substrate)
    # resolve cases with multiple substrates
    for gene_id, substrate_list in substrates.items():
        substrate_list = list(set(substrate_list))
        if len(substrate_list) == 1:
            substrates[gene_id] = substrate_list[0]
        else:
            substrates[gene_id] = ",".join(substrate_list)
    return substrates


def check_folder_completeness(input_folder):
    status = True
    for file in ["dbcan-sub.hmm.out", "overview.txt"]:
        if not os.path.exists(os.path.join(input_folder, file)):
            logging.error("File {} does not exist.".format(file))
            status = False
    return status


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "The script takes dbCAN output for a eukaryotic genome and parses it to create a standalone GFF."
        )
    )
    parser.add_argument(
        "-i",
        dest="input_folder",
        required=True,
        help="Path to the folder with dbCAN results.",
    )
    parser.add_argument(
        "-g",
        dest="genome_gff",
        required=True,
        help="Path to the genome GFF.",
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
    main(args.input_folder, args.genome_gff, args.outfile, args.dbcan_ver)
