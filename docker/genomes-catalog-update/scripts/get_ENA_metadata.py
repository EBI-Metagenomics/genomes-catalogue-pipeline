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
import xmltodict


def get_contamination_completeness(sample_id):
    contamination = ''
    completeness = ''
    json_data = load_xml(sample_id)
    for attribute in json_data['SAMPLE_SET']['SAMPLE']['SAMPLE_ATTRIBUTES']['SAMPLE_ATTRIBUTE']:
        if attribute.get('TAG') == 'completeness score':
            completeness = attribute.get('VALUE')
        elif attribute.get('TAG') == 'contamination score':
            contamination = attribute.get('VALUE')
        elif attribute.get('TAG') == 'ENA-CHECKLIST':
            checklist = attribute.get('VALUE')
            if checklist != 'ERC000047':
                print('WARNING: checklist for {} is {}; expected checklist: ERC000047'.
                      format(sample_id, checklist))
        else:
            pass
    return contamination, completeness


def get_location(sample_id):
    location = ''
    json_data = load_xml(sample_id)
    for attribute in json_data['SAMPLE_SET']['SAMPLE']['SAMPLE_ATTRIBUTES']['SAMPLE_ATTRIBUTE']:
        if attribute.get('TAG') == 'geographic location (country and/or sea)':
            location = attribute.get('VALUE')
    return location


def load_xml(sample_id):
    xml_url = 'https://www.ebi.ac.uk/ena/browser/api/xml/{}'.format(sample_id)
    r = requests.get(xml_url)
    if r.ok:
        data_dict = xmltodict.parse(r.content)
        json_dump = json.dumps(data_dict)
        json_data = json.loads(json_dump)
        return json_data
    else:
        print('Could not retrieve xml for sample', sample_id)
        print(r.text)
        return None


#test_sample = 'SAMEA6774373'
#cont, comp = get_contamination_completeness(test_sample)
#location = get_location(test_sample)
#print(cont, comp, location)