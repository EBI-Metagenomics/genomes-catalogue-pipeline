process GTDBTK {

    container 'quay.io/microbiome-informatics/gtdb-tk:2.1.0'
    containerOptions "--bind ${gtdbtk_refdata}:/opt/gtdbtk_refdata"

    publishDir(
        path: "${params.outdir}/",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                def name = output_file.getName();
                def extension = output_file.getExtension();
                if ( name  == "gtdbtk_results.tar.gz" ) {
                    return "additional_data/${name}";
                }
                return null;
            }
        },
        mode: 'copy',
        failOnError: true
    )

    label 'process_bigmem'

    input:
    path genomes_fna, stageAs: "genomes_dir/*"
    path gtdbtk_refdata

    output:
    path 'gtdbtk_results/classify/gtdbtk.bac120.summary.tsv', optional: true, emit: gtdbtk_summary_bac120
    path 'gtdbtk_results/classify/gtdbtk.ar53.summary.tsv', optional: true, emit: gtdbtk_summary_arc53
    path 'gtdbtk_results/align/gtdbtk.bac120.user_msa.fasta.gz', optional: true, emit: gtdbtk_user_msa_bac120
    path 'gtdbtk_results/align/gtdbtk.ar53.user_msa.fasta.gz', optional: true, emit: gtdbtk_user_msa_ar53
    path 'gtdbtk_results.tar.gz', emit: gtdbtk_output_tarball


    script:
    // TODO: tweak the cpus based on the number of genomes
    """
    GTDBTK_DATA_PATH=/opt/gtdbtk_refdata \
    gtdbtk classify_wf \
    --cpus ${task.cpus} \
    --pplacer_cpus ${task.cpus} \
    --genome_dir genomes_dir \
    --extension fna \
    --out_dir gtdbtk_results

    tar -czf gtdbtk_results.tar.gz gtdbtk_results
    """

    stub:
    """
    mkdir gtdbtk_results

    mkdir -p gtdbtk_results/classify
    touch gtdbtk_results/classify/gtdbtk.bac120.summary.tsv
    touch gtdbtk_results/classify/gtdbtk.ar122.summary.tsv

    echo "user_genome	classification	fastani_reference	fastani_reference_radius	fastani_taxonomy	fastani_ani	fastani_af	closest_placement_reference	closest_placement_radius	closest_placement_taxonomy	closest_placement_ani	closest_placement_af	pplacer_taxonomy	classification_method	note	other_related_references(genome_id,species_name,radius,ANI,AF)	msa_percent	translation_table	red_value	warnings" > gtdbtk_results/classify/gtdbtk.bac120.summary.tsv

    for file in $drep_folder/*
    do
        GENOME=\$(basename \$file .fna)
        echo "\$GENOME	d__Bacteria;p__Actinobacteriota;c__Actinomycetia;o__Actinomycetales;f__Micrococcaceae;g__Rothia;s__Rothia mucilaginosa_B	GCF_001548235.1	95	d__Bacteria;p__Actinobacteriota;c__Actinomycetia;o__Actinomycetales;f__Micrococcaceae;g__Rothia;s__Rothia mucilaginosa_B	95.51	0.96	GCF_000175615.1	95	d__Bacteria;p__Actinobacteriota;c__Actinomycetia;o__Actinomycetales;f__Micrococcaceae;g__Rothia;s__Rothia mucilaginosa	94.5	0.94	d__Bacteria;p__Actinobacteriota;c__Actinomycetia;o__Actinomycetales;f__Micrococcaceae;g__Rothia;s__	ANI	topological placement and ANI have incongruent species assignments	GCF_000269965.1, s__Bifidobacterium infantis, 95.0, 94.8, 0.77	97.9	11	N/A	N/A" >> gtdbtk_results/classify/gtdbtk.bac120.summary.tsv
    done
    """
}
