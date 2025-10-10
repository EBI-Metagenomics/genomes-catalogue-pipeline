/*
 * Run RNA detection
*/

include { DETECT_NCRNA } from '../modules/detect_ncrna'
include { DETECT_TRNA } from '../modules/detect_trna'

workflow DETECT_RNA {
    take:
        fnas
        accessions_with_domains
        rfam_ncrna_models
        kingdom
    main:
        DETECT_TRNA(
            fnas.map(it -> [it[1].baseName.replace("_sm", ""), it[1]]).join(
                accessions_with_domains, remainder: true
            ).filter{  it -> it[1] != null } // remove genomes that were filtered out during QC and don't have an fna
        )
       DETECT_NCRNA(
            fnas,
            rfam_ncrna_models,
            kingdom
       )
    emit:
        ncrna_tblout = DETECT_NCRNA.out.ncrna_tblout
        rrna_outs = DETECT_NCRNA.out.rrna_out_results.join(DETECT_TRNA.out.trna_count)
        trna_gff = DETECT_TRNA.out.trna_gff
}