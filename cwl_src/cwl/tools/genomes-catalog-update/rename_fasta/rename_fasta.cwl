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
        location: ../../../../../containers/genomes-catalog-update/scripts/rename_fasta.py

#hints:
#  DockerRequirement:
#    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.genomes-catalog-update:v1"

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

  max_number:
    type: int
    inputBinding:
      position: 6
      prefix: --max

  csv:
    type: File
    inputBinding:
      position: 7
      prefix: --csv

outputs:
  naming_table:
    type: File
    outputBinding:
      glob: $(inputs.output_filename)

  renamed_genomes:
    type: Directory
    outputBinding:
      glob: $(inputs.output_dirname)

  renamed_csv:
    type: File
    outputBinding:
      glob: renamed_$(inputs.csv.basename)

