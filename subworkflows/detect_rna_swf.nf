/*
 * Run RNA detection
*/

include { DETECT_NCRNA } from '../modules/detect_ncrna'
include { DETECT_TRNA  } from '../modules/detect_trna'

workflow DETECT_RNA {

    take:
    fnas                      // channel: [ val(cluster_name), path(fasta) ] - softmasked genomes
    accessions_with_domains   // channel: [ val(genome_name), val(domain) ] - assigned domain for each genome
    rfam_ncrna_models         // val(path) - to RFAM ncRNA models
    kingdom                   // val(kingdom) - either "eukaryotes" or "prokaryotes"

    main:
    DETECT_TRNA(
        fnas.map{ _cluster_name, genome_fasta -> [genome_fasta.baseName, genome_fasta] }
            .join(accessions_with_domains, remainder: true)
            .filter { _genome_name, genome_fasta, _domain -> // TODO: check if this filter is necessary
                genome_fasta != null  // remove genomes that were filtered out during QC and don't have an fna
            }
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
