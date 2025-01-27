process CHECKM2 {

    container 'quay.io/biocontainers/checkm2:1.0.1--pyh7cba7a3_0'
    
    errorStrategy = { task.attempt <= 3 ? 'retry' : 'finish' }

    input:
    path assemblies_folder
    path ch_checkm2_db

    output:
    path "checkm_quality.csv", emit: checkm_csv

    script:
    """
    change_extensions.py -i ${assemblies_folder}
    
    checkm2 predict \
    --threads ${task.cpus} \
    --input ${assemblies_folder} \
    -x fa \
    --output-directory checkm_output \
    --database_path ${ch_checkm2_db}
    
    # add in extensions #
    add_extensions_to_checkm.py -i checkm_output -d ${assemblies_folder}
    
    # to csv #
    checkm2csv.py -i checkm_output/quality_report.tsv --checkm2 > checkm_quality.csv
    """

    stub:
    """
    touch checkm_quality.csv
    """
}
