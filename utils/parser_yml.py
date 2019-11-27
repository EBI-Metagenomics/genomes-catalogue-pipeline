#!/usr/bin/env python3

import json
import argparse
import sys

NAME_many_genomes_out = "many_genomes"
NAME_one_genome_out = "one_genome"
NAME_mash_out = "mash_folder"

def parse_json(filename, yml):
    with open(filename, 'r') as file_input, open(yml, 'a') as yml_out:
        data = json.load(file_input)

        print('=== First step: parsing for ' + NAME_many_genomes_out + ' and ' + NAME_one_genome_out)
        if NAME_many_genomes_out in data:
            folders = data[NAME_many_genomes_out]
            if folders is None:
                print('Many genomes NOT presented')
            else:
                print('Many genomes presented')
                yml_out.write(NAME_many_genomes_out + ':\n')
                for folder in folders:
                    str_out = '  - class: Directory\n    path: ' + folder["location"].split('file://')[1] + '\n'
                    yml_out.write(str_out)
        if NAME_one_genome_out in data:
            folders = data[NAME_one_genome_out]
            if folders is None:
                print('One genome NOT presented')
            else:
                print('One genome presented')
                yml_out.write(NAME_one_genome_out + ':\n')
                for folder in folders:
                    str_out = '  - class: Directory\n    path: ' + folder["location"].split('file://')[1] + '\n'
                    yml_out.write(str_out)
        if NAME_mash_out in data:
            files = data[NAME_mash_out]
            if files is None:
                print('MASH files NOT presented')
            else:
                print('MASH files genome presented')
                yml_out.write(NAME_mash_out + ':\n')
                for mashfile in files:
                    str_out = '  - class: File\n    path: ' + mashfile["location"].split('file://')[1] + '\n'
                    yml_out.write(str_out)

        if data[NAME_many_genomes_out] is None and data[NAME_one_genome_out] is None:
            sys.exit(4)

        if data[NAME_many_genomes_out] is not None:
            if data[NAME_one_genome_out] is not None:
                sys.exit(1)
            else:
                sys.exit(2)
        else:
            sys.exit(3)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Parsing first sub-wf of pipeline")
    parser.add_argument("-j", "--json", dest="json", help="Output structure in json", required=True)
    parser.add_argument("-y", "--yml", dest="yml", help="Input Yml file", required=True)

    if len(sys.argv) == 1:
        parser.print_help()
    else:
        args = parser.parse_args()
        print('Exit == 1 if many & one genomes presented\n'
              'Exit == 2 if only many genomes clusters presented\n'
              'Exit == 3 if only one genome clusters presented\n'
              'Exit == 4 if nothing presented')
        parse_json(args.json, args.yml)