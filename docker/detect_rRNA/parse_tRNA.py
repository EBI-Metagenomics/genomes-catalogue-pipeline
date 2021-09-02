#!/usr/bin/env python

import sys
import os


if len(sys.argv) < 2:
    print("ERROR! usage: python script.py trnas_stats.out")
    sys.exit()


aa = ["Ala", "Gly", "Pro", "Thr", "Val", "Ser",
      "Arg", "Leu", "Phe", "Asn", "Lys", "Asp",
      "Glu", "His", "Gln", "Ile", "Tyr",
      "Cys", "Trp"]

with open(sys.argv[1], "r") as f:
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

print("{name}\t{trnas}".format(name=os.path.basename(sys.argv[1]).split("_stats")[0], trnas=trnas))
