process CHECKM {

    publishDir "${params.outdir}/checkm", mode: "copy"

    container 'quay.io/microbiome-informatics/genomes-pipeline.checkm:v1'

    label 'process_medium'

    input:
    path assemblies_folder

    output:
    path "checkm_quality.csv", emit: checkm_csv

    script:
    """
    checkm lineage_wf -t ${task.cpus} -x fa --tab_table ${assemblies_folder} checkm_output

    # to csv #
    checkm2csv.py -i checkm_output > checkm_quality.csv
    """

    stub:
    """
    touch checkm_quality.csv
    """
}
