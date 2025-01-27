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
import logging
import os

logging.basicConfig(level=logging.INFO)


def main(input_folder, output_prefix):
    expected_bac_name = "gtdbtk.bac120.summary.tsv"
    expected_arch_name = "gtdbtk.ar53.summary.tsv"
    
    process_file(os.path.join(input_folder, "classify", expected_bac_name), output_prefix, input_folder)
    process_file(os.path.join(input_folder, "classify", expected_arch_name), output_prefix, input_folder)
    

def process_file(input_file, prefix, input_folder):
    if not os.path.isfile(input_file):
        logging.info("File {} does not exist. Skipping.".format(input_file))
        return True
    
    output_file = os.path.join(input_folder, "classify", "{}_{}".format(prefix, os.path.basename(input_file)))
    
    replacement_flag = False
    
    with open(input_file, "r") as file_in, open(output_file, "w") as file_out:
        for line in file_in:
            if line.startswith("user_genome"):
                file_out.write(line)
            else:
                new_taxonomy = ""
                taxonomy = line.split("\t")[1]
                if taxonomy.lower() == "unclassified bacteria":
                    new_taxonomy = "d__Bacteria;p__;c__;o__;f__;g__;s__"
                elif taxonomy.lower() == "unclassified archaea":
                    new_taxonomy = "d__Archaea;p__;c__;o__;f__;g__;s__"
                elif taxonomy.lower() == "unclassified":
                    new_taxonomy = "d__;p__;c__;o__;f__;g__;s__"
                if new_taxonomy:
                    line = line.replace(taxonomy, new_taxonomy)
                    genome = line.split("\t")[0]
                    logging.info("Replaced taxonomy for genome {} from {} to {}".format(genome, taxonomy, new_taxonomy))
                    replacement_flag = True
                file_out.write(line)
        if not replacement_flag:
            logging.info("No replacements were made in file {}".format(input_file))
            os.remove(output_file)
    return True
    
    
def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "GTDB outputs genomes that are filtered out during the alignment step as Unclassified Bacteria/Archaea "
            "and genomes that cannot be assigned to a domain as Unclassified. This creates format inconsistency in "
            "the pipeline and breaks tools that rely on the usual GTDB format. "
            "This script reformats these three types of taxonomy outputs to be in line with the expected format."
        )
    )
    parser.add_argument(
        "-i",
        "--input-folder",
        help=(
            "Folder containing GTDB results."
        ),
    )
    parser.add_argument(
        "-p",
        "--output-prefix",
        help=(
            "Prefix to assign to the output files."
        ),
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.input_folder,
        args.output_prefix,
    )
