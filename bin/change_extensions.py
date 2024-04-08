import os
import argparse


def change_file_extensions(directory_path):
    for filename in os.listdir(directory_path):
        file_path = os.path.join(directory_path, filename)

        # Check if the path is a file (not a directory)
        if os.path.isfile(file_path):
            # Split the file name and extension
            file_name, file_extension = os.path.splitext(filename)

            # Check if the current extension is not "fa" and rename
            if file_extension != '.fa':
                new_file_name = file_name + '.fa'
                new_file_path = os.path.join(directory_path, new_file_name)
                os.rename(file_path, new_file_path)


def main():
    parser = argparse.ArgumentParser(description='The script changes extensions of genomes in the '
                                                 'NCBI folder to .fa.')
    parser.add_argument('--i', dest='input_folder', required=True, help='Input folder name where genomes are located.')

    args = parser.parse_args()
    input_folder = args.input_folder

    assert os.path.isdir(input_folder), f"Error: The input folder '{input_folder}' does not exist."

    change_file_extensions(input_folder)


if __name__ == '__main__':
    main()
