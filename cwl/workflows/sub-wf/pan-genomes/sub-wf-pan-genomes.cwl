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
              --- fa
              --- fa.fai

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
  prokka_gff-s:
    type: File[]
    outputSource: prokka/gff
  cluster_folder:
    type: Directory
    outputSource: create_cluster_directory/pool_directory
  panaroo_tar:
    type: File
    outputSource: tar_gz_panaroo_folder/folder_tar
  initial_genomes_fa:
    type: File[]
    outputSource: preparation/files
  main_rep_gff:
    type: File
    outputSource: choose_main_rep_gff/file_pattern
  main_rep_faa:
    type: File
    outputSource: choose_main_rep_faa/file_pattern

  # for json
  core_genes:
    type: File
    outputSource: get_core_genes/core_genes
  pangenome_fna:
    type: File
    outputSource: rename_panaroo_fna/renamed_file


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
      panaroo_outfolder:
        source: cluster
        valueFrom: $(self.basename)_panaroo
      threads: {default: 8 }
    out:
      - pan_genome_reference-fa
      - gene_presence_absence
      - panaroo_dir

  get_core_genes:
    run: ../../../tools/genomes-catalog-update/get_core_genes/get_core_genes.cwl
    in:
      input: panaroo/gene_presence_absence
      output_filename:
        source: cluster
        valueFrom: "$(self.basename).core_genes.txt"
    out:
      - core_genes

  rename_panaroo_fna:
    run: ../../../utils/move.cwl
    in:
      initial_file: panaroo/pan_genome_reference-fa
      out_file_name:
        source: cluster
        valueFrom: "$(self.basename).pan-genome.fna"
    out: [ renamed_file ]

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
# ------------------------ pan-genome folder
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
        - rename_panaroo_fna/renamed_file
        - panaroo/gene_presence_absence
      dir_name: { default: 'pan-genome'}
    out: [ out ]

# ------------------------ genome folder
  choose_main_rep_gff:
    run: ../../../utils/get_file_pattern.cwl
    in:
      list_files: prokka/gff
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ file_pattern ]

  choose_main_rep_faa:
    run: ../../../utils/get_file_pattern.cwl
    in:
      list_files: prokka/faa
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ file_pattern ]

  choose_main_rep_fa:
    run: ../../../utils/get_file_pattern.cwl
    in:
      list_files: preparation/files
      pattern:
        source: cluster
        valueFrom: $(self.basename)
    out: [ file_pattern ]

  index_fasta:
    run: ../../../tools/index_fasta/index_fasta.cwl
    in:
      fasta: choose_main_rep_fa/file_pattern
    out: [ fasta_index ]

  create_genome_folder:
    doc: |
       Add:
         - faa (prokka)
         - gff (prokka)
         - fa
         - fa.fai
    run: ../../../utils/return_directory.cwl
    in:
      list:
        - choose_main_rep_gff/file_pattern
        - choose_main_rep_faa/file_pattern
        - choose_main_rep_fa/file_pattern
        - index_fasta/fasta_index
      dir_name: { default: 'genome'}
    out: [ out ]

# ------------------------ cluster folder
  create_cluster_directory:
    run: ../../../utils/return_dir_of_dir.cwl
    in:
      directory_array:
        - create_pangenome_folder/out
        - create_genome_folder/out
      newname:
        source: cluster
        valueFrom: $(self.basename)
    out: [pool_directory]

  tar_gz_panaroo_folder:
    run: ../../../utils/tar.cwl
    in:
      folder: panaroo/panaroo_dir
    out: [ folder_tar ]
