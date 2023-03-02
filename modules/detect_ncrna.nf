
process DETECT_NCRNA {

    container 'quay.io/microbiome-informatics/genomes-pipeline.detect_rrna:v3'

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                def result_file = file(filename);
                String genome_id = result_file.getSimpleName();
                def file_extension = result_file.getExtension();
                if (file_extension == "deoverlapped" && cluster_name == genome_id) {
                    return "additional_data/rrna_deoverlapped_species_reps/${genome_id}.${file_extension}";
                }
            }
        },
        mode: 'copy'
    )

    cpus 4
    memory '5 GB'

    input:
    tuple val(cluster_name), path(fasta)
    path rfam_ncrna_models

    output:
    tuple val(cluster_name), path('*.ncrna.deoverlap.tbl'), emit: ncrna_tblout

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
    """
}
