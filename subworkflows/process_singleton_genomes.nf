/*
 * Run GUNC and Prokka on the singletons
*/

include { GUNC } from '../modules/gunc'
include { PROKKA } from '../modules/prokka'

process COLLECT_FAILED_GUNC {

    publishDir(
        "${params.outdir}",
        pattern: "gunc_failed.txt",
        saveAs: { "additional_data/intermediate_files/gunc/gunc_failed.txt" },
        mode: "copy",
        failOnError: true
    )

    input:
    path failed_gunc_files, stageAs: "failed_gunc/*"

    output:
    path("gunc_failed.txt"), emit: gunc_failed_txt

    script:
    """
    rm -f gunc_failed.txt || true
    touch gunc_failed.txt
    for GUNC_FAILED in failed_gunc/*; do
        if [ \$GUNC_FAILED != "failed_gunc/NO_FILE" ]
        then
            name=\$(basename \$GUNC_FAILED)
            genome_name="\${name%"_gunc_empty.txt"}"
            echo \$genome_name >> gunc_failed.txt
        fi
    done
    """
}

workflow PROCESS_SINGLETON_GENOMES {
    take:
        singleton_cluster_tuple
        genomes_checkm
        accessions_with_domains_tuples
        gunc_db
    main:
    
        singleton_cluster_tuple_with_domain = singleton_cluster_tuple \
        .join(accessions_with_domains_tuples) \
        .filter({ !it[2].contains('Undefined') })
        
        GUNC(
            singleton_cluster_tuple_with_domain,
            genomes_checkm,
            gunc_db
        )

        PROKKA(
            GUNC.out.cluster_gunc_result.filter({
                it[2].name.contains('_complete.txt')
            }).join(accessions_with_domains_tuples
            ).map({ cluster_name, cluster_fasta, cluster_gunc, cluster_domain ->
                return tuple(cluster_name, cluster_fasta, cluster_domain)
            })
        )

        COLLECT_FAILED_GUNC(
            GUNC.out.cluster_gunc_result.filter({
                it[2].name.contains('_gunc_empty.txt')
            }).map({ cluster_name, cluster_fasta, cluster_gunc ->
                return cluster_gunc
            }).collect().ifEmpty(file("NO_FILE"))
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
