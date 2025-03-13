/*
 * Functional annotation of the cluster rep genomes - prokaryotic genomes only
*/

include { SANNTIS } from '../modules/sanntis'
include { DEFENSE_FINDER } from '../modules/defense_finder'
include { GECCO_RUN } from '../modules/gecco'
include { CRISPRCAS_FINDER } from '../modules/crisprcasfinder'
include { AMRFINDER_PLUS } from '../modules/amrfinder_plus'


workflow ANNOTATE_PROKARYOTES {
    take:
        prokka_gbk
        prokka_faa
        prokka_gff
        prokka_fnas
        ips_annotation_tsvs
        defense_finder_db

    main:
     
        DEFENSE_FINDER(
            prokka_faa.join(prokka_gff),
            defense_finder_db
        )   
        
        GECCO_RUN(
            prokka_gbk    
        )     

        SANNTIS(
            ips_annotation_tsvs.join(prokka_gbk)
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

    emit:
        sanntis_annotation_gffs = SANNTIS.out.sanntis_gff
        defense_finder_gffs = DEFENSE_FINDER.out.gff
        gecco_gffs = GECCO_RUN.out.gecco_gff
        crisprcasfinder_hq_gff = CRISPRCAS_FINDER.out.hq_gff
        amrfinder_tsv = AMRFINDER_PLUS.out.amrfinder_tsv
}
