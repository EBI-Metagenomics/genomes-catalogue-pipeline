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
  many_genomes: Directory[]?
  mash_folder: File[]?          # for many_genomes
  one_genome: Directory[]?
  mmseqs_limit_c: float         # common
  mmseqs_limit_i: float[]       # common

outputs:
  mash_folder:
    type: Directory?
    outputSource: process_many_genomes/mash_folder

  many_genomes:
    type: Directory[]?
    outputSource: process_many_genomes/cluster_folder
  many_genomes_roary:
    type: Directory[]?
    outputSource: process_many_genomes/roary_folder
  many_genomes_prokka:
    type:
      type: array?
      items:
        type: array
        items: Directory
    outputSource: process_many_genomes/prokka_folder
  many_genomes_genomes:
    type: Directory[]?
    outputSource: process_many_genomes/genomes_folder

  one_genome:
    type: Directory[]?
    outputSource: process_one_genome/cluster_folder
  one_genome_prokka:
    type: Directory[]?
    outputSource: process_one_genome/cluster_folder_prokka
  one_genome_genomes:
    type: Directory[]?
    outputSource: process_one_genome/cluster_folder_genome

  mmseqs:
    type: Directory
    outputSource: return_mmseq_dir/pool_directory

steps:

# ----------- << many genomes cluster processing >> -----------
  process_many_genomes:
    when: $(inputs.cluster)
    run: sub-wf/sub-wf-many-genomes.cwl
    scatter: cluster
    in:
      cluster: many_genomes
      mash_files: mash_folder
    out:
      - prokka_faa-s
      - cluster_folder
      - roary_folder
      - prokka_folder
      - genomes_folder
      - mash_folder

# ----------- << one genome cluster processing >> -----------
  process_one_genome:
    when: $(inputs.cluster)
    run: sub-wf/sub-wf-one-genome.cwl
    scatter: cluster
    in:
      cluster: one_genome
    out:
      - prokka_faa-s
      - cluster_folder
      - cluster_folder_prokka
      - cluster_folder_genome


# ----------- << mmseqs >> -----------

  flatten_many:
   when: $(inputs.many_genomes)
   run: ../utils/flatten_array.cwl
   in:
     many_input: many_genomes
     arrayTwoDim: process_many_genomes/prokka_faa-s
   out: [array1d]

  concatenate:
    run: ../utils/concatenate.cwl
    in:
      files:
        source:
          - flatten_many/array1d
          - process_one_genome/prokka_faa-s
        linkMerge: merge_flattened
        pickValue: all_non_null
      outputFileName: { default: 'prokka_cat.fa' }
    out: [ result ]

  mmseqs:
    run: ../tools/mmseqs/mmseqs.cwl
    scatter: limit_i
    in:
      input_fasta: concatenate/result
      limit_i: mmseqs_limit_i
      limit_c: mmseqs_limit_c
    out: [ outdir ]

  return_mmseq_dir:
    run: ../utils/return_dir_of_dir.cwl
    in:
      directory_array: mmseqs/outdir
      newname: { default: "mmseqs_output" }
    out: [ pool_directory ]
