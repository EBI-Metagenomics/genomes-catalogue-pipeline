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
        
    lineage_dict = tax.run(gtdbtk_folder, selected_archaea_metadata, selected_bacteria_metadata, "gtdbtk")
    with open("ncbi.out", "w") as file_out:
        for key, value in lineage_dict.items():
            file_out.write("{}\t{}\n".format(key, value))
        
    # lookup tax id and print results to file
    lowest_taxon_mgyg_dict, lowest_taxon_lineage_dict = get_lowest_taxa(lineage_dict)  
    # lowest_taxon_mgyg_dict: # key = mgyg, value = name of the lowest known taxon
    # lowest_taxon_lineage_dict: # key = lowest taxon, value = list of lineages where taxon is lowest
    with open(outfile, "w") as file_out:
        for key, value in lowest_taxon_mgyg_dict.items():
            file_out.write("{}\t{}\n".format(key, value))
    taxid_dict = run_taxonkit_on_dict(lowest_taxon_mgyg_dict, lineage_dict, lowest_taxon_lineage_dict)  # key = taxon name, value = taxid
    with open(outfile, "w") as file_out:
        for key, value in lowest_taxon_mgyg_dict.items():
            print(key, value)
            lineage = lineage_dict[key]
            species_level = False if lineage.endswith("s__") else True
            taxid = taxid_dict[value]
            print(key, lineage, taxid, species_level)
            file_out.write("{}\t{}\t{}\t{}\n".format(key, lineage, taxid, species_level))


def run_taxonkit_on_dict(lowest_taxon_mgyg_dict, lineage_dict, lowest_taxon_lineage_dict):
    input_data = "\n".join(set(lowest_taxon_mgyg_dict.values()))  # remove duplicate taxa and save all lines to a variable
    command = ["/homes/tgurbich/Taxonkit/taxonkit", "name2taxid", "--data-dir", "/homes/tgurbich/Taxonkit/taxdump"]
    try:
        result = subprocess.run(command, input=input_data, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, check=True)
        taxid_dict = process_taxonkit_output(result.stdout)
        filtered_taxid_dict = filter_taxid_dict(taxid_dict, lineage_dict)  # resolve cases where multiple taxid are assigned to taxon
        return filtered_taxid_dict
    except subprocess.CalledProcessError as e:
        print("Error:", e.stderr)


def filter_taxid_dict(taxid_dict, lineage_dict):
    filtered_taxid_dict = dict()
    command = ["/homes/tgurbich/Taxonkit/taxonkit", "lineage", "--data-dir",
               "/homes/tgurbich/Taxonkit/taxdump"]
    for taxon_name, taxid_list in taxid_dict.items():
        if len(taxid_list) == 1:
            filtered_taxid_dict[taxon_name] = taxid_list[0]
        else:
            # check if the lowest taxon is present in multiple different lineages
            print("------------------> resolving duplicate {} {}".format(taxon_name, taxid_list))
            correct_taxon = list()
            for taxid in taxid_list:
                result = subprocess.run(command, input=taxid, text=True, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, check=True)
                try:
                    lineage = result.stdout.strip().split("\t")[1]
                    retrieved_name = result.stdout.strip().split("\t")[1].split(";")[-1]
                    print(lineage, retrieved_name)
                    if retrieved_name == taxon_name:
                        correct_taxon.append(taxid)
                except:
                    logging.error("Error when resolving duplicate {}".format(taxid))
                    sys.exit("Unable to find lineages for taxid {}".format(taxid))
            correct_taxon = list(set(correct_taxon))
            # Todo: fix how this is handled - check lineage
            if len(correct_taxon) == 1:
                filtered_taxid_dict[taxon_name] = correct_taxon[0]
            else:
                print("Multiple identical taxon names: {}".format(taxon_name))
                filtered_taxid_dict[taxon_name] = taxid
    return filtered_taxid_dict
        

def process_taxonkit_output(taxonkit_output):
    taxid_dict = dict()
    lines = taxonkit_output.split("\n")
    for line in lines:
        line = line.strip()
        if len(line) > 0:
            parts = line.split("\t")
            if len(parts) == 1:
                logging.error("No taxid for taxon {}. EXITING!".format(parts[0]))
                sys.exit(1)
                #taxid_dict.setdefault(parts[0], list()).append(None)
            else:
                taxon, taxid = parts[:2]
                taxid_dict.setdefault(taxon, list()).append(taxid)
    return taxid_dict


def get_lowest_taxa(tax_dict):
    lowest_taxon_mgyg_dict = dict()
    lowest_taxon_lineage_dict = dict()
    for mgyg, lineage in tax_dict.items():
        lowest_known_taxon = get_lowest_taxon(lineage)
        lowest_taxon_mgyg_dict[mgyg] = lowest_known_taxon
        lowest_taxon_lineage_dict.setdefault(lowest_known_taxon, list()).append(lineage)
    return lowest_taxon_mgyg_dict, lowest_taxon_lineage_dict
    
    
def get_lowest_taxon(lineage):
    elements = lineage.strip().split(";")
    for i in reversed(elements):
        if not i.endswith("__"):
            return i.split("__")[1]
    sys.exit("Could not obtain lowest taxon from lineage {}".format(lineage))
    
    
def select_dump(taxonomy_release, db_dir):
    dump_dict = {
        "r202": "fullnamelineage_2020-11-01.dmp",
        "r207": "fullnamelineage_2022-03-01.dmp",
        "r214": "fullnamelineage_2022-12-01.dmp"
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