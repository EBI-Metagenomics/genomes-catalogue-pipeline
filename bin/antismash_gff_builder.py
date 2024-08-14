#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2024 EMBL - European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The script is part of mgnify-pipelines-toolkit: https://github.com/EBI-Metagenomics/mgnify-pipelines-toolkit

import argparse
from collections import defaultdict
import json

import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input', required=True, type=str, help='Input JSON from antiSMASH')
    parser.add_argument('-o', '--output', required=True, type=str, help='Output GFF3 file name')
    parser.add_argument('--cds_tag', default='ID', type=str,
                        help='Type of CDS ID tag to use in the GFF3 (to account for CDS identifier changes between'
                             'tools) (default: locus_tag)')  
    args = parser.parse_args()

    return args.input, args.output, args.cds_tag


def main():
    """ Transform an antiSMASH JSON into a GFF3 with 'regions' and CDS within those regions
    """

    json_input, output_file, cds_tag = parse_args()

    with open(json_input, 'r') as json_data:
        antismash_analysis = json.load(json_data)

    res_dict = defaultdict(list)
    attributes_dict = defaultdict(dict)

    antismash_ver = antismash_analysis['version']

    for record in antismash_analysis['records']:
        record_id = record['id']

        iter_cds = 'antismash.detection.genefunctions' in record['modules'].keys()  # Flag to iterate CDS
        region_name = None

        for feature in record['features']:

            if feature['type'] == 'region':
                # Annotate region features
                region_name = f"{record_id}_region{feature['qualifiers']['region_number'][0]}"
                region_start = int(feature['location'].split(':')[0].split('[')[1])
                region_end = int(feature['location'].split(':')[1].split(']')[0])

                res_dict['contig'].append(record_id)
                res_dict['version'].append(f"antiSMASH:{antismash_ver}")
                res_dict['type'].append('region')
                res_dict['start'].append(region_start + 1)
                res_dict['end'].append(region_end)
                res_dict['score'].append('.')
                res_dict['strand'].append('.')
                res_dict['phase'].append('.')

                product = ','.join(feature['qualifiers'].get('product', []))

                attributes_dict[region_name].update({'ID': region_name, 'product': product})

            if iter_cds and feature['type'] == 'CDS':
                # Annotate CDS features

                start = int(feature['location'].split(':')[0][1:])
                end = int(feature['location'].split(':')[1].split(']')[0])
                strand = feature['location'].split('(')[1][0]  # + or -

                if not region_name or not (region_start <= end and start <= region_end):
                    continue

                res_dict['contig'].append(record_id)
                res_dict['version'].append(f"antiSMASH:{antismash_ver}")
                res_dict['type'].append('gene')
                res_dict['start'].append(start + 1)  # Correct for 1-based indexing
                res_dict['end'].append(end)
                res_dict['score'].append('.')
                res_dict['strand'].append(strand)
                res_dict['phase'].append('.')

                locus_tag = feature['qualifiers'][cds_tag][0]
                attributes_dict[locus_tag].update({
                    'ID': locus_tag,
                    'as_type': ','.join(feature['qualifiers'].get('gene_kind', ['other'])),
                    'gene_functions': ','.join(feature['qualifiers'].get('gene_functions', [])).replace(' ',
                                                                                                        '_').replace(
                        ':_', ':').replace(';_', '%3B'),
                    'Parent': region_name
                })

        # Extended CDS attributes 
        if 'antismash.detection.hmm_detection' in record['modules'].keys():
            cds_by_protocluster = record['modules']['antismash.detection.hmm_detection']['rule_results'][
                'cds_by_protocluster']
            if len(cds_by_protocluster) > 0:
                for feature in cds_by_protocluster[0][1]:
                    if 'cds_name' in feature.keys():
                        locus_tag = feature['cds_name']
                        as_clusters = ','.join(list(feature['definition_domains'].keys()))
                        if locus_tag in attributes_dict.keys():
                            attributes_dict[locus_tag].update({'as_gene_clusters': as_clusters})

        if 'antismash.detection.genefunctions' in record['modules'].keys():
            for tool in record['modules']['antismash.detection.genefunctions']['tools']:
                if tool['tool'] == 'smcogs':
                    for locus_tag in tool['best_hits']:
                        hit_id = tool['best_hits'][locus_tag]['hit_id'].split(':')[0]
                        hit_desc = tool['best_hits'][locus_tag]['hit_id'].split(':')[1].replace(' ', '_')
                        score = tool['best_hits'][locus_tag]['bitscore']
                        e_value = tool['best_hits'][locus_tag]['evalue']

                        smcog_note = f"smCOG:{hit_id}:{hit_desc.replace(' ', '_')}(Score:{score}%3BE-value:{e_value})"
                        if locus_tag in attributes_dict.keys():
                            attributes_dict[locus_tag].update({'as_notes': smcog_note})
                        break

    attributes = [';'.join(f"{k}={v}" for k, v in attrib_data.items() if v) for attrib_data in attributes_dict.values()]
    res_dict['attributes'] = attributes

    res_df = pd.DataFrame.from_dict(res_dict)

    with open(output_file, 'w') as f_out:
        f_out.write('##gff-version 3\n')  # Save data to the GFF3 file with the proper header
        res_df.to_csv(f_out, header=False, index=False, sep='\t')


if __name__ == '__main__':
    main()