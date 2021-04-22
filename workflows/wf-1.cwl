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
    outputSource: checkm2csv/csv
  gtdbtk:
    type: Directory
    outputSource: gtdbtk/gtdbtk_folder
  taxcheck_dir:
    type: Directory
    outputSource: taxcheck/taxcheck_dir

  many_genomes:
    type: Directory[]?
    outputSource: drep/many_genomes
  one_genome:
    type: Directory[]?
    outputSource: drep/one_genome
  mash_folder:
    type: File[]?
    outputSource: drep/mash_folder

steps:

# ----------- << taxcheck subwf >> -----------
  taxcheck:
    run: sub-wf/taxcheck-subwf.cwl
    in:
      genomes_folder: genomes_folder
    out: taxcheck_dir

# ----------- << checkm >> -----------
  checkm:
    run: ../tools/checkm/checkm.cwl
    in:
      input_folder: genomes_folder
      checkm_outfolder: { default: 'checkm_outfolder' }
    out: [ stdout, out_folder ]

  checkm2csv:
    run: ../tools/checkm/checkm2csv.cwl
    in:
      out_checkm: checkm/stdout
    out: [ csv ]

# ----------- << drep subwf >> -----------
  drep:
    run: sub-wf/drep-subwf.cwl
    in:
      genomes_folder: genomes_folder
      checkm_csv: checkm2csv/csv
    out:
      - many_genomes
      - one_genome
      - mash_folder
      - dereplicated_genomes

# ----------- << GTDB - Tk >> -----------
  gtdbtk:
    run: ../tools/gtdbtk/gtdbtk.cwl
    in:
      drep_folder: drep/dereplicated_genomes
      gtdb_outfolder: { default: 'gtdb-tk_output' }
    out: [ gtdbtk_folder ]