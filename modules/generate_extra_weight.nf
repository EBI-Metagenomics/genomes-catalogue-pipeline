process GENERATE_EXTRA_WEIGHT {

    publishDir(
        path: "${params.outdir}/additional_data/intermediate_files/",
        saveAs: { filename -> "extra_weight_table.txt" },
        mode: 'copy'
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    label 'process_light'

    input:
    path genomes_folder
    path per_genome_category // contains the information whether the genomes are MAGs or Isolates
    path per_study_genomes_category // contains the information whether the genomes per study are MAGs or Isolates
    path name_mapping // if provided, will be used to convert the names of the genomes on the result table

    output:
    path "extra_weight_table.txt", emit: extra_weight_table

    script:
    def args = ""
    if (genomes_info) {
        args += "-g ${per_genome_category}"
    }
    if (study_info) {
        args += "-s ${per_study_genomes_category}"
    }
    if (rename_mapping) {
        args += "-n ${rename_mapping}"
    }
    """
    generate_extra_weight_table.py \
    -d ${genomes_folder} \
    -o extra_weight_table.txt ${args}
    """

    stub:
    """
    touch extra_weight_table.txt
    """
}
