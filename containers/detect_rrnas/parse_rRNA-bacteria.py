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


import os
import sys
import argparse


rRNAs_exp = {"5S_rRNA": 119, "SSU_rRNA_bacteria": 1533, "LSU_rRNA_bacteria": 2925}
rRNAs_obs = {"5S_rRNA": [], "SSU_rRNA_bacteria": [], "LSU_rRNA_bacteria": []}
rRNAs_merged = {}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script detects bacretia rRNA")
    parser.add_argument(
        "-i", "--input", dest="input", help="rrna.tblout.deoverlapped", required=True
    )

    args = parser.parse_args()
    # store start and end position of each hit
    with open(args.input, "r") as f:
        for line in f:
            cols = line.split()
            rfam = cols[2]
            rfam_start = int(cols[5])
            rfam_end = int(cols[6])
            rRNAs_obs[rfam].append([rfam_start, rfam_end])

    # sort intervals by start position and merge
    for ele in rRNAs_obs.keys():
        rRNAs_merged[ele] = []
        try:
            saved = sorted(rRNAs_obs[ele])[0]
            for i in sorted(rRNAs_obs[ele]):
                if i[0] <= saved[-1]:
                    saved[-1] = max(saved[-1], i[-1])
                else:
                    rRNAs_merged[ele].append(tuple(saved))
                    saved[0] = i[0]
                    saved[1] = i[1]
            rRNAs_merged[ele].append(tuple(saved))
        except:
            rRNAs_merged[ele] = [0, 0]

    # calculate total length based on merged intervals
    # The name of the file is: MGYGXX.tblout.deoverlapped#
    # and the name we need is the MGYGXX
    run_name = os.path.basename(args.input).split(".")[0]

    for rna in rRNAs_merged.keys():
        totalLen = 0
        for interval in rRNAs_merged[rna]:
            try:
                totalLen += interval[1] - interval[0]
            except:
                totalLen = 0
        print(
            "%s\t%s\t%.2f" % (run_name, rna, float(totalLen) / rRNAs_exp[rna] * 100)
        )
