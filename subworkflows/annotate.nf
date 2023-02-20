/*
 * Functional annontation of the genomes of the cluster reps
*/

include { IPS } from '../modules/interproscan'
include { EGGNOG_MAPPER as EGGNOG_MAPPER_ORTHOLOGS } from '../modules/eggnog'
include { EGGNOG_MAPPER as EGGNOG_MAPPER_ANNOTATIONS } from '../modules/eggnog'
include { PER_GENOME_ANNONTATION_GENERATOR } from '../modules/per_genome_annotations'
include { DETECT_RRNA } from '../modules/detect_rrna'
include { SANNTIS } from '../modules/sanntis'


process PROTEIN_CATALOGUE_STORE_ANNOTATIONS {

    publishDir "${params.outdir}/protein_catalogue/mmseqs_0.9_outdir/", mode: 'copy'

    input:
    path interproscan_annotations
    path eggnog_annotations

    output:
    stdout

    script:
    """
    mv ${interproscan_annotations} protein_catalogue-90_InterProScan.tsv
    mv ${eggnog_annotations} protein_catalogue-90_eggNOG.tsv
    """
}

workflow ANNOTATE {
    take:
        mmseq_faa
        mmseq_tsv
        prokka_faas
        prokka_fnas
        prokka_gbk
        species_reps_names_list
        interproscan_db
        eggnog_db
        eggnog_diamond_db
        eggnog_data_dir
        cmmodels_db
    main:
        faa_chunks_ch = prokka_faas.collectFile(name: "collected.faa").splitFasta(
            by: 10000,
            file: true
        )

        IPS(
            faa_chunks_ch,
            interproscan_db
        )

        EGGNOG_MAPPER_ORTHOLOGS(
            faa_chunks_ch,
            file("NO_FILE"),
            channel.value('mapper'),
            eggnog_db,
            eggnog_diamond_db,
            eggnog_data_dir
        )

        EGGNOG_MAPPER_ANNOTATIONS(
            file("NO_FILE"),
            EGGNOG_MAPPER_ORTHOLOGS.out.orthologs.collectFile(name: "eggnog_orthologs.tsv"),
            channel.value('annotations'),
            eggnog_db,
            eggnog_diamond_db,
            eggnog_data_dir
        )

        interproscan_annotations = IPS.out.ips_annontations.collectFile(name: "ips_annotations.tsv")
        eggnog_mapper_annotations = EGGNOG_MAPPER_ANNOTATIONS.out.annotations.collectFile(name: "eggnog_annotations.tsv")

        PROTEIN_CATALOGUE_STORE_ANNOTATIONS(
            interproscan_annotations,
            eggnog_mapper_annotations
        )

        PER_GENOME_ANNONTATION_GENERATOR(
            interproscan_annotations,
            eggnog_mapper_annotations,
            species_reps_names_list,
            mmseq_tsv
        )

        DETECT_RRNA(
            prokka_fnas,
            cmmodels_db
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
}
