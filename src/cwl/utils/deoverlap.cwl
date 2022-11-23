cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 1000
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../docker/bash/remove_overlaps_cmscan.sh

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.bash:v1"

inputs:
  cmscan:
    type: File
    inputBinding:
      prefix: -i
  outputname:
    type: string
    inputBinding:
      prefix: -o

baseCommand: [ "remove_overlaps_cmscan.sh" ]

outputs:
  deoverlapped_table:
    type: File
    outputBinding:
      glob: "$(inputs.outputname)"

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
    - name: "EMBL - European Bioinformatics Institute"
    - url: "https://www.ebi.ac.uk/"