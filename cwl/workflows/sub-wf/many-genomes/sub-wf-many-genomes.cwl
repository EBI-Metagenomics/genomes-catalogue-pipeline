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
    outputSource: create_cluster_genomes/out

  mash_folder:
    type: Directory
    outputSource: return_mash_dir/out


steps:
  preparation:
    run: ../../../utils/get_files_from_dir.cwl
    in:
      dir: cluster
    out: [files]

  prokka:
    run: ../../../tools/prokka/prokka.cwl
    scatter: fa_file
    in:
      fa_file: preparation/files
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
    run: ../../../tools/get_core_genes/get_core_genes.cwl
    in:
      input: panaroo/gene_presence_absence
      output_filename: {default: "core_genes.txt"}
    out: [ core_genes ]

# --------------------------------------- result folder -----------------------------------------

  get_mash_file:
    run: ../../../utils/get_file_pattern.cwl
    in:
      list_files: mash_files
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ file_pattern ]

  create_cluster_folder:
    run: ../../../utils/return_directory.cwl
    in:
      list:
        - get_core_genes/core_genes
        - get_mash_file/file_pattern
      dir_name:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ out ]

  create_cluster_genomes:
    run: ../../../utils/return_directory.cwl
    in:
      list: preparation/files
      dir_name:
        source: cluster
        valueFrom: cluster_$(self.basename)/genomes
    out: [ out ]

  return_prokka_cluster_dir:
    run: ../../../utils/return_dir_of_dir.cwl
    scatter: directory
    in:
      directory: prokka/outdir
      newname:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [ dir_of_dir ]

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

# ----------- << mash trees >> -----------
  process_mash:
    scatter: input_mash
    run: ../../../tools/mash2nwk/mash2nwk.cwl
    in:
      input_mash: mash_files
    out: [mash_tree]

  return_mash_dir:
    run: ../../../utils/return_directory.cwl
    in:
      list: process_mash/mash_tree
      dir_name: { default: 'mash_trees' }
    out: [ out ]