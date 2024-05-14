process RENAME_FASTA {

    publishDir(
        path: "${params.outdir}",
        pattern: "*.txt",
        saveAs: { "additional_data/intermediate_files/renamed_genomes_stats.txt" },
        mode: "copy",
        failOnError: true
    )
    publishDir(
        path: "${params.outdir}",
        pattern: "*.tsv",
        saveAs: { "additional_data/intermediate_files/renamed_genomes_name_mapping.tsv" },
        mode: "copy",
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    label 'process_light'

    input:
    path genomes
    val start_number
    val max_number
    path preassigned_accessions
    path check_csv
    // optional
    val prefix

    output:
    path "renamed_genomes", emit: renamed_genomes
    path "name_mapping.tsv", emit: rename_mapping
    path "renamed_*.???", emit: renamed_checkm

    script:
    genomes_prefix = prefix ? prefix : "MGYG"
    
    def args = ""
    if (preassigned_accessions.name != "NO_FILE_PREASSIGNED_ACCS") {
        args += "--map-file ${preassigned_accessions} "
    }
    """
    rename_fasta.py -d ${genomes} \
    -p ${genomes_prefix} \
    -i ${start_number} \
    --max ${max_number} \
    -t name_mapping.tsv \
    -o renamed_genomes \
    --csv ${check_csv} \
    ${args}
    """

    stub:
    """
    mkdir renamed_genomes
    touch name_mapping.tsv
    touch renamed_${check_csv.baseName}_checkm.txt
    """
}
