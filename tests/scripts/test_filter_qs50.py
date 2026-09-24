#!/bin/env python3

import pytest

from bin.filter_qs50 import main as filter_qs50_main


@pytest.fixture
def make_input(tmp_path_factory):
    """Build a genomes folder and its quality.csv from {genome: (completeness, contamination)}"""

    def _make(quality_values):
        genomes = tmp_path_factory.mktemp("genomes")
        rows = ["genome,completeness,contamination"]
        for genome, (completeness, contamination) in quality_values.items():
            (genomes / genome).write_text(">contig\nACGT\n")
            rows.append(f"{genome},{completeness},{contamination}")
        # kept outside the genomes folder, everything in there is treated as a genome
        quality_csv = tmp_path_factory.mktemp("quality") / "quality.csv"
        quality_csv.write_text("\n".join(rows) + "\n")
        return genomes, quality_csv

    return _make


class TestFilterQS50:
    def _details(self, details_csv):
        lines = details_csv.read_text().splitlines()
        return {line.split(",")[0]: line.split(",")[3] for line in lines}

    def test_filtering_and_failure_reasons(self, tmp_path, make_input):
        """Genomes without quality values or below QS50 are filtered out, and every removal is traced"""
        genomes, quality_csv = make_input(
            {
                "kept.fa": (95.0, 1.0),
                "no_values.fa": ("NA", "NA"),
                "contaminated.fa": (95.0, 7.0),
                "low_score.fa": (60.0, 3.0),
            }
        )

        filter_qs50_main(
            str(genomes),
            str(quality_csv),
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

    def test_failed_genomes_are_deleted_from_the_input_folder(self, tmp_path, make_input):
        """With --remove the genomes that failed QC are deleted in place"""
        genomes, quality_csv = make_input({"kept.fa": (95.0, 1.0), "low_score.fa": (60.0, 3.0)})

        filter_qs50_main(
            str(genomes),
            str(quality_csv),
            str(tmp_path / "failed.txt"),
            str(tmp_path / "passed.csv"),
            str(tmp_path / "details.csv"),
            True,  # delete from the input folder
            False,  # don't write the filtered folder
        )

        assert [_.name for _ in genomes.iterdir()] == ["kept.fa"]

    def test_details_csv_written_when_nothing_fails(self, tmp_path, make_input):
        genomes, quality_csv = make_input({"kept.fa": (95.0, 1.0)})

        filter_qs50_main(
            str(genomes),
            str(quality_csv),
            str(tmp_path / "failed.txt"),
            str(tmp_path / "passed.csv"),
            str(tmp_path / "details.csv"),
            False,
            False,
        )

        assert self._details(tmp_path / "details.csv") == {}
