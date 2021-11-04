import numpy as np
from itertools import groupby
import sys

# modified from https://github.com/MikeTrizna/assembly_stats/blob/master/assembly_stats/assembly_stats.py


def run_assembly_stats(infilename):
    contig_lens, gc_cont = read_genome(infilename)
    contig_stats = calculate_stats(contig_lens, gc_cont)
    return contig_stats


def fasta_iter(fasta_file):
    fh = open(fasta_file)
    fa_iter = (x[1] for x in groupby(fh, lambda line: line[0] == ">"))
    for header in fa_iter:
        # drop the ">"
        header = next(header)[1:].strip()
        # join all sequence lines to one.
        seq = "".join(s.upper().strip() for s in next(fa_iter))
        yield header, seq


def read_genome(fasta_file):
    gc = 0
    total_len = 0
    contig_lens = []
    for _, seq in fasta_iter(fasta_file):
        if "NN" in seq:
            contig_list = seq.split("NN")
        else:
            contig_list = [seq]
        for contig in contig_list:
            if len(contig):
                gc += contig.count('G') + contig.count('C')
                total_len += len(contig)
                contig_lens.append(len(contig))
    gc_cont = (gc / total_len) * 100
    return contig_lens, gc_cont


def calculate_stats(seq_lens, gc_cont):
    stats = {}
    seq_array = np.array(seq_lens)
    stats['N_contigs'] = seq_array.size
    stats['GC_content'] = gc_cont
    sorted_lens = seq_array[np.argsort(-seq_array)]
    stats['Length'] = int(np.sum(sorted_lens))
    csum = np.cumsum(sorted_lens)
    level = 50
    nx = int(stats['Length'] * (level / 100))
    csumn = min(csum[csum >= nx])
    l_level = int(np.where(csum == csumn)[0])
    n_level = int(sorted_lens[l_level])
    stats['N' + str(level)] = n_level
    return stats


if __name__ == "__main__":
    infilename = sys.argv[1]
    contig_stats = run_assembly_stats(infilename)
    print(contig_stats)