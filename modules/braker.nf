process BRAKER {
    tag "${genome_name}"

    container "docker.io/teambraker/braker3:v3.0.8"

    input:
    tuple val(genome_name), path(masked_genome) // genome fasta with softmasked repeat
    tuple val(genome_name), path(protein_evidence) // tuple with original genome fasta (for naming) and protein evidence

    output:
    tuple val(genome_name), path("${genome_name}_braker/*.gtf"), emit: gtf
    tuple val(genome_name), path("${genome_name}_braker/*.gff3"), emit: gff3
    tuple val(genome_name), path("${genome_name}_braker/*.aa"), emit: proteins
    tuple val(genome_name), path("${genome_name}_braker/*.codingseq"), emit: ffn
    tuple val(genome_name), path("${genome_name}_braker/*.map"), emit: headers_map
    path "versions.yml" , emit: versions

    script:
    def args = ""
    if (protein_evidence.name != "NO_PROTEINS.faa") {
        args += "--prot_seq ${protein_evidence} "
    }
    """
    # Make HOME unique for this task; AUGUSTUS will then use \$HOME/.augustus
    export HOME="\$PWD/.home"
    mkdir -p "\$HOME"

    braker.pl \\
        $args \\
        --genome ${masked_genome} \\
        --species ${genome_name} \\
        --threads $task.cpus \\
        --workingdir "${genome_name}_braker" \\
        --min_contig=1500 \\
        --gff3

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        braker: \$(echo \$(braker.pl --version) | sed -E 's/[^0-9]*([0-9]+\\.[0-9]+\\.[0-9]+).*/\\1/')
    END_VERSIONS
    """
}
