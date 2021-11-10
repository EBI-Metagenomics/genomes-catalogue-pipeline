#!/usr/bin/env python3
# coding=utf-8

# This file is part of MGnify genome analysis pipeline.
#
# MGnify genome analysis pipeline is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MGnify genome analysis pipeline is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with MGnify genome analysis pipeline. If not, see <https://www.gnu.org/licenses/>.


import argparse
import os
from shutil import copy
import sys
import re


def parse_args():
    parser = argparse.ArgumentParser(description='Script creates folders per each genome with IPS, eggnog, faa and gff')
    parser.add_argument('--gffs', required=True, nargs='+',
                        help='list of GFF files')
    parser.add_argument('--faas', required=True, nargs='+',
                        help='list of FAA files')
    parser.add_argument('--annotations', required=True, nargs='+',
                        help='list of eggnog and IPS files')
    parser.add_argument('--pangenome-fna', required=False, nargs='*',
                        help='pangenome.fna fasta')
    parser.add_argument('--pangenome-core', required=False, nargs='*',
                        help='pangenome: core_genes.txt')
    parser.add_argument('--clusters', required=True,
                        help='file with cluster representatives list')
    parser.add_argument('--output', required=True,
                        help='name of output directory')
    return parser.parse_args()


pattern_ips = "{name}_InterProScan.tsv"
pattern_eggnog = "{name}_eggNOG.tsv"
pattern_faa = "{name}.faa"
pattern_gff = "{name}.gff"
pattern_core_genes = "{name}.core_genes.txt"
pattern_pangenome_fna = "{name}.pan-genome.fna"


def main():
    if len(sys.argv) == 1:
        print('No input data')
        exit(1)
    else:
        args = parse_args()
        types = [args.annotations, args.annotations, args.faas, args.gffs]
        patterns = [pattern_ips, pattern_eggnog, pattern_faa, pattern_gff]
        if not os.path.exists(args.output):
            os.mkdir(args.output)
        # read cluster names (main reps)
        with open(args.clusters, 'r') as file_clusters:
            for line in file_clusters:
                cluster_name = line.strip().split('.')[0]
                cluster = os.path.join(args.output, cluster_name)
                if not os.path.exists(cluster):
                    os.mkdir(cluster)
                for file_pattern, files in zip(patterns, types):
                    pattern = file_pattern.format(name=cluster_name)
                    cluster_file = [i for i in files if i.endswith(pattern)]
                    if len(cluster_file) != 1:
                        exit(1)
                    else:
                        copy(cluster_file[0], os.path.join(cluster, os.path.basename(cluster_file[0])))
                if args.pangenome_core:
                    core_genes = pattern_core_genes.format(name=cluster_name)
                    cluster_file = [i for i in os.listdir(args.pangenome_core) if i.endswith(core_genes)]
                    if len(cluster_file) == 1:
                        copy(cluster_file[0], os.path.join(cluster, os.path.basename(cluster_file[0])))
                if args.pangenome_fna:
                    pangenome_fna = pattern_pangenome_fna.format(name=cluster_name)
                    cluster_file = [i for i in os.listdir(args.pangenome_fna) if i.endswith(pangenome_fna)]
                    if len(cluster_file) == 1:
                        copy(cluster_file[0], os.path.join(cluster, os.path.basename(cluster_file[0])))


if __name__ == '__main__':
    main()