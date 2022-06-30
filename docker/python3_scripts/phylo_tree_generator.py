import argparse
import csv
import json


def parse_args():
    parser = argparse.ArgumentParser(description='Tool to generate a phylogenetic tree from a tsv file')
    parser.add_argument('--table', dest='tsv_file', help='2-column file containing the genome name and lineage')
    parser.add_argument('--out', dest='out', default='tree.json', help='Tree file output')
    return parser.parse_args()


def read_tsv(filename):
    genomes_data = []
    with open(filename, 'r') as f:
        for line in f:
            if not line.startswith('user_genome'):
                line = line.strip().split('\t')
                genomes_data.append(line[:2])
    return genomes_data


json_root = {
    'children': [],
    'name': 'Domain',
    'type': 'root'
}


def add_to_json(json_root, genome, lineage):
    if len(lineage) == 0:
        new_node = {
            'coungen': 1,
            'name': genome,
            'type': 'genome'
        }
        json_root['children'].append(new_node)
        return

    l = lineage.pop(0)
    for child in json_root['children']:
        if child['name'] == l:
            child['countgen'] += 1
            return add_to_json(child, genome, lineage)

    new_node = {
        'countgen': 1,
        'name': l,
        'type': l[0],
        'children': []
    }
    json_root['children'].append(new_node)
    return add_to_json(new_node, genome, lineage)


def write_output(tree, filename):
    with open(filename, 'w') as f:
        json.dump(tree, f, indent=4)


def main():
    args = parse_args()
    for item in read_tsv(args.tsv_file):
        genome = item[0]
        lineage = item[1].split(';')
        add_to_json(json_root, genome, lineage)
    write_output(json_root, args.out)


if __name__ == '__main__':
    main()