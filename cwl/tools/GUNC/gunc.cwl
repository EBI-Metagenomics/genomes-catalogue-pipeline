class: CommandLineTool
cwlVersion: v1.0
$namespaces:
  s: 'http://schema.org/'

requirements:
  ResourceRequirement:
    ramMin: 10000
    coresMax: 4
  InlineJavascriptRequirement: {}


hints:
  DockerRequirement:
    #dockerPull: "docker.io/microbiomeinformatics/genomes-pipeline.gunc:v1"
    dockerPull: "microbiomeinformatics/genomes-pipeline.gunc:v1"

baseCommand: [ "gunc", "run" ]
arguments: ["-t", "4"]

inputs:
  input_fasta:
    type: File
    inputBinding:
      position: 1
      prefix: -i

outputs:
  gunc_tsv:
    type: Directory
    outputBinding:
      glob: "GUNC.maxCSS_level.tsv"


