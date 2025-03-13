process BUSCO {

    tag "${fasta.baseName}"

    container 'quay.io/biocontainers/busco:5.8.0--pyhdfd78af_0'

    input:
    path fasta
    path busco_db

    output:
    path "short_summary.specific_${fasta.baseName}.txt", emit: busco_summary

    script:
    """
    
    busco  --offline \
            -i ${fasta} \
            -m 'genome' \
            -o out \
            --auto-lineage-euk \
            --download_path ${busco_db} \
            -c ${task.cpus}

    #   parse and output genomes id and busco scores as csv
    result_file=\$(ls out/short_summary.specific*.out.txt | head -n 1)

    if [ -f "\${result_file}" ]; then
        result=\$(grep 'C:' "\${result_file}" | head -n 1)
        echo "${fasta.baseName},\${result}" > "short_summary.specific_${fasta.baseName}.txt"
    else
        echo "No result file found starting short_summary.specific..."
        exit 1
    fi
    """
}