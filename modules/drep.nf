/*
 * dRep, this workflow dereplicates a set of genomes.
*/
process DREP {

    publishDir(
        path: "${params.outdir}/intermediate_files",
        mode: 'copy',
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.drep:v2'

    cpus 8
    memory '5 GB'

    input:
    path genomes_directory
    path checkm_csv
    path extra_weights_table

    output:
    path "drep_output/data_tables/Cdb.csv", emit: cdb_csv
    path "drep_output/data_tables/Mdb.csv", emit: mdb_csv
    path "drep_output/data_tables/Sdb.csv", emit: sdb_csv
    path "drep_output/", emit: drep_folder

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
    """

    stub:
    """
    mkdir -p drep_output/data_tables
    touch drep_output/data_tables/Cdb.csv
    touch drep_output/data_tables/Mdb.csv
    touch drep_output/data_tables/Sdb.csv
    """
}
