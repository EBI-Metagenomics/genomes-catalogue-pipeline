process BUSCO {

    tag "${fasta.baseName}"

    container 'quay.io/biocontainers/busco:5.8.0--pyhdfd78af_0'

    input:
    path fasta
    path busco_db

    output:
    path "short_summary.specific_${fasta.baseName}.txt", emit: busco_summary
    path "${fasta.baseName}", emit: busco_folder

    script:
    """
    
    busco  --offline \
            -i ${fasta} \
            -m 'genome' \
            -o ${fasta.baseName} \
            --auto-lineage-euk \
            --download_path ${busco_db} \
            -c ${task.cpus}

    #   parse and output genomes id and busco scores as csv
    result_file=\$(ls ${fasta.baseName}/short_summary.specific*.out.txt | head -n 1)

    if [ -f "\${result_file}" ]; then
        result=\$(grep 'C:' "\${result_file}" | head -n 1 | sed 's?\t??g')
        echo "${fasta.name}\t\${result}" > "short_summary.specific_${fasta.baseName}.txt"
    else
        echo "No result file found starting short_summary.specific..."
        exit 1
    fi
    """
}