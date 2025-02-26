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

include { PREPARE_UPDATE } from '../subworkflows/prepare_update'
include { PREPARE_DATA } from '../subworkflows/prepare_data'
include { DREP_SWF } from '../subworkflows/drep_swf'
include { DREP_LARGE_SWF } from '../subworkflows/drep_large_catalogue_swf'
include { GTDBTK_QC } from '../modules/gtdbtk_qc'
include { GTDBTK_TAX } from '../modules/gtdbtk_tax'
include { PARSE_DOMAIN } from '../modules/parse_domain'
include { PROCESS_MANY_GENOMES } from '../subworkflows/process_many_genomes'
include { PROCESS_SINGLETON_GENOMES } from '../subworkflows/process_singleton_genomes'
include { GENERATE_COMBINED_QC_REPORT } from '../modules/generate_combined_qc_report'
include { MMSEQ_SWF } from '../subworkflows/mmseq_swf'
include { ANNOTATE_PROKARYOTES } from '../subworkflows/annotate_prokaryotes'
include { ANNOTATE_ALL_DOMAINS } from '../subworkflows/annotate_all_domains'
include { METADATA_AND_PHYLOTREE } from '../subworkflows/metadata_and_phylotree'
include { KRAKEN_SWF } from '../subworkflows/kraken_swf'
include { DETECT_RNA } from '../subworkflows/detect_rna_swf.nf'
include { UPDATE_CLUSTERS } from '../subworkflows/update_clusters_swf.nf'

include { MASH_TO_NWK } from '../modules/mash2nwk'
include { FUNCTIONAL_ANNOTATION_SUMMARY } from '../modules/functional_summary'
include { INDEX_FNA } from '../modules/index_fna'
include { ANNOTATE_GFF } from '../modules/annotate_gff'
include { GENOME_SUMMARY_JSON } from '../modules/genome_summary_json'
include { IQTREE as IQTREE_BAC } from '../modules/iqtree'
include { IQTREE as IQTREE_AR } from '../modules/iqtree'
include { FASTTREE as FASTTREE_BAC } from '../modules/fasttree'
include { FASTTREE as FASTTREE_AR } from '../modules/fasttree'
include { GENE_CATALOGUE } from '../modules/gene_catalogue'
include { MASH_SKETCH } from '../modules/mash_sketch'

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

ch_defense_finder_db = file(params.defense_finder_db)

ch_dbcan_db = file(params.dbcan_db)

ch_antismash_db = file(params.antismash_db)

/*
    ~~~~~~~~~~~~~~~~~~
       Run workflow
    ~~~~~~~~~~~~~~~~~~
*/

workflow GAP {
    // if this is an update, do pre-update checks
    if ( params.update_catalogue_path ){
        PREPARE_UPDATE(
            ch_previous_catalogue_location,
            ch_remove_genomes,
            params.skip_genome_validity_check,
            params.rerun_checkm2,
            ch_checkm2_db
        )
        remove_list_mgyg = PREPARE_UPDATE.out.remove_list_mgyg
    }
    
    // if we are adding data (either new catalogue or adding genomes during an update), prepare incoming data
    if ( params.ena_genomes || params.ncbi_genomes ){
        PREPARE_DATA(
            ch_ena_genomes,
            ch_ena_genomes_checkm,
            ch_ncbi_genomes,
            ch_mgyg_index_start,
            ch_mgyg_index_end,
            ch_preassigned_accessions,
            ch_genome_prefix,
            ch_genomes_information,
            ch_study_genomes_information,
            ch_checkm2_db
        )
        new_data_checkm = PREPARE_DATA.out.genomes_checkm
        new_genome_stats = PREPARE_DATA.out.new_genome_stats
        extra_weight_table_new_genomes = PREPARE_DATA.out.extra_weight_table
        new_genomes = PREPARE_DATA.out.new_genomes
        qs50_failed = PREPARE_DATA.out.qs50_failed
        genomes_name_mapping = PREPARE_DATA.out.genomes_name_mapping
        
    } else {
        // if we are not adding new genomes, make dummy files
        new_data_checkm = file("NO_FILE_NEW_GENOMES_CHECKM")
        new_genome_stats = file("NO_FILE_NEW_GENOMES_STATS")
        extra_weight_table_new_genomes = file("NO_FILE_NEW_GENOMES_EXTRA_WEIGHT")
        new_genomes = file("NO_FILE_NEW_GENOMES")
        qs50_failed = file("NO_FILE_QS50_FAILED")
        genomes_name_mapping = file("NO_FILE_GENOMES_NAME_MAPPING")
    }
    
    // generate species level genome clusters
    dereplicated_genomes = channel.empty()
    if ( params.update_catalogue_path ){
        // if updating a catalogue, don't run dRep, generate clusters with Python
        UPDATE_CLUSTERS(
            ch_previous_catalogue_location,
            remove_list_mgyg,
            PREPARE_UPDATE.out.previous_version_quality,
            PREPARE_UPDATE.out.previous_version_assembly_stats,
            new_data_checkm,
            new_genome_stats,
            extra_weight_table_new_genomes
        )
        dereplicated_genomes = UPDATE_CLUSTERS
        all_assembly_stats = UPDATE_CLUSTERS.out.assembly_stats_all_genomes
    } else {
        // if generating a new catalogue, cluster with dRep 
    
        if ( !params.xlarge ) {
            DREP_SWF(
                new_genomes,
                new_data_checkm,
                extra_weight_table_new_genomes
            )
            dereplicated_genomes = DREP_SWF
        } else {
            DREP_LARGE_SWF(
                new_genomes,
                new_data_checkm,
                extra_weight_table_new_genomes
            )
            dereplicated_genomes = DREP_LARGE_SWF
        }
        all_assembly_stats = new_genome_stats
    }

    // make pan-genome trees
    MASH_TO_NWK(
        dereplicated_genomes.out.mash_splits | flatten
    )
    
    GTDBTK_QC(
      dereplicated_genomes.out.single_genomes_fna_tuples.map({ it[1] })
          .mix(
              dereplicated_genomes.out.many_genomes_fna_tuples.filter { it[1].name.contains(it[0]) }
                  .map({ it[1] })
          )
        .collect(),
        channel.value("fa"), // genome file extension
        ch_gtdb_db
    )

    gtdbtk_tables_qc_ch = channel.empty() \
        .mix(GTDBTK_QC.out.gtdbtk_summary_bac120, GTDBTK_QC.out.gtdbtk_summary_arc53) \
        .collectFile(name: 'gtdbtk.summary.tsv')
        
    PARSE_DOMAIN(
        gtdbtk_tables_qc_ch,
        dereplicated_genomes.out.drep_split_text
    )
    
    accessions_with_domains_ch = PARSE_DOMAIN.out.detected_domains.flatMap { file ->
        file.readLines().collect { line ->
            def (genomeName, domain) = line.split(',')
            [genomeName, domain]
        }
    }
            
    PROCESS_MANY_GENOMES(
        dereplicated_genomes.out.many_genomes_fna_tuples,
        accessions_with_domains_ch
    )

    PROCESS_SINGLETON_GENOMES(
        dereplicated_genomes.out.single_genomes_fna_tuples,
        new_data_checkm.first(),
        accessions_with_domains_ch,
        ch_gunc_db
    )
    
    GENERATE_COMBINED_QC_REPORT(
        qs50_failed,
        PROCESS_SINGLETON_GENOMES.out.gunc_failed_txt,
        PARSE_DOMAIN.out.detected_domains
    )

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
    
    // Do the same with genomes that were removed by GUNC (these are loaded from file first)
    gunc_removed_genomes = PROCESS_SINGLETON_GENOMES.out.gunc_failed_txt.map { file_path ->
        def contents = file(file_path).splitText().collect { line ->
        line.trim()
        }
        return contents
    }.flatten().map(it -> [it, "to_remove"])
    
    // Make a single set of tuples to remove, then remove these from fna tuples for singleton genomes
    combined_list_to_remove = gunc_removed_genomes.concat(undefined_genomes)
    filtered_single_genome_fna_tuples = dereplicated_genomes.out.single_genomes_fna_tuples \
        .join(combined_list_to_remove, remainder: true) \
        .filter { genome_name, fa_path, remove_flag -> remove_flag == null} \
        .map { genome_name, fa_path, remove_flag -> [genome_name, fa_path] }
    
    GTDBTK_TAX(
        filtered_single_genome_fna_tuples 
        .map({ it[1] }) 
        .mix( 
            dereplicated_genomes.out.many_genomes_fna_tuples 
                .filter { 
                    it[1].name.contains(it[0])
                }
                .map({ it[1] })
        ) 
        .collect(),
        channel.value("fa"), // genome file extension
        ch_gtdb_db,
        combined_list_to_remove.count(),
        GTDBTK_QC.out.gtdbtk_summary_bac120.ifEmpty(file("EMPTY")),
        GTDBTK_QC.out.gtdbtk_summary_arc53.ifEmpty(file("EMPTY")),
        GTDBTK_QC.out.gtdbtk_user_msa_bac120.ifEmpty(file("EMPTY")),
        GTDBTK_QC.out.gtdbtk_user_msa_ar53.ifEmpty(file("EMPTY")),
        GTDBTK_QC.out.gtdbtk_output_tarball
    )

    gtdbtk_tables_ch = channel.empty() \
        .mix(GTDBTK_TAX.out.gtdbtk_summary_bac120, GTDBTK_TAX.out.gtdbtk_summary_arc53) \
        .collectFile(name: 'gtdbtk.summary.tsv')

    
    MMSEQ_SWF(
        PROCESS_MANY_GENOMES.out.prokka_faas.map({ it[1] }).collectFile(name: "pangenome_prokka.faa"),
        PROCESS_SINGLETON_GENOMES.out.prokka_faa.map({ it[1] }).collectFile(name: "singleton_prokka.faa"),
        genomes_name_mapping.first(),
        ch_mmseq_coverage_threshold
    )

    cluster_reps_faas = PROCESS_MANY_GENOMES.out.rep_prokka_faa.mix(
        PROCESS_SINGLETON_GENOMES.out.prokka_faa
    )

    cluster_reps_fnas = PROCESS_MANY_GENOMES.out.rep_prokka_fna.mix(
        PROCESS_SINGLETON_GENOMES.out.prokka_fna
    )

    cluster_reps_gbks = PROCESS_MANY_GENOMES.out.rep_prokka_gbk.mix(
        PROCESS_SINGLETON_GENOMES.out.prokka_gbk
    )
    
    cluster_reps_gffs = PROCESS_MANY_GENOMES.out.rep_prokka_gff.mix(
        PROCESS_SINGLETON_GENOMES.out.prokka_gff
    )

    all_prokka_fna = PROCESS_SINGLETON_GENOMES.out.prokka_fna.mix(
        PROCESS_MANY_GENOMES.out.prokka_fnas
    )

    species_reps_names_list = PROCESS_MANY_GENOMES.out.rep_prokka_fna.map({ it[0] }) \
        .mix(PROCESS_SINGLETON_GENOMES.out.prokka_fna.map({ it[0] })) \
        .collectFile(name: "species_reps_names_list.txt", newLine: true)

    ANNOTATE_ALL_DOMAINS(
        MMSEQ_SWF.out.mmseq_90_cluster_tsv,
        MMSEQ_SWF.out.mmseq_90_tarball,
        MMSEQ_SWF.out.mmseq_90_cluster_rep_faa,
        cluster_reps_gbks,
        cluster_reps_faas,
        cluster_reps_gffs,
        species_reps_names_list,
        ch_interproscan_db,
        ch_eggnog_db,
        ch_eggnog_diamond_db,
        ch_eggnog_data_dir,
        ch_dbcan_db,
        ch_antismash_db
    )
    
    ANNOTATE_PROKARYOTES(
        cluster_reps_gbks,
        cluster_reps_faas,
        cluster_reps_gffs,
        cluster_reps_fnas,
        ANNOTATE_ALL_DOMAINS.out.ips_annotation_tsvs,
        ch_defense_finder_db
    )
    
    DETECT_RNA(
        all_prokka_fna,
        accessions_with_domains_ch,
        ch_rfam_ncrna_models
    )
    
    METADATA_AND_PHYLOTREE(
        cluster_reps_fnas.map({ it[1]}).collect(),
        all_prokka_fna.map({ it[1] }).collect(),
        extra_weight_table_new_genomes,
        new_data_checkm,
        DETECT_RNA.out.rrna_outs.flatMap {it -> it[1..-1]}.collect(),
        genomes_name_mapping,
        dereplicated_genomes.out.drep_split_text,
        ch_ftp_name,
        ch_ftp_version,
        ch_geo_metadata,
        PROCESS_SINGLETON_GENOMES.out.gunc_failed_txt.ifEmpty("EMPTY"),
        gtdbtk_tables_ch,
        //ch_previous_catalogue_location,
        //all_assembly_stats
    )

    /*
    IQTree needs at least 3 sequences, but it's too slow for more than 2000 sequences so we use FastTree in that case
    */
    def treeCreationCriteria = branchCriteria {
        iqtree: file(it).countFasta() > 2 && file(it).countFasta() < 2000
        fasttree: file(it).countFasta() >= 2000
    }

    GTDBTK_TAX.out.gtdbtk_user_msa_bac120.branch( treeCreationCriteria ).set { gtdbtk_user_msa_bac120 }

    IQTREE_BAC(
        gtdbtk_user_msa_bac120.iqtree,
        channel.value("bac120")
    )
    FASTTREE_BAC(
        gtdbtk_user_msa_bac120.fasttree,
        channel.value("bac120")
    )

    GTDBTK_TAX.out.gtdbtk_user_msa_ar53.branch( treeCreationCriteria ).set{ gtdbtk_user_msa_ar53 }

    IQTREE_AR(
        gtdbtk_user_msa_ar53.iqtree,
        channel.value("ar53")
    )
    FASTTREE_AR(
        gtdbtk_user_msa_ar53.fasttree,
        channel.value("ar53")
    )

    faa_and_annotations = cluster_reps_faas.join(
        ANNOTATE_ALL_DOMAINS.out.ips_annotation_tsvs
    ).join(
        ANNOTATE_ALL_DOMAINS.out.eggnog_annotation_tsvs
    )

    FUNCTIONAL_ANNOTATION_SUMMARY(
        faa_and_annotations,
        ch_kegg_classes
    )

    INDEX_FNA(
        all_prokka_fna
    )

    cluster_reps_gff = PROCESS_SINGLETON_GENOMES.out.prokka_gff.mix(
        PROCESS_MANY_GENOMES.out.rep_prokka_gff
    )

    // Select the only the reps //
    // Those where the cluster-name and the file name match
    // i.e., such as cluster_name: MGY1 and file MGY1_eggnog.tsv
    reps_ips = ANNOTATE_ALL_DOMAINS.out.ips_annotation_tsvs.filter {
        it[1].name.contains(it[0])
    }
    reps_eggnog = ANNOTATE_ALL_DOMAINS.out.eggnog_annotation_tsvs.filter {
        it[1].name.contains(it[0])
    }
    all_ncrna = DETECT_RNA.out.ncrna_tblout.filter {
        it[1].name.contains(it[0])
    }
    
    // Filter DETECT_RNA.out.trna_gff to only save tRNA GFFs for species reps to reps_trna_gff
    reps_trna_gff = cluster_reps_gff.join(DETECT_RNA.out.trna_gff, remainder: true)
    .filter { it -> it[1] != null }  // Remove tuples where there is no species rep genome GFF (= this is not a rep)
    .map { it -> [it[0], it[2]] }  // 
    
    // Filter all_ncrna to only keep results for species reps
    reps_ncrna = cluster_reps_gff.join(all_ncrna, remainder: true)
    .filter { it -> it[1] != null }  // Remove tuples where there is no species rep genome GFF (= this is not a rep)
    .map { it -> [it[0], it[2]] }  // 
        
    // REPS //
    ANNOTATE_GFF(
        cluster_reps_gff.join(
            reps_eggnog
        ).join(
            reps_ncrna
        ).join(
            reps_trna_gff
        ).join(
            ANNOTATE_PROKARYOTES.out.crisprcasfinder_hq_gff, remainder: true
        ).join(
            ANNOTATE_PROKARYOTES.out.amrfinder_tsv, remainder: true
        ).join(
            ANNOTATE_ALL_DOMAINS.out.antismash_gffs, remainder: true
        ).join(
            ANNOTATE_PROKARYOTES.out.gecco_gffs, remainder: true
        ).join(
            ANNOTATE_ALL_DOMAINS.out.dbcan_gffs, remainder: true
        ).join(
            ANNOTATE_PROKARYOTES.out.defense_finder_gffs, remainder: true
        ).join(
            reps_ips
        ).join(
            ANNOTATE_PROKARYOTES.out.sanntis_annotation_gffs, remainder: true
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
    files_for_json_summary = ANNOTATE_GFF.out.annotated_gff.join(
        FUNCTIONAL_ANNOTATION_SUMMARY.out.coverage
    ).join(
        cluster_reps_faas
    ).join(
        PROCESS_MANY_GENOMES.out.panaroo_pangenome_fna, remainder: true
    ).join(
        PROCESS_MANY_GENOMES.out.core_genes, remainder: true
    )

    GENOME_SUMMARY_JSON(
        files_for_json_summary,
        METADATA_AND_PHYLOTREE.out.metadata_tsv.first(),
        ch_biome
    )

    KRAKEN_SWF(
        GTDBTK_TAX.out.gtdbtk_summary_bac120,
        GTDBTK_TAX.out.gtdbtk_summary_arc53,
        cluster_reps_fnas.map({ it[1] })
    )

    cluster_rep_ffn = PROCESS_SINGLETON_GENOMES.out.prokka_ffn.mix(
        PROCESS_MANY_GENOMES.out.rep_prokka_ffn
    )

    GENE_CATALOGUE(
        cluster_rep_ffn.map({ it[1] }).collectFile(name: "cluster_reps.ffn", newLine: true),
        MMSEQ_SWF.out.mmseq_100_cluster_tsv
    )

    MASH_SKETCH(
        all_prokka_fna.map({ it[1] }).collect()
    )
}
