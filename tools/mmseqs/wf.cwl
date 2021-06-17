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
  seq: File
  db: string
  limit_i: float
  limit_c: float

outputs: []

steps:

  create_db:
    run: try/mmseq_createdb.cwl
    in:
      seq: seq
      db: db
    out:
      - created_db
      - db_file
      - db_file_index
      - db_file_dbtype

  step:
    run: mmseqs-subwf.cwl
    in:
      input_fasta: seq
      limit_i: limit_i
      limit_c: limit_c
      db: db_file



