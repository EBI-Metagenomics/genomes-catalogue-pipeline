process CATALOGUE_SUMMARY {

    publishDir "${params.outdir}/", mode: 'copy', failOnError: true

    container 'quay.io/microbiome-informatics/genomes-pipeline.python3base:v1.1'

    input:
    path metadata_tsv
    path mmseqs_tsv

    output:
    path "catalogue_summary.json", emit: catalogue_summary

    script:
    """
    wc -l ${mmseqs_tsv} | cut -d ' ' -f1 > protein_count.txt
    awk '!seen[\$1]++ {count++} END {print count}' ${mmseqs_tsv} > cluster90_count.txt
    
    generate_catalogue_summary_json.py \
    -p protein_count.txt \
    -c cluster90_count.txt \
    -m ${metadata_tsv} \
    -o catalogue_summary.json
    """

    stub:
    """
    touch catalogue_summary.json
    """
}
