#!/usr/bin/env python

import os
import sys
import argparse

def getClusters(drep_out):
    clusters = {}
    clst_file = "%s/data_tables/Cdb.csv" % (drep_out)
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

def splitMash(drep_out, genlist, outdir, cluster_name):
    mash_dist = "%s/data_tables/Mdb.csv" % (drep_out)
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
    parser.add_argument('-d', dest='drep_folder', help='dRep output folder [REQUIRED]', required=True)
    parser.add_argument('-f', dest='fasta_folder', help='FASTA folder [REQUIRED]', required=True)
    parser.add_argument('-o', dest='output_folder', help='Output folder [REQUIRED]', required=True)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()
        clusters = getClusters(args.drep_folder)
        for c in clusters:
            genomes = clusters[c]
            cluster_output = "%s/%s" % (args.output_folder, c)
            if not os.path.isdir(cluster_output):
                os.makedirs(cluster_output)
            for genome in genomes:
                src = "%s/%s" % (os.path.abspath(args.fasta_folder), genome)
                dst = "%s/%s" % (cluster_output, genome)
                os.symlink(src, dst)
            splitMash(args.drep_folder, genomes, args.output_folder, c)
                
