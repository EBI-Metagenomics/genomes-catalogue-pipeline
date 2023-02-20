/*
 * SMBGC Annotation using Neural Networks Trained on Interpro Signatures
*/
process SANNTIS {

    tag "${cluster_name}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                String rep_name = filename.tokenize('.')[0];
                String cluster_prefix = cluster_name.substring(0, 11);
                return "species_catalogue/${cluster_prefix}/${rep_name}/genome/$filename"
            }
        },
        mode: 'copy'
    )

    container 'quay.io/microbiome-informatics/sanntis:0.1.0'

    input:
    tuple val(cluster_name), path(interproscan_tsv), path(prokka_gbk)

    output:
    tuple val(cluster_name), path("*_sanntis.gff"), emit: sanntis_gff

    script:
    if (interproscan_tsv.extension == "gz") {
        """
        gunzip -c ${interproscan_tsv} > interproscan.tsv 
        sanntis \
        --ip-file interproscan.tsv \
        --outfile ${cluster_name}_sanntis.gff \
        ${prokka_gbk}
        """
    } else {
        """
        sanntis \
        --ip-file ${interproscan_tsv} \
        --outfile ${cluster_name}_sanntis.gff \
        ${prokka_gbk}
        """
    }
}