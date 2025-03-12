process MERGE_NCBI_ENA {

    label 'process_light'

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    input:
    path ncbi_genomes
    path ena_genomes
    file ncbi_genomes_checkm
    file ena_genomes_checkm

    output:
    path "merged_genomes", emit: genomes
    path "merged_genomes.csv", emit: merged_checkm_csv

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

process MERGE_NCBI_ENA_EUKS {

    label 'process_light'

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    input:
    path ncbi_genomes
    path ena_genomes
    file ncbi_genomes_busco
    file ena_genomes_busco
    file ncbi_genomes_eukcc
    file ena_genomes_eukcc

    output:
    path "merged_genomes", emit: genomes
    path "merged_genomes_busco.csv", emit: merged_busco_csv
    path "merged_genomes_eukcc.csv", emit: merged_eukcc_csv

    script:
    """
    merge_ncbi_ena.py --ncbi ${ncbi_genomes} \
    --ena ${ena_genomes} \
    --ncbi-busco-csv ${ncbi_genomes_busco} \
    --ncbi-eukcc-csv ${ncbi_genomes_eukcc} \
    --ena-busco-csv ${ena_genomes_busco} \
    --ena-eukcc-csv ${ena_genomes_eukcc} \
    --outname merged_genomes
    """

    stub:
    """
    mkdir merged_genomes
    touch merged_genomes_busco.csv
    touch merged_genomes_eukcc.csv
    """
}
