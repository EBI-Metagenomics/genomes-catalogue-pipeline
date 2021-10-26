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
import sys
import argparse
from shutil import copy


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Split returns folder with main")
    parser.add_argument('-i', dest='input', help='file with clusters distribution', required=True)
    parser.add_argument('-g', dest='gffs', help='list of gffs', required=True, nargs='+')
    parser.add_argument('-f', dest='fastas', help='list of faas', required=True, nargs='+')
    parser.add_argument('-n', dest='name', help='cluster name', required=True)
    parser.add_argument('-o', dest='outdir', help='output folder', required=False, default='outdir')

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    else:
        args = parser.parse_args()
        clusters = {}
        with open(args.input, 'r') as file_in:
            for line in file_in:
                line = line.strip().split(':')
                cluster = line[1]