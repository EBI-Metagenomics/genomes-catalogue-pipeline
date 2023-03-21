process MERGE_NCBI_ENA {

    label 'process_light'

    container 'quay.io/biocontainers/python:3.9--1'

    memory "500 MB"
    cpus 1

    input:
    path ncbi_genomes
    path ena_genomes
    file ncbi_genomes_checkm
    file ena_genomes_checkm

    output:
    path "merged_genomes", emit: genomes
    path "merged_genomes.csv", emit: merged_checm_csv

    script:
    """
    merge_ncbi_ena.py --ncbi ${ncbi_genomes} \
    --ncbi-csv ${ncbi_genomes_checkm} \
    --ena ${ena_genomes} \
    --ena-csv ${ena_genomes_checkm} \
    --outname merged_genomes
    """

    stub:
    """
    mkdir merged_genomes
    touch merged_genomes.csv
    """
}
