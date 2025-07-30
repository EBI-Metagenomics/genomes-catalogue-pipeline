/*
 * Process a clusters with multiples genomes
*/

include { GROUP_GENOME_PROTEINS } from '../modules/group_genomes_and_proteins'
include { EUK_GENE_CALLING } from '../subworkflows/eukaryotic_gene_annotation'


workflow PROCESS_MANY_GENOMES_EUKS {
    take:

        many_genomes_clusters // list<tuple(cluster_name, genome_fna)>
        mapping_file // genome name mapping
        protein_evidence // file of fasta files and protein evidence

    main:

        GROUP_GENOME_PROTEINS(
            many_genomes_clusters,
            mapping_file.first(),
            protein_evidence
        )

        EUK_GENE_CALLING(GROUP_GENOME_PROTEINS.out.tuple_with_proteins)

        rep_braker_gff = EUK_GENE_CALLING.out.gff.filter {
            it[1].name.contains(it[0])
        }
        rep_braker_faa = EUK_GENE_CALLING.out.proteins.filter {
            it[1].name.contains(it[0])
        }
        rep_braker_fna = EUK_GENE_CALLING.out.softmasked_genome.filter {
            it[1].name.contains(it[0])
        }
        rep_braker_ffn = EUK_GENE_CALLING.out.ffn.filter {
            it[1].name.contains(it[0])
        }

        non_rep_braker_gff = EUK_GENE_CALLING.out.gff.filter {
            !it[1].name.contains(it[0])
        }
        non_rep_braker_fna = EUK_GENE_CALLING.out.softmasked_genome.filter {
            !it[1].name.contains(it[0])
        }

    emit:
        braker_faas = EUK_GENE_CALLING.out.proteins
        braker_fnas = EUK_GENE_CALLING.out.softmasked_genome
        braker_gffs = EUK_GENE_CALLING.out.gff
        rep_braker_fna = rep_braker_fna
        rep_braker_gff = rep_braker_gff
        rep_braker_faa = rep_braker_faa
        rep_braker_ffn = rep_braker_ffn
        non_rep_braker_fna = non_rep_braker_fna
        non_rep_braker_gff = non_rep_braker_gff
}
