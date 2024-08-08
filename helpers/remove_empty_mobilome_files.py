#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Copyright 2024 EMBL - European Bioinformatics Institute
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
import glob
import os


def main(results_folder):
    pattern = os.path.join(results_folder, "species_catalogue", '**', '*_mobilome.gff')
    all_matching_files = glob.glob(pattern, recursive=True)
    filtered_files = [file for file in all_matching_files if os.path.basename(file).count('_') == 1]
    for mobilome_file in filtered_files:
        file_has_contents = evaluate_file(mobilome_file)
        if not file_has_contents:
            print("Cleaning {}".format(mobilome_file))
            with open(mobilome_file, "w") as f_out:
                f_out.write("##gff-version 3\n")
        
        
def evaluate_file(mobilome_file):
    with open(mobilome_file, 'r') as f:
        for line in f:
            if line.startswith("##FASTA"):
                return False
            elif not line.startswith("##"):
                return True


def parse_args():
    parser = argparse.ArgumentParser(
        description="The script goes through the catalogue results folder and replaces the mobilome GFF with "
                    "an empty, header-only GFF file if there are no mobilome lines in it. This is to account "
                    "for the fact that the mobilome pipeline outputs a file with just the headers and the original "
                    "fasta sequences if there are no mobilome results."
    )
    parser.add_argument(
        "-i", "--input-directory",
        required=True,
        help="Path to the catalogue results folder",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args.input_directory)
    
