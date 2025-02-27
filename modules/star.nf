process STAR_INDEX {
    tag "${output_prefix}"

    container 'quay.io/biocontainers/star:2.7.3a--h5ca1c30_1'

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> "bamfiles/$filename"
        },
        mode: "copy",
        failOnError: true
    )

    input:
    path genome_fasta // genome_masked.fa

    output:
    tuple path("*.bam"), emit: bamfile

    script:
    """
    id=$(basename ${genome_fasta} .fa)

    STAR \
    --runThreadN 6 \
    --runMode genomeGenerate \
    --genomeDir ${id}_index \
    --genomeFastaFiles ${genome_fasta} \
    """
}

process STAR_ALIGN {

    tag "${output_prefix}"

    container 'quay.io/biocontainers/star:2.7.3a--h5ca1c30_1'

    publishDir(
        path: "${params.outdir}",
        saveAs: {
            filename -> "bamfiles/$filename"
        },
        mode: "copy",
        failOnError: true
    )

    input:
    path genome_index // directory
    path fastq_fwd // SRR_1.fastq
    path fastq_rev // SRR_2.fastq

    output:
    tuple path("*.bam"), emit: bamfile

    script:
    """
    id=$(basename ${fastq_fwd} _1.fastq)

    STAR \
    --runThreadN 16 \
    --twopassMode Basic \
    --runMode alignReads \
    --genomeDir ${genome_index} \
    --readFilesIn ${fastq_fwd} ${fastq_rev} \
    --outFileNamePrefix ${id} \
    --outTmpDir star_tmp_dir \
    --outSAMtype SAM 
    """
}

// index and map transcriptomic reads to genome
