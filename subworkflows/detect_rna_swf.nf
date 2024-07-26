/*
 * Run RNA detection
*/

include { DETECT_NCRNA } from '../modules/detect_ncrna'
include { DETECT_TRNA } from '../modules/detect_trna'

workflow DETECT_RNA {
    take:
        all_prokka_fnas
        accessions_with_domains
        rfam_ncrna_models
    main:
        DETECT_TRNA(
            all_prokka_fnas.map(it -> [it[1].baseName, it[1]]).join(
                accessions_with_domains
            )
        )
       DETECT_NCRNA(
            all_prokka_fnas,
            rfam_ncrna_models
       )
    emit:
        ncrna_tblout = DETECT_NCRNA.out.ncrna_tblout
        rrna_outs = DETECT_NCRNA.out.rrna_out_results.join(DETECT_TRNA.out.trna_count)
}