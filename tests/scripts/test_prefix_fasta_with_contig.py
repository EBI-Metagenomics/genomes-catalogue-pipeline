#!/bin/env python3

import pytest

from bin.prefix_fasta_with_contig import build_id_to_contig, prefix_fasta

GFF = (
    "##gff-version 3\n"
    "contig_1\tAUGUSTUS\tgene\t1\t145\t.\t-\t.\tID=g1;original_gene_id=g1\n"
    "contig_1\tAUGUSTUS\tmRNA\t1\t145\t0.62\t-\t.\tID=g1.t1;Parent=g1\n"
    "contig_2\tAUGUSTUS\tgene\t10\t99\t.\t+\t.\tID=g2\n"
    "contig_2\tAUGUSTUS\tmRNA\t10\t99\t0.9\t+\t.\tID=g2.t1;Parent=g2\n"
)

FASTA = ">g1.t1\nMKV\n>g2.t1 gene=g2 seq_id=contig_2 type=cds\nMWW\nAAK\n"


def _write(path, content):
    path.write_text(content)
    return str(path)


class TestBuildIdToContig:
    def test_maps_gene_and_transcript_ids(self, tmp_path):
        mapping = build_id_to_contig(_write(tmp_path / "in.gff", GFF))
        assert mapping == {
            "g1": "contig_1",
            "g1.t1": "contig_1",
            "g2": "contig_2",
            "g2.t1": "contig_2",
        }

    def test_gff_without_ids_raises(self, tmp_path):
        with pytest.raises(ValueError, match="No feature with an ID attribute"):
            build_id_to_contig(_write(tmp_path / "empty.gff", "##gff-version 3\n"))


class TestPrefixFasta:
    def test_headers_get_the_contig_and_keep_the_description(self, tmp_path):
        mapping = build_id_to_contig(_write(tmp_path / "in.gff", GFF))
        output = tmp_path / "out.faa"
        prefix_fasta(_write(tmp_path / "in.faa", FASTA), mapping, str(output))

        assert output.read_text() == (
            ">contig_1_g1.t1\nMKV\n" ">contig_2_g2.t1 gene=g2 seq_id=contig_2 type=cds\nMWW\nAAK\n"
        )

    def test_separator_inside_the_id_is_replaced(self, tmp_path):
        """CAT recovers the contig by dropping the last '_' field, so the ID must not carry one."""
        gff = "contig_1\tAUGUSTUS\tmRNA\t1\t9\t.\t+\t.\tID=MGYG001_00001.t1\n"
        mapping = build_id_to_contig(_write(tmp_path / "in.gff", gff))
        output = tmp_path / "out.faa"
        prefix_fasta(_write(tmp_path / "in.faa", ">MGYG001_00001.t1\nMKV\n"), mapping, str(output))

        header = output.read_text().splitlines()[0]
        assert header == ">contig_1_MGYG001-00001.t1"
        assert header[1:].rsplit("_", 1)[0] == "contig_1"

    def test_record_missing_from_the_gff_raises(self, tmp_path):
        mapping = build_id_to_contig(_write(tmp_path / "in.gff", GFF))
        fasta = _write(tmp_path / "in.faa", ">g9.t1\nMKV\n")
        with pytest.raises(ValueError, match="'g9.t1' is present"):
            prefix_fasta(fasta, mapping, str(tmp_path / "out.faa"))
