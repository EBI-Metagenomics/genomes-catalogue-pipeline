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
import json
import logging
import sys
from pathlib import Path
from jsonschema import validate

logging.basicConfig(level=logging.INFO)


def check_structure(base_folder: Path, structure: dict):
    """Recursively verify that expected structure exists under base_folder."""
    issues = []

    for key, expected_items in structure.items():
        folder_path = base_folder / key
        if not folder_path.exists():
            issues.append(f"Missing folder: {folder_path}")
            continue

        for item in expected_items:
            # If it's a string → file or folder expected
            if isinstance(item, str):
                item_path = folder_path / item
                if not item_path.exists():
                    issues.append(f"Missing: {item_path}")

            # If it's a dict → nested structure
            elif isinstance(item, dict):
                issues.extend(check_structure(folder_path, item))

    return issues


def main():
    parser = argparse.ArgumentParser(
        description="Validate folder structure of the previous catalogue version using a JSON definition."
    )
    parser.add_argument(
        "-i", "--input_folder", required=True,
        help="Path to the output folder of the previous catalogue version. Folders 'ftp' and 'additional_data' should"
             "be inside of it."
    )
    parser.add_argument(
        "-s", "--schema", required=True,
        help="Path to JSON file defining expected folder structure."
    )
    args = parser.parse_args()

    base_folder = Path(args.input_folder)
    schema_path = Path(args.schema)

    if not base_folder.exists():
        logging.error(f"Input folder does not exist: {base_folder}")
        sys.exit(1)

    if not schema_path.exists():
        logging.error(f"Schema file not found: {schema_path}")
        sys.exit(1)

    with open(schema_path) as f:
        expected_structure = json.load(f)

    # Validate JSON format itself
    validate(
        instance=expected_structure,
        schema={
            "type": "object",
            "patternProperties": {
                ".*": {
                    "type": "array",
                    "items": {
                        "anyOf": [
                            {"type": "string"},
                            {"type": "object"}
                        ]
                    }
                }
            }
        }
    )

    issues = check_structure(base_folder, expected_structure)

    if issues:
        Path("PREVIOUS_CATALOGUE_STRUCTURE_ERRORS.txt").write_text("\n".join(issues))
        logging.error("Catalogue structure issues found.")
    else:
        Path("PREVIOUS_CATALOGUE_STRUCTURE_OK.txt").write_text("Catalogue structure OK")
        logging.info("Catalogue structure OK.")


if __name__ == "__main__":
    main()
