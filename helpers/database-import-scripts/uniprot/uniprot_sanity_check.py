#!/usr/bin/env python3

import argparse
import concurrent.futures
import json
import sys

import requests
from retry import retry


def main(input_file):
    no_errors = True
    species_level_gca = non_species_gca_justified = non_species_gca_unjustified = species_level_na = \
        non_species_level_na = 0
    print("started loading gca lineages")
    gca_lineages = get_gca_lineages(input_file)
    print("finished loading gca lineages")
    with open(input_file, "r") as file_in:
        for line in file_in:
            justified = False
            mgyg, name, lineage, gca, taxid, species_level, _ = line.strip().split("\t")
            if lineage.startswith("k_"):
                print("Incorrect format of lineage {}".format(lineage))
                no_errors = False
            if lineage.lower().startswith("d_virus"):
                no_errors = False
                print("Wrong domain: {}".format(lineage))
            if gca.startswith("GCA"):
                gca_taxid, gca_scientific_name = gca_taxid_lookup(gca)
                if any(n in gca_scientific_name for n in ["metagenome", "uncultured bacterium"]):
                    # it is ok if our taxonomy doesn't match because the reported ENA taxonomy is questionable
                    justified = True
                    if not check_sp_name(lineage):
                        no_errors = False
                        print("Species name is one word in {} {}".format(mgyg, lineage))
                else:
                    if not gca_taxid == taxid:
                        if domain_ok(gca_taxid):
                            print("Taxid mismatch: {} File: {} GCA: {}".format(mgyg, taxid, gca_taxid))
                            no_errors = False
                        else:
                            justified = True
                            if not check_sp_name(lineage):
                                no_errors = False
                                print("Species name is one word in {} {}".format(mgyg, lineage))
                    elif not gca_scientific_name.lower() == name.lower():
                        print("Wrong scientific name: {} GCA: {} File: {} GCA taxid: {} File taxid: {}".format(mgyg, gca_scientific_name, name, gca_taxid, taxid))
                        no_errors = False
                    else:
                        expected_lineage = gca_lineages[gca]
                        if not expected_lineage.lower() == lineage.lower():
                            print("Lineage mismatch: {} {} {}".format(mgyg, expected_lineage, lineage))
                            no_errors = False
            else:
                if not check_sp_name(lineage):
                    no_errors = False
                    print("Species name is one word in {} {}".format(mgyg, lineage))
            if gca.startswith("GCA"):
                if lineage.endswith("__"):
                    if justified:
                        non_species_gca_justified += 1
                    else:
                        non_species_gca_unjustified += 1
                else:
                    species_level_gca += 1
            else:
                if lineage.endswith("__"):
                    non_species_level_na += 1
                else:
                    species_level_na += 1
                        
    if non_species_gca_unjustified:
        no_errors = False
        print("Missing species levels for {} lineages (GCA known, no reason for high level)".format(
            str(non_species_gca_unjustified)))
    if no_errors:
        print("OK")
    print("GCA: sp level: {} non-sp justified: {} non-sp unjustified: {} N/A: sp level: {} non-sp: {}".format(
        species_level_gca, non_species_gca_justified, non_species_gca_unjustified, species_level_na, 
        non_species_level_na))


def check_sp_name(lineage):
    if not lineage.endswith("_"):
        elements = lineage.strip().split(";")
        if " " in elements[-1]:
            return True
        else:
            return False
    else:
        return True


def get_gca_lineages(file):
    threads = 16
    gca_accs = [line.strip().split('\t')[3] for line in open(file, 'r') if
                       len(line.strip().split('\t')) >= 4]
    gca_accs = list(set(gca_accs))
    if "N/A" in gca_accs:
        gca_accs.remove("N/A")
    gca_taxids = dict()
    gca_lineages = dict()
    print("loading taxa")
    for acc in gca_accs:
        taxid, _ = gca_taxid_lookup(acc)
        gca_taxids[acc] = taxid
    print("loading lineages")
    with concurrent.futures.ThreadPoolExecutor(max_workers=threads) as executor:
        taxid_lineages = {gca: lineage for gca, lineage in zip(gca_taxids.values(), executor.map(get_expected_lineage, gca_taxids.values()))} 
    for gca, taxid in gca_taxids.items():
        gca_lineages[gca] = taxid_lineages[taxid]
    return gca_lineages


def get_expected_lineage(taxid):
    url = "https://www.ebi.ac.uk/ena/taxonomy/rest/tax-id/{}".format(taxid)
    r = run_full_url_request(url)
    res = json.loads(r.text)
    lineage = res.get("lineage", "")
    scientific_name = res.get("scientificName", "")
    lineage = lineage + scientific_name
    build_lineage = dict()
    formatted_lineage = ""
    ranks = ['domain', 'phylum', 'class', 'order', 'family', 'genus', 'species']
    elements = lineage.strip().split("; ")
    for e in elements:
        _, _, rank = query_scientific_name_from_ena(e, search_rank=True)
        if rank == "subspecies":
            rank = "species"
        elif rank in ["superkingdom", "kingdom"]:
            rank = "domain"
        if rank in ranks:
            build_lineage[rank] = e
    for r in ranks:
        if r in build_lineage:
            formatted_lineage = formatted_lineage + "{}__{};".format(r[0], build_lineage[r])
        else:
            formatted_lineage = formatted_lineage + "{}__;".format(r[0])
    if formatted_lineage.endswith(";"):
        formatted_lineage = formatted_lineage[:-1]
    if formatted_lineage.endswith("__"):
        _, _, rank = query_scientific_name_from_ena(scientific_name, search_rank=True)
        if rank == "no rank" and " " in scientific_name:
            formatted_lineage = formatted_lineage + scientific_name
    return formatted_lineage


def query_scientific_name_from_ena(scientific_name, search_rank=False):
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
    
    
def domain_ok(taxid):
    url = "https://www.ebi.ac.uk/ena/taxonomy/rest/tax-id/{}".format(taxid)
    r = run_full_url_request(url)
    res = json.loads(r.text)
    lineage = res.get("lineage", "")
    if lineage.lower().startswith("virus"):
        return False
    else:
        return True


@retry(tries=5, delay=10, backoff=1.5)
def run_full_url_request(full_url):
    r = requests.get(url=full_url)
    r.raise_for_status()
    return r
    

def gca_taxid_lookup(gca_acc):
    api_endpoint = "https://www.ebi.ac.uk/ena/portal/api/search"
    query_params = {
        "result": "assembly",
        "query": 'accession="{}"'.format(gca_acc),
        "fields": "tax_id, scientific_name",
        "format": "json"
    }

    r = run_query_request(api_endpoint, query_params)
    if r.ok:
        data = r.json()
        taxid = data[0]['tax_id']
        scientific_name = data[0]['scientific_name']
        return taxid, scientific_name
    else:
        sys.exit("Failed to fetch taxid for GCA accession {}. Aborting.".format(gca_acc))
    

@retry(tries=5, delay=10, backoff=1.5)
def run_query_request(api_url, query_params):
    r = requests.get(api_url, params=query_params)
    r.raise_for_status()
    return r
    
    
def parse_args():
    parser = argparse.ArgumentParser(description="The script takes in the pre-processed taxonomy file generated by "
                                                 "preprocess_taxonomy_for_uniprot.py and checks that there are "
                                                 "no obvious errors.")
    parser.add_argument('-i', '--input-file', required=True,
                        help='Path to the pre-processed taxonomy file generated by preprocess_taxonomy_for_uniprot.py.')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.input_file)
