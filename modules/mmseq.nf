process MMSEQ {

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                int threshold_rounded = id_threshold * 100;
                if ( output_file.name == "mmseq_${threshold_rounded}_outdir.tar.gz" ) {
                    return "additional_data/protein_catalogue/mmseq_${threshold_rounded}_outdir.tar.gz";
                // For the .9 protein catalogue, we need to add the IPS and EGG annotations
                // This is done by PROTEIN_CATALOGUE_STORE_ANNOTATIONS 
                } else if ( output_file.extension == "gz" && id_threshold != 0.90 ) {
                    return "protein_catalogue/$filename";
                } else {
                    return null;
                }
            }
        },
        mode: 'copy'
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.mmseqs:v2'

    label 'process_bigmem'

    cpus 32
    // TODO: this needs to be dynamic
    memory "100 GB"

    input:
    file faa_file
    val id_threshold
    val cov_threshold

    output:
    path "protein_catalogue_*.fa", emit: mmseq_cluster_rep_faa
    path "protein_catalogue_*.tsv", emit: mmseq_cluster_tsv
    path "protein_catalogue_*.tar.gz", emit: mmseq_tarball
    path "*_outdir.tar.gz", emit: mmseq_outdir_tarball

    script:
    int threshold_rounded = id_threshold * 100;
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
    protein_catalogue_${threshold_rounded}.tsv \
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
    protein_catalogue_${threshold_rounded}.fa \
    --use-fasta-header

    # Create a tarball with all the mmseq files
    tar -czf mmseq_${threshold_rounded}_outdir.tar.gz mmseqs*

    tar -czf protein_catalogue_${threshold_rounded}.tar.gz protein_catalogue_${threshold_rounded}.fa protein_catalogue_${threshold_rounded}.tsv
    """

    // stub:
    // """
    // mkdir mmseqs_${id_threshold}_outdir
    // touch mmseqs_${id_threshold}_outdir/mmseqs_cluster_rep.fa
    // touch mmseqs_${id_threshold}_outdir/mmseqs_cluster_rep.tsv
    // """
}
