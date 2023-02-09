process MASH_TO_NWK {

    publishDir "results/mashtrees/", mode: 'copy'

    container 'quay.io/microbiome-informatics/genomes-pipeline.mash2nwk:v1'

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    file mash

    output:
    path 'trees/*.nwk', emit: mash_nwk

    script:
    """
    mash2nwk1.R -m ${mash}

    mv trees/mashtree.nwk trees/${mash.baseName}.nwk
    """

    // stub:
    // """
    // mkdir trees
    // touch trees/{mash.baseName}.nwk
    // """
}
