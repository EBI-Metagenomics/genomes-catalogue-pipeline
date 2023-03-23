process SPLIT_DREP {

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                if ( output_file.getBaseName() == "clusters_split.txt" ) {
                    return "additional_data/intermediate_files/clusters_split.txt";
                };
                return null;
            }
        },
        mode: "copy"
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.0'

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    file cdb_csv
    file mdb_csv
    file sdb_csv

    output:
    path "split_output/mash_folder/*.tsv", emit: mash_splits
    path "split_output/clusters_split.txt", emit: text_split

    script:
    """
    split_drep.py --cdb ${cdb_csv} --mdb ${mdb_csv} --sdb ${sdb_csv} -o split_output
    """

    // stub:
    // """
    // mkdir -p split_output/mash_folder
    // touch split_output/mash_folder/MGYG000000001_mash.tsv
    // touch split_output/mash_folder/MGYG000000002_mash.tsv
    // touch split_output/clusters_split.txt
    // """
}
