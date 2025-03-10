 /*
  Subworkflow to annotate eukaryotic genes
*/

include { REPEAT_MODELER } from '../modules/repeatmodeler.nf'
include { REPEAT_MASKER } from '../modules/repeatmasker.nf'
include { BRAKER } from '../modules/braker.nf' 


workflow EUK_GENE_CALLING {
    take:
        genome
        proteins

    main:

        REPEAT_MODELER(
            genome
        )

        REPEAT_MASKER(
            genome, 
            REPEAT_MODELER.out.repeat_families
        )

        BRAKER(
            REPEAT_MASKER.out.masked_genome,
            proteins,
            [],
            [],
            []
        )

    emit:
        gff = BRAKER.out.gff3
        proteins = BRAKER.out.proteins
        ffn = BRAKER.out.ffn
        headers_map = BRAKER.out.headers_map

}