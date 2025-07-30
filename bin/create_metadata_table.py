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
import pandas as pd
import re
import sys

from itertools import chain

from assembly_stats import run_assembly_stats

logging.basicConfig(level=logging.INFO)


def main(
    genomes_dir,
    extra_weight_table,
    checkm_results,
    rna_results,
    naming_file,
    clusters_file,
    taxonomy_file,
    location_file,
    outfile,
    ftp_name,
    ftp_version,
    gunc_failed,
    previous_metadata_table,
    precomputed_genome_stats,
    busco_output,
    euk=False,
):
    # table_columns = ['Genome', 'Genome_type', 'Length', 'N_contigs', 'N50',	'GC_content',
    #           'Completeness', 'Contamination', 'rRNA_5S', 'rRNA_16S', 'rRNA_23S', 'tRNAs', 'Genome_accession',
    #           'Species_rep', 'MGnify_accession', 'Lineage', 'Sample_accession', 'Study_accession', 'Country',
    #           'Continent', 'FTP_download']
    genome_list, genomes_ext = load_genome_list(genomes_dir, gunc_failed)
    logging.info("Loaded genome list")
    if previous_metadata_table:
        logging.info("Loading data from the previous catalogue version's metadata table")
        previous_version_data = load_previous_metadata_table(previous_metadata_table, genome_list)
    else:
        previous_version_data = pd.DataFrame()
    df = pd.DataFrame(genome_list, columns=["Genome"])
    df = add_genome_type(df, extra_weight_table)
    df = add_precomputed_stats(df, precomputed_genome_stats)
    df = add_checkm(df, checkm_results)
    if busco_output:
        df = add_busco(df, busco_output)
    logging.info("Loaded stats. Adding RNA...")
    df = add_rna(df, genome_list, rna_results, euk=euk)
    logging.info("Added RNA")
    df, original_accessions = add_original_accession(df, naming_file)
    df, reps = add_species_rep(df, clusters_file)
    df = add_taxonomy(df, taxonomy_file, genome_list, reps)
    logging.info("Added species reps and taxonomy")
    df = add_sample_project_loc(df, location_file, previous_version_data)
    logging.info("Added locations")
    df = add_ftp(df, genome_list, ftp_name, ftp_version, reps)
    df.set_index("Genome", inplace=True)
    df.to_csv(outfile, sep="\t")


def add_busco(df, busco_output):
    if not os.path.isfile(busco_output):
        return df
    busco_mapping = {
        "C": "Complete",
        "S": "Single-copy",
        "D": "Duplicated",
        "F": "Fragmented",
        "M": "Missing",
        "n": "Total BUSCOs",
        "E": "Erroneous"
    }
    pattern = r'([CSDMFEn]):([\d\.%]+)'
    busco_results = dict()
    with open(busco_output, "r") as f:
        for line in f:
            file_name, busco_line = line.strip().split("\t")
            file_name = file_name.replace(".fa", "")
            converted_busco = re.sub(pattern, lambda m: f"{busco_mapping[m.group(1)]}:{m.group(2) }", busco_line)
            file_name = file_name.replace(".fa", "")
            busco_results[file_name] = converted_busco
    df["BUSCO_quality"] = df["Genome"].map(busco_results)
    return df


def load_previous_metadata_table(previous_metadata_table, genome_list):
    columns_to_save = ["Genome", "Sample_accession", "Study_accession", "Country", "Continent"]
    previous_version_data = pd.read_csv(previous_metadata_table, sep='\t', usecols=columns_to_save)

    # filter the dataframe to only keep genomes that we are using
    previous_version_data = previous_version_data[previous_version_data["Genome"].isin(genome_list)]
    return previous_version_data


def add_ftp(df, genome_list, catalog_ftp_name, catalog_version, species_reps):
    ftp_res = dict()
    url = "ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/mgnify_genomes/{}/{}/all_genomes".format(
        catalog_ftp_name, catalog_version
    )
    for genome in genome_list:
        subfolder = species_reps[genome][:-2]
        ftp_res[genome] = "{}/{}/{}/genomes1/{}.gff.gz".format(
            url, subfolder, species_reps[genome], genome
        )
    df["FTP_download"] = df["Genome"].map(ftp_res)
    return df


def add_sample_project_loc(df, location_file, previous_version_data):
    location_data_df = pd.read_csv(
        location_file,
        sep='\t',
        header=None,
        names=['Genome_accession', 'Sample_accession', 'Study_accession', 'Country', 'Continent']
    )
    df = df.merge(location_data_df, on='Genome_accession', how='left')

    # If previous version data is available, override where applicable
    if not previous_version_data.empty:
        prev_data_dict = previous_version_data.set_index("Genome").to_dict(orient="index")
        for idx, row in df.iterrows():
            genome = row["Genome"]
            if genome in prev_data_dict:
                for col in ["Sample_accession", "Study_accession", "Country", "Continent"]:
                    # TODO: add checks that this is informative (not "not provided")
                    df.at[idx, col] = prev_data_dict[genome][col]
                    
    return df


def add_taxonomy(df, taxonomy_file, genome_list, reps):
    taxonomy_result = dict()
    with open(taxonomy_file, "r") as file_in:
        for line in file_in:
            if not line.startswith("user_genome"):
                fields = line.strip().split("\t")
                taxonomy_result[fields[0]] = fields[1]
    for genome in genome_list:
        if genome not in taxonomy_result:
            taxonomy_result[genome] = taxonomy_result[reps[genome]]
    df["Lineage"] = df["Genome"].map(taxonomy_result)
    return df


def add_species_rep(df, clusters_file):
    reps = dict()
    with open(clusters_file, "r") as file_in:
        for line in file_in:
            if line.startswith("one_genome"):
                genome = line.strip().split(":")[-1].rsplit(".", 1)[0]
                reps[genome] = genome
            elif line.startswith("many_genomes"):
                fields = line.strip().split(":")
                rep = fields[2].split(".")[0]
                cluster_members = fields[2].split(",")
                for i in range(0, len(cluster_members)):
                    reps[cluster_members[i].split(".")[0]] = rep
            else:
                if not line.strip() == "":
                    logging.error("Unknown clusters file format: {}".format(line))
                    sys.exit()
    df["Species_rep"] = df["Genome"].map(reps)
    return df, reps


def add_original_accession(df, naming_file):
    conversion_table = dict()
    with open(naming_file, "r") as file_in:
        for line in file_in:
            fields = line.strip().split("\t")
            old, new = fields[0].split(".")[0], fields[1].split(".")[0]
            conversion_table[new] = old
    df["Genome_accession"] = df["Genome"].map(conversion_table)
    return df, conversion_table


def add_rna(df, genome_list, rna_folder, euk=False):
    if euk:
        rna_types = ["rRNA_5S", "rRNA_18S", "rRNA_28S", "rRNA_5.8S"]
    else:
        rna_types = ["rRNA_5S", "rRNA_16S", "rRNA_23S"]
    rna_results = dict()
    for key in chain(rna_types, ["tRNAs"]):
        rna_results.setdefault(key, dict())
    for genome in genome_list:
        rrna_file = os.path.join(rna_folder, "{}_rRNAs.out".format(genome))
        trna_file = os.path.join(
            rna_folder,
            "{}_tRNA_20aa.out".format(genome),
        )
        rna_results["tRNAs"][genome] = load_trna(trna_file)
        (
            rna_results
        ) = load_rrna(rrna_file, rna_results, euk=euk)
    for key in chain(rna_types, ["tRNAs"]):
        df[key] = df["Genome"].map(rna_results[key])
    return df


def load_rrna(rrna_file, rna_results, euk=False):
    conversion = {"SSU_rRNA_eukarya": "rRNA_18S",
                  "LSU_rRNA_eukarya": "rRNA_28S",
                  "5S_rRNA": "rRNA_5S",
                  "5_8S_rRNA": "rRNA_5.8S",
                  "SSU_rRNA": "rRNA_16S",
                  "LSU_rRNA": "rRNA_23S"}

    with open(rrna_file, "r") as file_in:
        for line in file_in:
            genome, rna_type, coverage = line.strip().split("\t")
            # In the conversion dictionary, prokaryotic SSU and LSU keys are truncated but all the other keys are 
            # shown in full. The line below checks for this to assign correct conversion.
            key = rna_type if euk or not rna_type.startswith(("SSU_rRNA", "LSU_rRNA")) else rna_type.rsplit("_", 1)[0]
            converted_rna_type = conversion[key]
            rna_results[converted_rna_type][genome] = coverage
    return rna_results


def load_trna(trna_file):
    with open(trna_file, "r") as file_in:
        return file_in.readline().strip().split("\t")[1]


def add_checkm(df, checkm_results):
    checkm_compl = dict()
    checkm_contam = dict()
    with open(checkm_results, "r") as file_in:
        for line in file_in:
            if not line.startswith("genome,"):
                fields = line.strip().split(",")
                checkm_compl[fields[0].split(".")[0]] = fields[1]
                checkm_contam[fields[0].split(".")[0]] = fields[2]
    df["Completeness"] = df["Genome"].map(checkm_compl)
    df["Contamination"] = df["Genome"].map(checkm_contam)
    return df


def add_stats(df, genomes_dir, genomes_ext):
    new_df = df.apply(
        lambda x: calc_assembly_stats(genomes_dir, x["Genome"], genomes_ext), axis=1
    )
    return pd.concat([df, new_df], axis=1)


def calc_assembly_stats(genomes_dir, acc, ext):
    file_path = os.path.join(genomes_dir, "{}.{}".format(acc, ext))
    stats = run_assembly_stats(file_path)
    return pd.Series(
        [
            int(stats["Length"]),
            int(stats["N_contigs"]),
            int(stats["N50"]),
            str(round(stats["GC_content"], 2)),
        ],
        index=["Length", "N_contigs", "N50", "GC_content"],
    )


def add_precomputed_stats(df, precomputed_genome_stats):
    columns_to_save = ["Genome", "Length", "N_contigs", "N50", "GC_content"]
    stats = pd.read_csv(precomputed_genome_stats, sep='\t', usecols=columns_to_save)
    df = df.merge(stats, on="Genome", how="left")  # Left join to keep only existing genomes in df
    # reorder columns
    df = df[[col for col in df.columns if col not in columns_to_save] + columns_to_save]
    return df


def add_genome_type(df, extra_weight_table):
    result = dict()
    with open(extra_weight_table, "r") as file_in:
        for line in file_in:
            fields = line.strip().split("\t")
            genome = fields[0].rsplit(".", 1)[0]
            if fields[1] == "0":
                result[genome] = "MAG"
            elif int(fields[1]) > 0:
                result[genome] = "Isolate"
            else:
                logging.error(
                    "Genome {} was not found in the extra weight table".format(genome)
                )
                result[genome] = ""
    df["Genome_type"] = df["Genome"].map(result)
    return df


def load_genome_list(genomes_dir, gunc_file):
    genome_list = [filename.rsplit(".", 1)[0].replace("_sm", "") for filename in os.listdir(genomes_dir)]
    genomes_ext = os.listdir(genomes_dir)[0].rsplit(".", 1)[1]
    if gunc_file and gunc_file != "EMPTY":
        with open(gunc_file, "r") as gunc_in:
            for line in gunc_in:
                acc = line.strip().split(".")[0]
                try:
                    genome_list.remove(acc)
                except:
                    logging.info(
                        "Genome {} failed GUNC and is not present in the genomes"
                        " directory".format(acc)
                    )
    return sorted(genome_list), genomes_ext


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Creates a metadata table for all new genomes to be added to the catalog"
        )
    )
    parser.add_argument(
        "-c",
        "--clusters-table",
        help="A path to the table containing cluster information (clusters_split.txt)",
    )
    parser.add_argument(
        "-e", "--extra-weight-table", help="Path to the extra weight table"
    )
    parser.add_argument(
        "-n",
        "--naming-table",
        help=(
            "Path to the names.tsv file. The file should be tab delimited with first"
            " column containing the original accession and the second column contatming"
            " the assigned accession"
        ),
    )
    parser.add_argument(
        "-o",
        "--outfile",
        required=True,
        help="Path to the output file where the metadata table will be stored",
    )
    parser.add_argument(
        "-d",
        "--genomes-dir",
        required=True,
        help=(
            "A space delimited list of paths to the directory where genomes are stored"
        ),
    )
    parser.add_argument(
        "-g",
        "--gunc-failed",
        help=(
            "Path to the file containing a list of genomes that were filtered out by"
            " GUNC"
        ),
    )
    parser.add_argument(
        "-r",
        "--rna-results",
        required=True,
        help="Path to the folder with the RNA detection results (rRNA_outs)",
    )
    parser.add_argument(
        "--checkm-results",
        required=True,
        help="Path to the file containing checkM results",
    )
    parser.add_argument(
        "--taxonomy",
        required=True,
        help=(
            "Path to the file generated by GTDB-tk"
            " (parser.add_argument(gtdbtk.bac120.summary.tsv)"
        ),
    )
    parser.add_argument(
        "--location-table",
        required=True,
        help=(
            "Path to the file generated by get_locations.py."
            "The file should be tab-delimited and contain the following columns: "
            "Original genome accession, sample accession, project accession, country, continent."
        ),
    )
    parser.add_argument(
        "--ftp-name",
        required=True,
        help="The name of the FTP folder containing the catalog",
    )
    parser.add_argument(
        "--ftp-version",
        required=True,
        help="Catalog version for the ftp (for example, v1.0",
    )
    parser.add_argument(
        "--previous-metadata-table",
        help="Path to the metadata table for the previous catalogue version. Only is used for updates.",
    )
    parser.add_argument(
        "--precomputed_genome_stats",
        help="If genome length, N50 and GC content have been pre-computed, provide path to the TSV file.",
    )
    parser.add_argument(
        "--busco-output",
        required=False,
        help="For eukaryotes, provide the Busco quality file.",
    )
    parser.add_argument(
        "--euk",
        action='store_true',
        help="Use this flag if the metadata table is being generated for a eukaryotic catalogue.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.genomes_dir,
        args.extra_weight_table,
        args.checkm_results,
        args.rna_results,
        args.naming_table,
        args.clusters_table,
        args.taxonomy,
        args.location_table,
        args.outfile,
        args.ftp_name,
        args.ftp_version,
        args.gunc_failed,
        args.previous_metadata_table,
        args.precomputed_genome_stats,
        args.busco_output,
        args.euk,
    )
