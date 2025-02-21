process ANTISMASH {

    tag "${cluster_name}"

    container 'quay.io/microbiome-informatics/antismash:7.1.0.1_2'

    input:
    tuple val(cluster_name), path(gbk)
    path(antismash_db)

    output:
    tuple val(cluster_name), path("${cluster_name}_regions.json"), emit: antismash_json
    path("antismash_version.txt"), emit: antismash_version

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
    
    # To build the GFF3 file the scripts needs the regions.js file to be converted to json
    # In order to do that this process uses nodejs (using a patched version of the antismash container)

    echo ";var fs = require('fs'); fs.writeFileSync('./${cluster_name}_regions.json', JSON.stringify(recordData));" >> ${cluster_name}_results/regions.js

    node ${cluster_name}_results/regions.js
    
    echo \$(antismash --version | sed 's/^antiSMASH //' ) > antismash_version.txt
    """
}
