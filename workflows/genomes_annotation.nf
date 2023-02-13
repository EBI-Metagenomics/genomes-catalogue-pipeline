/*
    ~~~~~~~~~~~~~~~~~~
     Input validation
    ~~~~~~~~~~~~~~~~~~
*/
ch_ena_genomes = channel.fromPath(params.ena_genomes, checkIfExists: true)
ch_ena_genomes_checkm = channel.fromPath(params.ena_genomes_checkm, checkIfExists: true)

// TODO: Validate
ch_mgyg_index_start = channel.value(params.mgyg_start)
ch_mgyg_index_end = channel.value(params.mgyg_end)

// TODO: Add help message with parameters

/*
    ~~~~~~~~~~~~~~~~
        Imports
    ~~~~~~~~~~~~~~~~
*/

include { PREPARE_DATA } from '../subworkflows/prepare_data'
include { DREP_SWF } from '../subworkflows/drep_swf'
include { PROCESS_MANY_GENOMES } from '../subworkflows/process_many_genomes'
include { PROCESS_SINGLETON_GENOMES } from '../subworkflows/process_singleton_genomes'
include { MMSEQ_SWF } from '../subworkflows/mmseq_swf'
include { ANNOTATE } from '../subworkflows/annotate'
include { GTDBTK_AND_METADATA } from '../subworkflows/gtdbtk_and_metadata'

include { MASH_TO_NWK } from '../modules/mash2nwk'
include { FUNCTIONAL_ANNOTATION_SUMMARY } from '../modules/functional_summary'
include { DETECT_NCRNA } from '../modules/detect_ncrna'
include { INDEX_FNA } from '../modules/index_fna'
include { ANNONTATE_GFF } from '../modules/annotate_gff'
include { GENOME_SUMMARY_JSON } from '../modules/genome_summary_json'
include { IQTREE } from '../modules/iqtree'

/*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Channels for ref databases and input parameters
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_gtdb_db = file(params.gtdb_db)
ch_gunc_db = file(params.gunc_db)
ch_interproscan_db = file(params.interproscan_db)

ch_eggnog_db = file(params.eggnog_db)
ch_eggnog_diamond_db = file(params.eggnong_diamond_db)
ch_eggnog_data_dir = file(params.eggnong_data_dir)

ch_rfam_rrna_models = file(params.rfam_rrna_models)
ch_rfam_ncrna_models = file(params.rfam_ncrna_models)

ch_geo_metadata = file(params.geo_metadata)
ch_kegg_classes = file(params.kegg_classes)
ch_genome_prefix = channel.value(params.genome_prefix)

// TODO: Parametrize //
ch_mmseq_coverage_threshold = channel.value(0.8)
ch_biome = channel.value(params.biome)
ch_ftp_name = channel.value("test-ftp")
ch_ftp_version = channel.value(1.0)

/*
    ~~~~~~~~~~~~~~~~~~
       Run workflow
    ~~~~~~~~~~~~~~~~~~
*/

// TODO: move to utils
process COLLECT_IN_FOLDER {

    publishDir "results/", mode: 'symlink'

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    path files
    val folder_name

    output:
    path "${folder_name}", type: 'dir', emit: collection_folder

    script:
    """
    mkdir ${folder_name}
    mv ${files.join( ' ' )} ${folder_name}
    """
}

workflow GAP {

    PREPARE_DATA(
        ch_ena_genomes,
        ch_ena_genomes_checkm,
        channel.empty(), // ncbi, we are ignoring this ATM
        ch_mgyg_index_start,
        ch_mgyg_index_end,
        ch_genome_prefix
    )

    DREP_SWF(
        PREPARE_DATA.out.genomes,
        PREPARE_DATA.out.genomes_checkm
    )

    MASH_TO_NWK(
        DREP_SWF.out.mash_splits | flatten
    )

    PROCESS_MANY_GENOMES(
        DREP_SWF.out.many_genomes_fna_tuples
    )

    PROCESS_SINGLETON_GENOMES(
        DREP_SWF.out.single_genomes_fna_tuples,
        PREPARE_DATA.out.genomes_name_mapping.first(),
        ch_gunc_db
    )

    MMSEQ_SWF(
        PROCESS_MANY_GENOMES.out.prokka_faas.map({ it[1] }).collectFile(name: "pangenome_prokka.faa"),
        PROCESS_SINGLETON_GENOMES.out.prokka_faa.map({ it[1] }).collectFile(name: "singleton_prokka.faa"),
        PREPARE_DATA.out.genomes_name_mapping.first(),
        ch_mmseq_coverage_threshold
    )

    cluster_reps_faas = PROCESS_MANY_GENOMES.out.rep_prokka_faa.mix(
        PROCESS_SINGLETON_GENOMES.out.prokka_faa
    )

    cluster_reps_fnas = PROCESS_MANY_GENOMES.out.rep_prokka_fna.mix(
        PROCESS_SINGLETON_GENOMES.out.prokka_fna
    )

    species_reps_names_list = PROCESS_MANY_GENOMES.out.rep_prokka_fna.map({ it[0] }) \
        .mix(PROCESS_SINGLETON_GENOMES.out.prokka_fna.map({ it[0] })) \
        .collectFile(name: "species_reps_names_list.txt", newLine: true)

    ANNOTATE(
        MMSEQ_SWF.out.mmseq_cluster_rep_faa,
        MMSEQ_SWF.out.mmseq_cluster_tsv,
        cluster_reps_faas,
        cluster_reps_fnas,
        species_reps_names_list,
        ch_interproscan_db,
        ch_eggnog_db,
        ch_eggnog_diamond_db,
        ch_eggnog_data_dir,
        ch_rfam_rrna_models
    )

    fna_folder = COLLECT_IN_FOLDER(
        cluster_reps_fnas.map({ it[1]}).collect(),
        channel.value("all_fna")
    )

    GTDBTK_AND_METADATA(
        fna_folder,
        DREP_SWF.out.extra_weight_table,
        PREPARE_DATA.out.genomes_checkm,
        ANNOTATE.out.rrna_outs,
        PREPARE_DATA.out.genomes_name_mapping,
        DREP_SWF.out.drep_split_text,
        ch_ftp_name,
        ch_ftp_version,
        ch_geo_metadata,
        PROCESS_SINGLETON_GENOMES.out.gunc_report,
        ch_gtdb_db
    )

    if (GTDBTK_AND_METADATA.out.gtdbtk_msa_bac120) {
        IQTREE(
            GTDBTK_AND_METADATA.out.gtdbtk_msa_bac120,
            channel.val("bac120")
        )
    }

    if (GTDBTK_AND_METADATA.out.gtdbtk_msa_ar53) {
        IQTREE(
            GTDBTK_AND_METADATA.out.gtdbtk_msa_ar53,
            channel.val("ar53")
        )
    }

    cluster_reps_faa = PROCESS_SINGLETON_GENOMES.out.prokka_faa.mix(
        PROCESS_MANY_GENOMES.out.rep_prokka_faa
    )

    faa_and_annotations = cluster_reps_faa.join(
        ANNOTATE.out.ips_annotation_tsvs
    ).join(
        ANNOTATE.out.eggnog_annotation_tsvs
    )

    FUNCTIONAL_ANNOTATION_SUMMARY(
        faa_and_annotations,
        ch_kegg_classes
    )

    all_prokka_fna = PROCESS_SINGLETON_GENOMES.out.prokka_fna.mix(
        PROCESS_MANY_GENOMES.out.prokka_fnas
    )

    DETECT_NCRNA(
        all_prokka_fna,
        ch_rfam_ncrna_models
    )

    INDEX_FNA(
        all_prokka_fna
    )

    cluster_reps_gff = PROCESS_SINGLETON_GENOMES.out.prokka_gff.mix(
        PROCESS_MANY_GENOMES.out.rep_prokka_gff
    )

    ANNONTATE_GFF(
        cluster_reps_gff.join(
            ANNOTATE.out.ips_annotation_tsvs
        ).join(
            ANNOTATE.out.eggnog_annotation_tsvs
        ).join(
            DETECT_NCRNA.out.ncrna_tblout
        )
    )

    /* This operation will generate a list of tuples for the json generation 
    * Example of one element on the list;
    * tuple ( 
        val(cluster),
        file(annotated_gff),
        file(coverage_summary),
        file(cluster_faa),
        file(pangenome_fasta), // only for many_genomes clusters otherwise empty
        file(core_genes)       // only for many_genomes clusters otherwise empty
    )
    */
    files_for_json_summary = ANNONTATE_GFF.out.annotated_gff.join(
        FUNCTIONAL_ANNOTATION_SUMMARY.out.coverage
    ).join(
        cluster_reps_faa
    ).join(
        PROCESS_MANY_GENOMES.out.panaroo_pangenome_fna, remainder: true
    ).join(
        PROCESS_MANY_GENOMES.out.core_genes, remainder: true
    )

    GENOME_SUMMARY_JSON(
        files_for_json_summary,
        GTDBTK_AND_METADATA.out.metadata_tsv.first(),
        ch_biome
    )

}
