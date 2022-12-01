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

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Get files by pattern")
    parser.add_argument("-f", "--input-files", dest="inputs", required=True, nargs='+')
    parser.add_argument("-p", "--pattern", dest="pattern", required=True)
    parser.add_argument("-o", "--output", dest="output", required=False, default="out")

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()
        if not os.path.exists(args.output):
            os.mkdir(args.output)

        for line in args.inputs:
            basename = os.path.basename(line)
            if args.pattern in basename:
                copy(line, os.path.join(args.output, basename))

        if len(os.listdir(args.output)) > 1:
            os.rename(args.output, "many")
        elif len(os.listdir(args.output)) == 1:
            os.rename(args.output, "one")


