process CHECKM2 {

    container 'quay.io/biocontainers/checkm2:1.1.0--pyh7e72e81_1'
    
    errorStrategy = { task.attempt <= 3 ? 'retry' : 'finish' }

    input:
    path(genomes, stageAs: 'assemblies_folder/*')
    path ch_checkm2_db

    output:
    path "checkm_quality.csv", emit: checkm_csv

    script:
    """
    change_extensions.py -i assemblies_folder
    
    mkdir -p checkm_tmp
    
    checkm2 predict \
    --threads ${task.cpus} \
    --input assemblies_folder \
    -x fa \
    --output-directory checkm_output \
    --database_path ${ch_checkm2_db} \
    --tmpdir checkm_tmp
    
    # make sure none of diamond output files are empty - CheckM2 sometimes fails on diamond silently
    for F in checkm_output/diamond_output/*.tsv; do
        if [ ! -s "\$F" ]; then
            echo "Empty DIAMOND output file detected in CheckM2 results. Results will be unreliable."
            exit 1
        fi
    done
    
    # add in extensions #
    add_extensions_to_checkm.py -i checkm_output -d assemblies_folder
    
    # to csv #
    checkm2csv.py -i checkm_output/quality_report.tsv --checkm2 > checkm_quality.csv
    """

    stub:
    """
    touch checkm_quality.csv
    """
}
