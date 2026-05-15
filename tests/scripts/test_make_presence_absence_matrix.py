#!/bin/env python3

from pathlib import Path

from bin.make_presence_absence_matrix import (
    build_canonical_names,
    compute_cluster_metadata,
    make_gene_presence_absence_csv,
    make_presence_absence_matrix,
    parse_clusters,
    parse_gff_annotations,
    write_pan_genome_fna,
)
from .base_classes import BaseTestWithFiles

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "make_presence_absence_matrix"
GFF_FILES = [FIXTURES / "genome1.gff", FIXTURES / "genome2.gff", FIXTURES / "genome3.gff"]


# ---------------------------------------------------------------------------
# Helpers — shared setup used by multiple test classes
# ---------------------------------------------------------------------------

def _load_full_pipeline():
    """Run the full pipeline on the shared fixtures and return all intermediates."""
    clusters, all_genomes = parse_clusters(FIXTURES / "clusters.tsv")
    annotations = parse_gff_annotations(GFF_FILES)
    cluster_meta, gene_to_reps = compute_cluster_metadata(clusters, annotations)
    canonical_names, non_unique_genes = build_canonical_names(cluster_meta, gene_to_reps)
    return clusters, all_genomes, annotations, cluster_meta, gene_to_reps, canonical_names, non_unique_genes


# ---------------------------------------------------------------------------
# parse_clusters
# ---------------------------------------------------------------------------

class TestParseClusters:
    def test_returns_all_genomes_sorted(self):
        _, all_genomes = parse_clusters(FIXTURES / "clusters.tsv")
        assert all_genomes == sorted(all_genomes)
        assert all_genomes == ["G1", "G2", "G3"]

    def test_cluster_representative_keys(self):
        clusters, _ = parse_clusters(FIXTURES / "clusters.tsv")
        assert set(clusters.keys()) == {"G1_00001", "G1_00002", "G1_00003", "G2_00004"}

    def test_multi_genome_cluster_membership(self):
        clusters, _ = parse_clusters(FIXTURES / "clusters.tsv")
        # G1_00001 is the rep for a cluster present in all three genomes
        assert set(clusters["G1_00001"].keys()) == {"G1", "G2", "G3"}
        assert clusters["G1_00001"]["G1"] == ["G1_00001"]
        assert clusters["G1_00001"]["G2"] == ["G2_00001"]
        assert clusters["G1_00001"]["G3"] == ["G3_00001"]

    def test_singleton_cluster(self):
        clusters, _ = parse_clusters(FIXTURES / "clusters.tsv")
        assert list(clusters["G1_00003"].keys()) == ["G1"]
        assert list(clusters["G2_00004"].keys()) == ["G2"]


# ---------------------------------------------------------------------------
# parse_gff_annotations
# ---------------------------------------------------------------------------

class TestParseGffAnnotations:
    def test_extracts_gene_and_product(self):
        annotations = parse_gff_annotations(GFF_FILES)
        assert annotations["G1_00001"] == {"gene": "recA", "product": "Recombinase A"}
        assert annotations["G1_00002"]["gene"] == "dnaA"

    def test_missing_gene_attribute_returns_empty_string(self):
        annotations = parse_gff_annotations(GFF_FILES)
        # G1_00003 has no gene= attribute in the GFF
        assert annotations["G1_00003"]["gene"] == ""
        assert annotations["G1_00003"]["product"] == "hypothetical protein"

    def test_multiple_gff_files_merged(self):
        annotations = parse_gff_annotations(GFF_FILES)
        for locus_tag in ["G1_00001", "G1_00002", "G1_00003", "G2_00001", "G2_00002", "G2_00004", "G3_00001"]:
            assert locus_tag in annotations

    def test_stops_at_fasta_directive(self, tmp_path):
        # A syntactically valid CDS line placed after ##FASTA must not be parsed
        gff = tmp_path / "test.gff"
        gff.write_text(
            "##gff-version 3\n"
            "G1\tProkka\tCDS\t1\t300\t.\t+\t0\tID=BEFORE_FASTA;gene=realGene;product=real\n"
            "##FASTA\n"
            "G1\tProkka\tCDS\t1\t300\t.\t+\t0\tID=AFTER_FASTA;gene=fakeGene;product=fake\n"
        )
        annotations = parse_gff_annotations([gff])
        assert "BEFORE_FASTA" in annotations
        assert "AFTER_FASTA" not in annotations


# ---------------------------------------------------------------------------
# compute_cluster_metadata
# ---------------------------------------------------------------------------

class TestComputeClusterMetadata:
    def test_dominant_gene_by_majority(self):
        clusters, _, annotations, cluster_meta, gene_to_reps, _, _ = _load_full_pipeline()
        # G1_00001 cluster has recA in all three member genomes
        assert cluster_meta["G1_00001"]["gene"] == "recA"
        assert cluster_meta["G1_00001"]["annotation"] == "Recombinase A"

    def test_cluster_without_gene_annotation(self):
        clusters, _, annotations, cluster_meta, _, _, _ = _load_full_pipeline()
        assert cluster_meta["G1_00003"]["gene"] == ""
        assert cluster_meta["G1_00003"]["annotation"] == "hypothetical protein"

    def test_gene_to_reps_populated_for_named_genes(self):
        _, _, _, _, gene_to_reps, _, _ = _load_full_pipeline()
        assert "recA" in gene_to_reps
        assert "dnaA" in gene_to_reps
        assert "G1_00001" in gene_to_reps["recA"]

    def test_empty_annotations_yields_empty_fields(self):
        clusters, _, _, _, _, _, _ = _load_full_pipeline()
        cluster_meta, gene_to_reps = compute_cluster_metadata(clusters, {})
        for meta in cluster_meta.values():
            assert meta["gene"] == ""
            assert meta["annotation"] == ""
        assert gene_to_reps == {}


# ---------------------------------------------------------------------------
# build_canonical_names
# ---------------------------------------------------------------------------

class TestBuildCanonicalNames:
    def test_unique_gene_uses_gene_name(self):
        _, _, _, _, _, canonical_names, _ = _load_full_pipeline()
        assert canonical_names["G1_00001"] == "recA"
        assert canonical_names["G1_00002"] == "dnaA"

    def test_unnamed_clusters_get_group_prefix(self):
        _, _, _, _, _, canonical_names, _ = _load_full_pipeline()
        assert canonical_names["G1_00003"] == "group_1"
        assert canonical_names["G2_00004"] == "group_2"

    def test_all_canonical_names_unique(self):
        _, _, _, _, _, canonical_names, _ = _load_full_pipeline()
        names = list(canonical_names.values())
        assert len(names) == len(set(names))

    def test_duplicate_gene_names_get_numeric_suffix(self):
        cluster_meta = {
            "repA": {"gene": "recA", "annotation": ""},
            "repB": {"gene": "recA", "annotation": ""},
        }
        gene_to_reps = {"recA": ["repA", "repB"]}
        canonical_names, non_unique = build_canonical_names(cluster_meta, gene_to_reps)
        assert set(canonical_names.values()) == {"recA", "recA_2"}
        assert "recA" in non_unique


# ---------------------------------------------------------------------------
# make_presence_absence_matrix  (Rtab format)
# ---------------------------------------------------------------------------

class TestMakePresenceAbsenceMatrix(BaseTestWithFiles):
    def test_rtab_matches_expected(self, tmp_path):
        clusters, all_genomes, _, _, _, canonical_names, _ = _load_full_pipeline()
        out = tmp_path / "gene_presence_absence.Rtab"
        make_presence_absence_matrix(clusters, all_genomes, canonical_names, out)
        assert self._get_checksum(out) == self._get_checksum(
            FIXTURES / "expected" / "gene_presence_absence.Rtab"
        )

    def test_rtab_header(self, tmp_path):
        clusters, all_genomes, _, _, _, canonical_names, _ = _load_full_pipeline()
        out = tmp_path / "gene_presence_absence.Rtab"
        make_presence_absence_matrix(clusters, all_genomes, canonical_names, out)
        header = out.read_text().splitlines()[0].split("\t")
        assert header[0] == "Gene"
        assert header[1:] == all_genomes

    def test_rtab_values_are_binary(self, tmp_path):
        clusters, all_genomes, _, _, _, canonical_names, _ = _load_full_pipeline()
        out = tmp_path / "gene_presence_absence.Rtab"
        make_presence_absence_matrix(clusters, all_genomes, canonical_names, out)
        for line in out.read_text().splitlines()[1:]:
            for val in line.split("\t")[1:]:
                assert val in ("0", "1")


# ---------------------------------------------------------------------------
# make_gene_presence_absence_csv
# ---------------------------------------------------------------------------

class TestMakeGenePresenceAbsenceCsv(BaseTestWithFiles):
    def test_csv_matches_expected(self, tmp_path):
        clusters, all_genomes, _, cluster_meta, _, canonical_names, non_unique_genes = _load_full_pipeline()
        out = tmp_path / "gene_presence_absence.csv"
        make_gene_presence_absence_csv(
            clusters, all_genomes, cluster_meta, canonical_names, non_unique_genes, out
        )
        assert self._get_checksum(out) == self._get_checksum(
            FIXTURES / "expected" / "gene_presence_absence.csv"
        )

    def test_csv_columns(self, tmp_path):
        import pandas as pd
        clusters, all_genomes, _, cluster_meta, _, canonical_names, non_unique_genes = _load_full_pipeline()
        out = tmp_path / "gene_presence_absence.csv"
        make_gene_presence_absence_csv(
            clusters, all_genomes, cluster_meta, canonical_names, non_unique_genes, out
        )
        df = pd.read_csv(out)
        assert list(df.columns[:3]) == ["Gene", "Non-unique Gene name", "Annotation"]
        assert list(df.columns[3:]) == all_genomes

    def test_csv_locus_tags(self, tmp_path):
        import pandas as pd
        clusters, all_genomes, _, cluster_meta, _, canonical_names, non_unique_genes = _load_full_pipeline()
        out = tmp_path / "gene_presence_absence.csv"
        make_gene_presence_absence_csv(
            clusters, all_genomes, cluster_meta, canonical_names, non_unique_genes, out
        )
        df = pd.read_csv(out).set_index("Gene")
        assert df.loc["recA", "G1"] == "G1_00001"
        assert df.loc["recA", "G2"] == "G2_00001"
        assert df.loc["recA", "G3"] == "G3_00001"


# ---------------------------------------------------------------------------
# write_pan_genome_fna
# ---------------------------------------------------------------------------

class TestWritePanGenomeFna(BaseTestWithFiles):
    def test_fna_matches_expected(self, tmp_path):
        _, _, _, _, _, canonical_names, _ = _load_full_pipeline()
        out = tmp_path / "pan_genome.fna"
        write_pan_genome_fna(FIXTURES / "rep_seq.fna", canonical_names, out)
        assert self._get_checksum(out) == self._get_checksum(
            FIXTURES / "expected" / "pan_genome.fna"
        )

    def test_fna_headers_are_canonical_names(self, tmp_path):
        _, _, _, _, _, canonical_names, _ = _load_full_pipeline()
        out = tmp_path / "pan_genome.fna"
        write_pan_genome_fna(FIXTURES / "rep_seq.fna", canonical_names, out)
        headers = {l.strip()[1:] for l in out.read_text().splitlines() if l.startswith(">")}
        assert headers == set(canonical_names.values())

    def test_fna_one_entry_per_cluster(self, tmp_path):
        clusters, _, _, _, _, canonical_names, _ = _load_full_pipeline()
        out = tmp_path / "pan_genome.fna"
        write_pan_genome_fna(FIXTURES / "rep_seq.fna", canonical_names, out)
        headers = [l for l in out.read_text().splitlines() if l.startswith(">")]
        assert len(headers) == len(clusters)
