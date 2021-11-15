#!/usr/bin/env python3
import argparse
import sys
import os
from shutil import copy

"""
all_genomes
    --- 000
         ----- 00001
                ----- genomes1
                        ------- GUT_GENOME000001.gff.gz
                        ...
                        ------- GUT_GENOME091053.gff.gz
         ----- 00002
                ----- genomes1
                        ------- GUT_GENOME000002.gff.gz
                        ... ...
                        ------- GUT_GENOME091054.gff.gz
         ...
    --- 001
    ...
genomes-all_metadata.tsv  (script is not ready)
README.txt                (script is not ready)
uhgg_catalogue
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
uhgp_catalogue  (mmseqs)
    --- mmseqs_1.0_outdir.tar.gz                           ( was uhgp-100.tar.gz)
    --- mmseqs_0.5_outdir.tar.gz
    --- mmseqs_0.9_outdir.tar.gz
    --- mmseqs_0.95_outdir.tar.gz
"""



# /nfs/production/rdf/metagenomics/pipelines/dev/genomes-pipeline/RESULTS/marine/clusters/clusters_split.txt


CORE_GENES_NAME = 'core_genes.txt'
GENE_PRESENCE_NAME = "gene_presence_absence.Rtab"
PAN_GENOME_FA = "pan_genome_reference.fa"
IPS_POSTFIX = "_InterProScan.tsv"
EGGNOG_POSTFIX = "_eggNOG.tsv"

VERSION = '1.0'

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Copy files to correct structure')
    parser.add_argument('--output', dest='output', help='Path to output', required=False)
    parser.add_argument('--sdb', dest='sdb', help='File with main reps scores', required=False)
    parser.add_argument('--split-clusters', dest='split_clusters', help='File with main reps scores', required=True)
    parser.add_argument('--folder-many', dest='folder_many', help='Folder output for pangenomes', required=True)
    parser.add_argument('--folder-mash', dest='mash_trees', help='Folder output for mash_trees nwk', required=True)
    parser.add_argument('--folder-one', dest='folder_one', help='Folder output for singletons', required=True)
    parser.add_argument('--folder-per-genome', dest='folder_per_genome',
                        help='Folder output for per-genome annotations with IPS and Eggnog', required=True)
    parser.add_argument('--folder-kegg', dest='folder_kegg',
                        help='Folder output for KEGG annotations', required=False)
    parser.add_argument('--folder-annotated-gff', dest='folder_annotated_gff',
                        help='Folder output for annotated GFF', required=False)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()
        out_dir = os.path.join(args.output, VERSION)
        if not os.path.exists(out_dir):
            os.mkdir(out_dir)
        main_reps_clusters = {}
        with open(args.split_clusters, 'r') as file_in:
            for line in file_in:
                type = line.strip().split(':')[0]
                cluster_id = line.strip().split(':')[1]
                name = line.strip().split(':')[2].split(',')[0].split('.')[0]
                print('----> ' + name)
                main_reps_clusters[cluster_id] = name

                genome_folder_path = os.path.join(out_dir, name, 'genome')

                if not os.path.exists(os.path.join(out_dir, name)):
                    os.makedirs(genome_folder_path, exist_ok=True)

                # IPS + EggNOG
                ips_old = os.path.join(args.folder_per_genome, name + IPS_POSTFIX)
                ips_new = os.path.join(genome_folder_path, name + IPS_POSTFIX)
                copy(ips_old, ips_new)
                eggnog_old = os.path.join(args.folder_per_genome, name + EGGNOG_POSTFIX)
                eggnog_new = os.path.join(genome_folder_path, name + EGGNOG_POSTFIX)
                copy(eggnog_old, eggnog_new)

                if type == 'one_genome':
                    # FAA
                    faa_old = os.path.join(args.folder_one, 'cluster_' + cluster_id, 'prokka_output', name + '.faa')
                    faa_new = os.path.join(genome_folder_path, name + '.faa')
                    copy(faa_old, faa_new)
                    # GFF
                    gff_old = os.path.join(args.folder_one, 'cluster_' + cluster_id, 'prokka_output', name + '.gff')
                    gff_new = os.path.join(genome_folder_path, name + '.gff')
                    copy(gff_old, gff_new)
                    # FNA
                    fna_old = os.path.join(args.folder_one, 'cluster_' + cluster_id, 'prokka_output', name + '.fna')
                    fna_new = os.path.join(genome_folder_path, name + '.fna')
                    copy(fna_old, fna_new)

                # PAN_GENOME
                if type == 'many_genomes':
                    print('Many ' + cluster_id)
                    pangenome_folder_path = os.path.join(out_dir, name, 'pan-genome')
                    os.makedirs(pangenome_folder_path, exist_ok=True)

                    # FAA
                    faa_old = os.path.join(args.folder_many, 'cluster_' + cluster_id, 'prokka_output', name + '.faa')
                    faa_new = os.path.join(genome_folder_path, name + '.faa')
                    copy(faa_old, faa_new)
                    # GFF
                    gff_old = os.path.join(args.folder_many, 'cluster_' + cluster_id, 'prokka_output', name + '.gff')
                    gff_new = os.path.join(genome_folder_path, name + '.gff')
                    copy(gff_old, gff_new)
                    # FNA
                    fna_old = os.path.join(args.folder_many, 'cluster_' + cluster_id, 'prokka_output', name + '.fna')
                    fna_new = os.path.join(genome_folder_path, name + '.fna')
                    copy(fna_old, fna_new)

                    # core_genes
                    core_genes_old = os.path.join(args.folder_many, 'cluster_'+cluster_id, CORE_GENES_NAME)
                    core_genes_new = os.path.join(pangenome_folder_path, CORE_GENES_NAME)
                    copy(core_genes_old, core_genes_new)
                    # gene_presence_absence.Rtab
                    presence_old = os.path.join(args.folder_many, 'cluster_'+cluster_id, 'panaroo_output',
                                                GENE_PRESENCE_NAME)
                    presence_new = os.path.join(pangenome_folder_path, GENE_PRESENCE_NAME)
                    copy(presence_old, presence_new)
                    # mash.nwk
                    mash_old = os.path.join(args.mash_trees, cluster_id + '_mashtree.nwk')
                    mash_new = os.path.join(pangenome_folder_path, 'mashtree.nwk')
                    copy(mash_old, mash_new)
                    # pan-genome.fna
                    pg_fna_old = os.path.join(args.folder_many, 'cluster_'+cluster_id, 'panaroo_output',
                                              PAN_GENOME_FA)
                    pg_fna_new = os.path.join(pangenome_folder_path, 'pan-genome.fna')
                    copy(pg_fna_old, pg_fna_new)

                # KEGG
                if args.folder_kegg:
                    kegg_files = os.listdir(os.path.join(args.folder_kegg, name))
                    for kegg_file in kegg_files:
                        kegg_old = os.path.join(args.folder_kegg, name, kegg_file)
                        kegg_new = os.path.join(genome_folder_path, kegg_file)
                        copy(kegg_old, kegg_new)
                else:
                    print('Skipping kegg files')

                # Annotated GFF
                if args.folder_annotated_gff:
                    annotated_gff = os.path.join(args.folder_annotated_gff, name + '.gff')
                    annotated_gff_new = os.path.join(genome_folder_path, name + '.gff')
                    copy(annotated_gff, annotated_gff_new)
                else:
                    print('Skipping annotated gff files')