process FUNCTIONAL_ANNOTATION_SUMMARY {

    label 'process_light'

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> "species_catalogue/${cluster.substring(0, 11)}/${cluster}/genome/$filename"
        },
        mode: "copy"
    )

    container 'quay.io/biocontainers/python:3.9--1'

    memory '1 GB'
    cpus 1

    input:
    tuple val(cluster), file(cluster_rep_faa), file(ips_annotation_tsvs), file(eggnog_annotation_tsvs)
    file kegg_classes

    output:
    tuple val(cluster), path("*_annotation_coverage.tsv"), emit: coverage
    tuple val(cluster), path("*_kegg_classes.tsv"), emit: kegg_classes
    tuple val(cluster), path("*_kegg_modules.tsv"), emit: kegg_modules
    tuple val(cluster), path("*_cazy_summary.tsv"), emit: cazy_summary
    tuple val(cluster), path("*_cog_summary.tsv"), emit: cog_summary

    script:
    """
    functional_annotations_summary.py \
    -f ${cluster_rep_faa} \
    -i ${ips_annotation_tsvs} \
    -e ${eggnog_annotation_tsvs} \
    -k ${kegg_classes}
    """

    stub:
    """
    touch ${cluster_rep_faa.baseName}_annotation_coverage.tsv
    touch ${cluster_rep_faa.baseName}_kegg_classes.tsv
    touch ${cluster_rep_faa.baseName}_kegg_modules.tsv
    touch ${cluster_rep_faa.baseName}_cazy_summary.tsv
    touch ${cluster_rep_faa.baseName}_cog_summary.tsv
    """
}
