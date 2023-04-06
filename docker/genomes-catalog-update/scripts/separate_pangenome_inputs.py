#!/usr/bin/env python3
# coding=utf-8

import argparse
import os
import sys
import shutil


def main(new_strain_clusters_file, metadata_table, outfile, make_folders, outdir, strains_dir, existing_panaroo_dir,
         existing_species_rep_dir):
    # get a list of existing species reps that already have a pan-genome
    existing_pangenomes = load_metadata(metadata_table)
    # separate new strains into categories
    new_pangenomes, add_one_to_pangenome, add_several_to_pangenome = \
        process_strains(new_strain_clusters_file, existing_pangenomes)
    # print results to a file for records
    generate_outfile(new_pangenomes, add_one_to_pangenome, add_several_to_pangenome, outfile)
    # move files into folders to prepare for pan-genome generation
    if make_folders:
        generate_folders(outdir, new_pangenomes, add_one_to_pangenome, add_several_to_pangenome, strains_dir,
                         existing_panaroo_dir, existing_species_rep_dir)


def generate_folders(outdir, new_pangenomes, add_one_to_pangenome, add_several_to_pangenome, strains_dir,
                     existing_panaroo_dir, existing_species_rep_dir):
    if not os.path.exists(outdir):
        os.makedirs(outdir)
    new_pangenomes_dir = os.path.join(outdir, "New_pangenomes")
    add_one_dir = os.path.join(outdir, "Pangenomes_add_one")
    add_several_dir = os.path.join(outdir, "Pangenomes_add_several")
    for d in [new_pangenomes_dir, add_one_dir, add_several_dir]:
        if not os.path.exists(d):
            os.makedirs(d)
    put_together_new_pangenomes(new_pangenomes, new_pangenomes_dir, strains_dir, existing_species_rep_dir)
    put_together_pangenomes_to_amend(add_one_to_pangenome, add_one_dir, strains_dir, existing_panaroo_dir)
    put_together_pangenomes_to_amend(add_several_to_pangenome, add_several_dir, strains_dir, existing_panaroo_dir)


def put_together_pangenomes_to_amend(results_dict, dir_to_save_to, strains_dir, existing_panaroo_dir):
    for rep, genomes in results_dict.items():
        output_dir = os.path.join(dir_to_save_to, rep)
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
        new_genomes_dir = os.path.join(output_dir, "Genomes_to_add")
        if not os.path.exists(new_genomes_dir):
            os.makedirs(new_genomes_dir)
        for genome in genomes:
            shutil.copy(os.path.join(strains_dir, "{}.fna".format(genome)),
                        os.path.join(new_genomes_dir, "{}.fna".format(genome)))
        shutil.copytree(os.path.join(existing_panaroo_dir, "{}_panaroo".format(rep)),
                    os.path.join(output_dir, "{}_panaroo".format(rep)))


def put_together_new_pangenomes(new_pangenomes, new_pangenomes_dir, strains_dir, existing_species_rep_dir):
    for rep, genomes in new_pangenomes.items():
        output_dir = os.path.join(new_pangenomes_dir, rep)
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
        # copy the species rep from the old catalogue version
        shutil.copy(os.path.join(existing_species_rep_dir, "{}.fna".format(rep)),
                    os.path.join(output_dir, "{}.fna".format(rep)))
        # copy the new strains
        for genome in genomes:
            shutil.copy(os.path.join(strains_dir, "{}.fna".format(genome)),
                        os.path.join(output_dir, "{}.fna".format(genome)))


def generate_outfile(new_pangenomes, add_one_to_pangenome, add_several_to_pangenome, outfile):
    with open(outfile, "w") as file_out:
        for k, v in new_pangenomes.items():
            file_out.write("new_pangenome:{}.fna,{}.fna\n".format(k, ".fna,".join(v)))
        for k, v in add_one_to_pangenome.items():
            file_out.write("add_one:{}.fna,{}.fna\n".format(k, ".fna,".join(v)))
        for k, v in add_several_to_pangenome.items():
            file_out.write("add_several:{}.fna,{}.fna\n".format(k, ".fna,".join(v)))


def process_strains(clusters_file, existing_pangenomes):
    clusters = dict()
    with open(clusters_file, "r") as file_in:
        for line in file_in:
            species_rep, new_genome = line.strip().replace(".fna", "").split("\t")
            clusters.setdefault(species_rep, list()).append(new_genome)
    new_pangenomes = {k: v for k, v in clusters.items() if k not in existing_pangenomes}
    add_one_to_pangenome = {k: v for k, v in clusters.items() if len(v) == 1 and k in existing_pangenomes}
    add_several_to_pangenome = {k: v for k, v in clusters.items() if len(v) > 1 and k in existing_pangenomes}
    return new_pangenomes, add_one_to_pangenome, add_several_to_pangenome


def load_metadata(metadata_table):
    counter = dict()
    with open(metadata_table, "r") as file_in:
        header_fields = file_in.readline().strip().split("\t")
        species_rep_index = header_fields.index("Species_rep")
        for line in file_in:
            fields = line.strip().split("\t")
            counter.setdefault(fields[species_rep_index], 0)
            counter[fields[species_rep_index]] += 1
    return {k for k, v in counter.items() if v != 1}


def parse_args():
    parser = argparse.ArgumentParser(description='The script separates new strains into categories based'
                                                 'on what needs to be done to generate pan-genomes:'
                                                 '- new strain (adding to singleton) - generate pan-genome from scratch'
                                                 '- new strain (multiple new strains) - generate pan-genome'
                                                 'for the new strains, then add to existing'
                                                 '- new strain (single strain) - add new strain to existing'
                                                 'pan-genome')
    parser.add_argument('--new-strain-clusters', required=True,
                        help='Path to the replace_species_reps_result.clusters.txt file.')
    parser.add_argument('-m', '--metadata-table', required=True,
                        help='Path to the metadata table from the previous catalogue version.')
    parser.add_argument('-o', '--outfile', required=True,
                        help='Path to the outfile where the splitting will be recorded')
    parser.add_argument('--make-folders', action='store_true',
                        help='If this flag is used, the script will also create a folder with files for pan-genomes.'
                             'Parameters --outdir, path to existing pan-genomes and path to strains directory'
                             'are required if flag is used.')
    parser.add_argument('--outdir', required=False,
                        help='Path to the folder where genomes for pan-genome generation should be saved to.'
                             'Required if --make-folders is used.')
    parser.add_argument('--strains-dir', required=False,
                        help='Folder where genomes for new strains can be taken from.'
                             'Required if --make-folders is used.')
    parser.add_argument('--existing-panaroo-dir', required=False,
                        help='Folder where panaroo outputs for existing pangenomes can be taken from.'
                             'Required if --make-folders is used.')
    parser.add_argument('--existing-species-rep-dir', required=False,
                        help='Folder with species rep fastas for previous catalogue version.'
                             'Required if --make-folders is used.')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    if args.make_folders:
        if not all([args.outdir, args.strains_dir, args.existing_panaroo_dir, args.existing_species_rep_dir]):
            sys.exit("If the --make-folders flag is used, --outdir, --strains-dir, --existing-panaroo-dir "
                     "and --existing-species-rep-dir parameters are required.")

    main(args.new_strain_clusters, args.metadata_table, args.outfile, args.make_folders, args.outdir,
         args.strains_dir, args.existing_panaroo_dir, args.existing_species_rep_dir)