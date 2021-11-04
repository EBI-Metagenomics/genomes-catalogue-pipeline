#!/usr/bin/env python3

import os
import sys
import argparse
import glob
from argparse import RawTextHelpFormatter
import json

# static files
metadata_file = "/hps/nobackup2/production/metagenomics/databases/human-gut_resource/update_v2/genomes-all_metadata_v2.tsv"
counts_file = "/hps/nobackup2/production/metagenomics/databases/human-gut_resource/species_counts.tsv"

def get_metadata(species_name, coverage, fasta):
    biome = "root:Host-Associated:Human:Digestive System:Large intestine"
    cov = get_annotcov(coverage)
    num_proteins = get_cdscount(fasta)
    with open(metadata_file) as f:
        linen = 0
        geo_range = set()
        for line in f:
            linen += 1
            cols = line.rstrip().split("\t")
            mgnify = cols[17]
            species = cols[16]
            if mgnify == species_name:
                geo_range.add(cols[22])
                if species == cols[0]:
                    species_code = species
                    genome_set = cols[2]
                    genome_accession = cols[15]
                    sample_accession = cols[19]
                    study_accession = cols[20]
                    geo_origin = cols[22]
                    complet = float(cols[8])
                    cont = float(cols[9])
                    gtype = cols[3]
                    genome_length = int(cols[4])
                    n_contigs = int(cols[5])
                    n50 = int(cols[6])
                    gc_content = float(cols[7])
                    try:
                        cmseq = float(cols[10])
                    except:
                        cmseq = "NA"
                    tax_lineage = cols[18]
                    rna_5s = float(cols[11])
                    rna_16s = float(cols[12])
                    rna_23s = float(cols[13])
                    trnas = int(cols[14])
        geo_range = list(geo_range)
        try:
            geo_range.remove("NA")
        except:
            pass
        return geo_range, species_code, {
            'accession': species_name,
            'length': genome_length,
            'num_contigs': n_contigs,
            'n_50': n50,
            'gc_content': gc_content,
            'num_proteins': num_proteins,
            'taxon_lineage': tax_lineage,
            'gold_biome': biome,
            'genome_set': genome_set,
            'genome_accession': genome_accession,
            'sample_accession': sample_accession,
            'study_accession': study_accession,
            'type': gtype,
            'geographic_origin': geo_origin,
            'completeness': complet,
            'contamination': cont,
            'cmseq': cmseq,
            'eggnog_coverage': cov[-1],
            'ipr_coverage': cov[0],
            'rna_5s': rna_5s,
            'rna_16s': rna_16s,
            'rna_23s': rna_23s,
            'trnas': trnas
        }


def get_cdscount(fasta):
    cds = 0
    with open(fasta) as f:
        for line in f:
            if line[0] == ">":
                cds += 1
    return cds


def get_annotcov(annot):
    with open(annot) as f:
        linen = 0
        for line in f:
            linen += 1
            if linen > 1:
                cols = line.rstrip().split("\t")
                if cols[1] == "InterProScan":
                    ipr_cov = float(cols[-1])
                elif cols[1] == "eggNOG":
                    eggnog_cov = float(cols[-1])
    return ipr_cov, eggnog_cov


def get_pangenome(core, accessory, coverage, species_code):
    core_count = get_cdscount(core)
    access_count = get_cdscount(accessory)
    pangenome_size = core_count + access_count
    cov = get_annotcov(coverage)
    with open(counts_file) as f:
        linen = 0
        for line in f:
            linen += 1
            if linen > 1:
                cols = line.rstrip().split("\t")
                if cols[0] == species_code:
                    num_genomes_total = int(cols[1])
                    num_genomes_non_redundant = int(cols[2])
    return {
        'num_genomes_total': num_genomes_total,
        'num_genomes_non_redundant': num_genomes_non_redundant,
        'pangenome_size': pangenome_size,
        'pangenome_core_size': core_count,
        'pangenome_accessory_size': access_count,
        'pangenome_eggnog_coverage': cov[-1],
        'pangenome_ipr_coverage': cov[0]
    }


def get_ncrnas(gff):
    nc_rnas = 0
    with open(gff) as f:
        for line in f:
            line = line.rstrip()
            cols = line.split("\t")
            if cols[2] == "ncRNA":
                nc_rnas += 1
    return {
        'nc_rnas': nc_rnas
    }


def merge_dicts(*dict_args):
    result = {}
    for dictionary in dict_args:
        result.update(dictionary)
    return result


def write_obj_2_json(obj, filename):
    with open(filename, 'w') as fp:
        json.dump(obj, fp, indent=4, sort_keys=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='''
    Generate species summary stats 
    Input folder must contain
    - genome / annotation_coverage.tsv
    - genome / species_name.faa
    - genome / species_name.gff
    - pan - genome / annotation_coverage.tsv
    - pan - genome / core_genes.faa
    - pan - genome / accessory_genes.faa
    ''', formatter_class=RawTextHelpFormatter)
    parser.add_argument('-i', dest='in_folder', help='Input folder [REQUIRED]', required=True)
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()
        assembly_stats = glob.glob(os.path.join(args.in_folder, "genome/*stats"))[0]
        gen_cov = glob.glob(os.path.join(args.in_folder, "genome/*coverage.tsv"))[0]
        gen_cds = glob.glob(os.path.join(args.in_folder, "genome/*.faa"))[0]
        species_name = os.path.basename(gen_cds).split(".fa")[0]
        gff = "%s/%s.gff" % (glob.glob(os.path.join(args.in_folder, "genome/"))[0], species_name)

        meta_res = get_metadata(species_name, gen_cov, gen_cds)
        meta_dict = meta_res[-1]
        species_code = meta_res[1]
        # check genome accession
        if meta_dict['genome_set'] == "EBI":
            meta_dict['ena_genome_accession'] = meta_dict.pop('genome_accession')
        elif meta_dict['genome_set'] == "PATRIC/IMG" and meta_dict['genome_accession'].find(".") != -1:
            meta_dict['patric_genome_accession'] = meta_dict.pop('genome_accession')
        elif meta_dict['genome_set'] == "PATRIC/IMG" and meta_dict['genome_accession'].find(".") == -1:
            meta_dict['img_genome_accession'] = meta_dict.pop('genome_accession')
        elif meta_dict['genome_accession'][:3] in ["GCF","GCA"]:
            meta_dict['ncbi_genome_accession'] = meta_dict.pop('genome_accession')
        # check sample accessions
        if meta_dict['sample_accession'][:3] == "SAM":
            meta_dict['ncbi_sample_accession'] = meta_dict.pop('sample_accession')
        elif meta_dict['sample_accession'][1:3] == "RS":
            meta_dict['ena_sample_accession'] = meta_dict.pop('sample_accession')
        # check study accessions
        if meta_dict['study_accession'][:3] == "PRJ":
            meta_dict['ncbi_study_accession'] = meta_dict.pop('study_accession')
        elif meta_dict['study_accession'][1:3] == "RP":
            meta_dict['ena_study_accession'] = meta_dict.pop('study_accession')

        ncrnas = get_ncrnas(gff)

        output = merge_dicts(meta_dict, ncrnas)
        for key in output.keys():
            if output[key] == "NA" or not output[key] and output[key] != 0:
                del output[key]
        try:
            pangen_cov = glob.glob(os.path.join(args.in_folder, "pan-genome/*coverage.tsv"))[0]
            core_cds = glob.glob(os.path.join(args.in_folder, "pan-genome/core_genes.faa"))[0]
            access_cds = glob.glob(os.path.join(args.in_folder, "pan-genome/accessory_genes.faa"))[0]
            pangenome = get_pangenome(core_cds, access_cds, pangen_cov, species_code)
            pangenome['geographic_range'] = meta_res[0]
            output['pangenome'] = pangenome
        except:
            pass

        out_file = os.path.join(args.in_folder, 'genome.json')
        write_obj_2_json(output, out_file)