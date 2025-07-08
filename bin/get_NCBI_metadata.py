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


import json

import requests
import time

NCBI_SEARCH_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
NCBI_SUMMARY_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi"
RETRY_ATTEMPTS = 3
RETRY_DELAY_MIN = 15


def get_json(url):
    for attempt in range(1, RETRY_ATTEMPTS + 1):
        try:
            r = requests.get(url, timeout=10)
            if r.ok:
                return r.text
            else:
                print(
                    f"Request failed with status code {r.status_code}. Retrying in {RETRY_DELAY_MIN * attempt} "
                    f"seconds...")
        except requests.exceptions.RequestException as e:
            print(f"Attempt {attempt} failed with exception: {e}. Retrying in {RETRY_DELAY_MIN * attempt} seconds...")

        time.sleep(RETRY_DELAY_MIN * attempt)

    print("All retry attempts failed.")
    return None
    
    
def get_ncbi_api_id(accession, db):
    json_url = "{}?db={}&term={}&format=json".format(NCBI_SEARCH_URL, db, accession)
    data_raw = get_json(json_url)
    if data_raw is None:
        print("Were not able to get an NCBI ID for {}".format(accession))
        return None
    else:
        data_json = json.loads(data_raw)
        try:
            id_list = data_json['esearchresult']['idlist']
            if len(id_list) > 1:
                print("Id list for accession {} is too long".format(accession))
                return None
            else:
                return id_list[0]
        except:
            print("Unable to get idlist for accession {}".format(accession))
            return None


def get_location_from_id(id, db):
    json_url = "{}?db={}&id={}&format=json".format(NCBI_SUMMARY_URL, db, id)
    data_raw = get_json(json_url)
    if data_raw is None:
        print("Unable to get sample from id {}".format(id))
        return None
    else:
        data_json = json.loads(data_raw)
        try:
            geographic_location = \
                data_json['result'][id]['sampledata'].split('display_name="geographic location">')[1].split(
                    '</Attribute>')[0]
            return geographic_location
        except:
            print("Unable to parse out geographic location for id {}".format(id))
            return None
        

def get_sample_location_from_ncbi(accession):
    id = get_ncbi_api_id(accession, "biosample")
    location = get_location_from_id(id, "biosample")
    return location
