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
    path name_mapping // if provided, will be used to convert the names of the genomes on the result table
    path per_genome_category // contains the information whether the genomes are MAGs or Isolates
    path per_study_genomes_category // contains the information whether the genomes per study are MAGs or Isolates

    output:
    path "extra_weight_table.txt", emit: extra_weight_table

    script:
    def args = ""
    if (per_genome_category.name != "NO_FILE_GENOME_CAT") {
        args += "-g ${per_genome_category} "
    }
    if (per_study_genomes_category.name != "NO_FILE_STUDY_CAT") {
        args += "-s ${per_study_genomes_category} "
    }
    if (name_mapping) {
        args += "-n ${name_mapping}"
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
