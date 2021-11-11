cwlVersion: v1.2
class: CommandLineTool

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.bash_genomes_pipeline:v1"
  ResourceRequirement:
    coresMin: 1
    ramMin: 1000

baseCommand: [ "tar" ]

arguments: ["-zcvf", "$(inputs.folder.basename).tar.gz"]

inputs:

  folder:
    type: Directory
    inputBinding:
      position: 2

outputs:
  folder_tar:
    type: File
    outputBinding:
      glob: $(inputs.folder.basename).tar.gz


$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"