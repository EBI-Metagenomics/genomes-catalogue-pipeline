process DETECT_NCRNA {

    tag "$genome_accession"
    container 'quay.io/microbiome-informatics/genomes-pipeline.detect_rrna:v3.2'

    publishDir(
        path: "${params.outdir}/additional_data/ncrna_deoverlapped_species_reps",
        pattern: '*.ncrna.deoverlap.tbl',
        saveAs: { filename ->
            is_rep ? "${genome_accession}.ncrna.deoverlap.tbl" : null
        },
        mode: 'copy'
    )

    publishDir(
        path: "${params.outdir}/species_catalogue/${cluster_rep_prefix}/${genome_accession}/genome",
        pattern: '*_rRNAs.fasta',
        saveAs: { filename ->
            is_rep ? filename : null
        },
        mode: 'copy',
        failOnError: true
    )

    publishDir(
        path: "${params.outdir}/additional_data/rRNA_outs/${genome_accession}",
        pattern: '*_rRNAs.out',
        mode: 'copy',
        failOnError: true
    )

    input:
    tuple val(cluster_name), path(fasta)
    path rfam_ncrna_models
    val kingdom

    output:
    tuple val(genome_accession), path('*.ncrna.deoverlap.tbl'), emit: ncrna_tblout
    tuple val(genome_accession), path('*_rRNAs.out'), emit: rrna_out_results
    tuple val(genome_accession), path('*_rRNAs.fasta'), emit: rrna_fasta_results

    script:
    genome_accession = fasta.baseName
    is_rep = (genome_accession == cluster_name)
    cluster_rep_prefix = cluster_name.substring(0, cluster_name.length() - 2)
    """
    cmscan \
    --cpu ${task.cpus} \
    --tblout overlapped_${genome_accession} \
    --hmmonly \
    --clanin ${rfam_ncrna_models}/Rfam.clanin \
    --fmt 2 \
    --cut_ga \
    --noali \
    -o /dev/null \
    ${rfam_ncrna_models}/Rfam.cm \
    ${fasta}

    # De-overlap #
    grep -v " = " overlapped_${genome_accession} > ${genome_accession}.ncrna.deoverlap.tbl

    if [ "${kingdom}" = "eukaryotes" ]; then
        echo "Parsing final eukaryotic results"
        parse_rRNA-eukaryotes.py \
        -s cmscan \
        -i ${genome_accession}.ncrna.deoverlap.tbl \
        -o ${genome_accession}_rRNAs.out
    else
        echo "Parsing final bacterial results..."
        parse_rRNA-bacteria.py \
        -s cmscan \
        -i ${genome_accession}.ncrna.deoverlap.tbl \
        -o ${genome_accession}_rRNAs.out
    fi

    rRNA2seq.py -d \
    ${genome_accession}.ncrna.deoverlap.tbl \
    -s cmscan \
    -i ${fasta} \
    -o ${genome_accession}_rRNAs.fasta
    """
}
