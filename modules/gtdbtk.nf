process GTDBTK {

    container 'quay.io/microbiome-informatics/gtdb-tk:2.1.0'
    containerOptions "--bind ${gtdbtk_refdata}:/opt/gtdbtk_refdata"

    publishDir "results/gtdbtk", mode: 'copy'

    label 'process_bigmem'

    cpus 32
    memory '500 GB'

    input:
    path drep_folder
    path gtdbtk_refdata

    output:
    path 'gtdbtk_results/', emit: gtdbtk_results
    path 'gtdbtk_results/classify/gtdbtk.bac120.summary.tsv', optional: true, emit: gtdbtk_bac
    path 'gtdbtk_results/classify/gtdbtk.ar122.summary.tsv', optional: true, emit: gtdbtk_arc

    script:
    // TODO: tweak the cpus based on the number of genomes
    """
    GTDBTK_DATA_PATH=/opt/gtdbtk_refdata \
    gtdbtk classify_wf \
    --cpus ${task.cpus} \
    --pplacer_cpus ${task.cpus} \
    --genome_dir ${drep_folder} \
    --extension fna \
    --out_dir gtdbtk_results
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