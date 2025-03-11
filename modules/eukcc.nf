process EUKCC {

    container 'quay.io/microbiome-informatics/eukcc:2.1.3'
    tag "${fasta.baseName}"
    
    input:
    path fasta
    path eukcc_db
    
    output:
    path "${fasta.baseName}_eukcc_results/eukcc.csv", emit: eukcc_result
    
    script:
    """
	single \
	--out ${fasta.baseName}_eukcc_results \
	--threads ${task.cpus} \
	--db ${eukcc_db} \
 	${fasta}
    """
    
    
    
}