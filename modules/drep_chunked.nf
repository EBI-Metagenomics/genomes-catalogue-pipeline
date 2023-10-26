/*
 * dRep, this process dereplicates a set of genomes.
 * this version of the process is meant to be use for a subset
 * of the genomes (as part of the drep_swf for large catalogues)
*/
process DREP_CHUNKED {

    container 'quay.io/biocontainers/drep:3.2.2--pyhdfd78af_0'

    input:
    path genomes, stageAs: "genomes/*"
    path checkm_csv
    path extra_weights_table
    val merged

    output:
    path "drep_output/data_tables/Cdb.csv", emit: cdb_csv
    path "drep_output/data_tables/Mdb.csv", emit: mdb_csv
    path "drep_output/data_tables/Sdb.csv", emit: sdb_csv
    path "drep_output/dereplicated_genomes/*.fa", emit: dereplicated_genomes
    path "drep_data_tables_*.tar.gz", emit: drep_data_tables_tarball

    script:
    tarball_suffix = merged ? "merged" : task.index 
    """
    dRep dereplicate -g genomes/* \
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

    tar -czf drep_data_tables_${tarball_suffix}.tar.gz drep_output/data_tables
    """

    stub:
    """
    mkdir -p drep_output/data_tables
    mkdir -p drep_output/dereplicated_genomes/
    touch drep_output/data_tables/Cdb.csv
    touch drep_output/data_tables/Sdb.csv
    touch drep_output/dereplicated_genomes/CAMNGJ02.fa
    touch drep_output/dereplicated_genomes/CAMNGJ04.fa
    """
}
