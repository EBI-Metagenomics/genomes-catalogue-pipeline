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
import logging
import re
from typing import Dict

ID_PATTERN = re.compile(r"(?:^|;)ID=([^;]+)")

logger = logging.getLogger(__name__)


def build_id_to_contig(gff_path: str) -> Dict[str, str]:
    """Build the {feature_id: contig} mapping from the GFF."""
    id_to_contig: Dict[str, str] = {}
    with open(gff_path, "r") as gff_in:
        for line in gff_in:
            if line.startswith("#") or not line.strip():
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 9:
                continue
            contig, attributes = fields[0], fields[8]
            match = ID_PATTERN.search(attributes)
            if match:
                id_to_contig[match.group(1)] = contig

    if not id_to_contig:
        raise ValueError(f"No feature with an ID attribute was found in {gff_path}")
    logger.info(f"Loaded {len(id_to_contig)} feature IDs from {gff_path}")
    return id_to_contig


def prefix_fasta(fasta: str, id_to_contig: Dict[str, str], output: str, separator: str = "_") -> None:
    """Rewrite every FASTA header as <contig><separator><record_id>, keeping the description."""
    renamed = 0
    with open(fasta, "r") as fasta_in, open(output, "w") as fasta_out:
        for line in fasta_in:
            if not line.startswith(">"):
                fasta_out.write(line)
                continue
            header = line[1:].rstrip("\n")
            record_id = header.split()[0] if header.split() else ""
            description = header[len(record_id) :]
            if record_id not in id_to_contig:
                raise ValueError(f"ID {record_id!r} is present in {fasta} but missing from the GFF")
            safe_id = record_id.replace(separator, "-")
            fasta_out.write(f">{id_to_contig[record_id]}{separator}{safe_id}{description}\n")
            renamed += 1

    if not renamed:
        raise ValueError(f"No FASTA record was found in {fasta}")
    logger.info(f"Renamed {renamed} FASTA headers into {output}")


def parse_args():
    parser = argparse.ArgumentParser(description="Prefix FASTA headers with the contig taken from the GFF.")
    parser.add_argument("-g", "--gff", required=True, help="Input GFF3 file.")
    parser.add_argument("-f", "--fasta", required=True, help="Input FASTA file.")
    parser.add_argument("-o", "--output", required=True, help="Output FASTA file.")
    parser.add_argument(
        "--sep", default="_", help="Separator between the contig and the record ID. Default: _"
    )
    return parser.parse_args()


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )
    args = parse_args()
    prefix_fasta(args.fasta, build_id_to_contig(args.gff), args.output, args.sep)
