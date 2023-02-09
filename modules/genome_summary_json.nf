process GENOME_SUMMARY_JSON {

    publishDir "results/genome_jsons", mode:'copy'

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    tuple val(cluster), file(annotated_gff), file(coverage_summary), file(cluster_faa), file(pangenome_fasta), file(core_genes)
    file metadata
    val biome

    output:
    file "*.json"

    script:
    """
    generate_summary_json.py \
    --annot-cov ${coverage_summary} \
    --gff ${annotated_gff} \
    --metadata ${metadata} \
    --biome ${biome} \
    --species-faa ${cluster_faa} \
    --core-genes ${core_genes} \
    --pangenome-fna ${pangenome_fasta} \
    --species-name ${cluster} \
    --output-file ${cluster}.json
    """

    // stub:
    // """
    // touch ${cluster}.json
    // """
}
