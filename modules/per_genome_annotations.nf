/*
 * Takes interproscan and eggNOG results for an MMseqs catalog as well
 * as a list of representative genomes and locations where the results
 * should be stored and creates individual annotation files for each
 * representative genome
*/

process PER_GENOME_ANNONTATION_GENERATOR {

    publishDir(
        "${params.outdir}",
        pattern: "output_folder/*.tsv",
        saveAs: {
            filename -> "${params.catalogue_name}_metadata/${filename.tokenize(".")[0]}/genome/$filename"
        },
        mode: 'copy'
    )

    cpus 16
    memory '5 GB'

    input:
    file ips_annotations_tsv
    file eggnog_annotations_tsv
    file species_reps_csv
    file mmseq_tsv

    output:
    path "output_folder/*_InterProScan.tsv", emit: ips_annotation_tsvs
    path "output_folder/*_eggNOG.tsv", emit: eggnog_annotation_tsvs

    script:
    """
    per_genome_annotations.py \
    --ips ${ips_annotations_tsv} \
    --eggnog ${eggnog_annotations_tsv} \
    --rep-list ${species_reps_csv} \
    --mmseqs-tsv ${mmseq_tsv} \
    -c ${task.cpus} \
    -o output_folder
    """

    // stub:
    // """
    // mkdir -p output_folder/
    // touch output_folder/mmseqs_0.9_cluster_rep.emapper.annotations
    // touch output_folder/MGYG000000004_InterProScan.tsv
    // touch output_folder/MGYG000000004_eggNOG.tsv
    // touch output_folder/mmseqs_0.9_cluster_rep.IPS.tsv

    // mkdir -p output_folder/rRNA_fastas/MGYG000000004_fasta-results
    // touch output_folder/rRNA_fastas/MGYG000000004_fasta-results/MGYG000000004_rRNAs.fasta

    // mkdir -p output_folder/rRNA_outs/MGYG000000004_out-results
    // touch output_folder/rRNA_outs/MGYG000000004_out-results/MGYG000000004_rRNAs.out
    // touch output_folder/rRNA_outs/MGYG000000004_out-results/MGYG000000004_tRNA_20aa.out
    // """
}
