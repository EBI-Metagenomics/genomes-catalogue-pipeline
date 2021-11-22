#!/usr/bin/env python3

import os
import sys
import argparse
from argparse import RawTextHelpFormatter
from shutil import copy

def create_folder(name, dir, kegg_files, index, gff, annotations=None):
    genome_folder = os.path.join(args.name, 'genome')
    if not os.path.exists(genome_folder):


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='''Script to create final genome folder
    Input:
      - directory with files: fna, prokka.gff, faa, (panaroo.fna, core_genes.txt, genes_presence-absence.tsv, mash.nwk) 
      - fna.fai
      - annotation_coverage.tsv
      - cog_summary.tsv
      - kegg_classes.tsv
      - kegg_modules.tsv
      - IPS, EggNOG
      - annotated gff
      - genome.json
      Output:
        genome.json
        genome:
          - fna, faa, fna.fai, gff (annotated)
          - annotation_coverage.tsv, cog_summary.tsv, kegg_classes.tsv, kegg_modules.tsv
          - IPS, EggNOG
        pan-genome:
          - panaroo.fna, core_genes.txt, genes_presence-absence.tsv, mash.nwk
      ''', formatter_class=RawTextHelpFormatter)
    parser.add_argument('-i', dest='input_dir', required=True,
                        help='Directory with protein.fasta, fna, gff (IPS, Eggnog if -a is not presented')
    parser.add_argument('-a', dest='annotations', help='IPS and EggNOG files', required=False, nargs='+')
    parser.add_argument('-k', dest='kegg_files', help='KEGG annotation files', required=True)
    parser.add_argument('--index', dest='index', help='fna.fai', required=True)
    parser.add_argument('-g', dest='annotated_gff', help='Annotated gff', required=True)
    parser.add_argument('-j', dest='json', help='genome.json', required=True)
    parser.add_argument('-n', dest='name', help='MGYG accession', required=True)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()

        # create main folder
        if not os.path.exists(args.name):
            os.mkdir(args.name)
        copy(args.json, os.path.join(args.name, os.path.basename(args.json)))

        # create genome and pan-genome folder
        create_folder(name=args.name, dir=args.input_dir, kegg_files=args.kegg_files, index=args.index,
                      gff=args.annotated_gff, annotations=args.annotations)