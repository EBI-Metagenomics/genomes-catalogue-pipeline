/*
 * Process a clusters with multiples genomes
*/

include { PANAROO             } from '../modules/panaroo'
include { CORE_GENES          } from '../modules/core_genes'
include { PROKKA              } from '../modules/prokka'
include { CONCAT_FFN          } from '../modules/concat_ffn'
include { MMSEQS_EASYCLUSTER  } from '../modules/mmseqs_easycluster'
include { BUILD_MATRIX        } from '../modules/build_matrix'
include { CGT                 } from '../modules/cgt'

workflow PROCESS_MANY_GENOMES {
    take:
        many_genomes_clusters          // list<tuple(cluster_name, genome_fna)>
        accessions_with_domains_tuples // tuple( mgyg_accession, domain ) - the domain is either "Bacteria", "Archaea" or "Undefined"
        genomes_checkm                 // 

    main:

        PROKKA(
            many_genomes_clusters.combine(accessions_with_domains_tuples)
            .filter { genome_name_fa, fa_path, genome_name_domain, domain -> genome_name_fa == genome_name_domain }
            .map { genome_name_fa, fa_path, genome_name_domain, domain -> [genome_name_fa, fa_path, domain] }
        )

        // Group by cluster
        pangenome_prokka_gff_tuple = PROKKA.out.gff | groupTuple()

        // Route by cluster size: below threshold → Panaroo, at/above → mmseqs2
        // params.pangenome_panaroo_limit_threshold controls the cutoff (default: 1000)
        pangenome_prokka_gff_tuple.branch {
            cluster_name, gff_files ->
                small: gff_files.size() < params.pangenome_panaroo_limit_threshold
                large: true
        }.set { cluster_gff }

        small_cluster_gff = cluster_gff.small
        large_cluster_gff = cluster_gff.large

        // --- Small clusters → Panaroo ---
        PANAROO( small_cluster_gff )

        // --- Large clusters → mmseqs2 ---
        large_cluster_ffn = PROKKA.out.ffn
            | groupTuple()
            | filter { cluster_name, ffn_files -> ffn_files.size() >= params.pangenome_panaroo_limit_threshold }

        large_cluster_gff_meta = large_cluster_gff

        CONCAT_FFN( large_cluster_ffn )

        MMSEQS_EASYCLUSTER( CONCAT_FFN.out.ffn )

        BUILD_MATRIX(
            MMSEQS_EASYCLUSTER.out.tsv
                .join( MMSEQS_EASYCLUSTER.out.representatives )
                .join( large_cluster_gff_meta )
        )

        mmseqs_pangenome_fna = BUILD_MATRIX.out.fna.map { cluster_name, fna -> [cluster_name, fna] }
        mmseqs_rtab          = BUILD_MATRIX.out.rtab.map { cluster_name, tab -> [cluster_name, tab] }


        // --- Correcting pangenome using cgt ---
        pangenome_rtab = PANAROO.out.panaroo_gene_presence_absence.mix( mmseqs_rtab )

        CGT(
            pangenome_rtab
                .combine(genomes_checkm.first())
                .map { cluster_name, rtab, checkm2 -> [cluster_name, checkm2, rtab] }
        )

        // --- CORE_GENES runs on both paths ---
        // Panaroo and mmseqs2 Rtab channels are mixed before calling CORE_GENES.
        // The mmseqs2 channel maps meta.id (= cluster_name) back to the plain
        // cluster_name key so both sides have the same tuple structure.
        CORE_GENES(
            ( PANAROO.out.panaroo_gene_presence_absence | groupTuple() )
                .mix(
                    BUILD_MATRIX.out.rtab | groupTuple()
                )
        )

        // --- Representative / non-representative genome filters ---
        PROKKA.out.gff.branch {
            cluster_name, gff ->
                rep:     gff.name.contains(cluster_name)
                non_rep: true
        }.set { prokka_gff }
        rep_prokka_gff     = prokka_gff.rep
        non_rep_prokka_gff = prokka_gff.non_rep

        PROKKA.out.fna.branch {
            cluster_name, fna ->
                rep:     fna.name.contains(cluster_name)
                non_rep: true
        }.set { prokka_fna }
        rep_prokka_fna     = prokka_fna.rep
        non_rep_prokka_fna = prokka_fna.non_rep

        rep_prokka_faa = PROKKA.out.faa.filter { it[1].name.contains(it[0]) }
        rep_prokka_gbk = PROKKA.out.gbk.filter { it[1].name.contains(it[0]) }
        rep_prokka_ffn = PROKKA.out.ffn.filter { it[1].name.contains(it[0]) }

    emit:
        pangenome_fna         = PANAROO.out.panaroo_pangenome_fna.mix( mmseqs_pangenome_fna )
        prokka_faas           = PROKKA.out.faa
        prokka_fnas           = PROKKA.out.fna
        prokka_gffs           = PROKKA.out.gff
        rep_prokka_fna        = rep_prokka_fna
        rep_prokka_gff        = rep_prokka_gff
        rep_prokka_faa        = rep_prokka_faa
        rep_prokka_gbk        = rep_prokka_gbk
        rep_prokka_ffn        = rep_prokka_ffn
        non_rep_prokka_fna    = non_rep_prokka_fna
        non_rep_prokka_gff    = non_rep_prokka_gff
        core_genes            = CORE_GENES.out.core_genes
}
