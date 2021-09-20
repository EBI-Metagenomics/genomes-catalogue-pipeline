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
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script converts checkm output to csv format")
    parser.add_argument("-i", "--input", dest="input", help="checkm_results.tab: checkm output log",
                        required=True)

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()

        print("genome,completeness,contamination,strain_heterogeneity")

        with open(args.input, "r") as f:
            next(f)
            for line in f:
                if 'INFO:' in line:
                    continue
                if 'Completeness' in line and 'Contamination' in line:
                    continue
                cols = line.strip("\n").split("\t")
                genome = cols[0]
                complet = cols[-3]
                cont = cols[-2]
                strain = cols[-1]
                print("%s.fa,%s,%s,%s" % (genome, complet, cont, strain))