#!/usr/bin/env python3

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
import csv
import sys


def main(metadata_table, prefix):
    outfile_quality = f'{prefix}_checkm_quality.csv'
    outfile_stats = f'{prefix}_assembly_stats.tsv'
    with (open(metadata_table, "r") as file_in, open(outfile_quality, "w") as checkm_out,
          open(outfile_stats, "w") as stats_out):
        csv_writer_checkm = csv.writer(checkm_out)
        csv_writer_stats = csv.writer(stats_out, delimiter='\t')
        header = file_in.readline()
        fields = header.strip().split("\t")
        genome_idx = get_field_index("Genome", fields, metadata_table)
        comp_idx = get_field_index("Completeness", fields, metadata_table)
        cont_idx = get_field_index("Contamination", fields, metadata_table)
        n50_idx = get_field_index("N50", fields, metadata_table)
        length_idx = get_field_index("Length", fields, metadata_table)
        gc_idx = get_field_index("GC_content", fields, metadata_table)
        num_contigs_idx = get_field_index("N_contigs", fields, metadata_table)

        # write headers
        csv_writer_stats.writerow(["Genome", "Length", "N50", "GC_content", "N_contigs"])
        csv_writer_checkm.writerow(["genome", "completeness", "contamination"])

        for line in file_in:
            parts = line.strip().split("\t")
            csv_writer_stats.writerow([parts[genome_idx], parts[length_idx], parts[n50_idx], parts[gc_idx], 
                                       parts[num_contigs_idx]])
            csv_writer_checkm.writerow([f"{parts[genome_idx]}.fa", parts[comp_idx], parts[cont_idx]])


def get_field_index(field_name, fields, metadata_table):
    if field_name in fields:
        return fields.index(field_name)
    else:
        sys.exit(f"Cannot find {field_name} field in {metadata_table}")


def parse_args():
    parser = argparse.ArgumentParser(description='The script is part of the catalogue update pipeline. It takes the '
                                                 'metadata table from the previous catalogue version and regenerates '
                                                 'a CheckM output file and an assembly statistics file.')
    parser.add_argument('-i', dest='metadata_table', required=True, help='Location of the metadata table from the '
                                                                         'previous catalogue version.')
    parser.add_argument('-o', dest='prefix', required=True, help='Prefix for the output files.')

    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.metadata_table, args.prefix)
