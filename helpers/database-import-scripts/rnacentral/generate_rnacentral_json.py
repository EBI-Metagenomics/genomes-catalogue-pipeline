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
from retry import retry
import urllib.parse
import xmltodict

logging.basicConfig(level=logging.WARNING)

# Define variables for stats report
SKIP_CMSCAN = SKIP_GFF = GOOD = BAD_SEQUENCE = 0
skip_short = list()
skip_total = list()


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
                mgnify_accession, insdc_accession, species_rep, taxonomy, sample_accession, reported_project, ftp = \
                    parts[0], parts[12], parts[13], parts[14], parts[15], parts[16], parts[19]
                # metadata json is only produced once for the entire catalogue
                if not metadata_json:
                    metadata_json, catalogue_name = generate_metadata_dict(ftp, produced_date)
                # only process species reps
                if mgnify_accession == species_rep:
                    json_data, sample_publication_mapping = generate_data_dict(
                        mgnify_accession, sample_accession, taxonomy, deoverlap_dir, gff_dir, fasta_dir, rfam_lengths,
                        sample_publication_mapping, catalogue_name, reported_project, insdc_accession)
                    if json_data:
                        final_dict["data"].extend(json_data)
    final_dict["metaData"] = metadata_json
    with open(outfile, "w") as file_out:
        json.dump(final_dict, file_out, indent=5)
    skip_other = set(skip_total) - set(skip_short)
    with open(outfile + ".report", "w") as file_out:
        file_out.write("Total hits reported in JSON\t{}\n".format(GOOD))
        file_out.write("Hits excluded due to short length\t{}\n".format(len(skip_short)))
        file_out.write("Hits excluded because contig names don't match between GFF and cmsearch output\t{}\n".format(
            len(skip_other)))
        file_out.write("Hits excluded due to too many N's in sequence\t{}\n".format(
            BAD_SEQUENCE))
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
                       gff_dir, fasta_dir, rfam_lengths, sample_publication_mapping, catalogue_name,
                       reported_project, insdc_accession):
    global SKIP_CMSCAN, SKIP_GFF, GOOD, BAD_SEQUENCE
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
                            if not pass_seq_check(data_dict["sequence"]):
                                BAD_SEQUENCE += 1
                                continue
                            data_dict["name"] = get_seq_name(annotation)
                            data_dict["version"] = "1"
                            data_dict["sourceModel"] = "RFAM:{}".format(get_rfam_accession(annotation))
                            data_dict["genomeLocations"] = make_genome_locations(contig, start, end, strand,
                                                                                 mgnify_accession)
                            data_dict["url"] = \
                                "https://www.ebi.ac.uk/metagenomics/genomes/{}?contig_id={}&start={}&end={}&functional-annotation=ncrna#genome-browser".\
                                format(mgnify_accession, contig, start, end)
                            if sample_accession in sample_publication_mapping:
                                data_dict["publications"] = sample_publication_mapping[sample_accession]
                            else:
                                data_dict["publications"] = get_publications(sample_accession, reported_project, 
                                                                             insdc_accession)
                                sample_publication_mapping[sample_accession] = data_dict["publications"]
                            data_dict["additionalAnnotations"] = {"catalog_name": catalogue_name}
                            dict_list.append(data_dict)
                        else:
                            logging.info("Hit {} start {} end {} exists in the GFF file but is not added to the "
                                         "JSON because it did not make the high quality list or the contig name "
                                         "doesn't match between the GFF and the deoverlapped file.".
                                         format(contig, start, end))
                            skip_total.append("{}_{}_{}".format(contig, start, end))
    else:
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
                        skip_total.append("{}_{}_{}".format(contig, start, end))
    # TO DO: Print a warning if there are no hits in GFF but there are hits in hits_to_report
    return dict_list, sample_publication_mapping


def pass_seq_check(seq):
    count_n = seq.lower().count('n')
    total_length = len(seq)
    if count_n / total_length < 0.1:
        return True
    else:
        return False
    
    
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


def get_publications(genome_sample_accession, reported_project, insdc_accession):
    """Get a list of PMIDs associated with the raw data from which the genome was generated.

    :param genome_sample_accession: sample from the metadata table.
    :param reported_project: project accession for this sample from the metadata table.
    :param insdc_accession: INSDC accession of the genome.
    :return: list of PMIDs
    """
    publications = list()
    biosamples = list()
    ena_format_issue = False

    samples_to_check = [genome_sample_accession]
    # Check if there are read files associated with the sample (meaning sample accession points to raw data already)
    # If that's the case, there is no need to convert the sample accession to the raw data one
    raw_data_sample = check_sample_level(genome_sample_accession)
    if raw_data_sample:
        biosamples = samples_to_check
    else:
        # keep going through levels of samples until we get to the raw read samples
        while samples_to_check:
            samples_for_next_iteration = list()
            for sample_to_check in samples_to_check:
                xml_data = load_xml(sample_to_check, insdc_accession)
                try:
                    if xml_data:
                        sample_attributes = xml_data["SAMPLE_SET"]["SAMPLE"]["SAMPLE_ATTRIBUTES"]["SAMPLE_ATTRIBUTE"]
                    else:
                        # there is no XML for this sample, we can't get samples it is derived from
                        sample_attributes = list()
                except:
                    # There is XML but it's format is wrong and we can't parse it
                    logging.exception("Unable to process XML for sample {}".format(sample_to_check))
                    sys.exit()
                sample_is_derived = False
                for attribute in sample_attributes:
                    if all([x in attribute["TAG"] for x in ["derived", "from"]]):
                        derived_from_list = re.findall("SAM[A-Z]+\d+|ERS\d+|SRS\d+|DRS\d+", attribute["VALUE"])
                        if len(derived_from_list) == 0:
                            logging.warning("Found an issue with derived samples format for sample {}. "
                                            "Attempting to resolve.".format(genome_sample_accession))
                            derived_from_list = identify_derived_sample_issue(attribute["VALUE"])
                            if len(derived_from_list) == 0:
                                ena_format_issue = True
                            else:
                                logging.warning("Resolved the format issue for sample {} successfully.".format(
                                    genome_sample_accession))
                                sample_to_check = derived_from_list
                        samples_for_next_iteration = samples_for_next_iteration + derived_from_list
                        sample_is_derived = True
                        break
                if not sample_is_derived:  # we found the raw read sample
                    biosamples.append(sample_to_check)
            samples_to_check = samples_for_next_iteration
    # now we are working with raw read samples
    for biosample in biosamples:
        if biosample.startswith("ERS"): 
            biosample = convert_bin_sample(biosample)  # convert to biosample
        project_accessions = get_project_accession(biosample)  # find what project the sample is from
        if not project_accessions and raw_data_sample:
            project_accessions = {reported_project}
        if project_accessions:
            publications_to_add = list()
            for project in project_accessions:
                extracted_publications = get_publications_from_xml(project)
                if extracted_publications:
                    publications_to_add.extend(list(extracted_publications))
            publications.extend(list(publications_to_add))
        else:
            logging.warning("Could not obtain project accessions for sample {}".
                          format(genome_sample_accession))
    if not biosamples:
        if ena_format_issue is True:
            logging.warning("Unable to obtain citation information for sample {} due to format errors in ENA. "
                            "No citations will be reported to RNAcentral for this sample.".format(
                genome_sample_accession))
        else:
            logging.error("Biosample couldn't be obtained for sample {}".format(genome_sample_accession))
            if insdc_accession.startswith("CA"):
                logging.error("Biosample could not be obtained for an ENA genome {}".
                              format(insdc_accession))
                sys.exit("ERROR: cannot proceed because at least one ENA sample is not found in ENA.")
    return list(filter(None, list(set(publications))))


def identify_derived_sample_issue(ena_data):
    derived_from_list = list()
    # check if runs were reported instead of sampples
    runs = re.findall("ERR\d+|SRR\d+|DRR\d+", ena_data)
    if len(runs) > 0:
        for run in runs:
            xml_data = load_xml(run)
            try:
                run_links = xml_data["RUN_SET"]["RUN"]["RUN_LINKS"]["RUN_LINK"]
                for entry in run_links:
                    # Check if 'DB' is 'ENA-SAMPLE' inside the inner dictionary
                    if entry.get('XREF_LINK', {}).get('DB') == 'ENA-SAMPLE':
                        # If present, print the 'ID' value
                        sample_acc = entry.get('XREF_LINK', {}).get('ID')
                        if not sample_acc.startswith("SAM"):
                            sample_acc = convert_bin_sample(sample_acc)
                            derived_from_list.append(sample_acc)
            except:
                logging.warning("Unable to obtain sample accession for  run {} from ENA".format(run))
    return derived_from_list
    
    
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


@retry(tries=5, delay=10, backoff=1.5)
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
    counter = 1
    study_links = None
    while counter < 5:
        try:
            xml_data = load_xml(project)
            study_links = xml_data["STUDY_SET"]["STUDY"]["STUDY_LINKS"]
            break
        except:
            counter += 1
            logging.info("XML data retrieval failed for project {}. Retrying. Attempt {}.".
                         format(project, counter))
    if not study_links:
        logging.error("Failed to get XML for project {}".format(project))
        sys.exit()
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
    r = requests.get(url=full_url)
    if r.ok:
        projects = list()
        elements = r.text.split("\n")
        header = elements[0]
        col_names = header.strip().split("\t")
        study_index = col_names.index("secondary_study_accession")
        for e in elements[1:]:
            if not e == "":
                project_to_add = e.strip().split("\t")[study_index]
                assert any(project_to_add.startswith(prefix) for prefix in
                           ["SRP", "ERP", "DRP", "PR"]), "Incorrect project format: {}".format(project_to_add)
                projects.append(project_to_add)
        return set(projects)
    else:
        logging.error("Error when requesting study accession for biosample {}".format(biosample))
        logging.error(r.text)
        sys.exit()
        # return None


def load_xml(sample_id, insdc_accession=None):
    xml_url = 'https://www.ebi.ac.uk/ena/browser/api/xml/{}'.format(sample_id)
    try:
        r = run_xml_request(xml_url)
    except:
        if insdc_accession.startswith("C"):
            logging.error("Unable to get XML for sample {}, ENA genome {}".format(sample_id, insdc_accession))
            sys.exit()
        else:
            logging.warning("Unable to get XML for accession {}. Skipping.".format(sample_id))
            return None
    if r.ok:
        try:
            data_dict = xmltodict.parse(r.content)
            json_dump = json.dumps(data_dict)
            json_data = json.loads(json_dump)
            return json_data
        except:
            logging.exception("Unable to load json from API for accession {}".format(sample_id))
            print(r.text)
    else:
        logging.error('Could not retrieve xml for accession {}'.format(sample_id))
        logging.error(r.text)
        return None


@retry(tries=5, delay=10, backoff=1.5)
def run_xml_request(xml_url):
    r = requests.get(xml_url)
    r.raise_for_status()
    return r


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
    return str(seq).upper()


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
                    pos = sorted([contig_start, contig_end])
                    skip_short.append("{}_{}_{}".format(contig, pos[0], pos[1]))
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
