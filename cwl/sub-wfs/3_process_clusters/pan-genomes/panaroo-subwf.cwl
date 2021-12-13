#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}

inputs:
  prokka_gffs: File[]
  panaroo_folder_name: string
  panaroo_fna_name: string

outputs:
  gene_presence_absence:
    type: File
    outputSource: panaroo/gene_presence_absence
  panaroo_fna:
    type: File
    outputSource: rename_panaroo_fna/renamed_file
  panaroo_dir:
    type: Directory
    outputSource: panaroo/panaroo_dir

steps:

  panaroo:
    run: ../../../tools/panaroo/panaroo.cwl
    in:
      gffs: prokka_gffs
      panaroo_outfolder: panaroo_folder_name
      threads: {default: 8 }
    out:
      - pan_genome_reference-fa
      - gene_presence_absence
      - panaroo_dir

  rename_panaroo_fna:
    run: ../../../utils/move.cwl
    in:
      initial_file: panaroo/pan_genome_reference-fa
      out_file_name: panaroo_fna_name
    out: [ renamed_file ]

  #tar_gz_panaroo_folder:
  #  run: ../../../utils/tar.cwl
  #  in:
  #    folder: panaroo/panaroo_dir
  #  out: [ folder_tar ]