process BRAKER {
    tag "${genome.baseName}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://teambraker/braker3:latest' :
        'teambraker/braker3:latest' }"


    input:
    path(masked_genome) // genome fasta with softmasked repeat
    tuple val(cluster_name), path(genome), path(proteins) // tuple with original genome fasta (for naming) and protein evidence

    output:
    tuple val(cluster_name), path("${genome.baseName}_braker/*.gtf"), emit: gtf
    tuple val(cluster_name), path("${genome.baseName}_braker/*.gff3"), emit: gff3
    tuple val(cluster_name), path("${genome.baseName}_braker/*.aa"), emit: proteins
    tuple val(cluster_name), path("${genome.baseName}_braker/*.codingseq"), emit: ffn
    tuple val(cluster_name), path("${genome.baseName}_braker/*.map"), emit: headers_map
    path "versions.yml" , emit: versions

    script:
    def args = ""
    if (proteins.name != "NO_PROTEINS.faa") {
        args += "--prot_seq ${proteins} "
    }
    """
    braker.pl \\
        $args \\
        --genome ${masked_genome} \\
        --threads $task.cpus \\
        --workingdir "${genome.baseName}_braker" \\
        --min_contig=1500 \\
        --gff3

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        braker: \$(echo \$(braker.pl --version) | sed -E 's/[^0-9]*([0-9]+\\.[0-9]+\\.[0-9]+).*/\\1/')
    END_VERSIONS
    """
}
