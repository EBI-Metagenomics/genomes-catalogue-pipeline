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

        rep_gene_caller_gff = EUK_GENE_CALLING.out.gffs.filter {
            it[1].name.contains(it[0])
        }
        rep_gene_caller_faa = EUK_GENE_CALLING.out.proteins.filter {
            it[1].name.contains(it[0])
        }
        rep_gene_caller_fna = EUK_GENE_CALLING.out.softmasked_genomes.filter {
            it[1].name.contains(it[0])
        }
        rep_gene_caller_ffn = EUK_GENE_CALLING.out.ffns.filter {
            it[1].name.contains(it[0])
        }

        non_rep_gene_caller_gff = EUK_GENE_CALLING.out.gffs.filter {
            !it[1].name.contains(it[0])
        }
        non_rep_gene_caller_fna = EUK_GENE_CALLING.out.softmasked_genomes.filter {
            !it[1].name.contains(it[0])
        }

    emit:
        gene_caller_faas = EUK_GENE_CALLING.out.proteins
        gene_caller_fnas = EUK_GENE_CALLING.out.softmasked_genomes
        gene_caller_ffns = EUK_GENE_CALLING.out.ffns
        gene_caller_gffs = EUK_GENE_CALLING.out.gffs
        rep_gene_caller_fna = rep_gene_caller_fna
        rep_gene_caller_gff = rep_gene_caller_gff
        rep_gene_caller_faa = rep_gene_caller_faa
        rep_gene_caller_ffn = rep_gene_caller_ffn
        non_rep_gene_caller_fna = non_rep_gene_caller_fna
        non_rep_gene_caller_gff = non_rep_gene_caller_gff
        gene_calls = EUK_GENE_CALLING.out.gene_calls
}
