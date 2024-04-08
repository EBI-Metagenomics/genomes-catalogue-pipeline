#!/usr/bin/env python3
# coding=utf-8

import argparse
import csv
import hashlib
import logging
import shutil
import os
import gzip
from pathlib import Path

from Bio import SeqIO

logging.basicConfig(level=logging.INFO)

def open_fasta_file(filename):
    if filename.endswith('.gz'):
        f = gzip.open(filename, "rt")
    else:
        f = open(filename, "rt")
    return f

def main(fastas, outdir):
    file_hashes = {}  # filename, whole-file-checksum
    dedup_folder = Path(outdir)
    hashes_folder = dedup_folder / Path("hashes")

    dedup_folder.mkdir(exist_ok=True)
    hashes_folder.mkdir(exist_ok=True)

    logging.info("Creating the fasta md5 checksums")
    for fasta in fastas:
        fasta_name = Path(fasta).stem
        fasta_hashes = []
        handle = open_fasta_file(fasta)
        for record in SeqIO.parse(handle, "fasta"):
            hash_object = hashlib.md5(str(record.seq).encode())
            fasta_hashes.append(hash_object.hexdigest())
        handle.close()
        sorted_hashes = sorted(fasta_hashes)
        # TODO: this is not the fastest way of doing this
        #       as we are writing and reading the file
        with open(f"{hashes_folder}/{fasta_name}.md5hashes", "w") as hash_fh:
            for checkshum in sorted_hashes:
                print(checkshum, file=hash_fh)
        with open(f"{hashes_folder}/{fasta_name}.md5hashes", "rb") as open_hash_fh:
            whole_file_hash = hashlib.md5(open_hash_fh.read()).hexdigest()
            file_hashes.setdefault(whole_file_hash, []).append(fasta)

    # find duplicates, create report and cp the files to a dedup folder
    with open(dedup_folder / "duplicates.tsv", "w") as tsv_fh:
        csv_writer = csv.writer(tsv_fh, delimiter="\t")
        csv_writer.writerow(["fasta_sequences_md5", "nro of copies", "dups"])
        for file_hash, fasta_files in file_hashes.items():
            fasta_files_sorted = sorted(fasta_files)
            csv_writer.writerow(
                [
                    str(file_hash),
                    str(len(fasta_files_sorted)),
                    ",".join(fasta_files_sorted),
                ]
            )
            # Pick the first one
            file_to_cp = fasta_files_sorted[0]
            logging.info(f"Copying {file_to_cp} to the dedup output folder")
            shutil.copy(file_to_cp, dedup_folder / Path(file_to_cp).name)
    logging.info(f"Deduplicated genomes copied to {dedup_folder}")
    logging.info(f"Deduplicated genomes report {dedup_folder / 'duplicates.tsv'}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=(
            "Deduplication tool for fasta files. This tool uses the sequences to deduplicate a set of fasta"
            " files."
        )
    )
    input_group = parser.add_mutually_exclusive_group()
    input_group.add_argument("-f", "--fastas", help="The fasta files paths", nargs="+")
    input_group.add_argument("-i", "--input-folder", help="Folder with fasta files")
    parser.add_argument(
        "-o",
        "--outdir",
        required=True,
        help="The output folder for the deduplicated fasta files and the report tsv",
    )
    args = parser.parse_args()
    fastas = []
    if args.input_folder:
        fastas = [os.path.join(args.input_folder, i) for i in os.listdir(args.input_folder)]
    else:
        fastas = args.fastas
    main(fastas, args.outdir)
