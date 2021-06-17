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
  outname: string?
  limit_i: float
  limit_c: float

outputs: []


steps:

  prepare_db:
   run: mmseq_createdb.cwl
   in:
     seq: seq
     db: db
   out: [ created_db, db_file ]

  wrap_db:
    run: ../../utils/return_directory.cwl
    in:
      list: prepare_db/created_db
      dir_name: {default: "db"}
    out: [out]

  annotations:
    run: mmseq-annotations.cwl
    in:
      input_fasta: seq
      limit_i: limit_i
      limit_c: limit_c
      db: wrap_db/out
      db_name: db
    out: [ outdir ]





