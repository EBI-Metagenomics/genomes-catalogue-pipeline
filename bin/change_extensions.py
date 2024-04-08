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
import argparse


def change_file_extensions(directory_path):
    for filename in os.listdir(directory_path):
        file_path = os.path.join(directory_path, filename)

        # Check if the path is a file (not a directory)
        if os.path.isfile(file_path):
            # Split the file name and extension
            file_name, file_extension = os.path.splitext(filename)

            # Check if the current extension is not "fa" and rename
            if file_extension != '.fa':
                new_file_name = file_name + '.fa'
                new_file_path = os.path.join(directory_path, new_file_name)
                os.rename(file_path, new_file_path)


def main():
    parser = argparse.ArgumentParser(description='The script changes extensions of genomes in the '
                                                 'NCBI folder to .fa.')
    parser.add_argument('--i', dest='input_folder', required=True, help='Input folder name where genomes are located.')

    args = parser.parse_args()
    input_folder = args.input_folder

    assert os.path.isdir(input_folder), f"Error: The input folder '{input_folder}' does not exist."

    change_file_extensions(input_folder)


if __name__ == '__main__':
    main()
