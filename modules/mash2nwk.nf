process MASH_TO_NWK {

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                String rep_name = filename.replace("_mash", "").tokenize(".")[0];
                String cluster_prefix = rep_name.substring(0, rep_name.length() - 2);
                return "species_catalogue/${cluster_prefix}/${rep_name}/pan-genome/mashtree.nwk";
            }
        },
        mode: 'copy',
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.mash2nwk:v1'

    label 'process_light'

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
