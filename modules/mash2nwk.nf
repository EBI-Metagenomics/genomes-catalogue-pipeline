process MASH_TO_NWK {

    publishDir(
        "${params.outdir}",
        saveAs: {
            filename -> "${params.catalogue_name}_metadata/${filename.replace("_mash", "").tokenize(".")[0]}/pan-genome/mashtree.nwk"
        },
        mode: 'copy'
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.mash2nwk:v1'

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    path mash

    output:
    path "${mash.baseName}.nwk", emit: mash_nwk

    script:
    """
    mash2nwk1.R -m ${mash}

    mv trees/mashtree.nwk ${mash.baseName}.nwk
    """

    // stub:
    // """
    // mkdir trees
    // touch trees/{mash.baseName}.nwk
    // """
}
