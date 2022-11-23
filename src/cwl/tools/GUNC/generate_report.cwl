class: CommandLineTool
cwlVersion: v1.2

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMax: 1
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../../docker/python3_scripts/generate_gunc_report.py

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.python3_scripts:v4"

baseCommand: [ generate_gunc_report.py ]

inputs:
  input:
    type: string[]
    inputBinding:
      position: 1
      prefix: -i


outputs:
  report_completed:
    type: File
    outputBinding:
      glob: "gunc_report_completed.txt"

  report_failed:
    type: File
    outputBinding:
      glob: "gunc_report_failed.txt"


$namespaces:
 s: http://schema.org/
$schemas:
 - https://schema.org/version/latest/schemaorg-current-http.rdf
s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
  - class: s:Organization
    s:name: "EMBL - European Bioinformatics Institute"
    s:url: "https://www.ebi.ac.uk"
