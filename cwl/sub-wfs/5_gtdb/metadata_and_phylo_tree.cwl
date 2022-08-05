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
  gtdb_taxonomy: File

outputs:

  metadata:
    type: File
    outputSource: metadata/metadata_table

  phylo_tree:
    type: File
    outputSource: phylo_json/phylo_tree_json

steps:

# ----------- << Metadata >> -----------
  metadata:
    run: ../../tools/genomes-catalog-update/generate_metadata/create_metadata.cwl
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
      gtdb_taxonomy: gtdb_taxonomy
      outfile_name: metadata_outname
      ftp_name: ftp_name_catalogue
      ftp_version: ftp_version_catalogue
      geo: geo_file
      gunc_failed: gunc_failed_genomes
    out: [ metadata_table ]

# ----------- << phylo_json >> -----------
  phylo_json:
    run: ../../tools/post-processing/generate_phylo_json/phylo_json.cwl
    in:
      table: gtdb_taxonomy
      outname: { default: "phylo_tree.json" }
    out: [phylo_tree_json]