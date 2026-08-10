process BAT {

    label 'process_high'
    tag "${bin}"

    container 'quay.io/biocontainers/cat:5.2.3--hdfd78af_1'

    input:
    path bin
    path predicted_proteins // optional, pass [] to let CAT predict the genes itself
    path predicted_gff // optional, only used to map the predicted proteins back to their contig
    path cat_db_folder
    path cat_taxonomy_db

    output:
    path '*.BAT_run.bin2classification.names.txt', emit: bat_names

    script:
    def renamed_proteins = "${bin.baseName}.contig_prefixed_proteins.faa"
    def proteins_flag = predicted_proteins ? "-p ${renamed_proteins}" : ""
    """
    if [ -e "${predicted_proteins}" ]; then
        echo "[MAG euk taxonomy] Adding contig IDs to the predicted protein headers"
        prefix_fasta_with_contig.py \
          -g ${predicted_gff} \
          -f ${predicted_proteins} \
          -o ${renamed_proteins}
    fi

    echo "[MAG euk taxonomy] Analysing bins"
    CAT bin -b ${bin} \
      -d ${cat_db_folder} \
      -t ${cat_taxonomy_db} \
      -o ${bin.baseName}.BAT_run \
      ${proteins_flag} \
      --force --no_stars

    echo "[MAG euk taxonomy] Adding taxonomy names"
    CAT add_names -i ${bin.baseName}.BAT_run.bin2classification.txt \
      -o ${bin.baseName}.BAT_run.bin2classification.names.txt \
      -t ${cat_taxonomy_db} \
      --only_official

    rm -f ${renamed_proteins}
    """

    stub:
    """
    touch ${bin.baseName}.BAT_run.bin2classification.names.txt
    """
}
