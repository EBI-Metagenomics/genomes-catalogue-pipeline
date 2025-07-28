/*
 * Functional annotation of the cluster rep genomes - prokaryotes and eukaryotes
*/

include { IPS } from '../modules/interproscan'
include { EGGNOG_MAPPER as EGGNOG_MAPPER_ORTHOLOGS } from '../modules/eggnog'
include { EGGNOG_MAPPER as EGGNOG_MAPPER_ANNOTATIONS } from '../modules/eggnog'
include { DBCAN } from '../modules/dbcan'
include { PROTEIN_CATALOGUE_STORE_ANNOTATIONS } from '../modules/utils'

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
        eggnog_tax_scope
        dbcan_db
    
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
            eggnog_tax_scope,
            eggnog_db,
            eggnog_diamond_db,
            eggnog_data_dir
        )

        EGGNOG_MAPPER_ANNOTATIONS(
            tuple("empty", "NO_FILE"),
            EGGNOG_MAPPER_ORTHOLOGS.out.orthologs,
            channel.value('annotations'),
            eggnog_tax_scope,
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

    emit:
        dbcan_gffs = DBCAN.out.dbcan_gff
        interproscan_annotations_mmseqs90 = interproscan_annotations
        eggnog_annotations_mmseqs90 = eggnog_mapper_annotations
        
}