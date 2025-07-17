#!/usr/bin/env python3
# coding=utf-8

# This file is part of MGnify genomes catalogue pipeline.
#
# MGnify genomes catalogue pipeline is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MGnify genomes catalogue pipeline is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with MGnify genomes catalogue pipeline. If not, see <https://www.gnu.org/licenses/>.


import argparse


def read_failed_accessions(filepath):
    with open(filepath, 'r') as f:
        return set(line.strip() for line in f if line.strip())


def process_name_mapping(mapping_file, failed_accessions):
    valid_original_accessions = []

    with open(mapping_file, 'r') as f:
        for line in f:
            if not line.strip():
                continue
            original, assigned = line.strip().split('\t')
            # Strip .fa or other extensions
            assigned_base = assigned.rsplit('.', 1)[0]
            if assigned_base not in failed_accessions:
                original_base = original.rsplit('.', 1)[0]
                valid_original_accessions.append(original_base)

    return valid_original_accessions


def main():
    parser = argparse.ArgumentParser(description="Print original accessions of genomes that passed QS50 and GUNC.")
    parser.add_argument('--gunc-failed', required=True, help='File with accessions that failed GUNC.')
    parser.add_argument('--name-mapping', required=True, help='File with original and MGYG accession mapping.')
    parser.add_argument('--output', required=True, help='Output file for genome accessions that passed QC.')
    args = parser.parse_args()

    failed_accessions = read_failed_accessions(args.gunc_failed)
    valid_names = process_name_mapping(args.name_mapping, failed_accessions)

    with open(args.output, 'w') as out_f:
        for name in valid_names:
            out_f.write(name + '\n')


if __name__ == '__main__':
    main()
