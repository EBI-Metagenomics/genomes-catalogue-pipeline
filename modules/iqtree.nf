process IQTREE {

    tag "${output_prefix}"

    publishDir "${params.outdir}/phylogenies/iqtree", pattern: "*_iqtree.nwk", mode: "copy"
    publishDir "${params.outdir}/phylogenies/iqtree", pattern: "*_alignment.faa.gz", mode: "copy"

    container 'quay.io/biocontainers/iqtree:2.0.3--h176a8bc_0'

    cpus 4 // TODO: change to 16
    memory '5 GB'

    input:
    path msa_fasta_gz // gtdbtk.bac120.user_msa.fasta.gz
    val output_prefix // bac120 or ar53

    output:
    tuple val(output_prefix), path("*_iqtree.nwk"), emit: tree

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