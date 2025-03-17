#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Copyright 2023-2025 EMBL - European Bioinformatics Institute
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
import re
import sys
from itertools import chain


def main(
    gff,
    ipr_file,
    eggnog_file,
    antismash_file,
    dbcan_file,
    rfam_file,
    trnascan_file,
    outfile,
):
    # load annotations and add them to existing CDS
    # here header contains leading GFF lines starting with "#",
    # main_gff_extended is a dictionary that contains Prokka GFF lines with added in additional annotations
    # fasta is the fasta portion of the Prokka GFF files
    header, main_gff_extended, fasta = load_annotations(
        gff,
        eggnog_file,
        ipr_file,
        antismash_file,
        dbcan_file,
    )

    ncrnas = get_ncrnas(rfam_file)
    trnas = get_trnas(trnascan_file)

    write_results_to_file(
        outfile, header, main_gff_extended, fasta, ncrnas, trnas
    )


def write_results_to_file(
    outfile, header, main_gff_extended, fasta, ncrnas, trnas
):
    with open(outfile, "w") as file_out:
        file_out.write("\n".join(header) + "\n")
        contig_list = list(main_gff_extended.keys())
        # check if there are any contigs that don't have CDS; if so add them in
        contig_list = check_for_additional_keys(
            ncrnas, trnas, contig_list
        )
        for contig in contig_list:
            sorted_pos_list = sort_positions(
                contig, main_gff_extended, ncrnas, trnas
            )
            for pos in sorted_pos_list:
                for my_dict in (ncrnas, trnas, main_gff_extended):
                    if contig in my_dict and pos in my_dict[contig]:
                        if isinstance(my_dict[contig][pos], dict):
                            list_to_print = list(chain(*my_dict[contig][pos].values()))  # merge dict lists into one
                        else:
                            list_to_print = my_dict[contig][pos]  # these are RNAs, they are already lists
                        for line in list_to_print:
                            if type(line) is str:
                                file_out.write(f"{line}\n")
                            else:
                                for element in line:
                                    file_out.write(element)
        for line in fasta:
            file_out.write(f"{line}\n")


def sort_positions(contig, main_gff_extended, ncrnas, trnas):
    sorted_pos_list = list()
    for my_dict in (main_gff_extended, ncrnas, trnas):
        if contig in my_dict:
            sorted_pos_list += list(my_dict[contig].keys())
    return sorted(list(set(sorted_pos_list)))


def check_for_additional_keys(ncrnas, trnas, contig_list):
    for my_dict in (ncrnas, trnas):
        dict_keys = set(my_dict.keys())
        absent_keys = dict_keys - set(contig_list)
        if absent_keys:
            contig_list = contig_list + list(absent_keys)
    return contig_list


def get_iprs(ipr_annot):
    iprs = {}
    antifams = list()
    if not ipr_annot:
        return iprs, antifams
    with open(ipr_annot, "r") as f:
        for line in f:
            cols = line.strip().split("\t")
            protein = cols[0]
            try:
                evalue = float(cols[8])
            except ValueError:
                continue
            if evalue > 1e-10:
                continue
            if cols[3] == "AntiFam":
                antifams.append(protein)
                continue
            if protein not in iprs:
                iprs[protein] = [set(), set()]
            if cols[3] == "Pfam":
                pfam = cols[4]
                iprs[protein][0].add(pfam)
            if len(cols) > 12:
                ipr = cols[11]
                if not ipr == "-":
                    iprs[protein][1].add(ipr)
    return iprs, antifams


def get_eggnog(eggnog_annot):
    eggnogs = {}
    with open(eggnog_annot, "r") as f:
        for line in f:
            line = line.rstrip()
            cols = line.split("\t")
            if line.startswith("#"):
                eggnog_fields = get_eggnog_fields(line)
            else:
                try:
                    evalue = float(cols[2])
                except ValueError:
                    continue
                if evalue > 1e-10:
                    continue
                protein = cols[0]
                eggnog = [cols[1]]

                cog = list(cols[eggnog_fields["cog_func"]])
                if len(cog) > 1:
                    cog = ["R"]

                kegg = cols[eggnog_fields["KEGG_ko"]].split(",")
                go = cols[eggnog_fields["GOs"]].split(",")
                eggnogs[protein] = [eggnog, cog, kegg, go]
    return eggnogs


def get_eggnog_fields(line):
    cols = line.strip().split("\t")
    try:
        index_of_go = cols.index("GOs")
    except ValueError:
        sys.exit("Cannot find the GO terms column.")
    if cols[8] == "KEGG_ko" and cols[15] == "CAZy":
        eggnog_fields = {"KEGG_ko": 8, "cog_func": 20, "GOs": index_of_go}
    elif cols[11] == "KEGG_ko" and cols[18] == "CAZy":
        eggnog_fields = {"KEGG_ko": 11, "cog_func": 6, "GOs": index_of_go}
    else:
        sys.exit("Cannot parse eggNOG - unexpected field order or naming")
    return eggnog_fields


def get_bgcs(bgc_file, prokka_gff, tool):
    cluster_positions = dict()
    tool_result = dict()
    bgc_annotations = dict()
    if not bgc_file:
        return bgc_annotations
    # save positions of each BGC cluster to dictionary cluster_positions
    # and save the annotations to dictionary bgc_result
    with open(bgc_file, "r") as bgc_in:
        for line in bgc_in:
            if not line.startswith("#"):
                (
                    contig,
                    _,
                    feature,
                    start_pos,
                    end_pos,
                    _,
                    _,
                    _,
                    annotations,
                ) = line.strip().split("\t")
                if tool == "sanntis":
                    for a in annotations.split(
                        ";"
                    ):  # go through all parts of the annotation field
                        if a.startswith("nearest_MiBIG_class="):
                            class_value = a.split("=")[1]
                        elif a.startswith("nearest_MiBIG="):
                            mibig_value = a.split("=")[1]
                elif tool == "gecco":
                    for a in annotations.split(
                        ";"
                    ):  # go through all parts of the annotation field
                        if a.startswith("Type="):
                            type_value = a.split("=")[1]
                elif tool == "antismash":
                    if feature != "gene":
                        continue
                    type_value = ""
                    as_product = ""
                    for a in annotations.split(
                        ";"
                    ):  # go through all parts of the annotation field
                        if a.startswith("as_type="):
                            type_value = a.split("=")[1]
                        elif a.startswith("as_gene_clusters="):
                            as_product = a.split("=")[1]
                # save cluster positions to a dictionary where key = contig name,
                # value = list of position pairs (list of lists)
                cluster_positions.setdefault(contig, list()).append(
                    [int(start_pos), int(end_pos)]
                )
                # save BGC annotations to dictionary where key = contig, value = dictionary, where
                # key = 'start_end' of BGC, value = dictionary, where key = feature type, value = description
                if tool == "sanntis":
                    tool_result.setdefault(contig, dict()).setdefault(
                        "_".join([start_pos, end_pos]),
                        {
                            "nearest_MiBIG_class": class_value,
                            "nearest_MiBIG": mibig_value,
                        },
                    )
                elif tool == "gecco":
                    tool_result.setdefault(contig, dict()).setdefault(
                        "_".join([start_pos, end_pos]),
                        {"bgc_type": type_value},
                    )
                elif tool == "antismash":
                    tool_result.setdefault(contig, dict()).setdefault(
                        "_".join([start_pos, end_pos]),
                        {"bgc_function": type_value},
                    )
                    if as_product:
                        tool_result[contig]["_".join([start_pos, end_pos])]["bgc_product"] = as_product
    # identify CDSs that fall into each of the clusters annotated by the BGC tool
    with open(prokka_gff, "r") as gff_in:
        for line in gff_in:
            if not line.startswith("#"):
                matching_interval = ""
                (
                    contig,
                    _,
                    _,
                    start_pos,
                    end_pos,
                    _,
                    _,
                    _,
                    annotations,
                ) = line.strip().split("\t")
                if contig in cluster_positions:
                    for i in cluster_positions[contig]:
                        if int(start_pos) in range(i[0], i[1] + 1) and int(
                            end_pos
                        ) in range(i[0], i[1] + 1):
                            matching_interval = "_".join([str(i[0]), str(i[1])])
                            break
                # if the CDS is in an interval, save cluster's annotation to this CDS
                if matching_interval:
                    cds_id = annotations.split(";")[0].split("=")[1]
                    if tool == "sanntis":
                        bgc_annotations.setdefault(
                            cds_id,
                            {
                                "nearest_MiBIG": tool_result[contig][matching_interval][
                                    "nearest_MiBIG"
                                ],
                                "nearest_MiBIG_class": tool_result[contig][
                                    matching_interval
                                ]["nearest_MiBIG_class"],
                            },
                        )
                    elif tool == "gecco":
                        bgc_annotations.setdefault(
                            cds_id,
                            {
                                "gecco_bgc_type": tool_result[contig][
                                    matching_interval
                                ]["bgc_type"],
                            },
                        )
                    elif tool == "antismash":
                        bgc_annotations.setdefault(
                            cds_id,
                            {
                                "antismash_bgc_function": tool_result[contig][
                                    matching_interval
                                ]["bgc_function"],
                            },
                        )
                        if "bgc_product" in tool_result[contig][matching_interval]:
                            bgc_annotations[cds_id]["antismash_product"] = tool_result[contig][matching_interval][
                                "bgc_product"]
            elif line.startswith("##FASTA"):
                break
    return bgc_annotations


def get_dbcan_individual_cazys(dbcan_file):
    dbcan_annotations = dict()
    if not dbcan_file:
        return dbcan_annotations
    with open(dbcan_file, "r") as f:
        for line in f:
            if line.startswith("#"):
                continue
            attributes = line.strip().split("\t")[8]
            attributes_dict = dict(
                re.split(r"(?<!\\)=", item) for item in re.split(r"(?<!\\);", attributes.rstrip(";"))
            )
            if "num_tools" in attributes_dict and int(attributes_dict["num_tools"]) < 2:
                continue  # don't keep annotations supported by only one tool within dbcan
            cds_pattern = r'\.CDS\d+$'
            protein = re.sub(cds_pattern, '', attributes_dict["ID"])  # remove the CDS number
            annotation_text = ""
            for field in ["protein_family", "substrate_dbcan-sub", "eC_number"]:
                if field in attributes_dict:
                    annotation_text += (f"{'dbcan_prot_family' if field == 'protein_family' else field}"
                                        f"={attributes_dict[field]};")
            dbcan_annotations[protein] = annotation_text
    return dbcan_annotations


def load_annotations(
    in_gff,
    eggnog_file,
    ipr_file,
    antismash_file,
    dbcan_file,
):
    eggnogs = get_eggnog(eggnog_file)
    iprs, antifams = get_iprs(ipr_file)
    antismash_bgcs = get_bgcs(antismash_file, in_gff, tool="antismash")
    dbcan_annotations = get_dbcan_individual_cazys(dbcan_file)
    added_annot = dict()
    main_gff = dict()
    header = []
    fasta = []
    fasta_flag = False
    gene_start_dict = dict()
    with open(in_gff, "r") as f:
        for line in f:
            line = line.strip()
            if len(line) > 0 and line[0] != "#" and not fasta_flag:
                line = line.replace("db_xref", "Dbxref")
                line = line.replace(";note=", ";Note=")
                line = line.replace("‘", "'").replace("’", "'")
                cols = line.split("\t")
                if len(cols) == 9:
                    contig, feature, start, attributes = (
                        cols[0],
                        cols[2],
                        cols[3],
                        cols[8],
                    )
                    attributes_dict = dict(
                        re.split(r"(?<!\\)=", item) for item in re.split(r"(?<!\\);", attributes.rstrip(";"))
                    )
                    feature_id = attributes_dict["ID"]
                    
                    if feature == "gene":
                        # Use this feature to sort the dictionary by position later
                        main_gff.setdefault(contig, dict()).setdefault(
                            int(start), dict()).setdefault(feature_id, list()).append(line)
                        gene_start_dict[feature_id] = int(start)
                    else:
                        protein_id = re.match(r"^(.*?t\d+)", feature_id).group(1)
                        gene_id = protein_id.rsplit('.', 1)[0]  # remove the transcript number
                        if protein_id in antifams:
                            # Don't print to the final GFF proteins that are known to not be real
                            continue
                        
                        if feature == "CDS":
                            # Add annotations to this feature
                            added_annot[protein_id] = {}
                            try:
                                eggnogs[protein_id]
                                pos = 0
                                for a in eggnogs[protein_id]:
                                    pos += 1
                                    if a != [""] and a != ["NA"]:
                                        if pos == 1:
                                            added_annot[protein_id]["eggNOG"] = a
                                        elif pos == 2:
                                            added_annot[protein_id]["cog"] = a
                                        elif pos == 3:
                                            added_annot[protein_id]["kegg"] = a
                                        elif pos == 4:
                                            added_annot[protein_id]["Ontology_term"] = a
                            except KeyError:
                                pass
                            try:
                                iprs[protein_id]
                                pos = 0
                                for a in iprs[protein_id]:
                                    pos += 1
                                    a = list(a)
                                    if a != [""] and a:
                                        if pos == 1:
                                            added_annot[protein_id]["pfam"] = sorted(a)
                                        elif pos == 2:
                                            added_annot[protein_id]["interpro"] = sorted(a)
                            except KeyError:
                                pass
                            try:
                                antismash_bgcs[protein_id]
                                for key, value in antismash_bgcs[protein_id].items():
                                    added_annot[protein_id][key] = value
                            except KeyError:
                                pass
                            try:
                                dbcan_annotations[protein_id]
                                added_annot[protein_id]["dbCAN"] = dbcan_annotations[protein_id]
                            except KeyError:
                                pass
                            
                            cols[8] = cols[8].rstrip(";")
                            for a in added_annot[protein_id]:
                                value = added_annot[protein_id][a]
                                if type(value) is list:
                                    value = ",".join(value)
                                if a == "dbCAN":
                                    cols[8] = f"{cols[8]};{value}"
                                else:
                                    if not value == "-":
                                        cols[8] = f"{cols[8]};{a}={value}"
                            line = "\t".join(cols) + ';'
                            
                        gene_start = gene_start_dict[gene_id]
                        main_gff[contig][gene_start][gene_id].append(line)

            elif line.startswith("#"):
                if line == "##FASTA":
                    fasta_flag = True
                    fasta.append(line)
                else:
                    header.append(line)
            elif fasta_flag:
                fasta.append(line)
    return header, main_gff, fasta


def get_ncrnas(ncrnas_file):
    ncrnas = {}
    counts = 0
    with open(ncrnas_file, "r") as f:
        for line in f:
            if not line.startswith("#"):
                cols = line.strip().split()
                counts += 1
                contig = cols[3]
                locus = f"{contig}_ncRNA{counts}"
                product = " ".join(cols[28:])
                model = cols[2]
                if model == "RF00005":
                    # Skip tRNAs, we add them from tRNAscan-SE
                    continue
                strand = cols[11]
                if strand == "+":
                    start = int(cols[9])
                    end = int(cols[10])
                else:
                    start = int(cols[10])
                    end = int(cols[9])
                rna_feature_name, ncrna_class = prepare_rna_gff_fields(cols)
                annot = [
                    "ID=" + locus,
                    "inference=Rfam:15.0",
                    "locus_tag=" + locus,
                    "product=" + product,
                    "rfam=" + model,
                ]
                if ncrna_class:
                    annot.append(f"ncRNA_class={ncrna_class}")
                annot = ";".join(annot)
                newline = "\t".join(
                    [
                        contig,
                        "INFERNAL:1.1.4",
                        rna_feature_name,
                        str(start),
                        str(end),
                        ".",
                        strand,
                        ".",
                        annot,
                    ]
                )
                ncrnas.setdefault(contig, dict()).setdefault(start, list()).append(
                    newline
                )
    return ncrnas


def prepare_rna_gff_fields(cols):
    rna_feature_name = "ncRNA"
    if cols[1] in ["LSU_rRNA_bacteria", "SSU_rRNA_bacteria", "5S_rRNA"]:
        rna_feature_name = "rRNA"
    # ncRNA classes are described here: https://www.insdc.org/submitting-standards/ncrna-vocabulary/
    ncrna_class = ""
    rna_types = {
        "antisense_RNA": [
            "RF00039",
            "RF00042",
            "RF00057",
            "RF00106",
            "RF00107",
            "RF00236",
            "RF00238",
            "RF00240",
            "RF00242",
            "RF00262",
            "RF00388",
            "RF00489",
            "RF01695",
            "RF01794",
            "RF01797",
            "RF01809",
            "RF01813",
            "RF02194",
            "RF02235",
            "RF02236",
            "RF02237",
            "RF02238",
            "RF02239",
            "RF02519",
            "RF02550",
            "RF02558",
            "RF02559",
            "RF02560",
            "RF02563",
            "RF02592",
            "RF02662",
            "RF02674",
            "RF02735",
            "RF02743",
            "RF02792",
            "RF02793",
            "RF02812",
            "RF02818",
            "RF02819",
            "RF02820",
            "RF02839",
            "RF02843",
            "RF02844",
            "RF02846",
            "RF02850",
            "RF02851",
            "RF02855",
            "RF02873",
            "RF02874",
            "RF02875",
            "RF02876",
            "RF02891",
            "RF02892",
            "RF02903",
            "RF02908",
        ],
        "autocatalytically_spliced_intron": ["RF01807"],
        "ribozyme": [
            "RF00621",
            "RF01787",
            "RF01788",
            "RF01865",
            "RF02678",
            "RF02679",
            "RF02681",
            "RF02682",
            "RF02684",
            "RF03154",
            "RF03160",
            "RF04188",
        ],
        "hammerhead_ribozyme": [
            "RF00008",
            "RF00163",
            "RF02275",
            "RF02276",
            "RF02277",
            "RF03152",
        ],
        "RNase_P_RNA": [
            "RF00009",
            "RF00010",
            "RF00011",
            "RF00373",
            "RF01577",
            "RF02357",
        ],
        "RNase_MRP_RNA": ["RF00030", "RF02472"],
        "telomerase_RNA": ["RF00024", "RF00025", "RF01050", "RF02462"],
        "scaRNA": [
            "RF00231",
            "RF00283",
            "RF00286",
            "RF00422",
            "RF00423",
            "RF00424",
            "RF00426",
            "RF00427",
            "RF00478",
            "RF00492",
            "RF00553",
            "RF00564",
            "RF00565",
            "RF00582",
            "RF00601",
            "RF00602",
            "RF01268",
            "RF01295",
            "RF02665",
            "RF02666",
            "RF02667",
            "RF02668",
            "RF02669",
            "RF02670",
            "RF02718",
            "RF02719",
            "RF02720",
            "RF02721",
            "RF02722",
        ],
        "snRNA": ["RF01802"],
        "SRP_RNA": [
            "RF00017",
            "RF00169",
            "RF01502",
            "RF01570",
            "RF01854",
            "RF01855",
            "RF01856",
            "RF01857",
            "RF04183",
        ],
        "vault_RNA": ["RF00006"],
        "Y_RNA": ["RF00019", "RF02553", "RF01053", "RF02565"],
    }

    if rna_feature_name == "ncRNA":
        ncrna_class = next((rna_type for rna_type, rfams in rna_types.items() if cols[2] in rfams), None)
        if not ncrna_class:
            if "microRNA" in cols[-1]:
                ncrna_class = "pre_miRNA"
            else:
                ncrna_class = "other"
    return rna_feature_name, ncrna_class


def get_trnas(trnas_file):
    trnas = {}
    with open(trnas_file, "r") as f:
        for line in f:
            if not line.startswith("#"):
                cols = line.split("\t")
                contig, feature, start = cols[0], cols[2], cols[3]
                if feature == "tRNA":
                    line = line.replace("tRNAscan-SE", "tRNAscan-SE:2.0.9")
                    trnas.setdefault(contig, dict()).setdefault(
                        int(start), list()
                    ).append(line.strip())
    return trnas


def parse_args():
    parser = argparse.ArgumentParser(
        description="Add functional annotation to GFF file for a eukaryote",
    )
    parser.add_argument(
        "-g",
        dest="gff_input",
        required=True,
        help="GFF input file",
    )
    parser.add_argument(
        "-i",
        dest="ips",
        help="InterproScan annotations results for the cluster rep",
        required=False,
    )
    parser.add_argument(
        "-e",
        dest="eggnog",
        help="eggnog annotations for the cluster repo",
        required=True,
    )
    parser.add_argument(
        "--antismash",
        help="The GFF file produced by AntiSMASH post-processing script",
        required=False,
    )
    parser.add_argument(
        "--dbcan",
        help="The GFF file produced by dbCAN post-processing script",
        required=False,
    )
    parser.add_argument("-r", dest="rfam", help="Rfam results", required=True)
    parser.add_argument(
        "-t", dest="trnascan", help="tRNAScan-SE results", required=True
    )
    parser.add_argument("-o", dest="outfile", help="Outfile name", required=True)

    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.gff_input,
        args.ips,
        args.eggnog,
        args.antismash,
        args.dbcan,
        args.rfam,
        args.trnascan,
        args.outfile,
    )
