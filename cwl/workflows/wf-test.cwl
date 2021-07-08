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
  # download params
  download_from: string?  # ENA or NCBI
  infile: File?            # file containing a list of GenBank accessions, one accession per line
  directory_name: string?  # directory name to download files to
  unzip: boolean?

  # no download
  genomes: Directory?
  csv: File?

  # common input
  mmseqs_limit_c: float
  mmseqs_limit_i: float[]


outputs:
  output_csv:
    type: File?
    outputSource: download/stats_download

  genomes:
    type: Directory
    outputSource: download/downloaded_folder

steps:
# ----------- << download data >> -----------
  download:
    when: $(Boolean(inputs.download_from))
    run: sub-wf/fetch_data.cwl
    in:
      download_from: download_from
      infile: infile
      directory_name: directory_name
      unzip: unzip
    out:
      - downloaded_folder
      - stats_download
      - flag_no-data
