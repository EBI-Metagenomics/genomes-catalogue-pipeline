#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "split drep"

doc: |
    "
    This script does detection and separation of genomes into clusters according drep results.
    Script generates clusters_split.txt file with information about each cluster:
        ex:
            many_genomes:1_1:CAJJTO01.fa,CAJKGB01.fa,CAJLGA01.fa
            many_genomes:2_1:CAJKRE01.fa,CAJKXJ01.fa
            one_genome:3_0:CAJKRY01.fa
            one_genome:4_0:CAJKXZ01.fa

    If you want to return cluster folders with mash-files - use --create-clusters flag and set -f path
        ex. of output:
          split_outfolder
            - 1_1
                ---- CAJJTO01.fa
                ---- CAJKGB01.fa
                ---- CAJLGA01.fa
                ---- 1_1_mash.tsv
            - 2_1
                ---- CAJKRE01.fa
                ---- CAJKXJ01.fa
                ---- 2_1_mash.tsv
            - 3_0
                ---- CAJKRY01.fa
                ---- 3_0_mash.tsv
            - 4_0
                ---- CAJKRY01.fa
                ---- 4_0_mash.tsv
    If option --create-clusters was not set script will return mash-folder with mash-files only for many-genomes clusters
        ex:
         split_outfolder
            - mash_folder
                ---- 1_1_mash.tsv
                ---- 2_1_mash.tsv
    ! Toil copies all genomes to tmp and job-store that is why we don't recommend to use --create-clusters option.
    "

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../docker/python3_scripts/split_drep.py

hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.python3:v3"

baseCommand: [ split_drep.py ]

inputs:

  Cdb_csv:
    type: File
    inputBinding:
      prefix: '--cdb'
  Mdb_csv:
    type: File
    inputBinding:
      prefix: '--mdb'
  split_outfolder:
    type: string
    inputBinding:
      position: 3
      prefix: '-o'

  create_clusters:
    type: boolean?
    inputBinding:
      position: 5
      prefix: '--create-clusters'
  genomes_folder:
    type: Directory?
    inputBinding:
      prefix: '-f'

outputs:
  split_out_mash:
    type: File[]?
    outputBinding:
      glob: "$(inputs.split_outfolder)/mash_folder/*"

  split_text:
    type: File
    outputBinding:
      glob: $(inputs.split_outfolder)/clusters_split.txt

  split_out_clusters:
    type: Directory?
    outputBinding:
      glob: $(inputs.split_outfolder)/clusters