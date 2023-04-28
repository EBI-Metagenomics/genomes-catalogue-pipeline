/*
 * dRep, this workflow dereplicates a set of genomes.
*/
process DREP {

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def result_file = file(filename);
                if ( result_file.name == "drep_data_tables.tar.gz" ) {
                    return "additional_data/intermediate_files/drep_data_tables.tar.gz";
                }
                return null;
            }
        },
        mode: 'copy',
    )

    container 'quay.io/biocontainers/drep:3.2.2--pyhdfd78af_0'

    input:
    path genomes_directory
    path checkm_csv
    path extra_weights_table

    output:
    path "drep_output/data_tables/Cdb.csv", emit: cdb_csv
    path "drep_output/data_tables/Mdb.csv", emit: mdb_csv
    path "drep_output/data_tables/Sdb.csv", emit: sdb_csv
    path "drep_data_tables.tar.gz", emit: drep_data_tables_tarball

    script:
    """
    dRep dereplicate -g ${genomes_directory}/*.fa \
    -p ${task.cpus} \
    -pa 0.9 \
    -sa 0.95 \
    -nc 0.30 \
    -cm larger \
    -comp 50 \
    -con 5 \
    -extraW ${extra_weights_table} \
    --genomeInfo ${checkm_csv} \
    drep_output

    tar -czf drep_data_tables.tar.gz drep_output/data_tables
    """

    stub:
    """
    mkdir -p drep_output/data_tables
    touch drep_output/data_tables/Cdb.csv
    touch drep_output/data_tables/Mdb.csv
    touch drep_output/data_tables/Sdb.csv
    """
}
