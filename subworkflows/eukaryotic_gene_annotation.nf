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

        tuple_genome_proteins_nocluster = tuple_genome_proteins.map { cluster, genome, proteins -> tuple(genome.baseName, genome, proteins) }
        cluster_name_ch = tuple_genome_proteins.map { cluster, genome, proteins -> tuple(genome.baseName, cluster) }
        
        ch_repeat_masker = Channel.empty()

        tuple_genome_proteins_nocluster.join( REPEAT_MODELER.out.repeat_families ).multiMap { genome_name, genome, prot_evidence, repeat_families ->
            genome_proteins: [genome_name, genome, prot_evidence]
            repeat_families: [genome_name, repeat_families]
        }.set {
            ch_repeat_masker
        }

        REPEAT_MASKER(
            ch_repeat_masker.genome_proteins, 
            ch_repeat_masker.repeat_families, 
        )

        ch_repeat_modeler = Channel.empty()

        tuple_genome_proteins_nocluster.join( REPEAT_MASKER.out.masked_genome ).multiMap { genome_name, genome, prot_evidence, masked_genome ->
            genome_proteins: [genome_name, prot_evidence]
            masked_genome: [genome_name, masked_genome]
        }.set {
            ch_repeat_modeler
        }

        BRAKER(
            ch_repeat_modeler.masked_genome,
            ch_repeat_modeler.genome_proteins
        )

        ch_braker = Channel.empty()
        cluster_name_ch
            .join( tuple_genome_proteins_nocluster )
            .join( BRAKER.out.gff3 )
            .join( BRAKER.out.proteins )
            .join( BRAKER.out.ffn )
            .join( ch_repeat_modeler.masked_genome ).multiMap { genome_name, cluster, genome, prot_evidence, gff, faa, ffn, masked_genome ->
                genome: [cluster, genome_name, masked_genome]
                gff: [genome_name, gff]
                faa: [genome_name, faa]
                ffn: [genome_name, ffn]
        }.set {
            ch_braker
        }

        BRAKER_POSTPROCESSING(
            ch_braker.genome,
            ch_braker.gff,
            ch_braker.faa,
            ch_braker.ffn
        )
        
        output_ch = Channel.empty()
        cluster_name_ch
            .join( BRAKER_POSTPROCESSING.out.renamed_gff3 )
            .join( BRAKER_POSTPROCESSING.out.renamed_proteins )
            .join( BRAKER_POSTPROCESSING.out.renamed_ffn )
            .join( ch_repeat_modeler.masked_genome ).multiMap { genome_name, cluster_name, gff, faa, ffn, masked_genome ->
                masked_genome: [cluster_name, masked_genome]
                gff: [cluster_name, gff]
                faa: [cluster_name, faa]
                ffn: [cluster_name, ffn]
        }.set {
            output_ch
        }

    emit:
        gff = output_ch.gff
        proteins = output_ch.faa
        ffn = output_ch.ffn
        softmasked_genome = output_ch.masked_genome
}
