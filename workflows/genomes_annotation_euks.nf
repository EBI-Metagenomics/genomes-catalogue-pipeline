/*
    ~~~~~~~~~~~~~~~~~~
     Input validation
    ~~~~~~~~~~~~~~~~~~
*/
ch_ena_genomes = []
ch_ena_genomes_checkm = file("NO_FILE_ENA_CHECKM")

if (params.ena_genomes) {
    ch_ena_genomes = channel.fromPath(params.ena_genomes, checkIfExists: true)
    ch_ena_genomes_checkm = file(params.ena_genomes_checkm, checkIfExists: true)
}

ch_ncbi_genomes = []

if (params.ncbi_genomes) {
    ch_ncbi_genomes = channel.fromPath(params.ncbi_genomes, checkIfExists: true)
}

ch_mgyg_index_start = channel.value(params.mgyg_start)
ch_mgyg_index_end = channel.value(params.mgyg_end)

ch_genomes_information = file("NO_FILE_GENOME_CAT")
ch_study_genomes_information = file("NO_FILE_STUDY_CAT")
ch_preassigned_accessions = file("NO_FILE_PREASSIGNED_ACCS")
ch_remove_genomes = file("NO_FILE_REMOVE_GENOMES")

if (params.genomes_information) {
    ch_genomes_information = file(params.genomes_information, checkIfExists: true)
}
if (params.study_genomes_information) {
    ch_study_genomes_information = file(params.study_genomes_information, checkIfExists: true)
}
if (params.preassigned_accessions) {
    ch_preassigned_accessions = file(params.preassigned_accessions, checkIfExists: true)
}

// Update pipeline
if (params.update_catalogue_path) {
    ch_previous_catalogue_location = file(params.update_catalogue_path)
} else {
    ch_previous_catalogue_location = file("NO_PREVIOUS_CATALOGUE_VERSION")
}

if (params.remove_genomes) {
    ch_remove_genomes = file(params.remove_genomes, checkIfExists: true)
}

// TODO: Add help message with parameters

/*
    ~~~~~~~~~~~~~~~~
        Imports
    ~~~~~~~~~~~~~~~~
*/

include { PREPARE_DATA_EUKS } from '../subworkflows/prepare_data_euks' 
include { DREP_SWF } from '../subworkflows/drep_swf'
include { PROCESS_MANY_GENOMES_EUKS } from '../subworkflows/process_many_genomes_euks'
include { PROCESS_SINGLETON_GENOMES_EUKS } from '../subworkflows/process_singleton_genomes_euks'
include { EUK_GENE_CALLING } from '../subworkflows/eukaryotic_gene_annotation'
include { MMSEQ_SWF } from '../subworkflows/mmseq_swf'
include { ANNOTATE_EUKARYOTES } from '../subworkflows/annotate_eukaryotes'
include { ANNOTATE_ALL_DOMAINS } from '../subworkflows/annotate_all_domains'
include { METADATA_AND_PHYLOTREE } from '../subworkflows/metadata_and_phylotree'
include { KRAKEN_SWF } from '../subworkflows/kraken_swf'
include { DETECT_RNA } from '../subworkflows/detect_rna_swf.nf'
include { UPDATE_CLUSTERS } from '../subworkflows/update_clusters_swf.nf'

include { BAT } from '../modules/bat'
include { REFORMAT_BAT } from '../modules/reformat_bat_taxonomy'
include { PARSE_DOMAIN } from '../modules/parse_domain'
include { BUSCO } from '../modules/busco'
include { BUSCO_PHYLOGENOMICS } from '../modules/busco_phylogenomics'
include { INDEX_FNA } from '../modules/index_fna'
include { MASH_TO_NWK } from '../modules/mash2nwk'
include { FUNCTIONAL_ANNOTATION_SUMMARY } from '../modules/functional_summary'
include { ANNOTATE_EUKS_GFF } from '../modules/annotate_euk_gff'
include { GENOME_SUMMARY_JSON } from '../modules/genome_summary_json'
include { GENE_CATALOGUE } from '../modules/gene_catalogue'
include { MASH_SKETCH } from '../modules/mash_sketch'
include { KEGG_COMPLETENESS } from '../modules/kegg_completeness.nf'
include { CATALOGUE_SUMMARY } from '../modules/catalogue_summary'

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

ch_rfam_ncrna_models = file(params.rfam_ncrna_models)

ch_geo_metadata = file(params.geo_metadata)
ch_kegg_classes = file(params.kegg_classes)
ch_genome_prefix = channel.value(params.genome_prefix)

ch_mmseq_coverage_threshold = channel.value(params.mmseq_coverage_threshold) // def: 0.8
ch_biome = channel.value(params.biome)
ch_ftp_name = channel.value(params.ftp_name)
ch_ftp_version = channel.value(params.ftp_version)

ch_amrfinder_plus_db = file(params.amrfinder_plus_db)

ch_checkm2_db = file(params.checkm2_db)
ch_eukcc_db = file(params.eukcc_db)
ch_busco_db = file(params.busco_db)

ch_defense_finder_db = file(params.defense_finder_db)

ch_dbcan_db = file(params.dbcan_db)

ch_antismash_db = file(params.antismash_db)

ch_cat_db_folder = file(params.cat_db_folder)
ch_cat_taxonomy_db = file(params.cat_taxonomy_db)

ch_protein_evidence = file(params.protein_evidence)

/*
    ~~~~~~~~~~~~~~~~~~
       Run workflow
    ~~~~~~~~~~~~~~~~~~
*/

workflow GAP_EUKS {
    
    // prepare incoming data
    if ( params.ena_genomes || params.ncbi_genomes) {
        PREPARE_DATA_EUKS(
            ch_ena_genomes,
            ch_ena_genomes_checkm,
            ch_ncbi_genomes,
            ch_mgyg_index_start,
            ch_mgyg_index_end,
            ch_preassigned_accessions,
            ch_genome_prefix,
            ch_genomes_information,
            ch_study_genomes_information,
            ch_eukcc_db,
            ch_busco_db
        )
        new_data_checkm = PREPARE_DATA_EUKS.out.genomes_checkm // this is eukcc
        new_genome_stats = PREPARE_DATA_EUKS.out.new_genome_stats
        extra_weight_table_new_genomes = PREPARE_DATA_EUKS.out.extra_weight_table
        new_genomes = PREPARE_DATA_EUKS.out.genomes
        qs50_failed = PREPARE_DATA_EUKS.out.qs50_failed
        genomes_name_mapping = PREPARE_DATA_EUKS.out.genomes_name_mapping
        busco_summary = PREPARE_DATA_EUKS.out.genomes_busco
    } else {
        // if we are not adding new genomes, make dummy files
        new_data_checkm = file("NO_FILE_NEW_GENOMES_CHECKM")
        new_genome_stats = file("NO_FILE_NEW_GENOMES_STATS")
        extra_weight_table_new_genomes = file("NO_FILE_NEW_GENOMES_EXTRA_WEIGHT")
        new_genomes = file("NO_FILE_NEW_GENOMES")
        qs50_failed = file("NO_FILE_QS50_FAILED")
        genomes_name_mapping = file("NO_FILE_GENOMES_NAME_MAPPING")
        busco_summary = channel.empty()
    }
    
    // generate species level genome clusters
    dereplicated_genomes = channel.empty()
    DREP_SWF(
        new_genomes,
        new_data_checkm,
        extra_weight_table_new_genomes,
        params.euk_drep_args
    )
    dereplicated_genomes = DREP_SWF
    all_assembly_stats = new_genome_stats
    checkm_all_genomes = new_data_checkm // this is eukcc
    extra_weight_table_all_genomes = extra_weight_table_new_genomes

    // get fasta paths for rep genomes
    gdtb_input_ch = dereplicated_genomes.out.single_genomes_fna_tuples
        .map({ it[1] })
        .mix( dereplicated_genomes.out.many_genomes_fna_tuples.filter { it[1].name.contains(it[0]) }
        .map({ it[1] })
        )

    BAT( 
        gdtb_input_ch,
        ch_cat_db_folder,
        ch_cat_taxonomy_db
    )
    
    taxonomy_ch = BAT.out.bat_names.collectFile(
        keepHeader: true,
        name: "bat_taxonomy.txt"
    )

    REFORMAT_BAT(taxonomy_ch)
    reformatted_tax = REFORMAT_BAT.out.taxonomy
        
    PARSE_DOMAIN(
        reformatted_tax,
        dereplicated_genomes.out.drep_split_text
    )
    
    accessions_with_domains_ch = PARSE_DOMAIN.out.detected_domains.flatMap { file ->
        file.readLines().collect { line ->
            def (genomeName, domain) = line.split(',')
            [genomeName, domain]
        }
    }

    PROCESS_MANY_GENOMES_EUKS(
        dereplicated_genomes.out.many_genomes_fna_tuples,
        genomes_name_mapping,
        ch_protein_evidence
    )

    PROCESS_SINGLETON_GENOMES_EUKS(
        dereplicated_genomes.out.single_genomes_fna_tuples,
        genomes_name_mapping,
        ch_protein_evidence
    )

    MMSEQ_SWF(
        PROCESS_MANY_GENOMES_EUKS.out.braker_faas.map({ it[1] }).collectFile(name: "pangenome_braker.faa"),
        PROCESS_SINGLETON_GENOMES_EUKS.out.braker_faa.map({ it[1] }).collectFile(name: "singleton_braker.faa"),
        genomes_name_mapping.first(),
        ch_mmseq_coverage_threshold
    )

    cluster_reps_faas = PROCESS_MANY_GENOMES_EUKS.out.rep_braker_faa.mix(
        PROCESS_SINGLETON_GENOMES_EUKS.out.braker_faa
    )

    cluster_reps_fnas = PROCESS_MANY_GENOMES_EUKS.out.rep_braker_fna.mix(
        PROCESS_SINGLETON_GENOMES_EUKS.out.braker_fna
    )
    cluster_reps_fnas.view()
    
    cluster_reps_gffs = PROCESS_MANY_GENOMES_EUKS.out.rep_braker_gff.mix(
        PROCESS_SINGLETON_GENOMES_EUKS.out.braker_gff
    )

    cluster_reps_ffn = PROCESS_MANY_GENOMES_EUKS.out.rep_braker_ffn.mix(
        PROCESS_SINGLETON_GENOMES_EUKS.out.braker_ffn
    )

    all_braker_fna = PROCESS_SINGLETON_GENOMES_EUKS.out.braker_fna.mix(
        PROCESS_MANY_GENOMES_EUKS.out.braker_fnas
    )

    species_reps_names_list = PROCESS_MANY_GENOMES_EUKS.out.rep_braker_fna.map({ it[0] }) \
        .mix(PROCESS_SINGLETON_GENOMES_EUKS.out.braker_fna.map({ it[0] })) \
        .collectFile(name: "species_reps_names_list.txt", newLine: true)


    // Separate accessions into those we don't know domain for (Undefined) and those that we do
    accessions_with_domains_ch
    .branch {
        defined: it[1] != "Undefined"
        return it[0]
        undefined: it[1] == "Undefined"
        return it[0]
    }
    .set { domain_splits }
    
    // Add "to_remove" to accessions that have an undefined domain
    undefined_genomes = domain_splits.undefined.map(it -> [it, "to_remove"])
        
    // Make a single set of tuples to remove, then remove these from fna tuples for singleton genomes
    filtered_single_genome_fna_tuples = dereplicated_genomes.out.single_genomes_fna_tuples \
        .join(undefined_genomes, remainder: true) \
        .filter { genome_name, fa_path, remove_flag -> remove_flag == null} \
        .map { genome_name, fa_path, remove_flag -> [genome_name, fa_path] }


    // tree generation
    BUSCO(cluster_reps_fnas.map { it[1] }, ch_busco_db)
    BUSCO.out.busco_folder.view()

    busco_folders = BUSCO.out.busco_folder.collect()
    busco_folders.view()
    BUSCO_PHYLOGENOMICS(busco_folders)

    cluster_reps_gbks = file("EMPTY_GBK_CHANNEL")
    ANNOTATE_ALL_DOMAINS(
        MMSEQ_SWF.out.mmseq_90_cluster_tsv,
        MMSEQ_SWF.out.mmseq_90_tarball,
        MMSEQ_SWF.out.mmseq_90_cluster_rep_faa,
        cluster_reps_gbks,
        cluster_reps_faas,
        cluster_reps_gffs,
        accessions_with_domains_ch,
        ch_interproscan_db,
        ch_eggnog_db,
        ch_eggnog_diamond_db,
        ch_eggnog_data_dir,
        ch_dbcan_db,
        ch_antismash_db
    )
    
    ANNOTATE_EUKARYOTES(
        cluster_reps_faas,
        ch_interproscan_db,
        ch_eggnog_db,
        ch_eggnog_diamond_db,
        ch_eggnog_data_dir
    )
    ips_annotation_tsvs = ANNOTATE_EUKARYOTES.out.ips_annotation_tsvs
    eggnog_annotation_tsvs = ANNOTATE_EUKARYOTES.out.eggnog_annotation_tsvs
    
    KEGG_COMPLETENESS(
       eggnog_annotation_tsvs
       )
    
    DETECT_RNA(
        all_braker_fna,
        accessions_with_domains_ch,
        ch_rfam_ncrna_models
    )
    
    METADATA_AND_PHYLOTREE(
        cluster_reps_fnas.map({ it[1]}).collect(),
        all_braker_fna.map({ it[1] }).collect(),
        extra_weight_table_all_genomes,
        checkm_all_genomes,
        DETECT_RNA.out.rrna_outs.flatMap {it -> it[1..-1]}.collect(),
        genomes_name_mapping,
        dereplicated_genomes.out.drep_split_text,
        ch_ftp_name,
        ch_ftp_version,
        ch_geo_metadata,
        file("EMPTY"),
        reformatted_tax,
        ch_previous_catalogue_location,
        all_assembly_stats
    )

    faa_and_annotations = cluster_reps_faas.join(
        ips_annotation_tsvs
    ).join(
        eggnog_annotation_tsvs
    )

    FUNCTIONAL_ANNOTATION_SUMMARY(
        faa_and_annotations,
        ch_kegg_classes
    )

    INDEX_FNA(
        all_braker_fna
    )

    // Select the only the reps //
    // Those where the cluster-name and the file name match
    // i.e., such as cluster_name: MGY1 and file MGY1_eggnog.tsv
    reps_ips = ips_annotation_tsvs.filter {
        it[1].name.contains(it[0])
    }
    reps_eggnog = eggnog_annotation_tsvs.filter {
        it[1].name.contains(it[0])
    }
    all_ncrna = DETECT_RNA.out.ncrna_tblout.filter {
        it[1].name.contains(it[0])
    }
    
    // Filter DETECT_RNA.out.trna_gff to only save tRNA GFFs for species reps to reps_trna_gff
    reps_trna_gff = cluster_reps_gffs.join(DETECT_RNA.out.trna_gff, remainder: true)
    .filter { it -> it[1] != null }  // Remove tuples where there is no species rep genome GFF (= this is not a rep)
    .map { it -> [it[0], it[2]] }  // 
    
    // Filter all_ncrna to only keep results for species reps
    reps_ncrna = cluster_reps_gffs.join(all_ncrna, remainder: true)
    .filter { it -> it[1] != null }  // Remove tuples where there is no species rep genome GFF (= this is not a rep)
    .map { it -> [it[0], it[2]] }  // 
        
    // REPS //
    antismash_results = Channel.value(file("NO_FILE_ANTISMASH_RESULTS"))
    ANNOTATE_EUKS_GFF(
        cluster_reps_gffs.join(
            reps_eggnog
        ).join(
            reps_ncrna
        ).join(
            reps_trna_gff
        ).join(
            antismash_results
        ).join(
            ANNOTATE_ALL_DOMAINS.out.dbcan_gffs, remainder: true
        ).join(
            reps_ips
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
    ch_pangenomes_fna = Channel.empty()
    ch_core_genes = Channel.empty()
    files_for_json_summary = ANNOTATE_EUKS_GFF.out.annotated_gff.join(
        FUNCTIONAL_ANNOTATION_SUMMARY.out.coverage
    ).join(
        cluster_reps_faas
    ).join(
        ch_pangenomes_fna, remainder: true
    ).join(
        ch_core_genes, remainder: true
    )

    GENOME_SUMMARY_JSON(
        files_for_json_summary,
        METADATA_AND_PHYLOTREE.out.metadata_tsv.first(),
        ch_biome
    )
    
    CATALOGUE_SUMMARY(
       METADATA_AND_PHYLOTREE.out.metadata_tsv,
       MMSEQ_SWF.out.mmseq_90_cluster_tsv
    )

    GENE_CATALOGUE(
        cluster_reps_ffn.map({ it[1] }).collectFile(name: "cluster_reps.ffn", newLine: true),
        MMSEQ_SWF.out.mmseq_100_cluster_tsv
    )

    MASH_SKETCH(
        all_braker_fna.map({ it[1] }).collect()
    )
}