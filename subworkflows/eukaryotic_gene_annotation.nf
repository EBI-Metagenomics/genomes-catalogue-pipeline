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

        tuple_genome_proteins_nocluster = tuple_genome_proteins.map { _cluster, genome, proteins ->
            tuple(genome.baseName, genome, proteins)
        }
        cluster_name_ch = tuple_genome_proteins.map { cluster, genome, _proteins ->
            tuple(genome.baseName, cluster)
        }

        // Use join with remainder to handle genomes without repeat families
        genomes_after_repeatmodeler = tuple_genome_proteins_nocluster
            .join(REPEAT_MODELER.out.repeat_families, remainder: true)
            .branch { genome_name, genome, prot_evidence, repeat_families ->
                with_repeats: repeat_families != null
                    return tuple(genome_name, genome, prot_evidence, repeat_families)
                without_repeats: true
                    return tuple(genome_name, genome)
            }

        // Process genomes with repeats through REPEAT_MASKER
        ch_repeat_masker_input = genomes_after_repeatmodeler.with_repeats
            .multiMap { genome_name, genome, prot_evidence, repeat_families ->
                genome_proteins: tuple(genome_name, genome, prot_evidence)
                repeat_families: tuple(genome_name, repeat_families)
            }

        REPEAT_MASKER(
            ch_repeat_masker_input.genome_proteins,
            ch_repeat_masker_input.repeat_families
        )

        // Combine masked genomes with unmasked genomes
        def all_genomes_for_braker = REPEAT_MASKER.out.masked_genome
            .mix(genomes_after_repeatmodeler.without_repeats)

        // Prepare channels for BRAKER
        ch_braker_input = tuple_genome_proteins_nocluster
            .map { genome_name, _genome, prot_evidence ->
                tuple(genome_name, prot_evidence)
            }
            .join(all_genomes_for_braker)
            .multiMap { genome_name, prot_evidence, genome ->
                masked_genome: tuple(genome_name, genome)
                genome_proteins: tuple(genome_name, prot_evidence)
            }

        BRAKER(
            ch_braker_input.masked_genome,
            ch_braker_input.genome_proteins
        )

        ch_braker = cluster_name_ch
            .join( tuple_genome_proteins_nocluster )
            .join( BRAKER.out.gff3 )
            .join( BRAKER.out.proteins )
            .join( BRAKER.out.ffn )
            .join( all_genomes_for_braker )
            .multiMap { genome_name, cluster, _genome, _prot_evidence, gff, faa, ffn, masked_genome ->
                genome: [cluster, genome_name, masked_genome]
                gff: [genome_name, gff]
                faa: [genome_name, faa]
                ffn: [genome_name, ffn]
            }

        BRAKER_POSTPROCESSING(
            ch_braker.genome,
            ch_braker.gff,
            ch_braker.faa,
            ch_braker.ffn
        )

        output_ch = cluster_name_ch
            .join( BRAKER_POSTPROCESSING.out.renamed_gff3 )
            .join( BRAKER_POSTPROCESSING.out.renamed_proteins )
            .join( BRAKER_POSTPROCESSING.out.renamed_ffn )
            .join( all_genomes_for_braker )
            .multiMap { _genome_name, cluster_name, gff, faa, ffn, masked_genome ->
                masked_genome: [cluster_name, masked_genome]
                gff: [cluster_name, gff]
                faa: [cluster_name, faa]
                ffn: [cluster_name, ffn]
            }

    emit:
        gffs = output_ch.gff
        proteins = output_ch.faa
        ffns = output_ch.ffn
        softmasked_genomes = output_ch.masked_genome
}
