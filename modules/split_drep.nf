process SPLIT_DREP {

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    label 'process_light'

    input:
    file cdb_csv
    file mdb_csv // optional, use file("NO_FILE") when empty
    file sdb_csv

    output:
    path "split_output/clusters_split.txt", emit: text_split
    path "split_output/mash_folder/*.tsv", optional: true, emit: mash_splits

    script:
    def mdb_arg = mdb_csv.name != "NO_FILE" ? "--mdb ${mdb_csv}" : ""
    """
    split_drep.py \
        --cdb ${cdb_csv} \
        --sdb ${sdb_csv} \
        -o split_output ${mdb_arg}
    """

    stub:
    """
    mkdir -p split_output/mash_folder
    touch split_output/mash_folder/MGYG000000001_mash.tsv
    touch split_output/mash_folder/MGYG000000002_mash.tsv
    touch split_output/clusters_split.txt
    """
}
