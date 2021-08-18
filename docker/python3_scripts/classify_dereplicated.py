#!/usr/bin/env python3

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