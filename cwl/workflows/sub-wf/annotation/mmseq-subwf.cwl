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
    outputSource: create_mmseqs_dir/out

  cluster_reps:
    type: File?
    outputSource: mmseqs_annotations/faa
  cluster_tsv:
    type: File?
    outputSource: mmseqs_annotations/mmseq_cluster_tsv

steps:

  flatten_many:
   doc: |
      Firstly, make prokka output from many_genomes_sub_wf ([File[], File[]])
      as one dimensional array (File[])
      if only many_genomes clusters were detected
   when: $(Boolean(inputs.arrayTwoDim))
   run: ../../../utils/flatten_array.cwl
   in:
     arrayTwoDim: prokka_many
   out: [array1d]

  filter_nulls:
    doc: |
       Remove all nulls from concatenate input.
       Prokka one_genome could be empty as well as prokka from many_genomes
       In case of all empty prokkas - tool returns null
       Otherwise it will return prokka files
    run: ../../../utils/filter_nulls.cwl
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
    run: ../../../utils/concatenate.cwl
    in:
      files: filter_nulls/out_files
      outputFileName: { default: 'prokka_cat.fa' }
    out: [ result ]

# ------ mmseq --------
  mmseqs:
    when: $(Boolean(inputs.files))
    run: ../../../tools/mmseqs/mmseqs.cwl
    scatter: limit_i
    in:
      files: filter_nulls/out_files
      input_fasta: concatenate/result
      limit_i: mmseqs_limit_i
      limit_c: mmseqs_limit_c
    out: [ outdir ]

# ------ mmseq for functional annotation ------

  mmseqs_annotations:
    doc: |
       Expected limit_i = 0.9
       This additional step could be part of previous scatter
       But we need results from this folder for functional annotation
       It would be difficult to detect this folder from scatter output
       That is why this step was made separate in order to have results
    when: $(Boolean(inputs.files))
    run: ../../../tools/mmseqs/mmseqs.cwl
    in:
      files: filter_nulls/out_files
      input_fasta: concatenate/result
      limit_i: mmseq_limit_annotation
      limit_c: mmseqs_limit_c
    out:
      - outdir
      - faa
      - mmseq_cluster_tsv


# ----- tar.gz all mmseqs folders -----
  create_tars:
    run: ../../../utils/tar.cwl
    when: $(Boolean(inputs.folder))
    scatter: folder
    in:
      folder:
        source:
          - mmseqs_annotations/outdir  # Dir
          - mmseqs/outdir              # Dir[]
        linkMerge: merge_flattened
    out: [ folder_tar ]

  create_mmseqs_dir:
    when: $(Boolean(inputs.list))
    run: ../../../utils/return_directory.cwl
    in:
      list:
        source: create_tars/folder_tar
        pickValue: all_non_null
      dir_name: { default: "mmseqs_output" }
    out: [ out ]