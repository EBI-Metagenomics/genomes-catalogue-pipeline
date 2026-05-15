#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2026 EMBL - European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# This is a refactored script from CELEBRIMBOR project: https://github.com/bacpop/CELEBRIMBOR/blob/main/scripts/make_presence_absence_matrix.py

from collections import Counter
import argparse
import pandas as pd


def parse_clusters(adjacency_file):
    """
    Parse an mmseqs2 cluster TSV into a structured dict, sorting lines in memory
    for consistent representative ordering regardless of mmseqs2 output order.

    Gene IDs must follow the <genome_name>_<gene_number> convention so that genome
    identity can be recovered by splitting on the last underscore. Prokka satisfies
    this automatically when run with --locustag <genome_name>.

    Input
    -----
    adjacency_file : str
        Two-column TSV from `mmseqs easy-cluster` (*_cluster.tsv).
        Column 1: cluster representative gene ID.
        Column 2: cluster member gene ID (equals column 1 for singletons/self-pairs).

    Returns
    -------
    clusters : dict
        {representative_id: {genome_name: [member_locus_tag, ...]}}
        Each key is a cluster representative; values map genome names to the list
        of member locus tags from that genome belonging to the cluster.
    all_genomes : list[str]
        Sorted list of all genome names found across all clusters.
    """
    clusters = {}
    all_genomes = set()

    with open(adjacency_file) as f:
        lines = sorted(f.readlines())

    for line in lines:
        parts = line.split()
        if len(parts) < 2:
            continue
        rep, member = parts[0], parts[1]
        genome = member.rsplit("_", 1)[0]
        all_genomes.add(genome)
        clusters.setdefault(rep, {}).setdefault(genome, []).append(member)

    return clusters, sorted(all_genomes)


def parse_gff_annotations(gff_files):
    """
    Extract per-locus-tag gene names and product annotations from a list of Prokka GFF3 files.

    Only lines with exactly 9 tab-separated columns are parsed — this safely skips
    comment lines and FASTA headers. Iteration stops at the ##FASTA directive.
    Only CDS features (column 3) are considered.
    The gene symbol is read from the 'gene' attribute and the functional annotation
    from the 'product' attribute of column 9.

    Input
    -----
    gff_files : list[str]
        Per-genome Prokka GFF3 files. Files are read individually; they do not need
        to be concatenated beforehand.

    Returns
    -------
    annotations : dict
        {locus_tag: {'gene': str, 'product': str}}
        Values are empty strings when the attribute is absent in the GFF.
    """
    annotations = {}

    for gff_file in gff_files:
        with open(gff_file) as f:
            for line in f:
                if line.startswith("##FASTA"):
                    break
                parts = line.strip().split("\t")
                if len(parts) != 9 or parts[2] != "CDS":
                    continue
                attrs = {}
                for item in parts[8].split(";"):
                    if "=" in item:
                        k, v = item.split("=", 1)
                        attrs[k] = v
                locus_tag = attrs.get("ID", "")
                if locus_tag:
                    annotations[locus_tag] = {
                        "gene": attrs.get("gene", ""),
                        "product": attrs.get("product", ""),
                    }

    return annotations


def compute_cluster_metadata(clusters, annotations):
    """
    Determine the dominant gene name and product annotation for each cluster.

    For each cluster, collects gene names and product annotations from all member
    locus tags via the annotations dict and picks the most frequent non-empty value.
    When annotations is empty (e.g. --gff not provided), both fields are empty strings.

    Input
    -----
    clusters : dict
        Output of parse_clusters().
    annotations : dict
        Output of parse_gff_annotations(), or an empty dict.

    Returns
    -------
    cluster_meta : dict
        {representative_id: {'gene': str, 'annotation': str}}
    gene_to_reps : dict
        {gene_name: [representative_id, ...]}
        Only populated for non-empty gene names. Used downstream to detect
        gene names that appear in more than one cluster.
    """
    cluster_meta = {}
    gene_to_reps = {}

    for rep, genome_members in clusters.items():
        all_members = [m for members in genome_members.values() for m in members]

        gene_names = [annotations.get(m, {}).get("gene", "") for m in all_members]
        products = [annotations.get(m, {}).get("product", "") for m in all_members]

        gene = Counter(g for g in gene_names if g).most_common(1)
        gene = gene[0][0] if gene else ""
        annotation = Counter(p for p in products if p).most_common(1)
        annotation = annotation[0][0] if annotation else ""

        cluster_meta[rep] = {"gene": gene, "annotation": annotation}
        if gene:
            gene_to_reps.setdefault(gene, []).append(rep)

    return cluster_meta, gene_to_reps


def build_canonical_names(cluster_meta, gene_to_reps):
    """
    Assign a unique canonical name to every cluster representative.

    Rules (applied in sorted representative order for determinism):
      - Clusters with a gene name that is unique across all clusters → use the gene name as-is.
      - Clusters sharing a gene name with other clusters → use <gene_name> for the first
        (lexicographically smallest representative) and <gene_name>_N (N = 2, 3, ...) for
        subsequent ones.
      - Clusters with no gene name → group_N (sequential integer starting at 1).

    These canonical names are used as the row index in the Rtab, the Gene column in the
    CSV, and the FASTA header in pan-genome.fna, ensuring the three outputs are
    cross-referenceable.

    Input
    -----
    cluster_meta : dict
        Output of compute_cluster_metadata().
    gene_to_reps : dict
        Output of compute_cluster_metadata().

    Returns
    -------
    canonical_names : dict
        {representative_id: canonical_name}
    non_unique_genes : set[str]
        Gene names that appear as the dominant name in more than one cluster.
        Used to populate the Non-unique Gene name column in the CSV.
    """
    non_unique_genes = {g for g, reps in gene_to_reps.items() if len(reps) > 1}

    # Pre-assign suffixed names for duplicates in sorted rep order
    gene_suffix_map = {}
    for gene, reps in gene_to_reps.items():
        if gene in non_unique_genes:
            for i, rep in enumerate(sorted(reps), start=1):
                gene_suffix_map[(gene, rep)] = gene if i == 1 else f"{gene}_{i}"

    canonical_names = {}
    group_counter = 1

    for rep in sorted(cluster_meta.keys()):
        gene = cluster_meta[rep]["gene"]
        if not gene:
            canonical_names[rep] = f"group_{group_counter}"
            group_counter += 1
        elif gene in non_unique_genes:
            canonical_names[rep] = gene_suffix_map[(gene, rep)]
        else:
            canonical_names[rep] = gene

    return canonical_names, non_unique_genes


def make_presence_absence_matrix(clusters, all_genomes, canonical_names, outputfilename):
    """
    Write a gene presence/absence matrix in Roary/Panaroo Rtab format.

    Row labels use canonical gene names (from build_canonical_names) so the index
    is consistent with the Gene column in the CSV and the headers in pan-genome.fna.

    Input
    -----
    clusters : dict
        Output of parse_clusters().
    all_genomes : list[str]
        Sorted list of all genome names.
    canonical_names : dict
        Output of build_canonical_names(): {representative_id: canonical_name}.

    Output
    ------
    outputfilename : str
        Tab-separated file:
          - Rows    : canonical gene names (index label "Gene").
          - Columns : genome names, sorted lexicographically.
          - Values  : 1 if the cluster is present in that genome, 0 otherwise.
    """
    pa = {
        canonical_names[rep]: {g: 1 for g in genome_members}
        for rep, genome_members in clusters.items()
    }
    df = pd.DataFrame.from_dict(pa, orient="index")
    df = df.reindex(sorted(df.columns), axis=1)
    df = df.sort_index()
    df = df.fillna(0).astype(int)
    df.to_csv(outputfilename, sep="\t", index_label="Gene")


def make_gene_presence_absence_csv(
    clusters, all_genomes, cluster_meta, canonical_names, non_unique_genes, outputfilename
):
    """
    Write a reduced Roary-style gene_presence_absence.csv.

    Metadata columns (Roary semantics)
    -----------------------------------
    Gene
        Canonical gene name from build_canonical_names(). Unique across all rows.
        Duplicated gene families are disambiguated with a _N suffix.
    Non-unique Gene name
        The original (undisambiguated) gene symbol for clusters whose dominant gene
        name also appears in at least one other cluster, flagging potential split genes
        or misannotations. Empty string when the gene name is unique.
    Annotation
        Most frequently occurring product description across all cluster members.
        Empty string when no annotation is available.

    Per-genome columns
        Locus tag(s) from that genome belonging to the cluster, tab-separated when
        multiple paralogs are present. Empty string when the cluster is absent.

    Input
    -----
    clusters : dict
        Output of parse_clusters().
    all_genomes : list[str]
        Sorted list of all genome names (defines column order).
    cluster_meta : dict
        Output of compute_cluster_metadata(): {rep: {'gene': str, 'annotation': str}}.
    canonical_names : dict
        Output of build_canonical_names(): {rep: canonical_name}.
    non_unique_genes : set[str]
        Output of build_canonical_names(): gene names shared across multiple clusters.

    Output
    ------
    outputfilename : str
        Comma-separated file with columns:
        Gene, Non-unique Gene name, Annotation, <genome_1>, <genome_2>, ...
    """
    rows = []

    for rep in sorted(clusters.keys()):
        meta = cluster_meta[rep]
        original_gene = meta["gene"]

        row = {
            "Gene": canonical_names[rep],
            "Non-unique Gene name": original_gene if original_gene in non_unique_genes else "",
            "Annotation": meta["annotation"],
        }
        for genome in all_genomes:
            row[genome] = "\t".join(clusters[rep].get(genome, []))

        rows.append(row)

    cols = ["Gene", "Non-unique Gene name", "Annotation"] + list(all_genomes)
    pd.DataFrame(rows, columns=cols).to_csv(outputfilename, index=False)


def write_pan_genome_fna(rep_seq_fasta, canonical_names, outputfilename):
    """
    Write a pan-genome nucleotide FASTA with canonical gene names as sequence headers.

    Reads the mmseqs2 representative-sequence FASTA and replaces each locus-tag header
    with the corresponding canonical gene name, producing one entry per gene cluster.
    The canonical names are guaranteed unique, so headers are safe for downstream tools.

    Input
    -----
    rep_seq_fasta : str
        FASTA of cluster representative sequences from `mmseqs easy-cluster`
        (*_rep_seq.fasta). Headers are representative locus tags.
    canonical_names : dict
        Output of build_canonical_names(): {rep_locus_tag: canonical_gene_name}.

    Output
    ------
    outputfilename : str
        FASTA file with one entry per gene cluster.
          - Header   : >canonical_gene_name
          - Sequence : nucleotide sequence of the cluster representative.
    """
    with open(rep_seq_fasta) as fin, open(outputfilename, "w") as fout:
        write_seq = False
        for line in fin:
            if line.startswith(">"):
                locus_tag = line[1:].split()[0]
                canonical = canonical_names.get(locus_tag)
                if canonical:
                    fout.write(f">{canonical}\n")
                    write_seq = True
                else:
                    write_seq = False
            elif write_seq:
                fout.write(line)


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Convert mmseqs2 cluster output into pangenome outputs compatible with "
            "Roary/Panaroo: a presence/absence Rtab, an annotated gene_presence_absence.csv, "
            "and a pan-genome nucleotide FASTA. "
            "Gene IDs must follow the <genome_name>_<gene_number> convention so that "
            "genome names can be recovered by splitting on the last underscore. "
            "Prokka satisfies this automatically when run with --locustag <genome_name>. "
            "The cluster TSV is sorted internally; no prior sort step is required. "
            "All outputs share the same canonical gene names as identifiers, making "
            "them directly cross-referenceable."
        )
    )
    parser.add_argument(
        "--mmseqs_clusters",
        required=True,
        help=(
            "Raw TSV output from `mmseqs easy-cluster` (*_cluster.tsv). "
            "Two-column file: cluster representative gene ID (col 1), "
            "cluster member gene ID (col 2). Singletons appear as self-pairs."
        ),
    )
    parser.add_argument(
        "--output",
        required=True,
        default="gene_presence_absence.Rtab",
        help=(
            "Output Rtab file. Tab-separated presence/absence matrix: "
            "canonical gene names as rows (index label 'Gene'), genome names as columns, "
            "0/1 values. Default: gene_presence_absence.Rtab"
        ),
    )
    parser.add_argument(
        "--gff",
        nargs="+",
        default=None,
        help=(
            "One or more per-genome Prokka GFF3 files (do not need to be concatenated). "
            "Required to populate gene names and annotations in the CSV output. "
            "Gene symbols are read from the 'gene' attribute; functional annotations "
            "from the 'product' attribute. Without --gff, all clusters are named group_N."
        ),
    )
    parser.add_argument(
        "--output_csv",
        default="gene_presence_absence.csv",
        help=(
            "Output Roary-style CSV (written only when --gff is provided). "
            "Columns: Gene, Non-unique Gene name, Annotation, then one column per genome "
            "containing member locus tag(s). Default: gene_presence_absence.csv"
        ),
    )
    parser.add_argument(
        "--rep_seq",
        default=None,
        help=(
            "FASTA of cluster representative sequences from `mmseqs easy-cluster` "
            "(*_rep_seq.fasta). When provided, a pan-genome.fna is written with "
            "canonical gene names as headers."
        ),
    )
    parser.add_argument(
        "--output_fna",
        default="pan-genome.fna",
        help=(
            "Output pan-genome nucleotide FASTA (written only when --rep_seq is provided). "
            "One entry per gene cluster, header is the canonical gene name. "
            "Default: pan-genome.fna"
        ),
    )
    args = parser.parse_args()

    clusters, all_genomes = parse_clusters(args.mmseqs_clusters)
    annotations = parse_gff_annotations(args.gff) if args.gff else {}
    cluster_meta, gene_to_reps = compute_cluster_metadata(clusters, annotations)
    canonical_names, non_unique_genes = build_canonical_names(cluster_meta, gene_to_reps)

    make_presence_absence_matrix(clusters, all_genomes, canonical_names, args.output)

    if args.gff:
        make_gene_presence_absence_csv(
            clusters, all_genomes, cluster_meta, canonical_names, non_unique_genes, args.output_csv
        )

    if args.rep_seq:
        write_pan_genome_fna(args.rep_seq, canonical_names, args.output_fna)


if __name__ == "__main__":
    main()
