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
    outputSource: return_taxcheck_dir/pool_directory

  many_genomes:
    type: Directory[]?
    outputSource: classify_clusters/many_genomes
  one_genome:
    type: Directory[]?
    outputSource: classify_clusters/one_genome
  mash_folder:
    type: File[]?
    outputSource: classify_clusters/mash_folder

steps:
# ----------- << taxcheck >> -----------
  prep_taxcheck:
    run: ../utils/get_files_from_dir.cwl
    in:
      dir: genomes_folder
    out: [files]

  taxcheck:
    run: ../tools/taxcheck/taxcheck.cwl
    scatter: genomes_fasta
    in:
      genomes_fasta: prep_taxcheck/files
      taxcheck_outfolder: { default: 'taxcheck'}
      taxcheck_outname: { default: 'taxcheck'}
    out: [ taxcheck_folder ]

  return_taxcheck_dir:
    run: ../utils/return_dir_of_dir.cwl
    in:
      directory_array: taxcheck/taxcheck_folder
      newname: { default: "taxcheck_output" }
    out: [ pool_directory ]

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

# ----------- << drep >> -----------
  drep:
    run: ../tools/drep/drep.cwl
    in:
      genomes: genomes_folder
      drep_outfolder: { default: 'drep_outfolder' }
      checkm_csv: checkm2csv/csv
    out: [ out_folder, dereplicated_genomes ]

  split_drep:
    run: ../tools/drep/split_drep.cwl
    in:
      genomes_folder: genomes_folder
      drep_folder: drep/out_folder
      split_outfolder: { default: 'split_outfolder' }
    out: [ split_out ]

  classify_clusters:
    run: ../tools/drep/classify_folders.cwl
    in:
      clusters: split_drep/split_out
    out: [many_genomes, one_genome, mash_folder]

# ----------- << GTDB - Tk >> -----------
  gtdbtk:
    run: ../tools/gtdbtk/gtdbtk.cwl
    in:
      drep_folder: drep/dereplicated_genomes
      gtdb_outfolder: { default: 'gtdb-tk_output' }
    out: [ gtdbtk_folder ]