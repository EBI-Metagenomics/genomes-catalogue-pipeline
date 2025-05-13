/*
 * SMBGC Annotation using Neural Networks Trained on Interpro Signatures
*/
process SANNTIS {

    tag "${cluster_name}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                String cluster_prefix = cluster_name.substring(0, cluster_name.length() - 2);
                return "species_catalogue/${cluster_prefix}/${cluster_name}/genome/${output_file.getSimpleName()}.gff"
            }
        },
        mode: 'copy',
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/sanntis:0.9.3.2'
    
    errorStrategy = { task.attempt <= 2 ? 'retry' : 'finish' }

    input:
    tuple val(cluster_name), path(interproscan_tsv), path(prokka_gbk)

    output:
    tuple val(cluster_name), path("*_sanntis.gff"), emit: sanntis_gff

    script:
    if (interproscan_tsv.extension == "gz") {
        """
        gunzip -c ${interproscan_tsv} > interproscan.tsv
        sanntis \\
        --ip-file interproscan.tsv \\
        --outfile ${cluster_name}_sanntis.gff \\
        --cpu ${task.cpus} \\
        ${prokka_gbk}
        """
    } else {
        """
        sanntis \\
        --ip-file ${interproscan_tsv} \\
        --outfile ${cluster_name}_sanntis.gff \\
        --cpu ${task.cpus} \\
        ${prokka_gbk}
        """
    }
}
