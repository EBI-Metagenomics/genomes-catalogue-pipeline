/*
 * Process a clusters with multiples genomes
*/

include { PANAROO             } from '../modules/panaroo'
include { CORE_GENES          } from '../modules/core_genes'
include { PROKKA              } from '../modules/prokka'
include { CONCAT_FFN          } from '../modules/concat_ffn'
include { MMSEQS_EASYCLUSTER  } from '../modules/mmseqs_easycluster'
include { BUILD_MATRIX        } from '../modules/build_matrix'


workflow PROCESS_MANY_GENOMES {
    take:
        many_genomes_clusters          // list<tuple(cluster_name, genome_fna)>
        accessions_with_domains_tuples // tuple( mgyg_accession, domain ) - the domain is either "Bacteria", "Archaea" or "Undefined"

    main:

        PROKKA(
            many_genomes_clusters.combine(accessions_with_domains_tuples)
            .filter { genome_name_fa, fa_path, genome_name_domain, domain -> genome_name_fa == genome_name_domain }
            .map { genome_name_fa, fa_path, genome_name_domain, domain -> [genome_name_fa, fa_path, domain] }
        )

        // Group by cluster
        pangenome_prokka_gff_tuple = PROKKA.out.gff | groupTuple()

        // Route by cluster size: below threshold → Panaroo, at/above → mmseqs2
        // params.mmseqs2_pangenome_switch controls the cutoff (default: 1000)
        small_cluster_gff = pangenome_prokka_gff_tuple
            .filter { cluster_name, gff_files -> gff_files.size() < params.mmseqs2_pangenome_switch }

        large_cluster_gff = pangenome_prokka_gff_tuple
            .filter { cluster_name, gff_files -> gff_files.size() >= params.mmseqs2_pangenome_switch }

        // --- Small clusters → Panaroo ---
        PANAROO( small_cluster_gff )

        // --- Large clusters → mmseqs2 ---
        large_cluster_ffn = PROKKA.out.ffn
            | groupTuple()
            | filter { cluster_name, ffn_files -> ffn_files.size() >= params.mmseqs2_pangenome_switch }
            | map    { cluster_name, ffn_files -> [ cluster_name, ffn_files ] }

        large_cluster_gff_meta = large_cluster_gff
            .map { cluster_name, gff_files -> [ cluster_name, gff_files ] }

        CONCAT_FFN( large_cluster_ffn )

        MMSEQS_EASYCLUSTER( CONCAT_FFN.out.ffn )

        BUILD_MATRIX(
            MMSEQS_EASYCLUSTER.out.tsv
                .join( MMSEQS_EASYCLUSTER.out.representatives )
                .join( large_cluster_gff_meta )
        )

        mmseqs_pangenome_fna = BUILD_MATRIX.out.fna.map { cluster_name, fna -> [cluster_name, fna] }
        mmseqs_rtab          = BUILD_MATRIX.out.rtab.map { cluster_name, fna -> [cluster_name, fna] }

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
        rep_prokka_gff = PROKKA.out.gff.filter { it[1].name.contains(it[0]) }
        rep_prokka_faa = PROKKA.out.faa.filter { it[1].name.contains(it[0]) }
        rep_prokka_fna = PROKKA.out.fna.filter { it[1].name.contains(it[0]) }
        rep_prokka_gbk = PROKKA.out.gbk.filter { it[1].name.contains(it[0]) }
        rep_prokka_ffn = PROKKA.out.ffn.filter { it[1].name.contains(it[0]) }

        non_rep_prokka_gff = PROKKA.out.gff.filter { !it[1].name.contains(it[0]) }
        non_rep_prokka_fna = PROKKA.out.fna.filter { !it[1].name.contains(it[0]) }

    emit:
        pangenome_fna         = PANAROO.out.panaroo_pangenome_fna.mix( mmseqs_pangenome_fna )
        pangenome_rtab        = PANAROO.out.panaroo_gene_presence_absence.mix( mmseqs_rtab )    // we need this for celebrimbor
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
