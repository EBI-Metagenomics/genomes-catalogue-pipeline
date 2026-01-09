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

import argparse
import os


def load_metadata_accessions(metadata_file):
    """Load the first column of metadata file, skipping the header."""
    accessions = set()
    with open(metadata_file, 'r') as f:
        next(f)  # Skip header
        for line in f:
            line = line.strip()
            if line:
                accessions.add(line.split('\t')[0])
    return accessions


def filter_clusters(input_file, output_file, valid_accessions):
    """Filter clusters file removing singletons that are not in the metadata table."""
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            line = line.strip()
            if line.startswith("many_genomes"):
                outfile.write(line + "\n")
            elif line.startswith("one_genome"):
                # Example: one_genome:2_0:MGYG000518607.fa
                parts = line.split(":")
                if len(parts) == 3:
                    accession_with_ext = parts[2]
                    accession, _ = os.path.splitext(accession_with_ext)  # remove extension
                    if accession in valid_accessions:
                        outfile.write(line + "\n")


def main():
    parser = argparse.ArgumentParser(description="Filter clusters_split.txt to remove singletons that are not present"
                                                 "in the metadata table.")
    parser.add_argument("-i", "--input", required=True, help="Path to clusters_split.txt")
    parser.add_argument("-o", "--output", required=True, help="Output filtered file")
    parser.add_argument("-m", "--metadata", required=True, help="Path to genomes-all_metadata.tsv")

    args = parser.parse_args()

    valid_accessions = load_metadata_accessions(args.metadata)
    filter_clusters(args.input, args.output, valid_accessions)


if __name__ == "__main__":
    main()
