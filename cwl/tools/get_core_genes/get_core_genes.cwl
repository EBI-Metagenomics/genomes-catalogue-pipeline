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
        location: ../../../docker/genomes-catalog-update/scripts/get_core_genes.py

hints:
  DockerRequirement:
    dockerPull: "microbiomeinformatics/genomes-pipeline.genome-catalog-update:v1"

baseCommand: [ get_core_genes.py ]


inputs:
  input:
    type: File
    inputBinding:
      position: 1
      prefix: -i

  output_filename:
    type: string
    inputBinding:
      position: 2
      prefix: -o


outputs:
  core_genes:
    type: File
    outputBinding:
      glob: $(inputs.output_filename)


