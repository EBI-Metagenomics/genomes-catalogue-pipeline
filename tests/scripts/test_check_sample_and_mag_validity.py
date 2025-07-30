import filecmp
import importlib
import unittest
import os

from pathlib import Path

from bin.check_sample_and_mag_validity import main as check_validity_main

script_dir = Path(__file__).resolve().parent


class TestMAGValidityScript(unittest.TestCase):
    def setUp(self):
        self.test_data_dir = os.path.join(script_dir, "fixtures", "check_sample_and_mag_validity")
        self.removal_file = os.path.join(self.test_data_dir, "remove_list.txt")
        self.removal_file_mgyg = os.path.join(self.test_data_dir, "remove_list_mgyg.txt")
        self.outfile1 = os.path.join(self.test_data_dir, "output1.txt")
        self.outfile2 = os.path.join(self.test_data_dir, "output2.txt")
        self.outfile3 = os.path.join(self.test_data_dir, "output3.txt")
        self.expected_file_no_remove_list = os.path.join(self.test_data_dir, "expected_result_no_remove_list.txt")
    
    def test_empty_remove_list(self):
        check_validity_main(self.test_data_dir, None, self.outfile1, 16)
        self.assertTrue(
            filecmp.cmp(self.outfile1, self.expected_file_no_remove_list, shallow=False),
            "The output file does not match the expected results"
        )
        
    def test_with_remove_list(self):
        check_validity_main(self.test_data_dir, self.removal_file, self.outfile2, 16)
        self.assertFalse(os.path.exists(self.outfile2))
    
    def test_remove_mgyg(self):
        check_validity_main(self.test_data_dir, self.removal_file_mgyg, self.outfile3, 16)
        self.assertFalse(os.path.exists(self.outfile3))
        
        