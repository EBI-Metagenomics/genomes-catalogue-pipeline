import importlib
import json
import unittest
import os

from pathlib import Path

script_dir = Path(__file__).resolve().parent
rnacentral_dir = script_dir / '../../helpers/database_import_scripts/rnacentral'
rnacentral_dir = rnacentral_dir.resolve()

generate_json = importlib.import_module("helpers.database_import_scripts.rnacentral.generate_rnacentral_json")
generate_metadata_dict = generate_json.generate_metadata_dict
get_good_hits = generate_json.get_good_hits
load_rfam = generate_json.load_rfam
pass_seq_check = generate_json.pass_seq_check
get_publications_from_xml = generate_json.get_publications_from_xml
check_sample_level = generate_json.check_sample_level
convert_bin_sample = generate_json.convert_bin_sample
generate_data_dict = generate_json.generate_data_dict


class TestRNAcentralScript(unittest.TestCase):
    def setUp(self):
        self.ftp = "https://ftp.ebi.ac.uk/pub/databases/metagenomics/mgnify_genomes/human-oral/v1.0.1/species_catalogue/MGYG0002980/MGYG000298013/genome/MGYG000298013.gff"
        self.rfam_length_file = os.path.join(rnacentral_dir, "rfam_model_lengths_14.9.txt")
        self.rfam_lengths = load_rfam(self.rfam_length_file)
        self.deoverlapped_file = os.path.join(script_dir, "fixtures", "generate_rnacentral_json", 
                                              "MGYG000306392.ncrna.deoverlap.tbl")
    
    def test_generate_metadata_dict(self):
        result = generate_metadata_dict(self.ftp, "2023-07-11T11:30:35+01:00")
        expected_result = ({
            "dateProduced": "2023-07-11T11:30:35+01:00",
            "dataProvider": "MGNIFY",
            "release": "v1.0.1",
            "genomicCoordinateSystem": "1-start, fully-closed",
            "schemaVersion": "0.5.0",
            "publications": [
                "DOI:10.1016/j.jmb.2023.168016"
                ]
            }, "human oral genome catalogue")
        self.assertEqual(result, expected_result)        
        
    def test_load_rfam(self):
        self.assertEqual(len(self.rfam_lengths), 4108)
    
    def test_get_good_hits(self):
        good_hits = get_good_hits(self.deoverlapped_file, self.rfam_lengths)
        expected_good_hits = {'MGYG000306392_2': [[18716, 19044]], 
                              'MGYG000306392_4': [[23650, 23728]], 
                              'MGYG000306392_10': [[19338, 19397], [19464, 19532]]}
        self.assertEqual(good_hits, expected_good_hits)
    
    def test_pass_seq_check(self):
        good_seq = "TTTCAGNTTACGCGC"
        bad_seq = "NNNNTTA"
        self.assertEqual(pass_seq_check(good_seq), True)
        self.assertEqual(pass_seq_check(bad_seq), False)
    
    def test_get_publications_from_xml(self):
        expected_publications = {"PMID:37897342"}
        publications = get_publications_from_xml("ERP151511")
        self.assertEqual(publications, expected_publications)
        
    def test_check_sample_level(self):
        sample_mag_level = "SAMEA110586774"
        sample_read_level = "SAMN14884640"
        self.assertEqual(check_sample_level(sample_mag_level), False)
        self.assertEqual(check_sample_level(sample_read_level), True)
    
    def test_convert_bin_sample(self):
        sample = convert_bin_sample("ERS21055784")
        self.assertEqual(sample, "SAMEA116057743")
        
    def test_generate_data_dict(self):
        dict_list_result, sample_publication_mapping_result = generate_data_dict(
            mgnify_accession="MGYG000306392", 
            sample_accession="SAMEA110746264", 
            taxonomy="d__Bacteria;p__Bacillota_I;c__Bacilli_A;o__RF39;f__UBA660;g__Scybalousia;s__Scybalousia sp946639185", 
            deoverlap_dir=os.path.join(script_dir, "fixtures", "generate_rnacentral_json"),
            gff_dir=os.path.join(script_dir, "fixtures", "generate_rnacentral_json", "GFF"),
            fasta_dir=os.path.join(script_dir, "fixtures", "generate_rnacentral_json", "FASTA"),
            rfam_lengths=self.rfam_lengths, 
            sample_publication_mapping=dict(),
            catalogue_name="sheep rumen catalogue", 
            reported_project="PRJEB22623",
            insdc_accession="CAMPBR01")
        
        with open(os.path.join(script_dir, "fixtures", "generate_rnacentral_json", "expected_output.json"), "r") as f:
            expected_json = json.load(f)
        self.assertEqual(dict_list_result, expected_json)

    