process GTDB_TAX_DUMP {

    container 'quay.io_microbiome-informatics_genomes-pipeline.gtdb-tax-dump:1.0'

    input:
    file gtdbtk_summary_tsv // merged gtdbtk.ar53.summary.tsv and gtdbtk.bac120.summary.tsv
    path cluster_reps_fa
    path kraken_db

    output:

    script:
    """
    cat gtdbtk_summary_tsv | grep -v "user_genome" | cut -f1-2 > kraken_taxonomy_temp.tsv

    while read line; do
        NAME=$(echo \$line | cut -d ' ' -f1 | cut -d '.' -f1)
        echo \$line | sed "s/__\;/__\$NAME\;/g" | sed "s/s__$/s__\$NAME/g"
    done < kraken_taxonomy_temp.tsv > kraken_taxonomy.tsv

    sed -i "s/ /\t/" kraken_taxonomy.tsv

    perl /opt/gtdbToTaxonomy.pl \
    --infile kraken_taxonomy.tsv \
    --sequence-dir $cluster_reps_fa \
    --output-dir .
    """
}