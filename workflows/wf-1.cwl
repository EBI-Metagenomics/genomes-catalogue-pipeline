#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  genomes_folder: Directory

outputs:

  checkm_csv:
    type: File
    outputSource: checkm_subwf/checkm_csv
  taxcheck_dir:
    type: Directory
    outputSource: taxcheck_subwf/taxcheck_dir

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

# ----------- << taxcheck subwf >> -----------
  taxcheck_subwf:
    run: sub-wf/taxcheck-subwf.cwl
    in:
      genomes_folder: genomes_folder
    out:
      - taxcheck_dir

# ----------- << checkm >> -----------
  checkm_subwf:
    run: sub-wf/checkm-subwf.cwl
    in:
      genomes_folder: genomes_folder

    out:
      - checkm_csv

# ----------- << drep subwf >> -----------
  drep_subwf:
    run: sub-wf/drep-subwf.cwl
    in:
      genomes_folder: genomes_folder
      checkm_csv: checkm_subwf/checkm_csv
    out:
      - many_genomes
      - one_genome
      - mash_folder
      - dereplicated_genomes

