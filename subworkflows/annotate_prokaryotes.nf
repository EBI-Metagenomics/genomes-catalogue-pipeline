/*
 * Functional annotation of the cluster rep genomes - prokaryotic genomes only
*/

include { PER_GENOME_ANNOTATION_GENERATOR } from '../modules/per_genome_annotations'
include { SANNTIS } from '../modules/sanntis'
include { DEFENSE_FINDER } from '../modules/defense_finder'
include { GECCO_RUN } from '../modules/gecco'
include { CRISPRCAS_FINDER } from '../modules/crisprcasfinder'
include { AMRFINDER_PLUS } from '../modules/amrfinder_plus'
include { ANTISMASH } from '../modules/antismash'
include { ANTISMASH_MAKE_GFF } from '../modules/antismash_make_gff'


workflow ANNOTATE_PROKARYOTES {
    take:
        prokka_gbk
        prokka_faa
        prokka_gff
        prokka_fnas
        interproscan_annotations_mmseqs90
        eggnog_annotations_mmseqs90
        species_reps_names_list
        mmseq_90_tsv
        defense_finder_db
        antismash_db

    main:
     
        PER_GENOME_ANNOTATION_GENERATOR(
            interproscan_annotations_mmseqs90,
            eggnog_annotations_mmseqs90,
            species_reps_names_list,
            mmseq_90_tsv
        )
        
        // Group by cluster //
        per_genome_ips_annotations = PER_GENOME_ANNOTATION_GENERATOR.out.ips_annotation_tsvs | flatten | map { file ->
            def key = file.name.toString().tokenize('_').get(0)
            return tuple(key, file)
        }

        per_genome_eggnog_annotations = PER_GENOME_ANNOTATION_GENERATOR.out.eggnog_annotation_tsvs | flatten | map { file ->
            def key = file.name.toString().tokenize('_').get(0)
            return tuple(key, file)
        }
        
        DEFENSE_FINDER(
            prokka_faa.join(prokka_gff),
            defense_finder_db
        )   
        
        GECCO_RUN(
            prokka_gbk    
        )     

        SANNTIS(
            per_genome_ips_annotations.join(prokka_gbk)
        )
        
        CRISPRCAS_FINDER(
            prokka_fnas
        )

        AMRFINDER_PLUS(
            prokka_fnas.join(
                prokka_faa
            ).join(
                prokka_gff
            )
        )
        
        ANTISMASH(
             prokka_gbk,
             antismash_db
        )
        
        ANTISMASH_MAKE_GFF(
             ANTISMASH.out.antismash_json
        )  

    emit:
        ips_annotation_tsvs = per_genome_ips_annotations
        eggnog_annotation_tsvs = per_genome_eggnog_annotations
        sanntis_annotation_gffs = SANNTIS.out.sanntis_gff
        defense_finder_gffs = DEFENSE_FINDER.out.gff
        gecco_gffs = GECCO_RUN.out.gecco_gff
        crisprcasfinder_hq_gff = CRISPRCAS_FINDER.out.hq_gff
        amrfinder_tsv = AMRFINDER_PLUS.out.amrfinder_tsv
        antismash_gffs = ANTISMASH_MAKE_GFF.out.antismash_gff
}
