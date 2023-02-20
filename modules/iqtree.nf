process IQTREE {

    tag "${output_prefix}"

    publishDir(
        saveAs: {
            filename -> "${params.outdir}/phylogenies/$filename"
        },
        mode: "copy"
    )

    container 'quay.io/biocontainers/iqtree:2.0.3--h176a8bc_0'

    cpus 16
    memory '10 GB'

    input:
    path msa_fasta_gz // gtdbtk.bac120.user_msa.fasta.gz
    val output_prefix // bac120 or ar53

    output:
    tuple val(output_prefix), path("*_iqtree.nwk"), emit: tree
    tuple val(output_prefix), path("*_alignment.faa.gz"), emit: alignment

    script:
    """
    gunzip -c ${msa_fasta_gz} > ${output_prefix}_alignment.faa

    iqtree -nt ${task.cpus} \
    -s ${output_prefix}_alignment.faa \
    --prefix iqtree.${output_prefix}

    mv iqtree.${output_prefix}.treefile ${output_prefix}_iqtree.nwk
    cp ${msa_fasta_gz} ${output_prefix}_alignment.faa.gz
    """
}