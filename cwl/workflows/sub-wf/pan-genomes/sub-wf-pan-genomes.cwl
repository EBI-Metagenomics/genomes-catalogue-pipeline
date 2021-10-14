#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

doc: |
  Subwf processes one cluster with more than one genome inside
  Steps:
    1) prokka
    2) panaroo
    3) detect core genes
    4) filter mash file
    5) return final folder cluster_NUM
  Output structure:
    cluster
         --- pan-genome
              --- core_genes
              --- mash-file.nwk
              --- pan_genome_reference-fa
              --- gene_presence_absence
         --- genome
              --- faa-s
              --- gff-s

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}

inputs:
  cluster: Directory
  mash_files: File[]

outputs:
  prokka_faa-s:
    type: File[]
    outputSource: prokka/faa

  cluster_folder:
    type: Directory
    outputSource: create_cluster_directory/pool_directory

steps:
  preparation:
    run: ../../../utils/get_files_from_dir.cwl
    in:
      dir: cluster
    out: [files]

  prokka:
    run: ../prokka-subwf.cwl
    scatter: prokka_input
    in:
      prokka_input: preparation/files
      outdirname: {default: prokka_output }
    out:
      - gff
      - faa

  panaroo:
    run: ../../../tools/panaroo/panaroo.cwl
    in:
      gffs: prokka/gff
      panaroo_outfolder: {default: panaroo_output }
      threads: {default: 8 }
    out:
      - pan_genome_reference-fa
      - gene_presence_absence

  get_core_genes:
    run: ../../../tools/genomes-catalog-update/get_core_genes/get_core_genes.cwl
    in:
      input: panaroo/gene_presence_absence
      output_filename: {default: "core_genes.txt"}
    out:
      - core_genes

  get_mash_file:
    doc: |
       Filter mash files by cluster name
       For example: cluster_1_1 should have 1_1.tree.mash inside
                    filtering pattern: "1_1"
    run: ../../../utils/get_file_pattern.cwl
    in:
      list_files: mash_files
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ file_pattern ]

# --------------------------------------- result folders -----------------------------------------
  create_pangenome_folder:
    doc: |
       Add:
         - core_genes
         - mash-file.nwk
         - pan_genome_reference-fa (panaroo)
         - gene_presence_absence (panaroo)
    run: ../../../utils/return_directory.cwl
    in:
      list:
        - get_core_genes/core_genes
        - get_mash_file/file_pattern
        - panaroo/pan_genome_reference-fa
        - panaroo/gene_presence_absence
      dir_name: { default: 'pan-genome'}
    out: [ out ]

  create_genome_folder:
    doc: |
       Add:
         - faa (prokka)
         - gff (prokka)
    run: ../../../utils/return_directory.cwl
    in:
      list:
        source:
          - prokka/faa
          - prokka/gff
        linkMerge: merge_flattened
      dir_name: { default: 'genome'}
    out: [ out ]


  create_cluster_directory:
    run: ../../../utils/return_dir_of_dir.cwl
    in:
      directory_array:
        - create_pangenome_folder/out
        - create_genome_folder/out
      newname:
        source: cluster
        valueFrom: cluster_$(self.basename)
    out: [pool_directory]

