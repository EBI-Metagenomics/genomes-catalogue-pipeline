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

import os
import sys
import argparse
import json


def get_metadata(species_name, coverage, fasta, biome, metadata_file):
    cov = get_annotcov(
        coverage
    )  # cov contains 2 values: IPS coverage and eggNOG coverage
    num_proteins = get_cdscount(fasta)
    with open(metadata_file, "r") as f:
        linen = 0
        geo_range = set()
        for line in f:
            linen += 1
            cols = line.rstrip().split("\t")
            mgnify = cols[13]  # mgnify accession of species rep
            species = mgnify  # species rep
            if mgnify == species_name:
                geo_range.add(cols[18])  # continent
                if species == cols[0]:  # means this is the representative
                    species_code = species
                    genome_accession = cols[
                        12
                    ]  # old accession (original one with which it was fetched)
                    sample_accession = cols[15]
                    study_accession = cols[16]
                    geo_origin = cols[18]  # continent
                    complet = float(cols[6])
                    cont = float(cols[7])
                    gtype = cols[1]
                    genome_length = int(cols[2])
                    n_contigs = int(cols[3])
                    n50 = int(cols[4])
                    gc_content = float(cols[5])
                    tax_lineage = cols[14]
                    rna_5s = float(cols[8])
                    rna_16s = float(cols[9])
                    rna_23s = float(cols[10])
                    trnas = int(cols[11])
    geo_range = list(geo_range)
    try:
        geo_range.remove("not provided")
    except:
        pass
    return (
        geo_range,
        species_code,
        {
            "accession": species_name,
            "length": genome_length,
            "num_contigs": n_contigs,
            "n_50": n50,
            "gc_content": gc_content,
            "num_proteins": num_proteins,
            "taxon_lineage": tax_lineage,
            "gold_biome": biome,
            "genome_accession": genome_accession,
            "sample_accession": sample_accession,
            "study_accession": study_accession,
            "type": gtype,
            "geographic_origin": geo_origin,
            "completeness": complet,
            "contamination": cont,
            "eggnog_coverage": cov[-1],
            "ipr_coverage": cov[0],
            "rna_5s": rna_5s,
            "rna_16s": rna_16s,
            "rna_23s": rna_23s,
            "trnas": trnas,
        },
    )


def get_cdscount(fasta):
    cds = 0
    with open(fasta) as f:
        for line in f:
            if line.startswith(">"):
                cds += 1
    return cds


def get_genecount(list_file):
    count = 0
    with open(list_file, "r") as file_in:
        for line in file_in:
            if line.strip() != "":
                count += 1
    return count


def get_annotcov(annot):
    with open(annot) as f:
        linen = 0
        for line in f:
            linen += 1
            if linen > 1:
                cols = line.rstrip().split("\t")
                if cols[1] == "InterProScan":
                    ipr_cov = float(cols[-1])
                elif cols[1] == "eggNOG":
                    eggnog_cov = float(cols[-1])
    return ipr_cov, eggnog_cov


def count_total_genomes(species_code, metadata_file):
    count = 0
    with open(metadata_file, "r") as file_in:
        for line in file_in:
            fields = line.strip().split("\t")
            if fields[13] == species_code:
                count += 1
    return count


def get_pangenome(core, pangenome_fasta, species_code, metadata_file):
    pangenome_size = get_cdscount(pangenome_fasta)
    core_count = get_genecount(core)
    access_count = pangenome_size - core_count
    num_genomes_total = count_total_genomes(species_code, metadata_file)
    return {
        "num_genomes_total": num_genomes_total,
        "num_genomes_non_redundant": num_genomes_total,
        "pangenome_size": pangenome_size,
        "pangenome_core_size": core_count,
        "pangenome_accessory_size": access_count,
    }


def get_ncrnas(gff):
    nc_rnas = 0
    with open(gff) as f:
        for line in f:
            if line.startswith(">"):
                break
            else:
                if not line.startswith("#"):
                    line = line.rstrip()
                    cols = line.split("\t")
                    if cols[2] == "ncRNA":
                        nc_rnas += 1
    return {"nc_rnas": nc_rnas}


def merge_dicts(*dict_args):
    result = {}
    for dictionary in dict_args:
        result.update(dictionary)
    return result


def write_obj_2_json(obj, filename):
    with open(filename, "w") as fp:
        json.dump(obj, fp, indent=4, sort_keys=True)


def get_files(folder, species_name, cluster_structure):
    if cluster_structure:
        protein_fasta = os.path.join(folder, "genome", species_name + ".faa")
        pangenome_fasta_path = os.path.join(
            folder, "pan-genome", species_name + ".pan-genome.fna"
        )
        pangenome_core_path = os.path.join(
            folder, "pan-genome", species_name + ".core_genes.txt"
        )
    else:
        protein_fasta = os.path.join(folder, species_name + ".faa")
        pangenome_fasta_path = os.path.join(folder, species_name + ".pan-genome.fna")
        pangenome_core_path = os.path.join(folder, species_name + ".core_genes.txt")
    pangenome_fasta = (
        pangenome_fasta_path if os.path.exists(pangenome_fasta_path) else None
    )
    pangenome_core = (
        pangenome_core_path if os.path.exists(pangenome_core_path) else None
    )
    return protein_fasta, pangenome_fasta, pangenome_core


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate species summary stats for species reps",
    )
    parser.add_argument(
        "--species-faa",
        required=True,
        help="The prefix (such as MGYG).faa file., pangenome.fasta, core_genes",
    )
    parser.add_argument(
        "--pangenome-fna",
        required=True,
        help="The genome - pangenome fasta.",
    )
    parser.add_argument(
        "--core-genes", required=True, help="The core genes from panaroo."
    )
    parser.add_argument(
        "--annot-cov", help="Path to the genome annotation coverage file", required=True
    )
    parser.add_argument("--gff", help="Path to the gff file", required=True)
    parser.add_argument(
        "--output-file",
        dest="out_file",
        help="Output json filename [REQUIRED]",
        required=True,
    )
    parser.add_argument(
        "--biome",
        help="Full biome. Example: root:Host-Associated:Human:Digestive System:"
        "Large intestine",
        required=True,
    )
    parser.add_argument("--species-name", help="Species name (MGYG...)", required=True)
    parser.add_argument(
        "--metadata-file", help="Path to the metadata table", required=True
    )
    parser.add_argument(
        "--cluster-structure",
        help="Cluster has folders genome and pan-genome, "
        "otherwise all files are in the same folder",
        action="store_true",
    )

    args = parser.parse_args()
    species_name = args.species_name
    protein_fasta, pangenome_fasta, pangenome_core = get_files(
        folder=os.getcwd(),
        species_name=species_name,
        cluster_structure=args.cluster_structure,
    )
    # Genome is a main representative
    meta_res = get_metadata(
        species_name, args.annot_cov, protein_fasta, args.biome, args.metadata_file
    )
    meta_dict = meta_res[-1]
    species_code = meta_res[1]
    # check genome accession
    if meta_dict["genome_accession"][:3] in ["GCF", "GCA"]:
        meta_dict["ncbi_genome_accession"] = meta_dict.pop("genome_accession")
    # check sample accessions
    if meta_dict["sample_accession"][:3] == "SAM":
        meta_dict["ncbi_sample_accession"] = meta_dict.pop("sample_accession")
    elif meta_dict["sample_accession"][1:3] == "RS":
        meta_dict["ena_sample_accession"] = meta_dict.pop("sample_accession")
    # check study accessions
    if meta_dict["study_accession"][:3] == "PRJ":
        meta_dict["ncbi_study_accession"] = meta_dict.pop("study_accession")
    elif meta_dict["study_accession"][1:3] == "RP":
        meta_dict["ena_study_accession"] = meta_dict.pop("study_accession")

    ncrnas = get_ncrnas(args.gff)

    output = merge_dicts(meta_dict, ncrnas)
    delete_dict = dict()
    for key in output.keys():
        if output[key] == "NA" or not output[key] and output[key] != 0:
            delete_dict[key] = output[key]
    for key in delete_dict:
        del output[key]
    if pangenome_fasta and pangenome_core:
        pangenome = get_pangenome(
            pangenome_core, pangenome_fasta, species_code, args.metadata_file
        )
        pangenome["geographic_range"] = meta_res[0]
        output["pangenome"] = pangenome

    write_obj_2_json(output, args.out_file)
