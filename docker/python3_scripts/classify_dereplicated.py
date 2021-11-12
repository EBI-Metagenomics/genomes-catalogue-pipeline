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


import os
import shutil
import argparse
import sys

NAME_ONE_GENOME = "one_genome"

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Creates folder for every genome")
    parser.add_argument("-i", "--input", dest="input", help="folder with dereplicated genomes from ENA",
                        required=True)

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()
        genomes = os.listdir(args.input)
        if not os.path.exists(NAME_ONE_GENOME):
            os.mkdir(NAME_ONE_GENOME)
        for i in range(len(genomes)):
            folder_name = str(i+1) + '_0'
            if not os.path.exists(os.path.join(NAME_ONE_GENOME, folder_name)):
                os.mkdir(os.path.join(NAME_ONE_GENOME, folder_name))
                shutil.copy(os.path.join(args.input, genomes[i]),
                            os.path.join(NAME_ONE_GENOME, folder_name, genomes[i]))