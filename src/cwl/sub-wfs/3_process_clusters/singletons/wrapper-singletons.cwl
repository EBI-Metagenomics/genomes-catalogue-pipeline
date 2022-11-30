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
  input_cluster: Directory[]
  csv: File
  gunc_db_path: File

outputs:

  all_filt_sigletons_faa:
    type: File[]?
    outputSource: filter_nulls_prokka/out_files

  all_filt_sigletons_fna:
    type: File[]?
    outputSource: filter_nulls_fna/out_files

  singleton_clusters:
    type: Directory[]?
    outputSource: filter_null_clusters/out_dirs

  gunc_completed:
    type: File
    outputSource: create_gunc_reports/report_completed
  gunc_failed:
    type: File
    outputSource: create_gunc_reports/report_failed

steps:

  process_one_genome:
    run: sub-wf-singleton.cwl
    scatter: cluster
    in:
      cluster: input_cluster
      csv: csv
      gunc_db_path: gunc_db_path
    out:
      - singleton_cluster  # Dir (faa, fna, gff)?
      - gunc_decision
      - prokka_fna
      - prokka_faa

  create_gunc_reports:
    run: ../../../tools/GUNC/generate_report.cwl
    in:
      input: process_one_genome/gunc_decision
    out:
      - report_completed
      - report_failed

  filter_nulls_prokka:
    run: ../../../utils/filter_nulls.cwl
    in:
      list_files: process_one_genome/prokka_faa
    out: [ out_files ]

  filter_nulls_fna:
    run: ../../../utils/filter_nulls.cwl
    in:
      list_files: process_one_genome/prokka_fna
    out: [ out_files ]

  filter_null_clusters:
    run: ../../../utils/filter_nulls.cwl
    in:
      list_dirs: process_one_genome/singleton_cluster
    out: [ out_dirs ]

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"