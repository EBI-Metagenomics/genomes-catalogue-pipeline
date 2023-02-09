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


def get_gca_location(sample_id):
    location = ''
    json_data = load_gca_json(sample_id)
    geo_data_list = json_data['characteristics']['geo loc name']
    for item in geo_data_list:
        if 'text' in item:
            location = item['text'].strip().split(':')[0]
            break
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


def load_gca_json(sample_id):
    json_url = 'https://www.ebi.ac.uk/biosamples/samples/{}.json'.format(sample_id)
    r = requests.get(json_url)
    if r.ok:
        json_data = r.json()
        return json_data
    else:
        print('Could not retrieve json for sample', sample_id)
        print(r.text)
        return None


#test_sample = 'SAMEA6774373'
#test_sample = 'SAMN14571041'  # GCA
#cont, comp = get_contamination_completeness(test_sample)
#location = get_location_gca(test_sample)
#print(cont, comp, location)
#print(location)

#xml_res = load_xml('GCA_015260435')
#print(xml_res)
#project = xml_res['ASSEMBLY_SET']['ASSEMBLY']['STUDY_REF']['IDENTIFIERS']['PRIMARY_ID']
#print(project)
