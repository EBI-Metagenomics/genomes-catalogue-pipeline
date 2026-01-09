process EUKCC {


    container 'quay.io/microbiome-informatics/eukcc:2.1.3'
    tag "${fasta.baseName}"
    
    input:
    path fasta
    path eukcc_db
    
    output:
    path "${fasta.baseName}_eukcc.csv", emit: eukcc_result
    
    script:
    """
    eukcc single \
	--out ${fasta.baseName}_eukcc_results \
	--threads ${task.cpus} \
	--db ${eukcc_db} \
 	${fasta}

    result_file=\$(ls *eukcc_results/eukcc.csv | head -n1)

    #comma separate, change header, remove tax lineage column
    awk '{gsub(".*/", "", \$1); \$1=\$1; OFS=","; print}' \${result_file} |\
     cut -d',' -f1,2,3 |\
     sed '1s/.*/genome,completeness,contamination/' > ${fasta.baseName}_eukcc.csv 

    """
       
}