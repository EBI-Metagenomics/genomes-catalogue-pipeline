process BRAKER_POSTPROCESSING {

    tag "${fasta.baseName}"
    
    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'
    
    label 'process_light'
    
    input:
    path genome
    path gff3
    path proteins
    path ffn
    
    output:
    path("renamed_*.gff3"), emit: renamed_gff3  
    path("renamed_*.aa"), emit: renamed_proteins 
    path("renamed_*.codingseq"), emit: renamed_ffn 
    
    script:
    """
    rename_and_process_braker_outputs.py \
    --gff ${gff3} \
    --ffn ${ffn} \
    --faa ${proteins} \
    --genome-fasta ${genome} \
    -p renamed \
    --mgyg-accession ${fasta.baseName}
    """    
}