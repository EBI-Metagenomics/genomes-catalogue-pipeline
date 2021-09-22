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
from shutil import copy

def getClusters(clst_file):
    clusters = {}
    with open(clst_file) as f:
        next(f)
        for line in f:
            line = line.rstrip()
            cols = line.split(",")
            cluster = cols[1]
            genome = cols[0]
            if cluster not in clusters:
                clusters[cluster] = [genome]
            else:
                clusters[cluster].append(genome)
    return clusters

def splitMash(mash_dist, genlist, outdir, cluster_name):
    outname = "%s/%s/%s_mash.tsv" % (outdir, cluster_name, cluster_name)
    with open(mash_dist, "r") as f, open(outname, "w") as fout:
        linen = 0
        for line in f:
            linen += 1
            line = line.rstrip()
            if linen == 1:
                fout.write("%s\n" % (line))
            else:
                cols = line.split(",")
                if cols[0] in genlist and cols[1] in genlist:
                    fout.write("%s\n" % (line))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Split dRep results by species cluster")
    #parser.add_argument('-d', dest='drep_folder', help='dRep output folder [REQUIRED]', required=True)
    parser.add_argument('-f', dest='fasta_folder', help='FASTA folder [REQUIRED]', required=True)
    parser.add_argument('-o', dest='output_folder', help='Output folder [REQUIRED]', required=True)
    parser.add_argument('--cdb', dest='cdb', help='dRep output folder/data_tables/Cdb.csv', required=True)
    parser.add_argument('--mdb', dest='mdb', help='dRep output folder/data_tables/Mdb.csv', required=True)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()
        clusters = getClusters(clst_file=args.cdb)
        for c in clusters:
            genomes = clusters[c]
            cluster_output = "%s/%s" % (args.output_folder, c)
            if not os.path.isdir(cluster_output):
                os.makedirs(cluster_output)
            for genome in genomes:
                src = "%s/%s" % (os.path.abspath(args.fasta_folder), genome)
                dst = "%s/%s" % (cluster_output, genome)
                copy(src, dst)
            splitMash(mash_dist=args.mdb, genlist=genomes, outdir=args.output_folder, cluster_name=c)
                
