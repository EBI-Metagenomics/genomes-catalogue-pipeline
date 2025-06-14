#!/usr/bin/env python3
# coding=utf-8

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
import multiprocessing as mp
import os

logging.basicConfig(level=logging.INFO)


def main(ips, eggnog, rep_list, outdir, mmseqs_tsv, cores):
    if not os.path.exists(outdir):
        os.makedirs(outdir)

    with open(rep_list, "r") as f:
        genome_list = {line.strip().split(".")[0] for line in f}
    logging.info(f"Loaded {len(genome_list)} representative accessions.")

    if len(genome_list) <= 10000:
        logging.info("Using fast (memory-intensive) workflow.")
        fast_workflow(ips, eggnog, genome_list, outdir, mmseqs_tsv, cores)
    else:
        logging.info("Using memory-efficient (slower) workflow.")
        memory_efficient_workflow(ips, eggnog, genome_list, outdir, mmseqs_tsv, cores)


# ------------------- FAST WORKFLOW -------------------

def fast_workflow(ips, eggnog, genome_list, outdir, mmseqs_tsv, cores):
    global clusters
    clusters = dict()
    pool = mp.Pool(cores)
    for chunk_start, chunk_size in make_tsv_chunks(mmseqs_tsv):
        pool.apply_async(
            process_chunk_fast,
            (chunk_start, chunk_size, genome_list, mmseqs_tsv),
            callback=append_values,
        )
    pool.close()
    pool.join()

    logging.info("Loaded cluster information.")
    # separate annotations by genome, load into dictionaries and generate result files
    header_ips, results_ips = load_annotations(ips, clusters)
    print_results(results_ips, header_ips, outdir, "InterProScan")
    del results_ips
    logging.info("Generated IPS output.")
    header_eggnog, results_eggnog = load_annotations(eggnog, clusters)
    print_results(results_eggnog, header_eggnog, outdir, "eggNOG")
    logging.info("Generated eggNOG output.")


def process_chunk_fast(chunk_start, chunk_size, genome_list, tsv_file):
    result = []
    with open(tsv_file) as f:
        f.seek(chunk_start)
        lines = f.read(chunk_size).splitlines()
        for line in lines:
            rep, member = line.strip().split("\t")
            if member.split("_")[0] in genome_list:
                result.append([rep, member])
    return result


def append_values(returned_values):
    if returned_values:
        for rep, member in returned_values:
            clusters.setdefault(rep, set()).add(member)


def load_annotations(ann_file, clusters):
    ann_result = dict()
    header = ""
    with open(ann_file, "r") as file_in:
        for line in file_in:
            line = line.strip()
            if line.startswith("#query"):
                header = line
            else:
                rep_protein = line.split("\t")[0]
                if rep_protein in clusters:
                    for member in clusters[rep_protein]:
                        genome = member.split("_")[0]
                        ann_result.setdefault(genome, []).append(line.replace(rep_protein, member))
    return header, ann_result


def print_results(result_dict, header, outdir, tool):
    for genome, lines in result_dict.items():
        out_path = os.path.join(outdir, f"{genome}_{tool}.tsv")
        with open(out_path, "w") as f_out:
            if header:
                f_out.write(header + "\n")
            f_out.write("\n".join(lines))


# ------------------- MEMORY EFFICIENT WORKFLOW -------------------

def memory_efficient_workflow(ips, eggnog, genome_list, outdir, mmseqs_tsv, cores):
    cluster_map_path = "cluster_map.tsv"
    process_mmseqs_to_file(mmseqs_tsv, genome_list, cluster_map_path, cores)
    logging.info("Cluster information written to disk.")
    stream_annotations(ips, cluster_map_path, outdir, "InterProScan")
    logging.info("Processed InterProScan annotations.")
    stream_annotations(eggnog, cluster_map_path, outdir, "eggNOG")
    logging.info("Processed eggNOG annotations.")


def process_mmseqs_to_file(tsv_file, genome_list, out_path, cores):
    queue = mp.Queue(maxsize=cores * 4)
    writer = mp.Process(target=write_cluster_map, args=(queue, out_path))
    writer.start()

    with mp.Pool(cores) as pool:
        for chunk_start, chunk_size in make_tsv_chunks(tsv_file):
            pool.apply_async(
                process_chunk_memory_efficient,
                args=(chunk_start, chunk_size, genome_list, tsv_file),
                callback=lambda result: queue.put(result)
            )
        pool.close()
        pool.join()

    queue.put(None)
    writer.join()


def process_chunk_memory_efficient(chunk_start, chunk_size, genome_list, tsv_file):
    result = []
    with open(tsv_file, "r") as f:
        f.seek(chunk_start)
        lines = f.read(chunk_size).splitlines()
        for line in lines:
            if "\t" not in line:
                continue
            rep, member = line.strip().split("\t")
            if member.split("_")[0] in genome_list:
                result.append(f"{rep}\t{member}")
    return result


def write_cluster_map(queue, out_path):
    with open(out_path, "w") as f:
        while True:
            item = queue.get()
            if item is None:
                break
            for line in item:
                f.write(line + "\n")


def stream_annotations(ann_file, cluster_map_path, outdir, tool):
    clusters = {}
    with open(cluster_map_path, "r") as f:
        for line in f:
            rep, member = line.strip().split("\t")
            clusters.setdefault(rep, []).append(member)

    header = None
    writers = set()

    with open(ann_file, "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith("#query"):
                header = line
                continue
            rep_protein = line.split("\t")[0]
            if rep_protein not in clusters:
                continue
            for member_protein in clusters[rep_protein]:
                genome = member_protein.split("_")[0]
                replaced_line = line.replace(rep_protein, member_protein)
                out_file = os.path.join(outdir, f"{genome}_{tool}.tsv")
                mode = "a" if genome in writers else "w"
                with open(out_file, mode) as f_out:
                    if mode == "w" and header:
                        f_out.write(header + "\n")
                    f_out.write(replaced_line + "\n")
                writers.add(genome)


# ------------------- COMMON -------------------

def make_tsv_chunks(file, size=10 * 1024 * 1024):
    file_end = os.path.getsize(file)
    with open(file, "rb") as f:
        chunk_end = f.tell()
        while True:
            chunk_start = chunk_end
            f.seek(size, 1)
            f.readline()
            chunk_end = f.tell()
            yield chunk_start, chunk_end - chunk_start
            if chunk_end >= file_end:
                break


def parse_args():
    parser = argparse.ArgumentParser(description="Takes interproscan and eggNOG results for an "
                                                 "MMseqs catalog as well as a list of representative "
                                                 "genomes and locations where the results should be "
                                                 "stored and creates individual annotation files for "
                                                 "each representative genome")
    parser.add_argument("-i", "--ips", required=True, help="Path to InterProScan input")
    parser.add_argument("-e", "--eggnog", required=True, help="Path to eggNOG input")
    parser.add_argument("-r", "--rep-list", required=True, help="Representative genomes list")
    parser.add_argument("-t", "--mmseqs-tsv", required=True, help="MMseqs TSV file")
    parser.add_argument("-o", "--outdir", required=True, help="Output directory")
    parser.add_argument("-c", "--cores", required=True, type=int, help="Number of CPU cores")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args.ips, args.eggnog, args.rep_list, args.outdir, args.mmseqs_tsv, args.cores)
