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
import json
import re
import os
import sys


def get_metadata(species_name, coverage, fasta, biome, metadata_file, euk_flag=False):
    cov = get_annotcov(
        coverage
    )  # cov contains 2 values: IPS coverage and eggNOG coverage
    num_proteins = get_cdscount(fasta)
    with open(metadata_file, "r") as f:
        geo_range = set()
        header = next(f)
        field_indices = get_field_indices(header)
        for line in f:
            cols = line.rstrip().split("\t")
            species_rep_accession = cols[field_indices["Species_rep"]]  # mgnify accession of species rep
            if (
                species_rep_accession == species_name
            ):  # we are running the script on 1 species at a time
                geo_range.add(cols[field_indices["Continent"]])  # continent
                
                if species_rep_accession == cols[field_indices["Genome"]]:  # means this is the representative
                    tax_lineage = cols[field_indices["Lineage"]]
                    tax_lineage = "d__unclassified" if tax_lineage.startswith("d__;p__;") else tax_lineage
                    species_info = {
                        "accession": species_name,
                        "length": int(cols[field_indices["Length"]]),
                        "num_contigs": int(cols[field_indices["N_contigs"]]),
                        "n_50": int(cols[field_indices["N50"]]),
                        "gc_content": float(cols[field_indices["GC_content"]]),
                        "num_proteins": num_proteins,
                        "taxon_lineage": tax_lineage,
                        "gold_biome": biome,
                        "genome_accession": cols[field_indices["Genome_accession"]],  # this is the INSDC accession
                        "sample_accession": cols[field_indices["Sample_accession"]],
                        "study_accession": cols[field_indices["Study_accession"]],
                        "type": cols[field_indices["Genome_type"]],
                        "geographic_origin": cols[field_indices["Continent"]],
                        "completeness": float(cols[field_indices["Completeness"]]),
                        "contamination": float(cols[field_indices["Contamination"]]),
                        "eggnog_coverage": cov[-1],
                        "ipr_coverage": cov[0],
                        "trnas": int(cols[field_indices["tRNAs"]]),
                    }
                    if euk_flag:
                        species_info.update({
                            "rna_5s": float(cols[field_indices["rRNA_5S"]]),
                            "rna_5.8s": float(cols[field_indices["rRNA_5.8S"]]),
                            "rna_18s": float(cols[field_indices["rRNA_18S"]]),
                            "rna_28s": float(cols[field_indices["rRNA_28S"]]),
                        })
                        busco_text = cols[field_indices["BUSCO_quality"]]
                        match = re.search(r"Complete:(\d+\.\d+)%", busco_text)
                        species_info.update({
                            "busco_completeness": float(match.group(1))
                        })
                    else:
                        species_info.update({
                            "rna_5s": float(cols[field_indices["rRNA_5S"]]),
                            "rna_16s": float(cols[field_indices["rRNA_16S"]]),
                            "rna_23s": float(cols[field_indices["rRNA_23S"]]),
                        })

    geo_range = list(geo_range)

    try:
        geo_range.remove("not provided")
    except Exception:
        pass

    return (
        geo_range,
        species_name,
        species_info,
    )


def get_field_indices(header):
    fields = header.strip().split("\t")
    field_indices = dict()
    for field in ["Genome", "Genome_type", "Length", "N_contigs", "N50", "GC_content", "Lineage", "Genome_accession", 
                  "Sample_accession", "Study_accession", "Continent", "Completeness", "Contamination", "Species_rep",
                  "rRNA_5S", "rRNA_16S", "rRNA_23S", "rRNA_5.8S", "rRNA_18S", "rRNA_28S", "BUSCO_quality", "tRNAs"]:
        try:
            field_indices[field] = fields.index(field)
        except ValueError:
            if field in ["rRNA_16S", "rRNA_23S", "rRNA_5.8S", "rRNA_18S", "rRNA_28S", "BUSCO_quality"]:
                continue
            else:
                print(f"Error: Required field '{field}' is missing. Exiting.")
                sys.exit(1)
    return field_indices
    

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
                    if cols[2] in ["ncRNA", "rRNA"]:
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


def main(
    species_faa,
    pangenome_fna,
    core_genes,
    annot_cov,
    gff,
    out_file,
    biome,
    species_accession,
    metadata_file,
    euk_flag,
):
    # Get metadata for the genome we are running the script on (it will be a species rep because
    # we only make JSON files for reps
    meta_res = get_metadata(
        species_accession, annot_cov, species_faa, biome, metadata_file, euk_flag=euk_flag
    )
    meta_dict = meta_res[-1]
    species_code = meta_res[1]

    # check genome accession
    if meta_dict["genome_accession"][:3] in ["GCF", "GCA"]:
        meta_dict["ncbi_genome_accession"] = meta_dict.pop("genome_accession")

    # check sample accessions
    if meta_dict["sample_accession"][:3] == "SAM":
        meta_dict["ena_sample_accession"] = meta_dict.pop("sample_accession")

    elif meta_dict["sample_accession"][1:3] == "RS":
        if meta_dict["sample_accession"].startswith("S"):
            meta_dict["ncbi_sample_accession"] = meta_dict.pop("sample_accession")
        else:
            meta_dict["ena_sample_accession"] = meta_dict.pop("sample_accession")

    # check study accessions
    if meta_dict["study_accession"][:3] == "PRJ":
        meta_dict["ncbi_study_accession"] = meta_dict.pop("study_accession")
    elif meta_dict["study_accession"][1:3] == "RP":
        meta_dict["ena_study_accession"] = meta_dict.pop("study_accession")

    ncrnas = get_ncrnas(gff)

    output = merge_dicts(meta_dict, ncrnas)

    delete_dict = dict()
    for key in output.keys():
        if output[key] == "NA" or not output[key] and output[key] != 0:
            delete_dict[key] = output[key]

    for key in delete_dict:
        del output[key]

    if (
        pangenome_fna
        and core_genes
        and os.path.exists(pangenome_fna)
        and os.stat(pangenome_fna).st_size
        != 0  # this is required because nextflow submits an empty file
    ):
        pangenome = get_pangenome(
            core_genes, pangenome_fna, species_code, metadata_file
        )
        pangenome["geographic_range"] = meta_res[0]
        output["pangenome"] = pangenome

    write_obj_2_json(output, out_file)


def parse_args():
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
        required=False,
        help="The genome - pangenome fasta.",
    )
    parser.add_argument(
        "--core-genes", required=False, help="The core genes from panaroo."
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
        help="Full biome. Example: root:Host-Associated:Human:Digestive System:Large intestine",
        required=True,
    )
    parser.add_argument(
        "--species-name", help="Species accession (MGYG...)", required=True
    )
    parser.add_argument(
        "--metadata-file", help="Path to the metadata table", required=True
    )
    parser.add_argument(
        "--euk", help="Add this flag if the catalogue is eukaryotic", action='store_true'
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.species_faa,
        args.pangenome_fna,
        args.core_genes,
        args.annot_cov,
        args.gff,
        args.out_file,
        args.biome,
        args.species_name,
        args.metadata_file,
        args.euk,
    )
