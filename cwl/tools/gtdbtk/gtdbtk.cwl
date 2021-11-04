#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 500000
    coresMin: 2
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entry: $(inputs.refdata)
        entryname: $("/refdata")
      - entry: $(inputs.drep_folder)
        entryname: $("/data")
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.gtdb-tk:v1"

baseCommand: ["gtdbtk", "classify_wf"]

arguments:
  - prefix: --cpus
    valueFrom: '2'
    position: 1
  - prefix: --genome_dir
    valueFrom: "/data"
    position: 2
  - prefix: -x
    valueFrom: 'fa'
    position: 4

inputs:
  drep_folder: Directory
  gtdb_outfolder:
    type: string
    inputBinding:
      position: 3
      prefix: '--out_dir'
  refdata: Directory

outputs:
  gtdbtk_folder:
    type: Directory
    outputBinding:
      glob: $(inputs.gtdb_outfolder)
  gtdbtk_bac:
    type: File
    outputBinding:
      glob: $(inputs.gtdb_outfolder)/classify/gtdbtk.bac120.summary.tsv