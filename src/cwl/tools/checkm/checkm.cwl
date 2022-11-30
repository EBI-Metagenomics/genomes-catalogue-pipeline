#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: "checkm"

requirements:
  ResourceRequirement:
    ramMin: 85000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.checkm:v1"

baseCommand: ["checkm", "lineage_wf"]

arguments:
  - prefix: -t
    valueFrom: '16'
    position: 1
  - prefix: -x
    valueFrom: 'fa'
    position: 2
  - valueFrom: --tab_table
    position: 3


inputs:
  input_folder:
    type: Directory
    inputBinding:
      position: 4

  checkm_outfolder:
    type: string
    inputBinding:
      position: 5

stdout: checkm.out
stderr: checkm.err

outputs:
  stdout: stdout
  stderr: stderr

  out_folder:
    type: Directory
    outputBinding:
      glob: $(inputs.checkm_outfolder)

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"