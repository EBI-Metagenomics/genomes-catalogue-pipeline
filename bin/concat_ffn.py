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


def main():
    parser = argparse.ArgumentParser(
        description="Concatenate all .ffn files in a directory into a single output file."
    )
    parser.add_argument("--input-dir", required=True, help="Directory containing .ffn files")
    parser.add_argument("--output", required=True, help="Output concatenated .ffn file")
    args = parser.parse_args()

    ffn_files = sorted(f for f in os.listdir(args.input_dir) if f.endswith(".ffn"))

    with open(args.output, "w") as out:
        for fname in ffn_files:
            with open(os.path.join(args.input_dir, fname)) as f:
                out.write(f.read())


if __name__ == "__main__":
    main()
