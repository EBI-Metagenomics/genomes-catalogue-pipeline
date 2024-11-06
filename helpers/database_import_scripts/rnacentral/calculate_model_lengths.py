#!/usr/bin/env python3

import argparse
import re
import sys


def main(rfam_file, output):
    rfam_lengths = dict()
    with open(rfam_file, "r") as f:
        for line in f:
            if line.startswith("ACC"):
                name = re.sub(" +", "\t", line.strip()).split("\t")[1]
            elif line.startswith(("CLEN", "LENG")):
                model_length = re.sub(" +", "\t", line.strip()).split("\t")[1]
                if name == "":
                    print("ERROR: unexpected line order", line)
                    sys.exit()
                elif name in rfam_lengths:
                    if rfam_lengths[name] == model_length:
                        pass
                    else:
                        print(
                            "ERROR: same name occurs multiple times and lengths do not match",
                            name,
                        )
                else:
                    rfam_lengths[name] = model_length
                    name = ""
    with open(output, "w") as file_out:
        for rfam_name, len in rfam_lengths.items():
            file_out.write("{}\t{}\n".format(rfam_name, len))


def parse_args():
    parser = argparse.ArgumentParser(
        description="Script produces a file with lengths of Rfam covariance models."
        "The resulting file is necessary for running the JSON generating"
        "script and only needs to be produced once unless the Rfam.cm"
        "file is updated."
    )
    parser.add_argument(
        "-r",
        "--rfam-file",
        required=True,
        help="Path to the Rfam.cm file containing concatinated Rfam models.",
    )
    parser.add_argument(
        "-o",
        "--output",
        required=True,
        help="Path to the output file where the lengths of models will be saved to.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args.rfam_file, args.output)
