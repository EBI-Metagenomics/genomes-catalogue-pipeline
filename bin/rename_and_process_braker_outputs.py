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
import re
import os

from Bio import SeqIO


def main(gff, ffn, faa, genome_fasta, output_prefix):
    mgyg_accession = str(os.path.basename(genome_fasta)).split('_')[0]
    # Rename proteins in the protein FASTA file and remove any asterisks from the sequence
    gene_map = rename_fasta(faa, output_prefix, mgyg_accession, create_dictionary=True, remove_asterisks=True)
    # Rename CDS in the coding sequence FASTA file
    rename_fasta(ffn, output_prefix, mgyg_accession, gene_map)
    
    # Create a GFF header from the genome assembly file and store the assembly in a variable
    gff_header, genome_fasta_contents = process_genome_fasta(genome_fasta)
    
    # Generate a new GFF file - add a header, add FASTA at the bottom, rename IDs and add product
    gff_outfile = f"{output_prefix}_{gff}"
    remake_gff(gff_header, genome_fasta_contents, gene_map, gff, gff_outfile)


def remake_gff(gff_header, genome_fasta_contents, gene_map, gff, gff_outfile):
    with open(gff_outfile, "w") as gff_out:
        # Write the header to file
        gff_out.write(gff_header + "\n")
        
        # Iterate through GFF lines, rename features and add product
        with open(gff, "r") as gff_in:
            for line in gff_in:
                fields = line.strip().split("\t")
                if len(fields) == 9:
                    col9 = fields[8]
                    feature = fields[2]

                    def replace_id(match):
                        gene_id = match.group(1)
                        return f"ID={gene_map.get(gene_id, gene_id)}"

                    def replace_parent(match):
                        gene_id = match.group(1)
                        return f"Parent={gene_map.get(gene_id, gene_id)}"

                    col9 = re.sub(r"ID=(g\d+)", replace_id, col9)
                    col9 = re.sub(r"Parent=(g\d+)", replace_parent, col9)
                    
                    if feature == "CDS":
                        col9 += "product=hypothetical protein"  # braker's lines already end with a semicolon

                    fields[8] = col9
                    gff_out.write("\t".join(fields) + "\n")
                    
                else:
                    gff_out.write(line)
        gff_out.write("##FASTA\n")
        gff_out.write(genome_fasta_contents + "\n")


def process_genome_fasta(fasta_file):
    header = ["##gff-version 3"]
    
    with open(fasta_file, "r") as f:
        fasta_content = f.readlines()

    for record in SeqIO.parse(fasta_file, "fasta"):
        seq_id = record.id
        length = len(record.seq)
        header.append(f"##sequence-region {seq_id} 1 {length}")

    return "\n".join(header), "".join(fasta_content)
        

def rename_fasta(input_file, output_prefix, mgyg_accession, name_dictionary=None, create_dictionary=False, 
                 remove_asterisks=False):
    gene_map = {} if create_dictionary else None
    output_fasta = f"{output_prefix}_{input_file}"
    with open(output_fasta, "w") as output_handle:
        for record in SeqIO.parse(input_file, "fasta"):
            # sequences are named as g1.t1, g1.t2, g2.t1 etc., where g is followed by the gene number and t is
            # followed by the transcript number
            gene_name, transcript_name = record.id.split(".")
            if create_dictionary:
                gene_number = gene_name[1:]  # Remove 'g' prefix
                new_gene_number = f"{int(gene_number):05d}"  # Convert to 5-digit format (with 0s in front)
                new_gene_name = f"{mgyg_accession}_{new_gene_number}"
                gene_map[gene_name] = f"{mgyg_accession}_{new_gene_number}"
            else:
                new_gene_name = name_dictionary.get(gene_name)
            new_header = f"{new_gene_name}.{transcript_name}"
            record.id = new_header
            record.description = ""  # Remove additional descriptions
            if remove_asterisks:
                record.seq = record.seq.replace("*", "")
            SeqIO.write(record, output_handle, "fasta")
            
    return gene_map if create_dictionary else None
    
    
def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "The script assigns MGYG accessions to eukaryotic proteins and renames them in all of the Braker-produced "
            "files. The script also reformats the GFF3 file produced by Braker, adding a header, the product field to "
            "the 9th column, and the genome sequence to the end of the file."
        )
    )
    parser.add_argument(
        "--gff",
        required=True,
        help=(
            "Path to the gff3 file produced by Braker."
        ),
    )
    parser.add_argument(
        "--ffn",
        required=True,
        help=(
            "Path to the CDS file produced by Braker."
        ),
    )
    parser.add_argument(
        "--faa",
        required=True,
        help=(
            "Path to the FAA file produced by Braker."
        ),
    )
    parser.add_argument(
        "--genome-fasta",
        required=True,
        help=(
            "Path to the genome FASTA file, with contigs renamed to MGYG."
        ),
    )
    parser.add_argument(
        "-p",
        "--output-prefix",
        required=False,
        default="renamed",
        help=(
            "Prefix to assign to the output file names. Default: renamed"
        ),
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.gff,
        args.ffn,
        args.faa,
        args.genome_fasta,
        args.output_prefix
    )
