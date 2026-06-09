process METAEUK {

    tag "${genome_name}"

    publishDir(
        path: "${params.outdir}/additional_data/intermediate_files/metaeuk/",
        saveAs: { filename -> file(filename).name },
        mode: 'copy',
        failOnError: true
    )

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/metaeuk:7.bba0d80--pl5321h6a68c12_0' :
        'quay.io/biocontainers/metaeuk:7.bba0d80--pl5321h6a68c12_0' }"

    input:
    tuple val(genome_name), path(masked_genome), path(protein_evidence)

    output:
    tuple val(genome_name), path("*.metaeuk.gff"), emit: gff
    tuple val(genome_name), path("*.metaeuk.faa"), emit: proteins
    tuple val(genome_name), path("*.metaeuk.ffn"), emit: nucleotide

    script:
    """
    metaeuk easy-predict \\
        ${masked_genome} \\
        ${protein_evidence} \\
        ${genome_name}.metaeuk \\
        tmp_${genome_name}

    mv ${genome_name}.metaeuk.fas ${genome_name}.metaeuk.faa
    mv ${genome_name}.metaeuk.codon.fas ${genome_name}.metaeuk.ffn
    """

    stub:
    """
    touch ${genome_name}.metaeuk.gff ${genome_name}.metaeuk.faa ${genome_name}.metaeuk.ffn
    """
}
