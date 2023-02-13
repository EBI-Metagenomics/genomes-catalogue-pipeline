process KRAKEN2_PREPARE_GTDBTK_TAX {

    container 'quay.io_microbiome-informatics_genomes-pipeline.gtdb-tax-dump:1.0.sif'

    input:
    path gtdbtk_bac120
    path gtdbtk_ar53
    path kraken_db

    output:
    path "kraken_intermediate/*", emit: kraken_intermediate

    script:
    """
    # Prepare the GTDB inputs #
    cat ${gtdbtk_bac120} ${gtdbtk_ar53} | grep -v \"user_genome\" | cut -f1-2 > kraken_taxonomy_temp.tsv

    while read line; do
        NAME=\$(echo \$line | cut -d ' ' -f1 | cut -d '.' -f1)
        echo \$line | sed "s/__\;/__\$NAME\;/g" | sed "s/s__$/s__\$NAME/g"
    done < kraken_taxonomy_temp.tsv > kraken_taxonomy.tsv

    sed -i "s/ /\t/" kraken_taxonomy.tsv

    gtdbToTaxonomy.pl \
    --infile kraken_taxonomy.tsv \
    --sequence-dir "${OUT}"/reps_fa/ \
    --output-dir kraken_intermediate
    """
}

process KRAKEN2_BUILD_LIBRARY {

    tag "${cluster_name}"

    container 'quay.io/biocontainers/kraken2:2.1.2--pl5321h9f5acd7_2'

    input:
    tuple val(cluster_name), path(cluster_fna) 
    path kraken_db

    output:
    val(cluster_name)

    script:
    """
    kraken2-build --add-to-library ${cluster_fna} --db ${kraken_db}
    """
}
