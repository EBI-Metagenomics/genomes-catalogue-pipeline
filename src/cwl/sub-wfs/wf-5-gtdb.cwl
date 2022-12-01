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

  gtdbtk_outdir:
    type: Directory
    outputSource: gtdbtk/gtdbtk_outdir

  metadata:
    type: File
    outputSource: metadata_and_tree/metadata

  phylo_tree:
    type: File
    outputSource: metadata_and_tree/phylo_tree

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
    run: 5_gtdb/gtdbtk.cwl
    in:
      drep_folder: create_folder_reps/out
      gtdb_outfolder: { default: 'gtdb-tk_output' }
      refdata: gtdbtk_data
    out:
      - gtdbtk_outdir
      - taxonomy

  create_all_fna_dir:
    run: ../utils/return_directory.cwl
    in:
      list:
        source:
          - reps_pangenomes_fna
          - other_pangenomes_fna
          - singletons_fna
        linkMerge: merge_flattened
      dir_name: {default: "all_fna"}
    out: [out]

# ----------- << Metadata and phylo.tree >> -----------
  metadata_and_tree:
    run: 5_gtdb/metadata_and_phylo_tree.cwl
    in:
      all_fna_dir: create_all_fna_dir/out
      extra_weights_table: extra_weights_table
      checkm_results_table: checkm_results_table
      rrna_dir: rrna_dir
      naming_table: naming_table
      clusters_split: clusters_split
      gtdb_taxonomy: gtdbtk/taxonomy
      metadata_outname: metadata_outname
      ftp_name_catalogue: ftp_name_catalogue
      ftp_version_catalogue: ftp_version_catalogue
      geo_file: geo_file
      gunc_failed_genomes: gunc_failed_genomes
    out:
      - metadata
      - phylo_tree
