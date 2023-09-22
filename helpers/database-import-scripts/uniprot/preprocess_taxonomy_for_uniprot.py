#!/usr/bin/env python3

import argparse
import logging
import os
import re
import subprocess
import sys

import gtdb_to_ncbi_majority_vote, gtdb_to_ncbi_majority_vote_v2

logging.basicConfig(level=logging.INFO)

TAXDUMP_PATH = "/homes/tgurbich/Taxonkit/taxdump"
DB_DIR = "/nfs/production/rdf/metagenomics/pipelines/prod/assembly-pipeline/taxonomy_dbs/"


def main(gtdbtk_folder, outfile, taxonomy_version, taxonomy_release):
    if not os.path.isdir(gtdbtk_folder):
        sys.exit("GTDB folder {} is not a directory. EXITING.".format(gtdbtk_folder))
    if not versions_compatible(taxonomy_version, taxonomy_release):
        sys.exit("GTDB versions {} and {} are not compatible".format(taxonomy_version, taxonomy_release))
    
    
    selected_archaea_metadata, selected_bacteria_metadata = select_metadata(taxonomy_release, DB_DIR)
    tax_ncbi = select_dump(taxonomy_release, DB_DIR)
    print("Using the following databases:\n{}\n{}\n{}\n".format(selected_archaea_metadata, selected_bacteria_metadata,
                                                                tax_ncbi))

    if taxonomy_version == "1":
        tax = gtdb_to_ncbi_majority_vote.Translate()
    else:
        tax = gtdb_to_ncbi_majority_vote_v2.Translate()
        
    lineage_dict = tax.run(gtdbtk_folder, selected_archaea_metadata, selected_bacteria_metadata, "gtdbtk")
        
    # lookup tax id and print results to file
    lowest_taxon_mgyg_dict, lowest_taxon_lineage_dict = get_lowest_taxa(lineage_dict)  
    # lowest_taxon_mgyg_dict: # key = mgyg, value = name of the lowest known taxon
    # lowest_taxon_lineage_dict: # key = lowest taxon, value = list of lineages where this taxon is lowest
    taxid_dict = run_taxonkit_on_dict(lowest_taxon_mgyg_dict, lineage_dict, lowest_taxon_lineage_dict)  # key = taxon name, value = taxid
    #with open(outfile, "w") as file_out:
    #    for key, value in lowest_taxon_mgyg_dict.items():
    #        lineage = lineage_dict[key]
    #        species_level = False if lineage.endswith("s__") else True
    #        taxid = taxid_dict[value]
    #        file_out.write("{}\t{}\t{}\t{}\n".format(key, lineage, taxid, species_level))


def load_synonyms():
    namesdump = os.path.join(TAXDUMP_PATH, "names.dmp")
    synonym_dict = dict()
    with open(namesdump, "r") as file_in:
        for line in file_in:
            if any(term in line for term in ["authority", "genbank acronym", "blast name", "genbank common name"]):
                pass
            else:
                taxid, name = line.strip().split("|")[:2]
                taxid = re.sub("\s+", "", taxid)
                name = re.sub("^\s+|\s+$", "", name)
                synonym_dict.setdefault(taxid, list()).append(name)
    return synonym_dict
    
    
def run_taxonkit_on_dict(lowest_taxon_mgyg_dict, lineage_dict, lowest_taxon_lineage_dict):
    input_data = "\n".join(set(lowest_taxon_mgyg_dict.values()))  # remove duplicate taxa and save all lines to a variable
    command = ["/homes/tgurbich/Taxonkit/taxonkit", "name2taxid", "--data-dir", TAXDUMP_PATH]
    try:
        result = subprocess.run(command, input=input_data, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, check=True)
        taxid_dict = process_taxonkit_output(result.stdout)
        filtered_taxid_dict = filter_taxid_dict(taxid_dict, lineage_dict, lowest_taxon_lineage_dict)  # resolve cases where multiple taxid are assigned to taxon
        return filtered_taxid_dict
    except subprocess.CalledProcessError as e:
        print("Error:", e.stderr)


def filter_taxid_dict(taxid_dict, lineage_dict, lowest_taxon_lineage_dict):
    """
    Resolve cases where multiple taxids are assigned to the same taxon by matching domain and phylum. 
    If domain and phylum match multiple taxon ids, the function picks the first one.
    If no match is found by using taxonkit, the script checks synonyms in names.dmp.
    
    @param taxid_dict: key = taxon name, value = list of taxids
    @param lineage_dict: key = mgyg, value = full NCBI lineage
    @param lowest_taxon_lineage_dict: key = taxon name, value = list of lineages where the taxon is lowest
    @return: filtered_taxid_dict: key = taxon name, value = dictionary where key = lineage, value = taxid
    """
    filtered_taxid_dict = dict()
    # get synonyms from names.dmp
    synonyms = load_synonyms()  # key = taxid, value = list of synonyms
    command = ["/homes/tgurbich/Taxonkit/taxonkit", "reformat", "--data-dir",
               TAXDUMP_PATH, "-I", "1"]
    for taxon_name, taxid_list in taxid_dict.items():
        if len(taxid_list) == 1:
            # no need to filter anything, save to results
            #filtered_taxid_dict[taxon_name] = taxid_list[0]
            filtered_taxid_dict.setdefault(taxon_name, dict())
            filtered_taxid_dict[taxon_name][lowest_taxon_lineage_dict[taxon_name][0]] = taxid_list[0]
        else:
            # if we are here, the taxon name has multiple taxids associated with it
            success = False 
            print("\n\n\n------------------> resolving duplicate {} {}".format(taxon_name, taxid_list))
            correct_taxon = list()
            # go through taxids and identify the ones we need to keep
            for taxid in taxid_list:
                # get the lineage
                result = subprocess.run(command, input=taxid, text=True, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, check=True)
                try:
                    lineage = result.stdout.strip().split("\t")[1]
                    print("Checking dump lineage", lineage)
                    retrieved_name = re.sub(";+$", "", lineage).split(";")[-1]
                    assert retrieved_name, "Could not get retrieved name for lineage".format(lineage)
                    print("Checking name from dump lineage is", retrieved_name)
                    expected_domains_and_phyla = get_domains_and_phyla(lowest_taxon_lineage_dict[taxon_name])
                    print("expected phyla obtained", expected_domains_and_phyla)
                    retrieved_domain = lineage.split(";")[0]
                    print("Checking domain", retrieved_domain)
                    if retrieved_domain in expected_domains_and_phyla:
                        print("Domain match")
                        for phylum in expected_domains_and_phyla[retrieved_domain]:
                            print("checking phylum {}".format(phylum))
                            if phylum == lineage.split(';')[1]:
                                print("Phylum match")
                                matching_lineage = pick_lineage(retrieved_domain, phylum,
                                                                lowest_taxon_lineage_dict[taxon_name])
                                if compare_positions(lineage, matching_lineage, taxon_name) and \
                                        last_non_empty_segment_position(lineage) == \
                                        last_non_empty_segment_position(matching_lineage):
                                    print("Positions match")
                                    success = True
                                    filtered_taxid_dict.setdefault(taxon_name, dict())
                                    if matching_lineage not in filtered_taxid_dict[taxon_name]:
                                        filtered_taxid_dict[taxon_name][matching_lineage] = taxid
                                    else:
                                        print("###################### Multiple matching taxids: {}".format(
                                            matching_lineage))
                                        
                                else:
                                    print("levels are different")
                            else:
                                matching_lineage = pick_lineage(retrieved_domain, phylum,
                                                                lowest_taxon_lineage_dict[taxon_name])
                                if (taxon_name in synonyms[taxid] and last_non_empty_segment_position(lineage) == 
                                    last_non_empty_segment_position(matching_lineage)):
                                    success = True
                                    print("Resolved lineage through synonyms")
                    print(lineage, retrieved_name)
                    print(lowest_taxon_lineage_dict[taxon_name])
                    # first check that the name matches
                    if retrieved_name == taxon_name:
                        # now check that lineage is correct
                        # compare phyla:
                        
                        correct_taxon.append(taxid)
                except AssertionError as e:
                    logging.error("Assertion error: {}".format(e))
                except IndexError:
                    logging.error("Index error: Unable to extract lineage from result.stdout")
                except Exception as e:
                    logging.error("Error when processing taxid {}: {}".format(taxid, e))
                    sys.exit("Unable to find lineages for taxid {}".format(taxid))
            correct_taxon = list(set(correct_taxon))
            # Todo: fix how this is handled - check lineage
            #if len(correct_taxon) == 1:
            #    filtered_taxid_dict[taxon_name] = correct_taxon[0]
            #else:
            #    print("Multiple identical taxon names: {}".format(taxon_name))
            #    filtered_taxid_dict[taxon_name] = taxid
            if not success:
                sys.exit("Unable to resolve taxonomy of {}. EXITING.".format(taxon_name))
    for key, value in filtered_taxid_dict.items():
        for lineage, taxid in value.items():
            command = ["/homes/tgurbich/Taxonkit/taxonkit", "reformat", "--data-dir",
                       TAXDUMP_PATH, "-I", "1"]
            result = subprocess.run(command, input=taxid, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE, check=True)
            retrieved_lineage = result.stdout.strip().split("\t")[1]
            print(key, "\n", lineage, "\n", retrieved_lineage, "\n", taxid, "\n")
    
    return filtered_taxid_dict


def last_non_empty_segment_position(lineage_string):
    # Remove taxonomy levels if present
    if "s__" in lineage_string:
        lineage_string = re.sub("[a-z]__", "", lineage_string)
        
    # Remove last semicolon if present
    if lineage_string.endswith(";"):
        lineage_string = lineage_string[:-1]
    
    position = None
    
    # Split the input string using semicolons as delimiters
    segments = lineage_string.split(';')

    # Iterate through the segments in reverse order
    for i in range(len(segments) - 1, -1, -1):
        segment = segments[i].strip()
        if segment:
            position = i
            break  # Stop when the last non-empty segment is found
    print("lineage position", position, "in lineage", lineage_string)
    if position is None:
        sys.exit("Could not find last non-empty position in lineage {}".format(lineage_string))
    return position
    
    
def compare_positions(lineage1, lineage2, search_term):
    # Split the input strings into segments using semicolon as the delimiter
    segments1 = lineage1.split(';')
    segments2 = lineage2.split(';')
    
    position1 = position2 = None

    # Iterate through the segments in both strings
    for i, segment in enumerate(segments1):
        if search_term == segment:
            position1 = i

    for i, segment in enumerate(segments2):
        if search_term == segment.split("__")[1]:
            position2 = i
    if position1 is None or position2 is None:
        raise Exception("Unable to find taxon in lineages {} {} {}".format(lineage1, lineage2, search_term))
    return position1 == position2


def pick_lineage(expected_domain, expected_phylum, lineage_list):
    if len(lineage_list) == 1:
        return lineage_list[0]
    else:
        print("---------------------->>>>>>> Multiple lineages: {}".format(lineage_list))
        for lineage in lineage_list:
            domain, phylum = [part.replace("d__", "").replace("p__", "") for part in lineage.split(";")[:2]]
            if domain == expected_domain and phylum == expected_phylum:
                return lineage
    sys.exit("ERROR: could not resolve lineages: {} {} {}".format(expected_domain, expected_phylum, lineage_list))


def get_domains_and_phyla(lineage_list):
    expected_domains_and_phyla = dict()
    for lineage in lineage_list:
        domain, phylum = [part.replace("d__", "").replace("p__", "") for part in lineage.split(";")[:2]]
        expected_domains_and_phyla.setdefault(domain, list()).append(phylum)
    return expected_domains_and_phyla


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
    for key, value in lowest_taxon_lineage_dict.items():
        lowest_taxon_lineage_dict[key] = list(set(value))  # remove repeat lineages
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
    