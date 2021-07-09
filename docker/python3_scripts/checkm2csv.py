#!/usr/bin/env python

import sys

if len(sys.argv) < 2:
    print("usage: script.py checkm_results.tab")
    sys.exit(1)

print("genome,completeness,contamination,strain_heterogeneity")

with open(sys.argv[1], "r") as f:
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