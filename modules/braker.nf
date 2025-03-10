process BRAKER {
    tag "$meta.id"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://teambraker/braker3:latest' :
        'teambraker/braker3:latest' }"


    input:
    tuple val(meta), path(genome)
    path faa
    path bam
    path gff
    val species

    output:
    tuple val(meta), path("${prefix}/*.gtf"), emit: gtf
    tuple val(meta), path("${prefix}/*.gff3"), emit: gff3
    tuple val(meta), path("${prefix}/*.aa"), emit: proteins
    tuple val(meta), path("${prefix}/*.codingseq"), emit: ffn
    tuple val(meta), path("${prefix}/*.map"), emit: headers_map
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def species = species ? "--species ${species}" : ''
    def accepted_hits = bam ? "--bam ${bam}" : ''
    def proteins = faa ? "--prot_seq ${faa}" : ''
    def hints = gff ? "--hints ${gff}" : ''
    """
    braker.pl \\
        $args \\
        --genome ${genome} \\
        $species \\
        $accepted_hits \\
        $proteins \\
        $hints \\
        --threads $task.cpus \\
        --workingdir "${prefix}_braker" \\
        --min_contig=1500 \\
        --gff3

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        braker: \$(echo \$(braker.pl --version) | sed -E 's/[^0-9]*([0-9]+\\.[0-9]+\\.[0-9]+).*/\\1/')
    END_VERSIONS
    """
}
