#!/usr/bin/env python3

import argparse
import logging

import gtdb_to_ncbi_majority_vote, gtdb_to_ncbi_majority_vote_v2

logging.basicConfig(level=logging.INFO)


def main(gtdbtk_folder, outfile, taxonomy_version):
    # ar122_metadata = "/nfs/production/rdf/metagenomics/pipelines/prod/assembly-pipeline/taxonomy_dbs/ar122_metadata_r95.tsv"
    # ar53_metadata = "/nfs/production/rdf/metagenomics/pipelines/prod/assembly-pipeline/taxonomy_dbs/ar53_metadata_r207.tsv"
    # bac120_metadata = "/nfs/production/rdf/metagenomics/pipelines/prod/assembly-pipeline/taxonomy_dbs/bac120_metadata_r214.tsv"
    # tax_ncbi_v2 = "/nfs/production/rdf/metagenomics/pipelines/prod/assembly-pipeline/taxonomy_dbs/fullnamelineage_01_31.dmp"

    ar122_metadata = "ar122_metadata_r95.tsv"
    ar53_metadata = "ar53_metadata_r207.tsv"
    bac120_metadata = "bac120_metadata_r214.tsv"
    tax_ncbi_v2 = "fullnamelineage_01_31.dmp"
    tax_ncbi_v1 = ""

    if taxonomy_version == "1":
        tax = gtdb_to_ncbi_majority_vote.Translate()
        selected_archaea_metadata = ar122_metadata
        tax_ncbi = tax_ncbi_v1
    else:
        tax = gtdb_to_ncbi_majority_vote_v2.Translate()
        selected_archaea_metadata = ar53_metadata
        tax_ncbi = tax_ncbi_v2
        
    tax_dict = tax.run(gtdbtk_folder, selected_archaea_metadata, bac120_metadata, "gtdbtk")
    tax_dict_filtered = filter_tax(tax_dict)  # filtered out unknown species; key=MGYG, value=full NCBI lineage
    ncbi_dump = load_ncbi(tax_ncbi)
    # lookup tax id and print results to file
    with open(outfile, "w") as file_out:
        for mgyg, lineage in tax_dict_filtered.items():
            species = lineage.strip().split(";")[-1].replace("s__", "")
            try:
                file_out.write("{}\t{}\t{}\t{}\n".format(mgyg, species, lineage, ncbi_dump[species]))
            except:
                logging.error("Unable to obtain NCBI taxid for genome {}. Skipping genome.".format(mgyg))


def load_ncbi(tax_ncbi):
    ncbi_dump = dict()
    repeats = list()
    with open(tax_ncbi, "r") as file_in:
        for line in file_in:
            if "cellular organisms; Archaea" in line or "cellular organisms; Bacteria" in line:
                fields = line.strip().split("|")
                taxid = fields[0].replace(" ", "").replace("\t", "")
                taxon_name = fields[1].replace("\t", "")
                if taxon_name in ncbi_dump:
                    repeats.append(taxon_name)
                ncbi_dump[taxon_name] = taxid
    repeats = set(repeats)
    # remove names that appear multiple times - we can't assign taxid with confidence and they are not species anyway
    filtered_ncbi_dump = {key: value for key, value in ncbi_dump.items() if key not in repeats}
    return filtered_ncbi_dump
    

def filter_tax(tax_dict):
    filtered_tax_dict = dict()
    for genome, taxonomy in tax_dict.items():
        if not taxonomy.endswith("s__"):
            filtered_tax_dict[genome] = taxonomy
    return filtered_tax_dict

    
    
    
def parse_args():
    parser = argparse.ArgumentParser(description="The script takes in a GTDB-Tk output folder and "
                                                 "outputs NCBI taxonomy.")
    parser.add_argument('-g', '--gtdbtk-folder', required=True,
                        help='Path to the GTDB-Tk output folder.')
    parser.add_argument('-o', '--outfile', required=True,
                        help='Path to the output file where the modified file will be stored.')
    parser.add_argument('-v', '--taxonomy-version', choices=['1', '2'], default="2",
                        help='Version of GTDB, "1" or "2". Default = "2".')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.gtdbtk_folder, args.outfile, args.taxonomy_version)