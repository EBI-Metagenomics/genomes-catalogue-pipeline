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
  genomes_folder: Directory
  type_download: string?
  ena_csv:
    type:
      - 'null'
      - File

outputs:
  ncbi_csv:
    type: File?
    outputSource: checkm_subwf/checkm_csv

  many_genomes:
    type: Directory[]?
    outputSource: drep_subwf/many_genomes
  one_genome:
    type: Directory[]?
    outputSource: drep_subwf/one_genome
  mash_folder:
    type: File[]?
    outputSource: drep_subwf/mash_folder
  dereplicated_genomes:
    type: Directory
    outputSource: drep_subwf/dereplicated_genomes


steps:

# ----------- << drep subwf >> -----------
  drep_subwf:
    run: sub-wf/drep-subwf.cwl
    in:
      genomes_folder: genomes_folder
      input_csv:
        source:
          - checkm_subwf/checkm_csv
          - ena_csv
        pickValue: first_non_null
    out:
      - many_genomes
      - one_genome
      - mash_folder
      - dereplicated_genomes

