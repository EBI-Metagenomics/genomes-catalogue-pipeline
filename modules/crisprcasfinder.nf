process CRISPRCAS_FINDER {

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                if ( filename.contains("hq.gff") ) {
                    return null;
                }
                def output_file = file(filename);
                def cluster_rep_prefix = cluster.substring(0, 11);
                return "species_catalogue/${cluster_rep_prefix}/${cluster}/genome/${output_file.simpleName}";
            }
        },
        mode: 'copy'
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.crisprcasfinder:4.3.2'

    cpus 1
    memory '10G'

    input:
    tuple val(cluster), path(fasta)

    output:
    tuple val(cluster), path("crisprcasfinder_results/${fasta.baseName}.crisprcasfinder.gff"), emit: gff
    tuple val(cluster), path("crisprcasfinder_results/${fasta.baseName}.crisprcasfinder.tsv"), emit: tsv
    tuple val(cluster), path("crisprcasfinder_results/${fasta.baseName}.crisprcasfinder.hq.gff"), emit: hq_gff

    script:
    """
    CRISPRCasFinder.pl -i $fasta \
    -so /opt/CRISPRCasFinder/sel392v2.so \
    -def G \
    -drpt /opt/CRISPRCasFinder/supplementary_files/repeatDirection.tsv \
    -outdir crisprcasfinder_results

    echo "Running post-processing"

    process_crispr_results.py \
    --tsv-report crisprcasfinder_results/TSV/Crisprs_REPORT.tsv \
    --gffs crisprcasfinder_results/GFF/*gff \
    --tsv-output crisprcasfinder_results/${fasta.baseName}.crisprcasfinder.tsv \
    --gff-output crisprcasfinder_results/${fasta.baseName}.crisprcasfinder.gff \
    --gff-output-hq crisprcasfinder_results/${fasta.baseName}.crisprcasfinder.hq.gff \
    --fasta $fasta
    """
}
