process ANTISMASH {

    tag "${cluster_name}"
    
    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                String cluster_prefix = cluster_name.substring(0, cluster_name.length() - 2);
                return "species_catalogue/${cluster_prefix}/${cluster_name}/genome/${cluster_name}_antismash.gff"
            }
        },
        mode: 'copy',
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/antismash:7.1.0.1_2'

    input:
    tuple val(cluster_name), path(gbk)
    path(antismash_db)

    output:
    tuple val(cluster_name), path("${cluster_name}_antismash.gff"), emit: antismash_gff

    script:
    """
    antismash \\
    -t bacteria \\
    -c ${task.cpus} \\
    --databases ${antismash_db} \\
    --output-basename ${cluster_name} \\
    --genefinding-tool none \\
    --output-dir ${cluster_name}_results \\
    ${gbk}

    tar -czf ${cluster_name}_antismash.tar.gz ${cluster_name}_results

    # To build the GFF3 file the scripts needs the regions.js file to be converted to json
    # In order to do that this process uses nodejs (using a patched version of the antismash container)

    echo ";var fs = require('fs'); fs.writeFileSync('./regions.json', JSON.stringify(recordData));" >> ${cluster_name}_results/regions.js

    node ${cluster_name}_results/regions.js

    antismash_to_gff.py \\
        -r regions.json -a \$(echo \$(antismash --version | sed 's/^antiSMASH //' )) \\
        -o ${cluster_name}_antismash.gff

    """
}
