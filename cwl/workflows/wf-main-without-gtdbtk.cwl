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

  # skip dRep step if MAGs were already dereplicated and provide Sdb.csv, Mdb.csv and Cdb.csv
  skip_drep_step: boolean   # set True for skipping
  sdb_dereplicated: File?
  cdb_dereplicated: File?
  mdb_dereplicated: File?

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
  kegg_db: File

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

  panaroo:
    type: Directory
    outputSource: annotation/panaroo_folder

# ------- additional files for clusters (kegg, ips, eggnog, cog, cazy, annotated gff) ----------
  cluster_annotations:
    type: Directory[]
    outputSource: post_processing/annotations_cluster_dir

# ---------- rRNA -------------
  rrna_out:
    type: Directory
    outputSource: annotation/rrna_out

  rrna_fasta:
    type: Directory
    outputSource: annotation/rrna_fasta

# ---------- GFF ----------
  gff_ftp:
    type: Directory
    outputSource: create_gff_folder_ftp/gffs_folder

# for gtdbtk and post-processing
  drep_genomes:
    type: Directory
    outputSource: annotation/filter_genomes_drep_filtered_genomes


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
    run: sub-wf/drep/drep-main.cwl
    in:
      genomes_folder: preparation/assign_mgygs_renamed_genomes
      input_csv: preparation/assign_mgygs_renamed_csv
      # for dereplicated set
      skip_flag: skip_drep_step
      sdb_dereplicated: sdb_dereplicated
      cdb_dereplicated: cdb_dereplicated
      mdb_dereplicated: mdb_dereplicated
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
      - pan-genomes             # Dir[]
      - singletons              # Dir[]
      - mmseqs                  # Dir[]
      - ips_eggnog_annotations  # File[]
      - rrna_out
      - rrna_fasta
      - clusters_annotation_singletons_gunc_completed
      - filter_genomes_list_drep_filtered
      - filter_genomes_drep_filtered_genomes
      - mmseqs_clusters_tsv
      - panaroo_folder
      - main_reps_faa_pangenomes
      - main_reps_gff_pangenomes
      - main_reps_faa_singletons
      - main_reps_gff_singletons
      - gffs_pangenomes

# ---------- << post-processing >> ----------
  post_processing:
    run: wf-post-processing.cwl
    in:
      annotations: annotation/ips_eggnog_annotations
      clusters: annotation/filter_genomes_list_drep_filtered
      kegg: kegg_db
      gffs:
        source:
          - annotation/main_reps_gff_pangenomes
          - annotation/main_reps_gff_singletons
        pickValue: all_non_null
        linkMerge: merge_flattened
      faas:
        source:
          - annotation/main_reps_faa_pangenomes
          - annotation/main_reps_faa_singletons
        pickValue: all_non_null
        linkMerge: merge_flattened
    out:
      - annotations_cluster_dir  # Dir[]
      - annotated_gff  # File[]

  create_gff_folder_ftp:
    run: sub-wf/post-processing/create_gffs_folder.cwl
    in:
      gffs:
        source:
          - post_processing/annotated_gff           # annotated GFFs for main reps
          - annotation/gffs_pangenomes              # all GFF from pangenomes
          - annotation/main_reps_gff_singletons     # all GFF from singletones
        pickValue: all_non_null
        linkMerge: merge_flattened
      folder_name: { default: GFF }
    out: [ gffs_folder ]


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
          - annotation/mmseqs_clusters_tsv                              # mmseqs 0.9 tsv
        pickValue: all_non_null
      dir_name: { default: 'intermediate_files'}
    out: [ out ]
