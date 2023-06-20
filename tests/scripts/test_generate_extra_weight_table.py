#!/bin/env python3

from bin.generate_extra_weight_table import main as generate_extra_weight_table_main

from .base_classes import BaseTestWithFiles


class TestGenerateExtraWeightTable(BaseTestWithFiles):
    def test_table_generation(self, tmp_path):
        """Assert that the generation works"""

        generate_extra_weight_table_main(
            None,
            None,  # emtpy genome and study_genomes info
            tmp_path / "output_table.tsv",
            self._base_path() / "generate_extra_weight_table/genomes_folder",
            None,  # no rename mapping
        )

        assert self._get_checksum(tmp_path / "output_table.tsv") == self._get_checksum(
            self._base_path() / "generate_extra_weight_table/expected/output_table.tsv"
        )

    def test_table_generation_with_rename(self, tmp_path):
        """Assert that the generation works when provided a genome_info"""

        generate_extra_weight_table_main(
            self._base_path() / "generate_extra_weight_table/genome_info.tsv",
            None,  # emtpy genome and study_genomes info
            tmp_path / "output_table.tsv",
            self._base_path() / "generate_extra_weight_table/genomes_folder",
            None,  # no rename mapping
        )

        print(tmp_path / "output_table.tsv")

        assert self._get_checksum(tmp_path / "output_table.tsv") == self._get_checksum(
            self._base_path()
            / "generate_extra_weight_table/expected/output_table_w_genome_info.tsv"
        )
