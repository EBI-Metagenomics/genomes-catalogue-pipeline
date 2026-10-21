process GTDBTK_IDENTIFY {

    container 'quay.io/biocontainers/gtdbtk:2.7.1--pyhdfd78af_0'
    containerOptions "--bind ${gtdbtk_refdata}:/opt/gtdbtk_refdata"
    
    label 'retry_twice'

    input:
    path genomes_fna, stageAs: "genomes_dir/*"
    val extension
    path gtdbtk_refdata
   
    output:
    path 'gtdbtk_msa', emit: gtdbtk_msa_folder

    script:
    """
    export GTDBTK_DATA_PATH=/opt/gtdbtk_refdata
    
    gtdbtk identify \
    --cpus ${task.cpus} \
    --genome_dir genomes_dir \
    --extension ${extension} \
    --out_dir gtdbtk_msa
    """

    stub:
    """
    mkdir gtdbtk_msa
    """
}
