#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Copyright 2023 EMBL - European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
import argparse
import json
from collections import namedtuple

import logging

logger = logging.getLogger(__name__)

BGC = namedtuple("BGC", "contig_name bgc_name start end orfs")
ORF = namedtuple("ORF", "locus_tag start end strand type product")


def load_regions_json(json_file) -> list[BGC]:
    """Load the gene types from the json
    The structure of the json is:
    {
        "length": 4688977,
        "seq_id": "contig_4",
        "regions": [{
            "start": 1185393,
            "end": 1205746,
            "idx": 1,
            "orfs": [
                {
                "start": 1187624,
                "end": 1188664,
                "strand": 1,
                "locus_tag": "BU_ATCC8492_00951",
                "type": "biosynthetic-additional",
                "description": "<div class=\"focus-intro\">\n <strong><span class=\"serif\">BU_ATCC8492_00951</span></strong><br>... ",
                "dna": "ATGCAGAAACGACCTCT...",
                "translation": "MQKRPLLGLT...",
                "product": "Dual-specificity RNA methyltransferase RlmN"
            },...
        ],..
    }
    Note: this json file is build from the regions.js file of the html output of antiSMASH.
    To build the json file:
    echo ";var fs = require('fs'); fs.writeFileSync('./regions.json', JSON.stringify(recordData));" >> convert_to_json.js
    node geneclusters.js # this will generate the geneclusters.json file
    """

    bgcs = []

    with open(json_file) as json_handle:
        json_dict = json.load(json_handle)
        for bgc_entry in json_dict:
            regions = bgc_entry.get("regions")
            if not regions:
                # ignore this contig, no bgc found
                continue
            for region in regions:
                index = region["idx"]
                region_start = region["start"]
                region_end = region["end"]
                bgc_orfs = []
                for orf in region.get("orfs", []):
                    bgc_orfs.append(
                        ORF(
                            locus_tag=orf["locus_tag"],
                            start=orf["start"],
                            end=orf["end"],
                            strand=int(orf["strand"]),
                            product=orf["product"],
                            type=orf["type"],
                        )
                    )
                bgcs.append(
                    BGC(
                        contig_name=bgc_entry["seq_id"],
                        bgc_name=f"{bgc_entry['seq_id']}_bgc{index}",
                        start=region_start,
                        end=region_end,
                        orfs=bgc_orfs,
                    )
                )

    return bgcs


def build_gff(regions_json, antismash_version):
    """Build the GFF from the geneclusters and the EMBL file"""
    bgc_regions: list[BGC] = load_regions_json(regions_json)
    for bgc in bgc_regions:
        # BGC region "parent"
        yield [
            bgc.contig_name,
            f"antiSMASH:{antismash_version}",
            "biosynthetic-gene-cluster",
            bgc.start,
            bgc.end,
            ".",
            ".",
            ".",
            f"ID={bgc.bgc_name}",
        ]
        orf: ORF
        for orf in bgc.orfs:
            ninth_column = [
                f"ID={orf.locus_tag}",
                f"Parent={bgc.bgc_name}",
            ]
            if orf.product:
                ninth_column.append(f"product={orf.product}")
            if orf.type:
                ninth_column.append(f"function={orf.type}")

            yield [
                bgc.contig_name,
                f"antiSMASH:{antismash_version}",
                "CDS",
                orf.start,  # FIXME, shoud we correct offset (gff are +1)?
                orf.end,
                ".",  # TODO, it should be possible to get the confidence score from the antismash gbk result file
                "+" if orf.strand == 1 else "-",
                ".",
                ";".join(ninth_column),
            ]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Build an antiSMASH gff from the gbk and regionsjs json~fied file"
    )
    parser.add_argument(
        "-r",
        dest="regions",
        help="antiSMASH json-fied regions.js file (it should be regions.json not .js)",
        required=True,
    )
    parser.add_argument(
        "-a",
        dest="antismash_version",
        help="The version of antiSMASH",
        required=True,
    )
    parser.add_argument("-o", dest="out", help="Ouput GFF file name", required=True)
    args = parser.parse_args()

    with open(args.out, "w") as out_handle:
        print("##gff-version 3", file=out_handle)
        for row in build_gff(args.regions, args.antismash_version):
            print("\t".join(map(str, row)), file=out_handle)
