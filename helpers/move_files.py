#!/usr/bin/env python3

import argparse
import os
import shutil


def main(command, dir_from, dir_to, filename):
    assert os.path.isdir(dir_from), "The from directory {} does not exist".format(dir_from)
    assert os.path.isdir(dir_to), "The to directory {} does not exist".format(dir_to)
    if command == "copy":
        execute_command = shutil.copy
    elif command == "move":
        execute_command = shutil.move
    if not filename:
        files = [f for f in os.listdir(dir_from) if os.path.isfile(os.path.join(dir_from, f))]
    else:
        files = [filename]
    for file_name in files:
        source_path = os.path.join(dir_from, file_name)
        destination_path = os.path.join(dir_to, file_name)
        execute_command(source_path, destination_path)
        

def parse_args():
    parser = argparse.ArgumentParser(
        description="Script moves or copies files"
    )
    parser.add_argument(
        "--command",
        required=True,
        choices=['move', 'copy'],
        help="Command to execute: copy or move",
    )
    parser.add_argument("--dir-from", required=True, help="A path to the folder where to move/copy files from")
    parser.add_argument("--dir-to", required=True, help="A path to the folder where to move/copy files to")
    parser.add_argument("--filename", required=False, help="Only copy a specific file")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.command,
        args.dir_from,
        args.dir_to,
        args.filename,
    )

