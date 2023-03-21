process GENERATE_EXTRA_WEIGHT {

    publishDir(
        path: "${params.outdir}/additional_data/intermediate_files/",
        saveAs: { filename -> "extra_weight_table.txt" },
        mode: 'copy'
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.0'

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    path genomes_folder

    output:
    path "extra_weight_table.txt", emit: extra_weight_table

    script:
    """
    generate_extra_weight_table.py -d ${genomes_folder} -o extra_weight_table.txt
    """

    stub:
    """
    touch extra_weight_table.txt
    """
}
