process POSTPROCESSING_GENE_CALLER {

    tag "${genome_name}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/61/6151add1e8ca2e3eaaa65584e3ff9c551eecbfad282dc61f26b5bcbf626b4c06/data' :
    'community.wave.seqera.io/library/pip_biopython:326a6be8fb21b301' }"

    label 'process_light'

    input:
    val genome_name
    val cluster_name
    path gff
    path faa, stageAs: "input/*"
    path ffn, stageAs: "input/*"
    path genome, stageAs: "genome_input/*"

    output:
    tuple val(genome_name), path("${genome_name}.gff"), emit: gff
    tuple val(genome_name), path("${genome_name}.faa"), emit: faa
    tuple val(genome_name), path("${genome_name}.ffn"), emit: ffn
    tuple val(genome_name), path("${genome_name}.fna"), emit: genome

    script:
    """
    rename_and_process_gene_callers_outputs.py \\
        --gff ${gff} \\
        --ffn ${ffn} \\
        --faa ${faa} \\
        --genome-fasta ${genome} \\
        -p ${genome_name}

    # Necessary to publish genomes into additional_data/mgyg_genomes and species_catalogue folders
    cp ${genome} ${genome_name}.fna
    """

    stub:
    """
    touch ${genome_name}.gff ${genome_name}.faa ${genome_name}.ffn ${genome_name}.fna
    """
}
