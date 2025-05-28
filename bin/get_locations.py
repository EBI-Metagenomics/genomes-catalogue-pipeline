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
            if country not in countries_continents:
                error_text += (f"Found location {country} for genome {original_acc}. Location not present in the countries "
                               f"file. Replacing with 'not provided'.")
                country = "not provided"
                continent = "not provided"
            else:
                continent = countries_continents[country]
            out_f.write(f"{original_acc}\t{sample}\t{project}\t{country}\t{continent}\n")
            if error_text:
                warn_f.write(error_text + "\n")


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
            logging.info("Missing metadata in ENA XML for sample {}. Using API instead.".format(acc))
            try:
                biosample, project = ena_api_request(acc)
            except:
                logging.exception("Could not obtain biosample and project information for {}".format(acc))
                error_text += "Could not obtain biosample and project information for {} .".format(acc)
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
                        "Unable to get location from ENA for sample {} (genome {}) which is unexpected. "
                        "Trying NCBI.".format(biosample, acc))
                    error_text += "Had to get location from NCBI for sample {}".format(biosample)
                    location = get_sample_location_from_ncbi(biosample)
                    logging.error(
                        "MAJOR WARNING: had to get location for sample {} from NCBI. Location acquired: {}".format(
                            biosample,
                            location))
                else:
                    logging.warning(
                        "Unable to obtain location for sample {} (genome {}), which is unexpected. Unable to look up "
                        "the location in NCBI because the --disable-ncbi-lookup flag is used. Returning 'not "
                        "provided'".format(biosample, acc))
                    location = "not provided"
    if not location:
        logging.warning("Unable to obtain location for sample {} (genome {})".format(biosample, acc))
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
    return converted_sample, converted_project, location, error_text


def ena_api_request(acc):
    biosample = project = ""
    if not acc.startswith(("GCA", "ERZ", "GUT")):
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
