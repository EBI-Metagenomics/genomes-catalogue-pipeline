#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 250000
    coresMin: 1
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

baseCommand: [ mmseqs, createdb ]

inputs:
  seq:
    type: File
    inputBinding:
      position: 1

  db:
    type: string
    inputBinding:
      position: 2


outputs:
  created_db:
    type: File[]
    outputBinding:
      glob: $(inputs.db)*
  db_file:
    type: File
    outputBinding:
      glob: $(inputs.db)
  db_file_index:
    type: File
    outputBinding:
      glob: $(inputs.db).index
  db_file_dbtype:
    type: File
    outputBinding:
      glob: $(inputs.db).dbtype