#!/usr/bin/env python3

# This file is part of MGnify genomes catalogue pipeline.
#
# MGnify genomes catalogue pipeline is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MGnify genomes catalogue pipeline is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with MGnify genomes catalogue pipeline. If not, see <https://www.gnu.org/licenses/>.

import argparse
import logging
import os

logging.basicConfig(level=logging.INFO)


def main(input_folder):
    issues = list()
    # verify that all expected folders are where they are
    main_folders = ["ftp", "additional_data"]  # not checking "website" because we don't need it
    for folder in main_folders:
        if not verify_folder(input_folder, folder):
            issues.append("Folder {} is not found.".format(os.path.join(input_folder, folder)))
    ftp_checklist = ["genomes-all_metadata.tsv", "all_genomes", "species_catalogue"]
    additional_data_checklist = ["panaroo_output", "mgyg_genomes"]
    intermediate_files_checklist = ["extra_weight_table.txt", "drep_data_tables.tar.gz",
                                    "renamed_genomes_name_mapping.tsv"]
    for element in ftp_checklist:
        ftp_path = os.path.join(input_folder, "ftp")
        if not verify_folder(ftp_path, element):
            issues.append("{} is not found.".format(os.path.join(ftp_path, element)))
    for element in additional_data_checklist:
        additional_data_path = os.path.join(input_folder, "additional_data")
        if not verify_folder(additional_data_path, element):
            issues.append("{} is not found.".format(os.path.join(additional_data_path, element)))
    for element in intermediate_files_checklist:
        intermediate_files_path = os.path.join(input_folder, "additional_data", "intermediate_files")
        if not verify_folder(intermediate_files_path, element):
            issues.append("{} is not found.".format(os.path.join(intermediate_files_path, element)))
    if len(issues) > 0:
        with open("PREVIOUS_CATALOGUE_STRUCTURE_ERRORS.txt", "w") as f:
            f.write("\n".join(issues))
        logging.error("Catalogue structure issues found")
    else:
        with open("PREVIOUS_CATALOGUE_STRUCTURE_OK.txt", "w") as f:
            logging.info("Catalogue structure OK")


def verify_folder(main_path, element_to_check):
    if os.path.exists(os.path.join(main_path, element_to_check)):
        return True
    else:
        return False


def parse_args():
    parser = argparse.ArgumentParser(description='The script is part of the catalogue update pipeline. It checks '
                                                 'that all expected files from the previous version of the catalogue '
                                                 'are present in the expected locations.')
    parser.add_argument('-i', dest='input_folder', required=True, help='Location of the previous catalogue. '
                                                                       'Folders "ftp", "website", "additional_data" '
                                                                       'should be inside this folder')

    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args.input_folder)
