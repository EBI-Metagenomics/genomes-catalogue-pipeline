#!/usr/bin/env cwl-runner
cwlVersion: v1.2.0-dev2
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  download_from: string   # ENA or NCBI
  infile: File            # file containing a list of GenBank accessions, one accession per line
  directory_name: string  # directory name to download files to
  unzip: boolean?

outputs:
  downloaded_folder:
    type: Directory
    outputSource:
      - download_from_ena/downloaded_files
      - download_from_ncbi/downloaded_files
    pickValue: first_non_null
  stats_download_ena:
    type: File?
    outputSource: download_from_ena/stats_file

steps:
  download_from_ena:
    run: ../../tools/fetch_data/fetch_ena.cwl
    when: $(inputs.type == 'ENA')
    in:
      type: download_from
      infile: infile
      directory: directory_name
      unzip: unzip
    out:
     - downloaded_files
     - stats_file

  download_from_ncbi:
    run: ../../tools/fetch_data/fetch_ena.cwl
    when: $(inputs.type == 'NCBI')
    in:
      type: download_from
      infile: infile
      directory: directory_name
      unzip: unzip
    out: [ downloaded_files ]