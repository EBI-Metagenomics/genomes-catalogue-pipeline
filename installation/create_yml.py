#!/usr/bin/env python3

import argparse


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Create the input.yml for the pipeline"
    )
    parser.add_argument(
        "-y", "--yml", dest="yml", help="YAML file with the constants", required=True
    )
    parser.add_argument(
        "-e", "--ena", dest="ena_genomes", help="Genomes from ENA", required=False
    )
    parser.add_argument(
        "-s", "--csv", dest="ena_csv", help="CSV file for ENA genomes", required=False
    )
    parser.add_argument(
        "-a", "--ncbi", dest="ncbi_genomes", help="Genomes from NCBI", required=False
    )
    parser.add_argument(
        "-m", "--max", dest="max", help="maximum MGYG number", required=True
    )
    parser.add_argument(
        "-n", "--min", dest="min", help="minimum MGYG number", required=True
    )
    parser.add_argument(
        "-c", "--name", dest="catalogue_name", help="name of catalogue on FTP (example: HUMAN-GUT)", required=True
    )
    parser.add_argument(
        "-v", "--version", dest="version", help="version of catalogue (example: v1.0)", required=True
    )
    parser.add_argument(
        "-b", "--biom", dest="biom", help="biom (example: Human:Gut)", required=True
    )
    parser.add_argument(
        "-o", "--output", dest="output", help="Output yaml file path", required=True
    )

    args = parser.parse_args()

    if not(args.ena_genomes or args.ncbi_genomes):
        parser.error("ENA or NCBI genomes are required.")

    if args.ena_genomes:
        if not args.ena_csv:
            parser.error("For ENA genomes --csv is required.")

    if args.ena_csv:
        if not args.ena_genomes:
            parser.error("ENA CSV given without ENA genomes location.")

    if int(args.min) > int(args.max):
        parser.error("Min accession is bigger than Max accession")

    if "v" not in args.version:
        parser.error("Add version with 'v'. Example: v1.0")

    print(f"Loading the constants from {args.yml}.")
    with open(args.yml, "r") as constants_yml:
        constants = constants_yml.read()

    print(f"---------> prepare YML file for {args.catalogue_name} version {args.version}")

    with open(args.output, "w") as output_yml:
        print(constants, "", sep="\n", file=output_yml)
        print("max_accession_mgyg: " + args.max, sep="\n", file=output_yml)
        print("min_accession_mgyg: " + args.min, sep="\n", file=output_yml)
        print("ftp_name_catalogue: \"" + args.catalogue_name + "\"", sep="\n", file=output_yml)
        print("ftp_version_catalogue: \"" + args.version + "\"", sep="\n", file=output_yml)
        print("biom: \"" + args.biom + "\"", sep="\n", file=output_yml)
        if args.ena_genomes:
            print(
                "genomes_ena:",
                "  class: Directory",
                "  path: " + args.ena_genomes,
                sep="\n",
            file=output_yml,
            )
            print(
                "ena_csv:",
                "  class: File",
                "  path: " + args.ena_csv,
                sep="\n",
            file=output_yml,
            )
        if args.ncbi_genomes:
            print(
                "genomes_ncbi:",
                "  class: Directory",
                "  path: " + args.ncbi_genomes,
                sep="\n",
            file=output_yml,
            )
    print("---------> yml done. Exit")
