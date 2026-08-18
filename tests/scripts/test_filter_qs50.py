#!/bin/env python3

from bin.filter_qs50 import main as filter_qs50_main


class TestFilterQS50:
    def _setup(self, tmp_path, rows):
        """Build a genomes folder and a matching quality CSV from (genome, completeness, contamination) rows"""
        genomes = tmp_path / "genomes"
        genomes.mkdir()
        lines = ["genome,completeness,contamination"]
        for genome, completeness, contamination in rows:
            (genomes / genome).write_text(">contig\nACGT\n")
            lines.append("{},{},{}".format(genome, completeness, contamination))
        quality = tmp_path / "quality.csv"
        quality.write_text("\n".join(lines) + "\n")
        return genomes, quality

    def _details(self, tmp_path):
        lines = (tmp_path / "details.csv").read_text().splitlines()
        return {line.split(",")[0]: line.split(",")[3] for line in lines}

    def test_filtering_and_failure_reasons(self, tmp_path, monkeypatch):
        """Genomes without quality values are filtered out, and every removal is traced with its reason"""
        genomes, quality = self._setup(
            tmp_path,
            [
                ("kept.fa", "95.0", "1.0"),
                ("no_values.fa", "NA", "NA"),
                ("contaminated.fa", "95.0", "7.0"),
                ("low_score.fa", "60.0", "3.0"),  # 60 - 3*5 = 45, below the QS50 cutoff
            ],
        )
        monkeypatch.chdir(tmp_path)

        filter_qs50_main(
            str(genomes),
            str(quality),
            "failed.txt",
            "passed.csv",
            "details.csv",
            False,  # don't delete from the input folder
            True,  # write the filtered folder
        )

        # only the passing genome is carried forward, and the input folder is untouched
        assert [_.name for _ in (tmp_path / "genomes_filtered").iterdir()] == ["kept.fa"]
        assert len(list(genomes.iterdir())) == 4

        assert set((tmp_path / "failed.txt").read_text().split()) == {
            "no_values.fa",
            "contaminated.fa",
            "low_score.fa",
        }
        assert self._details(tmp_path) == {
            "no_values.fa": "Missing completeness/contamination value",
            "contaminated.fa": "Failed QS50",
            "low_score.fa": "Failed QS50",
        }

        passed = (tmp_path / "passed.csv").read_text().splitlines()
        assert passed == ["genome,completeness,contamination", "kept.fa,95.0,1.0"]

    def test_details_csv_written_when_nothing_fails(self, tmp_path, monkeypatch):
        """The details CSV is always produced - Nextflow declares it as an output"""
        genomes, quality = self._setup(tmp_path, [("kept.fa", "95.0", "1.0")])
        monkeypatch.chdir(tmp_path)

        filter_qs50_main(str(genomes), str(quality), "failed.txt", "passed.csv", "details.csv", False, True)

        assert self._details(tmp_path) == {}
