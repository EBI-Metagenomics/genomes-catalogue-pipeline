#!/bin/env python3

import hashlib
import os
from pathlib import Path

from bin.process_crispr_results import main as process_main


class TestProcessCRISPRResults:
    def _get_checksum(self, filename):
        with open(filename, "r") as file_handle:
            file_content = "\n".join(sorted(file_handle.readlines()))
            return hashlib.md5(file_content.encode(encoding="UTF-8")).hexdigest()

    def _base_path(self):
        return Path(
            os.path.abspath(
                "/" + os.path.dirname(__file__) + "/fixtures/crispcas_finder"
            )
        )

    def test_gff_generation(self, tmp_path):
        """Assert that the .gff generation works as expected."""
        tsv_report = self._base_path() / "crisprs_report.tsv"
        fasta = self._base_path() / "MGYG000299389.fna"
        gff_files = self._base_path() / "gff"

        process_main(
            tsv_report,
            list(map(str, gff_files.glob("*.gff"))),
            tmp_path / "output.tsv",
            tmp_path / "output.gff",
            tmp_path / "output.hq.gff",
            fasta,
        )

        result_tsv = tmp_path / "output.tsv"
        result_gff = tmp_path / "output.gff"
        result_hq_gff = tmp_path / "output.hq.gff"

        expected_tsv = self._base_path() / "expected/MGYG000299389.tsv"
        expected_gff = self._base_path() / "expected/MGYG000299389.gff"
        expected_hq_gff = self._base_path() / "expected/MGYG000299389.hq.gff"

        assert self._get_checksum(result_tsv) == self._get_checksum(expected_tsv)
        assert self._get_checksum(result_gff) == self._get_checksum(expected_gff)
        assert self._get_checksum(result_hq_gff) == self._get_checksum(expected_hq_gff)
