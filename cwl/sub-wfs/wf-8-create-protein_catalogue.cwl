#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
   Subwf to create a protein_catalogue for FTP
   Input:
     protein_catalogue-1.0.tar.gz
     protein_catalogue-0.5.tar.gz
     protein_catalogue-0.95.tar.gz
     mmseqs_0.9_outdir
     IPS.tsv
     eggnog.tsv
   Output:
       protein_catalogue/
         protein_catalogue-1.0.tar.gz
           mmseqs_1.0_outdir/
             mmseqs_cluster*
             mmseqs.*
         protein_catalogue-0.95.tar.gz
           mmseqs_0.95_outdir/
             mmseqs_cluster*
             mmseqs.*
         protein_catalogue-0.5.tar.gz
           mmseqs_0.5_outdir/
             mmseqs_cluster*
             mmseqs.*
         protein_catalogue-0.9.tar.gz
           mmseqs_0.9_outdir/
             protein_catalogue-90_eggNOG.tsv
             protein_catalogue-90_InterProScan.tsv
             mmseqs_cluster*
             mmseqs.*


requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  mmseq_tars: File[]
  mmseq_ann_folder: Directory
  ips: File
  eggnog: File

outputs:
  protein_catalogue_final_folder:
    type: Directory
    outputSource: wrap_to_dir/out

steps:

  rename_ips:
    run: ../utils/move.cwl
    in:
      initial_file: ips
      out_file_name: {default: "protein_catalogue-90_InterProScan.tsv"}
    out: [renamed_file]

  rename_eggnog:
    run: ../utils/move.cwl
    in:
      initial_file: eggnog
      out_file_name: {default: "protein_catalogue-90_eggNOG.tsv"}
    out: [renamed_file]

  add_files_to_annotation_dir:
    run: ../utils/add_files_to_dir.cwl
    in:
      folder: mmseq_ann_folder
      files_to_add:
        - rename_ips/renamed_file
        - rename_eggnog/renamed_file
    out: [ dir ]

  tar_annotation_folder:
    run: ../tar.cwl
    in:
      folder: add_files_to_annotation_dir/dir
      output_name: {default: "protein_catalogue_0.9.tar.gz"}
    out: [folder_tar]

  wrap_to_dir:
    run: ../return_directory.cwl
    in:
      list:
        source:
          - tar_annotation_folder/folder_tar
          - mmseq_tars
        linkMerge: merge_flattened
      dir_name: {default: "protein_catalogue"}
    out: [out]

