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


def get_metadata(acc, disable_ncbi_lookup):
    location = None
    project = "N/A"
    biosample = "N/A"
    error_text = ""
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
            logging.info(f"Missing metadata in ENA XML for sample {acc}. Using API instead.")
            try:
                biosample, project = ena_api_request(acc)
            except:
                logging.exception(f"Could not obtain biosample and project information for {acc}")
                error_text += f"Could not obtain biosample and project information for {acc} ."
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
                        f"Unable to get location from ENA for sample {biosample} (genome {acc}) which is unexpected. "
                        f"Trying NCBI.")
                    error_text += f"Had to get location from NCBI for sample {biosample} (genome {acc})"
                    location = get_sample_location_from_ncbi(biosample)
                    logging.error(
                        f"MAJOR WARNING: had to get location for sample {biosample} from NCBI. Location acquired: "
                        f"{location}"
                    )
                else:
                    logging.warning(
                        f"Unable to obtain location for sample {biosample} (genome {acc}), which is unexpected. Unable "
                        f"to look up the location in NCBI because the --disable-ncbi-lookup flag is used. Returning "
                        f"'not provided'")
                    location = "not provided"
    if not location:
        logging.warning(f"Unable to obtain location for sample {biosample} (genome {acc})")
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
        error_text += f"Could not find any information for genome {acc}, user has to fill manually. "
        converted_sample = "FILL"
        converted_project = "FILL"
        location = "FILL"
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
