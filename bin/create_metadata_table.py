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

from retry import retry

from assembly_stats import run_assembly_stats
from get_ENA_metadata import get_location, load_xml, get_gca_location
from get_NCBI_metadata import *

logging.basicConfig(level=logging.INFO)


def main(
    genomes_dir,
    extra_weight_table,
    checkm_results,
    rna_results,
    naming_file,
    clusters_file,
    taxonomy_file,
    geofile,
    outfile,
    ftp_name,
    ftp_version,
    gunc_failed,
    disable_ncbi_lookup,
):
    # table_columns = ['Genome', 'Genome_type', 'Length', 'N_contigs', 'N50',	'GC_content',
    #           'Completeness', 'Contamination', 'rRNA_5S', 'rRNA_16S', 'rRNA_23S', 'tRNAs', 'Genome_accession',
    #           'Species_rep', 'MGnify_accession', 'Lineage', 'Sample_accession', 'Study_accession', 'Country',
    #           'Continent', 'FTP_download']
    genome_list, genomes_ext = load_genome_list(genomes_dir, gunc_failed)
    logging.info("Loaded genome list")
    df = pd.DataFrame(genome_list, columns=["Genome"])
    df = add_genome_type(df, extra_weight_table)
    df = add_stats(df, genomes_dir, genomes_ext)
    df = add_checkm(df, checkm_results)
    logging.info("Loaded stats. Adding RNA...")
    df = add_rna(df, genome_list, rna_results)
    logging.info("Added rna")
    df, original_accessions = add_original_accession(df, naming_file)
    df, reps = add_species_rep(df, clusters_file)
    df = add_taxonomy(df, taxonomy_file, genome_list, reps)
    logging.info("Added species reps and taxonomy")
    df = add_sample_project_loc(df, original_accessions, geofile, disable_ncbi_lookup)
    logging.info("Added locations")
    df = add_ftp(df, genome_list, ftp_name, ftp_version, reps)
    df.set_index("Genome", inplace=True)
    df.to_csv(outfile, sep="\t")


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


def add_sample_project_loc(df, original_accessions, geofile, disable_ncbi_lookup):
    countries_continents = load_geography(geofile)
    metadata = dict()
    for col_name in ["Sample_accession", "Study_accession", "Country", "Continent"]:
        metadata.setdefault(col_name, dict())
    for new_acc, original_acc in original_accessions.items():
        sample, project, loc = get_metadata(original_acc, disable_ncbi_lookup)
        metadata["Sample_accession"][new_acc] = sample
        metadata["Study_accession"][new_acc] = project
        metadata["Country"][new_acc] = loc
        if loc in countries_continents:
            metadata["Continent"][new_acc] = countries_continents[loc]
        else:
            metadata["Continent"][new_acc] = "not provided"
    for col_name in ["Sample_accession", "Study_accession", "Country", "Continent"]:
        df[col_name] = df["Genome"].map(metadata[col_name])
    return df


def load_geography(geofile):
    geography = dict()
    with open(geofile, "r") as file_in:
        for line in file_in:
            if not line.startswith("Continent"):
                fields = line.strip().split(",")
                geography[fields[1]] = fields[0]
    return geography


def get_metadata(acc, disable_ncbi_lookup):
    warnings_out = open("warnings.txt", "w")
    location = None
    project = "N/A"
    biosample = "N/A"
    if acc.startswith("ERZ"):
        json_data_erz = load_xml(acc)
        biosample = json_data_erz["ANALYSIS_SET"]["ANALYSIS"]["SAMPLE_REF"][
            "IDENTIFIERS"
        ]["EXTERNAL_ID"]["#text"]
        project = json_data_erz["ANALYSIS_SET"]["ANALYSIS"]["STUDY_REF"]["IDENTIFIERS"][
            "SECONDARY_ID"
        ]
    elif acc.startswith("GUT"):
        pass
    elif acc.startswith("GCA"):
        try:
            json_data_gca = load_xml(acc)
            biosample = json_data_gca["ASSEMBLY_SET"]["ASSEMBLY"]["SAMPLE_REF"]["IDENTIFIERS"]["PRIMARY_ID"]
            project = json_data_gca["ASSEMBLY_SET"]["ASSEMBLY"]["STUDY_REF"]["IDENTIFIERS"]["PRIMARY_ID"]
        except:
            logging.info("Missing metadata in ENA XML for sample {}. Using API instead.".format(acc))
            try:
                biosample, project = ena_api_request(acc)
            except:
                logging.exception("Could not obtain biosample and project information for {}".format(acc))
    else:
        biosample, project = ena_api_request(acc)
    if not acc.startswith("GUT"):
        if acc.startswith("GCA"):
            location = get_gca_location(biosample)
        else:
            try:
                location = get_location(biosample)
            except:
                if not disable_ncbi_lookup:
                    logging.info(
                        "Unable to get location from ENA for sample {} which is unexpected. Trying NCBI.".format(biosample))
                    warnings_out.write("Had to get location from NCBI for sample {}".format(biosample))
                    location = get_sample_location_from_ncbi(biosample)
                    logging.error(
                        "MAJOR WARNING: had to get location for sample {} from NCBI. Location acquired: {}".format(
                            biosample,
                            location))
                else:
                    logging.warning(
                        "Unable to obtain location for sample {}, which is unexpected. Unable to look up the location "
                        "in NCBI because the --disable-ncbi-lookup flag is used. Returning 'not provided'".format(
                            biosample))
                    location = "not provided"
    if not location:
        logging.warning("Unable to obtain location for sample {}".format(biosample))
        location = "not provided"
    if not acc.startswith("GUT"):
        if acc.startswith("GCA"):
            converted_sample = biosample
        else:
            json_data_sample = load_xml(biosample)
            try:
                converted_sample = json_data_sample["SAMPLE_SET"]["SAMPLE"]["IDENTIFIERS"][
                    "PRIMARY_ID"
                ]
            except:
                converted_sample = biosample
        if project == "N/A":
            converted_project = "N/A"
        else:
            json_data_project = load_xml(project)
            try:
                converted_project = json_data_project["PROJECT_SET"]["PROJECT"]["IDENTIFIERS"][
                    "SECONDARY_ID"
                ]
            except:
                converted_project = project
    else:
        converted_sample = "FILL"
        converted_project = "FILL"
        location = "FILL"
    warnings_out.close()
    return converted_sample, converted_project, location


def ena_api_request(acc):
    biosample = project = ""
    if acc.startswith("CA"):
        acc = acc + "0" * 7
    r = run_request(acc, "https://www.ebi.ac.uk/ena/browser/api/embl")
    if r.ok:
        match_pr = re.findall("PR +Project: *(PRJ[A-Z0-9]+)", r.text)
        if match_pr:
            project = match_pr[0]
        match_samp = re.findall("DR +BioSample; ([A-Z0-9]+)", r.text)
        if match_samp:
            biosample = match_samp[0]
    else:
        logging.error("Cannot obtain metadata from ENA")
        sys.exit()
    return biosample, project


@retry(tries=5, delay=10, backoff=1.5)
def run_request(acc, url):
    r = requests.get("{}/{}".format(url, acc))
    r.raise_for_status()
    return r


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


def add_rna(df, genome_list, rna_folder):
    rna_results = dict()
    for key in ["rRNA_5S", "rRNA_16S", "rRNA_23S", "tRNAs"]:
        rna_results.setdefault(key, dict())
    for genome in genome_list:
        rrna_file = os.path.join(rna_folder, "{}_rRNAs.out".format(genome))
        trna_file = os.path.join(
            rna_folder,
            "{}_tRNA_20aa.out".format(genome),
        )
        rna_results["tRNAs"][genome] = load_trna(trna_file)
        (
            rna_results["rRNA_5S"][genome],
            rna_results["rRNA_16S"][genome],
            rna_results["rRNA_23S"][genome],
        ) = load_rrna(rrna_file)
    for key in ["rRNA_5S", "rRNA_16S", "rRNA_23S", "tRNAs"]:
        df[key] = df["Genome"].map(rna_results[key])
    return df


def load_rrna(rrna_file):
    with open(rrna_file, "r") as file_in:
        for line in file_in:
            fields = line.strip().split("\t")
            if fields[1].startswith("SSU_rRNA"):
                rRNA_16S = fields[2]
            elif fields[1].startswith("5S_rRNA"):
                rRNA_5S = fields[2]
            elif fields[1].startswith("LSU_rRNA"):
                rRNA_23S = fields[2]
            else:
                logging.error("Unexpected file format: {}".format(rrna_file))
                sys.exit()
    return rRNA_5S, rRNA_16S, rRNA_23S


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
    genome_list = [filename.rsplit(".", 1)[0] for filename in os.listdir(genomes_dir)]
    genomes_ext = os.listdir(genomes_dir)[0].rsplit(".", 1)[1]
    if gunc_file:
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
        "--geo",
        required=True,
        help=(
            "Path to the countries and continents file (continent_countries.csv from"
            "https://raw.githubusercontent.com/dbouquin/IS_608/master/NanosatDB_munging/Countries-Continents.csv)"
        ),
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
        "--disable-ncbi-lookup",
        action='store_true',
        help="Use this flag not to use NCBI as the fallback source of sample location. Default: False",
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
        args.geo,
        args.outfile,
        args.ftp_name,
        args.ftp_version,
        args.gunc_failed,
        args.disable_ncbi_lookup,
    )
