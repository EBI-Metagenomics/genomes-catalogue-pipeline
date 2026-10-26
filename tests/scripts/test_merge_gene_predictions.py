#!/bin/env python3

import argparse
import os
from pathlib import Path

from bin.merge_gene_predictions import (
    Transcript,
    append_attribute,
    build_metaeuk_gff_lines,
    exon_overlap,
    main,
    matched_secondary_transcripts,
    order_genes_by_position,
    parse_braker_genes,
    read_cds,
    remap_braker_ids,
    transcript_key,
)


def _base_path():
    return Path(
        os.path.abspath(
            "/" + os.path.dirname(__file__) + "/fixtures/merge_gene_predictions"
        )
    )


def _read_lines(path):
    with open(path) as handle:
        return [line.rstrip("\n") for line in handle]


class TestTranscriptKey:
    """transcript_key extracts a unique per-caller key from a CDS attribute column."""

    def test_braker_returns_parent(self):
        attr = "ID=g5.t1.CDS1;Parent=g5.t1"
        assert transcript_key(attr, is_metaeuk=False) == "g5.t1"

    def test_braker_missing_parent_returns_none(self):
        assert transcript_key("ID=g5.t1.CDS1", is_metaeuk=False) is None

    def test_metaeuk_uses_first_two_tcs_fields(self):
        attr = "Target_ID=acc;TCS_ID=acc|contig_1|+|100_CDS_0;Parent=acc|contig_1|+|100_exon_0"
        assert transcript_key(attr, is_metaeuk=True) == "acc|contig_1"

    def test_metaeuk_missing_tcs_returns_none(self):
        assert transcript_key("Target_ID=acc", is_metaeuk=True) is None


class TestExonOverlap:
    """Reciprocal CDS overlap test between two transcripts."""

    def _transcript(self, exons, strand="+", contig="c1"):
        return Transcript(contig=contig, strand=strand, exons=exons)

    def test_identical_exons_fully_overlap(self):
        t1 = self._transcript([(101, 403)])
        t2 = self._transcript([(101, 403)])
        is_match, cov1 = exon_overlap(t1, t2, threshold=0.1)
        assert is_match is True
        assert cov1 == 1.0

    def test_disjoint_exons_do_not_overlap(self):
        t1 = self._transcript([(101, 200)])
        t2 = self._transcript([(300, 400)])
        is_match, cov1 = exon_overlap(t1, t2, threshold=0.1)
        assert is_match is False
        assert cov1 == 0

    def test_partial_overlap_below_threshold_is_not_a_match(self):
        t1 = self._transcript([(101, 301)])
        t2 = self._transcript([(292, 492)])
        is_match, _ = exon_overlap(t1, t2, threshold=0.5)
        assert is_match is False

    def test_multi_exon_overlap(self):
        t1 = self._transcript([(201, 500), (601, 900)])
        t2 = self._transcript([(201, 500), (601, 900)])
        is_match, cov1 = exon_overlap(t1, t2, threshold=0.1)
        assert is_match is True
        assert cov1 == 1.0


class TestAppendAttribute:
    def test_appends_to_existing_attributes(self):
        assert append_attribute("ID=g1", "original_gene_id", "g1") == (
            "ID=g1;original_gene_id=g1"
        )

    def test_does_not_duplicate_existing_key(self):
        col9 = "ID=g1;original_gene_id=g1"
        assert append_attribute(col9, "original_gene_id", "g9") == col9

    def test_handles_empty_column(self):
        assert append_attribute("", "ID", "g1") == "ID=g1"

    def test_handles_trailing_semicolon(self):
        assert append_attribute("ID=g1;", "score", "5") == "ID=g1;score=5"


class TestRemapBrakerIds:
    def test_remaps_id_and_parent(self):
        col9 = "ID=g1.t1;Parent=g1"
        remapped = remap_braker_ids(col9, {"g1": "g7"})
        assert remapped == "ID=g7.t1;Parent=g7"

    def test_leaves_unmapped_ids_untouched(self):
        col9 = "ID=g3.t1;Parent=g3"
        assert remap_braker_ids(col9, {"g1": "g7"}) == col9


class TestReadCds:
    def test_reads_braker_cds(self):
        transcripts = read_cds(str(_base_path() / "braker.gff"), is_metaeuk=False)
        assert set(transcripts) == {"g1.t1", "g2.t1"}
        assert transcripts["g1.t1"].exons == [(101, 403)]
        assert transcripts["g1.t1"].strand == "+"
        assert transcripts["g2.t1"].strand == "-"

    def test_reads_metaeuk_cds_with_phases(self):
        transcripts = read_cds(str(_base_path() / "metaeuk.gff"), is_metaeuk=True)
        assert set(transcripts) == {"acc_match|contig_1", "acc_uniq|contig_2"}
        unique = transcripts["acc_uniq|contig_2"]
        assert unique.exons == [(201, 500), (601, 900)]
        assert unique.phases == {(201, 500): "0", (601, 900): "1"}


class TestMatchedSecondaryTranscripts:
    def test_detects_overlap_and_skips_opposite_strand(self):
        braker = read_cds(str(_base_path() / "braker.gff"), is_metaeuk=False)
        metaeuk = read_cds(str(_base_path() / "metaeuk.gff"), is_metaeuk=True)
        matched, overlapped_fraction = matched_secondary_transcripts(
            braker, metaeuk, threshold=0.1
        )
        assert matched == {"acc_match|contig_1"}
        assert overlapped_fraction == {"g1.t1": 1.0}


class TestParseBrakerGenes:
    def test_groups_lines_by_gene_and_records_order(self):
        genes, contig_order = parse_braker_genes(str(_base_path() / "braker.gff"))
        assert set(genes) == {1, 2}
        assert genes[1].start == 101
        assert genes[2].start == 1001
        assert contig_order == ["contig_1"]


class TestOrderGenesByPosition:
    def test_assigns_contiguous_ids_in_genomic_order(self):
        braker_genes, contig_order = parse_braker_genes(
            str(_base_path() / "braker.gff")
        )
        metaeuk = read_cds(str(_base_path() / "metaeuk.gff"), is_metaeuk=True)
        ordered_genes, braker_id_map, metaeuk_new_ids = order_genes_by_position(
            braker_genes, contig_order, metaeuk, ["acc_uniq|contig_2"]
        )
        assert ordered_genes == [(True, 1), (True, 2), (False, "acc_uniq|contig_2")]
        assert braker_id_map == {"g1": "g1", "g2": "g2"}
        assert metaeuk_new_ids == {"acc_uniq|contig_2": "g3"}


class TestBuildMetaeukGffLines:
    def test_reconstructs_gene_mrna_exon_cds(self):
        metaeuk = read_cds(str(_base_path() / "metaeuk.gff"), is_metaeuk=True)
        lines = build_metaeuk_gff_lines(
            metaeuk["acc_uniq|contig_2"], "g3", "MetaEuk", "acc_uniq|contig_2"
        )
        feature_types = [line.split("\t")[2] for line in lines]
        assert feature_types == ["gene", "mRNA", "exon", "exon", "CDS", "CDS"]
        assert lines[0].endswith(
            "ID=g3;original_gene_id=acc_uniq|contig_2;"
            "prediction_support=1;prediction_tools=MetaEuk"
        )
        # CDS phases are preserved from the (reconciled) MetaEuk GFF.
        assert lines[4].split("\t")[7] == "0"
        assert lines[5].split("\t")[7] == "1"


class TestMergeEndToEnd:
    """Run the full script and compare against checked-in golden outputs."""

    def test_merge_matches_expected_outputs(self, tmp_path):
        base = _base_path()
        output_prefix = str(tmp_path / "merged")
        args = argparse.Namespace(
            gff_braker=str(base / "braker.gff"),
            faa_braker=str(base / "braker.faa"),
            ffn_braker=str(base / "braker.ffn"),
            gff_metaeuk=str(base / "metaeuk.gff"),
            faa_metaeuk=str(base / "metaeuk.faa"),
            ffn_metaeuk=str(base / "metaeuk.ffn"),
            threshold=0.1,
            output_prefix=output_prefix,
        )

        main(args)

        for extension in ("gff", "faa", "ffn"):
            produced = _read_lines(f"{output_prefix}.{extension}")
            expected = _read_lines(base / f"expected_merged.{extension}")
            assert produced == expected, f"{extension} output differs from golden file"
