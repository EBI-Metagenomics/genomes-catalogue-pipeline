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
  download_from_ena: boolean    # True for ENA,  False otherwise
  download_from_ncbi: boolean   # True for NCBI, False otherwise

  infile: File            # file containing a list of GenBank accessions, one accession per line
  directory_name: string  # directory name to download files to

  unzip: boolean?

outputs:
  downloaded_folder_ena:
    type: Directory?
    outputSource: download_from_ena/downloaded_files

  downloaded_folder_ncbi:
    type: Directory?
    outputSource: download_from_ncbi/downloaded_files

  stats_ena:
    type: File?
    outputSource: download_from_ena/stats_file

  flag_no-data:
    type: File?
    outputSource: touch_flag/created_file

steps:

  download_from_ena:
    run: ../../tools/fetch_data/fetch_ena.cwl
    when: $(Boolean(inputs.type))
    in:
      type: download_from_ena
      infile: infile
      directory: directory_name
      unzip: unzip
    out:
     - downloaded_files
     - stats_file

  download_from_ncbi:
    run: ../../tools/fetch_data/fetch_ncbi.cwl
    when: $(Boolean(inputs.type))
    in:
      type: download_from_ncbi
      infile: infile
      directory: directory_name
      unzip: unzip
    out: [ downloaded_files ]

  touch_flag:
    run: ../../utils/touch_file.cwl
    when: $(!inputs.downloaded_files_ena && !inputs.downloaded_files_ncbi)
    in:
      downloaded_files_ena: download_from_ena/downloaded_files
      downloaded_files_ncbi: download_from_ncbi/downloaded_files
      filename: { default: "no-data" }
    out: [ created_file ]
