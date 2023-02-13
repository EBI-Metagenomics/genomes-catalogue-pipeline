process GENOME_SUMMARY_JSON {

    publishDir "${params.outdir}/${param.catalogue_name}_metadata/${cluster}/", mode:'copy'

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    tuple val(cluster), file(annotated_gff), file(coverage_summary), file(cluster_rep_faa), file(pangenome_fasta), file(core_genes)
    file metadata
    val biome

    output:
    file "*.json"

    script:
    def args = ""
    if (core_genes) {
        args = args + "--core-genes ${core_genes} "
    }
    if (pangenome_fasta) {
        args = args + "--pangenome-fna ${pangenome_fasta} "
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

    // stub:
    // """
    // touch ${cluster}.json
    // """
}
