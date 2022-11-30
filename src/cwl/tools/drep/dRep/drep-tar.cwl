#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: "dRep"

requirements:
  ResourceRequirement:
    ramMin: 50000
    coresMin: 16
  InlineJavascriptRequirement: {}
  ScatterFeatureRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.drep:v2"


baseCommand: ["drep-wrapper.sh"]

inputs:
  genomes:
    type: File
    inputBinding:
      prefix: '-g'

  drep_outfolder:
    type: string
    inputBinding:
      prefix: '-o'

  csv:
    type: File
    inputBinding:
      prefix: '-c'

  extra_weights:
    type: File
    inputBinding:
      prefix: '-w'

  name:
    type: string
    inputBinding:
      prefix: '-n'

outputs:

  Cdb_csv:
    type: File
    outputBinding:
      glob: $(inputs.drep_outfolder)/data_tables/Cdb.csv

  Mdb_csv:
    type: File
    outputBinding:
      glob: $(inputs.drep_outfolder)/data_tables/Mdb.csv

  Sdb_csv:
    type: File
    outputBinding:
      glob: $(inputs.drep_outfolder)/data_tables/Sdb.csv

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"