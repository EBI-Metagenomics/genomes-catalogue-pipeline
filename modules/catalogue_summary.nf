process CATALOGUE_SUMMARY {

    publishDir "${params.outdir}/", mode: 'copy', failOnError: true

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    label 'process_light'

    input:
    path metadata_tsv
    path mmseqs_tsv

    output:
    path "catalogue_summary.json", emit: catalogue_summary

    script:
    """
    wc -l ${mmseqs_tsv} | cut -d ' ' -f1 > protein_count.txt
    
    generate_catalogue_summary_json.py \
    -p protein_count.txt \
    -m ${metadata_tsv} \
    -o catalogue_summary.json
    """

    stub:
    """
    touch catalogue_summary.json
    """
}
