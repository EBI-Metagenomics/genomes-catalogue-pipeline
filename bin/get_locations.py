#!/usr/bin/env python3
# coding=utf-8

# This file is part of MGnify genomes catalogue pipeline.
#
# MGnify genomes catalogue pipeline is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MGnify genomes catalogue pipeline is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with MGnify genomes catalogue pipeline. If not, see <https://www.gnu.org/licenses/>.


import argparse
import logging
import re
import sys

from get_ENA_metadata import get_location, load_xml, get_gca_location
from get_NCBI_metadata import *

from retry import retry

logging.basicConfig(level=logging.INFO)


def main(input_file, geofile, disable_ncbi_lookup):
    outfile = input_file + ".locations"
    warnings_file = "warnings.txt"
    countries_continents = load_geography(geofile)
    with open(input_file, "r") as in_f, open(outfile, "w") as out_f, open(warnings_file, "w") as warn_f:
        for line in in_f:
            original_acc = line.strip()
            sample, project, country, error_text = get_metadata(original_acc, disable_ncbi_lookup)
            country = refine_country_name(country)
            if country not in countries_continents:
                if country == "Antarctica":
                    continent = "Antarctica"
                else:
                    continent = "not provided"
                    if country.lower() in ["not provided", "not collected", "not present", "na", "n/a"]:
                        error_text += (f"Submitter did not provide a location for genome {original_acc}. "
                                       f"Submitted value: '{country}'. Recording country and continent as "
                                       f"'not provided'.")
                        country = "not provided"
                    else:
                        error_text += (f"Found location {country} for genome {original_acc}. Location not present in "
                                       f"the countries file. Reporting continent as 'not provided'.")
            else:
                continent = countries_continents[country]
            out_f.write(f"{original_acc}\t{sample}\t{project}\t{country}\t{continent}\n")
            if error_text:
                warn_f.write(error_text + "\n")


def refine_country_name(country):
    if ":" in country:
        country = country.split(":")[0]
    if country in ["USA", "United States", "United States of America"]:
        return "US"
    if country == "Russia":
        return "Russian Federation"
    if country in ["UK", "England", "Scotland", "Wales", "Northern Ireland"]:
        return "United Kingdom"
    if country == "Viet Nam":
        return "Vietnam"
    return country


def get_erz_metadata(acc):
    json_data = load_xml(acc)
    if not json_data:
        logging.error(f"No XML data returned for {acc}")
        sys.exit(1)

    try:
        analysis = json_data["ANALYSIS_SET"]["ANALYSIS"]
        # Analysis can sometimes be a list
        if isinstance(analysis, list):
            analysis = analysis[0]
        biosample = analysis["SAMPLE_REF"]["IDENTIFIERS"]["EXTERNAL_ID"]["#text"]
    except KeyError:
        logging.error(f"Unable to obtain biosample for {acc} - json does not contain expected fields.")
        sys.exit(1)

    try:
        project = analysis["STUDY_REF"]["IDENTIFIERS"]["SECONDARY_ID"]
    except KeyError:
        logging.error(f"Unable to obtain project accession for {acc} - json does not contain expected fields.")
        sys.exit(1)

    return biosample, project


def get_gca_metadata(acc):
    error_text = ""
    try:
        json_data = load_xml(acc)
        biosample = json_data["ASSEMBLY_SET"]["ASSEMBLY"]["SAMPLE_REF"]["IDENTIFIERS"]["PRIMARY_ID"]
        project = json_data["ASSEMBLY_SET"]["ASSEMBLY"]["STUDY_REF"]["IDENTIFIERS"]["PRIMARY_ID"]
    except Exception:
        logging.info(f"Missing metadata in ENA XML for sample {acc}. Using API instead.")
        try:
            biosample, project = ena_api_request(acc)
        except Exception:
            logging.exception(f"Could not obtain biosample and project information for {acc}")
            biosample, project = "N/A", "N/A"
            error_text = f"Could not obtain biosample and project information for {acc}. "
    return biosample, project, error_text


def resolve_location(acc, biosample, disable_ncbi_lookup):
    location = "not provided"
    error_text = ""
    try:
        if acc.startswith("GCA"):
            location = get_gca_location(biosample)
        else:
            location = get_location(biosample)
    except Exception:
        if not disable_ncbi_lookup:
            logging.info(f"Trying NCBI for biosample {biosample} (genome {acc})")
            error_text = f"Had to get location from NCBI for sample {biosample} (genome {acc})"
            location = get_sample_location_from_ncbi(biosample)
            logging.error(f"MAJOR WARNING: Got location from NCBI: {location}")
        else:
            logging.warning(f"NCBI lookup disabled. Could not resolve location for {biosample} which is unexpected.")
    return location or "not provided", error_text


def convert_sample_id(biosample):
    try:
        json_data = load_xml(biosample)
        return json_data["SAMPLE_SET"]["SAMPLE"]["IDENTIFIERS"]["PRIMARY_ID"]
    except Exception:
        return biosample


def convert_project_id(project):
    try:
        json_data = load_xml(project)
        return json_data["PROJECT_SET"]["PROJECT"]["IDENTIFIERS"]["SECONDARY_ID"]
    except Exception:
        return project


def get_metadata(acc, disable_ncbi_lookup):
    location = None
    error_text = ""
    if acc.startswith("ERZ"):
        # No errors tolerated here - if unable to get values, something is wrong
        biosample, project = get_erz_metadata(acc)
    elif acc.startswith("GCA"):
        biosample, project, error_text = get_gca_metadata(acc)
    elif acc.startswith("GUT"):
        # Return "FILL" for converted_project, converted_sample, and location
        return "FILL", "FILL", "FILL", f"Could not find any information for genome {acc}, user has to fill manually. "
    else:
        biosample, project = ena_api_request(acc)

    location, location_error = resolve_location(acc, biosample, disable_ncbi_lookup)
    error_text += location_error

    converted_sample = convert_sample_id(biosample) if not acc.startswith("GCA") else biosample
    converted_project = convert_project_id(project) if project != "N/A" else "N/A"
    
    return converted_sample, converted_project, location, error_text


def ena_api_request(acc):
    biosample = project = ""
    if not acc.startswith(("GCA", "ERZ", "GUT")):
        acc = acc + "0" * 7  # e.g. CAVPYQ01 -> CAVPYQ010000000
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


@retry(tries=3, delay=15, backoff=2)
def run_request(acc, url):
    try:
        r = requests.get(f"{url}/{acc}")
        r.raise_for_status()
        return r
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 429:
            logging.warning("Rate limit hit (429). Sleeping for 3 minutes before retrying...")
            time.sleep(180)  # Wait for 3 minutes
            raise
        else:
            raise


def load_geography(geofile):
    geography = dict()
    with open(geofile, "r") as file_in:
        for line in file_in:
            if not line.startswith("Continent"):
                fields = line.strip().split(",")
                geography[fields[1]] = fields[0]
    return geography


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Fetches sample name, project name and location from ENA for a list of genomes"
        )
    )
    parser.add_argument(
        "-i", "--input_file", help="Path to the file containing a list of genome accessions, one per line"
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
        "--disable-ncbi-lookup",
        action='store_true',
        help="Use this flag not to use NCBI as the fallback source of sample location. Default: False",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.input_file,
        args.geo,
        args.disable_ncbi_lookup,
    )
