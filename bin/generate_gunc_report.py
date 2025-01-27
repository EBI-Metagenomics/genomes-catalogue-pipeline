#!/usr/bin/env python3

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
import sys
import os

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="GUNC report about filtered genomes")
    parser.add_argument(
        "-i",
        "--input",
        dest="input",
        help="Gunc decision files",
        nargs="+",
        required=True,
    )

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()
        with open("gunc_report_completed.txt", "w") as completed, open(
            "gunc_report_failed.txt", "w"
        ) as failed:
            for filename in args.input:
                name = os.path.basename(filename)
                genome = name.split("_")[0]
                if "complete" in filename:
                    completed.write(genome + ".fa\n")
                else:
                    failed.write(genome + ".fa\n")
