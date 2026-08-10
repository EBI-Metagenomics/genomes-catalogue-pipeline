 /*
  Subworkflow to annotate eukaryotic genes.
*/

include { REPEAT_MODELER } from '../modules/repeatmodeler.nf'
include { REPEAT_MASKER } from '../modules/repeatmasker.nf'
include { BRAKER } from '../modules/braker.nf'
include { DEDUP_GFF } from '../modules/agat_dedup.nf'
include { EXTRACT_SEQUENCES as EXTRACT_DEDUP_BRAKER_FAA } from '../modules/agat_extract_sequences.nf'
include { EXTRACT_SEQUENCES as EXTRACT_DEDUP_BRAKER_FFN } from '../modules/agat_extract_sequences.nf'
include { METAEUK } from '../modules/metaeuk.nf'
include { FIX_METAEUK_CDS_PHASES } from '../modules/agat_fix_cds_phases.nf'
include { RECONCILE_METAEUK_PHASES } from '../modules/reconcile_metaeuk_phases.nf'
include { MERGE_GENE_PREDICTIONS } from '../modules/merge_gene_predictions.nf'
include { POSTPROCESSING_GENE_CALLER } from '../modules/postprocessing_gene_caller.nf'
include { PSAURON } from '../modules/psauron.nf'


workflow EUK_GENE_CALLING {
    take:
        tuple_genome_proteins // tuple(cluster_name, genome_fna, protein_evidence)
        taxonomy_map          // eukaryotic_taxonomy_reformatted.tsv (REFORMAT_BAT.out.taxonomy)
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

        repeatmasker_input = genomes_after_repeatmodeler.with_repeats
            .multiMap { genome_name, genome, proteins, library ->
                genome_name: genome_name
                genome: genome
                proteins: proteins
                library: library
            }
        REPEAT_MASKER(
            repeatmasker_input.genome_name,
            repeatmasker_input.genome,
            repeatmasker_input.proteins,
            repeatmasker_input.library
        )

        // Combine masked genomes with unmasked genomes
        def all_genomes_for_gene_calling = REPEAT_MASKER.out.masked_genome
            .mix(genomes_after_repeatmodeler.without_repeats)

        braker_input = tuple_genome_proteins_nocluster
            .map { genome_name, _genome, prot_evidence -> tuple(genome_name, prot_evidence) }
            .join(all_genomes_for_gene_calling)
            .multiMap { genome_name, prot_evidence, genome ->
                genome_name: genome_name
                genome: genome
                proteins: prot_evidence
            }

        BRAKER(braker_input.genome_name, braker_input.genome, braker_input.proteins)
        DEDUP_GFF(BRAKER.out.gff3)

        dedup_gff_with_genome = DEDUP_GFF.out.dedup_gff.join(all_genomes_for_gene_calling)
        EXTRACT_DEDUP_BRAKER_FAA(
            dedup_gff_with_genome.map { genome_name, gff, genome -> tuple(genome_name, gff, genome, "protein") }
        )
        EXTRACT_DEDUP_BRAKER_FFN(
            dedup_gff_with_genome.map { genome_name, gff, genome -> tuple(genome_name, gff, genome, "nucleotide") }
        )

        braker_out = DEDUP_GFF.out.dedup_gff
            .join(EXTRACT_DEDUP_BRAKER_FAA.out.protein)
            .join(EXTRACT_DEDUP_BRAKER_FFN.out.nucleotide)

        // Prepare channel for MetaEuk, which requires protein evidence
        genomes_with_proteins = tuple_genome_proteins_nocluster
            .map { genome_name, _genome, prot_evidence -> tuple(genome_name, prot_evidence) }
            .filter { _genome_name, prot_evidence -> prot_evidence.name != "NO_PROTEINS.faa" }

        ch_metaeuk_input = genomes_with_proteins
            .join(all_genomes_for_gene_calling, remainder: true)
            .filter { _genome_name, prot_evidence, genome -> prot_evidence != null && genome != null }
            .map { genome_name, prot_evidence, genome -> tuple(genome_name, genome, prot_evidence) }

        metaeuk_input = ch_metaeuk_input
            .multiMap { genome_name, genome, prot_evidence ->
                genome_name: genome_name
                genome: genome
                proteins: prot_evidence
            }
        METAEUK(metaeuk_input.genome_name, metaeuk_input.genome, metaeuk_input.proteins)

        metaeuk_genomes = ch_metaeuk_input.map { genome_name, genome, _prot -> tuple(genome_name, genome) }
        FIX_METAEUK_CDS_PHASES(METAEUK.out.gff.join(metaeuk_genomes))
        RECONCILE_METAEUK_PHASES(METAEUK.out.gff.join(FIX_METAEUK_CDS_PHASES.out.gff))

        metaeuk_out = RECONCILE_METAEUK_PHASES.out.gff
            .join(METAEUK.out.proteins)
            .join(METAEUK.out.nucleotide)

        merge_input = braker_out
            .join(metaeuk_out, remainder: true)
            .filter { joined_prediction ->
                def braker_gff = joined_prediction[1]
                def metaeuk_gff = joined_prediction[4]
                braker_gff != null && metaeuk_gff != null
            }
            .multiMap { genome_name, braker_gff, braker_faa, braker_ffn, metaeuk_gff, metaeuk_faa, metaeuk_ffn ->
                genome_name: genome_name
                braker: tuple(braker_gff, braker_faa, braker_ffn)
                metaeuk: tuple(metaeuk_gff, metaeuk_faa, metaeuk_ffn)
            }
        MERGE_GENE_PREDICTIONS(merge_input.genome_name, merge_input.braker, merge_input.metaeuk)

        merged_gene_sets = MERGE_GENE_PREDICTIONS.out.gff
            .join(MERGE_GENE_PREDICTIONS.out.faa)
            .join(MERGE_GENE_PREDICTIONS.out.ffn)

        // Genomes without protein evidence skip MetaEuk and use the BRAKER output directly.
        braker_only_gene_sets = braker_out
            .join(genomes_with_proteins, remainder: true)
            .filter { _genome_name, _gff, _faa, _ffn, prot_evidence -> prot_evidence == null }
            .map { genome_name, gff, faa, ffn, _prot_evidence -> tuple(genome_name, gff, faa, ffn) }

        // Finalise the gene set (merged or BRAKER-only) for every genome
        postprocessing_input = merged_gene_sets
            .mix(braker_only_gene_sets)
            .join(cluster_name_ch)
            .join(all_genomes_for_gene_calling)
            .multiMap { genome_name, gff, faa, ffn, cluster, genome ->
                genome_name: genome_name
                cluster_name: cluster
                gff: gff
                faa: faa
                ffn: ffn
                genome: genome
            }

        POSTPROCESSING_GENE_CALLER(
            postprocessing_input.genome_name,
            postprocessing_input.cluster_name,
            postprocessing_input.gff,
            postprocessing_input.faa,
            postprocessing_input.ffn,
            postprocessing_input.genome
        )

        psauron_target_genomes = taxonomy_map
            .first()
            .splitCsv(sep: "\t", header: true)
            .map { row ->
                def phylum = ""
                (row.classification ?: "").split(";").each { rank ->
                    if (rank.trim().startsWith("p__")) {
                        phylum = rank.trim()
                    }
                }
                tuple(row.user_genome, phylum)
            }
            .filter { _genome_name, phylum -> params.psauron_target_phyla.contains(phylum) }
            .map { genome_name, _phylum -> genome_name }
            .collect()
            .map { target_list -> [target_list] }

        // BAT/taxonomy only covers representatives, so redundant members inherit the rep's taxonomy.
        psauron_input = POSTPROCESSING_GENE_CALLER.out.faa
            .join(POSTPROCESSING_GENE_CALLER.out.gff)
            .join(cluster_name_ch)
            .combine(psauron_target_genomes)
            .filter { _genome_name, _faa, _gff, cluster, target_list -> target_list.contains(cluster) }
            .multiMap { genome_name, faa, gff, _cluster, _target_list ->
                genome_name: genome_name
                faa: faa
                gff: gff
            }

        PSAURON(psauron_input.genome_name, psauron_input.faa, psauron_input.gff)
        psauron_gff = PSAURON.out.psauron.map { genome_name, _csv, gff -> tuple(genome_name, gff) }

        // Final GFF is the PSAURON-scored GFF where available, otherwise the postprocessed BRAKER/Merge GFF
        final_gff = POSTPROCESSING_GENE_CALLER.out.gff
            .join(psauron_gff, remainder: true)
            .map { genome_name, postprocessed_gff, psauron_scored_gff ->
                tuple(genome_name, psauron_scored_gff ?: postprocessed_gff)
            }

        output_ch = cluster_name_ch
            .join( final_gff )
            .join( POSTPROCESSING_GENE_CALLER.out.faa )
            .join( POSTPROCESSING_GENE_CALLER.out.ffn )
            .join( all_genomes_for_gene_calling )
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
