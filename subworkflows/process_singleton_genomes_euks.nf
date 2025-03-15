/*
 * Run GUNC and Prokka on the singletons
*/

include { GROUP_GENOME_PROTEINS } from '../modules/group_genomes_and_proteins'
include { EUK_GENE_CALLING } from '../subworkflows/eukaryotic_gene_annotation'


workflow PROCESS_SINGLETON_GENOMES_EUKS {
    take:
        singleton_cluster_tuple // list<tuple(cluster_name, genome_fna)>
        mapping_file // genome name mapping
        protein_evidence // file of fasta files and protein evidence

    main:

        GROUP_GENOME_PROTEINS(
            singleton_cluster_tuple,
            mapping_file.first(),
            protein_evidence
        )

        EUK_GENE_CALLING(GROUP_GENOME_PROTEINS.out.tuple_with_proteins)

    emit:
        prokka_gff = EUK_GENE_CALLING.out.gff
        prokka_faa = EUK_GENE_CALLING.out.proteins
        prokka_fna = EUK_GENE_CALLING.out.softmasked_genome
        prokka_ffn = EUK_GENE_CALLING.out.ffn
}
