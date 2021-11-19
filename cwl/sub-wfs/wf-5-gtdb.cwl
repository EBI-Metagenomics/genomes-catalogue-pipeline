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
  reps_pangenomes_fna: File[]
  other_pangenomes_fna: File[]
  singletons_fna: File[]
  gtdbtk_data: Directory

  extra_weights_table: File
  checkm_results_table: File
  rrna_dir: Directory
  naming_table: File
  clusters_split: File
  metadata_outname: string
  ftp_name_catalogue: string
  ftp_version_catalogue: string
  geo_file: File
  gunc_failed_genomes: File

outputs:

  gtdbtk_tar:
    type: File
    outputSource: tar/folder_tar

  metadata:
    type: File
    outputSource: metadata/metadata_table

  phylo_tree:
    type: File
    outputSource: phylo_json/phylo_tree_json

steps:
# ----------- << GTDB - Tk >> -----------

  create_folder_reps:
    run: ../utils/return_directory.cwl
    in:
      list:
        source:
          - reps_pangenomes_fna
          - singletons_fna
        linkMerge: merge_flattened
      dir_name: {default: 'reps_fna'}
    out: [out]

  gtdbtk:
    run: ../tools/gtdbtk/gtdbtk.cwl
    in:
      drep_folder: create_folder_reps/out
      gtdb_outfolder: { default: 'gtdb-tk_output' }
      refdata: gtdbtk_data
    out:
      - gtdbtk_folder
      - gtdbtk_bac
      - gtdbtk_arc

  cat_tables:
    when: $(Boolean(inputs.file1) || Boolean(inputs.file2))
    run: ../utils/concatenate.cwl
    in:
      file1: gtdbtk/gtdbtk_bac
      file2: gtdbtk/gtdbtk_arc
      files:
        source:
          - gtdbtk/gtdbtk_bac
          - gtdbtk/gtdbtk_arc
        pickValue: all_non_null
      outputFileName: {default: "gtdbtk.summary.tsv" }
    out: [result]

  tar:
    run: ../utils/tar.cwl
    in:
      folder: gtdbtk/gtdbtk_folder
    out: [ folder_tar ]

# ----------- << Metadata >> -----------
  metadata:
    run: ../tools/genomes-catalog-update/generate_metadata/create_metadata.cwl
    in:
      input_dir:
        source:
          - reps_pangenomes_fna
          - other_pangenomes_fna
          - singletons_fna
        linkMerge: merge_flattened
      extra_weights: extra_weights_table
      checkm_results: checkm_results_table
      rrna: rrna_dir
      naming_table: naming_table
      clusters_split: clusters_split
      gtdb_taxonomy:
        source:
          - cat_tables/result
          - gtdbtk/gtdbtk_bac
          - gtdbtk/gtdbtk_arc
        pickValue: first_non_null
      outfile_name: metadata_outname
      ftp_name: ftp_name_catalogue
      ftp_version: ftp_version_catalogue
      geo: geo_file
      gunc_failed: gunc_failed_genomes
    out: [ metadata_table ]

# ----------- << phylo_json >> -----------
  phylo_json:
    run: ../tools/generate_phylo_json/phylo_json.cwl
    in:
      table:
        source:
          - cat_tables/result
          - gtdbtk/gtdbtk_bac
          - gtdbtk/gtdbtk_arc
        pickValue: first_non_null
      outname: { default: "phylo_tree.json" }
    out: [phylo_tree_json]