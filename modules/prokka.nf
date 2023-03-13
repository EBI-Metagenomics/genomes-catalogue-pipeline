process PROKKA {

    tag "${cluster_name}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                String genome_name = fasta.baseName;
                String cluster_prefix = cluster_name.substring(0, 11);
                def is_rep = genome_name == cluster_name;

                if ( is_rep && ( output_file.extension == "faa" || output_file.extension == "fna" ) ) {
                    return "species_catalogue/${cluster_prefix}/${genome_name}/genome/${genome_name}.${output_file.extension}";
                /* TODO: debuging. */
                // For non-reps we use the prokka gff file
                // } else if ( output_file.extension == "gff" ) {
                    // return "species_catalogue/${cluster_prefix}/${genome_name}/genome/${genome_name}.${output_file.extension}";
                // Used for sanity check purposes
                } else if ( output_file.extension == "ffn" ) {
                    return "additional_data/intermediate_files/ffn_files/${output_file.baseName}.${output_file.extension}";
                // Store the species reps gbk files //
                } else if ( output_file.extension == "gbk" && is_rep ) {
                    return "additional_data/prokka_gbk_species_reps/${output_file.baseName}.${output_file.extension}";
                }
            }
        },
        mode: "copy"
    )
    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                if (output_file.extension == "fna") {
                    return "additional_data/mgyg_genomes/${fasta.baseName}.${output_file.extension}";
                }
                return null;
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
