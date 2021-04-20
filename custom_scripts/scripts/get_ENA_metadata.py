#!/usr/bin/env python3
# coding=utf-8

import requests
import json
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

