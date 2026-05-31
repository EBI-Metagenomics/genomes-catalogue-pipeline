process CGT {
    tag "${cluster_name}"
    label 'process_medium'

    publishDir(
        path: "${params.outdir}",
        saveAs: { filename ->
            def output_file = file(filename);
            def extension = output_file.getExtension();
            String cluster_prefix = cluster_name.substring(0, cluster_name.length() - 2);
            if ( output_file.name == "${cluster_name}_cgt.txt" ) {
                return "species_catalogue/${cluster_prefix}/${cluster_name}/pan-genome/gene_prevalence_corrected.txt";
            }
        },
        mode: 'copy',
        failOnError: true
    )

    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/cgt:1.0.0--h4349ce8_0'
        : 'quay.io/biocontainers/cgt:1.0.0--h4349ce8_0'}"

    input:
    tuple val(cluster_name), path(checkm2), path(rtab)

    output:
    tuple val(cluster_name), path("*_cgt.txt"), emit: cgt

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${cluster_name}"
    """
    # Reformat checkm2 and filter to genomes present in the Rtab in one step
    head -1 ${rtab} | tr '\t' '\n' | tail -n +2 > rtab_genomes.txt
    sed 's|[.][a-zA-Z]*,|,|' ${checkm2} | tr ',' '\t' | awk 'FNR==NR {g[\$1]=1; next} FNR==1 || \$1 in g' rtab_genomes.txt - > checkm2_filtered.tsv

    # Check the number of genomes in the cluster
    n_genomes=\$(wc -l < rtab_genomes.txt)
    
    if [ "\$n_genomes" -gt 4 ]; then
        cgt_bacpop \\
            ${args} \\
            --completeness-column 2 \\
            --output-file ${prefix}_cgt.txt \\
            checkm2_filtered.tsv \\
            ${rtab} > cgt.log 2>&1
    
        # Prepend core and rare threshold lines as comments to the output file
        { grep -E "^(Core|Rare) threshold:" cgt.log | sed 's/^/# /'; cat ${prefix}_cgt.txt; } > ${prefix}_cgt.tmp
        mv ${prefix}_cgt.tmp ${prefix}_cgt.txt
    fi
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${cluster_name}"
    """
    echo ${args}

    touch ${prefix}_cgt.txt
    """
}

