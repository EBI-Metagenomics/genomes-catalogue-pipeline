process GENOME_SUMMARY_JSON {

    publishDir "${params.outdir}/${params.catalogue_name}_metadata/${cluster}/", mode:'copy'

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    tuple val(cluster), path(annotated_gff), path(coverage_summary), path(cluster_rep_faa), path(pangenome_fasta), path(core_genes)
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
