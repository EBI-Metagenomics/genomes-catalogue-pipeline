/*
 * Predict bacterial 5S, 16S, 23S rRNA and tRNA genes
*/
process DETECT_RRNA {

    tag "${cluster_name}"

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                if ( !filename.endsWith(".fasta") ) {
                    return null
                }
                def output_file = file(filename);
                def genome_id = fasta.baseName;
                def is_rep = genome_id == cluster_name;
                if ( is_rep && output_file.name.contains("_rRNAs") ) {
                    def cluster_rep_prefix = cluster_name.substring(0, cluster_name.length() - 2);
                    return "species_catalogue/${cluster_rep_prefix}/${genome_id}/genome/${genome_id}_rRNAs.fasta";
                }
                return null;
            }
        },
        mode: 'copy',
        failOnError: true
    )

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                if ( !filename.endsWith(".out") ) {
                    return null;
                }
                def output_file = file(filename);
                def genome_id = fasta.baseName;
                if ( output_file.name.contains("_rRNAs") || output_file.name.contains("_tRNA_20aa") ) {
                    return "additional_data/rRNA_outs/${genome_id}/${output_file.name}";
                }
                return null;
            }
        },
        mode: 'copy',
        failOnError: true
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.detect_rrna:v3.1'

    input:
    tuple val(cluster_name), path(fasta)
    path cm_models

    output:
    path 'results_folder/*.out', type: 'file', emit: rrna_out_results
    path 'results_folder/*.fasta', type: 'file', emit: rrna_fasta_results
    path 'results_folder/*.tblout.deoverlapped', emit: rrna_tblout_deoverlapped

    script:
    """
    shopt -s extglob

    RESULTS_FOLDER=results_folder
    FASTA=${fasta}
    CM_DB=${cm_models}

    BASENAME=\$(basename "\${FASTA}")
    FILENAME="\${BASENAME%.*}"

    mkdir "\${RESULTS_FOLDER}"

    echo "[ Detecting rRNAs ] "

    for CM_FILE in "\${CM_DB}"/*.cm; do
        MODEL=\$(basename "\${CM_FILE}")
        echo "Running cmsearch for \${MODEL}..."
        cmsearch -Z 1000 \
            --hmmonly \
            --cut_ga --cpu ${task.cpus} \
            --noali \
            --tblout "\${RESULTS_FOLDER}/\${FILENAME}_\${MODEL}.tblout" \
            "\${CM_FILE}" "\${FASTA}" 1> "\${RESULTS_FOLDER}/\${FILENAME}_\${MODEL}.out"
    done

    echo "Concatenating results..."
    cat "\${RESULTS_FOLDER}/\${FILENAME}"_*.tblout > "\${RESULTS_FOLDER}/\${FILENAME}.tblout"

    echo "Removing overlaps..."
    cmsearch-deoverlap.pl \
    --maxkeep \
    --clanin "\${CM_DB}/ribo.claninfo" \
    "\${RESULTS_FOLDER}/\${FILENAME}.tblout"

    mv "\${FILENAME}.tblout.deoverlapped" "\${RESULTS_FOLDER}/\${FILENAME}.tblout.deoverlapped"

    echo "Parsing final results..."
    parse_rRNA-bacteria.py -i \
    "\${RESULTS_FOLDER}/\${FILENAME}.tblout.deoverlapped" 1> "\${RESULTS_FOLDER}/\${FILENAME}_rRNAs.out"

    rRNA2seq.py -d \
    "\${RESULTS_FOLDER}/\${FILENAME}.tblout.deoverlapped" \
    -i "\${FASTA}" 1> "\${RESULTS_FOLDER}/\${FILENAME}_rRNAs.fasta"

    echo "[ Detecting tRNAs ]"
    tRNAscan-SE -B -Q \
    -m "\${RESULTS_FOLDER}/\${FILENAME}_stats.out" \
    -o "\${RESULTS_FOLDER}/\${FILENAME}_trna.out" "\${FASTA}"

    parse_tRNA.py -i "\${RESULTS_FOLDER}/\${FILENAME}_stats.out" 1> "\${RESULTS_FOLDER}/\${FILENAME}_tRNA_20aa.out"

    echo "Completed"
    """
}
