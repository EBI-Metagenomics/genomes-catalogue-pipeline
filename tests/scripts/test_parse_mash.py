import unittest
from unittest.mock import patch, mock_open
import os

from bin.parse_mash import remove_extension, load_list, load_metadata_table, evaluate, copy_file_list


class TestGenomePipeline(unittest.TestCase):

    def test_remove_extension(self):
        self.assertEqual(remove_extension("genome.fa"), "genome")
        self.assertEqual(remove_extension("genome.fna"), "genome")
        self.assertEqual(remove_extension("genome.fasta"), "genome")
        self.assertEqual(remove_extension("genome.txt"), "genome.txt")  # unchanged

    def test_evaluate(self):
        genomes = {"g1", "g2", "g3", "g4"}
        scores = {
            "g1": ("hit1", 0.0005),
            "g2": ("hit2", 0.002),
            "g3": ("hit3", 0.06)
        }
        same_strains, new_strains, new_species = evaluate(genomes, scores)
        self.assertEqual(same_strains, {"g1"})
        self.assertEqual(new_strains, {"g2"})
        self.assertEqual(new_species, {"g3", "g4"})

    @patch("builtins.open", new_callable=mock_open, read_data="Genome\tSpecies_rep\nacc1\trep1\nacc2\trep2\n")
    def test_load_metadata_table(self, mock_file):
        rep_to_member, member_to_rep = load_metadata_table("dummy_metadata.tsv")
        self.assertEqual(rep_to_member, {"rep1": ["acc1"], "rep2": ["acc2"]})
        self.assertEqual(member_to_rep, {"acc1": "rep1", "acc2": "rep2"})

    @patch("builtins.open", new_callable=mock_open, read_data="genome1.fa\ngenome2.fna\n")
    def test_load_list_with_remove_ext(self, mock_file):
        filename_dict = {}
        genomes = load_list("dummy_file.txt", remove_ext=True, filename_dict=filename_dict)
        self.assertEqual(genomes, {"genome1", "genome2"})
        self.assertEqual(filename_dict, {"genome1": "genome1.fa", "genome2": "genome2.fna"})

    @patch("bin.parse_mash.copy2")
    def test_copy_file_list(self, mock_copy):
        infolder = "/input"
        outfolder = "/output"
        filename_dict = {"g1": "g1.fa", "g2": "g2.fna"}
        copy_file_list(["g1", "g2"], infolder, outfolder, filename_dict)
        expected_calls = [
            ((os.path.join(infolder, "g1.fa"), os.path.join(outfolder, "g1.fa")),),
            ((os.path.join(infolder, "g2.fna"), os.path.join(outfolder, "g2.fna")),)
        ]
        mock_copy.assert_has_calls(expected_calls, any_order=True)


if __name__ == "__main__":
    unittest.main()
