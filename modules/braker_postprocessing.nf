process BRAKER_POSTPROCESSING {

    tag "${genome_name}"

    publishDir(
        path: "${params.outdir}/species_catalogue/${cluster_prefix}/${cluster_name}/genome",
        pattern: "*.faa",
        saveAs: { filename -> is_rep ? filename : null },
        mode: 'copy',
        failOnError: true
    )

    publishDir(
        path: "${params.outdir}/species_catalogue/${cluster_prefix}/${cluster_name}/genome",
        pattern: "${masked_genome.name}",
        saveAs: { filename -> is_rep ? "${masked_genome.baseName}.fna" : null },
        mode: 'copy',
        failOnError: true
    )

    publishDir(
        path: "${params.outdir}/additional_data/intermediate_files/ffn_files",
        pattern: "*.ffn",
        mode: 'copy',
        failOnError: true
    )

    publishDir(
        path: "${params.outdir}/all_genomes/${cluster_prefix}/${cluster_name}",
        pattern: "*.gff",
        saveAs: { filename -> is_rep ? null : filename },
        mode: 'copy',
        failOnError: true
    )

    publishDir(
        path: "${params.outdir}/additional_data/mgyg_genomes",
        pattern: "${masked_genome.name}",
        saveAs: { filename -> "${masked_genome.baseName}.fna" },
        mode: 'copy',
        failOnError: true
    )

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/61/6151add1e8ca2e3eaaa65584e3ff9c551eecbfad282dc61f26b5bcbf626b4c06/data' :
    'community.wave.seqera.io/library/pip_biopython:326a6be8fb21b301' }"

    label 'process_light'

    input:
    tuple val(cluster_name), val(genome_name), path(masked_genome)
    tuple val(genome_name), path(gff3)
    tuple val(genome_name), path(proteins)
    tuple val(genome_name), path(ffn)

    output:
    tuple val(genome_name), path(masked_genome), emit: input_genome
    tuple val(genome_name), path("*.gff"), emit: renamed_gff3
    tuple val(genome_name), path("*.faa"), emit: renamed_proteins
    tuple val(genome_name), path("*.ffn"), emit: renamed_ffn

    script:
    cluster_prefix = cluster_name.substring(0, cluster_name.length() - 2)
    is_rep = (genome_name == cluster_name)
    """
    rename_and_process_braker_outputs.py \
    --gff ${gff3} \
    --ffn ${ffn} \
    --faa ${proteins} \
    --genome-fasta ${masked_genome} \
    -p renamed

    mv renamed*.gff3 ${genome_name}.gff
    mv renamed*.aa ${genome_name}.faa
    mv renamed*.codingseq ${genome_name}.ffn
    """
}
