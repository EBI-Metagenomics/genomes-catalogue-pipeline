#!/usr/bin/env python3

import argparse
from datetime import datetime
import glob
import gzip
import json
import logging
import os
import pytz
import re
import sys

from Bio import SeqIO
from Bio.Seq import Seq
import requests
import urllib.parse
import xmltodict

logging.basicConfig(level=logging.INFO)

# Define variables for stats report
SKIP_CMSCAN = SKIP_GFF = SKIP_SHORT = SKIP_TOTAL = GOOD = 0


def main(rfam_info, metadata, outfile, deoverlap_dir, gff_dir, fasta_dir):
    produced_date = get_date()
    rfam_lengths = load_rfam(rfam_info)
    check_inputs_existence(deoverlap_dir, gff_dir, fasta_dir)
    metadata_json = dict()
    sample_publication_mapping = dict()
    sample_publication_mapping["NA"] = list()  # we are missing some sample accessions in the gut catalogue
    final_dict = dict()
    final_dict.setdefault("data", list())
    with open(metadata, "r") as f:
        for line in f:
            if not line.startswith("Genome"):
                parts = line.strip().split("\t")
                mgnify_accession, species_rep, taxonomy, sample_accession, ftp = \
                    parts[0], parts[13], parts[14], parts[15], parts[19]
                if not metadata_json:
                    metadata_json, catalogue_name = generate_metadata_dict(ftp, produced_date)
                # only process species reps
                if mgnify_accession == species_rep:
                    json_data, sample_publication_mapping = generate_data_dict(mgnify_accession, sample_accession,
                                                   taxonomy, deoverlap_dir, gff_dir, fasta_dir, rfam_lengths,
                                                   sample_publication_mapping, catalogue_name)
                    if json_data:
                        final_dict["data"].extend(json_data)
    final_dict["metaData"] = metadata_json
    with open(outfile, "w") as file_out:
        json.dump(final_dict, file_out, indent=5)
    with open(outfile + ".report", "w") as file_out:
        file_out.write("Total hits reported in JSON\t{}\n".format(GOOD))
        file_out.write("Hits excluded due to short length\t{}\n".format(SKIP_SHORT))
        file_out.write("Hits excluded because contig names don't match between GFF and cmsearch output\t{}\n".format(
            SKIP_TOTAL-SKIP_SHORT))
        file_out.write("Genomes not processed because cmsearch output is missing\t{}\n".format(SKIP_CMSCAN))
        file_out.write("Genomes not processed because GFF is missing (cmsearch output exists)\t{}\n".format(SKIP_GFF))


def get_date():
    now = datetime.now()
    tz = pytz.timezone("Europe/London")
    mydt = tz.localize(now)
    if mydt.tzname() == "BST":
        timezone_add = "01:00"
    else:
        timezone_add = "00:00"
    produced_date = now.strftime("%Y-%m-%dT%H:%M:%S")
    produced_date = produced_date + "+" + timezone_add
    return produced_date


def check_inputs_existence(deoverlap_dir, gff_dir, fasta_dir):
    if not os.path.exists(deoverlap_dir):
        logging.exception("cmscan deoverlap directory doesn't exist")
        sys.exit()
    if not os.path.exists(gff_dir):
        logging.exception("GFF directory doesn't exist")
        sys.exit()
    if not os.path.exists(fasta_dir):
        logging.exception("Fasta directory doesn't exist")
        sys.exit()
    
    
def generate_metadata_dict(ftp, produced_date):
    """Generates the metadata object for the entire JSON.

    :param ftp: A link to a GFF file
    :param produced_date: The date data were produced
    :return: A dictionary containing metadata for the final JSON file
    """
    release, catalogue_name = parse_ftp(ftp)
    metadata_json = {
        "dateProduced": produced_date,
        "dataProvider": "MGNIFY",
        "release": release,
        "genomicCoordinateSystem": "1-start, fully-closed",
        "schemaVersion": "0.5.0",
        "publications": ["DOI:10.1016/j.jmb.2023.168016"]
    }
    return metadata_json, catalogue_name.replace("-", " ") + " genome catalogue"


def parse_ftp(ftp):
    """Parses catalogue version and catalogue name out of an FTP link.

    :param ftp: A link to a GFF file
    :return: Catalogue version, catalogue name
    """
    parts = ftp.strip().split("/")
    return parts[-6], parts[-7]


def generate_data_dict(mgnify_accession, sample_accession, taxonomy, deoverlap_dir,
                       gff_dir, fasta_dir, rfam_lengths, sample_publication_mapping, catalogue_name):
    global SKIP_CMSCAN, SKIP_GFF, SKIP_TOTAL, GOOD
    deoverlap_path = os.path.join(deoverlap_dir, "{}.cmscan-deoverlap.tbl".format(mgnify_accession))
    if not os.path.exists(deoverlap_path):
        logging.warning("cmscan file for accession {} doesn't exist. Skipping.".format(mgnify_accession))
        SKIP_CMSCAN += 1
        return None
    try:
        gff_path = glob.glob(os.path.join(gff_dir, mgnify_accession + ".*"))[0]
    except:
        logging.warning("GFF file for accession {} doesn't exist. Skipping.".format(mgnify_accession))
        SKIP_GFF += 1
        return None
    hits_to_report = get_good_hits(deoverlap_path, rfam_lengths)

    dict_list = list()

    if len(hits_to_report.keys()) > 0:
        fasta_file = glob.glob(os.path.join(fasta_dir, mgnify_accession + ".*"))[0]
        seq_records = SeqIO.to_dict(SeqIO.parse(fasta_file, "fasta"))
        read_function = gzip.open if gff_path.endswith('.gz') else open
        with read_function(gff_path, "rt") as f:
            for line in f:
                if line.startswith(">"):
                    break
                elif line.startswith("#"):
                    pass
                else:
                    if "INFERNAL" in line:
                        fields = line.strip().split("\t")
                        contig, start, end, strand, annotation = fields[0], int(fields[3]), int(fields[4]), fields[6], \
                                                                 fields[8]
                        if contig in hits_to_report and [start, end] in hits_to_report[contig]:
                            GOOD += 1
                            data_dict = dict()
                            data_dict["primaryId"] = get_primary_id(annotation)
                            data_dict["inferredPhylogeny"] = "GTDB:{}".format(taxonomy)
                            data_dict["sequence"] = get_sequence(seq_records, contig, start, end, strand)
                            data_dict["name"] = get_seq_name(annotation)
                            data_dict["version"] = "1"
                            data_dict["sourceModel"] = get_rfam_accession(annotation)
                            data_dict["genomeLocations"] = make_genome_locations(contig, start, end, strand,
                                                                                 mgnify_accession)
                            data_dict["url"] = \
                                "https://www.ebi.ac.uk/metagenomics/genomes/{}?contig_id={}&start={}&end={}&functional-annotation=ncrna#genome-browser".\
                                format(mgnify_accession, contig, start, end)
                            if sample_accession in sample_publication_mapping:
                                data_dict["publications"] = sample_publication_mapping[sample_accession]
                            else:
                                data_dict["publications"] = get_publications(sample_accession)
                                sample_publication_mapping[sample_accession] = data_dict["publications"]
                            data_dict["additionalAnnotations"] = {"catalog_name": catalogue_name}
                            dict_list.append(data_dict)
                        else:
                            logging.info("Hit {} start {} end {} exists in the GFF file but is not added to the "
                                         "JSON because it did not make the high quality list or the contig name "
                                         "doesn't match between the GFF and the deoverlapped file.".
                                         format(contig, start, end))
                            SKIP_TOTAL += 1
                            print(line)
    else:
        SKIP_TOTAL += 1
    # Print a warning if there are no hits in GFF but there are hits in hits_to_report
    return dict_list, sample_publication_mapping


def get_seq_name(annotation):
    """Return the name of the matched sequence.

    :param annotation: annotation from one line in the GFF line
    :return: name of ncRNA
    """
    parts = annotation.strip().split(";")
    for p in parts:
        if p.startswith("product="):
            return p.split("=")[1]
    return ""


def make_genome_locations(contig, start, end, strand, mgnify_accession):
    loc_dict = [{
        "assembly": mgnify_accession,
        "exons": [{
            "chromosome": contig,
            "startPosition": start,
            "endPosition": end,
            "strand": strand
        }]
    }]
    return loc_dict


def get_publications(genome_sample_accession):
    """Get a list of PMIDs associated with the raw data from which the genome was generated.

    :param genome_sample_accession: sample from the metadata table.
    :return: list of PMIDs
    """
    publications = list()
    biosamples = None
    # Check if there are read files associated with the sample (meaning sample accession points to raw data already)
    raw_data_sample = check_sample_level(genome_sample_accession)
    #if raw_data_sample:
    #    biosamples = list()
    #    biosamples.append(genome_sample_accession)
    #else:
    xml_data = load_xml(genome_sample_accession)
    sample_attributes = xml_data["SAMPLE_SET"]["SAMPLE"]["SAMPLE_ATTRIBUTES"]["SAMPLE_ATTRIBUTE"]
    for attribute in sample_attributes:
        if all([x in attribute["TAG"] for x in ["derived", "from"]]):
            biosamples = re.findall("SAMN\d+|ERS\d+", attribute["VALUE"])
            print(biosamples)
            for biosample in biosamples:
                if biosample.startswith("ERS"):
                    biosample = convert_bin_sample(biosample)
                project_accessions = get_project_accession(biosample)
                print(project_accessions)
                if project_accessions:
                    publications_to_add = list()
                    for project in project_accessions:
                        extracted_publications = get_publications_from_xml(project)
                        if extracted_publications:
                            publications_to_add.extend(list(extracted_publications))
                    publications.extend(list(publications_to_add))
                else:
                    logging.error("Could not obtain project accessions for sample {}".
                                  format(genome_sample_accession))
            break
    if not biosamples:
        logging.error("Biosample couldn't be obtained for sample {}".format(genome_sample_accession))
    return list(filter(None, list(set(publications))))


def check_sample_level(genome_sample_accession):
    api_endpoint = "https://www.ebi.ac.uk/ena/portal/api/filereport"
    query = {
        'accession': '{}'.format(genome_sample_accession),
        'result': 'read_run',
        'fields': 'run_accession',
        'format': 'tsv'
    }
    r = run_request(query, api_endpoint)
    for line in r.text.splitlines():
        if line.startswith(("ERR", "DRR", "SRR")):
            return True
    return False


def run_request(query, api_endpoint):
    r = requests.get(api_endpoint, params=urllib.parse.urlencode(query))
    r.raise_for_status()
    return r


def convert_bin_sample(biosample):
    xml_data = load_xml(biosample)
    try:
        biosample = xml_data["SAMPLE_SET"]["SAMPLE"]["IDENTIFIERS"]["EXTERNAL_ID"]["#text"] \
            if xml_data["SAMPLE_SET"]["SAMPLE"]["IDENTIFIERS"]["EXTERNAL_ID"]["@namespace"] == "BioSample" \
            else biosample
    except:
        logging.error("Could not convert sample {}".format(biosample))
    return biosample


def get_publications_from_xml(project):
    extracted_publications = list()
    xml_data = load_xml(project)
    study_links = xml_data["STUDY_SET"]["STUDY"]["STUDY_LINKS"]
    for study_link in study_links.keys():
        for element in study_links[study_link]:
            if "XREF_LINK" in element and "DB" in element["XREF_LINK"]:
                if element["XREF_LINK"]["DB"].lower() == "pubmed":
                    pub = "PMID:{}".format(element["XREF_LINK"]["ID"])
                    extracted_publications.append(pub)
    return set(extracted_publications)


def get_project_accession(biosample):
    api_endpoint = "https://www.ebi.ac.uk/ena/portal/api/filereport"
    full_url = "{}?accession={}&result=read_run&fields=secondary_study_accession".format(api_endpoint, biosample)
    print(full_url)
    r = requests.get(url=full_url)
    if r.ok:
        projects = list()
        elements = r.text.split("\n")
        for e in elements:
            if not e.startswith("run_accession") and not e == "":
                projects.append(e.strip().split("\t")[1])
        return set(projects)
    else:
        logging.error("Error when requesting study accession for biosample {}".format(biosample))
        logging.error(r.text)
        return None


def load_xml(sample_id):
    xml_url = 'https://www.ebi.ac.uk/ena/browser/api/xml/{}'.format(sample_id)
    r = requests.get(xml_url)
    if r.ok:
        data_dict = xmltodict.parse(r.content)
        json_dump = json.dumps(data_dict)
        json_data = json.loads(json_dump)
        return json_data
    else:
        logging.error('Could not retrieve xml for sample {}'.format(sample_id))
        logging.error(r.text)
        return None


def get_sequence(seq_records, contig, start, end, strand):
    """Gets feature sequence from a Fasta file.

    :param seq_records: A dictionary containing a Fasta file for a genome
    :param contig: Contig ID
    :param start: Start position from the GFF (1-based)
    :param end: End position from the GFF
    :param strand: Strand from the GFF
    :return: DNA sequence (reverse complement if the sequence is on the minus strand)
    """
    seq = seq_records[contig][start-1:end].seq
    if strand == "-":
        seq = Seq(seq).reverse_complement()
    return str(seq)


def get_rfam_accession(annotation):
    """Returns Rfam accession from the GFF annotation field.

    :param annotation: Contents of the annotation fields for one feature in a GFF.
    :return: Rfam accession
    """
    parts = annotation.strip().split(";")
    for part in parts:
        if part.startswith("rfam"):
            return part.split("=")[1]


def get_primary_id(annotation):
    """Returns the ID assigned to the feature.

    :param annotation: Contents of the annotation fields for one feature in a GFF.
    :return: The contents of the ID portion of the annotation.
    """
    return "MGNIFY:{}".format(annotation.strip().split(";")[0].split("=")[1])


def get_good_hits(file, rfam_lengths):
    """Parses the cmsscan deoverlapped file for 1 genome and saves hits that cover at least 80%
    of the model.

    :param file: cmscan deoverlapped table file
    :param rfam_lengths: dictionary where key = Rfam model accession, value = length
    :return: dictionary where key = contig, value = list of start/end pairs that correspond to good hits
    """
    global SKIP_SHORT
    hits_to_report = dict()
    with open(file, 'r') as f:
        for line in f:
             if not line.startswith("#"):
                parts = line.strip().split()
                model_start, model_end = int(parts[7]), int(parts[8])
                model_acc, contig, contig_start, contig_end = parts[2], parts[3], int(parts[9]), int(parts[10])
                if model_end > model_start:
                    perc_covered = abs(model_end - model_start) * 100/rfam_lengths[model_acc]
                else:
                    sys.exit("Model end smaller than model start")
                if perc_covered >= 80.0:
                    hits_to_report.setdefault(contig, list()).append(sorted([contig_start, contig_end]))
                else:
                    SKIP_SHORT += 1
    return hits_to_report


def load_rfam(rfam_info):
    """Loads lengths of Rfam models.

    :param rfam_info: file containing lengths of Rfam models
    :return: a dictionary where key = Rfam accession, value = model length
    """
    rfam_lengths = dict()
    with open(rfam_info, "r") as f:
        for line in f:
            acc, len = line.strip().split("\t")
            rfam_lengths[acc] = int(len)
    return rfam_lengths


def parse_args():
    parser = argparse.ArgumentParser(description="Script produces JSON file to import RNA sequences from genome"
                                                 "catalogues into RNAcentral. The script relies on the metadata"
                                                 "table, GFF files and deoverlap.tbl files for species representatives")
    parser.add_argument('-r', '--rfam-info', required=True,
                        help='Path to the file that contains Rfam model lengths. The file should have no header,'
                             'the first column is Rfam accession, second column is length')
    parser.add_argument('-m', '--metadata', required=True,
                        help='Path to the file containing catalogue metadata.')
    parser.add_argument('-o', '--outfile', required=True,
                        help='Path to output file.')
    parser.add_argument('-d', '--deoverlap-dir', required=True,
                        help='Path to the directory containing deoverlapped cmscan files.')
    parser.add_argument('-g', '--gff-dir', required=True,
                        help='Path to the directory containing GFF files.')
    parser.add_argument('-f', '--fasta-dir', required=True,
                        help='Path to the directory containing genomes fasta files.')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.rfam_info, args.metadata, args.outfile, args.deoverlap_dir, args.gff_dir, args.fasta_dir)
