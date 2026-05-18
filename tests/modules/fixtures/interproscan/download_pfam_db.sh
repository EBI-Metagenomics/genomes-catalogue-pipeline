#!/bin/bash
# Download the Pfam mini test database from the InterProScan repo.
# Usage: ./download_pfam_db.sh <version> [output_folder]
# Example: ./download_pfam_db.sh 5.77-108.0

set -euo pipefail

VERSION="${1:-5.77-108.0}"
OUTPUT="${2:-interproscan_db}"
FOLDER="core/jms-implementation/support-mini-x86-32/data/pfam"
ORIGINAL_DIR=$(pwd)

git clone --depth 1 --filter=blob:none --sparse https://github.com/ebi-pf-team/interproscan.git interproscan_tmp
cd interproscan_tmp
git sparse-checkout set "$FOLDER"
git checkout "$VERSION"

mkdir -p "$ORIGINAL_DIR/$OUTPUT/data"
cp -r "$FOLDER" "$ORIGINAL_DIR/$OUTPUT/data/"
cd "$ORIGINAL_DIR"
rm -rf interproscan_tmp
