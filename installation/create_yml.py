#!/usr/bin/env python3

import argparse

WGS_ANALYSIS = "wgs"
ASSEMBLY_ANALYSIS = "assembly"
AMPLICON_ANALYSIS = "amplicon"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Create the input.yml for the pipeline"
    )
    parser.add_argument(
        "-y", "--yml", dest="yml", help="YAML file with the constants", required=True
    )
    parser.add_argument(
        "-a",
        "--analysis",
        dest="analysis",
        choices=[WGS_ANALYSIS, ASSEMBLY_ANALYSIS, AMPLICON_ANALYSIS],
        help="Type of analysis",
        required=True,
    )
    parser.add_argument(
        "-t",
        "--type",
        dest="type",
        choices=["single", "paired"],
        help="single/paired option",
        required=False,
    )
    parser.add_argument(
        "-f", "--fr", dest="fr", help="forward reads file path", required=False
    )
    parser.add_argument(
        "-r", "--rr", dest="rr", help="reverse reads file path", required=False
    )
    parser.add_argument(
        "-s", "--single", dest="single", help="single reads file path", required=False
    )
    parser.add_argument(
        "-o", "--output", dest="output", help="Output yaml file path", required=True
    )

    args = parser.parse_args()

    type_required = args.analysis in [WGS_ANALYSIS, AMPLICON_ANALYSIS]
    if type_required and args.type is None:
        parser.error(f"For {WGS_ANALYSIS} or {AMPLICON_ANALYSIS}, --type is required.")

    if args.analysis in [ASSEMBLY_ANALYSIS, AMPLICON_ANALYSIS] and args.single is None:
        parser.error(
            f"For {ASSEMBLY_ANALYSIS} or {AMPLICON_ANALYSIS}, --single is required."
        )

    print(f"Loading the constants from {args.yml}.")
    with open(args.yml, "r") as constants_yml:
        constants = constants_yml.read()

    print("---------> prepare YML file for " + args.analysis)

    with open(args.output, "w") as output_yml:
        print(constants, "", sep="\n", file=output_yml)
        if args.analysis in [WGS_ANALYSIS, AMPLICON_ANALYSIS]:
            if args.type == "single":
                print(
                    "single_reads:",
                    "  class: File",
                    "  format: edam:format_1930",
                    "  path: " + args.single,
                    sep="\n",
                    file=output_yml,
                )
            elif args.type == "paired":
                print(
                    "forward_reads:",
                    "  class: File",
                    "  format: edam:format_1930",
                    "  path: " + args.fr,
                    sep="\n",
                    file=output_yml,
                )
                print(
                    "reverse_reads:",
                    "  class: File",
                    "  format: edam:format_1930",
                    "  path: " + args.rr,
                    sep="\n",
                    file=output_yml,
                )
        elif args.analysis == ASSEMBLY_ANALYSIS:
            print(
                "contigs:",
                "  class: File",
                "  format: edam:format_1929",
                "  path: " + args.single,
                sep="\n",
                file=output_yml,
            )

        print("---------> yml done")
