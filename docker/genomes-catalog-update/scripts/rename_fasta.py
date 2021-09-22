#!/usr/bin/env python3

# This file is part of MGnify genome analysis pipeline.
#
# MGnify genome analysis pipeline is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MGnify genome analysis pipeline is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with MGnify genome analysis pipeline. If not, see <https://www.gnu.org/licenses/>.


import argparse
import logging
import os
import shutil
import re

logging.basicConfig(level=logging.INFO)


def main(fasta_file_directory, prefix, index, cluster_file, table_file, num_digits, rename_deflines, outdir=None,
		 max_number=None, csv=None):
	names = dict()  # matches old and new names
	files = os.listdir(fasta_file_directory)
	logging.info('Renaming files...')
	if cluster_file:
		assert os.path.isfile(cluster_file), 'Provided cluster information file does not exist'
	for file in files:
		if file.endswith(('fa', 'fasta')) and not file.startswith(prefix):
			accession = '{}{}{}'.format(prefix, '0' * (num_digits - len(str(index))), str(index))
			new_name = '{}.fa'.format(accession)
			names[file] = new_name
			if outdir:
				rename_to_outdir(file, new_name, accession, input_dir=fasta_file_directory, output_dir=outdir)
			else:
				rename_fasta(file, new_name, fasta_file_directory, rename_deflines, accession)
				try:
					os.remove(os.path.join(fasta_file_directory, file))
				except OSError as e:
					logging.error('Unable to delete {}: {}'.format(file, e))
			index += 1
			if max_number and index > max_number:
				print('index is bigger than requested number in catalogue')
				exit(1)
	logging.info('Printing names to table...')
	print_table(names, table_file)
	if cluster_file:
		logging.info('Renaming clusters...')
		rename_clusters(names, cluster_file)
	if csv:
		logging.info('Renaming csv...')
		rename_csv(names, csv)


def write_fasta(old_path, new_path, accession):
	file_in = open(old_path, 'r')
	file_out = open(new_path, 'w')
	spades_regex = re.compile("NODE_[0-9]+_length_([0-9]+)_cov_([0-9.]+)")
	n = 0
	for line in file_in:
		if line.startswith('>'):
			n += 1
			if spades_regex.search(line):
				length, coverage = [m for m in spades_regex.findall(line.strip())[0]]
			else:
				length, coverage = 'NA', 'NA'
			file_out.write('>{}_{}-length-{}-cov-{}\n'.format(accession, n, length, coverage))
		else:
			file_out.write(line)
	file_in.close()
	file_out.close()


def rename_to_outdir(file, new_name, accession, input_dir, output_dir):
	new_path = os.path.join(output_dir, new_name)
	old_path = os.path.join(input_dir, file)
	if not os.path.exists(output_dir):
		os.mkdir(output_dir)
	write_fasta(old_path, new_path, accession)


def rename_fasta(file, new_name, fasta_file_directory, rename_deflines, accession):
	new_path = os.path.join(fasta_file_directory, new_name)
	old_path = os.path.join(fasta_file_directory, file)
	if not rename_deflines:
		shutil.copyfile(old_path, new_path)
	else:
		write_fasta(old_path, new_path, accession)


def print_table(names, table_file):
	with open(table_file, 'w') as table_out:
		for key, value in names.items():
			table_out.write('{}\t{}\n'.format(key, value))


def rename_clusters(names, cluster_file):
	extension = cluster_file.split('.')[-1]
	clusters_renamed = cluster_file.replace('.{}'.format(extension), '_renamed.{}'.format(extension))
	file_in = open(cluster_file, 'r')
	file_out = open(clusters_renamed, 'w')
	for line in file_in:
		for g in line.strip().split('\t'):
			if g in names:
				line = line.replace(g, names[g])
		file_out.write(line)
	file_in.close()
	file_out.close()


def rename_csv(names, csv_file):
	clusters_renamed = "renamed_" + os.path.basename(csv_file)
	with open(csv_file, 'r') as file_in, open(clusters_renamed, 'w') as file_out:
		for line in file_in:
			items = line.strip().split(',')
			genome = names[items[0]] if items[0] in names else items[0]
			file_out.write(','.join([genome] + items[1:3]) + '\n')


def parse_args():
	parser = argparse.ArgumentParser(description='Rename multifasta files, cluster information file and create a table '
												 'matching old and new names')
	parser.add_argument('-d', dest='fasta_file_directory', required=True, help='Input directory containing FASTA files')
	parser.add_argument('-p', dest='prefix', default='MGYG', help='Header prefix')
	parser.add_argument('-i', dest='index', type=int, default=1,
						help='Number to start naming at (will be in the file name following prefix; default = 1')
	parser.add_argument('--max', dest='max', type=int, required=False, help='Number to finish naming')
	parser.add_argument('-c', dest='cluster_file',
						help='Path to the cluster information file. If provided, the names in the '
							 'file will be updated as well')
	parser.add_argument('-t', dest='table_file', default='naming_table.tsv',
						help='Path to file where output table matching old and new names will be saved to. '
							 'Default: naming_table.tsv')
	parser.add_argument('-n', dest='num_digits', type=int, default=9,
						help='Number of digit places to include after the prefix in the filename. Default = 9')
	parser.add_argument('--rename-deflines', action='store_true',
						help='If this flag is on, deflines within the FASTA file will be renamed using the new '
							 'accession.')
	parser.add_argument('-o', dest='outputdir', required=False,
						help='Output directory for renamed FASTA files (use in CWL)')
	parser.add_argument('--csv', dest='csv', required=False,
						help='CSV file with completeness and contamination')
	return parser.parse_args()


if __name__ == '__main__':
	args = parse_args()
	main(args.fasta_file_directory, args.prefix, args.index, args.cluster_file, args.table_file, args.num_digits,
		 args.rename_deflines, outdir=args.outputdir, max_number=args.max, csv=args.csv)

