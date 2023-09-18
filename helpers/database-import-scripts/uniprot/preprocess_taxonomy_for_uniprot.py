#!/usr/bin/env python3

import argparse
import logging
import os
import subprocess
import sys

import gtdb_to_ncbi_majority_vote, gtdb_to_ncbi_majority_vote_v2

logging.basicConfig(level=logging.INFO)


def main(gtdbtk_folder, outfile, taxonomy_version, taxonomy_release):
    if not versions_compatible(taxonomy_version, taxonomy_release):
        sys.exit("GTDB versions {} and {} are not compatible".format(taxonomy_version, taxonomy_release))
    
    db_dir = "/nfs/production/rdf/metagenomics/pipelines/prod/assembly-pipeline/taxonomy_dbs/"
    selected_archaea_metadata, selected_bacteria_metadata = select_metadata(taxonomy_release, db_dir)
    tax_ncbi = select_dump(taxonomy_release, db_dir)
    print("Using the following databases:\n{}\n{}\n{}\n".format(selected_archaea_metadata, selected_bacteria_metadata,
                                                                tax_ncbi))

    if taxonomy_version == "1":
        tax = gtdb_to_ncbi_majority_vote.Translate()
    else:
        tax = gtdb_to_ncbi_majority_vote_v2.Translate()
        
    tax_dict = tax.run(gtdbtk_folder, selected_archaea_metadata, selected_bacteria_metadata, "gtdbtk")
    #tax_dict_filtered = filter_tax(tax_dict)  # filtered out unknown species; key=MGYG, value=full NCBI lineage
    #ncbi_dump = load_ncbi(tax_ncbi)
    # lookup tax id and print results to file
    with open(outfile, "w") as file_out:
        for mgyg, lineage in tax_dict.items():
            #species = lineage.strip().split(";")[-1].replace("s__", "")
            lowest_known_taxon = get_lowest_taxon(lineage)
            if not lowest_known_taxon:
                sys.exit("Genome {} doesn't have any known taxonomy".format(mgyg))
            else:
                run_taxonkit(lowest_known_taxon)
            #try:
            #    file_out.write("{}\t{}\t{}\t{}\n".format(mgyg, species, lineage, ncbi_dump[species]))
            #except:
            #    logging.error("Unable to obtain NCBI taxid for genome {}. Skipping genome.".format(mgyg))
            #    sys.exit(1)


def run_taxonkit(lowest_known_taxon):
    command = ["/homes/tgurbich/Taxonkit/taxonkit", "name2taxid", "--data-dir", "/homes/tgurbich/Taxonkit/taxdump"]
    try:
        result = subprocess.run(command, input=lowest_known_taxon, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, check=True)
        non_empty_line_count = len([line for line in result.stdout.split('\n') if line.strip()])
        if non_empty_line_count > 1:
            print("There multiple lines in output: {}".format(result.stdout))
    except subprocess.CalledProcessError as e:
        print("Error:", e.stderr)
    
    
def get_lowest_taxon(lineage):
    elements = lineage.strip().split(";")
    for i in reversed(elements):
        if not i.endswith("__"):
            return i.split("__")[1]
    return None
    
    
def select_dump(taxonomy_release, db_dir):
    dump_dict = {
        "r202": "fullnamelineage_2020-11-01.dmp",
        "r207": "fullnamelineage_2022-03-01.dmp",
        "r214": "fullnamelineage_2023-02-01.dmp"
    }
    return os.path.join(db_dir, dump_dict[taxonomy_release])
    

def select_metadata(taxonomy_release, db_dir):
    bac_prefix = "bac120_metadata_"
    ar_prefix_old = "ar122_metadata_"
    ar_prefix_new = "ar53_metadata_"
    if taxonomy_release == "r202":
        ar_filename = "{}{}.tsv".format(ar_prefix_old, taxonomy_release)
    else:
        ar_filename = "{}{}.tsv".format(ar_prefix_new, taxonomy_release)
    bac_filename = "{}{}.tsv".format(bac_prefix, taxonomy_release)
    return os.path.join(db_dir, ar_filename), os.path.join(db_dir, bac_filename)
    

def versions_compatible(taxonomy_version, taxonomy_release):
    if taxonomy_version == "2" and taxonomy_release == "r202":
        return False
    else:
        return True
    
    
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
                        help='Version of GTDB-Tk, "1" or "2". Default = "2".')
    parser.add_argument('-r', '--taxonomy-release', choices=['r202', 'r207', 'r214'], default="r214",
                        help='Version of GTDB-Tk, "r202", "r207" or "r214". Default = "r214".')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.gtdbtk_folder, args.outfile, args.taxonomy_version, args.taxonomy_release)