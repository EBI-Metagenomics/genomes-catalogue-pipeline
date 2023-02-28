process KRAKEN2_PREPARE_GTDBTK_TAX {

    container 'quay.io/biocontainers/perl-bio-procedural:1.7.4--pl5321h9ee0642_0'

    input:
    file gtdbtk_concatenated
    val kraken_db_name
    path cluster_fna, stageAs: "reps_fa/*"

    output:
    path "kraken_intermediate/taxonomy", type: 'dir', emit: kraken_intermediate
    path "${kraken_db_name}", type: 'dir', emit: kraken_db
    path "reps_fa/gtdb/*.fna", emit: tax_annotated_fnas

    script:
    """
    # Prepare the GTDB inputs #
    cat ${gtdbtk_concatenated} | grep -v \"user_genome\" | cut -f1-2 > kraken_taxonomy_temp.tsv

    while read line; do
        NAME=\$(echo \$line | cut -d ' ' -f1 | cut -d '.' -f1)
        echo \$line | sed "s/__\\;/__\$NAME\\;/g" | sed "s/s__\$/s__\$NAME/g"
    done < kraken_taxonomy_temp.tsv > kraken_taxonomy.tsv

    sed -i "s/ /\t/" kraken_taxonomy.tsv

    gtdbToTaxonomy.pl \
    --infile kraken_taxonomy.tsv \
    --sequence-dir reps_fa/ \
    --output-dir kraken_intermediate

    mkdir ${kraken_db_name}
    
    cp -r kraken_intermediate/taxonomy ${kraken_db_name}
    """
}

process KRAKEN2_BUILD_LIBRARY {

    container 'quay.io/biocontainers/kraken2:2.1.2--pl5321h9f5acd7_2'

    input:
    path cluster_fna_tax_annotated
    path kraken_db_path

    output:
    stdout

    script:
    """
    kraken2-build \
    --add-to-library ${cluster_fna_tax_annotated} \
    --db ${kraken_db_path}
    """
}

process KRAKEN2_BUILD {

    container 'quay.io/biocontainers/kraken2:2.1.2--pl5321h9f5acd7_2'

    cpus 4

    stageInMode 'copy'

    input:
    path kraken_db_path
    path kraken_build_library_log

    output:
    path "${kraken_db_path}", emit: kraken_db

    script:
    """
    kraken2-build --build \
    --db ${kraken_db_path} \
    --threads ${task.cpus}
    """
}

process KRAKEN2_POSTPROCESSING {

    publishDir(
        "${params.outdir}/",
        mode: 'copy'
    )

    input:
    path kraken_db
    path bracken_log

    output:
    path "${kraken_db}", emit: kraken_db

    script:
    """
    cat ${kraken_db}/library/added/*.fna > ${kraken_db}/library/library.fna

    cp "${kraken_db}"/taxonomy/prelim_map.txt ${kraken_db}/library
    """
}