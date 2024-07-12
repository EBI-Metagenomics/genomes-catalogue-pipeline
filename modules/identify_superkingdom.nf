process IDENTIFY_SUPERKINGDOM {
   
    publishDir(
        path: "${params.outdir}",
        pattern: "detected_superkingdoms",
        saveAs: { "additional_data/intermediate_files/detected_superkingdoms" },
        mode: "copy",
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    input:
    path gtdb_summary_tsv

    output:
    path "detected_superkingdoms", emit: detected_superkingdoms

    script:
    """
    identify_superkingdom.py -i ${gtdb_summary_tsv}
    """

    stub:
    """
    mkdir detected_superkingdoms
    touch detected_superkingdoms/MGYG000000001_Bacteria.txt
    """
}
