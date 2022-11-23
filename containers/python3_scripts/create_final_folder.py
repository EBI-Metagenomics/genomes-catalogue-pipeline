#!/usr/bin/env python3

import os
import sys
import argparse
from argparse import RawTextHelpFormatter
from shutil import copy


def create_folder(name, dir, kegg_files, index, gff, annotations=None):
    genome_folder = os.path.join(name, 'genome')
    if not os.path.exists(genome_folder):
        os.mkdir(genome_folder)
    # move kegg
    for kegg in kegg_files:
        copy(kegg, os.path.join(genome_folder, os.path.basename(kegg)))
    # move index
    copy(index, os.path.join(genome_folder, os.path.basename(index)))
    # move gff
    copy(gff, os.path.join(genome_folder, os.path.basename(gff)))

    # move IPS and eggNOG
    input_files = os.listdir(dir)
    if annotations:
        annotations_list = annotations
    else:
        # search in input directory
        annotations_list = input_files
    eggnog_name = [cur_file for cur_file in annotations_list if cur_file.endswith('eggNOG.tsv')][0]
    eggnog_results = eggnog_name if args.annotations else os.path.join(dir, eggnog_name)
    ips_name = [cur_file for cur_file in annotations_list if cur_file.endswith('InterProScan.tsv')][0]
    ipr_results = ips_name if args.annotations else os.path.join(dir, ips_name)
    copy(eggnog_results, os.path.join(genome_folder, os.path.basename(eggnog_results)))
    copy(ipr_results, os.path.join(genome_folder, os.path.basename(ipr_results)))

    # fna, faa, gff
    fna = [cur_file for cur_file in input_files if cur_file.endswith(name + '.fna')][0]
    faa = [cur_file for cur_file in input_files if cur_file.endswith(name + '.faa')][0]
    #prokka_gff = [cur_file for cur_file in input_files if cur_file.endswith('.gff')][0]
    copy(os.path.join(dir, fna), os.path.join(genome_folder, fna))
    copy(os.path.join(dir, faa), os.path.join(genome_folder, faa))

    core_genes = [cur_file for cur_file in input_files if len(cur_file.split('core_genes.txt')) > 1]
    mash = [cur_file for cur_file in input_files if len(cur_file.split('.nwk')) > 1]
    gene_presence_absence = [cur_file for cur_file in input_files if len(cur_file.split('gene_presence_absence.Rtab')) > 1]
    pan_genome_reference = [cur_file for cur_file in input_files if len(cur_file.split('pan-genome.fna')) > 1]

    if len(core_genes) > 0 or len(mash) > 0 or len(gene_presence_absence) > 0 or len(pan_genome_reference) > 0:
        print('Create pan-genome folder')
        pangenome_folder = os.path.join(name, 'pan-genome')
        if not os.path.exists(pangenome_folder):
            os.mkdir(pangenome_folder)
        if len(core_genes) > 0:
            copy(os.path.join(dir, core_genes[0]), os.path.join(pangenome_folder, core_genes[0]))
        else:
            print('no core_genes')
        if len(mash) > 0:
            copy(os.path.join(dir, mash[0]), os.path.join(pangenome_folder, mash[0]))
        else:
            print('no mash')
        if len(gene_presence_absence) > 0:
            copy(os.path.join(dir, gene_presence_absence[0]), os.path.join(pangenome_folder, gene_presence_absence[0]))
        else:
            print('no gene_presence_absence')
        if len(pan_genome_reference) > 0:
            copy(os.path.join(dir, pan_genome_reference[0]), os.path.join(pangenome_folder, pan_genome_reference[0]))
        else:
            print('no pan_genome_reference')
    else:
        print('No pan-genome folder')


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
    parser.add_argument('-k', dest='kegg_files', help='KEGG annotation files', required=True, nargs='+')
    parser.add_argument('--index', dest='index', help='fna.fai', required=True)
    parser.add_argument('-g', dest='annotated_gff', help='Annotated gff', required=True)
    parser.add_argument('-j', dest='json', help='genome.json', required=False)
    parser.add_argument('-n', dest='name', help='MGYG accession', required=True)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()

        # create main folder
        if not os.path.exists(args.name):
            os.mkdir(args.name)
        if args.json:
            copy(args.json, os.path.join(args.name, os.path.basename(args.json)))

        # create genome and pan-genome folder
        create_folder(name=args.name, dir=args.input_dir, kegg_files=args.kegg_files, index=args.index,
                      gff=args.annotated_gff, annotations=args.annotations)