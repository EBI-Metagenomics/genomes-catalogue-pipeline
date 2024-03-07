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
import argparse


rRNAs_exp = {"5S_rRNA": 119, "SSU_rRNA_bacteria": 1533, "LSU_rRNA_bacteria": 2925}
rRNAs_obs = {"5S_rRNA": [], "SSU_rRNA_bacteria": [], "LSU_rRNA_bacteria": []}
rRNAs_merged = {}


def get_tblout_column_indices(tool):
    cmsearch_indices = {
        "gene": 2,
        "start": 5,
        "end": 6,
    }
    cmscan_indices = {
        "gene": 1,
        "start": 7,
        "end": 8,
    }
    if tool == "cmsearch":
        return cmsearch_indices
    else:
        return cmscan_indices


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script detects bacretia rRNA")
    parser.add_argument(
        "-i", "--input", dest="input", help="rrna.tblout.deoverlapped", required=True
    )
    parser.add_argument(
        "-s", "--source", dest="source", help="Program that generated the tblout file", 
        choices=['cmsearch', 'cmscan'], required=False, default="cmsearch"
    )
    parser.add_argument(
        "-o", "--outfile", dest="outfile", help="Path to file where the output will be saved to", 
        required=False
    )

    args = parser.parse_args()

    idx = get_tblout_column_indices(args.source)
    
    # store start and end position of each hit
    with open(args.input, "r") as f:
        for line in f:
            if line.startswith("#"):
                continue
            cols = line.split()
            rfam = cols[idx["gene"]]
            if rfam not in rRNAs_exp:
                continue
            rfam_start = int(cols[idx["start"]])
            rfam_end = int(cols[idx["end"]])
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
    # and the name we need is the MGYGXX (or a different style genome accession)
    run_name = os.path.basename(args.input).split(".")[0]
    
    if args.outfile:
        file_out = open(args.outfile, "w")
    for rna in rRNAs_merged.keys():
        totalLen = 0
        for interval in rRNAs_merged[rna]:
            try:
                totalLen += interval[1] - interval[0]
            except:
                totalLen = 0
        new_line = "{}\t{}\t{:.2f}\n".format(run_name, rna, float(totalLen) / rRNAs_exp[rna] * 100)
        if args.outfile:
            file_out.write(new_line)
        else:
            print(new_line)
    if args.outfile:
        file_out.close()
