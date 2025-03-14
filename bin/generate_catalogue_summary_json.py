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
import json
import sys


def main(protein_count_file, metadata_table_file, outfile):
    results = dict()
    num_proteins = load_proteins(protein_count_file)
    num_clusters_with_isolates, num_multigenome_clusters = load_metadata(metadata_table_file)
    results["Total proteins"] = num_proteins
    results["Clusters with isolate genomes"] = num_clusters_with_isolates
    results["Clusters with pan-genomes"] = num_multigenome_clusters
    save_dict_to_json(results, outfile)
    

def load_metadata(metadata_table_file):
    clusters = dict()
    isolate_clusters = list()
    num_singletons = 0
    # Read in the information
    with open(metadata_table_file) as file_in:
        header = next(file_in)
        header_fields = header.strip().split("\t")
        genome_index = header_fields.index("Genome")
        rep_index = header_fields.index("Species_rep")
        genome_type_index = header_fields.index("Genome_type")
        for line in file_in:
            fields = line.strip().split("\t")
            genome = fields[genome_index]
            species_rep = fields[rep_index]
            genome_type = fields[genome_type_index]
            clusters.setdefault(species_rep, list()).append(genome)
            # if any cluster member is an isolate, save the cluster rep into the isolate list
            if genome_type == "Isolate":
                if species_rep not in isolate_clusters:
                    isolate_clusters.append(species_rep)
    
    # Count singletons
    num_singletons = sum(1 for genome_list in clusters.values() if len(genome_list) > 1)

    return len(isolate_clusters), num_singletons
            
    
def load_proteins(file):
    with open(file) as f:
        return f.readline().strip()

    
def save_dict_to_json(data, filename):
    """Saves a dictionary to a file in JSON format."""
    try:
        with open(filename, 'w', encoding='utf-8') as file:
            json.dump(data, file, indent=4, ensure_ascii=False)
    except Exception as e:
        sys.exit(f"Error saving dictionary: {e}")


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "The script generates a JSON file containing a catalogue summary."
        )
    )
    parser.add_argument('-p', '--protein-count', required=True, help="A text file containing the number of proteins "
                                                                     "in the catalogue (from mmseqs)")
    parser.add_argument('-m', '--metadata-table', required=True, help="Path to the metadata file")
    parser.add_argument('-o', '--outfile', required=True, help="Path to the output JSON file.")
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.protein_count, args.metadata_table, args.outfile)