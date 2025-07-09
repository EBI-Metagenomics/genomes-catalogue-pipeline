import unittest
from pathlib import Path

from helpers.database_import_scripts.uniprot.preprocess_taxonomy_for_uniprot import (
    get_species_level_taxonomy,
    match_taxid_to_gca,
    parse_metadata,
)


class TestPreprocessTaxonomyForUniprot(unittest.TestCase):
    def setUp(self):
        self.metadata_file = (
            Path(__file__).resolve().parent
            / "fixtures/preprocess_taxonomy_for_uniprot/sample_metadata.tsv"
        )
        self.gca_accessions, self.sample_accessions = parse_metadata(self.metadata_file)
        self.mgyg_to_gca, self.gca_to_taxid = match_taxid_to_gca(
            self.gca_accessions, self.sample_accessions, 2
        )

    def test_match_taxid_to_gca(self):
        expected_gca_to_taxid = {
            "GCA_946182765": "370804",
            "GCA_946182785": "244328",
            "GCA_946182825": "297314",
            "GCA_946182815": "370804",
            "GCA_946182805": "190764",
            "GCA_946182835": "370804",
            "GCA_946183145": "1678694",
            "GCA_946183335": "157472",
        }
        expected_mgyg_to_gca = {
            "MGYG000304400": "GCA_946182765",
            "MGYG000304401": "GCA_946182785",
            "MGYG000304403": "GCA_946182825",
            "MGYG000304404": "GCA_946182815",
            "MGYG000304405": "GCA_946182805",
            "MGYG000304406": "GCA_946182835",
            "MGYG000304407": "GCA_946183145",
            "MGYG000304408": "GCA_946183335",
        }
        self.assertEqual(self.mgyg_to_gca, expected_mgyg_to_gca)
        self.assertEqual(self.gca_to_taxid, expected_gca_to_taxid)

    def test_get_species_level_taxonomy(self):
        _, name1, submittable1, lineage1 = get_species_level_taxonomy(
            "k__Bacteria;p__Bacillota_I;c__Bacilli_A;o__RFN20;f__CAG-826;g__UBA3207;s__UBA3207 sp946183335"
        )
        self.assertEqual(
            lineage1,
            "sk__Bacteria;p__Bacillota_I;c__Bacilli_A;o__RFN20;f__CAG-826;g__UBA3207;s__UBA3207 sp946183335",
        )
        self.assertEqual(submittable1, False)
        self.assertEqual(name1, "UBA3207 sp946183335")

        taxid2, _, submittable2, _ = get_species_level_taxonomy(
            "d__Bacteria; p__Pseudomonadota; c__Gammaproteobacteria; o__Enterobacterales; f__Enterobacteriaceae; g__Escherichia; s__Escherichia coli"
        )
        self.assertEqual(submittable2, True)
        self.assertEqual(taxid2, "562")
