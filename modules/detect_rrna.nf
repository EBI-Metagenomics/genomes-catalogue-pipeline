/*
 * Predict bacterial 5S, 16S, 23S rRNA and tRNA genes
*/
process DETECT_RRNA {

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                if (!filename.contains(".fasta")) {
                    return null;
                }
                String genome_id = filename.tokenize('.')[0];
                String cluster_rep_prefix = cluster.substring(10);
                return "species_catalogue/${cluster_rep_prefix}/${cluster_name}/genome/${genome_id}_rRNAs.fasta"
            }
        },
        mode: 'copy'
    )

    container 'quay.io/microbiome-informatics/genomes-pipeline.detect_rrna:v3.1'

    cpus 4
    memory '2 GB'

    input:
    tuple val(cluster_name), path(fasta)
    path cm_models

    output:
    path 'results_folder/*.out', type: 'file', emit: rrna_out_results
    path 'results_folder/*.fasta', type: 'file', emit: rrna_fasta_results

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
    cat "\${RESULTS_FOLDER}/\${FILENAME}"_*.tblout > "\${RESULTS_FOLDER}/\${FILENAME}_all.tblout"

    echo "Removing overlaps..."
    cmsearch-deoverlap.pl \
    --maxkeep \
    --clanin "\${CM_DB}/ribo.claninfo" \
    "\${RESULTS_FOLDER}/\${FILENAME}_all.tblout"

    mv "\${FILENAME}_all.tblout.deoverlapped" "\${RESULTS_FOLDER}/\${FILENAME}_all.tblout.deoverlapped"

    echo "Parsing final results..."
    parse_rRNA-bacteria.py -i \
    "\${RESULTS_FOLDER}/\${FILENAME}_all.tblout.deoverlapped" 1> "\${RESULTS_FOLDER}/\${FILENAME}_rRNAs.out"

    rRNA2seq.py -d \
    "\${RESULTS_FOLDER}/\${FILENAME}_all.tblout.deoverlapped" \
    -i "\${FASTA}" 1> "\${RESULTS_FOLDER}/\${FILENAME}_rRNAs.fasta"

    echo "[ Detecting tRNAs ]"
    tRNAscan-SE -B -Q \
    -m "\${RESULTS_FOLDER}/\${FILENAME}_stats.out" \
    -o "\${RESULTS_FOLDER}/\${FILENAME}_trna.out" "\${FASTA}"

    parse_tRNA.py -i "\${RESULTS_FOLDER}/\${FILENAME}_stats.out" 1> "\${RESULTS_FOLDER}/\${FILENAME}_tRNA_20aa.out"

    echo "Cleaning tmp files..."
    rm \
    "\${RESULTS_FOLDER}/\${FILENAME}_all.tblout.deoverlapped" \
    "\${RESULTS_FOLDER}/\${FILENAME}_all.tblout" \
    "\${RESULTS_FOLDER}/\${FILENAME}_all.tblout.sort" \
    "\${RESULTS_FOLDER}/\${FILENAME}"_*.cm.out \
    "\${RESULTS_FOLDER}/\${FILENAME}_stats.out" \
    "\${RESULTS_FOLDER}/\${FILENAME}_trna.out"

    echo "Completed"
    """
}

/*
 * Collect the rrna results into a folder
*/
process COLLECT_IN_FOLDER {

    publishDir "${params.outdir}/rrna/", mode: "copy"

    label 'process_light'

    cpus 1
    memory '1 GB'

    input:
    path files
    val folder_name

    output:
    path "${folder_name}", type: 'dir', emit: collection_folder

    script:
    """
    mkdir ${folder_name}
    mv ${files.join( ' ' )} ${folder_name}
    """
}
