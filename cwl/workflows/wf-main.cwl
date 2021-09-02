#!/usr/bin/env cwl-runner
cwlVersion: v1.2.0-dev2
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  genomes_ena: Directory?
  ena_csv: File?
  genomes_ncbi: Directory?

  max_accession_mgyg: int
  min_accession_mgyg: int

  # skip dRep step if MAGs were already dereplicated
  skip_drep_step: string   # set "skip" for skipping

  # no gtdbtk
  skip_gtdbtk_step: string   # set "skip" for skipping

  # common input
  mmseqs_limit_c: float
  mmseqs_limit_i: float[]

  gunc_db_path: File

  gtdbtk_data: Directory?

  InterProScan_databases: [string, Directory]
  chunk_size_IPS: int
  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]

outputs:

  # ------- unite_folders -------
  output_csv:
    type: File
    outputSource: unite_folders/csv

  # ------- assign_mgygs -------
  renamed_csv:
    type: File
    outputSource: assign_mgygs/renamed_csv
  naming_table:
    type: File
    outputSource: assign_mgygs/naming_table
  renamed_genomes:
    type: Directory
    outputSource: assign_mgygs/renamed_genomes

  # ------- drep -------
  weights:
    type: File?
    outputSource: drep_subwf/weights_file
  dereplicated_genomes:
    type: Directory?
    outputSource: drep_subwf/dereplicated_genomes
  mash_drep:
    type: File[]?
    outputSource: drep_subwf/mash_folder
  one_clusters:
    type: Directory[]?
    outputSource: drep_subwf/one_genome
  many_clusters:
    type: Directory[]?
    outputSource: drep_subwf/many_genomes

  # ------- clusters_annotation -------
  mash_folder:
    type: Directory?
    outputSource: clusters_annotation/mash_folder

  many_genomes:
    type: Directory[]?
    outputSource: clusters_annotation/many_genomes
  many_genomes_panaroo:
    type: Directory[]?
    outputSource: clusters_annotation/many_genomes_panaroo
  many_genomes_prokka:
    type:
      - 'null'
      - type: array
        items:
          type: array
          items: Directory
    outputSource: clusters_annotation/many_genomes_prokka
  many_genomes_genomes:
    type: Directory[]?
    outputSource: clusters_annotation/many_genomes_genomes

  one_genome:
    type: Directory[]?
    outputSource: clusters_annotation/one_genome
  one_genome_prokka:
    type: Directory[]?
    outputSource: clusters_annotation/one_genome_prokka
  one_genome_genomes:
    type: Directory[]?
    outputSource: clusters_annotation/one_genome_genomes

  mmseqs:
    type: Directory
    outputSource: clusters_annotation/mmseqs_output

  # ------- GTDB-Tk -------
  gtdbtk:
    type: Directory?
    outputSource: gtdbtk/gtdbtk_folder


steps:

# ----------- << checkm for NCBI >> -----------
  checkm_subwf:
    run: sub-wf/checkm-subwf.cwl
    when: $(Boolean(inputs.genomes_folder))
    in:
      genomes_folder: genomes_ncbi
    out:
      - checkm_csv

# ----------- << unite NCBI and ENA >> -----------
  unite_folders:
    run: ../tools/unite_ena_ncbi/unite.cwl
    in:
      ena_folder: genomes_ena
      ncbi_folder: genomes_ncbi
      ena_csv: ena_csv
      ncbi_csv: checkm_subwf/checkm_csv
      outputname: { default: "genomes"}
    out:
      - genomes
      - csv

# ----------- << assign MGYGs >> -----------
  assign_mgygs:
    run: ../tools/rename_fasta/rename_fasta.cwl
    in:
      genomes: unite_folders/genomes
      prefix: { default: "MGYG"}
      start_number: min_accession_mgyg
      max_number: max_accession_mgyg
      output_filename: { default: "names.tsv"}
      output_dirname: { default: "mgyg_genomes" }
      csv: unite_folders/csv
    out:
      - naming_table
      - renamed_genomes
      - renamed_csv

# ---------- dRep + split -----------
  drep_subwf:
    run: sub-wf/drep-subwf.cwl
    in:
      genomes_folder: assign_mgygs/renamed_genomes
      input_csv: assign_mgygs/renamed_csv
      skip_flag: skip_drep_step
    out:
      - many_genomes
      - one_genome
      - mash_folder           # only for non dereplicated mags
      - dereplicated_genomes  # only for non dereplicated mags
      - weights_file          # only for non dereplicated mags

# ---------- annotation
  clusters_annotation:
    run: sub-wf/subwf-process_clusters.cwl
    in:
      many_genomes: drep_subwf/many_genomes
      mash_folder: drep_subwf/mash_folder
      one_genome: drep_subwf/one_genome
      mmseqs_limit_c: mmseqs_limit_c
      mmseqs_limit_i: mmseqs_limit_i
      gunc_db_path: gunc_db_path
      InterProScan_databases: InterProScan_databases
      chunk_size_IPS: chunk_size_IPS
      chunk_size_eggnog: chunk_size_eggnog
      db_diamond_eggnog: db_diamond_eggnog
      db_eggnog: db_eggnog
      data_dir_eggnog: data_dir_eggnog
      csv: assign_mgygs/renamed_csv
    out:
      - mash_folder
      - many_genomes
      - many_genomes_panaroo
      - many_genomes_prokka
      - many_genomes_genomes
      - one_genome
      - one_genome_prokka
      - one_genome_genomes
      - mmseqs_output

# ----------- << GTDB - Tk >> -----------
  gtdbtk:
    when: $(inputs.skip_flag !== 'skip')
    run: ../tools/gtdbtk/gtdbtk.cwl
    in:
      skip_flag: skip_gtdbtk_step
      drep_folder:
        source:
          - drep_subwf/dereplicated_genomes
          - assign_mgygs/renamed_genomes
        pickValue: first_non_null
      gtdb_outfolder: { default: 'gtdb-tk_output' }
      refdata: gtdbtk_data
    out: [ gtdbtk_folder ]