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


import urllib.parse

import requests

# TODO: the methods in this file are repated in "containers/genomes-catalog-update/scripts/fetch_ena.py"
#       merge both.


def qs50(contamination, completeness):
    contam_cutoff = 5.0
    qs_cutoff = 50.0
    if contamination > contam_cutoff:
        return False
    elif completeness - contamination * 5 < qs_cutoff:
        return False
    else:
        return True


# @retry(tries=5, delay=10, backoff=1.5)
def run_request(query, api_endpoint):
    r = requests.get(api_endpoint, params=urllib.parse.urlencode(query))
    r.raise_for_status()
    return r
