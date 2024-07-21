/*
 * Functional annontation of the genomes of the cluster reps
*/

include { IPS } from '../modules/interproscan'
include { EGGNOG_MAPPER as EGGNOG_MAPPER_ORTHOLOGS } from '../modules/eggnog'
include { EGGNOG_MAPPER as EGGNOG_MAPPER_ANNOTATIONS } from '../modules/eggnog'
include { PER_GENOME_ANNONTATION_GENERATOR } from '../modules/per_genome_annotations'
include { DETECT_RRNA } from '../modules/detect_rrna'
include { SANNTIS } from '../modules/sanntis'
include { ANTISMASH } from '../modules/antismash'
include { DEFENSE_FINDER } from '../modules/defense_finder'
include { DBCAN } from '../modules/dbcan'
include { GECCO_RUN } from '../modules/gecco'


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

workflow ANNOTATE {
    take:
        mmseq_90_tsv
        mmseq_90_tarball
        mmseq_90_cluster_rep_faa
        prokka_fnas
        prokka_gbk
        prokka_faa
        prokka_gff
        species_reps_names_list
        interproscan_db
        eggnog_db
        eggnog_diamond_db
        eggnog_data_dir
        cmmodels_db
        defense_finder_db
        dbcan_db
        antismash_db
    main:

        mmseq_90_chunks = mmseq_90_cluster_rep_faa.flatten().splitFasta(
            by: 10000,
            file: true
        )

        IPS(
            mmseq_90_chunks,
            interproscan_db
        )

        EGGNOG_MAPPER_ORTHOLOGS(
            mmseq_90_chunks,
            file("NO_FILE"),
            channel.value('mapper'),
            eggnog_db,
            eggnog_diamond_db,
            eggnog_data_dir
        )

        EGGNOG_MAPPER_ANNOTATIONS(
            file("NO_FILE"),
            EGGNOG_MAPPER_ORTHOLOGS.out.orthologs,
            channel.value('annotations'),
            eggnog_db,
            eggnog_diamond_db,
            eggnog_data_dir
        )

        interproscan_annotations = IPS.out.ips_annontations.collectFile(
            name: "ips_annotations.tsv",
        )
        eggnog_mapper_annotations = EGGNOG_MAPPER_ANNOTATIONS.out.annotations.collectFile(
            keepHeader: true,
            skip: 1,
            name: "eggnog_annotations.tsv"
        )

        PROTEIN_CATALOGUE_STORE_ANNOTATIONS(
            interproscan_annotations,
            eggnog_mapper_annotations,
            mmseq_90_tarball
        )

        PER_GENOME_ANNONTATION_GENERATOR(
            interproscan_annotations,
            eggnog_mapper_annotations,
            species_reps_names_list,
            mmseq_90_tsv
        )

        // RRNA detection in all the genomes //
        DETECT_RRNA(
            prokka_fnas,
            cmmodels_db
        )
        
        DEFENSE_FINDER(
            prokka_faa.join(prokka_gff),
            defense_finder_db
        )
        
        DBCAN(
            prokka_faa.join(prokka_gff),
            dbcan_db
        ) 
        
        ANTISMASH(
            prokka_gbk,
            antismash_db
        )     
        
        GECCO_RUN(
            prokka_gbk    
        )     

        // Group by cluster //
        per_genome_ips_annotations = PER_GENOME_ANNONTATION_GENERATOR.out.ips_annotation_tsvs | flatten | map { file ->
            def key = file.name.toString().tokenize('_').get(0)
            return tuple(key, file)
        }

        per_genome_eggnog_annotations = PER_GENOME_ANNONTATION_GENERATOR.out.eggnog_annotation_tsvs | flatten | map { file ->
            def key = file.name.toString().tokenize('_').get(0)
            return tuple(key, file)
        }

        SANNTIS(
            per_genome_ips_annotations.join(prokka_gbk)
        )

    emit:
        ips_annotation_tsvs = per_genome_ips_annotations
        eggnog_annotation_tsvs = per_genome_eggnog_annotations
        rrna_outs = DETECT_RRNA.out.rrna_out_results.collect()
        sanntis_annotation_gffs = SANNTIS.out.sanntis_gff
        defense_finder_gffs = DEFENSE_FINDER.out.gff
        dbcan_gffs = DBCAN.out.dbcan_gff
        antismash_gffs = ANTISMASH.out.antismash_gff
        gecco_gffs = GECCO_RUN.out.gecco_gff
}
