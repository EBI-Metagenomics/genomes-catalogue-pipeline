process MMSEQ {

    // TODO: add tar.gz step
    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                if (filename.contains(".tar.gz")) {
                    int threshold = id_threshold * 100;
                    return "protein_catalogue/protein_catalogue-${threshold}.tar.gz"
                }
            }
        },
        mode: 'copy'
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.mmseqs:v2'

    // label 'process_bigmem'

    cpus 32
    // TODO: this needs to be dynamic
    memory "100 GB"

    input:
    file faa_file
    val id_threshold
    val cov_threshold

    output:
    path "*", type: "dir", emit: mmseq_outdir
    path "mmseqs_cluster_rep.fa", emit: mmseq_cluster_rep_faa
    path "mmseqs_cluster.tsv", emit: mmseq_cluster_tsv

    script:
    """
    timestamp() {
        date +"%H:%M:%S"
    }
    echo "\$(timestamp) [mmseqs script] Creating MMseqs database"

    mmseqs createdb ${faa_file} mmseqs.db

    echo "\$(timestamp) [mmseqs script] Clustering MMseqs with linclust with option -c ${id_threshold}"

    mmseqs linclust \
    mmseqs.db \
    mmseqs_cluster.db \
    mmseqs-tmp --min-seq-id ${id_threshold} \
    --threads ${task.cpus} \
    -c ${cov_threshold} \
    --cov-mode 1 \
    --cluster-mode 2 \
    --kmer-per-seq 80

    echo "\$(timestamp) [mmseqs script] Parsing output to create FASTA file of all sequences"

    mmseqs createseqfiledb mmseqs.db \
    mmseqs_cluster.db \
    mmseqs_cluster_seq \
    --threads ${task.cpus}

    mmseqs result2flat mmseqs.db \
    mmseqs.db \
    mmseqs_cluster_seq \
    mmseqs_cluster.fa

    echo "\$(timestamp) [mmseqs script] Parsing output to create TSV file with cluster membership"

    mmseqs createtsv mmseqs.db \
    mmseqs.db \
    mmseqs_cluster.db \
    mmseqs_cluster.tsv \
    --threads ${task.cpus}

    echo "\$(timestamp) [mmseqs script] Parsing output to create FASTA file of representative sequences"

    mmseqs result2repseq \
    mmseqs.db \
    mmseqs_cluster.db \
    mmseqs_cluster_rep \
    --threads ${task.cpus}

    mmseqs result2flat \
    mmseqs.db \
    mmseqs.db \
    mmseqs_cluster_rep \
    mmseqs_cluster_rep.fa \
    --use-fasta-header
    """

    // stub:
    // """
    // mkdir mmseqs_${id_threshold}_outdir
    // touch mmseqs_${id_threshold}_outdir/mmseqs_cluster_rep.fa
    // touch mmseqs_${id_threshold}_outdir/mmseqs_cluster_rep.tsv
    // """
}
