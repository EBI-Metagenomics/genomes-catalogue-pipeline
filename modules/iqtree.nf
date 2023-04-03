process IQTREE {

    tag "${output_prefix}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> "phylogenies/$filename"
        },
        mode: "copy"
    )

    container 'quay.io/biocontainers/iqtree:2.2.0.3--hb97b32f_1'

    input:
    path msa_fasta_gz // gtdbtk.bac120.user_msa.fasta.gz
    val output_prefix // bac120 or ar53

    output:
    tuple val(output_prefix), path("*.nwk"), emit: tree
    tuple val(output_prefix), path("*.faa.gz"), emit: alignment

    script:
    """
    gunzip -c ${msa_fasta_gz} > ${output_prefix}_alignment.faa

    iqtree -T 8 \
    -s ${output_prefix}_alignment.faa \
    --prefix iqtree.${output_prefix}
    
    cp iqtree.${output_prefix}.treefile ${output_prefix}_iqtree.nwk
    cp ${msa_fasta_gz} ${output_prefix}_alignment.faa.gz
    """
}