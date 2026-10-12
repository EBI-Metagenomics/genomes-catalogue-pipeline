process GTDBTK_ALIGN {

    container 'quay.io/biocontainers/gtdbtk:2.7.1--pyhdfd78af_0'
    containerOptions "--bind ${gtdbtk_refdata}:/opt/gtdbtk_refdata"
    
    label 'retry_twice'

    input:
    path identify_folder
    path gtdbtk_refdata
   
    output:
    path 'gtdbtk.bac120_full.user_msa.fasta.gz', optional: true, emit: gtdbtk_user_msa_bac120
    path 'gtdbtk.ar53_full.user_msa.fasta.gz', optional: true, emit: gtdbtk_user_msa_ar53

    script:
    """
    export GTDBTK_DATA_PATH=/opt/gtdbtk_refdata
    
    gtdbtk align \\
      --cpus ${task.cpus} \\
      --identify_dir ${identify_folder} \\
      --out_dir gtdbtk_result
      
    if [ -e gtdbtk_result/align/gtdbtk.bac120.user_msa.fasta.gz ]
    then
        cp gtdbtk_result/align/gtdbtk.bac120.user_msa.fasta.gz gtdbtk.bac120_full.user_msa.fasta.gz 
    fi
    
    if [ -e gtdbtk_result/align/gtdbtk.ar53.user_msa.fasta.gz ]
    then
        cp gtdbtk_result/align/gtdbtk.ar53.user_msa.fasta.gz gtdbtk.ar53_full.user_msa.fasta.gz
    fi
    """

    stub:
    """
    touch gtdbtk.bac120_full.user_msa.fasta.gz
    touch gtdbtk.ar53_full.user_msa.fasta.gz
    """
}
