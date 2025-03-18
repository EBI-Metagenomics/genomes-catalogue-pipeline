process GROUP_GENOME_PROTEINS {

    tag "${fasta.baseName}"

    label 'process_light'

    input:
    tuple val(cluster_name), path(fasta)
    path(mapping_file)
    path(protein_csv)

    output:
    tuple val(cluster_name), path(fasta), path("*faa"), emit: tuple_with_proteins

    script:
    """
    original_name=\$(grep ${fasta.baseName} ${mapping_file} | head -n1 | cut -f1)

    protein_file=\$(grep "\${original_name}" ${protein_csv} | head -n1 | cut -d ',' -f2)

    if [ -z "\${protein_file}" ]; then
        echo "NO PROTEINS" > NO_PROTEINS.faa
    else 
        cp "\${protein_file}" .
    fi
    """
}
