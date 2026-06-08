#!/usr/bin/env python3
# coding=utf-8

# This file is part of MGnify genome analysis pipeline.
#
# MGnify genome analysis pipeline is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MGnify genome analysis pipeline is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with MGnify genome analysis pipeline. If not, see <https://www.gnu.org/licenses/>.

import argparse
import csv
import re
from typing import Dict


ID_COLUMN = "description"
SCORE_COLUMN = "in-frame_score"


def load_psauron_scores(psauron_csv: str) -> Dict[str, float]:
    """Parse the PSAURON per-protein CSV into a {sequence_id: score} dict."""
    scores = {}
    with open(psauron_csv, "r", newline="") as psauron_file:
        reader = csv.DictReader(psauron_file)
        if (
            not reader.fieldnames
            or ID_COLUMN not in reader.fieldnames
            or SCORE_COLUMN not in reader.fieldnames
        ):
            raise ValueError(
                f"PSAURON CSV must contain the '{ID_COLUMN}' and '{SCORE_COLUMN}' columns; "
                f"got {reader.fieldnames}"
            )
        for row in reader:
            sequence_id = (row.get(ID_COLUMN) or "").split()
            score = float(row.get(SCORE_COLUMN).strip())
            if sequence_id and score is not None:
                scores[sequence_id[0]] = score
    return scores


def annotate_gff(input_gff: str, scores: Dict[str, float], output_gff: str) -> None:
    """Add psauron_score to the mRNA feature of each scored transcript."""
    id_re = re.compile(r"ID=([^;]+)")

    with open(input_gff, "r") as gff_in, open(output_gff, "w") as gff_out:
        for line in gff_in:
            fields = line.rstrip("\n").split("\t")
            if len(fields) != 9 or fields[2] != "mRNA":
                gff_out.write(line)
                continue

            match = id_re.search(fields[8])
            transcript_id = match.group(1) if match else None

            if transcript_id in scores:
                col9 = fields[8]
                if col9 and not col9.endswith(";"):
                    col9 += ";"
                fields[8] = f"{col9}psauron_score={scores[transcript_id]:.4f}"
                gff_out.write("\t".join(fields) + "\n")
            else:
                gff_out.write(line)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Add PSAURON scores as a psauron_score attribute in a GFF."
    )
    parser.add_argument("-i", "--input-gff", required=True, help="Input GFF file.")
    parser.add_argument("-p", "--psauron-csv", required=True, help="PSAURON CSV.")
    parser.add_argument("-o", "--output-gff", required=True, help="Output GFF.")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    psauron_scores = load_psauron_scores(args.psauron_csv)
    annotate_gff(args.input_gff, psauron_scores, args.output_gff)
