process EUKCC {


    container 'community.wave.seqera.io/library/python_metaeuk_pplacer_epa-ng_pruned:0b7ea587ebcad440'
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
 	${fasta} || [ \$? -eq 201 ]

    # eukcc.tsv is tab separated and looks like:
    #     fasta                      completeness  contamination  ncbi_lng
    #     /path/to/MGYG000000001.fa  95.24         1.19           2759-33154-4751
    # comma separate, drop the path and the lineage column, and set our own header
    awk '{gsub(".*/", "", \$1); \$1=\$1; OFS=","; print}' ${fasta.baseName}_eukcc_results/eukcc.tsv |\
     cut -d',' -f1,2,3 |\
     sed '1s/.*/genome,completeness,contamination/' > ${fasta.baseName}_eukcc.csv 
    """
}