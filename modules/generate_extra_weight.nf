process GENERATE_EXTRA_WEIGHT {

    publishDir "results/extra_weight_table", mode: 'copy'

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

    // stub:
    // """
    // touch extra_weight_table.txt
    // """
}
