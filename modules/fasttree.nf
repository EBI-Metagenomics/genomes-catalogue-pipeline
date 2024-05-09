process FASTTREE {

    tag "${output_prefix}"

    container 'quay.io/biocontainers/fasttree:2.1.11--h031d066_3'

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> "phylogenies/$filename"
        },
        mode: "copy",
        failOnError: true
    )

    input:
    path msa_fasta_gz // gtdbtk.bac120.user_msa.fasta.gz
    val output_prefix // bac120 or ar53

    output:
    tuple val(output_prefix), path("*.nwk"), emit: tree
    tuple val(output_prefix), path("*.faa.gz"), emit: alignment

    script:
    """
    gunzip -c ${msa_fasta_gz} > ${output_prefix}_alignment.faa

    FastTree -out ${output_prefix}_fasttree.nwk ${output_prefix}_alignment.faa

    cp ${msa_fasta_gz} ${output_prefix}_alignment.faa.gz
    """
}
