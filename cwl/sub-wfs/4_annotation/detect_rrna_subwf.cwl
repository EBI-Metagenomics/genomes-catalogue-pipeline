#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
   Subwf runs detection of rRNA using cmsearch (and cmseach models)
   It creates folders with results for each input fasta-file
   Output files: .out and .fasta
   Final step wraps all out-folders to one folder and the same for fastas
   Example of output:
   --- rRNA_fastas
      ----- MGYG...1_fasta-results
      ------------ ...fasta
      ------------ tRNA.fasta
      ----- MGYG...M_fasta-results
   --- rRNA_outs
      ----- MGYG...1_out-results
      ------------ ...out
      ------------ tRNA.out
      ----- MGYG...M_out-results


requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  filtered_genomes: File[]?
  filtered_genomes_folder: Directory?
  cm_models: Directory

outputs:
  rrna_outs:
    type: Directory
    outputSource: wrap_outs/pool_directory

  rrna_fastas:
    type: Directory
    outputSource: wrap_fastas/pool_directory

steps:

  get_files:
    when: $(Boolean(inputs.dir))
    run: ../../utils/get_files_from_dir.cwl
    in:
      dir: filtered_genomes_folder
    out: [files]

  detect:
    run: ../../tools/detect_rRNA/detect_rRna.cwl
    scatter: fasta
    in:
      fasta:
        source:
          - filtered_genomes
          - get_files/files
        pickValue: first_non_null
      cm_models: cm_models
    out: [out_counts, fasta_seq]

  wrap_outs:
    run: ../../utils/return_dir_of_dir.cwl
    in:
      directory_array: detect/out_counts
      newname: {default: "rRNA_outs"}
    out: [pool_directory]

  wrap_fastas:
    run: ../../utils/return_dir_of_dir.cwl
    in:
      directory_array: detect/fasta_seq
      newname: {default: "rRNA_fastas"}
    out: [pool_directory]