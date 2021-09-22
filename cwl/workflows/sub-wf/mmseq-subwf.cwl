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
  prokka_many:
    type:
      - 'null'
      - type: array
        items:
          type: array
          items: File
  prokka_one:
    type:
      - 'null'
      - type: array
        items: File

  mmseqs_limit_c: float
  mmseqs_limit_i: float[]
  mmseq_limit_annotation: float

outputs:

  mmseqs_dir:
    type: Directory?
    outputSource: return_mmseq_dir/pool_directory
  mmseqs_dir_annotation:
    type: Directory?
    outputSource: add_mmseq/dir_of_dir
  cluster_reps:
    type: File?
    outputSource: mmseqs_annotations/faa


steps:

  flatten_many:
   doc: |
      Firstly, make prokka output from many_genomes_sub_wf ([File[], File[]])
      as one dimensional array (File[])
      if only many_genomes clusters were detected
   when: $(Boolean(inputs.arrayTwoDim))
   run: ../../utils/flatten_array.cwl
   in:
     arrayTwoDim: prokka_many
   out: [array1d]

  filter_nulls:
    doc: |
       Remove all nulls from concatenate input.
       Prokka one_genome could be empty as well as prokka from many_genomes
       In case of all empty prokkas - tool returns null
       Otherwise it will return prokka files
    run: ../../utils/filter_nulls.cwl
    in:
      list_files:
        source:
          - flatten_many/array1d
          - prokka_one
        linkMerge: merge_flattened
    out: [out_files]

  concatenate:
    doc: |
       Concatenate all non-null prokka files
       If all files are empty - this step would be skipped
       together with the following steps
    when: $(Boolean(inputs.files))
    run: ../../utils/concatenate.cwl
    in:
      files: filter_nulls/out_files
      outputFileName: { default: 'prokka_cat.fa' }
    out: [ result ]

# ------ mmseq --------
  mmseqs:
    when: $(Boolean(inputs.files))
    run: ../../tools/mmseqs/mmseqs.cwl
    scatter: limit_i
    in:
      files: filter_nulls/out_files
      input_fasta: concatenate/result
      limit_i: mmseqs_limit_i
      limit_c: mmseqs_limit_c
    out: [ outdir ]

  return_mmseq_dir:
    when: $(Boolean(inputs.files))
    run: ../../utils/return_dir_of_dir.cwl
    in:
      files: filter_nulls/out_files
      directory_array: mmseqs/outdir
      newname: { default: "mmseqs_output" }
    out: [ pool_directory ]

# ------ mmseq for functional annotation ------

  mmseqs_annotations:
    doc: |
       Expected limit_i = 0.9
       This additional step could be part of previous scatter
       But we need results from this folder for functional annotation
       It would be difficult to detect this folder from scatter output
       That is why this step was made separate in order to have results
    when: $(Boolean(inputs.files))
    run: ../../tools/mmseqs/mmseqs.cwl
    in:
      files: filter_nulls/out_files
      input_fasta: concatenate/result
      limit_i: mmseq_limit_annotation
      limit_c: mmseqs_limit_c
    out: [ outdir, faa ]

  add_mmseq:
    doc: |
       This step adds additional "annotation folder"
       to common output folder of mmseq
    when: $(Boolean(inputs.files))
    run: ../../utils/return_dir_of_dir.cwl
    in:
      files: filter_nulls/out_files
      directory: mmseqs_annotations/outdir
      newname: { default: "mmseqs_output" }
    out: [ dir_of_dir ]