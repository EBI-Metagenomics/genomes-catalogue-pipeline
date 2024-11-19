#!/usr/bin/env python3

import argparse
import concurrent.futures
import json
import logging
import os
import re
import subprocess
import sys

import pandas as pd
import requests
from retry import retry

import gtdb_to_ncbi_majority_vote, gtdb_to_ncbi_majority_vote_v2

logging.basicConfig(level=logging.ERROR)

TAXDUMP_PATH = "/nfs/production/rdf/metagenomics/pipelines/prod/assembly-pipeline/taxonomy_dbs/Taxonkit/taxdump_2022-12-01"
TAXDUMP_PATH_NEW_VER = "/nfs/production/rdf/metagenomics/pipelines/prod/assembly-pipeline/taxonomy_dbs/Taxonkit/new_taxdump_2023-11-01"
DB_DIR = "/nfs/production/rdf/metagenomics/pipelines/prod/assembly-pipeline/taxonomy_dbs/"


def main(gtdbtk_folder, outfile, taxonomy_version, taxonomy_release, metadata_file, species_level_taxonomy, threads):
    if not os.path.isdir(gtdbtk_folder):
        sys.exit("GTDB folder {} is not a directory. EXITING.".format(gtdbtk_folder))
    if not versions_compatible(taxonomy_version, taxonomy_release):
        sys.exit("GTDB versions {} and {} are not compatible".format(taxonomy_version, taxonomy_release))
    
    # for each MGYG accession, get the corresponsing GCA (where available) and sample accessions from the metadata file
    gca_accessions, sample_accessions = parse_metadata(metadata_file)  # key=mgyg, value=gca accession/sample accession
    
    # supplement the gca accessions from the metadata table by looking them up in ENA. For each GCA accession, look up
    # corresponding taxid in ENA
    mgyg_to_gca, gca_to_taxid = match_taxid_to_gca(gca_accessions, sample_accessions, threads)
    
    # remove N/A's if present before looking up lineages
    na_true = False
    if "N/A" in gca_to_taxid:
        gca_to_taxid.pop("N/A")
        na_true = True
        
    # get a lineage for each taxid (from taxonkit or from ENA if unable)    
    gca_taxid_to_lineage = match_lineage_to_gca_taxid(gca_to_taxid, threads)  # key = taxid, value = lineage
    
    # check if any taxa are not real species (for example, a species is "metagenome")
    # we want to remove them and replace with converted ones from GTDB
    gca_to_taxid, invalid_flag = remove_invalid_taxa(gca_to_taxid, gca_taxid_to_lineage)
    
    if na_true or invalid_flag or not species_level_taxonomy:
        # If we are here, we have some genomes we were unable to get taxonomy from because we either don't know
        # the GCA accession or the taxonomy we got from GCA is invalid. We need to use GTDB taxonomy and convert it
        # to NCBI taxonomy.
        selected_archaea_metadata, selected_bacteria_metadata = select_metadata(taxonomy_release, DB_DIR)
        tax_ncbi = select_dump(taxonomy_release, DB_DIR)
        print(
            "Using the following databases:\n{}\n{}\n{}\n".format(selected_archaea_metadata, selected_bacteria_metadata,
                                                                  tax_ncbi))

        if taxonomy_version == "1":
            tax = gtdb_to_ncbi_majority_vote.Translate()
        else:
            tax = gtdb_to_ncbi_majority_vote_v2.Translate()
            
        lineage_dict = tax.run(gtdbtk_folder, selected_archaea_metadata, selected_bacteria_metadata, "gtdbtk")
        
        # lookup tax id
        lowest_taxon_mgyg_dict, lowest_taxon_lineage_dict = get_lowest_taxa(lineage_dict)  
       
        # lowest_taxon_mgyg_dict: # key = mgyg, value = name of the lowest known taxon
        # lowest_taxon_lineage_dict: # key = lowest taxon, value = list of lineages where this taxon is lowest
        
        taxid_dict = run_taxonkit_on_dict(lowest_taxon_mgyg_dict, lowest_taxon_lineage_dict)
    
    # look up all unknown GCA accessions using converted GTDB lineages and updating them in case some species level
    # taxa names are missing and/or the lineage has outdated taxon names
    if species_level_taxonomy and na_true:
        logging.debug("========================= Looking up lineages for unknown GCAs")
        lineages_to_lookup = list(set([lineage_dict[key] for key, value in mgyg_to_gca.items() if value == 'N/A']))
        unknown_gca_mgyg_and_lineage = {k: lineage_dict[k] for k, v in mgyg_to_gca.items() if v == 'N/A'}
        na_associated_lineages = dict()

        # Use ThreadPoolExecutor to parallelize the execution
        with concurrent.futures.ThreadPoolExecutor(max_workers=threads) as executor:
            # Submit the tasks and get the Future objects
            futures = {executor.submit(process_lineage, l): l for l in lineages_to_lookup}

            # Retrieve the results as they become available
            for future in concurrent.futures.as_completed(futures):
                lineage = futures[future]
                try:
                    result = future.result()
                    na_associated_lineages[lineage] = result
                except Exception as e:
                    print(f"Error processing lineage {lineage}: {e}")
                    
        for mgyg, lineage in unknown_gca_mgyg_and_lineage.items():
            unknown_gca_mgyg_and_lineage[mgyg] = na_associated_lineages[lineage]
        
    with open(outfile, "w") as file_out:
        for key, gca_accession in mgyg_to_gca.items():
            logging.debug("Processing {}".format(key))
            source = ""
            if gca_accession in gca_to_taxid and gca_to_taxid[gca_accession] == "invalid":
                logging.debug("In invalid")
                lineage = lineage_dict[key]
                logging.debug("Lineage from GTDB was {}".format(lineage))
                taxid_to_report, _, submittable, lineage = get_species_level_taxonomy(lineage)
                logging.debug("Lineage after processing is {}".format(lineage))
                source = "ENA"
                lowest_taxon = get_lowest_taxon(lineage)[0]
                logging.debug("Done processing {}".format(key))
            elif gca_accession == "N/A" and species_level_taxonomy:
                logging.debug("In N/A")
                source = "ENA"
                taxid_to_report = unknown_gca_mgyg_and_lineage[key]["taxid"]
                lineage = unknown_gca_mgyg_and_lineage[key]["lineage"]
                logging.debug("Starting function with taxid {} and lineage {}".format(taxid_to_report, lineage))
                if not taxid_to_report:
                    logging.debug("In no taxid to report condition")
                    lineage = lineage_dict[key]
                    logging.debug("Got lineage from GTDB: {}".format(lineage))
                    taxid_to_report, _, _, lineage = get_species_level_taxonomy(lineage)
                    logging.debug("After processing lineage is {} and taxid is {}".format(lineage, taxid_to_report))
                    source = "taxonkit/ENA"
                    if not taxid_to_report:
                        # Check if the taxon name has changed and update accordingly
                        gtdb_taxid = taxid_dict[lowest_taxon_mgyg_dict[key]][lineage]
                        logging.debug("No taxid to report so using GTDBs: {}".format(gtdb_taxid))
                        taxid_to_report, lineage = recover_possible_new_name(gtdb_taxid)
                        logging.debug("Tried to recover possible new name. Result taxid {} lineage {}".format(taxid_to_report, lineage))
                        if not taxid_to_report:
                            source = "GTDB"
                            lineage = lineage_dict[key]
                            taxid_to_report = gtdb_taxid
                            logging.debug("That didnt work so reporting GTDB: lineage {} taxid {}".format(lineage, taxid_to_report))
                logging.debug("Done processing {}".format(key))
                lowest_taxon = get_lowest_taxon(lineage)[0]
                submittable, _ = query_scientific_name_from_ena(lowest_taxon, search_rank=False)
            elif gca_accession.startswith("GCA") and species_level_taxonomy:
                logging.debug("In GCA")
                insdc_taxid = gca_to_taxid[gca_accession]
                lineage = gca_taxid_to_lineage[insdc_taxid]
                source = "taxonkit/ENA"
                lowest_taxon = get_lowest_taxon(lineage)[0]
                assert lowest_taxon, "Could not get retrieved name for lineage {}".format(lineage)
                taxid_to_report = insdc_taxid
                submittable, _ = query_scientific_name_from_ena(lowest_taxon, search_rank=False)
            else:
                logging.debug("In else (not invalid, N/A or GCA)")
                if gca_accession.startswith("GCA"):  # this means there is already a taxid in INSDC for this genome
                    insdc_taxid = gca_to_taxid[gca_accession]
                    taxid_to_report = insdc_taxid
                    lineage = gca_taxid_to_lineage[taxid_to_report]
                    source = "taxonkit/ENA"
                else:
                    source = "GTDB"
                    lineage = lineage_dict[key]
                    taxid_to_report = taxid_dict[lowest_taxon_mgyg_dict[key]][lineage]
                lowest_taxon = get_lowest_taxon(lineage)[0]
                submittable, _ = query_scientific_name_from_ena(lowest_taxon, search_rank=False)
            species_level = False if lineage.endswith("s__") else True
            if submittable:
                submittable_print = "Valid for ENA"
            else:
                submittable_print = "Not valid for ENA"
            file_out.write("{}\t{}\t{}\t{}\t{}\t{}\t{}\n".format(
                key, lowest_taxon, lineage, gca_accession, taxid_to_report, species_level, submittable_print))
            logging.debug(key, lineage, source)
    logging.info("Printed results to {}".format(outfile))


def process_lineage(l):
    taxid, name, submittable, lineage = get_species_level_taxonomy(l)
    return {"taxid": taxid, "name": name, "submittable": submittable, "lineage": lineage}


def remove_invalid_taxa(gca_to_taxid, gca_taxid_to_lineage):
    invalid_flag = False
    logging.debug("=================== Starting invalid check ===================")
    for gca_acc, taxid in gca_to_taxid.items():
        lineage = gca_taxid_to_lineage[taxid]
        lowest_taxon = get_lowest_taxon(lineage)[0]
        if "metagenome" in lowest_taxon or str(taxid) == "77133" or "d__Viruses" in lineage:
            invalid_flag = True
            gca_to_taxid[gca_acc] = "invalid"
            logging.debug("----------------> FOUND INVALID TAXON", lineage)
        else:
            logging.debug("Taxon is not invalid: {}".format(lowest_taxon))
    return gca_to_taxid, invalid_flag
    

def match_lineage_to_gca_taxid(gca_to_taxid, threads):
    logging.debug("Function match_lineage_to_gca_taxid")
    taxids = list(gca_to_taxid.values())
    with concurrent.futures.ThreadPoolExecutor(max_workers=threads) as executor:
        taxid_to_lineage = {taxid: lineage for taxid, lineage in zip(taxids, executor.map(lookup_lineage, taxids))}    
    return taxid_to_lineage
    

def match_taxid_to_gca(gca_accessions, sample_accessions, threads):
    logging.debug("Function match_taxid_to_gca")
    mgyg_to_gca = dict()  
    for mgyg, sample in sample_accessions.items():
        if mgyg in gca_accessions:
            mgyg_to_gca[mgyg] = gca_accessions[mgyg]
        else:
            mgyg_to_gca[mgyg] = get_gca_accession(sample_accessions[mgyg])
    gca_list = list(mgyg_to_gca.values())
    with concurrent.futures.ThreadPoolExecutor(max_workers=threads) as executor:
        gca_to_taxid = {gca_acc: taxid for gca_acc, taxid in zip(gca_list, executor.map(lookup_taxid_online, gca_list))}
    return mgyg_to_gca, gca_to_taxid
 
 
def recover_possible_new_name(gtdb_taxid):
    logging.debug("Function recover_possible_new_name")
    try:
        ena_lineage = lookup_lineage_in_ena(gtdb_taxid)
    except:
        return "", ""
    taxid, _, _, full_lineage = get_species_level_taxonomy(ena_lineage)
    return taxid, full_lineage
    

def get_species_level_taxonomy(lineage):
    lowest_taxon, lowest_rank = get_lowest_taxon(lineage)
    if lineage.startswith("k__"):
        lineage = lineage.replace("k__", "d__")
    if lineage.lower().startswith("d__b"):
        submittable, name, taxid = extract_bacteria_info(lowest_taxon, lowest_rank)
    elif lineage.lower().startswith("d__a"):
        submittable, name, taxid = extract_archaea_info(lowest_taxon, lowest_rank)
    elif lineage.lower().startswith("d__e"):
        submittable, name, taxid = extract_eukaryota_info(lowest_taxon, lowest_rank)
    else:
        sys.exit("Unknown domain in lineage {}. Aborting".format(lineage))
    if taxid:
        logging.debug("Lineage for unknown GCA before updating {}".format(lineage))
        lineage = lookup_lineage(taxid)
        if lineage.endswith("__"):
            lineage = lineage + name
        logging.debug("Lineage for unknown GCA after updating {}".format(lineage))
    return taxid, name, submittable, lineage


def query_scientific_name_from_ena(scientific_name, search_rank=False):
    logging.debug("Function query_scientific_name_from_ena")
    url = "https://www.ebi.ac.uk/ena/taxonomy/rest/scientific-name/{}".format(scientific_name)
    response = run_full_url_request(url)

    try:
        # Will raise exception if response status code is non-200 
        response.raise_for_status()
    except requests.exceptions.HTTPError:
        if search_rank:
            return False, "", ""
        else:
            return False, ""

    try:
        res = json.loads(response.text)[0]
    except IndexError:
        if search_rank:
            return False, "", ""
        else:
            return False, ""

    submittable = res.get("submittable", "").lower() == "true"
    taxid = res.get("taxId", "")
    rank = res.get("rank", "")

    if search_rank:
        return submittable, taxid, rank
    else:
        return submittable, taxid


def extract_eukaryota_info(name, rank):
    logging.debug("Function extract_eukaryota_info")
    nonsubmittable = (False, "", 0)

    # Asterisks in given taxonomy suggest the classification might be not confident enough.
    if '*' in name:
        return nonsubmittable

    if rank == "d":
        name = "uncultured eukaryote"
        submittable, taxid = query_scientific_name_from_ena(name)
        return submittable, name, taxid
    else:
        name = name.capitalize() + " sp."
        submittable, taxid = query_scientific_name_from_ena(name)
        if submittable:
            return submittable, name, taxid
        else:
            name = "uncultured " + name
            submittable, taxid = query_scientific_name_from_ena(name)
            if submittable:
                return submittable, name, taxid
            else:
                name = name.replace(" sp.", '')
                submittable, taxid = query_scientific_name_from_ena(name)
                if submittable:
                    return submittable, name, taxid
                else:
                    return nonsubmittable


def extract_bacteria_info(name, rank):
    logging.debug("Function extract_bacteria_info")
    if rank == "s":
        name = name
    elif rank == "d":
        name = "uncultured bacterium"
    elif rank in ["f", "o", "c", "p"]:
        name = "uncultured {} bacterium".format(name)
    elif rank == "g":
        name = "uncultured {} sp.".format(name)

    submittable, taxid = query_scientific_name_from_ena(name, search_rank=False)
    logging.debug("Rank is {}".format(rank))
    if not submittable:
        if rank in ["s", "g"] and name.lower().endswith("bacteria"):
            name = "uncultured {}".format(name.replace("bacteria", "bacterium"))
        elif rank == "f":
            if name.lower() == "deltaproteobacteria":
                name = "uncultured delta proteobacterium"
        elif rank == "p":
            if name.lower() == "uncultured proteobacteria bacterium":
                name = "uncultured proteobacterium"
            elif name.lower() == "uncultured lentisphaerae bacterium":
                name = "uncultured lentisphaerota bacterium"
            elif name.lower() == "uncultured cyanobacteria bacterium":
                name = "uncultured cyanobacterium"
            elif name.lower() == "uncultured verrucomicrobia bacterium":
                name = "uncultured verrucomicrobiota bacterium"
            elif name.lower() == "uncultured candidatus scatovivens sp.":
                name = "Candidatus Scatovivens sp."
        submittable, taxid = query_scientific_name_from_ena(name)
    if not submittable:
        if name.startswith("uncultured"): 
            if name.endswith("sp.") or "Candidatus" in name:
                logging.debug("Removing uncultured")
                name = name.replace("uncultured ", "")
                submittable, taxid = query_scientific_name_from_ena(name)
                logging.debug("Removed. Result: {} {} {}".format(name, taxid, submittable))
    logging.debug("Submittable {} name {} taxid {}".format(submittable, name, taxid))
    return submittable, name, taxid


def extract_archaea_info(name, rank):
    logging.debug("Function extract_archaea_info")
    if rank == "s":
        name = name
    elif rank == "d":
        name = "uncultured archaeon"
    elif rank == "p":
        if "Euryarchaeota" in name:
            name = "uncultured euryarchaeote"
        elif "Candidatus" in name:
            name = "{} archaeon".format(name)
        else:
            name = "uncultured {} archaeon".format(name)
    elif rank in ["f", "o", "c"]:
        name = "uncultured {} archaeon".format(name)
    elif rank == "g":
        name = "uncultured {} sp.".format(name)
    
    logging.debug("Looking up name {}".format(name))
    submittable, taxid = query_scientific_name_from_ena(name, search_rank=False)
    if not submittable:
        if "Candidatus" in name:
            if rank == "p":
                name = name.replace("Candidatus ", '')
            elif rank == "f":
                name = name.replace("uncultured ", '')
        if rank == "f" and "Methanomassiliicoccaceae" in name:
            name = "uncultured Methanomassiliicoccaceae bacterium"
            logging.debug("Name wasn't submittable. Now trying {}".format(name))
            submittable, taxid = query_scientific_name_from_ena(name)

    return submittable, name, taxid


def lookup_lineage(insdc_taxid):
    logging.debug("Function lookup_lineage")
    
    def get_lineage(taxid, taxdump_path):
        assert taxid, "Unable to use taxdump for an unknown taxid"
        command = ["/homes/tgurbich/Taxonkit/taxonkit", "reformat", "--data-dir", taxdump_path, "-I", "1", "-P"]
        result = subprocess.run(command, input=taxid, text=True, stdout=subprocess.PIPE, 
                                stderr=subprocess.PIPE, check=True)
        detected_lineage = result.stdout.strip().split("\t")[1]
        if detected_lineage.startswith("k__"):
            detected_lineage = detected_lineage.replace("k__", "d__")
        return detected_lineage
    
    logging.info("Looking up lineage for taxid {} in ENA".format(insdc_taxid))
    try:
        lineage = lookup_lineage_in_ena(insdc_taxid)
        return lineage
    except Exception as ena_e:
        logging.error("Unable to retrieve lineage from ENA due to error: {}. Trying taxonkit.".format(ena_e))
        try:
            lineage = get_lineage(insdc_taxid, TAXDUMP_PATH)
            if lineage == ";;;;;;":
                raise Exception("Empty lineage in taxdump for {}".format(insdc_taxid))
            logging.debug("Got INSDC lineage from taxdump", lineage)
            return lineage
        except Exception as e:
            logging.error("Error: {}".format(str(e)))
            try:
                lineage = get_lineage(insdc_taxid, TAXDUMP_PATH_NEW_VER)
                if lineage == ";;;;;;":
                    raise Exception("Empty lineage in taxdump for {}".format(insdc_taxid))
                logging.debug("Got INSDC lineage from taxdump", lineage)
                return lineage
            except Exception as e:
                logging.error("Unable to retrieve lineage from taxid {} from taxdump and ENA. Taxdump error: {}. "
                              "ENA error: {}".format(insdc_taxid, e, ena_e))
                sys.exit("Aborting.")


def lookup_lineage_in_ena(insdc_taxid):
    logging.debug("Function lookup_lineage_in_ena")
    assert insdc_taxid, "Cannot lookup lineage in ENA without a taxid"
    url = "https://www.ebi.ac.uk/ena/taxonomy/rest/tax-id/{}".format(insdc_taxid)
    r = run_full_url_request(url)
    res = json.loads(r.text)
    lineage = res.get("lineage", "")
    scientific_name = res.get("scientificName", "")
    logging.debug("Lineage is {}".format(lineage))
    logging.debug("Scientific name is {}".format(scientific_name))
    reformatted_lineage = reformat_lineage(lineage, scientific_name)
    return reformatted_lineage
    

def reformat_lineage(lineage, scientific_name):
    logging.debug("Function reformat_lineage")
    higher_level = False
    ranks_values = dict()
    split_lineage = lineage.strip().split(";")
    for element in split_lineage:
        element = element.lstrip()
        logging.debug(element)
        if element and not element.isspace():
            submittable, taxid, rank = query_scientific_name_from_ena(element, search_rank=True)
            if rank == ("superkingdom"):
                rank = "kingdom"
            if element.lower() == scientific_name.lower() and rank not in ["subspecies", "species"]:
                higher_level = True
                logging.info("Scientific name {} is already part of lineage {}".format(scientific_name, lineage))
            ranks_values[rank] = element
            logging.debug(element, submittable, taxid, rank)
    _, _, lowest_rank = query_scientific_name_from_ena(scientific_name, search_rank=True)
    if lowest_rank and not lowest_rank == "no rank":
        if lowest_rank == "subspecies":
            ranks_values["species"] = scientific_name
        else:
            ranks_values[lowest_rank] = scientific_name
    else:
        if higher_level:
            pass
        else:
            if "species" not in ranks_values:
                ranks_values["species"] = scientific_name
            else:
                logging.debug("Unresolved placement of scientific name {} in lineage {}".format(scientific_name, lineage))
    ranks = ['kingdom', 'phylum', 'class', 'order', 'family', 'genus', 'species']
    reformatted_lineage = ';'.join([f'{rank[0]}__{ranks_values.get(rank, "")}' for rank in ranks])
    logging.debug("Detected rank {} for scientific name {} in function reformat_lineage. After adding this to existing ranks we get {}. Formatted lineage now is {}.".format(lowest_rank, scientific_name, ranks_values, reformatted_lineage))
    if reformatted_lineage.startswith("k__"):
        reformatted_lineage = reformatted_lineage.replace("k__", "d__")
    
    logging.debug(reformatted_lineage)
    return reformatted_lineage
    
    
def parse_metadata(metadata_file):
    gca_accessions = dict()
    sample_accessions = dict()
    original_df = pd.read_csv(metadata_file, sep='\t')
    filtered_df = original_df[original_df['Genome'] == original_df['Species_rep']]
    for index, row in filtered_df.iterrows():
        sample_accessions[row['Genome']] = row['Sample_accession']
        if row['Genome_accession'].startswith("GCA"):
            gca_accessions[row['Genome']] = row['Genome_accession']
            logging.info("GCA accession already in metadata table {}".format(row['Genome_accession']))
    return gca_accessions, sample_accessions


def get_gca_accession(sample):
    logging.debug(sample)
    if not isinstance(sample, str):
        return "N/A"
    if sample == "NA" or sample.startswith("P"):
        return "N/A"
    api_endpoint = "https://www.ebi.ac.uk/ena/portal/api/filereport"
    full_url = "{}?accession={}&result=assembly&fields=accession".format(api_endpoint, sample)
    r = run_full_url_request(full_url)
    if r.ok:
        lines = r.text.split('\n')
        if len(lines) > 3:
            # check if the same GCA accession is duplicated; if there are distinct GCAs linked to the same 
            # sample accession, don't take any of them because we don't know which one is correct
            filtered_lines = list(set([item for item in lines if item != "" and item != "accession"]))
            if len(filtered_lines) == 1:
                gca_line = filtered_lines[0]
            else:
                gca_line = "N/A"
        else:
            try:
                gca_line = next(line for line in lines if line.startswith("GCA"))
            except:
                gca_line = "N/A"
        logging.debug(gca_line)
        return gca_line
    else:
        logging.error("Failed to load data from ENA API when querying sample {}".format(sample))
        sys.exit("Aborting.")
    

def lookup_taxid_online(gca_acc):
    logging.debug("Function lookup_taxid_online")
    if gca_acc == "N/A":
        return "N/A"
    api_endpoint = "https://www.ebi.ac.uk/ena/portal/api/search"
    query_params = {
        "result": "assembly",
        "query": 'accession="{}"'.format(gca_acc),
        "fields": "tax_id",
        "format": "json"
    }

    r = run_query_request(api_endpoint, query_params)
    if r.ok:
        data = r.json()
        taxid = data[0]['tax_id']
        return taxid
    else:
        sys.exit("Failed to fetch taxid for GCA accession {}. Aborting.".format(gca_acc))
        
    
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
    
    
def run_taxonkit_on_dict(lowest_taxon_mgyg_dict, lowest_taxon_lineage_dict):
    logging.debug("Function run_taxonkit_on_dict")
    input_data = "\n".join(set(lowest_taxon_mgyg_dict.values()))  # remove duplicate taxa and save all lines to a variable
    command = ["/homes/tgurbich/Taxonkit/taxonkit", "name2taxid", "--data-dir", TAXDUMP_PATH]
    try:
        result = subprocess.run(command, input=input_data, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, check=True)
        taxid_dict = process_taxonkit_output(result.stdout)
        filtered_taxid_dict = filter_taxid_dict(taxid_dict, lowest_taxon_lineage_dict)  # resolve cases where multiple taxid are assigned to taxon
        return filtered_taxid_dict
    except subprocess.CalledProcessError as e:
        print("Error:", e.stderr)


def filter_taxid_dict(taxid_dict, lowest_taxon_lineage_dict):
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
            filtered_taxid_dict.setdefault(taxon_name, dict())
            filtered_taxid_dict[taxon_name][lowest_taxon_lineage_dict[taxon_name][0]] = taxid_list[0]
        else:
            # if we are here, the taxon name has multiple taxids associated with it
            success = False 
            logging.debug("\n\n\n------------------> resolving duplicate {} {}".format(taxon_name, taxid_list))
            # go through taxids and identify the ones we need to keep
            for taxid in taxid_list:
                # get the lineage
                result = subprocess.run(command, input=taxid, text=True, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, check=True)
                try:
                    lineage = result.stdout.strip().split("\t")[1]
                    logging.debug("Checking dump lineage".format(lineage))
                    retrieved_name = re.sub(";+$", "", lineage).split(";")[-1]
                    assert retrieved_name, "Could not get retrieved name for lineage {}".format(lineage)
                    logging.debug("Checking name from dump lineage is {}".format(retrieved_name))
                    expected_domains_and_phyla = get_domains_and_phyla(lowest_taxon_lineage_dict[taxon_name])
                    logging.debug("expected phyla obtained: {}".format(expected_domains_and_phyla))
                    retrieved_domain = lineage.split(";")[0]
                    logging.debug("Checking domain {}".format(retrieved_domain))
                    if retrieved_domain in expected_domains_and_phyla:
                        logging.debug("Domain match")
                        for phylum in expected_domains_and_phyla[retrieved_domain]:
                            logging.debug("checking phylum {}".format(phylum))
                            if phylum == lineage.split(';')[1]:
                                logging.debug("Phylum match")
                                matching_lineage = pick_lineage(retrieved_domain, phylum,
                                                                lowest_taxon_lineage_dict[taxon_name], lineage)
                                if compare_positions(lineage, matching_lineage, taxon_name) and \
                                        last_non_empty_segment_position(lineage) == \
                                        last_non_empty_segment_position(matching_lineage):
                                    logging.debug("Positions match")
                                    success = True
                                    logging.debug("Saving {}".format(matching_lineage))
                                    filtered_taxid_dict.setdefault(taxon_name, dict())
                                    if matching_lineage not in filtered_taxid_dict[taxon_name]:
                                        filtered_taxid_dict[taxon_name][matching_lineage] = taxid
                                    else:
                                        logging.debug("###################### Multiple matching taxids: {}".format(
                                            matching_lineage))
                                        
                                else:
                                    logging.debug("levels are different")
                            else:
                                matching_lineage = pick_lineage(retrieved_domain, phylum,
                                                                lowest_taxon_lineage_dict[taxon_name], lineage)
                                if (taxon_name in synonyms[taxid] and last_non_empty_segment_position(lineage) == 
                                    last_non_empty_segment_position(matching_lineage)):
                                    success = True
                                    logging.debug("Resolved lineage through synonyms")
                                    logging.debug("Saving {}".format(matching_lineage))
                                    filtered_taxid_dict.setdefault(taxon_name, dict())
                                    if matching_lineage not in filtered_taxid_dict[taxon_name]:
                                        filtered_taxid_dict[taxon_name][matching_lineage] = taxid
                    logging.debug("Lineage {} retrieved name {}".format(lineage, retrieved_name))
                    logging.debug("Lowest taxon {}".format(lowest_taxon_lineage_dict[taxon_name]))
                    # first check that the name matches
                except AssertionError as e:
                    logging.error("Assertion error: {}".format(e))
                except IndexError:
                    logging.error("Index error: Unable to extract lineage from result.stdout")
                except Exception as e:
                    logging.error("Error when processing taxid {}: {}".format(taxid, e))
                    sys.exit("Unable to find lineages for taxid {}".format(taxid))
            if not success:
                sys.exit("Unable to resolve taxonomy of {}. EXITING.".format(taxon_name)) 
    return filtered_taxid_dict


def last_non_empty_segment_position(lineage_string):
    logging.debug("Function last_non_empty_segment_position")
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


def pick_lineage(expected_domain, expected_phylum, lineage_list, dump_lineage):
    if len(lineage_list) == 1:
        return lineage_list[0]
    else:
        for lineage in lineage_list:
            domain, phylum = [part.replace("d__", "").replace("p__", "") for part in lineage.split(";")[:2]]
            if domain == expected_domain and phylum == expected_phylum and \
                    last_non_empty_segment_position(lineage) == last_non_empty_segment_position(dump_lineage):
                return lineage
    sys.exit("ERROR: could not resolve lineages: {} {} {}".format(expected_domain, expected_phylum, lineage_list))


def get_domains_and_phyla(lineage_list):
    expected_domains_and_phyla = dict()
    for lineage in lineage_list:
        domain, phylum = [part.replace("d__", "").replace("p__", "") for part in lineage.split(";")[:2]]
        expected_domains_and_phyla.setdefault(domain, list()).append(phylum)
    for key, values in expected_domains_and_phyla.items():
        expected_domains_and_phyla[key] = list(set(values))
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
            else:
                taxon, taxid = parts[:2]
                taxid_dict.setdefault(taxon, list()).append(taxid)
    return taxid_dict


def get_lowest_taxa(tax_dict):
    logging.debug("Function get_lowest_taxa")
    lowest_taxon_mgyg_dict = dict()
    lowest_taxon_lineage_dict = dict()
    for mgyg, lineage in tax_dict.items():
        lowest_known_taxon, lowest_known_rank = get_lowest_taxon(lineage)
        lowest_taxon_mgyg_dict[mgyg] = lowest_known_taxon
        lowest_taxon_lineage_dict.setdefault(lowest_known_taxon, list()).append(lineage)
    for key, value in lowest_taxon_lineage_dict.items():
        lowest_taxon_lineage_dict[key] = list(set(value))  # remove repeat lineages
    return lowest_taxon_mgyg_dict, lowest_taxon_lineage_dict
    
    
def get_lowest_taxon(lineage):
    elements = lineage.strip().split(";")
    for i in reversed(elements):
        if not i.endswith("__"):
            return i.split("__")[1], i.split("__")[0]
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


@retry(tries=5, delay=10, backoff=1.5)
def run_full_url_request(full_url):
    r = requests.get(url=full_url)
    r.raise_for_status()
    return r


@retry(tries=5, delay=10, backoff=1.5)
def run_query_request(api_url, query_params):
    r = requests.get(api_url, params=query_params)
    r.raise_for_status()
    return r

    
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
    parser.add_argument('-m', '--metadata', required=True,
                        help='Path to the metadata table.')
    parser.add_argument('-s', '--species-level-taxonomy', action='store_true',
                        help='Flag to assign species-level taxonomy to everything (as uncultured X species)')
    parser.add_argument('-t', '--threads', required=True, type=int,
                        help='Number of threads to use (only helps if --species-level-taxonomy flag is used')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.gtdbtk_folder, args.outfile, args.taxonomy_version, args.taxonomy_release, args.metadata, 
         args.species_level_taxonomy, args.threads)
    