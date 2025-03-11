process BUSCO {

    label 'process_medium'
    tag "${fasta.baseName}"

    container 'quay.io/biocontainers/busco:5.8.0--pyhdfd78af_0'

    input:
    path fasta
    path busco_db

    output:
    path "short_summary.specific*.txt", emit: busco_summary

    script:
    """
    busco  --offline \
            -i ${fasta} \
            -m 'genome' \
            -o out \
            --auto-lineage-euk \
            --download_path ${busco_db} \
            -c ${task.cpus}

    mv out/short_summary.specific*.out.txt "short_summary.specific_${fasta.baseName}.txt"

    """
}