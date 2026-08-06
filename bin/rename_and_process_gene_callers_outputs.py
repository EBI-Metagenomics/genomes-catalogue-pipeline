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
from typing import Dict, Tuple

from Bio import SeqIO


def main(gff, ffn, faa, genome_fasta, output_prefix) -> None:
    mgyg_accession = str(os.path.basename(genome_fasta)).split("_")[0].split(".")[0]
    gene_map = build_gene_map(faa, mgyg_accession)

    # Rename proteins in the protein FASTA file and remove any asterisks from the sequence
    rename_fasta(faa, output_prefix, gene_map, remove_asterisks=True)
    # Rename CDS in the coding sequence FASTA file
    rename_fasta(ffn, output_prefix, gene_map)

    # Create a GFF header from the genome assembly file and store the assembly in a variable
    gff_header, genome_fasta_contents = process_genome_fasta(genome_fasta)

    # Generate a new GFF file - add a header, add FASTA at the bottom, rename IDs and add product
    remake_gff(gff_header, genome_fasta_contents, gene_map, gff, output_prefix)


def add_original_gene_id(col9: str, original_gene_id: str) -> str:
    """Add original_gene_id=<id> to a gene's attributes, unless the field is already present.

    The BRAKER+MetaEuk merge (merge_gene_predictions.py) already records original_gene_id, but a
    BRAKER-only genome bypasses that step and would otherwise lose its original gene caller ID once
    it is replaced by the MGYG accession, so the field is back-filled here.
    """
    if "original_gene_id=" in col9:
        return col9
    if col9 and not col9.endswith(";"):
        col9 += ";"
    return f"{col9}original_gene_id={original_gene_id}"


def remake_gff(gff_header, genome_fasta_contents, gene_map, gff, output_prefix) -> None:
    gff_outfile = f"{output_prefix}.gff"
    with open(gff_outfile, "w") as gff_out:
        # Write the header to file
        gff_out.write(gff_header + "\n")

        # Iterate through GFF lines, rename features and add product
        with open(gff, "r") as gff_in:
            for line in gff_in:
                if line.startswith("#"):
                    continue
                fields = line.strip().split("\t")
                if len(fields) == 9:
                    col9 = fields[8]
                    feature = fields[2]

                    def replace_id(match) -> str:
                        gene_id = match.group(1)
                        return f"ID={gene_map.get(gene_id, gene_id)}"

                    def replace_parent(match) -> str:
                        gene_id = match.group(1)
                        return f"Parent={gene_map.get(gene_id, gene_id)}"

                    original_gene_id = None
                    if feature == "gene":
                        id_match = re.search(r"ID=(g\d+)", col9)
                        if id_match:
                            original_gene_id = id_match.group(1)

                    col9 = re.sub(r"ID=(g\d+)", replace_id, col9)
                    col9 = re.sub(r"Parent=(g\d+)", replace_parent, col9)

                    if feature == "gene" and original_gene_id is not None:
                        col9 = add_original_gene_id(col9, original_gene_id)

                    if feature == "CDS" and "product=" not in col9:
                        # the lines do not always end with a semicolon (e.g. BRAKER vs MetaEuk), so add one if needed
                        if col9 and not col9.endswith(";"):
                            col9 += ";"
                        col9 += "product=hypothetical protein"

                    fields[8] = col9
                    gff_out.write("\t".join(fields) + "\n")

                else:
                    gff_out.write(line)
        gff_out.write("##FASTA\n")
        gff_out.write(genome_fasta_contents + "\n")


def process_genome_fasta(fasta_file) -> Tuple[str, str]:
    header = ["##gff-version 3"]

    with open(fasta_file, "r") as f:
        fasta_content = f.readlines()

    for record in SeqIO.parse(fasta_file, "fasta"):
        seq_id = record.id
        length = len(record.seq)
        header.append(f"##sequence-region {seq_id} 1 {length}")

    return "\n".join(header), "".join(fasta_content)


def build_gene_map(fasta_file, mgyg_accession) -> Dict[str, str]:
    """Map each gene caller gene ID to an MGYG accession."""
    gene_map = {}
    for record in SeqIO.parse(fasta_file, "fasta"):
        gene_name = record.id.split(".")[0]
        if gene_name not in gene_map:
            gene_number = int(gene_name[1:])  # drop the 'g' prefix
            gene_map[gene_name] = f"{mgyg_accession}_{gene_number:05d}"
    return gene_map


def rename_fasta(input_file, output_prefix, gene_map, remove_asterisks=False) -> None:
    """Rename FASTA records using gene_map (g<n>.t<m> -> <mgyg>_<n>.t<m>) and clean the headers."""
    extension = input_file.rsplit(".", 1)[-1]
    output_fasta = f"{output_prefix}.{extension}"
    with open(output_fasta, "w") as output_handle:
        for record in SeqIO.parse(input_file, "fasta"):
            gene_name, transcript_name = record.id.split(".")
            record.id = f"{gene_map[gene_name]}.{transcript_name}"
            record.description = ""  # Remove additional descriptions
            if remove_asterisks:
                record.seq = record.seq.replace("*", "")
            SeqIO.write(record, output_handle, "fasta")


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "The script assigns MGYG accessions to eukaryotic proteins and renames them in all of the files "
            "produced by the gene caller(s) (BRAKER3 or the merged set of BRAKER3 + MetaEuk). The script also "
            "reformats the GFF3 file, adding a header, the product field to the 9th column, the "
            "original_gene_id attribute on gene features (back-filled when absent), and the genome "
            "sequence to the end of the file."
        )
    )
    parser.add_argument(
        "--gff",
        required=True,
        help=("Path to the gff3 file produced by the gene caller."),
    )
    parser.add_argument(
        "--ffn",
        required=True,
        help=("Path to the CDS file produced by the gene caller."),
    )
    parser.add_argument(
        "--faa",
        required=True,
        help=("Path to the FAA file produced by the gene caller."),
    )
    parser.add_argument(
        "--genome-fasta",
        required=True,
        help=("Path to the genome FASTA file, with contigs renamed to MGYG."),
    )
    parser.add_argument(
        "-p",
        "--output-prefix",
        required=False,
        default="renamed",
        help=("Prefix to assign to the output file names. Default: renamed"),
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args.gff, args.ffn, args.faa, args.genome_fasta, args.output_prefix)
