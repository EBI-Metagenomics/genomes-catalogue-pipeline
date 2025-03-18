
process DETECT_NCRNA {

    container 'quay.io/microbiome-informatics/genomes-pipeline.detect_rrna:v3.2'
    
    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def output_file = file(filename);
                def is_rep = fasta.baseName == cluster_name;
                if ( is_rep && output_file.name.contains("ncrna.deoverlap.tbl" )) {
                    return "additional_data/ncrna_deoverlapped_species_reps/${fasta.baseName}.ncrna.deoverlap.tbl";
                }
            }
        },
        mode: 'copy'
    )
    
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
                if ( output_file.name.contains("_rRNAs") ) {
                    return "additional_data/rRNA_outs/${genome_id}/${output_file.name}";
                }
                return null;
            }
        },
        mode: 'copy',
        failOnError: true
    )

    input:
    tuple val(cluster_name), path(fasta)
    path rfam_ncrna_models
    val(kingdom)

    output:
    tuple val(fasta.baseName), path('*.ncrna.deoverlap.tbl'), emit: ncrna_tblout
    tuple val(fasta.baseName), path('*_rRNAs.out'), emit: rrna_out_results
    tuple val(fasta.baseName), path('*_rRNAs.fasta'), emit: rrna_fasta_results

    script:
    """
    cmscan \
    --cpu ${task.cpus} \
    --tblout overlapped_${fasta.baseName} \
    --hmmonly \
    --clanin ${rfam_ncrna_models}/Rfam.clanin \
    --fmt 2 \
    --cut_ga \
    --noali \
    -o /dev/null \
    ${rfam_ncrna_models}/Rfam.cm \
    ${fasta}

    # De-overlap #
    grep -v " = " overlapped_${fasta.baseName} > ${fasta.baseName}.ncrna.deoverlap.tbl

    if [ "${kingdom}" = "eukaryotes" ]; then
        echo "Parsing final eukaryotic results"
        parse_rRNA-eukaryotes.py \
        -s cmscan \
        -i ${fasta.baseName}.ncrna.deoverlap.tbl \
        -o ${fasta.baseName}_rRNAs.out
    else
        echo "Parsing final bacterial results..."
        parse_rRNA-bacteria.py \
        -s cmscan \
        -i ${fasta.baseName}.ncrna.deoverlap.tbl \
        -o ${fasta.baseName}_rRNAs.out
    fi

    rRNA2seq.py -d \
    ${fasta.baseName}.ncrna.deoverlap.tbl \
    -s cmscan \
    -i ${fasta} \
    -o ${fasta.baseName}_rRNAs.fasta
    
    """
}
