/*
 * Predict tRNA genes
*/
process DETECT_TRNA {

    tag "${genome_name}"

    container 'quay.io/microbiome-informatics/genomes-pipeline.detect_rrna:v3.2'
    
    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> {
                if ( !filename.endsWith(".out") ) {
                    return null;
                }
                def output_file = file(filename);
                def genome_id = fasta.baseName.replace("_sm", "");
                if ( output_file.name.contains("_tRNA_20aa") ) {
                    return "additional_data/rRNA_outs/${genome_id}/${output_file.name}";
                }
                return null;
            }
        },
        mode: 'copy',
        failOnError: true
    )

    input:
    tuple val(genome_name), path(fasta), val(detected_kingdom)

    output:
    tuple val(genome_name), path('*_trna.out'), emit: trna_out
    tuple val(genome_name), path('*_stats.out'), emit: trna_stats
    tuple val(genome_name), path('*_tRNA_20aa.out'), emit: trna_count
    tuple val(genome_name), path('*_trna.gff'), emit: trna_gff

    script:
    """
    shopt -s extglob

    # tRNAscan-SE needs a tmp folder otherwise it will use the base TMPDIR (with no subfolder)
    # and that causes issues as other detect_trna process will crash when the files are cleaned
    PROCESSTMP="\$(mktemp -d)"
    export TMPDIR="\${PROCESSTMP}"
    # bash trap to clean the tmp directory
    trap 'rm -r -- "\${PROCESSTMP}"' EXIT

    echo "[ Detecting tRNAs ]"
    kingdom=\$(echo ${detected_kingdom} | cut -c1)
    tRNAscan-SE -\${kingdom} -Q \
    -m ${genome_name}_stats.out \
    -o ${genome_name}_trna.out \
    --gff ${genome_name}_trna.gff \
    ${fasta}

    parse_tRNA.py -i ${genome_name}_stats.out -o ${genome_name}_tRNA_20aa.out

    echo "Completed"

    """
}
