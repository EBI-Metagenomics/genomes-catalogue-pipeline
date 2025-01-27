/*
 * Takes interproscan and eggNOG results for an MMseqs catalog as well
 * as a list of representative genomes and locations where the results
 * should be stored and creates individual annotation files for each
 * representative genome
*/

process PER_GENOME_ANNOTATION_GENERATOR {

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def tsv_file = file(filename);
                def tsv_simple_name = tsv_file.getSimpleName();
                String genome_name = tsv_simple_name.replace("_eggNOG", "").replace("_InterProScan", "");
                String cluster_prefix = genome_name.substring(0, genome_name.length() - 2);
                return "species_catalogue/${cluster_prefix}/${genome_name}/genome/${tsv_simple_name}.${tsv_file.getExtension()}";
            }
        },
        mode: 'copy',
        failOnError: true
    )

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
