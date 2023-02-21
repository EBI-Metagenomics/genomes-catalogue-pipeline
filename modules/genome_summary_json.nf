process GENOME_SUMMARY_JSON {

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                String cluster_rep_prefix = cluster.substring(0, 11);
                return "species_catalogue/${cluster_rep_prefix}/${cluster}/${filename}";
            }
        },
        mode:'copy'
    )

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    tuple val(cluster), path(annotated_gff), path(coverage_summary), path(cluster_rep_faa), file(pangenome_fasta), file(core_genes)
    path metadata
    val biome

    output:
    path "*.json"

    script:
    def args = ""
    if (pangenome_fasta) {
        args = args + "--pangenome-fna ${pangenome_fasta} "
    }
    if (core_genes) {
        args = args + "--core-genes ${core_genes} "
    }
    """
    generate_summary_json.py \
    --annot-cov ${coverage_summary} \
    --gff ${annotated_gff} \
    --metadata ${metadata} \
    --biome ${biome} \
    --species-faa ${cluster_rep_faa} \
    --species-name ${cluster} \
    ${args} \
    --output-file ${cluster}.json
    """

    stub:
    """
    touch ${cluster}.json
    """
}
