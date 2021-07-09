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

  # no gtdbtk
  skip_gtdbtk_step: string

  # common input
  mmseqs_limit_c: float
  mmseqs_limit_i: float[]

  gunc_db_path: File


outputs:
  output_csv:
    type: File?
    outputSource:
      - download/stats_ena
      - checkm_subwf/checkm_csv
    pickValue: first_non_null

  flag_no_data:
    type: File?
    outputSource: download/flag_no-data



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
      - downloaded_folder_ena
      - downloaded_folder_ncbi
      - stats_ena
      - flag_no-data

# ----------- << checkm for NCBI>> -----------
  checkm_subwf:
    run: sub-wf/checkm-subwf.cwl
    when: $(inputs.type == 'NCBI' and !inputs.flag)
    in:
      type: download_from
      flag: download/flag_no-data
      genomes_folder: download/downloaded_folder_ncbi
    out:
      - checkm_csv