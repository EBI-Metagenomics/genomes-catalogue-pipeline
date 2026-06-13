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
from typing import Dict, Optional

# 0-based indices of the GFF3 columns used here.
TYPE_COLUMN = 2
PHASE_COLUMN = 7
ATTRIBUTES_COLUMN = 8


def extract_attribute(attributes: str, key: str) -> Optional[str]:
    """Return the value of a GFF3 column-9 attribute, or None if the key is absent."""
    for field in attributes.split(";"):
        field = field.strip()
        if field.startswith(f"{key}="):
            return field[len(key) + 1 :]
    return None


def load_agat_phases(agat_gff: str) -> Dict[str, str]:
    """Map each CDS TCS_ID to the phase computed by agat_sp_fix_cds_phases.pl."""
    phases: Dict[str, str] = {}
    with open(agat_gff) as handle:
        for line in handle:
            if line.startswith("#"):
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) != 9 or fields[TYPE_COLUMN] != "CDS":
                continue
            tcs_id = extract_attribute(fields[ATTRIBUTES_COLUMN], "TCS_ID")
            if tcs_id is not None:
                phases[tcs_id] = fields[PHASE_COLUMN]
    return phases


def apply_phases(metaeuk_gff: str, phases: Dict[str, str], output: str) -> None:
    """Emit the original MetaEuk GFF line, only replacing the CDS phase with the AGAT one."""
    with open(metaeuk_gff) as handle_in, open(output, "w") as handle_out:
        for line in handle_in:
            if line.startswith("#"):
                handle_out.write(line)
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) == 9 and fields[TYPE_COLUMN] == "CDS":
                tcs_id = extract_attribute(fields[ATTRIBUTES_COLUMN], "TCS_ID")
                if tcs_id is not None and tcs_id in phases:
                    fields[PHASE_COLUMN] = phases[tcs_id]
                handle_out.write("\t".join(fields) + "\n")
            else:
                handle_out.write(line)


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Apply the CDS phases computed by agat_sp_fix_cds_phases.pl back onto the original MetaEuk "
            "GFF3. AGAT rewrites the non-standard MetaEuk structure (CDS Parent points to the exon) into "
            "a duplicated, unusable hierarchy, so only its per-CDS phase is reused: each CDS is matched "
            "to the original by its TCS_ID attribute and the original file is emitted unchanged except "
            "for the CDS phase (column 8)."
        )
    )
    parser.add_argument(
        "--metaeuk-gff",
        required=True,
        help="Original MetaEuk GFF3.",
    )
    parser.add_argument(
        "--agat-gff",
        required=True,
        help="GFF3 produced by agat_sp_fix_cds_phases.pl.",
    )
    parser.add_argument(
        "-o",
        "--output",
        required=True,
        help="Path for the fixed GFF3.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    phases = load_agat_phases(args.agat_gff)
    apply_phases(args.metaeuk_gff, phases, args.output)


if __name__ == "__main__":
    main()
