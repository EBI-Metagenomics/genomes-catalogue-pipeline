#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
   - checkM (for NCBI) + generate csv
   - unite ENA and NCBI genenomes into one folder and cat csv-s (skip if only one presented)
   - assign MGYGs to genomes


requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  genomes_ena: Directory?
  ena_csv: File?
  genomes_ncbi: Directory?

  max_accession_mgyg: int
  min_accession_mgyg: int

outputs:
  unite_folders_csv:
    type: File
    outputSource: unite_folders/csv
  assign_mgygs_renamed_genomes:
    type: Directory
    outputSource: assign_mgygs/renamed_genomes
  assign_mgygs_renamed_csv:
    type: File
    outputSource: assign_mgygs/renamed_csv
  assign_mgygs_naming_table:
    type: File
    outputSource: assign_mgygs/naming_table

steps:

# ----------- << checkm for NCBI >> -----------
  checkm_subwf:
    run: sub-wf/checkm-subwf.cwl
    when: $(Boolean(inputs.genomes_folder))
    in:
      genomes_folder: genomes_ncbi
    out:
      - checkm_csv

# ----------- << unite NCBI and ENA >> -----------
  unite_folders:
    run: ../tools/unite_ena_ncbi/unite.cwl
    when: $(Boolean(inputs.ncbi_folder) && Boolean(inputs.ena_folder))
    in:
      ena_folder: genomes_ena
      ncbi_folder: genomes_ncbi
      ena_csv: ena_csv
      ncbi_csv: checkm_subwf/checkm_csv
      outputname: { default: "genomes"}
    out:
      - genomes
      - csv

# ----------- << assign MGYGs >> -----------
  assign_mgygs:
    run: ../tools/genomes-catalog-update/rename_fasta/rename_fasta.cwl
    in:
      genomes:
        source:
          - unite_folders/genomes
          - genomes_ena
          - genomes_ncbi
        pickValue: first_non_null
      prefix: { default: "MGYG"}
      start_number: min_accession_mgyg
      max_number: max_accession_mgyg
      output_filename: { default: "names.tsv"}
      output_dirname: { default: "mgyg_genomes" }
      csv:
        source:
          - unite_folders/csv
          - ena_csv
          - checkm_subwf/checkm_csv
        pickValue: first_non_null
    out:
      - naming_table
      - renamed_genomes
      - renamed_csv
