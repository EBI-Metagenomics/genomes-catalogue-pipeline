#!/bin/env python3

import shutil
from bin.filter_qs50 import main as filter_qs50_main
from .base_classes import BaseTestWithFiles


class TestFilterQS50(BaseTestWithFiles):
    def _fixture_path(self):
        return self._base_path() / "filter_qs50"

    def _details(self, details_csv):
        lines = details_csv.read_text().splitlines()
        return {line.split(",")[0]: line.split(",")[3] for line in lines}

    def test_filtering_and_failure_reasons(self, tmp_path):
        """Genomes without quality values or below QS50 are filtered out, and every removal is traced"""
        genomes = self._fixture_path() / "genomes"

        filter_qs50_main(
            str(genomes),
            str(self._fixture_path() / "quality.csv"),
            str(tmp_path / "failed.txt"),
            str(tmp_path / "passed.csv"),
            str(tmp_path / "details.csv"),
            False,  # don't delete from the input folder
            False,  # don't write the filtered folder (it would be created in the current working directory)
        )

        assert len(list(genomes.iterdir())) == 4
        assert set((tmp_path / "failed.txt").read_text().split()) == {
            "no_values.fa",
            "contaminated.fa",
            "low_score.fa",
        }
        assert self._details(tmp_path / "details.csv") == {
            "no_values.fa": "Missing completeness/contamination value",
            "contaminated.fa": "Failed QS50",
            "low_score.fa": "Failed QS50",  # 60 - 3*5 = 45, below the QS50 cutoff
        }

        passed = (tmp_path / "passed.csv").read_text().splitlines()
        assert passed == ["genome,completeness,contamination", "kept.fa,95.0,1.0"]

    def test_failed_genomes_are_deleted_from_the_input_folder(self, tmp_path):
        """With --remove the genomes that failed QC are deleted in place"""
        genomes = tmp_path / "genomes"
        shutil.copytree(self._fixture_path() / "genomes", genomes)

        filter_qs50_main(
            str(genomes),
            str(self._fixture_path() / "quality.csv"),
            str(tmp_path / "failed.txt"),
            str(tmp_path / "passed.csv"),
            str(tmp_path / "details.csv"),
            True,  # delete from the input folder
            False,  # don't write the filtered folder
        )

        assert [_.name for _ in genomes.iterdir()] == ["kept.fa"]

    def test_details_csv_written_when_nothing_fails(self, tmp_path):
        filter_qs50_main(
            str(self._fixture_path() / "passing_genome"),
            str(self._fixture_path() / "passing_quality.csv"),
            str(tmp_path / "failed.txt"),
            str(tmp_path / "passed.csv"),
            str(tmp_path / "details.csv"),
            False,
            False,
        )

        assert self._details(tmp_path / "details.csv") == {}
