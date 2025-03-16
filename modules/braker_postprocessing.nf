process BRAKER_POSTPROCESSING {

    tag "${genome.baseName}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/61/6151add1e8ca2e3eaaa65584e3ff9c551eecbfad282dc61f26b5bcbf626b4c06/data' :
    'community.wave.seqera.io/library/pip_biopython:326a6be8fb21b301' }"
    
    
    label 'process_light'
    
    input:
    path genome
    tuple val(cluster_name), path(gff3)
    tuple val(cluster_name), path(proteins)
    tuple val(cluster_name), path(ffn)
    
    output:
    tuple val(cluster_name), path("renamed_*.gff3"), emit: renamed_gff3  
    tuple val(cluster_name), path("renamed_*.aa"), emit: renamed_proteins 
    tuple val(cluster_name), path("renamed_*.codingseq"), emit: renamed_ffn 
    
    script:
    """
    rename_and_process_braker_outputs.py \
    --gff ${gff3} \
    --ffn ${ffn} \
    --faa ${proteins} \
    --genome-fasta ${genome} \
    -p renamed \
    """    
}