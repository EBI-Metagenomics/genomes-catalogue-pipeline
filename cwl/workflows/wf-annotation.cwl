#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  - process singleton and pan-genome clusters
  - IPS + eggnog
  - filter drep genomes + filtered by GUNC
  - detect rRNA


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

  panaroo_folder:
    type: Directory
    outputSource: clusters_annotation/panaroo_folder

  mmseqs_clusters_tsv:
    type: File?
    outputSource: clusters_annotation/cluster_tsv

#  main_reps_faa:
#    type: File[]
#    outputSource: clusters_annotation/all_main_reps_faa
#  main_reps_gff:
#    type: File[]
#    outputSource: clusters_annotation/all_main_reps_gff
  main_reps_faa_pangenomes:
    type: File[]
    outputSource: clusters_annotation/all_main_reps_faa_pangenomes

  main_reps_gff_pangenomes:
    type: File[]
    outputSource: clusters_annotation/all_main_reps_gff_pangenomes

  main_reps_faa_singletons:
    type: File[]?
    outputSource: clusters_annotation/all_main_reps_faa_singletons

  main_reps_gff_singletons:
    type: File[]?
    outputSource: clusters_annotation/all_main_reps_gff_singletons

  gffs_pangenomes:
    type: File[]
    outputSource: clusters_annotation/all_gffs_pangenomes  #clusters_annotation/gffs_list

  core_genes_files:
    type: File[]
    outputSource: clusters_annotation/all_core_genes

  pangenome_fna_files:
    type: File[]
    outputSource: clusters_annotation/all_pangenome_fna

# ------- functional annotation ----------
  ips_eggnog_annotations:
    type: File[]
    outputSource: functional_annotation/per_genome_annotations

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
    run: sub-wf/annotation/subwf-process_clusters.cwl
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
      - pangenomes_initial_fa
      - singletons
      - singletons_gunc_completed
      - singletons_gunc_failed
      - singletons_filtered_initial_fa
      - mmseqs_output
      - cluster_representatives
      - cluster_tsv
      - panaroo_folder
      - all_main_reps_gff_pangenomes
      - all_main_reps_faa_pangenomes
      - all_main_reps_gff_singletons
      - all_main_reps_faa_singletons
      - all_gffs_pangenomes  # gffs_list  # File[]
      - all_core_genes          # for json
      - all_pangenome_fna       # for json

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

# ----------- << functional annotation >> ------
  functional_annotation:
    run: sub-wf/annotation/functional_annotation.cwl
    in:
      input_faa: clusters_annotation/cluster_representatives
      interproscan_databases: interproscan_databases
      chunk_size_ips: chunk_size_ips
      chunk_size_eggnog: chunk_size_eggnog
      db_diamond_eggnog: db_diamond_eggnog
      db_eggnog: db_eggnog
      data_dir_eggnog: data_dir_eggnog
      species_representatives: filter_genomes/list_drep_filtered
      mmseqs_tsv: clusters_annotation/cluster_tsv
    out:
      - per_genome_annotations

# ---------- << detect rRNA >> ---------
  detect_rrna:
    run: sub-wf/annotation/detect_rrna_subwf.cwl
    in:
      filtered_genomes:
        source:
          - clusters_annotation/pangenomes_initial_fa           # all genomes from pangenomes
          - clusters_annotation/singletons_filtered_initial_fa  # all passed GUNC singletons
        linkMerge: merge_flattened
        pickValue: all_non_null
      cm_models: cm_models
    out: [rrna_outs, rrna_fastas]


