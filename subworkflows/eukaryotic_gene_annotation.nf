 /*
  Subworkflow to annotate eukaryotic genes
*/

include { REPEAT_MODELER } from '../modules/repeatmodeler.nf'
include { REPEAT_MASKER } from '../modules/repeatmasker.nf'
include { BRAKER } from '../modules/braker.nf' 
include { BRAKER_POSTPROCESSING } from '../modules/braker_postprocessing.nf'


workflow EUK_GENE_CALLING {
    take:
        tuple_genome_proteins
    main:

        REPEAT_MODELER(
            tuple_genome_proteins
        )

        REPEAT_MASKER(
            tuple_genome_proteins, 
            REPEAT_MODELER.out.repeat_families
        )

        BRAKER(
            REPEAT_MASKER.out.masked_genome,
            tuple_genome_proteins,
        )

        BRAKER_POSTPROCESSING(
            REPEAT_MASKER.out.masked_genome,
            BRAKER.out.gff3,
            BRAKER.out.proteins,
            BRAKER.out.ffn
        )

        cluster_name_ch = tuple_genome_proteins.map { it[0] }
        softmasked_genome_ch = REPEAT_MASKER.out.masked_genome
        
        sm_genome_ch = cluster_name_ch.combine(softmasked_genome_ch)

    emit:
        gff = BRAKER_POSTPROCESSING.out.renamed_gff3
        proteins = BRAKER_POSTPROCESSING.out.renamed_proteins
        ffn = BRAKER_POSTPROCESSING.out.renamed_ffn
        headers_map = BRAKER.out.headers_map
        softmasked_genome = sm_genome_ch

}