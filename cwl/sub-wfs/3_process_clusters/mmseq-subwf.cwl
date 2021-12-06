#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  Input:
    pangenome.prokka.faa [][]
    singleton.prokka.faa []
    mmseqs params
  Steps: concatenate faa-s -> mmseqs -> process folders

  Output:


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

  mmseqs_dirs:
    type: File[]?
    outputSource: create_tars/folder_tar
  mmseqs_annotation_dir:
    type: Directory?
    outputSource: mmseqs_annotations/outdir

  cluster_reps:
    type: File?
    outputSource: mmseqs_annotations/faa
  cluster_tsv:
    type: File?
    outputSource: mmseqs_annotations/mmseq_cluster_tsv

steps:

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
          - prokka_many
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

# ----- tar.gz mmseqs folders -----

  create_tars:
    run: ../../utils/tar.cwl
    when: $(Boolean(inputs.folder))
    scatter: folder
    in:
      folder: mmseqs/outdir              # Dir[]
    out: [ folder_tar ]

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
    out:
      - outdir
      - faa
      - mmseq_cluster_tsv

