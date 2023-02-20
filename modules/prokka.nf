process PROKKA {

    tag "${cluster_name}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                if (filename.contains(".faa") or filename.contains(".fna")) {
                    String rep_name = filename.tokenize('.')[0];
                    String cluster_prefix = cluster_name.substring(10);
                    return "species_catalogue/${cluster_prefix}/${rep_name}/genome/$filename"
                } else {
                    return null;
                }
            }
        },
        mode: "copy"
    )

    container "quay.io/biocontainers/prokka:1.14.6--pl526_0"

    label 'process_light'

    memory "1 GB"
    cpus 8

    input:
    tuple val(cluster_name), path(fasta)

    output:
    tuple val(cluster_name), file("${fasta.baseName}_prokka/${fasta.baseName}.gff"), emit: gff
    tuple val(cluster_name), file("${fasta.baseName}_prokka/${fasta.baseName}.faa"), emit: faa
    tuple val(cluster_name), file("${fasta.baseName}_prokka/${fasta.baseName}.fna"), emit: fna
    tuple val(cluster_name), file("${fasta.baseName}_prokka/${fasta.baseName}.gbk"), emit: gbk
    tuple val(cluster_name), file("${fasta.baseName}_prokka/${fasta.baseName}.ffn"), emit: ffn

    script:
    """
    cat ${fasta} | tr '-' ' ' > ${fasta.baseName}_cleaned.fasta

    prokka ${fasta.baseName}_cleaned.fasta \
    --cpus ${task.cpus} \
    --kingdom 'Bacteria' \
    --outdir ${fasta.baseName}_prokka \
    --prefix ${fasta.baseName} \
    --force \
    --locustag ${fasta.baseName}
    """

    // stub:
    // """
    // mkdir "${fasta.baseName}_prokka"
    // touch "${fasta.baseName}_prokka/${fasta.baseName}.gff"
    // touch "${fasta.baseName}_prokka/${fasta.baseName}.faa"

    // touch "${fasta.baseName}_prokka/${fasta.baseName}.fna"
    // echo ">test\nACGT" > "${fasta.baseName}_prokka/${fasta.baseName}.fna"

    // touch "${fasta.baseName}_prokka/${fasta.baseName}.gbk"
    // touch "${fasta.baseName}_prokka/${fasta.baseName}.ffn"
    // """
}
