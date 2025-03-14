 /*
  Subworkflow to annotate eukaryotic genes
*/

include { REPEAT_MODELER } from '../modules/repeatmodeler.nf'
include { REPEAT_MASKER } from '../modules/repeatmasker.nf'
include { BRAKER } from '../modules/braker.nf' 
include { BRAKER_POSTPROCESSING } from '../modules/braker_postprocessing.nf'


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
        
        BRAKER_POSTPROCESSING(
            genome,
            BRAKER.out.gff3,
            BRAKER.out.proteins,
            BRAKER.out.ffn
        )

    emit:
        gff = BRAKER_POSTPROCESSING.out.renamed_gff3
        proteins = BRAKER_POSTPROCESSING.out.renamed_proteins
        ffn = BRAKER_POSTPROCESSING.out.renamed_ffn
        headers_map = BRAKER.out.headers_map

}