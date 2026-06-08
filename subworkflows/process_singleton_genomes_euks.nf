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
        taxonomy_map // eukaryotic_taxonomy_reformatted.tsv (REFORMAT_BAT.out.taxonomy)

    main:

        GROUP_GENOME_PROTEINS(
            singleton_cluster_tuple,
            mapping_file.first(),
            protein_evidence
        )

        EUK_GENE_CALLING(GROUP_GENOME_PROTEINS.out.tuple_with_proteins, taxonomy_map)

    emit:
        gene_caller_gff = EUK_GENE_CALLING.out.gffs
        gene_caller_faa = EUK_GENE_CALLING.out.proteins
        gene_caller_fna = EUK_GENE_CALLING.out.softmasked_genomes
        gene_caller_ffn = EUK_GENE_CALLING.out.ffns
}
