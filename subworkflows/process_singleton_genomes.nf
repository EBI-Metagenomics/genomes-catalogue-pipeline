/*
 * Run GUNC and Prokka on the singletons
*/

include { GUNC } from '../modules/gunc'
include { PROKKA } from '../modules/prokka'

workflow PROCESS_SINGLETON_GENOMES {
    take:
        singleton_cluster_tuple
        renamed_genomes_csv
        gunc_db
    main:

        GUNC(
            singleton_cluster_tuple,
            renamed_genomes_csv,
            gunc_db
        )

        PROKKA(
            GUNC.out.cluster_gunc_result.filter { 
                it[3].contains('_complete.txt')
            }
        )
    emit:
        gunc_report = GUNC.out.gunc_result
        prokka_gff = PROKKA.out.gff
        prokka_faa = PROKKA.out.faa
        prokka_fna = PROKKA.out.fna
        prokka_gbk = PROKKA.out.gbk
        prokka_ffn = PROKKA.out.ffn
}
