#!/usr/bin/env cwl-runner
cwlVersion: v1.2
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
  skip_drep_step: boolean   # set True for skipping

  # no gtdbtk
  skip_gtdbtk_step: boolean   # set True for skipping

  # common input
  mmseqs_limit_c: float
  mmseqs_limit_i: float[]
  mmseq_limit_annotation: float

  gunc_db_path: File

  gtdbtk_data: Directory?

  interproscan_databases: [string, Directory]
  chunk_size_ips: int
  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]

  cm_models: Directory

outputs:

# ------- intermediate files -------
  intermediate_files:
    type: Directory
    outputSource: folder_with_intermediate_files/out

# ------- clusters_annotation -------

  pan-genomes:
    type: Directory[]?
    outputSource: annotation/pan-genomes

  singletons:
    type: Directory[]?
    outputSource: annotation/singletons

  mmseqs:
    type: Directory?
    outputSource: annotation/mmseqs

  gffs:
    type: Directory
    outputSource: annotation/gffs
  panaroo:
    type: Directory
    outputSource: annotation/panaroo_folder
# ------- functional annotation ----------
  ips:
    type: File?
    outputSource: annotation/ips

  eggnog_annotations:
    type: File?
    outputSource: annotation/eggnog_annotations
  eggnog_seed_orthologs:
    type: File?
    outputSource: annotation/eggnog_seed_orthologs

# ---------- rRNA -------------
  rrna_out:
    type: Directory
    outputSource: annotation/rrna_out

  rrna_fasta:
    type: Directory
    outputSource: annotation/rrna_fasta

# ------------ GTDB-Tk --------------
  gtdbtk:
    type: Directory?
    outputSource: gtdbtk/gtdbtk_folder

steps:

# ----------- << checkM + assign MGYG >> -----------
  preparation:
    run: wf-preparation.cwl
    in:
      genomes_ena: genomes_ena
      ena_csv: ena_csv
      genomes_ncbi: genomes_ncbi
      max_accession_mgyg: max_accession_mgyg
      min_accession_mgyg: min_accession_mgyg
    out:
      - unite_folders_csv
      - assign_mgygs_renamed_genomes
      - assign_mgygs_renamed_csv
      - assign_mgygs_naming_table

# ---------- dRep + split -----------
  drep_subwf:
    run: sub-wf/drep-subwf.cwl
    in:
      genomes_folder: preparation/assign_mgygs_renamed_genomes
      input_csv: preparation/assign_mgygs_renamed_csv
      skip_flag: skip_drep_step
    out:
      - many_genomes
      - one_genome
      - mash_files
      - best_cluster_reps
      - weights_file
      - split_text


# ----------- << annotations + IPS, eggnog + filter drep + rRNA >> ------
  annotation:
    run: wf-annotation.cwl
    in:
      assign_mgygs_renamed_csv: preparation/assign_mgygs_renamed_csv
      assign_mgygs_renamed_genomes: preparation/assign_mgygs_renamed_genomes

      drep_subwf_many_genomes: drep_subwf/many_genomes
      drep_subwf_mash_files: drep_subwf/mash_files
      drep_subwf_one_genome: drep_subwf/one_genome
      drep_subwf_split_text: drep_subwf/split_text

      mmseqs_limit_c: mmseqs_limit_c
      mmseqs_limit_i: mmseqs_limit_i
      mmseq_limit_annotation: mmseq_limit_annotation

      gunc_db_path: gunc_db_path

      interproscan_databases: interproscan_databases
      chunk_size_ips: chunk_size_ips
      chunk_size_eggnog: chunk_size_eggnog
      db_diamond_eggnog: db_diamond_eggnog
      db_eggnog: db_eggnog
      data_dir_eggnog: data_dir_eggnog

      cm_models: cm_models

    out:
      - pan-genomes
      - singletons
      - mmseqs
      - gffs
      - ips
      - eggnog_annotations
      - eggnog_seed_orthologs
      - rrna_out
      - rrna_fasta
      - clusters_annotation_singletons_gunc_completed
      - filter_genomes_list_drep_filtered
      - filter_genomes_drep_filtered_genomes
      - mmseqs_clusters_tsv
      - panaroo_folder

# ----------- << GTDB - Tk >> -----------
  gtdbtk:
    when: $(!Boolean(inputs.skip_flag))
    run: ../tools/gtdbtk/gtdbtk.cwl
    in:
      skip_flag: skip_gtdbtk_step
      drep_folder: annotation/filter_genomes_drep_filtered_genomes
      gtdb_outfolder: { default: 'gtdb-tk_output' }
      refdata: gtdbtk_data
    out: [ gtdbtk_folder ]

# ---------- << return folder with intermediate files >> ----------
  folder_with_intermediate_files:
    run: ../utils/return_directory.cwl
    in:
      list:
        source:
          - preparation/unite_folders_csv                               # initail csv
          - preparation/assign_mgygs_renamed_csv                        # MGYG csv
          - preparation/assign_mgygs_naming_table                       # mapping initial names to MGYGs
          - drep_subwf/weights_file                                     # weights drep
          - drep_subwf/best_cluster_reps                                # Sdb.csv
          - drep_subwf/split_text                                       # split by clusters file
          - annotation/clusters_annotation_singletons_gunc_completed    # gunc passed genomes list
          - annotation/filter_genomes_list_drep_filtered                # list of dereplicated genomes
      dir_name: {default: 'intermediate_files'}
    out: [ out ]

