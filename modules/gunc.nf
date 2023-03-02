
process GUNC {

    publishDir(
        path: "${params.outdir}/gunc/intermediate_files/",
        mode: 'copy'
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.gunc:latest'

    cpus 4

    input:
    tuple val(cluster_name), path(fasta)
    file renamed_genomes_csv
    file gunc_db

    output:
    // TODO: review this, repeated emited value
    tuple val(cluster_name), path(fasta), path('*_gunc_*'), emit: cluster_gunc_result
    path('*_gunc_*'), emit: gunc_result

    script:
    """
    gunc run -t ${task.cpus} \
    -i ${fasta} \
    -r ${gunc_db}

    ### gunc contaminated genomes ###
    awk '{if(\$8 > 0.45 && \$9 > 0.05 && \$12 > 0.5) print\$1}' GUNC.*.maxCSS_level.tsv | grep -v "pass.GUNC" >gunc_contaminated.txt

    # gunc_contaminated.txt could be empty - that means genome is OK
    # gunc_contaminated.txt could have this genome inside - that means gunc filtered this genome

    ### check completeness ###

    # remove header
    tail -n +2 "${renamed_genomes_csv}" > genomes.csv

    ### get notcompleted genomes ###
    cat genomes.csv | tr ',' '\t' | awk '{if(\$2 < 90)print\$1}' > notcompleted.txt

    grep -f gunc_contaminated.txt notcompleted.txt > bad.txt || true
    # if bad.txt is not empty - that means genome didnt pass completeness and gunc filters

    ### final decision ###

    if [ -s bad.txt ]; then
        touch ${fasta.baseName}_gunc_empty.txt
    else
        touch ${fasta.baseName}_gunc_complete.txt
    fi
    """

    // stub:
    // """
    // touch ${fasta.baseName}_gunc_complete.txt
    // """
}
