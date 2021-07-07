class: CommandLineTool
cwlVersion: v1.0
$namespaces:
  s: 'http://schema.org/'

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMax: 1
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../docker/genomes-catalog-update/scripts/rename_fasta.py

hints:
  DockerRequirement:
    dockerPull: "docker.io/microbiomeinformatics/genomes-pipeline.genome-catalog-update:v1"

baseCommand: [ rename_fasta.py ]

inputs:
  genomes:
    type: Directory
    inputBinding:
      position: 1
      prefix: -d

  prefix:
    type: string
    inputBinding:
      position: 2
      prefix: -p

  start_number:
    type: int
    inputBinding:
      position: 3
      prefix: -i

  output_filename:
    type: string
    inputBinding:
      position: 4
      prefix: -t

  output_dirname:
    type: string
    inputBinding:
      position: 5
      prefix: -o

outputs:
  naming_table:
    type: File
    outputBinding:
      glob: $(inputs.output_filename)

  renamed_genomes:
    type: Directory
    outputBinding:
      glob: $(inputs.output_dirname)

