#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  Subwf processes one cluster with more than one genome inside
  Steps:
    1) prokka
    2) panaroo
    3) detect core genes
    4) filter mash file
    5) return final folder cluster_NUM
  Output structure:
    cluster_NUM
    ---- core_genes
    ---- mash-file
    ---- genomes
    -------- MGYG..1.fa
    -------- MGYG..M.fa
    ---- prokka
    -------- < files >
    ---- panaroo
    -------- < files >

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  cluster: Directory
  mash_files: File[]

outputs:
  prokka_faa-s:
    type: File[]
    outputSource: prokka/faa

  cluster_folder:
    type: Directory
    outputSource: create_cluster_folder/out
  panaroo_folder:
    type: Directory
    outputSource: return_panaroo_cluster_dir/pool_directory
  prokka_folder:
    type: Directory[]
    outputSource: return_prokka_cluster_dir/dir_of_dir
  genomes_folder:
    type: Directory
    outputSource: return_cluster_genomes/dir_of_dir


steps:
  preparation:
    run: ../../../utils/get_files_from_dir.cwl
    in:
      dir: cluster
    out: [files]

  prokka:
    run: ../prokka-subwf.cwl
    scatter: prokka_input
    in:
      prokka_input: preparation/files
      outdirname: {default: prokka_output }
    out: [ gff, faa, outdir ]

  panaroo:
    run: ../../../tools/panaroo/panaroo.cwl
    in:
      gffs: prokka/gff
      panaroo_outfolder: {default: panaroo_output }
      threads: {default: 8 }
    out: [ pan_genome_reference-fa, panaroo_dir, gene_presence_absence ]

  get_core_genes:
    run: ../../../tools/genomes-catalog-update/get_core_genes/get_core_genes.cwl
    in:
      input: panaroo/gene_presence_absence
      output_filename: {default: "core_genes.txt"}
    out: [ core_genes ]

# --------------------------------------- result folder -----------------------------------------

  get_mash_file:
    doc: |
       Filter mash files by cluster name
       For example: cluster_1_1 should have 1_1.tree.mash inside
                    filtering pattern: "1_1"
    run: ../../../utils/get_file_pattern.cwl
    in:
      list_files: mash_files
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ file_pattern ]

  create_cluster_folder:
    doc: |
       Add core_genes file to cluster_NUM
       Add filtered mash-file to cluster_NUM
    run: ../../../utils/return_directory.cwl
    in:
      list:
        - get_core_genes/core_genes
        - get_mash_file/file_pattern
      dir_name:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ out ]

# ----- cluster_NUM/genomes -------
  create_cluster_genomes:
    doc: |
       Add genomes to folder "genomes"
    run: ../../../utils/return_directory.cwl
    in:
      list: preparation/files
      dir_name: { default: "genomes" }
    out: [ out ]

  return_cluster_genomes:
    doc: |
       Add "genomes" folder to final cluster_NUM folder
    run: ../../../utils/return_dir_of_dir.cwl
    in:
      directory: create_cluster_genomes/out
      newname:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ dir_of_dir ]

# ----- cluster_NUM/prokka -------
  return_prokka_cluster_dir:
    run: ../../../utils/return_dir_of_dir.cwl
    scatter: directory
    in:
      directory: prokka/outdir
      newname:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ dir_of_dir ]

# ----- cluster_NUM/panaroo -------
  return_panaroo_cluster_dir:
    run: ../../../utils/return_dir_of_dir.cwl
    in:
      directory_array:
        linkMerge: merge_nested
        source:
          - panaroo/panaroo_dir
      newname:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ pool_directory ]

