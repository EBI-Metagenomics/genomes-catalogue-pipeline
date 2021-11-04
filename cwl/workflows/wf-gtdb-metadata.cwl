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
  genomes: Directory
  filter_genomes_drep: Directory
  gtdbtk_data: Directory

  extra_weights_table: File
  checkm_results_table: File
  rrna_dir: Directory
  naming_table: File
  clusters_split: File
  metadata_outname: string
  ftp_name_catalogue: string
  ftp_version_catalogue: string


outputs:

  gtdbtk_tar:
    type: File
    outputSource: tar/folder_tar

  matadata:
    type: File
    outputSource: metadata/metadata_table


steps:
# ----------- << GTDB - Tk >> -----------
  gtdbtk:
    run: ../tools/gtdbtk/gtdbtk.cwl
    in:
      drep_folder: annotation/filter_genomes_drep_filtered_genomes
      gtdb_outfolder: { default: 'gtdb-tk_output' }
      refdata: gtdbtk_data
    out:
      - gtdbtk_folder
      - gtdbtk_bac

  tar:
    run: ../utils/tar.cwl
    in:
      folder: gtdbtk/gtdbtk_folder
    out: [ folder_tar ]

# ----------- << Metadata >> -----------
  metadata:
    run: ../tools/genomes-catalog-update/generate_metadata/create_metadata.cwl
    in:
      input_dir: genomes
      extra_weights: extra_weights_table
      checkm_results: checkm_results_table
      rrna: rrna_dir
      naming_table: naming_table
      clusters_split: clusters_split
      gtdb_taxonomy: gtdbtk/gtdbtk_bac
      outfile_name: metadata_outname
      ftp_name: ftp_name_catalogue
      ftp_version: ftp_version_catalogue
    out: [ metadata_table ]
