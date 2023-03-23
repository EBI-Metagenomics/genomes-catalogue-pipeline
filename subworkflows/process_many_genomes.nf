/*
 * Process a clusters with multiples genomes
*/

include { PANAROO } from '../modules/panaroo'
include { CORE_GENES } from '../modules/core_genes'
include { PROKKA } from '../modules/prokka'


workflow PROCESS_MANY_GENOMES {
    take:
        many_genomes_clusters // list<tuple(cluster_name, genome_fna)>
    main:

        PROKKA(
            many_genomes_clusters
        )

        // Group by cluster
        pangenome_prokka_gff_tuple = PROKKA.out.gff | groupTuple()

        PANAROO(
            pangenome_prokka_gff_tuple
        )

        pangenome_panaroo_gene_presence_absence_tuples = PANAROO.out.panaroo_gene_presence_absence | groupTuple()

        CORE_GENES(
            pangenome_panaroo_gene_presence_absence_tuples
        )

        rep_prokka_gff = PROKKA.out.gff.filter {
            it[1].name.contains(it[0])
        }
        rep_prokka_faa = PROKKA.out.faa.filter {
            it[1].name.contains(it[0])
        }
        rep_prokka_fna = PROKKA.out.fna.filter {
            it[1].name.contains(it[0])
        }
        rep_prokka_gbk = PROKKA.out.gbk.filter {
            it[1].name.contains(it[0])
        }
        rep_prokka_ffn = PROKKA.out.ffn.filter {
            it[1].name.contains(it[0])
        }

        non_rep_prokka_gff = PROKKA.out.gff.filter {
            !it[1].name.contains(it[0])
        }
        non_rep_prokka_fna = PROKKA.out.fna.filter {
            !it[1].name.contains(it[0])
        }

    emit:
        panaroo_pangenome_fna = PANAROO.out.panaroo_pangenome_fna
        prokka_faas = PROKKA.out.faa
        prokka_fnas = PROKKA.out.fna
        prokka_gffs = PROKKA.out.gff
        rep_prokka_fna = rep_prokka_fna
        rep_prokka_gff = rep_prokka_gff
        rep_prokka_faa = rep_prokka_faa
        rep_prokka_gbk = rep_prokka_gbk
        rep_prokka_ffn = rep_prokka_ffn
        non_rep_prokka_fna = non_rep_prokka_fna
        non_rep_prokka_gff = non_rep_prokka_gff
        core_genes = CORE_GENES.out.core_genes
}
