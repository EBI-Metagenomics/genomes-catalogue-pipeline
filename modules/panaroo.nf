process PANAROO {

    tag "${cluster_name}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                def extension = output_file.getExtension();
                String cluster_prefix = cluster_name.substring(0, 11);
                if ( output_file.name == "gene_presence_absence.Rtab" ) {
                           "species_catalogue/${cluster_prefix}/${cluster_name}/genome/${genome_name}.${extension}";
                    return "species_catalogue/${cluster_prefix}/${cluster_name}/pan-genome/gene_presence_absence.Rtab";
                } else if ( output_file.name == "${cluster_name}.pan-genome.fna" ) {
                    return "species_catalogue/${cluster_prefix}/${cluster_name}/pan-genome/pan-genome.fna";
                } else {
                    return null;
                }
            }
        },
        mode: 'copy'
    )

    label 'process_medium'

    container 'quay.io/microbiome-informatics/genomes-pipeline.panaroo:v1'

    memory "1 GB"
    cpus 8

    input:
    tuple val(cluster_name), path(gff_files)

    output:
    tuple val(cluster_name), file("${cluster_name}_panaroo/gene_presence_absence.Rtab"), emit: panaroo_gene_presence_absence
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
    """

    // stub:
    // """
    // mkdir ${cluster_name}_panaroo
    // touch ${cluster_name}_panaroo/gene_presence_absence.Rtab
    // touch ${cluster_name}_panaroo/${cluster_name}.pan-genome.fna
    // """
}
