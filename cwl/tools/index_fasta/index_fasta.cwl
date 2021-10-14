cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 200  # just a default, could be lowered

hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.bash:v1"

inputs:
  fasta:
    type: File
    inputBinding:
      prefix: -f

baseCommand: [ "index_fasta.sh" ]

outputs:
  fasta_index:
    type: File
    outputBinding:
      glob: "$(inputs.fasta.basename).fai"

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