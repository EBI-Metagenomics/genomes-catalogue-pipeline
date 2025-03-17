/*
 * Functional annotation of the cluster rep genomes - prokaryotes and eukaryotes
*/

include { IPS } from '../modules/interproscan'
include { EGGNOG_MAPPER as EGGNOG_MAPPER_ORTHOLOGS } from '../modules/eggnog'
include { EGGNOG_MAPPER as EGGNOG_MAPPER_ANNOTATIONS } from '../modules/eggnog'
include { DBCAN } from '../modules/dbcan'
include { ANTISMASH } from '../modules/antismash'
include { ANTISMASH_MAKE_GFF } from '../modules/antismash_make_gff'


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

workflow ANNOTATE_ALL_DOMAINS {
    take:
        mmseq_90_tsv
        mmseq_90_tarball
        mmseq_90_cluster_rep_faa
        prokka_gbk
        prokka_faa
        prokka_gff
        accessions_with_domains_ch
        interproscan_db
        eggnog_db
        eggnog_diamond_db
        eggnog_data_dir
        dbcan_db
        antismash_db
    
    main:

        mmseq_90_chunks = mmseq_90_cluster_rep_faa.flatten().splitFasta(
            by: 10000,
            file: true
        ).map(chunk_path -> [chunk_path.baseName, chunk_path])

        IPS(
            mmseq_90_chunks,
            interproscan_db
        )

        EGGNOG_MAPPER_ORTHOLOGS(
            mmseq_90_chunks,
            tuple("empty", "NO_FILE"),
            channel.value('mapper'),
            eggnog_db,
            eggnog_diamond_db,
            eggnog_data_dir
        )

        EGGNOG_MAPPER_ANNOTATIONS(
            tuple("empty", "NO_FILE"),
            EGGNOG_MAPPER_ORTHOLOGS.out.orthologs,
            channel.value('annotations'),
            eggnog_db,
            eggnog_diamond_db,
            eggnog_data_dir
        )

        interproscan_annotations = IPS.out.ips_annotations.map{ it[1] }.collectFile(
            name: "ips_annotations.tsv",
        )
        
        eggnog_mapper_annotations = EGGNOG_MAPPER_ANNOTATIONS.out.annotations.map{ it[1] }.collectFile(
            keepHeader: true,
            skip: 1,
            name: "eggnog_annotations.tsv"
        )

        PROTEIN_CATALOGUE_STORE_ANNOTATIONS(
            interproscan_annotations,
            eggnog_mapper_annotations,
            mmseq_90_tarball
        )

        
        DBCAN(
            prokka_faa.join(
                prokka_gff
                ).join(
                    accessions_with_domains_ch, remainder: true
                ).filter { it -> it[1] != null },
            dbcan_db
        ) 
        
        // ANTISMASH(
        //     prokka_gbk,
        //     antismash_db
        // )
        
        // ANTISMASH_MAKE_GFF(
        //     ANTISMASH.out.antismash_json
        // )     


    emit:
        dbcan_gffs = DBCAN.out.dbcan_gff
        // antismash_gffs = ANTISMASH_MAKE_GFF.out.antismash_gff
        interproscan_annotations_mmseqs90 = interproscan_annotations
        eggnog_annotations_mmseqs90 = eggnog_mapper_annotations
        
}