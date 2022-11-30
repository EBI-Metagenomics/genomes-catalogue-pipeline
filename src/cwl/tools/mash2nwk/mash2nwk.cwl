#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "mash2nwk"

requirements:
  ResourceRequirement:
    ramMin: 10000
    coresMin: 4
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../docker/mash2nwk/mash2nwk1.R
hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.mash2nwk:v1"

baseCommand: ["mash2nwk1.R"]

inputs:
  input_mash:
    type: File
    inputBinding:
      position: 1
      prefix: '-m'

outputs:
  mash_tree:
    type: File
    outputBinding:
      glob: "trees/*.nwk"
      outputEval: |
        ${
          self[0].basename = inputs.input_mash.nameroot + 'tree.nwk';
          return self[0]
        }

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"