#!/usr/bin/env python3
# coding=utf-8

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


import argparse
import os
from shutil import copy


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "This script copies genomes from ENA and NCBI folders "
            "to common folder. It also unites csv files"
        )
    )
    parser.add_argument(
        "--kingdom", 
        required=False, 
        help="euk or prok genomes", 
        default="prok"
    )
    parser.add_argument(
        "--ena", 
        required=True, 
        help="path to folder with ENA genomes"
    )
    parser.add_argument(
        "--ncbi", 
        required=True, 
        help="path to folder with NCBI genomes"
    )
    parser.add_argument(
        "--outname", 
        required=False, 
        help="name of output folder", 
        default="genomes"
    )
    parser.add_argument(
        "--ena-csv",
        required=False,
        help="ena csv file with completeness and contamination",
    )
    parser.add_argument(
        "--ncbi-csv",
        required=False,
        help="ncbi csv file with completeness and contamination",
    )
    parser.add_argument(
        "--ena-eukcc-csv",
        required=False,
        help="ena csv file with eukcc completeness and contamination"
    )
    parser.add_argument(
        "--ena-busco-csv",
        required=False,
        help="ena csv file with busco completeness and contamination"
    )
    parser.add_argument(
        "--ncbi-eukcc-csv",
        required=False,
        help="ncbi csv file with eukcc completeness and contamination"
    )
    parser.add_argument(
        "--ncbi-busco-csv",
        required=False,
        help="ncbi csv file with busco completeness and contamination"
    )
    
    args = parser.parse_args()

    prok_args = [args.ena_csv, args.ncbi_csv]
    euk_args = [args.ena_eukcc_csv, args.ena_busco_csv, args.ncbi_eukcc_csv, args.ncbi_busco_csv]

    if args.kingdom == "prok" and any(euk_args):
        parser.error("For 'prok' kingdom, only --ena-csv or --ncbi-csv can be used.")
    elif args.kingdom == "euk" and any(prok_args):
        parser.error("For 'euk' kingdom, only --ena-eukcc-csv, --ena-busco-csv, --ncbi-eukcc-csv, or --ncbi-busco-csv can be used.")

    return args


def copy_genomes(data, outname):
    for item in os.listdir(data):
        if item.endswith(("fa", "fa.gz", "fasta", "fasta.gz", "fna", "fna.gz")):
            copy(
                os.path.join(data, item), os.path.join(outname, os.path.basename(item))
            )


def process_csv(csv, out_csv, type="def"):
    with open(csv, "r") as input_csv:
        for line in input_csv:
            if not "completeness" in line:
                out_csv.write(f"{line.rstrip()}\n")

    return out_csv


def main(args):
    # directory
    if not os.path.exists(args.outname):
        os.mkdir(args.outname)
    if args.ena:
        copy_genomes(args.ena, args.outname)
    if args.ncbi:
        copy_genomes(args.ncbi, args.outname)
    # csv
    if args.kingdom == "prok":
        out_csv = args.outname + ".csv"
        with open(out_csv, "w") as output:
            output.write("genome,completeness,contamination\n")
            if args.ena_csv:
                output = process_csv(args.ena_csv, output)
            if args.ncbi_csv:
                output = process_csv(args.ncbi_csv, output)
    elif args.kingdom == "euk":
        busco_out_csv = args.outname + "_busco.tsv"
        with open(busco_out_csv, "w") as busco_output:
            busco_output.write("genome\tbusco_score\n")
            if args.ena_busco_csv:
                busco_output = process_csv(args.ena_busco_csv, busco_output)
            if args.ncbi_busco_csv:
                busco_output = process_csv(args.ncbi_busco_csv, busco_output)            
        eukcc_out_csv = args.outname + "_eukcc.csv"
        with open(eukcc_out_csv, "w") as eukcc_output:
            eukcc_output.write("genome,completeness,contamination\n")
            if args.ena_eukcc_csv:
                eukcc_output = process_csv(args.ena_eukcc_csv, eukcc_output)
            if args.ncbi_eukcc_csv:
                busco_output = process_csv(args.ncbi_eukcc_csv, eukcc_output)              

if __name__ == "__main__":
    main(parse_args())
