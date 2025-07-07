/*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     Collect dRep results (xlarge catalogues)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process COLLECT_DREP_RESULTS {

    publishDir(
        path: "${params.outdir}/additional_data/intermediate_files",
        mode: "copy",
        failOnError: true
    )

    stageInMode "copy"

    input:
    path drep_tables_tarballs
    path cdb_csv
    path sdb_csv
    path mdb_csv

    output:
    path "drep_data_tables.tar.gz"

    script:
    """
    tar -czf drep_data_tables.tar.gz \
        ${cdb_csv} \
        ${sdb_csv} \
        ${mdb_csv} \
        ${drep_tables_tarballs.join(' ')}
    """

}


/*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     Generate an input file for locations fetching script 
     (in preparation for metadata table generation)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process PREPARE_LOCATION_INPUT {
    
    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    input:
    file gunc_failed_txt
    path name_mapping_tsv
    
    output:
    path "accession_list.txt", emit: locations_input_tsv
    
    script:
    """
    prepare_locations_input.py \
    --gunc-failed ${gunc_failed_txt} \
    --name-mapping ${name_mapping_tsv} \
    --output accession_list.txt
    """
}


/*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     Fetch geographic location information from ENA
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process FETCH_LOCATIONS {

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    errorStrategy = { task.attempt <= 3 ? 'retry' : 'finish' }
    
    input:
    path accessions_file
    path geo_metadata
    
    output:
    path '*.locations', emit: locations_tsv
    path 'ena_location_warnings.txt', emit: warnings_txt
    
    script:
    """
    get_locations.py \
    -i ${accessions_file} \
    --geo ${geo_metadata}
    """
}


/*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     Create a mmseq_90 tarball with annotations
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process PROTEIN_CATALOGUE_STORE_ANNOTATIONS {

    publishDir(
        "${params.outdir}/protein_catalogue/",
        mode: 'copy'
    )

    stageInMode 'copy'

    input:
    file interproscan_annotations
    file eggnog_annotations
    file mmseq_90_tarball

    output:
    file "protein_catalogue-90.tar.gz"

    script:
    """
    mv ${interproscan_annotations} protein_catalogue-90_InterProScan.tsv
    mv ${eggnog_annotations} protein_catalogue-90_eggNOG.tsv

    gunzip -c ${mmseq_90_tarball} > protein_catalogue-90.tar

    rm ${mmseq_90_tarball}

    tar -uf protein_catalogue-90.tar protein_catalogue-90_InterProScan.tsv protein_catalogue-90_eggNOG.tsv

    gzip protein_catalogue-90.tar
    """
}


/*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     Collect a list of genomes that failed GUNC
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process COLLECT_FAILED_GUNC {

    publishDir(
        "${params.outdir}",
        pattern: "gunc_failed.txt",
        saveAs: { "additional_data/intermediate_files/gunc/gunc_failed.txt" },
        mode: "copy",
        failOnError: true
    )

    input:
    path failed_gunc_files, stageAs: "failed_gunc/*"

    output:
    path("gunc_failed.txt"), emit: gunc_failed_txt

    script:
    """
    rm -f gunc_failed.txt || true
    touch gunc_failed.txt
    for GUNC_FAILED in failed_gunc/*; do
        if [ \$GUNC_FAILED != "failed_gunc/NO_FILE" ]
        then
            name=\$(basename \$GUNC_FAILED)
            genome_name="\${name%"_gunc_empty.txt"}"
            echo \$genome_name >> gunc_failed.txt
        fi
    done
    """
}