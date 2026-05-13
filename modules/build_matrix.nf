process BUILD_MATRIX {
    tag "${cluster_name}"
    label 'process_single'

    publishDir(
        path: "${params.outdir}",
        saveAs: { filename -> 
            def output_file = file(filename);
            def extension = output_file.getExtension();
            String cluster_prefix = cluster_name.substring(0, cluster_name.length() - 2);
            if ( output_file.name == "gene_presence_absence.Rtab" ) {
                return "species_catalogue/${cluster_prefix}/${cluster_name}/pan-genome/gene_presence_absence.Rtab";
            } else if ( output_file.name == "${cluster_name}.pan-genome.fna" ) {
                return "species_catalogue/${cluster_prefix}/${cluster_name}/pan-genome/pan-genome.fna";
            } else if ( output_file.name == "gene_presence_absence.csv" ) {
                return "species_catalogue/${cluster_prefix}/${cluster_name}/pan-genome/gene_presence_absence.csv";
            } else {
                return null;
            }
        },
        mode: 'copy',
        failOnError: true
    )

    conda "conda-forge::pandas"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'quay.io/biocontainers/pandas:2.2.1' }"

    input:
    tuple val(cluster_name), path(cluster_tsv), path(rep_seq_fasta), path(gff_files)

    output:
    tuple val(cluster_name), path("gene_presence_absence.Rtab"), emit: rtab
    tuple val(cluster_name), path("gene_presence_absence.csv"),  emit: csv
    tuple val(cluster_name), path("*pan-genome.fna"),            emit: fna

    script:
    def prefix = task.ext.prefix ?: "${cluster_name}"
    """
    make_presence_absence_matrix.py \\
        --mmseqs_clusters ${cluster_tsv} \\
        --gff ${gff_files.join(' ')} \\
        --rep_seq ${rep_seq_fasta} \\
        --output gene_presence_absence.Rtab \\
        --output_csv gene_presence_absence.csv \\
        --output_fna ${prefix}.pan-genome.fna
    """
}

