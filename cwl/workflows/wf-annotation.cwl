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
  drep_subwf_many_genomes: Directory[]?
  drep_subwf_mash_files: File[]?
  drep_subwf_one_genome: Directory[]?
  drep_subwf_split_text: File
  assign_mgygs_renamed_csv: File
  assign_mgygs_renamed_genomes: Directory

  # common input
  mmseqs_limit_c: float
  mmseqs_limit_i: float[]
  mmseq_limit_annotation: float

  gunc_db_path: File

  interproscan_databases: [string, Directory]
  chunk_size_ips: int
  chunk_size_eggnog: int
  db_diamond_eggnog: [string?, File?]
  db_eggnog: [string?, File?]
  data_dir_eggnog: [string?, Directory?]

  cm_models: Directory

outputs:

# ------- intermediate files -------
  clusters_annotation_singletons_gunc_completed:
    type: File
    outputSource: clusters_annotation/singletons_gunc_completed

  filter_genomes_list_drep_filtered:
    type: File
    outputSource: filter_genomes/list_drep_filtered

# ------- clusters_annotation -------

  pan-genomes:
    type: Directory[]?
    outputSource: clusters_annotation/pangenomes

  singletons:
    type: Directory[]?
    outputSource: clusters_annotation/singletons

  mmseqs:
    type: Directory?
    outputSource: clusters_annotation/mmseqs_output

  gffs:
    type: Directory
    outputSource: clusters_annotation/gffs_folder
  panaroo_folder:
    type: Directory
    outputSource: clusters_annotation/panaroo_folder

  mmseqs_clusters_tsv:
    type: File?
    outputSource: clusters_annotation/cluster_tsv

# ------- functional annotation ----------
  ips:
    type: File?
    outputSource: functional_annotation/ips_result

  eggnog_annotations:
    type: File?
    outputSource: functional_annotation/eggnog_annotations
  eggnog_seed_orthologs:
    type: File?
    outputSource: functional_annotation/eggnog_seed_orthologs

# ---------- rRNA -------------
  rrna_out:
    type: Directory
    outputSource: detect_rrna/rrna_outs

  rrna_fasta:
    type: Directory
    outputSource: detect_rrna/rrna_fastas

  filter_genomes_drep_filtered_genomes:
    type: Directory
    outputSource: filter_genomes/drep_filtered_genomes

steps:

# ---------- annotation
  clusters_annotation:
    run: sub-wf/subwf-process_clusters.cwl
    in:
      many_genomes: drep_subwf_many_genomes
      mash_folder: drep_subwf_mash_files
      one_genome: drep_subwf_one_genome
      mmseqs_limit_c: mmseqs_limit_c
      mmseqs_limit_i: mmseqs_limit_i
      mmseq_limit_annotation: mmseq_limit_annotation
      gunc_db_path: gunc_db_path
      csv: assign_mgygs_renamed_csv
    out:
      - pangenomes
      - singletons
      - singletons_gunc_completed
      - singletons_gunc_failed
      - mmseqs_output
      - cluster_representatives
      - cluster_tsv
      - gffs_folder
      - panaroo_folder

# ----------- << functional annotation >> ------
  functional_annotation:
    run: sub-wf/functional_annotation.cwl
    in:
      input_faa: clusters_annotation/cluster_representatives
      interproscan_databases: interproscan_databases
      chunk_size_ips: chunk_size_ips
      chunk_size_eggnog: chunk_size_eggnog
      db_diamond_eggnog: db_diamond_eggnog
      db_eggnog: db_eggnog
      data_dir_eggnog: data_dir_eggnog
    out:
      - ips_result
      - eggnog_annotations
      - eggnog_seed_orthologs

# ----------- << get genomes dereplicated genomes and GUNC-passed >> ------
  filter_genomes:
    run: ../tools/filter_drep_genomes/filter_drep_genomes.cwl
    in:
      genomes: assign_mgygs_renamed_genomes
      clusters: drep_subwf_split_text
      gunc_passed: clusters_annotation/singletons_gunc_completed
      outdirname: {default: deperlicated_genomes}
    out:
      - drep_filtered_genomes
      - list_drep_filtered


# ---------- << detect rRNA >> ---------
  detect_rrna:
    run: sub-wf/detect_rrna_subwf.cwl
    in:
      filtered_genomes: filter_genomes/drep_filtered_genomes
      cm_models: cm_models
    out: [rrna_outs, rrna_fastas]


