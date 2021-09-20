#!/usr/bin/env python

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


import sys
import os
import argparse

aa = [
    "Ala",
    "Gly",
    "Pro",
    "Thr",
    "Val",
    "Ser",
    "Arg",
    "Leu",
    "Phe",
    "Asn",
    "Lys",
    "Asp",
    "Glu",
    "His",
    "Gln",
    "Ile",
    "Tyr",
    "Cys",
    "Trp",
]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script detects tRNA")
    parser.add_argument("-i", "--input", dest="input", help="trnas_stats.out",
                        required=True)

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()

        with open(args.input, "r") as f:
            trnas = 0
            flag = 0
            for line in f:
                if "Isotype / Anticodon" in line:
                    flag = 1
                elif flag == 1:
                    cols = line.split()
                    if len(cols) > 1:
                        aa_pred = line.split(":")[0].split()[0]
                        counts = int(line.split(":")[1].split()[0])
                        if (aa_pred in aa or "Met" in aa_pred) and counts > 0:
                            trnas += 1

        print("{name}\t{trnas}".format(name=os.path.basename(args.input).split("_stats")[0], trnas=trnas))
