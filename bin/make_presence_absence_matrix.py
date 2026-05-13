#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2025 EMBL - European Bioinformatics Institute
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
# This is a refactored script from CELEBRIMBOR project

import pandas as pd
import argparse


def make_presence_absence_matrix(adjacency_file, outputfilename):
    """
    Convert an mmseqs2 cluster TSV into a gene presence/absence matrix.

    The cluster TSV is sorted in memory before processing to ensure consistent
    representative-gene ordering regardless of mmseqs2 output order.

    Gene IDs are expected to follow the <sample_name>_<gene_number> convention
    (e.g. Prokka with --locustag <sample_name> produces this automatically).
    Sample identity is recovered by splitting each gene ID on the last underscore.

    Input
    -----
    adjacency_file : str
        Two-column TSV produced by `mmseqs easy-cluster` (*_cluster.tsv).
        Column 1: cluster representative gene ID.
        Column 2: cluster member gene ID (can equal column 1 for singletons).

    Output
    ------
    outputfilename : str
        Tab-separated presence/absence matrix in Roary/Panaroo Rtab format:
          - Rows    : gene cluster representative IDs (index label "Gene").
          - Columns : sample names (derived from gene IDs).
          - Values  : 1 if the gene cluster is present in that sample, 0 otherwise.
        Rows and columns are sorted lexicographically.
    """
    dictionary_of_gene_presence_absence = {}

    with open(adjacency_file, "r") as fin:
        lines = sorted(fin.readlines())

    for line in lines:
        parts = line.split()
        if len(parts) < 2:
            continue
        edge1 = parts[0]
        edge2 = parts[1]
        sample_1_name = edge1.rsplit("_", 1)[0]
        sample_2_name = edge2.rsplit("_", 1)[0]
        if edge1 not in dictionary_of_gene_presence_absence:
            dictionary_of_gene_presence_absence[edge1] = {}
        dictionary_of_gene_presence_absence[edge1][sample_1_name] = 1
        dictionary_of_gene_presence_absence[edge1][sample_2_name] = 1

    matrixDf = pd.DataFrame.from_dict(dictionary_of_gene_presence_absence)
    matrixDf = matrixDf.reindex(sorted(matrixDf.columns), axis=1)
    matrixDf = matrixDf.sort_index()
    matrixDf.fillna(0, inplace=True)
    matrixDf = matrixDf.T.astype(int)
    matrixDf.to_csv(outputfilename, sep="\t", index_label="Gene")


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Convert mmseqs2 cluster output into a gene presence/absence matrix "
            "in Roary/Panaroo Rtab format. "
            "Gene IDs must follow the <sample_name>_<gene_number> convention so that "
            "sample names can be recovered by splitting on the last underscore. "
            "Prokka satisfies this automatically when run with --locustag <sample_name>. "
            "The cluster TSV is sorted internally, so the raw mmseqs2 output can be "
            "passed directly without a prior sort step."
        )
    )
    parser.add_argument(
        "--mmseqs_clusters",
        type=str,
        required=True,
        help=(
            "Raw TSV output from `mmseqs easy-cluster` (*_cluster.tsv). "
            "Two-column file: cluster representative gene ID (col 1), "
            "cluster member gene ID (col 2). Singletons appear as self-pairs."
        ),
    )
    parser.add_argument(
        "--output",
        type=str,
        required=True,
        default="gene_presence_absence.Rtab",
        help=(
            "Path for the output Rtab file. Tab-separated matrix with gene cluster "
            "representatives as rows, sample names as columns, and 0/1 values. "
            "Default: gene_presence_absence.Rtab"
        ),
    )
    args = parser.parse_args()

    make_presence_absence_matrix(args.mmseqs_clusters, args.output)


if __name__ == "__main__":
    main()
