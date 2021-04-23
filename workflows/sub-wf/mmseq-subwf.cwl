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
  prokka_many:
    type:
      - 'null'
      - type: array
          items:
            type: array
            items: File
  prokka_one: File[]?

  mmseqs_limit_c: float
  mmseqs_limit_i: float[]

outputs:

  mmseqs_dir:
    type: Directory
    outputSource: return_mmseq_dir/pool_directory

steps:

  flatten_many:
   when: $(inputs.arrayTwoDim !== undefined)
   run: ../../utils/flatten_array.cwl
   in:
     arrayTwoDim: prokka_many
   out: [array1d]

  concatenate:
    run: ../../utils/concatenate.cwl
    in:
      files:
        source:
          - flatten_many/array1d
          - prokka_one
        linkMerge: merge_flattened
        pickValue: all_non_null
      outputFileName: { default: 'prokka_cat.fa' }
    out: [ result ]

  mmseqs:
    run: ../../tools/mmseqs/mmseqs.cwl
    scatter: limit_i
    in:
      input_fasta: concatenate/result
      limit_i: mmseqs_limit_i
      limit_c: mmseqs_limit_c
    out: [ outdir ]

  return_mmseq_dir:
    run: ../../utils/return_dir_of_dir.cwl
    in:
      directory_array: mmseqs/outdir
      newname: { default: "mmseqs_output" }
    out: [ pool_directory ]
