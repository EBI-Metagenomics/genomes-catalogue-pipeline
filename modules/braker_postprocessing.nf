process BRAKER_POSTPROCESSING {

    tag "${cluster_name}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                String genome_name = genome_name;
                String cluster_prefix = cluster_name.substring(0, cluster_name.length() - 2);
                def is_rep = genome_name == cluster_name;

                if ( is_rep && ( output_file.extension == "faa" || output_file.extension == "fna" ) ) {
                    return "species_catalogue/${cluster_prefix}/${genome_name}/genome/${genome_name}.${output_file.extension}";
                // Used for sanity check purposes
                } else if ( output_file.extension == "ffn" ) {
                    return "additional_data/intermediate_files/ffn_files/${output_file.baseName}.${output_file.extension}";
                // Store the species reps gbk files //
                } else if ( output_file.extension == "gff" && !is_rep ) {
                    return "all_genomes/${cluster_prefix}/${cluster_name}/${genome_name}.${output_file.extension}";
                }
            }
        },
        mode: "copy",
        failOnError: true
    )
    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                if (output_file.extension == "fna") {
                    return "additional_data/mgyg_genomes/${fasta.baseName}.${output_file.extension}";
                }
                return null;
            }
        },
        mode: "copy",
        failOnError: true
    )

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/61/6151add1e8ca2e3eaaa65584e3ff9c551eecbfad282dc61f26b5bcbf626b4c06/data' :
    'community.wave.seqera.io/library/pip_biopython:326a6be8fb21b301' }"
    
    
    label 'process_light'
    
    input:
    tuple val(genome_name), path(masked_genome)
    tuple val(genome_name), path(gff3)
    tuple val(genome_name), path(proteins)
    tuple val(genome_name), path(ffn)
    
    output:
    tuple val(genome_name), path("*.gff"), emit: renamed_gff3  
    tuple val(genome_name), path("*.faa"), emit: renamed_proteins 
    tuple val(genome_name), path("*.ffn"), emit: renamed_ffn 
    
    script:
    """
    rename_and_process_braker_outputs.py \
    --gff ${gff3} \
    --ffn ${ffn} \
    --faa ${proteins} \
    --genome-fasta ${masked_genome} \
    -p renamed

    mv renamed*.gff3 ${genome_name}.gff
    mv renamed*.aa ${genome_name}.faa
    mv renamed*.codingseq ${genome_name}.ffn
    """    
}