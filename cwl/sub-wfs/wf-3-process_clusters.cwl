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
  many_genomes: Directory[]?
  mash_folder: File[]?

  one_genome: Directory[]?
  csv: File
  gunc_db_path: File

  mmseqs_limit_i: float[]
  mmseqs_limit_c: float
  mmseq_limit_annotation: float

outputs:

  clusters:
    type: Directory[]
    outputSource:
      source:
        - process_many_genomes/pangenome_clusters
        - process_one_genome/singleton_clusters
      linkMerge: merge_flattened

# ===== fna =======
  all_pangenome_fna:
    type: File[]
    outputSource: process_many_genomes/all_pangenome_fna

  all_singletons_fna:
    type: File[]
    outputSource: process_one_genome/all_filt_sigletons_fna

  reps_pangenomes_fna:
    type: File[]
    outputSource: process_many_genomes/reps_fna

# ===== gff =======
  pangenome_other_gffs:
    type: File[]
    outputSource: process_many_genomes/other_pangenome_gffs

# ===== gunc =======
  singletons_gunc_completed:
    type: File
    outputSource: process_one_genome/gunc_completed

  singletons_gunc_failed:
    type: File
    outputSource: process_one_genome/gunc_failed

# ===== panaroo ftp =======
  panaroo_folder:
    type: Directory
    outputSource: process_many_genomes/panaroo_output

# ===== mmseqs =======
  mmseq_final_dir:
    type: Directory
    outputSource: mmseqs/mmseqs_dir
  mmseq_cluster_rep_faa:
    type: File
    outputSource: mmseqs/cluster_reps
  mmseq_cluster_tsv:
    type: File
    outputSource: mmseqs/cluster_tsv

steps:

# ----------- << mash trees >> -----------
  process_mash:
    scatter: input_mash
    run: ../tools/mash2nwk/mash2nwk.cwl
    in:
      input_mash: mash_folder
    out: [mash_tree]  # File[]

# ----------- << many genomes cluster processing >> -----------
  process_many_genomes:
    when: $(Boolean(inputs.input_clusters))
    run: process_clusters/pan-genomes/wrapper-pan-genomes.cwl
    in:
      input_clusters: many_genomes
      mash_folder: process_mash/mash_tree
    out:
      - panaroo_output
      - all_pangenome_fna
      - all_pangenome_faa
      - other_pangenome_gffs
      - pangenome_clusters
      - reps_fna

# ----------- << one genome cluster processing >> -----------
  process_one_genome:
    when: $(Boolean(inputs.input_cluster))
    run: process_clusters/singletons/wrapper-singletons.cwl
    in:
      input_cluster: one_genome
      csv: csv
      gunc_db_path: gunc_db_path
    out:
      - singleton_clusters      # File[][]?
      - all_filt_sigletons_fna   # faa[]?
      - all_filt_sigletons_faa  # fna[]?
      - gunc_completed
      - gunc_failed

# ----------- << mmseqs >> -----------
  mmseqs:
    run: mmseq-subwf.cwl
    in:
      prokka_many: process_many_genomes/all_pangenome_faa
      prokka_one: process_one_genome/all_filt_sigletons_faa
      mmseqs_limit_i: mmseqs_limit_i
      mmseqs_limit_c: mmseqs_limit_c
      mmseq_limit_annotation: mmseq_limit_annotation
    out:
      - mmseqs_dir
      - cluster_reps
      - cluster_tsv

