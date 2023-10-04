/*
 * dRep, this workflow dereplicates a set of genomes.
*/
process DREP_CHUNKED {

    container 'quay.io/biocontainers/drep:3.2.2--pyhdfd78af_0'

    input:
    path genomes_directory
    path checkm_csv
    path extra_weights_table

    output:
    path "drep_output/data_tables/Cdb.csv", emit: cdb_csv
    path "drep_output/data_tables/Sdb.csv", emit: sdb_csv
    path "drep_output/dereplicated_genomes/", emit: dereplicated_genomes

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
    mkdir -p drep_output/dereplicated_genomes/
    touch drep_output/data_tables/Cdb.csv
    touch drep_output/data_tables/Sdb.csv
    touch drep_output/dereplicated_genomes/CAMNGJ02.fa
    """
}
