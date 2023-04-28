#!/bin/env python3

import os
from pathlib import Path

from bin.deduplicate import main as process_main


class TestDeduplication:
    def _base_path(self):
        return Path(
            os.path.abspath("/" + os.path.dirname(__file__) + "/fixtures/deduplication")
        )

    def test_deduplication(self, tmp_path):
        """Assert that the .gff generation works as expected."""
        fasta_files = list(map(str, self._base_path().glob("*.fa")))

        assert len(fasta_files) == 8

        process_main(fasta_files, tmp_path)

        dedup_files = []
        for fasta in Path(tmp_path).glob("*.fa"):
            dedup_files.append(fasta.name)

        dups_tsv = str(Path(tmp_path) / "duplicates.tsv")

        assert "CAJJTO01_dup.fa" not in dedup_files
        assert "CAJJTO01.fa" in dedup_files

        print(tmp_path)

        expected_lines = [
            [
                "454921b56bcf28e0c2ba9321369d340e",
                "2",
                ",".join(["CAJJTO01.fa", "CAJJTO01_dup.fa"]),
            ],
            ["ee7844f34749ca2a161dc9672fcf3d2d", "1", "CAJKXZ01.fa"],
            ["441efafcf52ab1c46e61cc56a5738dd6", "1", "CAJKRY01.fa"],
            ["733f65b1ade7f26e7ded6bd9b081c83e", "1", "CAJKGB01.fa"],
            ["152ff3be23649de3c10350099fec1567", "1", "CAJLGA01.fa"],
            ["797621ace89f0b650824889c79b0b973", "1", "CAJKXJ01.fa"],
            ["1198c226a0bad47e9f2ec272d673870a", "1", "CAJKRE01.fa"],
        ]

        expected_lines = sorted(expected_lines)

        with open(dups_tsv, "r") as dfh:
            next(dfh)
            lines = sorted(dfh.readlines())
            for idx, line in enumerate(lines):
                md5, copies, files_list = line.strip().replace("\n", "").split("\t")
                files = []
                for fasta_file in files_list.split(","):
                    files.append(Path(fasta_file).name)
                assert expected_lines[idx] == [md5, copies, ",".join(files)]
