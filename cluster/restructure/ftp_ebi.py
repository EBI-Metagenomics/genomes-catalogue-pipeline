# !/usr/bin/env python3
import argparse
import sys
import os
from shutil import copy
from distutils.dir_util import copy_tree

"""
name/v1.0/all_genomes                               [FTP]
    --- MGYG0002960 [7 dig]
         ----- MGYG000296009 [9 dig]
                ----- genomes1 [up to 500 genomes]
                        ------- MGYG000296009.gff.gz
                        ...
                        ------- cluster gff.gz
                ----- genomes2 [up to 500 genomes]
         ----- MGYG[9]
                ----- genomes1
                        ------- MGYG[12].gff.gz
                        ... ...
         ...
    --- MGYG[7]
    ...
genomes-all_metadata.tsv                            [FTP]
README.txt                                          [FTP] ??????  
species_catalogue
    --- phylo_tree.json                             [Web]
    --- 000
         ----- 00001
                ----- genome.json
                ----- genome
                        +----- annotation_coverage.tsv
                        +----- cog_summary.tsv
                        +----- kegg_classes.tsv
                        +----- kegg_modules.tsv
                        +---- MGYG-HGUT-00001_eggNOG.tsv
                        +---- MGYG-HGUT-00001_InterProScan.tsv
                        +---- MGYG-HGUT-00001.faa          ( prokka )
                        +---- MGYG-HGUT-00001.gff          ( prokka - make a file with link)
                        +---- MGYG-HGUT-00001.fna
                        ----- MGYG-HGUT-00001.fna.fai
                ----- pan-genome
                        +---- core_genes.faa               ( ready - core_genes.txt )
                        +---- genes_presence-absence.tsv   ( ready - panaroo - gene_presence_absence.Rtab )
                        +---- mashtree.nwk                 ( ready )
                        +---- pan-genome.fna               ( ready - panaroo - pan_genome_reference.fa)

protein_catalogue  (mmseqs)                            [FTP]
    --- protein_catalogue-100.tar.gz                          
    --- protein_catalogue-50.tar.gz
    --- protein_catalogue-90.tar.gz
       - protein_catalogue-90_InterProScan.tsv
       - protein_catalogue-90_eggNOG.tsv
       name of files...
    --- protein_catalogue-95.tar.gz
    
panaroo_output  ??????
gtdb-tk_output.tar.gz
rRNA           ???    (fastas)  
intermediate_files ???
  - mgyg_stats.csv                        
  - naming_table 
  - additional_weights_file 
  - Sdb.csv
  - split_clusters.txt
  - singletons_gunc_failed
   
==================================================================================
   
pipeline_output:
--- intermediate_files/                  [not for FTP]

--- GFF/
    --- *.gff.gz
    
--- panaroo_output/
    --- MGYG*.panaroo.tar.gz

--- mmseqs_output/
    --- mmseqs_1.0_outdir.tar.gz                           
    --- mmseqs_0.5_outdir.tar.gz
    --- mmseqs_0.9_outdir.tar.gz
    --- mmseqs_0.95_outdir.tar.gz
    
--- MGYGXXXXXXXXX/
    --- genome/
        ...
    --- pan-genome/
        ...
    --- MGYG*.json
    
--- MGYGXXXXXXXXX/
    --- genome/
        ...
    --- pan-genome/
        ...
    --- MGYG*.json
"""

PROTEIN_CATALOGUE_FOLDER_NAME = "protein_catalogue"  # mmseqs
ALL_CATALOGUE_FOLDER_NAME = "species_catalogue"
GFF_FOLDER_NAME = "all_genomes"
LIMIT_GFF_FOLDER = 500
INITIAL_GFF_NAME = 'GFF'
NUMBER_OF_SYMBOLS = 11

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Copy files to correct structure FTP')
    parser.add_argument('--output-location', dest='output', help='Path to FTP folder', required=False, default='.')
    parser.add_argument('--catalogue-version', dest='version', help='Catalogue version (ex. v1.0)', required=True)
    parser.add_argument('--catalogue-name', dest='name', help='Catalogue name (ex. marine)', required=True)
    parser.add_argument('--split-clusters', dest='split_clusters',
                        help='File from drep subwf named split_clusters.txt', required=True)
    parser.add_argument('--result-path', dest='result_path',
                        help='Path to pipeline output', required=True)

    parser.add_argument('--mmseqs-path', dest='mmseqs_path',
                        help='Path to pipeline mmseqs folder', required=False)
    parser.add_argument('--many-folder', dest='many_folder',
                        help='Path to pipeline many folder', required=False)

    parser.add_argument('--type', dest='type', required=True,
                        help='1: gff, '
                             '2: panaroo, '
                             '3: mmseqs, '
                             '4: genome and pan-genome')
    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true')
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()

        # dict for clusters
        clusters = {}
        with open(args.split_clusters, 'r') as file_in:
            for line in file_in:
                genomes = line.strip().split(':')[2].split(',')
                main_rep = genomes[0].split('.')[0]
                if len(genomes) >= 1:
                    clusters[main_rep] = [i.split('.')[0] for i in genomes]
                else:
                    print('error in clusters_split')
                    exit(1)

        # create main dir name/v1.0/
        ftp_path = os.path.join(args.output, args.name, args.version)
        if not os.path.exists(ftp_path):
            os.makedirs(ftp_path)

        # README ???

        if '1' in args.type:
            # GFFs
            all_genomes_path = os.path.join(ftp_path, GFF_FOLDER_NAME)
            if not os.path.exists(all_genomes_path):
                os.makedirs(all_genomes_path)
            for genome in clusters:
                genomes = clusters[genome]
                gff_genome_path = os.path.join(all_genomes_path, genome[:NUMBER_OF_SYMBOLS], genome)
                if not os.path.exists(gff_genome_path):
                    os.makedirs(gff_genome_path)
                for i in range(0, len(genomes)):
                    folder_index = int(i // LIMIT_GFF_FOLDER) + 1
                    folder_name = 'genomes' + str(folder_index)
                    new_path = os.path.join(gff_genome_path, folder_name)
                    if not os.path.exists(new_path):
                        os.makedirs(new_path)
                    old_path = os.path.join(args.result_path, INITIAL_GFF_NAME, genomes[i] + '.gff.gz')
                    print('from ' + old_path)
                    print('to ' + new_path)
                    if not args.verbose:
                        copy(old_path, os.path.join(new_path, genomes[i] + '.gff.gz'))

        if '2' in args.type:  # TODO change
            # panaroo
            with open(args.split_clusters, 'r') as file_in:
                for line in file_in:
                    line = line.strip().split(':')
                    if line[0] == 'many_genomes':
                        cluster = line[1]
                        main_genome = line[2].split(',')[0].split('.')[0]
                        old_path = os.path.join(args.many_folder, 'cluster_' + cluster, 'panaroo_output')
                        new_path = os.path.join(ftp_path, 'panaroo_output', main_genome + '_panaroo')
                        print('from ' + old_path)
                        print('to ' + new_path)
                        if not args.verbose:
                            copy_tree(old_path, new_path)

        if '3' in args.type:
            # protein catalogue (uhgp_catalogue)
            protein_catalogue_path = os.path.join(ftp_path, PROTEIN_CATALOGUE_FOLDER_NAME)
            if not os.path.exists(protein_catalogue_path):
                os.makedirs(protein_catalogue_path)
            old_mmseq = args.mmseqs_path if args.mmseqs_path else os.path.join(args.result_path, 'mmseqs_output')
            mmseqs = os.listdir(old_mmseq)
            for mmseq in mmseqs:
                percentage = int(float(mmseq.split('_')[1]) * 100)
                new_name = 'protein_catalogue-' + str(percentage) + '.tar.gz'
                print('from ' + os.path.join(old_mmseq, mmseq))
                print('to ' + os.path.join(protein_catalogue_path, new_name))
                if not args.verbose:
                    copy(os.path.join(old_mmseq, mmseq), os.path.join(protein_catalogue_path, new_name))

        if '4' in args.type:
            # uhgg_catalogue
            genomes_catalogue = os.path.join(ftp_path, ALL_CATALOGUE_FOLDER_NAME)
            if not os.path.exists(genomes_catalogue):
                os.makedirs(genomes_catalogue)
            for genome in clusters:
                genomes = clusters[genome]
                genome_path = os.path.join(genomes_catalogue, genome[:NUMBER_OF_SYMBOLS], genome)
                if not os.path.exists(genome_path):
                    os.makedirs(genome_path)
                old_path = os.path.join(args.result_path, genome)
                print('from ' + old_path)
                print('to ' + genome_path)
                if not args.verbose:
                    copy_tree(old_path, genome_path)

            # metadata
            metadata = [i for i in os.listdir(args.result_path) if 'metadata' in i][0]
            print('from ' + os.path.join(args.result_path, metadata))
            print('to ' + os.path.join(ftp_path, 'genomes-all_metadata.tsv'))
            if not args.verbose:
                copy(os.path.join(args.result_path, metadata), os.path.join(ftp_path, 'genomes-all_metadata.tsv'))
