process MERGE_GENE_PREDICTIONS {

    tag "${genome_name}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/61/6151add1e8ca2e3eaaa65584e3ff9c551eecbfad282dc61f26b5bcbf626b4c06/data' :
    'community.wave.seqera.io/library/pip_biopython:326a6be8fb21b301' }"

    label 'process_light'

    input:
    tuple val(genome_name),
        path(braker_gff),
        path(braker_faa),
        path(braker_ffn),
        path(metaeuk_gff),
        path(metaeuk_faa),
        path(metaeuk_ffn)

    output:
    tuple val(genome_name), path("*.merged.gff"), emit: gff
    tuple val(genome_name), path("*.merged.faa"), emit: faa
    tuple val(genome_name), path("*.merged.ffn"), emit: ffn

    script:
    """
    merge_gene_predictions.py \\
        --gff1 ${braker_gff} \\
        --faa1 ${braker_faa} \\
        --ffn1 ${braker_ffn} \\
        --gff2 ${metaeuk_gff} \\
        --faa2 ${metaeuk_faa} \\
        --ffn2 ${metaeuk_ffn} \\
        --output-prefix ${genome_name}.merged
    """

    stub:
    """
    touch ${genome_name}.merged.gff ${genome_name}.merged.faa ${genome_name}.merged.ffn
    """
}
