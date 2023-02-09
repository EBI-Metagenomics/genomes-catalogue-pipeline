#!/usr/bin/env python

import json
import argparse
import yaml
import sys

def get_args():
    parser = argparse.ArgumentParser(description="Convert cwltool output to cwltest")
    parser.add_argument("-i", "--input", dest="input", required=True, help="File with cwltool output")
    return parser


if __name__ == "__main__":

    args = get_args().parse_args()
    with open(args.input) as json_file:
        data = json.load(json_file)

    yaml.safe_dump(data, sys.stdout, default_flow_style=False)
