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
  mash_folder: File[]?          # for many_genomes
  one_genome: Directory[]?
  mmseqs_limit_c: float         # common
  mmseqs_limit_i: float[]       # common
  mmseq_limit_annotation: float
  csv: File
  gunc_db_path: File

outputs:

  pangenomes:
    type: Directory[]?
    outputSource: process_many_genomes/pangenome_clusters

  singletons:
    type: Directory[]?
    outputSource: process_one_genome/cluster_folder
  singletons_gunc_completed:
    type: File
    outputSource: process_one_genome/gunc_completed
  singletons_gunc_failed:
    type: File
    outputSource: process_one_genome/gunc_failed

  gffs_folder:
    type: Directory
    outputSource: create_folder_gffs/gffs_folder

  mmseqs_output:
    type: Directory?
    outputSource: mmseqs/mmseqs_dir
  cluster_representatives:
    type: File?
    outputSource: mmseqs/cluster_reps

steps:

# ----------- << mash trees >> -----------
  process_mash:
    scatter: input_mash
    run: ../../tools/mash2nwk/mash2nwk.cwl
    in:
      input_mash: mash_folder
    out: [mash_tree]  # File[]

# ----------- << many genomes cluster processing >> -----------
  process_many_genomes:
    when: $(Boolean(inputs.input_clusters))
    run: pan-genomes/wrapper-pan-genomes.cwl
    in:
      input_clusters: many_genomes
      mash_folder: process_mash/mash_tree
    out:
      - prokka_seqs
      - pangenome_clusters
      - prokka_gffs

# ----------- << one genome cluster processing >> -----------
  process_one_genome:
    when: $(Boolean(inputs.input_cluster))
    run: singletons/wrapper-singletons.cwl
    in:
      input_cluster: one_genome
      csv: csv
      gunc_db_path: gunc_db_path
    out:
      - prokka_faa-s
      - prokka_gff-s
      - cluster_folder
      - gunc_completed
      - gunc_failed


# ----------- << gffs folder >> -----------
  create_folder_gffs:
    run: create_gffs_folder.cwl
    in:
      gffs:
        source:
          - process_many_genomes/prokka_gffs
          - process_one_genome/prokka_gff-s
        linkMerge: merge_flattened
      folder_name: { default: 'GFFs'}
    out: [ gffs_folder ]

# ----------- << mmseqs subwf>> -----------

  mmseqs:
    run: mmseq-subwf.cwl
    in:
      prokka_many: process_many_genomes/prokka_seqs
      prokka_one: process_one_genome/prokka_faa-s
      mmseqs_limit_i: mmseqs_limit_i
      mmseqs_limit_c: mmseqs_limit_c
      mmseq_limit_annotation: mmseq_limit_annotation
    out: [ mmseqs_dir, cluster_reps ]

