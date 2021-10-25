#!/usr/bin/env python3

import os
import argparse
from argparse import RawTextHelpFormatter
import sys


def getIPRs(IPRannot):
    iprs = {}
    with open(IPRannot, "r") as f:
        for line in f:
            line = line.rstrip()
            cols = line.split("\t")
            protein = cols[0]
            if protein not in iprs:
                iprs[protein] = [set(),set()]
            if cols[3] == "Pfam":
                pfam = cols[4]
                iprs[protein][0].add(pfam)
            if len(cols) > 12:
                ipr = cols[11]
                iprs[protein][1].add(ipr)
    return iprs


def getEggNog(eggNOGannot):
    eggnogs = {}
    with open(eggNOGannot, "r") as f:
        for line in f:
            line = line.rstrip()
            cols = line.split("\t")
            if line[0] != "#":
                protein = cols[0]
                eggnog = [cols[1]]
                try:
                    cog = cols[20]
                    cog = cog.split()
                    if len(cog) > 1:
                        cog = ["R"]
                except:
                    cog = ["NA"]
                kegg = cols[8].split(",")
                eggnogs[protein] = [eggnog, cog, kegg]
    return eggnogs


def addGff(inGff, eggNOGfile, IPRfile):
    eggnogs = getEggNog(eggNOGfile)
    iprs = getIPRs(IPRfile)
    added_annot = {}
    outGff = []
    with open(inGff, "r") as f:
        for line in f:
            line = line.strip()
            if line[0] != "#":
                cols = line.split("\t")
                if len(cols) == 9:
                    annot = cols[8]
                    protein = annot.split(";")[0].split("=")[-1]
                    added_annot[protein] = {}
                    try:
                        eggnogs[protein]
                        pos = 0
                        for a in eggnogs[protein]:
                            pos += 1
                            if a != [""] and a != ["NA"]:
                                if pos == 1:
                                    added_annot[protein]['eggNOG'] = a
                                elif pos == 2:
                                    added_annot[protein]['COG'] = a
                                elif pos == 3:
                                    added_annot[protein]['KEGG'] = a
                    except:
                        pass
                    try:
                        iprs[protein]
                        pos = 0
                        for a in iprs[protein]:
                            pos += 1
                            a = list(a)
                            if a != [""] and a:
                                if pos == 1:
                                    added_annot[protein]['Pfam'] = a
                                elif pos == 2:
                                    added_annot[protein]['InterPro'] = a
                    except:
                        pass
                    for a in added_annot[protein]:
                        value = added_annot[protein][a]
                        if type(value) is list:
                            value = ",".join(value)
                        cols[8] = "%s;%s=%s" % (cols[8], a, value)
                    line = "\t".join(cols)
            outGff.append(line)
    return outGff


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='''
    Add functional annotation to GFF file''', formatter_class=RawTextHelpFormatter)
    parser.add_argument('-g', dest='gff', help='Input GFF file [REQUIRED]', required=True)
    parser.add_argument('-e', dest='eggnog', help='eggNOG TSV file [REQUIRED]', required=True)
    parser.add_argument('-i', dest='interpro', help='InterProScan TSV file [REQUIRED]', required=True)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()
        res = addGff(args.gff, args.eggnog, args.interpro)
        outName = args.gff.split(".gff")[0]+"_annotated.gff"
        with open(outName, "w") as fout:
            fout.write("\n".join(res))
