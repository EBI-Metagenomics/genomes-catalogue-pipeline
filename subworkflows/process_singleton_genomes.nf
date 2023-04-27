/*
 * Run GUNC and Prokka on the singletons
*/

include { GUNC } from '../modules/gunc'
include { PROKKA } from '../modules/prokka'

process COLLECT_FAILED_GUNC {

    input:
    path failed_gunc_files, stageAs: "failed_gunc/*"

    output:
    path("gunc_failed.txt"), gunc_failed_txt

    script:
    """
    rm -f gunc_failed.txt || true
    touch gunc_failed.txt
    for GUNC_FAILED in failed_gunc/*; do
        name=$(basename \$GUNC_FAILED)
        genome_name="\${name%"_gunc_empty.txt"}"
        echo \$genome_name >> gunc_failed.txt
    done
    """
}

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
            GUNC.out.cluster_gunc_result.filter({
                it[2].name.contains('_complete.txt')
            }).map({ cluster_name, cluster_fasta, cluster_gunc ->
                return tuple(cluster_name, cluster_fasta)
            })
        )

        COLLECT_FAILED_GUNC(
            GUNC.out.cluster_gunc_result.filter({
                it[2].name.contains('_gunc_empty.txt')
            }).collect()
        )

    emit:
        gunc_report = GUNC.out.gunc_result
        gunc_failed_txt = COLLECT_FAILED_GUNC.out.gunc_failed_txt
        prokka_gff = PROKKA.out.gff
        prokka_faa = PROKKA.out.faa
        prokka_fna = PROKKA.out.fna
        prokka_gbk = PROKKA.out.gbk
        prokka_ffn = PROKKA.out.ffn
}
