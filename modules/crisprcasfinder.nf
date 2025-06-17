process CRISPRCAS_FINDER {

    tag "${cluster}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                if ( filename.contains("hq.gff") ) {
                    return null;
                }
                def output_file = file(filename);
                def cluster_rep_prefix = cluster.substring(0, cluster.length() - 2);
                return "species_catalogue/${cluster_rep_prefix}/${cluster}/genome/${output_file.name}";
            }
        },
        mode: 'copy',
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.crisprcasfinder:4.3.2'

    input:
    tuple val(cluster), path(fasta)

    output:
    tuple val(cluster), path("crisprcasfinder_results/${fasta.baseName}_crisprcasfinder.gff"), emit: gff
    tuple val(cluster), path("crisprcasfinder_results/${fasta.baseName}_crisprcasfinder.tsv"), emit: tsv
    tuple val(cluster), path("crisprcasfinder_results/${fasta.baseName}_crisprcasfinder_hq.gff"), emit: hq_gff

    script:
    """
    # Remove results folder if it already exists to prevent restarts from failing
    if [ -d "crisprcasfinder_results" ]; then
        rm -rf "crisprcasfinder_results"
    fi
    
    CRISPRCasFinder.pl -i $fasta \
    -so /opt/CRISPRCasFinder/sel392v2.so \
    -def G \
    -drpt /opt/CRISPRCasFinder/supplementary_files/repeatDirection.tsv \
    -outdir crisprcasfinder_results

    echo "Running post-processing"

    process_crispr_results.py \
    --tsv-report crisprcasfinder_results/TSV/Crisprs_REPORT.tsv \
    --gffs crisprcasfinder_results/GFF/*gff \
    --tsv-output crisprcasfinder_results/${fasta.baseName}_crisprcasfinder.tsv \
    --gff-output crisprcasfinder_results/${fasta.baseName}_crisprcasfinder.gff \
    --gff-output-hq crisprcasfinder_results/${fasta.baseName}_crisprcasfinder_hq.gff \
    --fasta $fasta
    """
}
