process RENAME_FASTA {
    // for some reason this directive does not work when defined in the config file
    publishDir(
        path: "${params.outdir}/additional_data/busco",
        pattern: "renamed_*.summary",
        mode: 'copy'
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
    path busco_summary

    output:
    path "renamed_genomes", emit: renamed_genomes
    path "name_mapping.tsv", emit: rename_mapping
    path "renamed_*.???", emit: renamed_checkm
    path "renamed_*.summary", emit: busco_renamed, optional: true

    script:
    genomes_prefix = prefix ? prefix : "MGYG"

    def args = ""
    if (preassigned_accessions.name != "NO_FILE_PREASSIGNED_ACCS") {
        args += "--map-file ${preassigned_accessions} "
    }
    if (busco_summary.name != "NO_BUSCO_FILE") {
        args += "--busco ${busco_summary} "
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
