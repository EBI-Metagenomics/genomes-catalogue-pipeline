process EXTRACT_SEQUENCES {

    tag "${genome_name}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/agat:1.7.0--pl5321hdfd78af_0' :
        'quay.io/biocontainers/agat:1.7.0--pl5321hdfd78af_0' }"

    label 'process_light'

    input:
    tuple val(genome_name), path(gff), path(genome_fasta), val(mol_type)

    output:
    tuple val(genome_name), path("*.faa"), emit: protein, optional: true
    tuple val(genome_name), path("*.ffn"), emit: nucleotide, optional: true

    script:
    def protein_flag = mol_type == "protein" ? "-p" : ""
    def extension = mol_type == "protein" ? "faa" : "ffn"
    """
    # AGAT's progress bar croaks ("progress bar already finished") on larger inputs,
    # killing the task after a successful parse. Disable it via the local config.
    agat config --expose --no-progress_bar > /dev/null

    agat_sp_extract_sequences.pl \\
        -g ${gff} \\
        -f ${genome_fasta} \\
        -t CDS \\
        ${protein_flag} \\
        -o ${genome_name}.${extension}
    """

    stub:
    def extension = mol_type == "protein" ? "faa" : "ffn"
    """
    touch ${genome_name}.${extension}
    """
}
