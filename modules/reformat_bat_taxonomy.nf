process REFORMAT_BAT {

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/biopython:1.75':
        'quay.io/biocontainers/biopython:1.75' }"

    input:
    path bat_names

    output:
    path "eukaryotic_taxonomy_reformatted.tsv", emit: taxonomy
    path "all_bin2classification.txt" , emit: bat_stats

    script:
    """
    reformat_bat_taxonomy.py --bat_names ${bat_names} --output "eukaryotic_taxonomy_reformatted.tsv"

    """
}