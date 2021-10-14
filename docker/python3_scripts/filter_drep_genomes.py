#!/usr/bin/env python3

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
import sys
from shutil import copy
import os


def get_drep_genomes(clusters):
    # genomes sorted by score (from big to small)
    drep_genomes = []
    with open(clusters, 'r') as file_in:
        for line in file_in:
            if "many_genomes" in line:
                genomes = line.strip().split(':')[2].split(',')
                best_genome = genomes[0]
                drep_genomes.append(best_genome)
    return drep_genomes


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Get drep genomes and gunc-passed")
    parser.add_argument("-g", "--genomes", dest="genomes", help="All input genomes folder", required=True)
    parser.add_argument("--clusters", dest="clusters", help="Split clusters report", required=True)
    parser.add_argument("--gunc", dest="gunc", help="gunc completed report", required=True)
    parser.add_argument("--output", dest="output", help="output name", required=True)

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()

        # get pan-genomes clusters
        drep_genomes = get_drep_genomes(clusters=args.clusters)

        # get list of gunc-passed genomes
        with open(args.gunc, 'r') as file_gunc:
            for line in file_gunc:
                drep_genomes.append(line.strip())
        with open("drep-filt-list.txt", 'w') as list_drep:
            list_drep.write('\n'.join(drep_genomes))

        # make folder with chosen genomes
        if not os.path.exists(args.output):
            os.mkdir(args.output)
        for genome in drep_genomes:
            old = os.path.join(args.genomes, genome)
            new = os.path.join(args.output, genome)
            copy(old, new)