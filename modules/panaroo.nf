process PANAROO {

    tag "${cluster_name}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                def extension = output_file.getExtension();
                String cluster_prefix = cluster_name.substring(0, cluster_name.length() - 2);
                if ( output_file.name == "gene_presence_absence.Rtab" ) {
                           "species_catalogue/${cluster_prefix}/${cluster_name}/genome/${genome_name}.${extension}";
                    return "species_catalogue/${cluster_prefix}/${cluster_name}/pan-genome/gene_presence_absence.Rtab";
                } else if ( output_file.name == "${cluster_name}.pan-genome.fna" ) {
                    return "species_catalogue/${cluster_prefix}/${cluster_name}/pan-genome/pan-genome.fna";
                } else if ( output_file.name == "${cluster_name}_panaroo.tar.gz" ) {
                    return "additional_data/panaroo_output/${cluster_name}_panaroo.tar.gz";
                } else if ( output_file.name == "gene_presence_absence.csv" ) {
                    return "additional_data/panaroo_output/gene_presence_absence.csv";
                } else {
                    return null;
                }
            }
        },
        mode: 'copy',
        failOnError: true
    )

    label 'process_medium'

    container 'quay.io/biocontainers/panaroo:1.3.2--pyhdfd78af_0'

    input:
    tuple val(cluster_name), path(gff_files)

    output:
    tuple val(cluster_name), path("${cluster_name}_panaroo.tar.gz"), emit: panaroo_tarball_output
    tuple val(cluster_name), file("${cluster_name}_panaroo/gene_presence_absence.Rtab"), emit: panaroo_gene_presence_absence
    tuple val(cluster_name), file("${cluster_name}_panaroo/gene_presence_absence.csv"), emit: panaroo_gene_presence_absence_csv
    tuple val(cluster_name), file("${cluster_name}_panaroo/${cluster_name}.pan-genome.fna"), emit: panaroo_pangenome_fna

    script:
    """
    panaroo \
    -t ${task.cpus} \
    -i ${gff_files.join( ' ' )} \
    -o ${cluster_name}_panaroo \
    --clean-mode strict \
    --merge_paralogs \
    --core_threshold 0.90 \
    --threshold 0.90 \
    --family_threshold 0.5 \
    --no_clean_edges

    mv ${cluster_name}_panaroo/pan_genome_reference.fa ${cluster_name}_panaroo/${cluster_name}.pan-genome.fna

    tar -czf ${cluster_name}_panaroo.tar.gz ${cluster_name}_panaroo
    """

    // stub:
    // """
    // mkdir ${cluster_name}_panaroo
    // touch ${cluster_name}_panaroo/gene_presence_absence.Rtab
    // touch ${cluster_name}_panaroo/${cluster_name}.pan-genome.fna
    // """
}
